module Data.Universe

%default total

public export
interface DecEq t => Universe t where
  typeOf : t -> Type