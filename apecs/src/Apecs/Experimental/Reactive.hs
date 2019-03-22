{-|
Stability : experimental

This module is experimental, and its API might change between point releases. Use at your own risk.

Adds the @Reactive r s@ store, which when wrapped around store @s@, will call the @react@ on its @r@.

@Show c => Reactive (Printer c) (Map c)@ will print a message every time a @c@ value is set.

@Enum c => Reactive (EnumMap c) (Map c)@ allows you to look up entities by component value.
Use e.g. @rget >>= mapLookup True@ to retrieve a list of entities that have a @True@ component.

-}
{-# LANGUAGE FlexibleContexts      #-}
{-# LANGUAGE FlexibleInstances     #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE RankNTypes            #-}
{-# LANGUAGE ScopedTypeVariables   #-}
{-# LANGUAGE TypeFamilies          #-}

module Apecs.Experimental.Reactive where

import           Control.Monad.Reader
import qualified Data.IntMap.Strict   as M
import qualified Data.IntSet          as S
import           Data.IORef

import           Apecs.Core
import           Apecs.Components

-- | Analogous to @Elem@, but for @Reacts@ instances.
--   For a @Reactive r s@ to be valid, @ReactElem r = Elem s@
type family ReactElem r

-- | Class required by @Reactive@.
--   Given some @r@ and update information about some component, will run a side-effect in monad @m@.
--   Note that there are also instances for @(,)@.
class Monad m => Reacts m r where
  rempty :: m r
  react  :: Entity -> Maybe (ReactElem r) -> Maybe (ReactElem r) -> r -> m ()

type instance ReactElem (a,b) = ReactElem a
instance (ReactElem a ~ ReactElem b, Reacts m a, Reacts m b) => Reacts m (a, b) where
  {-# INLINE rempty #-}
  rempty = liftM2 (,) rempty rempty
  {-# INLINE react #-}
  react ety old new (a,b) = react ety old new a >> react ety old new b

-- | Wrapper for reactivity around some store s.
data Reactive r s = Reactive r s

type instance Elem (Reactive r s) = Elem s

-- | Reads @r@ from the game world.
rget :: forall w m r s.
  ( Component (ReactElem r)
  , Has w m (ReactElem r)
  , Storage (ReactElem r) ~ Reactive r s
  ) => SystemT w m r
rget = do
  Reactive r (_ :: s) <- getStore
  return r

instance (Reacts m r, ExplInit m s) => ExplInit m (Reactive r s) where
  explInit = liftM2 Reactive rempty explInit

instance (Reacts m r, ExplSet m s, ExplGet m s, Elem s ~ ReactElem r)
  => ExplSet m (Reactive r s) where
  {-# INLINE explSet #-}
  explSet (Reactive r s) ety c = do
    old <- explGet (MaybeStore s) ety
    react (Entity ety) old (Just c) r
    explSet s ety c

instance (Reacts m r, ExplDestroy m s, ExplGet m s, Elem s ~ ReactElem r)
  => ExplDestroy m (Reactive r s) where
  {-# INLINE explDestroy #-}
  explDestroy (Reactive r s) ety = do
    old <- explGet (MaybeStore s) ety
    react (Entity ety) old Nothing r
    explDestroy s ety

instance ExplGet m s => ExplGet m (Reactive r s) where
  {-# INLINE explExists #-}
  explExists (Reactive _ s) = explExists s
  {-# INLINE explGet    #-}
  explGet    (Reactive _ s) = explGet    s

instance ExplMembers m s => ExplMembers m (Reactive r s) where
  {-# INLINE explMembers #-}
  explMembers (Reactive _ s) = explMembers s

-- | Prints a message to stdout every time a component is updated.
data Printer c = Printer
type instance ReactElem (Printer c) = c

instance (MonadIO m, Show c) => Reacts m (Printer c) where
  {-# INLINE rempty #-}
  rempty = return Printer
  {-# INLINE react #-}
  react (Entity ety) (Just c) Nothing _ = liftIO$
    putStrLn $ "Entity " ++ show ety ++ ": destroyed component " ++ show c
  react (Entity ety) Nothing (Just c) _ = liftIO$
    putStrLn $ "Entity " ++ show ety ++ ": created component " ++ show c
  react (Entity ety) (Just old) (Just new) _ = liftIO$
    putStrLn $ "Entity " ++ show ety ++ ": update component " ++ show old ++ " to " ++ show new
  react _ _ _ _ = return ()

-- | Allows you to look up entities by component value.
--   Use e.g. @rget >>= mapLookup True@ to retrieve a list of entities that have a @True@ component.
newtype EnumMap c = EnumMap (IORef (M.IntMap S.IntSet))

type instance ReactElem (EnumMap c) = c
instance (MonadIO m, Enum c) => Reacts m (EnumMap c) where
  {-# INLINE rempty #-}
  rempty = liftIO$ EnumMap <$> newIORef mempty
  {-# INLINE react #-}
  react _ Nothing Nothing _ = return ()
  react (Entity ety) (Just c) Nothing (EnumMap ref) = liftIO$
    modifyIORef' ref (M.adjust (S.delete ety) (fromEnum c))
  react (Entity ety) Nothing (Just c) (EnumMap ref) = liftIO$
    modifyIORef' ref (M.insertWith mappend (fromEnum c) (S.singleton ety))
  react (Entity ety) (Just old) (Just new) (EnumMap ref) = liftIO$ do
    modifyIORef' ref (M.adjust (S.delete ety) (fromEnum old))
    modifyIORef' ref (M.insertWith mappend (fromEnum new) (S.singleton ety))

{-# INLINE mapLookup #-}
mapLookup :: Enum c => EnumMap c -> c -> System w [Entity]
mapLookup (EnumMap ref) c = do
  emap <- liftIO $ readIORef ref
  return $ maybe [] (fmap Entity . S.toList) (M.lookup (fromEnum c) emap)
