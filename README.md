# purescript-turbine

[![Turbine on Pursuit](https://pursuit.purescript.org/packages/purescript-turbine/badge)](https://pursuit.purescript.org/packages/purescript-turbine)
[![Build status](https://travis-ci.org/funkia/purescript-turbine.svg?branch=master)](https://travis-ci.org/funkia/purescript-turbine)

A purely functional library for building user interfaces powered by FRP.

* Based on higher-order FRP with support for continuous time.
* Concise and powerful thanks to FRP.
* No big global state/model. Everything is encapsulated in components.
* Type-safe communication between views and models.
* Model logic and view code is kept separate for logic-less views.
* Highly modular and composable thanks to encapsulated stateful components.
* Avoids using virtual DOM by utilizing FRP to make all changes to the DOM in reaction to changing behaviors.
* Easy to reason about thanks to tractable reactive data flow.

## Table of contents

* [Examples](#examples)
* [Installation](#installation)
* [Tutorial](#tutorial)

## Examples

### Single counter

![single counter GIF](examples/counters/single-counter.gif)

```purescript
counterModel {increment, decrement} init = do
  let changes = (increment $> 1) <> (decrement $> -1)
  count <- scan (+) init changes
  pure { count }

counterView {count} =
  H.text "Counter " </>
  H.span (H.textB $ map show count) </>
  H.button "+" `output` (\o -> { increment: o.click }) </>
  H.button "-" `output` (\o -> { decrement: o.click })

counter = modelView counterModel counterView

main = runComponent "#mount" (counter 0)
```

### List of counters

Show a list of counters. New counters can be added to the list. Existing
counters can be deleted. The aggregated sum of all the counters is shown.

![list of counters GIF](examples/counters/list-counter.gif)

```purescript
counterModel {increment, decrement, delete} id = do
  let changes = (increment $> 1) <> (decrement $> -1)
  count <- sample $ scan (+) 0 changes
  pure { count, delete: delete $> id }

counterView {count} =
  H.div (
    H.text "Counter" </>
    H.span {} (H.textB $ map show count) </>
    H.button {} "+" `output` (\o -> {increment: o.click}) </>
    H.button {} "-" `output` (\o -> {decrement: o.click}) </>
    H.button {} "x" `output` (\o -> {delete: o.click})
  )

counter = modelView counterModel counterView

counterListModel {addCounter, listOut} init = do
  let sum = listOut >>= (map (_.count) >>> foldr (lift2 (+)) (pure 0))

  let removeId = map (fold <<< map (_.delete)) listOut
  let removeCounter = map (\i -> filter (i /= _)) (switchStream removeId)

  nextId <- sample $ scanS (+) 0 (addCounter $> 1)
  let appendCounter = cons <$> nextId

  counterIds <- sample $ scan ($) init (appendCounter <> removeCounter)
  pure {sum, counterIds}

counterListView { sum, counterIds } _ =
  H.div {} (
    H.h1 {} (H.text "Counters") </>
    H.span {} (H.textB (map (\n -> "Sum " <> show n) sum)) </>
    H.button {} (H.text "Add counter") `output` (\o -> { addCounter: o.click }) </>
    list (\id -> counter id `output` identity) counterIds identity `output` (\o -> { listOut: o })
  )

counterList = modelView counterListModel counterListView

main = runComponent "#mount" (counterList [0])
```

## Installation

The following installs Hareactive and Turbine. Hareactive is the FRP library
that Turbine builds upon and is a hard dependency.

```
npm i @funkia/hareactive
bower install --save purescript-hareactive
npm i @funkia/turbine
bower install --save purescript-turbine
```

## Tutorial

This tutorial introduces and explains the core concepts in Turbine.  Along the
way we build a few simple applications to exemplify the material.

Turbine is based on _functional reactive programming_ (FRP). It uses the FRP
library [Hareactive](#https://github.com/funkia/purescript-hareactive). It is
important to understand that Turbine is a relatively small layer on top of
Hareactive that provides abstractions for building HTML in a way that is
connected with FRP. Hareactive is a substantially larger library than Turbine.
Both in terms of implementation but, more importantly for the tutorial, also in
terms of the size of the API and of how much there is to learn. Hence, when
learning Turbine the bulk of the learning is actually to learn FRP. This
tutorial assumes no prior experience with FRP and hence it can also be seen as
a tutorial to FRP in general and Hareactive in particular.

If you want to you can follow along the tutorial yourself and potentially
experiment with the code examples. You can do so by cloning the Turbine starter
template with the following commands.

```
git clone https://github.com/funkia/purescript-turbine-starter turbine-tutorial
cd turbine-tutorial
npm i
```

After having executed the above you can run `npm run build` and afterwards you
should see the text "Hello, world!" if you open the `index.html` file in a
browser. Along the way you should make changes to the file `src/Main.purs`,
rebuild the app with `npm run build`, and then observe the changes in a
browser.

### Component

The central type in Turbine is `Component`. As a first approximation a
`Component` represents a piece of user interface. For instance, that could be
an input field or a button. More concretely a `Component` contains a
description on how to create a piece of HTML. Components are composable. Hence
an input field and a button can be composed together and the result is another
component. A component also describes any state, logic, and side-effects
associated with the component. As an example two input fields and a button can
be composed to describe the UI of a login form. The logic for the login form
and the side-effects for performing the HTTP requests for the login can be
"attached" to the view.

A Turbine application is constructed by composing components. Components
divides the app into separate chunks that can be implemented in isolation. A
Turbine application is "components all the way down".

The `Component` type has the following kind.

```
Component :: Type -> Type -> Type
```

That is, it is parameterized by two types. The purpose of these are explained
later in the tutorial.

### Creating static HTML

In this section we will explain how to create static HTML with Turbine. Turbine
contains functions for creating components that correspond to single HTML
elements. These live in the module `Turbine.HTML` which is typically import
qualified like this.

```purescript
import Turbine.HTML as H
```

For every HTML element the `Turbine.HTML` module exports a corresponding
function. Fro the HTML element `div` there is a function `div`, for the `span`
element there is a `span` function, and so on. The first argument to these
functions is a record of attributes. Furthermore, if the HTML element supports
children then the corresponding function takes a second argument as well. This
argument must be a component and describes the child for the element. Here are
a few examples.

```purescript
myInput = H.input { placeholder: "Write here", class: "form-input" }
myButton = H.button {} (H.text "Click me")
myDivWithButton = H.div { class: "div-class" } myButton
```

The `text` function used above takes a string and returns a component
corresponding to a text node of the given string.

Components are composed together with the `</>` operator. As a first
approximation `</>` is similar to the semigroup operator `<>`. But, while `<>`
has a type of the form `a -> a -> a` the type of `</>` is slightly more complex
since components keep track of more information at the type level than a
typical semigroup. Writing `component1 </> component2` creates a new component
which represents the HTML from the first component followed by the HTML for the
second component. As an example the code

```purescript
const myLoginForm =
  H.input { placeholder: "Username" } </>
  H.input { placeholder: "Password" } </>
  H.label {} (H.text "Remember login") </>
  H.checkbox {}
```

Corresponds to the following HTML.

```html
<input placeholder="Username" />
input placeholder="Password" />
<label>Remember login</label>
<input type="checkbox" />
```

If you add the code above to `Main.purs` and change the definition of `Main`
into the following.

```diff
-app = H.text "Hello, world!"
+app = myLoginForm
```

Then you should see HTML corresponding to the HTML above.


By combining `</>` with the fact that the element functions accept a child
component as their second argument we can create arbitrary HTML of any
complexity. In this tutorial we will build a simple counter application
(similar to the one [shown above](#single-counter)). To this end let us create
the HTML which we will use going forward.

```purescript
counterView = 
  H.div {} (
    H.text "Counter " </>
    H.span {} (H.text "0") </>
    H.button {} (H.text "+") </>
    H.button {} (H.text "-")
  )
```

Here we have hard coded the value `0` into the user interface. The intended
outcome is that the displayed number is dynamic and increments every time the
`+` button is pressed and decrements every time the `-` button is pressed. But,
in order to achieve that we need to learn a little bit of FRP.

### A short interlude on FRP

At its essence functional reactive programming can be seen as providing
abstractions for representing phenomenon that _depends on time_ in a purely
function way. FRP contains two key data-types `Behavior` and `Stream`:

* A `Behavior` represents a value that changes over time.
* A `Stream` represents events or occurrences that happens at specific moments
  in time.

For instance, `Behavior Number` represents a changing number and `Behavior
String` represents a changing string. On the other hand, a `Stream Number`
represents numbers associated with moments in time and `Stream String`
represents strings associated with points in time.

> Note: What we call `Stream` is often called `Event` in other FRP libraries.

The difference between behaviors and streams can be illustrated as below.

![illustration of behavior and stream](resources/behaviorstream.svg)

As the image indicates a behavior can be seen a function from time. That is, at
any specific moment in time it has a value. A stream on the other hand only has
values, or occurrences, at specific punctuations in time.

Initially the distinction between a behavior and a stream may be unclear.
Fortunately, when one becomes familiar with the two abstractions the choice of
which one to use becomes unambiguous. A simple heuristic to determine whether a
particular thing should be represented as a behavior or as a stream is to ask
the question "does this thing has a notion of a current value". If yes, then it
is a behavior, if no, then it is a stream. Turbine uses behaviors and streams
to represent any dynamic UI value using FRP. Here are a few examples.

* The value of an input field is represented as a `Behavior String`. Because
  the input field always has a "current value" its value is represented as a
  behavior.
* The clicking of a button is represented as a `Stream ClickEvent`. A click of
  the button is an event that happens at specific discrete moment in time,
  hence a stream is used.
* Whether or not a checkbox is checked is represented as a `Behavior Boolean`.

### Dynamic HTML

In the counter component above we hard coded the value `0` into the view. The
goal is that the displayed number should _change over time_. And, as mentioned,
in FRP we use behaviors to represent values that changes over time. Thus, we
parameterize the HTML above such that it takes as argument a record of a
behavior of the type `Behavior Number`.

```purescript
counterView { count :: Behavior String } -> Component _ _
counterView { count } = 
  H.div {} (
    H.text "Counter " </>
    H.span {} (H.textB (map show count)) </>
    H.button {} (H.text "+") </>
    H.button {} (H.text "-")
  )
```

We also changed `H.text "0"` into `H.textB (map show count)`. The `textB`
function is similar to `text` except that instead of taking an argument of type
`String` it takes an argument of type `Behavior String.` It then returns a
component that describes _dynamic HTML_. The value of the text node will be
kept up to date with the value of the behavior.

We have now modified the view such that it takes as _input_ a dynamic count
which it displays in the UI. Next we much declare the views _output_ such that
the clicks of the two buttons.

### Output

Recall that the `Component` type is parameterized by two types. Both of these
are, by convention, almost always records. The first of them is called the
components _selected output_ and the second is called the components _available
output_. If you are familiar with `addEventListener` in the DOM API then, as an
analogy, the available output can be thought of the events that we _could_
listen to by calling `addEventListener` with the event name. The selected
output, on the other hand, is the output that we have explicitly declared that
we are interested in.

When a component is initially created its selected output is usually `{}`. This
matches the intuition that a newly constructed component has not had any of it
available output selected yet. The available output on the other hand will be a
record of all the various streams, behaviors, and other things that the
component produces.

As an example consider this slightly simplified type of the `button` function.

```purescript
button :: { | a } -> Component {} { click :: Stream ClickEvent
                                    dbclick :: Stream ClickEvent
                                    -- ... and so on
                                  }
```

This type tells us that when given a record of attributes the `button` function
returns a component with available output as declared by the last object. It
includes, among other things, a field of type `click :: Stream ClickEvent`.
This stream has an occurrence whenever the button is pressed.

As another example consider the type of the `input` function.

```purescript
input :: { | a } -> Component {} { value :: Behavior String
                                 , blur :: Stream FocusEvent
                                 , keydown :: Stream KeyboardEvent
                                 , keyup :: Stream KeyboardEvent
                                 -- ... and so on
                                 }
```

From this we see that a component constructed by the `input` function has among
its available output a field of type `value :: Behavior String`. This behavior
describes the current value of the input field.

Available output can be selected by using the
[`output`](https://pursuit.purescript.org/packages/purescript-turbine/0.0.4/docs/Turbine#v:output)
function. Its type is as follows.

```purescript
output :: forall a o p q. Union o p q => Component { | o } a -> (a -> { | p }) -> Component { | q } a
```

Let us unpack the type piece for piece. The `output` function takes as
arguments a component and a function. The type variable `a` is the components
available output. The function takes the available output, the `a`, and returns
a record of `p`. The given components selected output is the type variable `o`.
Per the constraint `Union o p q` the type variable `q` becomes the union of `o`
and `p`. The returned component has the type `Component { | q } a`. In other
words the given function receives the components available output, returns a
record and this record is then merged into the returned components selected
output. The end result is that `output` moves output from the available part
into the selected part.

The `output` function is often used infix as in the following example.

```purescript
usernameField = H.input {} `output` (\o -> { username: o.value })
```

In the above code we are selecting the `value` behavior that the component
created by `input` outputs. By returning a record with a field named `username`
we are in a sense moving the behavior from the available output into the
selected output and renaming it at the same time. As defined above
`usernameField` has the type `Component { username :: Behavior String } { ...
}`.

As the piece in the puzzle to understand how output works we must now
consider the type of the `</>` operator which is an alias for the
[output](https://pursuit.purescript.org/packages/purescript-turbine/0.0.4/docs/Turbine#v:merge)
function.

```purescript
merge :: forall a o b p q. Union o p q => Component { | o } a -> Component { | p } b -> Component { | q } { | q }
```

Due to the `Union o p q` constraint `merge` takes two components and returns a
new component that is their combination. This combination has as its selected
output the union of the two components selected output.

Let us return to the example with the login form from earlier and consider how
we might get output from the view and how the types interact.

```purescript
const myLoginForm =
  H.input { placeholder: "Username" } `output` (\o -> { username: o.value }) </>
  H.input { placeholder: "Password" } `output` (\o -> { password: o.value }) </>
  H.label {} (H.text "Remember login") </>
  H.checkbox {} `output` (\o -> { rememberLogin: o.checked })
```

Each invocation of `output` selects some output and each invocation of `</>`
merges these in the combined components. The end result is that `myLoginForm`
has the type.

```purescript
myLoginForm :: Component { username :: Behavior String
                         , password :: Behavior String
                         , rememberLogin :: Stream Boolean
                         }
                         { ... }
```

### Model view

The
[`modelView`](https://pursuit.purescript.org/packages/purescript-turbine/0.0.4/docs/Turbine#v:modelView)
function is a key part of Turbine. It is the primary way to create custom
components with custom logic. It takes a _model_ and a _view_. The model is a
function that returns a computation in the
[Now](https://pursuit.purescript.org/packages/purescript-hareactive/0.0.9/docs/Hareactive.Types#t:Now)
monad. The view is a function that returns a component.

```purescript
modelView :: forall o p a x. (o -> x -> Now p) -> (p -> x -> Component o a) -> (x -> Component { } p)
```
