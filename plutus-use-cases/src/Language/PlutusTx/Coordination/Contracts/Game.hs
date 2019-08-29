-- | A guessing game
{-# LANGUAGE DataKinds          #-}
{-# LANGUAGE DeriveAnyClass     #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE FlexibleContexts   #-}
{-# LANGUAGE NoImplicitPrelude  #-}
{-# LANGUAGE TemplateHaskell    #-}
{-# LANGUAGE TypeApplications   #-}
{-# LANGUAGE TypeOperators      #-}
{-# LANGUAGE PartialTypeSignatures #-}
{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE MonoLocalBinds #-}
{-# OPTIONS_GHC -fno-ignore-interface-pragmas #-}
module Language.PlutusTx.Coordination.Contracts.Game(
    lock,
    guess,
    game,
    GuessParams(..),
    LockParams(..),
    -- * Scripts
    gameValidator,
    gameDataScript,
    gameRedeemerScript,
    -- * Address
    gameAddress,
    validateGuess,
    -- * Traces
    guessTrace,
    guessWrongTrace,
    lockTrace
    ) where

import           Control.Lens                   (at, (^.))
import           Control.Monad                  (void)
import qualified Data.Aeson                     as Aeson
import qualified Data.Map                       as Map
import           Data.Maybe                     (fromMaybe)
import           GHC.Generics                   (Generic)
import           Language.Plutus.Contract.IOTS                      (IotsType)
import           Language.Plutus.Contract
import           Language.Plutus.Contract.Trace (ContractTrace, MonadEmulator)
import qualified Language.Plutus.Contract.Trace as Trace
import qualified Language.PlutusTx              as PlutusTx
import           Language.PlutusTx.Prelude
import           Ledger                         (Ada, Address, DataScript, PendingTx, RedeemerScript, ValidatorScript)
import qualified Ledger                         as Ledger
import qualified Ledger.Ada                     as Ada
import qualified Ledger.AddressMap              as AM

import qualified Prelude

import qualified Data.ByteString.Lazy.Char8     as C

newtype HashedString = HashedString ByteString

PlutusTx.makeLift ''HashedString

newtype ClearString = ClearString ByteString

PlutusTx.makeLift ''ClearString

type Req =
    BlockchainIn
        .\/ EndpointIn "lock" LockParams
        .\/ EndpointIn "guess" GuessParams

type Resp =
    BlockchainOut
        .\/ EndpointOut "lock"
        .\/ EndpointOut "guess"

correctGuess :: HashedString -> ClearString -> Bool
correctGuess (HashedString actual) (ClearString guess') = actual == sha2_256 guess'

-- | The validator (datascript -> redeemer -> PendingTx -> Bool)
validateGuess :: HashedString -> ClearString -> PendingTx -> Bool
validateGuess dataScript redeemerScript _ = correctGuess dataScript redeemerScript

gameValidator :: ValidatorScript
gameValidator =
    Ledger.ValidatorScript ($$(Ledger.compileScript [|| validateGuess ||]))

gameDataScript :: String -> DataScript
gameDataScript =
    Ledger.DataScript . Ledger.lifted . HashedString . Ledger.plcSHA2_256 . C.pack

gameRedeemerScript :: String -> RedeemerScript
gameRedeemerScript =
    Ledger.RedeemerScript . Ledger.lifted . ClearString . C.pack

gameAddress :: Address
gameAddress = Ledger.scriptAddress gameValidator

-- | Parameters for the "lock" endpoint
data LockParams = LockParams
    { secretWord :: String
    , amount     :: Ada
    }
    deriving stock (Prelude.Eq, Prelude.Ord, Prelude.Show, Generic)
    deriving anyclass (Aeson.FromJSON, Aeson.ToJSON, IotsType)

--  | Parameters for the "guess" endpoint
newtype GuessParams = GuessParams
    { guessWord :: String
    }
    deriving stock (Prelude.Eq, Prelude.Ord, Prelude.Show, Generic)
    deriving anyclass (Aeson.FromJSON, Aeson.ToJSON, IotsType)

guess :: Contract Req Resp ()
guess = do
    st <- nextTransactionAt gameAddress
    let mp = AM.fromTxOutputs st
    GuessParams theGuess <- endpoint @"guess" @GuessParams
    let
        txOutputs  = Map.toList . fromMaybe Map.empty $ mp ^. at gameAddress
        redeemer   = gameRedeemerScript theGuess
        inp        = (\o -> Ledger.scriptTxIn (fst o) gameValidator redeemer) <$> txOutputs
        tx         = unbalancedTx inp []
    void (writeTx tx)

lock :: Contract Req Resp ()
lock = do
    LockParams secret amt <- endpoint @"lock" @LockParams
    let
        vl         = Ada.toValue amt
        dataScript = gameDataScript secret
        output     = Ledger.TxOutOf gameAddress vl (Ledger.PayToScript dataScript)
        tx         = unbalancedTx [] [output]
    void (writeTx tx)

game :: Contract Req Resp ()
game = guess <|> lock

lockTrace
    :: ( MonadEmulator m )
    => ContractTrace Req Resp m a ()
lockTrace =
    let w1 = Trace.Wallet 1 
        w2 = Trace.Wallet 2 in
    Trace.callEndpoint @"lock" w1 (LockParams "secret" 10) 
        >> Trace.notifyInterestingAddresses w2
        >> Trace.handleBlockchainEvents w1

guessTrace
    :: ( MonadEmulator m )
    => ContractTrace Req Resp m a ()
guessTrace =
    let w2 = Trace.Wallet 2 in
    lockTrace 
        >> Trace.callEndpoint @"guess" w2 (GuessParams "secret") 
        >> Trace.handleBlockchainEvents w2

guessWrongTrace
    :: ( MonadEmulator m )
    => ContractTrace Req Resp m a ()
guessWrongTrace =
    let w2 = Trace.Wallet 2 in
    lockTrace 
        >> Trace.callEndpoint @"guess" w2 (GuessParams "SECRET") 
        >> Trace.handleBlockchainEvents w2
