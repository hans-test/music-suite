

{-# LANGUAGE
    ScopedTypeVariables,
    GeneralizedNewtypeDeriving,
    DeriveFunctor,
    DeriveFoldable,
    DeriveTraversable,
    DeriveDataTypeable,
    StandaloneDeriving,
    ConstraintKinds,
    GADTs,
    
    ViewPatterns,
    TypeFamilies,

    -- For Newtype
    MultiParamTypeClasses,
    FlexibleInstances 
    #-}

-------------------------------------------------------------------------------------
-- |
-- Copyright   : (c) Hans Hoglund 2012
--
-- License     : BSD-style
--
-- Maintainer  : hans@hanshoglund.se
-- Stability   : experimental
-- Portability : non-portable (TF,GNTD)
--
-- Provides the 'Score' type.
--
-------------------------------------------------------------------------------------

module Music.Score.Score (
        -- * Score type
        Score,

        AttributeClass(..),
        addM,
        getM,
  ) where

import Data.Dynamic
import Control.Newtype                
import Data.Maybe
import Data.Ord
import Data.Semigroup
import Data.Pointed
import Control.Arrow
import Control.Applicative
import Control.Monad
import Control.Monad.Compose

import Data.VectorSpace
import Data.AffineSpace
import Data.AffineSpace.Point
import Test.QuickCheck (Arbitrary(..), Gen(..))

import Data.Typeable
import Data.Set (Set)
import Data.Map (Map)
import Data.Foldable (Foldable)
import Data.Traversable (Traversable)
import qualified Data.Foldable as F
import qualified Data.Traversable as T
import qualified Data.List as List
import qualified Data.Set as Set
import qualified Data.Map as Map

import Music.Time
import Music.Time.Reactive
import Music.Pitch.Literal
import Music.Dynamics.Literal   
import Music.Score.Note
import Music.Score.Pitch
import Music.Score.Util

newtype Score a = Score { getScore :: (Meta, NScore a) }
    deriving (Functor, Semigroup, Monoid, Foldable, Traversable, Typeable)

type instance Container (Score a) = Score
type instance Event (Score a)     = a

instance Newtype (Score a) (Meta, NScore a) where
    pack = Score
    unpack = getScore

instance Monad Score where
    return = pack . return . return
    xs >>= f = pack $ mbind (unpack . f) (unpack xs)

instance Pointed Score where
    point = return

instance Applicative Score where
    pure = return
    (<*>) = ap

instance MonadPlus Score where
    mzero = mempty
    mplus = mappend

instance HasOnset (Score a) where
    onset (Score (m,x)) = onset x

instance HasOffset (Score a) where
    offset (Score (m,x)) = offset x

instance Delayable (Score a) where
    delay n (Score (m,x)) = Score (delay n m, delay n x)

instance Stretchable (Score a) where
    stretch n (Score (m,x)) = Score (stretch n m, stretch n x)

instance HasDuration (Score a) where
    duration = durationDefault

perform' :: Score a -> [Note a]
perform' = List.sortBy (comparing $ fst . getNote) . getNScore . snd . getScore

instance Performable (Score a) where
    perform = fmap ((\(delta -> (t,d),x) -> (t,d,x)) . getNote) . perform'
instance Composable (Score a) where

-- FIXME Reversible instance

    





type AttributeClass a = (Typeable a, Semigroup a)

-- | An existential wrapper type to hold attributes.
data Attribute :: * where
    Attribute  :: AttributeClass a => a -> Attribute
    -- TAttribute  :: (Transformable a, AttributeClass a) => a -> Attribute

-- | Wrap up an attribute.
wrapAttr :: AttributeClass a => a -> Attribute
wrapAttr = Attribute

unwrapAttr :: AttributeClass a => Attribute -> Maybe a
unwrapAttr (Attribute a)  = cast a

-- | Attributes form a semigroup, where the semigroup operation simply
--   returns the right-hand attribute when the types do not match, and
--   otherwise uses the semigroup operation specific to the (matching)
--   types.
instance Semigroup Attribute where
  (Attribute a1) <> a2 =
    case unwrapAttr a2 of
      Nothing  -> a2
      Just a2' -> Attribute (a1 <> a2')
  -- (TAttribute a1) <> a2 =
  --   case unwrapAttr a2 of
  --     Nothing  -> a2
  --     Just a2' -> TAttribute (a1 <> a2') 

instance Delayable Attribute where
  delay _ (Attribute  a) = Attribute a
  -- delay t (TAttribute a) = TAttribute (delay t a)
instance Stretchable Attribute where
  stretch _ (Attribute  a) = Attribute a
  -- stretch t (TAttribute a) = TAttribute (stretch t a)






-- TODO is Transformable right w.r.t. join?
newtype Meta = Meta (Map String (Reactive Attribute))
    deriving (Delayable, Stretchable)
inMeta f (Meta s) = Meta (f s)

