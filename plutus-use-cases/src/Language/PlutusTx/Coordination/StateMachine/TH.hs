{-# LANGUAGE TemplateHaskell     #-}
{-
    A state machine for smart contracts, implemented in Template Haskell.
-}
module Language.PlutusTx.Coordination.StateMachine.TH(
    StateMachine(..),
    stateMachine
    ) where

import           Language.Haskell.TH             (Q, TExp)
import qualified Language.PlutusTx.Prelude       as P
import qualified Language.PlutusTx.Builtins      as Builtins
import qualified Ledger.Validation               as Validation
import           Ledger.Validation               (PendingTx(..), PendingTx', ValidatorHash, DataScriptHash(..), RedeemerHash(..))
import           Prelude                         hiding ((&&), (||))

-- | A state machine (Moore) with state `s` and input `i` and some parameters
--   `p`. It consist of a step function and an equality test for states. The 
--   machine may stop by producing `Nothing`.
data StateMachine p s i = StateMachine {
    step :: Q (TExp (p -> PendingTx' -> s -> i -> s)),
    eqState :: Q (TExp (s -> s -> Bool)),
    finalState :: Q (TExp (s -> Bool))
    }

-- | A function that checks if the new state matches what is expected, and 
-- verifies that the hash of the current redeemer matches that of the new data 
-- script (unless the machine has stopped, in which case the pending 
-- transaction is not checked)
stateMachine :: 
    StateMachine p s i
    -> Q (TExp (p -> (s, i) -> (s, i) -> PendingTx' -> Bool))
stateMachine s = [|| \params (currentState, _) (newState, action) p ->

    let
        
        actualState = $$(step s) params p currentState action
        statesMatch = $$(eqState s) actualState newState

        PendingTx _ (o1:_) _ _ _ _ (_, _, RedeemerHash h) = p

        finished = $$(finalState s) newState

        -- check that our redeemer script hash is the same as the data script hash of the first tx output
        hashesMatch = case $$(Validation.scriptOutput) o1 of
            Nothing -> False -- o1 is a pay-to-pubkey output
            Just (_, DataScriptHash h2) -> Builtins.equalsByteString h h2

    in
        $$(P.and) statesMatch ($$(P.or) finished hashesMatch) ||]