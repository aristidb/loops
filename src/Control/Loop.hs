{-# LANGUAGE ExistentialQuantification #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE TypeFamilies #-}

module Control.Loop
    ( Loop, LoopT, LoopPrim(..)
    , continue
    , for, unfoldl, loopT
    , ForEach(..)
    , module Control.Monad.Trans.Class
    ) where

import Control.Applicative ((<$>))
import Control.Monad.Trans.Class
import Control.Monad.Free.Church
import Control.Monad.Trans.Free.Church hiding (F, fromF, runF)
import Data.Foldable
import Data.Maybe (fromJust, isJust)
import Prelude hiding (foldr)

data LoopPrim a = forall b. For b (b -> Bool) (b -> b) (b -> a) | Continue

instance Functor LoopPrim where
    fmap f prim =
      case prim of
        For i0 check next g -> For i0 check next (f . g)
        Continue -> Continue
    {-# INLINE fmap #-}

instance Foldable LoopPrim where
    foldr f r0 prim =
      case prim of
        For i0 check next g ->
          let _for i | check i = f (g i) $ _for $ next i
                     | otherwise = r0
          in _for i0
        Continue -> r0
    {-# INLINE foldr #-}

    foldl' f r0 prim =
      case prim of
        For i0 check next g ->
          let _for i r
                | check i =
                  let i' = next i
                      r' = f r $! g i
                  in i' `seq` r' `seq` _for i' r'
                | otherwise = r
          in _for i0 r0
        Continue -> r0
    {-# INLINE foldl' #-}

type Loop = F LoopPrim
type LoopT = FT LoopPrim

for :: MonadFree LoopPrim m => i -> (i -> Bool) -> (i -> i) -> m i
for i0 check next = liftF $ For i0 check next id
{-# INLINE for #-}

unfoldl :: (Functor m, MonadFree LoopPrim m) => (i -> Maybe (i, r)) -> i -> m r
unfoldl unf i0 = fromJust . fmap snd <$> for (unf i0) isJust (>>= unf . fst)
{-# INLINE unfoldl #-}

continue :: MonadFree LoopPrim m => m r
continue = liftF Continue
{-# INLINE continue #-}

loopT :: Monad m => LoopT m () -> m ()
loopT = iterT $ foldl' (>>) (return ())
{-# INLINE loopT #-}

class MonadFree LoopPrim m => ForEach m c where
    type ForEachValue c
    type ForEachIx c
    forEach :: c -> m (ForEachValue c)
    iforEach :: c -> m (ForEachIx c, ForEachValue c)

instance (Functor m, MonadFree LoopPrim m) => ForEach m [a] where
    type ForEachValue [a] = a
    type ForEachIx [a] = Int

    forEach as = head <$> for as (not . null) tail
    {-# INLINE forEach #-}

    iforEach = forEach . zip [0..]
    {-# INLINE iforEach #-}
