module Main
    ( main
    ) where

import qualified Auth.TypesSpec
import           Test.Tasty     (defaultMain, testGroup)

main :: IO ()
main =
    defaultMain $ testGroup "all tests" [Auth.TypesSpec.tests]