-- addM :: forall a b . (AttributeClass a, Monoid a, HasMeta b) => Note a -> b -> b
addM :: forall a b . (AttributeClass a, Monoid a) => Note a -> Score b -> Score b
addM x = applyMeta $ addMeta $ noteToReact x

-- TODO more generic
getM :: forall a b . (Monoid a, AttributeClass a) => Score b -> Reactive a
getM (Score (m,_)) = getMeta m 

addMeta :: forall a . AttributeClass a => Reactive a -> Meta
addMeta a = Meta $ Map.singleton ty $ fmap wrapAttr a
    where
        ty = show $ typeOf (undefined :: a)
                                                 

getMeta :: forall a . (Monoid a, AttributeClass a) => Meta -> Reactive a
getMeta = fromMaybe mempty . getMeta'

getMeta' :: forall a . AttributeClass a => Meta -> Maybe (Reactive a) 
getMeta' (Meta s) = fmap (fmap (fromMaybe (error "getMeta'") . unwrapAttr)) $ Map.lookup ty s
-- Note: unwrapAttr should never fail
    where
        ty = show . typeOf $ (undefined :: a)

instance Semigroup Meta where
    Meta s1 <> Meta s2 = Meta $ Map.unionWith (<>) s1 s2

-- | The empty style contains no attributes; composition of styles is
--   a union of attributes; if the two styles have attributes of the
--   same type they are combined according to their semigroup
--   structure.
instance Monoid Meta where
    mempty = Meta Map.empty
    mappend = (<>)




-- | Type class for things which have a style.
class HasMeta a where
    -- | /Apply/ a style by combining it (on the left) with the
    --   existing style.
    applyMeta :: Meta -> a -> a

instance HasMeta Meta where
    applyMeta = mappend

instance HasMeta (Score a) where
    applyMeta n (Score (m,x)) = Score (applyMeta n m,x)

instance (HasMeta a, HasMeta b) => HasMeta (a,b) where
    applyMeta s = applyMeta s *** applyMeta s

instance HasMeta a => HasMeta [a] where
    applyMeta = fmap . applyMeta

instance HasMeta b => HasMeta (a -> b) where
    applyMeta = fmap . applyMeta

instance HasMeta a => HasMeta (Map k a) where
    applyMeta = fmap . applyMeta

instance (HasMeta a, Ord a) => HasMeta (Set a) where
    applyMeta = Set.map . applyMeta


-- TODO wrong Monoid for map
-- We want it to be be lifted, not left-biased

-- instance Semigroup Meta where
--     (<>) = mappend
-- instance Monoid Meta where
--     mempty = Meta mempty
--     Meta x `mappend` Meta y = Meta (x `mappend` y)
-- instance Delayable Meta where
--     delay n (Meta x) = Meta (delay n x)
-- instance Stretchable Meta where
--     stretch n (Meta x) = Meta (stretch n x)

-- TODO convert to something more friendly





-- |
-- Score without meta-events.
--
-- Semantics: a list of 'Note'. The semantics of each instances follow the instances of
-- the semantics.
-- 
newtype NScore a = NScore { getNScore :: [Note a] } -- sorted
    deriving (Functor, Foldable, Semigroup, Monoid, Traversable, Delayable, Stretchable, HasOnset, HasOffset)

instance Newtype (NScore a) [Note a] where
    pack = NScore
    unpack = getNScore

instance Monad NScore where
    return = pack . return . return
    xs >>= f = pack $ mbind (unpack . f) (unpack xs)

instance Applicative NScore where
    pure = return
    (<*>) = ap

instance MonadPlus NScore where
    mzero = mempty
    mplus = mappend


-- The following instances allow us to write expressions like [c..g]

instance IsPitch a => IsPitch (Score a) where
    fromPitch = pure . fromPitch

instance IsDynamics a => IsDynamics (Score a) where
    fromDynamics = pure . fromDynamics

instance Enum a => Enum (Score a) where
    toEnum = return . toEnum
    fromEnum = list 0 (fromEnum . head) . F.toList

-- Bogus VectorSpace instance, so we can use c^*2 etc.

instance AdditiveGroup (Score a) where
    zeroV   = error "Not impl"
    (^+^)   = error "Not impl"
    negateV = error "Not impl"

instance VectorSpace (Score a) where
    type Scalar (Score a) = Duration
    d *^ s = d `stretch` s

instance Arbitrary a => Arbitrary (Score a) where
    arbitrary = do
        x <- arbitrary
        t <- fmap realToFrac (arbitrary::Gen Double)
        d <- fmap realToFrac (arbitrary::Gen Double)
        return $ delay t $ stretch d $ return x

instance HasPitch a => HasPitch (Score a) where
    type Pitch (Score a) = Pitch a
    getPitches as    = F.foldMap getPitches as
    modifyPitch f    = fmap (modifyPitch f)

