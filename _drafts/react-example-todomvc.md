---
title: TodoMVC example, a React version
layout: default
author: Stéphane Legrand
---

[TodoMVC](http://todomvc.com/) is a project which offers the same Todo application implemented using MV* concepts in most of the popular JavaScript MV* frameworks. One of the aim of this project is to give a possibility to make a fair comparison between several frameworks by coding the same application. A js_of_ocaml version using the React module is now available. Check out the [source code](https://github.com/slegrand45/examples_ocsigen/tree/master/jsoo/todomvc-react) and the [demo](http://slegrand45.github.io/examples_ocsigen.site/jsoo/todomvc-react/). Comments and pull requests are welcome!

#### MVC

[MVC](https://en.wikipedia.org/wiki/Model-view-controller) stands for Model-View-Controller. It's a commonly used software architecture for implementing user interfaces. The application is divided in three components:

- the Model manages the data, logic and rules of the application ;
- the Controller manages events from the view and accordingly updates the model ;
- the View generates an output presentation (a web page for instance) based on the model data.

For the Todo application, we have three corresponding modules. [Model](https://github.com/slegrand45/examples_ocsigen/blob/d6766d404a449d0b1d36ad3cd916b0c444390a19/jsoo/todomvc-react/todomvc.ml#L38) contains mainly the tasks list and the new task field value. It uses the deriving feature of jsoo to convert the data to json and vice versa in order to be able to save/restore the application state. Otherwise this module is written with basic OCaml code. [Controller](https://github.com/slegrand45/examples_ocsigen/blob/d6766d404a449d0b1d36ad3cd916b0c444390a19/jsoo/todomvc-react/todomvc.ml#L111) produces new models according to the actions it receives. Whenever a new model is built, the module also sets it as the new reactive signal value, we will detail this point later. [View](https://github.com/slegrand45/examples_ocsigen/blob/d6766d404a449d0b1d36ad3cd916b0c444390a19/jsoo/todomvc-react/todomvc.ml#L175) builds the HTML to display the page, it takes the dynamic data from the model. The HTML contains also the events management code needed to emit the corresponding actions.

Besides these three MVC modules, the application uses also two helpers. [Storage](https://github.com/slegrand45/examples_ocsigen/blob/d6766d404a449d0b1d36ad3cd916b0c444390a19/jsoo/todomvc-react/todomvc.ml#L14) contains the functions to read/write a string value in the browser local storage. This module is used to save/restore the application data in json format. [Action](https://github.com/slegrand45/examples_ocsigen/blob/d6766d404a449d0b1d36ad3cd916b0c444390a19/jsoo/todomvc-react/todomvc.ml#L94) contains all the actions available for the user interface.

#### React

[React](http://erratique.ch/software/react) is an OCaml module for [functional reactive programming](https://en.wikipedia.org/wiki/Functional_reactive_programming) (FRP). In this TodoMVC example, React is used to automatically refresh the view whenever a new model is built by the controller. 

#### Mixing the two

The following figure shows what happens when the user interacts with the application:

![MVC with React](/img/posts/2015/react-example-todomvc-steps.png)

1. the view sends the action to the controller ;
2. the controller gets the current model and build a new one accordingly to the action ;
3. the controller sets this new model as the new reactive signal value ;
4. the view detects that a new model is available (the view reacts to the new signal value) and updates itself with the new model data.

Let's now see how this is implemented. Please note that i will only detail the reactive features.

### Initialization

The [main function](https://github.com/slegrand45/examples_ocsigen/blob/d6766d404a449d0b1d36ad3cd916b0c444390a19/jsoo/todomvc-react/todomvc.ml#L393) creates the reactive signal with an initial model (possibly empty). The `m` value is of type `Model.t`:

{% highlight ocaml %}
let rp = React.S.create m in
{% endhighlight %}

React.S.create returns a tuple. The first value is a primitive signal. The second value is a function which will be used later by the controller [to set a new model as the new signal value](https://github.com/slegrand45/examples_ocsigen/blob/d6766d404a449d0b1d36ad3cd916b0c444390a19/jsoo/todomvc-react/todomvc.ml#L170).

### Reactive attribute

This first example explains how the CSS style of a HTML node becomes reactive ([source code](https://github.com/slegrand45/examples_ocsigen/blob/d6766d404a449d0b1d36ad3cd916b0c444390a19/jsoo/todomvc-react/todomvc.ml#L267-L299)). In the Todo application, the tasks list is displayed in a `<section>` HTML tag. The CSS style of this HTML node must contain `visibility: hidden;` if the tasks list is empty. But must contain `visibility: visible;` if the number of tasks is greater than zero. So the style attribute of this `<section>` node must change regarding the model content:

{% highlight ocaml %}
R.Html5.a_style (React.S.map css_visibility r)
{% endhighlight %}

The first thing to note is that we use the Tyxml_js.R.Html5 module instead of the Tyxml_js.Html5 one. Tyxml_js.R.Html5 is simply the Reactive counterpart of Tyxml_js.Html5. As it's a reactive attribute, the a_style function waits a reactive signal as its argument. Here we use React.S.map which have the signature `('a -> 'b) -> 'a React.signal -> 'b React.signal`. This map function takes as its first argument a function named css_visibility:

{% highlight ocaml %}
let css_visibility m =
      let tasks = m.Model.tasks in
      match tasks with
      | [] -> "visibility: hidden;"
      | _ -> "visibility: visible;"
{% endhighlight %}

As you can see, this function takes a model `m` as its argument. In fact, thanks to React.S.map, it takes the signal value as its argument. And then the function returns the right style regarding if the tasks list is empty or not.

The second argument to React.S.map is the value named `r`. Remember when we created the reactive signal with React.S.create? This `r` is simply the first returned value, the primitive signal.

So each time the signal value will be updated by the controller, the css_visibility function will be automatically called with the new signal value (a new model) as its argument and the style attribute will be automatically modified.

### Reactive list

TODO

### Signal typing

TODO

{% highlight ocaml %}
type rs = Model.t React.signal
type rf = ?step:React.step -> Model.t -> unit
type rp = rs * rf
{% endhighlight %}
