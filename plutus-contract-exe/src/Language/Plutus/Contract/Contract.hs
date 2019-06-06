{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE LambdaCase        #-}
{-# LANGUAGE TypeFamilies      #-}
module Language.Plutus.Contract.Contract(
      Contract
    , emit
    , waiting
    , applyInput
    , applyInputs
    , drain
    , outputs
    , await
    , result
    , loopM
    , foldMaybe
    , firstOf
    , select
    , both
    ) where

import           Control.Applicative (liftA2)
import           Control.Monad       ((>=>))
import           Data.Bifunctor      (first)
import           Data.List           (foldl')
import           Data.Functor.Alt

data Contract i o a =
    Waiting (i -> Contract i o a)
    | Emit o (Contract i o a) -- produce a 't' value
    | Pure a
    deriving (Functor)

instance Alt (Contract i o) where
    (<!>) = select

-- The applicative instance parallelises the 'Waiting' operations
instance Applicative (Contract i o) where
    pure = Pure
    cf <*> ca = case cf of
        Emit t c -> Emit t (c <*> ca)
        Pure f -> fmap f ca
        Waiting f ->
            case ca of
                Emit t c -> Emit t (Waiting f <*> c)
                Pure a' -> Waiting $ \i' -> fmap (\f' -> f' a') (f i')
                Waiting f' ->
                    Waiting $ \i' -> f i' <*> f' i'

-- The monad instance sequentialises the 'Waiting' operations
instance Monad (Contract i o) where
    c >>= f = case c of
        Waiting f' -> Waiting (f' >=> f)
        Pure a     -> f a
        Emit t c'  -> Emit t (c' >>= f)

instance Semigroup a => Semigroup (Contract i o a) where
    (<>) = liftA2 (<>)

-- | Run both contracts and return the first one that finishes
select :: Contract i o a -> Contract i o a -> Contract i o a
select l r = 
    case l of
        Pure a -> Pure a
        Emit e c -> Emit e (select c r)
        Waiting f -> 
            go r where
                go = \case
                    Pure a -> Pure a
                    Emit e c -> Emit e (go c)
                    Waiting f' -> 
                        Waiting $ \i -> select (f i) (f' i)


emit :: o -> Contract i o ()
emit t = Emit t (pure ())

waiting :: Contract i o i
waiting = Waiting pure

-- https://hackage.haskell.org/package/extra-1.6.15/docs/src/Control.Monad.Extra.html#loopM

-- | A monadic version of 'loop', where the predicate returns 'Left' as a seed for the next loop
--   or 'Right' to abort the loop.
loopM :: Monad m => (a -> m (Either a b)) -> a -> m b
loopM act x = do
    res <- act x
    case res of
        Left x' -> loopM act x'
        Right v -> return v

-- | Repeatedly evaluate the action until it yields 'Nothing',
--   then return the aggregated result.
foldMaybe 
    :: Monad m 
    => (a -> b -> b) 
    -> b 
    -> m (Maybe a) 
    -> m b
foldMaybe f b con = loopM go b where
    go b' = maybe (Left b') (Right . flip f b') <$> con

-- | Apply an input to a contract
applyInput
    :: i
    -> Contract i o a
    -> Contract i o a
applyInput ip = \case
    Waiting f -> f ip
    Pure a -> Pure a -- ??
    Emit t c -> Emit t (applyInput ip c)

applyInputs
    :: Contract i o a
    -> [i]
    -> Contract i o a
applyInputs = foldl' (flip applyInput)

drain :: Monoid o => Contract i o a -> (o, Contract i o a)
drain = \case
    Waiting f -> (mempty, Waiting f)
    Pure a -> (mempty, Pure a)
    Emit t c -> first (t <>) (drain c)

outputs :: Monoid o => Contract i o a -> o
outputs = fst . drain

result :: Monoid o => Contract i o a -> Maybe a
result = (\case { Pure b -> Just b; _ -> Nothing }) . snd . drain

await :: o -> (i -> Maybe a) -> Contract i o a
await a f = do
    emit a
    i <- waiting
    case f i of
        Nothing -> await a f
        Just i' -> pure i'

both :: Contract i o a -> Contract i o b -> Contract i o (a, b)
both = liftA2 (,)

firstOf :: Contract i o a -> Contract i o b -> Contract i o (Either a b)
firstOf l r = select (Left <$> l) (Right <$> r)