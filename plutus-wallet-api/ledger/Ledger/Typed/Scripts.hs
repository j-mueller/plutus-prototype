{-# LANGUAGE DataKinds           #-}
{-# LANGUAGE DeriveAnyClass      #-}
{-# LANGUAGE DeriveGeneric       #-}
{-# LANGUAGE DerivingStrategies  #-}
{-# LANGUAGE GADTs               #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeFamilies        #-}
{-# OPTIONS_GHC -fno-specialise #-}
{-# OPTIONS_GHC -fno-omit-interface-pragmas #-}
module Ledger.Typed.Scripts(
    ScriptType(..)
    , Validator
    , ScriptInstance
    , MonetaryPolicy
    , validator
    , scriptHash
    , scriptAddress
    , validatorScript
    , wrapValidator
    , wrapMonetaryPolicy
    , monetaryPolicy
    , monetaryPolicyHash
    , ValidatorType
    , WrappedValidatorType
    , WrappedMonetaryPolicyType
    , TypedValidatorHash
    , untypedHash
    , fromValidator
    , Any
    ) where

import           Language.PlutusTx

import qualified Ledger.Address                  as Addr
import           Ledger.Scripts                  hiding (monetaryPolicyHash)
import qualified Ledger.Scripts

import           Data.Aeson                      (FromJSON, ToJSON)
import           Data.Kind
import           Data.Text.Prettyprint.Doc
import           GHC.Generics                    (Generic)
import           Ledger.Typed.Scripts.Validators

-- | Validator hash with a phantom type
newtype TypedValidatorHash (h :: Type) = TypedValidatorHash { unTypedValidatorHash :: ValidatorHash }
    deriving (Eq, Generic)
    deriving newtype (ToJSON, FromJSON, Pretty)

-- | A typed validator script with its 'ValidatorScript' and 'Address'.
data ScriptInstance (a :: Type) =
    Validator
        { instanceScript  :: Validator
        , instanceHash    :: TypedValidatorHash a
        , instanceMPSHash :: MonetaryPolicyHash
        -- ^ The hash of the monetary policy that checks whether the validator
        --   is run in this transaction
        , instanceMPS     :: MonetaryPolicy
        }
    deriving (Eq, Generic, ToJSON, FromJSON)

-- | The 'ScriptInstance' of a validator script and its wrapper.
validator ::
    CompiledCode (ValidatorType a)
    -- ^ Validator script (compiled)
    -> CompiledCode (ValidatorType a -> WrappedValidatorType)
    -- ^ A wrapper for the compiled validator
    -> ScriptInstance a
validator vc wrapper =
    let val = mkValidatorScript $ wrapper `applyCode` vc
        hsh = TypedValidatorHash $ validatorHash val
        mps = mkMonetaryPolicy (untypedHash hsh)
    in Validator
        { instanceScript  = val
        , instanceHash    = TypedValidatorHash $ validatorHash val
        , instanceMPS     = mps
        , instanceMPSHash = Ledger.Scripts.monetaryPolicyHash mps
        }

-- | Get the typed validator hash for a script instance.
scriptHash :: ScriptInstance a -> TypedValidatorHash a
scriptHash = instanceHash

-- | The untyped 'ValidatorHash'
untypedHash :: TypedValidatorHash a -> ValidatorHash
untypedHash = unTypedValidatorHash

-- | Get the address for a script instance.
scriptAddress :: ScriptInstance a -> Addr.Address
scriptAddress = Addr.scriptHashAddress . unTypedValidatorHash . scriptHash

-- | Get the validator script for a script instance.
validatorScript :: ScriptInstance a -> Validator
validatorScript = instanceScript

-- | Script instance for a validator whose type is unknown
fromValidator :: Validator -> ScriptInstance Any
fromValidator vl =
    let vh = validatorHash vl
        mps = mkMonetaryPolicy vh
    in
    Validator
        { instanceScript  = vl
        , instanceHash    = TypedValidatorHash vh
        , instanceMPS     = mps
        , instanceMPSHash = Ledger.Scripts.monetaryPolicyHash mps
        }

-- | The monetary policy that forwards all checks to the instance's
--   validator
monetaryPolicy :: ScriptInstance a -> MonetaryPolicy
monetaryPolicy = instanceMPS

-- | Hash of the monetary policy that forwards all checks to the instance's
--   validator
monetaryPolicyHash :: ScriptInstance a -> MonetaryPolicyHash
monetaryPolicyHash = instanceMPSHash
