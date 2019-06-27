{-# LANGUAGE DeriveAnyClass     #-}
{-# LANGUAGE DeriveGeneric      #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE LambdaCase         #-}
module Language.Plutus.Contract.Record where

import           Control.Lens
import           Data.Bifunctor (Bifunctor (..))
import           Data.Sequence  (Seq)
import           GHC.Generics   (Generic)

import           Data.Aeson     (Value)
import qualified Data.Aeson     as Aeson

data FinalValue i = FinalJSON Value | FinalEvents (Seq i)
    deriving stock (Eq, Show, Generic, Functor)
    deriving anyclass (Aeson.FromJSON, Aeson.ToJSON)

data ClosedRecord i =
    ClosedLeaf (FinalValue i)
  | ClosedBin  (ClosedRecord i) (ClosedRecord i)
  deriving stock (Eq, Show, Generic, Functor)
  deriving anyclass (Aeson.FromJSON, Aeson.ToJSON)

data OpenRecord i =
    OpenLeaf (Seq i)
  | OpenBind (OpenRecord i)
  | OpenLeft (OpenRecord i) (ClosedRecord i)
  | OpenRight (ClosedRecord i) (OpenRecord i)
  | OpenBoth (OpenRecord i) (OpenRecord i)
  deriving stock (Eq, Show, Generic, Functor)
  deriving anyclass (Aeson.FromJSON, Aeson.ToJSON)

openSubRecords :: Traversal' (OpenRecord i) (OpenRecord i)
openSubRecords f = \case
    v@OpenLeaf{} -> pure v
    OpenBind b -> OpenBind <$> f b
    OpenLeft l r -> OpenLeft <$> f l <*> pure r
    OpenRight l r -> OpenRight l <$> f r
    OpenBoth l r -> OpenBoth <$> f l <*> f r

closedSubRecords :: Traversal' (ClosedRecord i) (ClosedRecord i)
closedSubRecords f = \case
    v@ClosedLeaf{} -> pure v
    ClosedBin l r -> ClosedBin <$> f l <*> f r

type Record i = Either (OpenRecord i) (ClosedRecord i)

fromPair :: Record i -> Record i -> Record i
fromPair l r = case (l, r) of
  (Left l', Right r')  -> Left (OpenLeft l' r')
  (Left l', Left r')   -> Left (OpenBoth l' r')
  (Right l', Left r')  -> Left (OpenRight l' r')
  (Right l', Right r') -> Right (ClosedBin l' r')

jsonLeaf :: (Aeson.ToJSON a) => a -> ClosedRecord i
jsonLeaf = ClosedLeaf . FinalJSON . Aeson.toJSON

insert :: i -> Record i -> Record i
insert i = bimap go id  where
  go = \case
      OpenLeaf s -> OpenLeaf (s |> i)
      OpenLeft or' cr -> OpenLeft (go or') cr
      OpenRight cr or' -> OpenRight cr (go or')
      OpenBoth or' or'' -> OpenBoth (go or') (go or'')
      OpenBind or' -> OpenBind (go or')
