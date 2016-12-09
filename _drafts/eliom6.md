---
title: Eliom 6.0 released
layout: default
author: The Ocsigen Team
authorurl: https://ocsigen.org
---

We are very happy to announce the release of [Eliom 6.0][release],
which follows the recent releases of
[Ocsigen Server 2.8][serverrelease]
and [Js\_of\_ocaml 2.8.x][jsoorelease].

New features include a friendlier service API that retains the
expressive power of our service system. Additionally, Eliom can now be
used to build mobile applications.

## What is Eliom?

Eliom is a framework for developing client/server web
applications. Both the server and the client parts of the application
are written in OCaml, as a single program.

Eliom makes extensive use of the Ocaml language features. It provides
advanced functionality like a powerful session mechanism and support
for functional reactive Web pages.

## Friendly service APIs

Services are a key concept in Eliom, used for building the pages that
are sent to the user, for accessing server-side data, for performing
various actions, and so on. Eliom 6.0 provides a friendlier API for
defining and registering services, thus making Eliom more
approachable.

The new API makes extensive use of OCaml's [GADTs][gadt], and provides
a single entry-point that supports most kinds of services
([Eliom_service.create][servicecreate]). For more information, refer
to the [Eliom manual][servicemanual].

## Mobile applications

Eliom 6.0 allows one to build applications for multiple mobile
platforms (including iOS, Android, and Windows) with the same codebase
as for a Web application, and following standard Eliom idioms.

To achieve this, we have made available the Eliom service APIs
[on the client][clientservice]. Thus, the user interface can be
produced directly on the mobile device, with remote calls only when
absolutely necessary.

To build an Eliom 6.0 mobile application easily, we recommend that you
use our soon-to-be-released [Ocsigen Start][ostart] project, which
provides a mobile-ready template application
([walkthrough][mobilewalkthrough]).

## Compatibility

Eliom 6.0 supports the last 3 major versions of OCaml (4.02 up to
4.04). Additionally, Eliom is compatible and with and builds on the
latest Ocsigen releases, including
[Ocsigen Server 2.8][serverrelease],
[Js\_of\_ocaml 2.8.x][jsoorelease], and [TyXML 4.0.x][tyxmlrelease].

## Future

The Ocsigen team is busy working on new features. Notably, we are
developing an [OCaml compiler][eliomc] specifically tuned for
Eliom. Additionally, we are planning a transition to the
[Cohttp][cohttp] HTTP backend.

## Support

- [Migration guide][migration]
- [Issue tracker][issues]
- [Mailing list][list]
- IRC: `#ocsigen` on `irc.freenode.net`

[release]: https://github.com/ocsigen/eliom/releases/tag/6.0.0
[serverrelease]: https://github.com/ocsigen/ocsigenserver/releases/tag/2.8
[jsoorelease]: https://github.com/ocsigen/js_of_ocaml/releases/tag/2.8.3
[tyxmlrelease]: https://github.com/ocsigen/tyxml/releases/tag/4.0.1

[migration]: https://ocsigen.org/eliom/Eliom60
[issues]: https://github.com/ocsigen/eliom/issues
[list]: https://sympa.inria.fr/sympa/info/ocsigen
[clientservice]: https://ocsigen.org/eliom/manual/clientserver-services
[ostart]: https://github.com/ocsigen/ocsigen-start
[mobilewalkthrough]: https://ocsigen.org/tuto/manual/mobile
[eliomc]: https://github.com/ocsigen/ocaml-eliom
[cohttp]: https://github.com/mirage/ocaml-cohttp
[gadt]: https://en.wikipedia.org/wiki/Generalized_algebraic_data_type
[servicecreate]: https://ocsigen.org/eliom/api/server/Eliom_service#VALcreate
[servicemanual]: https://ocsigen.org/eliom/dev/manual/server-services
