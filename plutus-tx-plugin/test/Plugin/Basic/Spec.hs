{-# LANGUAGE DataKinds           #-}
{-# LANGUAGE OverloadedStrings   #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeApplications    #-}
{-# OPTIONS -fplugin Language.PlutusTx.Plugin #-}
{-# OPTIONS -fplugin-opt Language.PlutusTx.Plugin:defer-errors #-}
{-# OPTIONS -fplugin-opt Language.PlutusTx.Plugin:no-context #-}

module Plugin.Basic.Spec where

import           Common
import           PlcTestUtils
import           Plugin.Lib

import qualified Language.PlutusTx.Builtins   as Builtins
import           Language.PlutusTx.Code
import           Language.PlutusTx.Plugin

import qualified Language.PlutusCore.Universe as PLC

-- this module does lots of weird stuff deliberately
{-# ANN module ("HLint: ignore"::String) #-}

basic :: TestNested
basic = testNested "Basic" [
    goldenPir "monoId" monoId
  , goldenPir "monoK" monoK
  , goldenPir "letFun" letFun
  -- must keep the scrutinee as it evaluates to error
  , goldenPir "ifOpt" ifOpt
  -- should fail
  , goldenEval "ifOptEval" [ifOpt]
  ]

monoId :: CompiledCode PLC.DefaultUni (Integer -> Integer)
monoId = plc @"monoId" (\(x :: Integer) -> x)

monoK :: CompiledCode PLC.DefaultUni (Integer -> Integer -> Integer)
monoK = plc @"monoK" (\(i :: Integer) -> \(j :: Integer) -> i)

-- GHC acutually turns this into a lambda for us, try and make one that stays a let
letFun :: CompiledCode PLC.DefaultUni (Integer -> Integer -> Bool)
letFun = plc @"letFun" (\(x::Integer) (y::Integer) -> let f z = Builtins.equalsInteger x z in f y)

ifOpt :: CompiledCode PLC.DefaultUni Integer
ifOpt = plc @"ifOpt" (if ((1 `Builtins.divideInteger` 0) `Builtins.equalsInteger` 0) then 1 else 1)
