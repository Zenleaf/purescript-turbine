module Turbine
  ( Component
  , runComponent
  , modelView
  , merge
  , (</>)
  , dynamic
  , output
  , list
  , class MapRecord
  , mapRecordBuilder
  , static
  ) where

import Prelude

import Control.Apply (lift2)
import Data.Function.Uncurried (Fn2, runFn2, mkFn2, Fn3, runFn3)
import Data.Symbol (class IsSymbol, SProxy(SProxy))
import Effect (Effect)
import Effect.Uncurried (EffectFn2, runEffectFn2)
import Hareactive (Behavior, Now)
import Prim.Row (class Union)
import Prim.Row as Row
import Prim.RowList as RL
import Record as R
import Record.Builder (Builder)
import Record.Builder as Builder
import Type.Data.RowList (RLProxy(RLProxy))

foreign import data Component :: Type -> Type -> Type

-- Component instances

instance semigroupComponent :: Semigroup a => Semigroup (Component o a) where
  append = lift2 append

instance functorComponent :: Functor (Component o) where
  map = runFn2 _map

foreign import _map :: forall o a b. Fn2 (a -> b) (Component o a) (Component o b)

instance applyComponent :: Apply (Component o) where
  apply = runFn2 _apply

foreign import _apply :: forall o a b. Fn2 (Component o (a -> b)) (Component o a) (Component o b)

instance bindComponent :: Bind (Component o) where
  bind = runFn2 _bind

foreign import _bind :: forall o a b. Fn2 (Component o a) (a -> Component o b) (Component o b)

modelView :: forall o p a x. (o -> x -> Now p) -> (p -> Component o a) -> (x -> Component {} p)
modelView m v = runFn2 _modelView (mkFn2 m) v

foreign import _modelView :: forall o p a x. Fn2 (Fn2 o x (Now p)) (p -> Component o a) (x -> Component {} p)

runComponent :: forall o a. String -> Component o a -> Effect Unit
runComponent = runEffectFn2 _runComponent

foreign import _runComponent :: forall o a. EffectFn2 String (Component o a) Unit

-- | Turns a behavior of a component into a component of a behavior.
-- | This function is used to create dynamic HTML where the structure of the HTML should change over time.
foreign import dynamic :: forall o a. Behavior (Component o a) -> Component {} (Behavior a)

list :: forall a o p.
  (a -> Component o p) -> Behavior (Array a) -> (a -> Int) -> Component {} (Behavior (Array o))
list = runFn3 _list

foreign import _list :: forall a o p.
  Fn3 (a -> Component o p) (Behavior (Array a)) (a -> Int) (Component {} (Behavior (Array o)))

merge :: forall a o b p q. Union o p q => Component { | o } a -> Component { | p } b -> Component { | q } { | q }
merge = runFn2 _merge

foreign import _merge :: forall a o b p q. Union o p q => Fn2 (Component { | o } a) (Component { | p } b) (Component { | q } { | q })
infixl 0 merge as </>

output :: forall a o p q. Union o p q => Component { | o } a -> (a -> { | p }) -> Component { | q } a
output = runFn2 _output

foreign import _output :: forall a o p q. Union o p q => Fn2 (Component { | o } a) (a -> { | p }) (Component { | q } a)

foreign import loop :: forall a o. (a -> Component o a) -> Component o a

mapHeterogenousRecord :: forall row xs f row'
   . RL.RowToList row xs
  => MapRecord xs row f () row'
  => (forall a. a -> f a)
  -> Record row
  -> Record row'
mapHeterogenousRecord f r = Builder.build builder {}
  where
    builder = mapRecordBuilder (RLProxy :: RLProxy xs) f r

class MapRecord (xs :: RL.RowList) (row :: # Type) f (from :: # Type) (to :: # Type)
  | xs -> row f from to where
  mapRecordBuilder :: RLProxy xs -> (forall a. a -> f a) -> Record row -> Builder { | from } { | to }

instance mapRecordCons ::
  ( IsSymbol name
  , Row.Cons name a trash row
  , MapRecord tail row f from from'
  , Row.Lacks name from'
  , Row.Cons name (f a) from' to
  ) => MapRecord (RL.Cons name a tail) row f from to where
  mapRecordBuilder _ f r =
    first <<< rest
    where
      nameP = SProxy :: SProxy name
      val = f $ R.get nameP r
      rest = mapRecordBuilder (RLProxy :: RLProxy tail) f r
      first = Builder.insert nameP val

instance mapRecordNil :: MapRecord RL.Nil row f () () where
  mapRecordBuilder _ _ _ = identity

static :: forall a c row. RL.RowToList row c => MapRecord c row Behavior () a => { | row } -> { | a }
static = mapHeterogenousRecord pure

withStatic :: forall o p q q' p' xs
   . RL.RowToList p xs
  => MapRecord xs p Behavior () p'
  => Union o p' q'
  => Row.Nub q' q
  => { | o } -> { | p } -> { | q }
withStatic a b = R.merge a (static b)
