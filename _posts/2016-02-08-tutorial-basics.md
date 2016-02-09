---
title: Ocsigen, the basics
layout: default
author: Vincent Balat
authorurl: http://ocsigen.org
---

Following last week release,
I'm starting today a series of tutorials about the Ocsigen framework. For the impatient, most of these tutorials are already available on [Ocsigen][tutorial]'s Web site.

In this first tutorial, we show how to use the Ocsigen framework (mainly Eliom) to write a lightweight Web site by generating pages using OCaml functions.
Even though Eliom makes it possible to write complete client-server Web and mobile apps,
you can still use Eliom even if you don't need all these features (for example if you don't want HTML type checking or client side features). Besides, this will allow you to extend your Web site in a full Web application if you need, later on. This tutorial is also a good overview of the basics of Eliom.

## A service generating a page

The following code shows how to create a service that answers requests at URL `http://.../aaa/bbb`, by invoking an Ocaml function `f` of type:

{% highlight ocaml %}
f : (string * string) list -> unit -> string Lwt.t
{% endhighlight %}


Function `f` generates HTML as a string, taking as argument the list of URL parameters (GET parameters).

{% highlight ocaml %}
let f _ () =
  Lwt.return "<html><head><title>A</title></head><body>B</body></html>"

let main_service =
  Eliom_registration.Html_text.register_service
    ~path:["aaa"; "bbb"]
    ~get_params:Eliom_parameter.any
    f
{% endhighlight %}

`Eliom_paramer.any` means that the service takes any GET parameter.

We recommend to use the program eliom-distillery to generate a template for your application (a Makefile and a default configuration file for Ocsigen Server).

```
$ eliom-distillery -name mysite -template basic.ppx -target-directory mysite
```
Put the piece of code above in file mysite.eliom, compile and run the server by doing:

```
$ make test.byte
```
Your page is now available at URL http://localhost:8080/aaa/bbb.

If you dont want to use the Makefile provided by eliom-distillery, just replace mysite.eliom by a file mysite.ml, compile and run with

```
$ ocamlfind ocamlc -package eliom.server -thread -c mysite.ml
$ ocsigenserver -c mysite.conf
```
where `mysite.conf` is adapted from `local/etc/mysite/mysite-test.conf` by replacing `mysite.cma` by your cmo.

## POST service

Services using the POST HTTP method are created using the function `Eliom_service.​Http.​post_service`. To create a service with POST parameters, first you must create a service without POST parameters, and then the service with POST parameters, with the first service as fallback. The fallback is used if the user comes back later without POST parameters, for example because he put a bookmark on this URL.

{% highlight ocaml %}
let g getp postp = Lwt.return "..."

let post_service =
  Eliom_registration.Html_text.register_post_service
    ~fallback:main_service
    ~post_params:Eliom_parameter.any
    g
{% endhighlight %}

## Going further

That is probably all you need for a very basic Web site in OCaml.
But Ocsigen provides many tools to write more advanced Web sites
and applications:

Instead of generating HTML in OCaml strings, we highly recommend to use
_typed HTML_. It is very easy to use, once you have learned the basics,
and helps a lot to efficiently write modular and valid HTML.
To do this, use module
[`Eliom_registration.Html5`](http://ocsigen.org/eliom/api/server/Eliom_registration.Html5)
instead of
[`Eliom_registration.Html_text`](http://ocsigen.org/eliom/api/server/Eliom_registration.Html_text).
See this
[tutorial](http://ocsigen.org/tuto/manual/application#tyxml)
for more information, a comprehensive documentation
[here](http://ocsigen.org/tyxml/manual/),
and a more advanced manual
[here](http://ocsigen.org/eliom/manual/clientserver-html).

Have a look at Eliom's API documentation to see other kinds of services,
for example [`Eliom_registration.Redirection`](http://ocsigen.org/eliom/api/server/Eliom_registration.Redirection)
to create HTTP redirections.

Eliom also has a way to typecheck forms and GET or POST parameters.
By giving a description of the parameters your service expects,
Eliom will check their presence automatically, and convert them
for you to OCaml types.
See
[this tutorial](http://ocsigen.org/tuto/manual/interaction)
and [this manual page](http://ocsigen.org/eliom/manual/server-params).

Eliom also has other ways to identify services (besides just the PATH
in the URL). For example Eliom can identify a service just by a parameter
(whatever the path is). This is called _non-attached coservices_ and
this makes it possible for instance to have the same feature on every page
(for example a connection service).
See
[this tutorial](http://ocsigen.org/tuto/manual/interaction)
and [this manual page](http://ocsigen.org/eliom/manual/server-services).

One of the main features of Eliom is the ability to write complete
Web and mobile applications in OCaml. Annotations are used to
separate the code to be executed server-side from the client code.
Client functions are translated into Javascript using
[Ocsigen Js_of_ocaml](http://ocsigen.org/js_of_ocaml/).
See
[this tutorial](http://ocsigen.org/tuto/manual/tutowidgets) for
a quick introduction,
or [this one](http://ocsigen.org/tuto/manual/application) for a
more comprehensive one.
You can also have a look at
[this manual page](http://ocsigen.org/eliom/manual/clientserver-applications).

Another interesting feature of Eliom is its session model, that uses a
very simple interface to record session data server-side.
It is even possible to choose
the _scope_ of this data: either a browser, or a tab, or even a group
of browsers (belonging for instance to a same user).
See
[this section](http://ocsigen.org/tuto/manual/interaction#eref)
and the beginning of
[this manual page](http://ocsigen.org/eliom/manual/server-state).

We suggest to continue your reading by one of these tutorials:

- [A quick start tutorial for client-server Eliom applications](http://ocsigen.org/tuto/manual/tutowidgets) (for the people already familiar with OCaml, Lwt, etc.)
- [A step by step tutorial for client-server Eliom applications](http://ocsigen.org/tuto/manual/application)
- [A tutorial on server side dynamic Web site](http://ocsigen.org/tuto/manual/interaction)








[tutorial]: http://ocsigen.org/tuto
