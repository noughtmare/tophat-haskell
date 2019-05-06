module Prelude
  ( module Relude
  , module Data.Text.Prettyprint.Doc
  , module Data.Type.Equality
  , List, Unit
  , Pretty(..), read
  , neutral
  , (<<), (>>) --, (<|), (|>)
  , map
  , (<-<), (>->) --, (-<), (>-)
  , Monoidal((<&>), skip, (<&), (&>)), applyDefault, pureDefault, pairDefault, skipDefault
  , Selective(branch, select, biselect), check, when
  , lift1, lift2, lift3
  , ok, throw, catch
  , (~=), (~~), proxyOf, typeOf, someTypeOf, typeRep, TypeRep, SomeTypeRep
  ) where


import Relude hiding ((.), (>>), (&), (<&>), (<$>), (<*), (*>), map, when, trace, readMaybe, liftA2, liftA3)
import qualified Relude

import Control.Monad.Except (MonadError(..))

import Data.Text (unpack)
import Data.Text.Prettyprint.Doc hiding (group)
import Data.Type.Equality

import Type.Reflection (typeOf, typeRep, someTypeRep, TypeRep, SomeTypeRep)



-- Synonyms --------------------------------------------------------------------


type List a = [a]


type Unit = ()



-- Reading & Showing -----------------------------------------------------------


read :: Read a => Text -> Maybe a
read = Relude.readMaybe << unpack



-- Monoids ---------------------------------------------------------------------


neutral :: Monoid m => m
neutral = mempty
{-# INLINE neutral #-}



-- Functions -------------------------------------------------------------------


infixr 9 <<
infixr 9 >>
infixr 0 <|
infixl 1 |>


(<<) :: (b -> c) -> (a -> b) -> a -> c
f << g = \x -> f (g x)
{-# INLINE (<<) #-}


(>>) :: (a -> b) -> (b -> c) -> a -> c
(>>) = flip (<<)
{-# INLINE (>>) #-}


(<|) :: (a -> b) -> a -> b
(<|) f a = f a
{-# INLINE (<|) #-}


(|>) :: a -> (a -> b) -> b
(|>) = flip (<|)
{-# INLINE (|>) #-}



-- Functors --------------------------------------------------------------------


-- infixl 1 <#>


-- (<#>) :: Functor f => f a -> (a -> b) -> f b
-- (<#>) = flip map
-- {-# INLINE (<#>) #-}


map :: Functor f => (a -> b) -> f a -> f b
map = Relude.fmap



-- Applicatives ----------------------------------------------------------------


infixr 1 <-<
infixr 1 >->
infixl 5 -<
infixr 5 >-


lift1 :: Functor f => (a -> b) -> f a -> f b
lift1 = fmap
{-# INLINE lift1 #-}


lift2 :: Applicative f => (a -> b -> c) -> f a -> f b -> f c
lift2 = Relude.liftA2
{-# INLINE lift2 #-}


lift3 :: Applicative f => (a -> b -> c -> d) -> f a -> f b -> f c -> f d
lift3 = Relude.liftA3
{-# INLINE lift3 #-}


(<-<) :: Applicative f => f (b -> c) -> f (a -> b) -> f (a -> c)
f <-< g = pure (<<) -< f -< g
{-# INLINE (<-<) #-}


(>->) :: Applicative f => f (a -> b) -> f (b -> c) -> f (a -> c)
(>->) = flip (<-<)
{-# INLINE (>->) #-}


(-<) :: Applicative f => f (a -> b) -> f a -> f b
(-<) = (Relude.<*>)
{-# INLINE (-<) #-}


(>-) :: Applicative f => f a -> f (a -> b) -> f b
(>-) = flip (Relude.<*>)
{-# INLINE (>-) #-}



-- Monoidal functors -----------------------------------------------------------


infixl 6 <&>
infixl 6 <&
infixl 6 &>


class Functor f => Monoidal f where
  (<&>) :: f a -> f b -> f ( a, b )
  skip  :: f ()

  (<&) :: f a -> f b -> f a
  (<&) x y = map fst <| x <&> y

  (&>) :: f a -> f b -> f b
  (&>) x y = map snd <| x <&> y


applyDefault :: Monoidal f => f (a -> b) -> f a -> f b
applyDefault fg fx = map (\( g, x ) -> g x) <| fg <&> fx


pureDefault :: Monoidal f => a -> f a
pureDefault x = map (const x) skip


pairDefault :: Applicative f => f a -> f b -> f ( a, b )
pairDefault x y = pure (,) -< x -< y


skipDefault :: Applicative f => f ()
skipDefault = pure ()



-- Selective functors ----------------------------------------------------------


class Applicative f => Selective f where
  branch :: f (Either a b) -> f (a -> c) -> f (b -> c) -> f c
  branch p x y = map (map Left) p `select` map (map Right) x `select` y

  select :: f (Either a b) -> f (a -> b) -> f b
  select x y = branch x y (pure identity)

  biselect :: f (Either a b) -> f (Either a c) -> f (Either a ( b, c ))
  biselect x y = select (pure (map Left << swap) -< x) (pure (\e a -> map ( a, ) e) -< y)
    where
      swap = either Right Left


check :: Selective f => f Bool -> f a -> f a -> f a
check p t e = branch (map go p) (map const t) (map const e)
  where
    go x = if x then Right () else Left ()


when :: Selective f => f Bool -> f Unit -> f Unit
when p t = check p t (pure ())



-- Monads ----------------------------------------------------------------------

-- Errors --


ok :: MonadError e m => a -> m a
ok = pure
{-# INLINE ok #-}


throw :: MonadError e m => e -> m a
throw = throwError
{-# INLINE throw #-}


catch :: MonadError e m => m a -> (e -> m a) -> m a
catch = catchError
{-# INLINE catch #-}



-- Type equality ---------------------------------------------------------------


infix 4 ~=
infix 4 ~~


(~=) :: ( Typeable a, Typeable b ) => a -> b -> Maybe (a :~: b)
(~=) x y = typeOf x ~~ typeOf y
{-# INLINE (~=) #-}


(~~) :: TestEquality f => f a -> f b -> Maybe (a :~: b)
(~~) = testEquality
{-# INLINE (~~) #-}


proxyOf :: a -> Proxy a
proxyOf _ = Proxy
{-# INLINE proxyOf #-}


someTypeOf :: forall a. Typeable a => a -> SomeTypeRep
someTypeOf = someTypeRep << proxyOf
{-# INLINE someTypeOf #-}


instance Pretty SomeTypeRep where
  pretty = viaShow