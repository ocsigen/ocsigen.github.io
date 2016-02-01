---
title: January 2016 Ocsigen releases
layout: default
author: The Ocsigen team
authorurl: https://ocsigen.org
---

We are excited to announce the releases of

- [Eliom 5.0](https://github.com/ocsigen/eliom/releases/tag/5.0.0)
- [js_of_ocaml 2.7](https://github.com/ocsigen/js_of_ocaml/releases/tag/2.7)
- [TyXML 3.6](https://github.com/ocsigen/tyxml/releases/tag/3.6.0)
- [reactiveData 0.2](https://github.com/ocsigen/reactiveData/releases/tag/0.2)

These releases are the result of many months of work by the Ocsigen
team, and bring a range of improvements.

## PPX

Eliom 5.0 comes with a [PPX-based
language](http://ocsigen.org/eliom/5.0/manual/ppx-syntax) (for OCaml
4.02.x). This follows our PPX extensions for
[js_of_ocaml](https://ocsigen.org/js_of_ocaml/2.7/api/Ppx_js) and
[Lwt](https://ocsigen.org/lwt/2.5.1/api/Ppx_lwt). The new syntax is
more flexible than our previous Camlp4-based one, and we recommend it
for new projects. Nevertheless, the Camlp4-based syntax remains
available.

## Shared reactive programming

Recent versions of Eliom provided client-side support for (functional)
reactive programming. Eliom 5.0 additionally supports ["shared"
(client-server) reactive
programming](http://ocsigen.org/eliom/5.0/manual/clientserver-react),
where the reactive signals have meaning both on the server and the
client. This means that the initial version of the page is produced
(on the server) with the same code that takes care of the dynamic
updates (on the client).

## Enhanced js_of_ocaml library

The js_of_ocaml library provides additional bindings for established
JavaScript APIs. This includes

- [geolocation](http://ocsigen.org/js_of_ocaml/2.7/api/Geolocation),
- [mutation
  observers](http://ocsigen.org/js_of_ocaml/2.7/api/MutationObserver), and
- [web workers](http://ocsigen.org/js_of_ocaml/2.7/api/Worker).

A new JavaScript-specific [table
module](http://ocsigen.org/js_of_ocaml/2.7/api/Jstable) is also
available.

## ppx_deriving

js_of_ocaml provides a new [JSON
  plugin](https://github.com/ocsigen/js_of_ocaml/pull/364) for
  [ppx_deriving](https://github.com/whitequark/ppx_deriving). This can
  be used for serializing OCaml data structures to JSON in a type-safe
  way. The plugin remains compatible with its Camlp4-based predecessor
  with respect to the serialization format.

## Under the hood

In addition to providing various fixes, we have improved the
performance of various Ocsigen components. Notably:

- A [range of patches related to request
  data](https://github.com/ocsigen/eliom/pull/233) result in
  measurably smaller size for the produced pages.

- The js_of_ocaml compiler becomes faster via improvements in
  [bytecode
  parsing](https://github.com/ocsigen/js_of_ocaml/commit/3991c07b15d88c89bad43de8303b0e0a553b2eed).

- reactiveData employs
  [diffing](https://github.com/ocsigen/reactiveData/pull/12) to detect
  data structure changes, leading to more localized incremental
  updates.

## Community

The Ocsigen team always welcomes your feedback and contributions.
Stay in touch via [GitHub](https://github.com/ocsigen) and our
[mailing list](https://sympa.inria.fr/sympa/subscribe/ocsigen)!
