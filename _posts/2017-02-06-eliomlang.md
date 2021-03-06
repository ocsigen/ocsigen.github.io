---
title: News on the Eliom language
layout: default
author: Gabriel `Drup` Radanne
authorurl: https://www.irif.fr/~gradanne/
---

The [Eliom framework][eliom] is the part of the [ocsigen project][ocsigen] that aims to provide
high level libraries for developing client/server web applications.
It contains a [language extension][syntax] of OCaml that allows implementing both the client
and the server parts of your application as a single program. It also
contains [several libraries and utilities][manual] to facilitate web programming.

[ocsigen]: https://ocsigen.org
[eliom]: https://ocsigen.org/eliom/
[manual]: https://ocsigen.org/eliom/manual/
[syntax]: https://ocsigen.org/eliom/6.1/manual/ppx-syntax

The various Ocsigen libraries have received a lot of care
lately. Notably, we have reworked the [service API][announcement6], we
have added support for mobile applications and, we have developed
[ocsigen-start][ostart].

[announcement6]: https://ocsigen.github.io/blog/2016/12/12/eliom6/
[ostart]: https://github.com/ocsigen/ocsigen-start

Today, I will not talk about the ocsigen libraries. I will talk solely about
the language extension.

## The current language extension

The Eliom language extension extends OCaml with various annotations that
allows specifying where things are to be defined and executed.

{% highlight ocaml %}
let%server s = 1 + 2 (* I'm executed on the server *)
let%server s2 = (* I'm declared on the server *)
  [%client 1 + 2 (* But I will be executed on the client! *) ]
let%client c =
  ~%s + ~%s2 + 1
  (* I access values on the server and execute things on the client! *)
{% endhighlight %}

The semantics is that the server part is executed first,
then the web page is sent to the client,
then the client part is executed.
See [the documentation][syntax] for detail on the current extension.

The language extension is currently implemented using a PPX extension and
a custom (and a bit sophisticated) compilation scheme. Note here that I used
the word "language" extension on purpose: this is not a simple syntax extension,
the Eliom language has its own type system, semantics and compilation
scheme, which are extensions of the OCaml ones.

The current implementation of our language, based on PPX, started to
show its limits in terms of flexibility, convenience and with respect to
the safety guarantees it can provide. This is why I started, as part
of my PhD thesis, to redesign and improve it.

## Formalizing the Eliom language

Our first goal was to formalize the Eliom language as an extension of the OCaml
language. Formalizing the language allowed us to better understand its type 
system and semantics, which led to various improvements and bug fixes.
The formalization was [published in APLAS 2016][paperAPLAS]. In this paper,
we present a (rather simple) type system based on two distinct type
universes and the notion of converters, that allows passing values from
the server to the client. We also show that the intuitive semantics
of Eliom, that server code is executed immediately and client code is executed
later in the exact same order it was encountered, does correspond to the
compilation scheme used to slice Eliom programs into a server program and a
client program.

In the the current implementation, when passing
a server value of type `Foo.t` to the client. It also has type `Foo.t`,
but the type is now the one available on the client. The actual object
can also be transformed while passing the client/server boundary using
[wrappers][wrap]. Unfortunately, this API is very difficult to use, not
flexible and quite unsafe. Instead, we propose to use converters.
Converters can be though as a pair of function: a server serialization
function `ty_server -> string` and a client deserialization function
`string -> ty_client` (the actual implementation will be a bit different to make (de)serializer composable).
The correctness of a converter depends of course on the good behavior of these
two functions, but the language guarantees that they will be used together
properly and each sides will properly respect the types of the converter.

By using converters, we can provide a convenient programming model and make
Eliom much easier to extend. We demonstrated this with multiple examples in
[another paper published in IFL 2016][paperIFL].
Unfortunately, a proper implementation of converters is only possible
with some form of ad-hoc polymorphism, which involve using modular implicits.

[paperAPLAS]: https://hal.archives-ouvertes.fr/hal-01349774
[paperIFL]: https://hal.archives-ouvertes.fr/hal-01407898
[wrap]: https://ocsigen.org/eliom/6.1/manual/clientserver-wrapping

## Implementing the Eliom language

In order to actually implement all these new things, I started to work on an
extension of the OCaml compiler capable of handling the Eliom language
constructs. Working directly in the compiler has several advantages:

- We can implement the actual type system of Eliom directly.
- Easier to extend with new features.
- Much better error messages.
- A simpler and faster compilation scheme.

The current work-in-progress compiler is available in the repository
[ocsigen/ocaml-eliom][ocaml-eliom]. A minimal runtime,
along with various
associated tools are available in [ocsigen/eliomlang][eliomlang].
A (perpetually broken) playground containing an extremely bare-bone
website using eliomlang without the complete framework is available in [ocsigen/eliomlang-playground][playground].

Finally, the work on using this new compiler to compile the Eliom framework can be followed via [this pull-request][PR].

[ocaml-eliom]: https://github.com/ocsigen/ocaml-eliom
[eliomlang]: https://github.com/ocsigen/eliomlang
[playground]: https://github.com/ocsigen/eliomlang-playground
[PR]: https://github.com/ocsigen/eliom/pull/459

## Going further

A more in-depth presentation of the Eliom language can be found [here][slides].
The [APLAS paper][paperAPLAS] is quite formal and is mostly aimed at people
that want to really understand the minute details of the language. The
[IFL paper][paperIFL], on the other hand, should be accessible to most OCaml programmers
(even those who don't know Eliom) and demonstrates how to use the new Eliom
constructs to build nice, tierless and typesafe libraries for client/server
web programming.

[slides]: https://www.irif.fr/~gradanne/papers/eliom/talk_gallium.pdf

## The future

The work on the Eliom language is far from done. A current area of work
is to extend the OCaml module language to be aware of the Eliom annotations.
A particularly delicate (but promising!) area is the ability to use
Eliom annotations inside functors.
A second area of work is that of stabilizing, debugging and documenting the patched compiler.
Finally, a difficulty raised by this new compiler is that existing build systems,
and in particular ocamlbuild, do not handle the Eliom compilation scheme
very well. Some details on this can be found [here][PR].

I wish this progress report has awaken your appetite for well-typed
and modular tierless programming in OCaml. I hope I will be able to
share more news in a few months.

Happy Eliom programming!
