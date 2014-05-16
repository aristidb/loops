{-# LANGUAGE ExistentialQuantification #-}
{-# LANGUAGE FlexibleContexts #-}

module Control.Loop
    ( Loop, Loop'
    , unfoldl, for
    , module Control.Monad.Trans.Class
    ) where

import Control.Monad.Trans.Class
import Control.Monad.Free (Free(..))
import Control.Monad.Free.Church
import Data.Bifunctor
import Data.Foldable
import Prelude hiding (foldr)

data LoopOp a = forall i. Unfold !i !(i -> Maybe (i, a))

instance Functor LoopOp where
    fmap f op =
        case op of
          Unfold i0 unf -> Unfold i0 $ fmap (second f) . unf

instance Foldable LoopOp where
    foldr f r0 op =
      case op of
        Unfold i0 unf ->
          let go i =
                case unf i of
                  Nothing -> r0
                  Just (i', a) -> f a $ go i'
          in go i0

    foldl' f r0 op =
      case op of
        Unfold i0 unf ->
          let go i r =
                case unf i of
                  Nothing -> r
                  Just (i', a) -> go i' $! f r a
          in go i0 r0

type Loop = F LoopOp
type Loop' = Free LoopOp

unfoldl :: MonadFree LoopOp m => (i -> Maybe (i, r)) -> i -> m r
unfoldl unf i0 = liftF $ Unfold i0 unf

for :: MonadFree LoopOp m => i -> (i -> Bool) -> (i -> i) -> m i
for i0 cont next = unfoldl unf i0
  where
    unf i | cont i = Just (next i, i)
          | otherwise = Nothing

instance (Foldable f, Functor f) => Foldable (F f) where
    foldr f r = foldr f r . (fromF :: Functor f => F f a -> Free f a)
    foldl' f r = foldl' f r . (fromF :: Functor f => F f a -> Free f a)
