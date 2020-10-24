module Data.Functor.Rep.Lens where


-- $dataFunctorRepLens
-- Provides access to the definition in "Data.Functor.Rep" in terms of "Control.Lens".

-- |
-- Index a representable functor.
--
-- This is an infix alias for 'index'.
--
-- (!) :: Representable f => f a -> Rep f -> a
-- (!) = index

-- infixl 6 !

{-
-- |
-- The isomorpism between a representable functor and its representation.
--
-- @
-- 'tabulated' = 'iso' 'tabulate' 'index'
-- @
--
tabulated :: (Representable f, Representable g) => Iso (Rep f -> a) (Rep g -> b) (f a) (g b)
tabulated = iso tabulate index
-}
