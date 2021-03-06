-- | This module exports all available examples via a data type which allows to test
-- various procedures (pretty-printing, type checking, etc) over the entire set of examples
-- in a convenient way: each time a function / data type is added to examples, none of the
-- tests is required to be adapted, instead you just add the new definition to 'examples'
-- defined below and all the tests see it automatically.

{-# LANGUAGE ScopedTypeVariables #-}

module Language.PlutusCore.Examples.Everything
    ( examples
    ) where

import           Language.PlutusCore.FsTree
import           Language.PlutusCore.Universe

import           Language.PlutusCore.StdLib.Type

import           Language.PlutusCore.Examples.Data.InterList
import           Language.PlutusCore.Examples.Data.TreeForest

-- | All examples exported as a single value.
examples :: PlcFolderContents DefaultUni
examples =
    FolderContents
      [ treeFolderContents "Examples"
          [ treeFolderContents "InterList"
              [ plcTypeFile "InterList"      $ _recursiveType interListData
              , plcTermFile "InterNil"       interNil
              , plcTermFile "InterCons"      interCons
              , plcTermFile "FoldrInterList" foldrInterList
              ]
          , treeFolderContents "TreeForest"
              [ plcTypeFile "Tree"       $ _recursiveType treeData
              , plcTypeFile "Forest"     $ _recursiveType forestData
              , plcTermFile "TreeNode"   treeNode
              , plcTermFile "ForestNil"  forestNil
              , plcTermFile "ForestCons" forestCons
              ]
          ]
      ]
