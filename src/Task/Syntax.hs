module Task.Syntax
  ( -- * Types
    Task (..),
    -- NormalTask (..),
    Editor (..),
    Name (..),
    Label,
    Id,

    -- * Reexports
    module Data.Basic,
    module Data.Some,
    module Data.Store,
  )
where

import Data.Basic
import Data.Some
import Data.Store
import Prelude hiding (guard, repeat)

---- Names ---------------------------------------------------------------------

data Name
  = Unnamed
  | Named Id
  deriving (Eq, Ord, Debug, Scan)

type Id = Nat

type Label = Text

---- Tasks ---------------------------------------------------------------------

-- | Tasks parametrised over a heap `h`, making use of effects `r`.
-- |
-- | **Important!**
-- | We do *not* encode this as a free monad.
-- | It is not free, because we'd like to have full control over the semantics for bind, i.e. `Step` below.
-- | This saves us from higher order interpretation,
-- | and gives us the freedom to completely control our own semantics.
-- |
-- | It can be seen best like this:
-- | We use `Sem` and its effects to *implement* its semantics,
-- | but `Task` is not an effect itself.
-- | In particular, it can't be combined with other effects,
-- | it only *needs* effects to be interpreted (denoted by `r`).
-- | I.e. `Task` is a monad on it's own right.
-- | (Although it actually isn't a monad... but that's another story.)
data Task h t where
  ---- Editors

  -- | Editors, named and unnamed
  Edit :: Name -> Editor h t -> Task h t
  -- | Selections, based on the output of the current task
  Select :: Name -> Task h a -> Assoc Label (a -> Task h t) -> Task h t
  ---- Parallels

  -- | Composition of two tasks.
  Pair :: Task h a -> Task h b -> Task h (a, b)
  -- | Internal, unrestricted and hidden editor
  Lift :: t -> Task h t
  -- | Internal choice between two tasks.
  Choose :: Task h t -> Task h t -> Task h t
  -- | The failing task
  Fail :: Task h t
  ---- Steps

  -- | Internal value transformation
  Trans :: (a -> t) -> Task h a -> Task h t
  -- | Internal, or system step.
  Step :: Task h a -> (a -> Task h t) -> Task h t
  ---- Checks

  -- | Assertions
  Assert :: Bool -> Task h Bool
  ---- References
  -- The inner monad `m` needs to have the notion of references.
  -- These references should be `Eq` and `Typeable`,
  -- because we need to mark them dirty and match those with watched references.

  -- | Create new reference of type `t`
  Share :: (Basic t, Reflect h) => t -> Task h (Store h t)
  -- | Assign to a reference of type `t` to a given value
  Assign :: (Basic a) => a -> Store h a -> Task h ()

-- NOTE:
-- We could choose to replace `Share` and `Assign` and with a general `Lift` constructor,
-- taking an arbitrary action in the underlying monad `m`.
-- This action would then be performed during normalisation.
-- However, for now, we like to constrain the actions one can perform in the `Task` monad.
-- This makes actions like logging to stdout, lounching missiles or other effects impossible.
-- (Though this would need to be constrained with classes when specifying the task!)

data Editor h t where
  -- | Unvalued editor
  Enter :: (Basic t) => Editor h t
  -- | Valued editor
  Update :: (Basic t) => t -> Editor h t
  -- | Valued, view only editor
  View :: (Basic t) => t -> Editor h t
  -- | Change to a reference of type `t` to a value
  Change :: (Basic t) => Store h t -> Editor h t
  -- | Watch a reference of type `t`
  Watch :: (Basic t) => Store h t -> Editor h t

---- Normalised tasks ----------------------------------------------------------

data NormalTask h t where
  ---- Editors
  NormalEdit :: Id -> Editor h t -> NormalTask h t
  NormalSelect :: Id -> NormalTask h a -> Assoc Label (a -> Task h t) -> NormalTask h t
  ---- Parallels
  NormalPair :: NormalTask h a -> NormalTask h b -> NormalTask h (a, b)
  NormalLift :: t -> NormalTask h t
  NormalChoose :: NormalTask h t -> NormalTask h t -> NormalTask h t
  NormalFail :: NormalTask h t
  ---- Steps
  NormalTrans :: (a -> t) -> NormalTask h a -> NormalTask h t
  NormalStep :: NormalTask h a -> (a -> Task h t) -> NormalTask h t

unnormal :: NormalTask h a -> Task h a
unnormal = \case
  NormalEdit k e -> Edit (Named k) e
  NormalSelect k t ts -> Select (Named k) (unnormal t) ts
  NormalPair t1 t2 -> Pair (unnormal t1) (unnormal t2)
  NormalLift e -> Lift e
  NormalChoose t1 t2 -> Choose (unnormal t1) (unnormal t2)
  NormalFail -> Fail
  NormalTrans e1 t2 -> Trans e1 (unnormal t2)
  NormalStep t1 e2 -> Step (unnormal t1) e2

---- Display -------------------------------------------------------------------

instance Display (Task h t) where
  display = \case
    Edit n e -> concat [display e |> between '(' ')', "^", display n]
    Select n t ts -> concat [display t, " >>?", display (keys ts), "^", display n] |> between '(' ')'
    Pair t1 t2 -> unwords [display t1, "><", display t2] |> between '(' ')'
    Lift _ -> "Lift _"
    Choose t1 t2 -> unwords [display t1, "<|>", display t2] |> between '(' ')'
    Fail -> "Fail"
    Trans _ t -> unwords ["Trans _", display t]
    Step t _ -> unwords [display t, ">>=", "_"] |> between '(' ')'
    Assert b -> unwords ["Assert", display b]
    Share v -> unwords ["Share", display v]
    Assign v _ -> unwords ["_", ":=", display v]

instance Display (NormalTask h a) where
  display = unnormal >> display

instance Display (Editor h a) where
  display = \case
    Enter -> "Enter"
    Update v -> unwords ["Update", display v] |> between '(' ')'
    View v -> unwords ["View", display v] |> between '(' ')'
    Watch _ -> unwords ["Watch", "_"]
    Change _ -> unwords ["Change", "_"]

instance Display Name where
  display = \case
    Unnamed -> "ε"
    Named n -> display n

---- Instances -----------------------------------------------------------------

instance Functor (Task h) where
  fmap = Trans

instance Monoidal (Task h) where
  (><) = Pair
  none = Lift ()

instance Applicative (Task h) where
  pure = Lift
  (<*>) = applyDefault

-- instance Selective (Task h) where
--   branch p t1 t2 = go =<< p
--     where
--       go (Left a) = map (<| a) t1
--       go (Right b) = map (<| b) t2

instance Alternative (Task h) where
  (<|>) = Choose
  empty = Fail

instance Monad (Task h) where
  (>>=) = Step
