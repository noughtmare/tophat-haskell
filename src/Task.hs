module Task
  ( Task,
    Store,

    -- ** Editors
    enter,
    update,
    view,
    select,

    -- ** Shares
    share,
    watch,
    change,
    (<<-),
    (<<=),

    -- ** Derived
    parallel,
    choose,
    branch,
    pick,
    assert,

    -- *** Selections
    (>>*),
    (>**),
    (>>?),
    (<?>),

    -- *** Repeats
    forever,
    repeat,
    -- (>>@),
  )
where

import Task.Syntax (Basic, Editor (..), Label, Name (..), Store, Task (..))
import Prelude hiding (guard, repeat)

---- Builtins ------------------------------------------------------------------

assert :: Bool -> Task h Bool
assert = Assert

---- Editors

new :: Editor h t -> Task h t
new = Edit Unnamed

enter :: (Basic t) => Task h t
enter = new Enter

update :: (Basic t) => t -> Task h t
update v = new (Update v)

view :: (Basic t) => t -> Task h t
view v = new (View v)

select :: Task h a -> Assoc Label (a -> Task h t) -> Task h t
select = Select Unnamed

---- Shares

share :: (Basic a, Reflect h) => a -> Task h (Store h a)
share = Share

watch :: (Basic a) => Store h a -> Task h a
watch l = new (Watch l)

change :: (Basic a) => Store h a -> Task h a
change l = new (Change l)

infixl 1 <<-

infixl 1 <<=

(<<-) :: (Basic a) => Store h a -> a -> Task h ()
(<<-) = flip Assign

-- (<<=) :: (Members '[Read h, Write h] r) => Store h a -> (a -> a) -> Sem r ()
(<<=) :: (Basic a) => Store h a -> (a -> a) -> Task h ()
(<<=) r f = do
  x <- watch r
  r <<- f x

---- Derived -------------------------------------------------------------------

parallel :: List (Task h a) -> Task h (List a)
parallel [] = pure []
parallel (t : ts) = t >< parallel ts >>= \(x, xs) -> pure (x : xs) --XXX order of parens?

choose :: List (Task h a) -> Task h a
-- choose xs = xs .\ fail <| (<|>)
choose = foldr (<|>) fail

branch :: List (Bool, Task h a) -> Task h a
branch [] = fail
branch ((b, t) : rs) = if b then t else branch rs

---- Selections

infixl 1 >>*

infixl 1 >**

infixl 1 >>?

infixl 3 <?>

(>>*) :: Task h a -> Assoc Label (a -> Task h b) -> Task h b
(>>*) = select

(>**) :: Task h a -> Assoc Label (a -> Bool, a -> Task h b) -> Task h b
(>**) t1 cs = t1 >>* [(l, \x -> if p x then c x else fail) | (l, (p, c)) <- cs]

(>>?) :: Task h a -> (a -> Task h b) -> Task h b
(>>?) t1 e2 = t1 >>* ["Continue" ~> e2]

pick :: Assoc Label (Task h a) -> Task h a
pick ts = pure () >>* [(l, const t) | (l, t) <- ts]

(<?>) :: Task h a -> Task h a -> Task h a
(<?>) t1 t2 = pick ["Left" ~> t1, "Right" ~> t2]

---- Repeats

forever :: Task h a -> Task h Void
forever t1 = t1 >>= \_ -> forever t1

repeat :: Task h a -> Task h a
repeat t1 = select t1 ["Repeat" ~> \_ -> repeat t1, "Exit" ~> pure]

-- infixl 1 >>@

-- (>>@) :: Task h a -> (a -> Task h a) -> Task h a
-- (>>@) t1 e2 = select t1 ["Repeat" ~> \x -> e2 x >>@ e2, "Exit" ~> e2]
