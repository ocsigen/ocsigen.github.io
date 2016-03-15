---
title: Ocsigen&#58; step by step tutorial for client-server Web application (1/2)
layout: default
author: Vincent Balat
authorurl: http://ocsigen.org
---

This post (and the following one) is a step by step tutorial about
client-server Web applications in OCaml. You can find the full
tutorial [here](http://ocsigen.org/tuto/manual/application). It
introduces the basics of Web programming with OCaml: type-checking
HTML, defining services, using lightweight threads, writing a
client-server program ...

We will write a collaborative drawing application. It is a
client-server Web application displaying an area where users can draw
using the mouse, and see what other users are drawing at the same time
and in real-time.

The final eliom code is available for download
[on github](https://github.com/ocsigen/graffiti/tree/master/simple).
[Git tag eliom-5.0](https://github.com/ocsigen/graffiti/releases/tag/eliom-5.0)
has been tested against Eliom 5.0.

The application is running online
[here](https://github.com/ocsigen/graffiti/releases/tag/eliom-5.0).

## Basics

To get started, we recommend using Eliom's distillery, a program which
creates scaffolds for Eliom projects. The following command creates a
very simple project called graffiti in the directory graffiti:

```
$ eliom-distillery -name graffiti -template basic.ppx -target-directory graffiti
```

## My first page

**(Services, Configuration file, Static validation of HTML)**

Our web application consists of a single page for now. Let's start by
creating a very basic page. We define the service that will implement
this page by the following declaration:

{% highlight ocaml %}
open Eliom_content.Html5.D (* provides functions to create HTML nodes *)

let main_service =
  Eliom_registration.Html5.register_service
    ~path:["graff"]
    ~get_params:Eliom_parameter.unit
    (fun () () ->
      Lwt.return
        (html
           (head (title (pcdata "Page title")) [])
           (body [h1 [pcdata "Graffiti"]])))
{% endhighlight %}

If you are using eliom-distillery just replace the content of the
eliom-file by the above lines and run

```
$ make test.byte
```

This will compile your application and run ocsigenserver on it. (Refer
to the manual on how to compile your project "by hand".)

Your page is now available at URL `http://localhost:8080/graff`.

### Services

Unlike typical web programming techniques (CGI, PHP, ...), with Eliom you do not need to write one file per URL. The application can be split into multiple files as per the developer's style. What matters is that you eventually produce a single module (*.cmo or *.cma) for the whole website.

Module
[Eliom_service](http://ocsigen.org/eliom/5.0/api/client/Eliom_service)
allows to create new entry points to your web site, called services.
In general, services are attached to a URL and generate a web page.
Services are represented by OCaml values, through which you must
register a function that will generate a page.

Parameter `~path` corresponds to the URL where you want to attach your service. It is a list of strings. The value `["foo"; "bar"]` corresponds to URL `foo/bar`. `["dir"; ""]` corresponds to URL `dir/` (that is: the default page of the directory dir).

### Configuration file

In the directory of the project created by the Eliom-distillery, you can find the file `graffiti.conf.in`. This file is used in conjunction with the variables in Makefile.options to generate the ocsigenserver configuration file.

Once you start up your application via `make test.byte`, the configuration file becomes available at `local/etc/graffiti/graffiti-test.conf`. It contains various directives for Ocsigen server (port, log files, extensions to be loaded, etc.), taken from Makefile.options, and something like:

```
<host>
  <static dir="static" />
  <eliommodule module="/path_to/graffiti.cma" />
  <eliom />
</host>
```

Line `<eliommodule ... />` asks the server to load Eliom module
`graffiti.cma`, containing the Eliom application, at startup and
attach it to this host (and site).

Extensions `<static ... />` (staticmod) and `<eliom />` are called successively:

- If they exist, files from the directory `/path_to/graffiti/static`
will be served,
- Otherwise, Server will try to generate pages with Eliom (`<eliom />`),
- Otherwise it will generate a 404 (Not found) error (default).

### Static validation of HTML

There are several ways to create pages for Eliom. You can generate
pages as strings (as in other web frameworks). However, it is
preferable to generate HTML in a way that provides compile-time HTML
correctness guarantees. This tutorial achieves this by using
module [Eliom_content.​Html5.​D](http://ocsigen.org/eliom/5.0/api/client/Eliom_content.Html5.D), which is implemented using the TyXML
library. The module defines a construction function for each HTML5
tag.

Note that it is also possible to use the usual HTML syntax directly in OCaml.

The TyXML library (and thus [Eliom_content.​Html5.​D](http://ocsigen.org/eliom/5.0/api/client/Eliom_content.Html5.D)) is very strict and compels you to respect HTML5 standard (with some limitations). For example if you write:

{% highlight ocaml %}
(html
   (head (title (pcdata "")) [pcdata ""])
   (body [pcdata "Hallo"]))
{% endhighlight %}

You will get an error message similar to the following, referring to the end of line 2:

```
Error: This expression has type ([> `PCDATA ] as 'a) Html5.elt
       but an expression was expected of type
         Html5_types.head_content_fun Html5.elt
       Type 'a is not compatible with type Html5_types.head_content_fun =
           [ `Base
           | `Command
           | `Link
           | `Meta
           | `Noscript of [ `Link | `Meta | `Style ]
           | `Script
           | `Style ]
       The second variant type does not allow tag(s) `PCDATA
```

where `Html5_types.​head_content_fun` is the type of content allowed inside `<head>` (`<base>`, `<command>`, `<link>`, `<meta>`, etc.). Notice that `\`PCDATA` (i.e. raw text) is not included in this polymorphic variant type.

Most functions take as parameter the list representing its contents. See other examples below. Each of them take un optional `?a` parameter for optional HTML attributes. Mandatory HTML attributes correspond to mandatory OCaml parameters. See below for examples.


### Lwt

Important warning: All the functions you write must be written in a cooperative manner using Lwt. Lwt is a convenient way to implement concurrent programs in OCaml, and is now also widely used for applications unrelated to Ocsigen.

For now we will just use the `Lwt.return` function as above. We will come back to Lwt programming later. You can also have a look at the Lwt programming guide.


## Execute parts of the program on the client

**(Service sending an application,
Client and server code, Compiling a web application with server and client parts, Calling JavaScript methods with Js_of_ocaml)**

To create our first service, we used the function [Eliom_registration.​Html5.​register_service](http://ocsigen.org/eliom/5.0/api/client/Eliom_registration.Html5#VALregister_service), as all we wanted to do was return HTML5. But we actually want a service that corresponds to a full Eliom application with client and server parts. To do so, we need to create our own registration module by using the functor Eliom_registration.App:

{% highlight ocaml %}
module Graffiti_app =
  Eliom_registration.App (struct
      let application_name = "graffiti"
    end)
{% endhighlight %}

It is now possible to use `My_app` for registering our main service
(now at URL `/`):

{% highlight ocaml %}
let main_service =
  Graffiti_app.register_service
    ~path:[""]
    ~get_params:Eliom_parameter.unit
    (fun () () ->
      Lwt.return
        (html
           (head (title (pcdata "Graffiti")) [])
           (body [h1 [pcdata "Graffiti"]]) ) )
{% endhighlight %}

We can now add some OCaml code to be executed by the browser. For this purpose, Eliom provides a syntax extension to distinguish between server and client code in the same file. We start by a very basic program, that will display a message to the user by calling the JavaScript function alert. Add the following lines to the program:

{% highlight ocaml %}
let%client _ = Eliom_lib.alert "Hello!"
{% endhighlight %}

After running again make test.byte, and visiting `http://localhost:8080/`, the browser will load the file `graffiti.js`, and open an alert-box.

### Splitting the code into server and client parts

At the very toplevel of your source file (i.e. not inside modules or other server- /client-parts), you can use the following constructs to indicate which side the code should run on.

- `[%%client ... ]` : the list of enclosed definitions is client-only code (similarly for `[%%server ... ]`). With `[%%shared ... ]`, the code is used both on the server and client.
- `let%client`, `let%server`, `let%shared`: same as above for a single definition.
- `[%%client.start]`, `[%%server.start]`, `[%%shared.start]`: these set the default location for all definitions that follow, and which do not use the preceding constructs.

If no location is specified, the code is assumed to be for the server.

The above constructs are implemented by means of PPX, OCaml's new mechanism for implementing syntax extensions. See [Ppx_eliom](http://ocsigen.org/eliom/5.0/manual/ppx-syntax) for details.

**Client parts are executed once, when the client side process is launched.** The client process is not restarted after each page change.

In the `Makefile` created by the distillery, we automatically split the code into client and server parts, compile the server part as usual, and compile the client part to a JavaScript file using `js_of_ocaml`.

### Client values on the server

Additionally, it is possible to create client values within the server code by the following quotation:

{% highlight ocaml %}
[%client (expr : typ) ]
{% endhighlight %}

where `typ` is the type of an expression `expr` on the client. Note, that such a client value is abstract on the server, but becomes concrete, once it is sent to the client with the next request.

(`typ` can be ommitted if it can be inferred from the usage of the client value in the server code.)

**Client values are executed on the client after the service returns.** You can use client values when a service wants to ask the client to run something, for example binding some event handler on some element produced by the service.

### Js_of_ocaml

The client-side parts of the program are compiled to JavaScript by `js_of_ocaml`. (Technically, `js_of_ocaml` compiles OCaml bytecode to JavaScript.) It is easy to bind JavaScript libraries so that OCaml programs can call JavaScript functions. In the example, we are using the [Dom_html](http://ocsigen.org/js_of_ocaml/2.7/api/Dom_html) module, which is a binding that allows the manipulation of an HTML page.

Js_of_ocaml is using a syntax extension to call JavaScript methods:

- `obj##m a b c` to call the method `m` of object `obj` with parameters `a`, `b`, `c`,
- `obj##.m` to get a property,
- `obj##.m := e` to set a property, and
- `new%js constr a b c` to call a JavaScript constructor.

More information can be found in the Js_of_ocaml manual, in the module
[Ppx_js](http://ocsigen.org/js_of_ocaml/2.7/api/Ppx_js).

## Accessing server side variables on client side code

**(Executing client side code after loading a page,
Sharing server side values,
Converting an HTML value to a portion of page (a.k.a. Dom node),
Manipulating HTML node 'by reference')**


The client side process is not strictly separated from the server side. We can access some server variables from the client code. For instance:

{% highlight ocaml %}
let count = ref 0

let main_service =
  Graffiti_app.register_service
    ~path:[""]
    ~get_params:Eliom_parameter.unit
    (fun () () ->
       let c = incr count; !count in
       ignore [%client
         (Dom_html.window##alert
            (Js.string
               (Printf.sprintf "You came %i times to this page" ~%c))
          : unit)
       ];
       Lwt.return
         (html
            (head (title (pcdata "Graffiti")) [])
            (body [h1 [pcdata "Graffiti"]])))
{% endhighlight %}

Here, we are increasing the reference count each time the page is accessed. When the page is loaded and the document is in-place, the client program initializes the value inside `[%client ... ]`, and thus triggers an alert window. More specifically, the variable `c`, in the scope of the client value on the server is made available to the client value using the syntax extension `~%c`. In doing so, the server side value `c` is displayed in a message box on the client.

###Injections: Using server side values in client code

Client side code can reference copies of server side values using syntax `~%variable`. Values sent that way are weakly type checked: the name of the client side type must match the server side one. If you define a type and want it to be available on both sides, declare it in `[%%shared ... ]`. The Eliom manual provides more information on the [Eliom's syntax extension](http://ocsigen.org/eliom/5.0/api/ppx/Ppx_eliom) and its [compilation process](http://ocsigen.org/eliom/5.0/manual/workflow-compilation#compilation).

Note that the value of an injection into a `[%%client ... ]` section is sent only once when starting the application in the browser, and not synced automatically later. In contrast, the values of injections into client values which are created during a request are sent alongside the next response.

## Next week

In next tutorial, we will turn the program into a collaborative drawing
application, and learn:
- How to draw on a canvas,
- How to program mouse events with `js_of_ocaml`,
- More about Lwt,
- How to create communication channels with the server
- How to create other types of services

The impatient can find the full tutorial
[here](http://ocsigen.org/tuto/manual/application).
