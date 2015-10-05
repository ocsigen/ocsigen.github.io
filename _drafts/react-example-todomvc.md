---
title: 'TodoMVC: a reactive version'
layout: default
author: Stéphane Legrand
---

[TodoMVC](http://todomvc.com/) is a project which offers the same Todo
application implemented using [MV*][mvc] concepts in most of the
popular JavaScript MV* frameworks. One of the aims of TodoMVC is to
enable a fair comparison between several frameworks, by providing
implementations of the same application. A [js_of_ocaml (JSOO)][jsoo]
version is now available:

- [Source code][source]
- [Demo][demo]

Our version is powered by the [`React`][react] module for [functional
reactive programming (FRP)][frp].

In this post, we outline the architecture of our implementation, with
a particular emphasis on how it applies MVC and FRP concepts.

## MVC

[MVC][mvc], which stands for *Model-View-Controller*, is a software
architecture very commonly used for implementing user interfaces. MVC
divides an application into three components:

- the *Model* manages the data, logic and rules of the application;

- the *Controller* manages events from the view and accordingly updates
  the model;

- the *View* generates an output presentation (a web page for
  instance) based on the model data.

For the Todo application, we have three corresponding OCaml
modules. [`Model`][modelsrc] mainly contains the task list and the new
task field value. It uses [`Deriving_Json`][derivingjson] to convert
the data to JSON and vice versa, in order to be able to save/restore
the application state. This module is otherwise written with basic
OCaml code. [`Controller`][controllersrc] produces new models
according to the actions it receives. Whenever a new model is built,
the model becomes the new reactive signal value. We will elaborate on
this point later. [`View`][viewsrc] builds the HTML to display the
page. It receives as input the dynamic data from the model. The HTML
also contains the event management code needed to emit the
corresponding actions.

Besides these three MVC modules, the application uses three
helpers. [`Storage`][storagesrc]
contains the functions to read and write a string value in the browser
local storage. This module is used to save and restore the application
data in JSON
format. [`Action`][actionsrc]
contains all the actions available from the user
interface. [`ReactList`][reactlistsrc]
contains a single function to ease the creation of a reactive list via
the [`ReactiveData` library][reactivedata].

## React

[React][react] is an OCaml module for [functional reactive programming
(FRP)][frp]. In our TodoMVC example, `React` provides a way to
automatically refresh the view whenever a new model is built by the
controller. To achieve this goal, the application uses a reactive
signal which carries the model values (which vary over time). The
model value may initially be equal to the [empty model][empty]. When
this value is modified by the controller, *i.e.,* after a new model
has been generated, the view automatically refreshes its reactive
parts.

## Mixing MVC and FRP

The following figure shows what happens when the user interacts with
the application, *e.g.,* by adding a new task, or by clicking on a
checkbox to select a specific task:

![MVC with `React`](/img/posts/2015/react-example-todomvc-steps.png)

1. the view sends the action to the controller;

2. the controller gets the current model from the reactive signal, and
   builds a new model accordingly to the action;

3. the controller sets this new model as the new reactive signal
   value;

4. the view reacts to the newly-available model (new signal value) and
   updates itself with the corresponding data.

We proceed to describe our implementation of the above scheme, with an
emphasis on the reactive features.

### Initialization

The [main function][main] creates the reactive signal with an initial
(possibly empty) model. The `m` value is of type `Model.t`:

{% highlight ocaml %}
let rp = React.S.create m in
{% endhighlight %}

`React.S.create` returns a tuple, the first part of which is a
primitive signal; the second part is a function used by the controller
[to set a new model as the new signal value][signalval].

### Reactive attribute

We first explain how the CSS style of a HTML node [becomes
reactive][reactattr]. In the Todo application, the task list is
displayed in a `<section>` HTML tag. The CSS style of this HTML node
must contain `visibility: hidden;` if the tasks list is empty, and
`visibility: visible;` otherwise (*i.e.,* if the number of tasks is
greater than zero). The style attribute of this `<section>` node must
therefore change according to the model content:

{% highlight ocaml %}
R.Html5.a_style (React.S.map css_visibility r)
{% endhighlight %}

We use the [`Tyxml_js`][tyxmljs] module to safely build the HTML
code. The first thing to note is that we use the reactive `R.Html5`
submodule, not the plain `Html5` submodule. The `a_style` function
implements a reactive attribute; it expects a reactive signal as its
argument. Here we use `React.S.map`, which has the signature `('a ->
'b) -> 'a React.signal -> 'b React.signal`. The first argument to
`map` is the `css_visibility` function:

{% highlight ocaml %}
let css_visibility m =
  let tasks = m.Model.tasks in
  match tasks with
  | [] -> "visibility: hidden;"
  | _ -> "visibility: visible;"
{% endhighlight %}

As you can see, `css_visibility` receives a model `m` as its
argument. When wrapped by `React.S.map` as above, `css_visibility`
operates on signals. The function returns the right style, depending
on whether the list of tasks is empty or not.

The second argument to `React.S.map` is the value named `r`, which is
the primitive signal. `r` is the first value returned by the
`React.S.create` function.

Each time the signal value gets updated by the controller, the
`css_visibility` function is automatically called with the new signal
value (a new model) as its argument, and the style attribute is
automatically modified.

### Reactive list

Reactive attributes alone would not suffice to build a user
interface. We also need a reactive list of child nodes. Such a list is
for example needed to display the task list. ([The source code section
is the same as for the first
example.](https://github.com/slegrand45/examples_ocsigen/blob/d6766d404a449d0b1d36ad3cd916b0c444390a19/jsoo/todomvc-react/todomvc.ml#L267-L299)) It
is a list of `<li>` nodes contained in a `<ul>` node. We accordingly
have a reactive node, as follows:

{% highlight ocaml %}
R.Html5.ul ~a:[a_class ["todo-list"]] rl
{% endhighlight %}

As before, we use the `R.Html5` module. This time we do not use
`R.Html5` to build an attribute, but rather a (`<ul>`) node. `rl`
contains the node's children:

{% highlight ocaml %}
let rl = ReactList.list (React.S.map visible_tasks r)
{% endhighlight %}

We create the reactive list via the helper module
[ReactList][reactlistsrc]. As for the previous example, we use
`React.S.map` to build a reactive signal, `r` being again the
primitive signal. The `visible_task` function generates the `<li>`
elements from the task list, filtered by the current selected
visibility:

{% highlight ocaml %}
let visible_tasks m =
  let visibility = m.Model.visibility in
  let is_visible todo =
    match visibility with
    | Model.Completed -> todo.Model.completed
    | Active -> not todo.completed
    | All -> true
  in
  let tasks = List.filter is_visible m.Model.tasks in
  List.rev (List.fold_left (todo_item (r, f)) [] tasks)
{% endhighlight %}

Following the same principle as for the reactive attribute, each time
the signal value gets updated by the controller, the `<li>` nodes are
automatically refreshed.

### Signal typing

You may have noticed that the code [includes the following
types](https://github.com/slegrand45/examples_ocsigen/blob/d6766d404a449d0b1d36ad3cd916b0c444390a19/jsoo/todomvc-react/todomvc.ml#L89-L91):

{% highlight ocaml %}
type rs = Model.t React.signal
type rf = ?step:React.step -> Model.t -> unit
type rp = rs * rf
{% endhighlight %}

These types are used whenever type annotations are required, *e.g.,*
for the `update` function from the `Controller` module:

{% highlight ocaml %}
let update a ((r, f) : rp) = (* ... *)
{% endhighlight %}

## Comparison with Elm implementation

[Elm](http://elm-lang.org/) is a functional programming language
dedicated to frontend web application development. Elm was designed by
Evan Czaplicki. The language should feel familiar to OCaml
programmers.

Our TodoMVC example is based on the [Elm
implementation](https://github.com/evancz/elm-todomvc), which follows
the structure used in [all Elm
programs](https://github.com/evancz/elm-architecture-tutorial/): a
model, an update function, and a view. Like Elm, our example uses the
functional reactive programming style, enabled in our case by the
React library and the reactive modules `Tyxml_js.R` and
`ReactiveData`.

## Conclusion

The combination of OCaml, js_of_ocaml, and Functional Reactive
Programming provides a killer feature combination for building rich
web clients. OCaml static typing associated with compile-time HTML
validity checking thanks to Tyxml also increase reliability.

[mvc]: https://en.wikipedia.org/wiki/Model-view-controller
[jsoo]: http://ocsigen.org/js_of_ocaml/
[react]: http://erratique.ch/software/react
[tyxmljs]: https://ocsigen.org/js_of_ocaml/api/Tyxml_js
[source]: https://github.com/slegrand45/examples_ocsigen/tree/master/jsoo/todomvc-react
[demo]: http://slegrand45.github.io/examples_ocsigen.site/jsoo/todomvc-react/
[modelsrc]: https://github.com/slegrand45/examples_ocsigen/blob/d6766d404a449d0b1d36ad3cd916b0c444390a19/jsoo/todomvc-react/todomvc.ml#L38
[controllersrc]: https://github.com/slegrand45/examples_ocsigen/blob/d6766d404a449d0b1d36ad3cd916b0c444390a19/jsoo/todomvc-react/todomvc.ml#L111
[viewsrc]: https://github.com/slegrand45/examples_ocsigen/blob/d6766d404a449d0b1d36ad3cd916b0c444390a19/jsoo/todomvc-react/todomvc.ml#L175
[storagesrc]: https://github.com/slegrand45/examples_ocsigen/blob/d6766d404a449d0b1d36ad3cd916b0c444390a19/jsoo/todomvc-react/todomvc.ml#L14
[actionsrc]: https://github.com/slegrand45/examples_ocsigen/blob/d6766d404a449d0b1d36ad3cd916b0c444390a19/jsoo/todomvc-react/todomvc.ml#L94
[reactattr]: https://github.com/slegrand45/examples_ocsigen/blob/d6766d404a449d0b1d36ad3cd916b0c444390a19/jsoo/todomvc-react/todomvc.ml#L267-L299
[reactlistsrc]: https://github.com/slegrand45/examples_ocsigen/blob/d6766d404a449d0b1d36ad3cd916b0c444390a19/jsoo/todomvc-react/todomvc.ml#L3
[reactivedata]: https://github.com/hhugo/reactiveData
[frp]: https://en.wikipedia.org/wiki/Functional_reactive_programming
[empty]: https://github.com/slegrand45/examples_ocsigen/blob/d6766d404a449d0b1d36ad3cd916b0c444390a19/jsoo/todomvc-react/todomvc.ml#L60-L65
[main]: https://github.com/slegrand45/examples_ocsigen/blob/d6766d404a449d0b1d36ad3cd916b0c444390a19/jsoo/todomvc-react/todomvc.ml#L393
[signalval]: https://github.com/slegrand45/examples_ocsigen/blob/d6766d404a449d0b1d36ad3cd916b0c444390a19/jsoo/todomvc-react/todomvc.ml#L170
[derivingjson]: https://ocsigen.org/js_of_ocaml/api/Deriving_Json
