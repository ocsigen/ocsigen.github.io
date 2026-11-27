# Ocsigen Server 8\.0.0: one command, and a modernized API

Published on 2026-09-24 by The Ocsigen team.

[Ocsigen Server](/ocsigenserver/) 8\.0.0 is out. Running a web server no longer needs a configuration file: `ocsigenserver ./public` serves a directory, and `ocsigenserver --reverse-proxy http://localhost:9000` puts a proxy in front of an application, both with compression and safe security headers already on. Static files now answer conditional and byte-range requests, compression speaks zstd, and accesses are logged in the Combined Log Format that usual analysers understand. This release also renames the public modules, with a compatibility package for existing code.

Ocsigen Server is a web server written in OCaml. It can be run as an executable, taking its configuration from a file, or used as a library, so that an application starts and configures its own server from OCaml code. Its architecture is modular: everything that handles a request is an extension, loaded and configured on demand. The ones shipped with the server cover most of what a site needs, among them [Staticmod](/ocsigenserver/latest/staticmod.html) for static files, [Revproxy](/ocsigenserver/latest/revproxy.html) for forwarding requests to another server, [Deflatemod](/ocsigenserver/latest/deflatemod.html) for compression, [Accesscontrol](/ocsigenserver/latest/accesscontrol.html) and [Authbasic](/ocsigenserver/latest/authbasic.html) for restricting access, [Redirectmod](/ocsigenserver/latest/redirectmod.html) and [Rewritemod](/ocsigenserver/latest/rewritemod.html) for redirections and URL rewriting, [CORS](/ocsigenserver/latest/cors.html), and the new [Securityheaders](/ocsigenserver/latest/securityheaders.html). An extension is an OCaml module that the server loads, so writing your own is the same exercise as using one. [Eliom](/eliom/), the multi-tier framework for web and mobile applications, is itself an extension of Ocsigen Server.

## One command

Ocsigen Server has always been configured by an XML file, which is what you want for a real deployment and what you do not want when you just need to serve a directory. It can now do the latter:

```ocaml
$ ocsigenserver ./public
Serving /home/me/public on http://localhost:8080
```
No configuration file, no log directory to create beforehand: logs go to the terminal, and the Staticmod extension is loaded on demand. Options are available for the usual cases:

```ocaml
$ ocsigenserver --serve ./public --port 8000 --directory-listing
```
The same goes for a reverse proxy, which is how most OCaml applications are actually exposed:

```ocaml
$ ocsigenserver --reverse-proxy http://localhost:9000 --port 8080
```
Both modes are also available as library functions, `Ocsigen.Server.serve` and `Ocsigen.Server.reverse_proxy`, so an application can start its own server in one call.

## Static files: conditional requests and byte ranges

Static files now carry an `ETag` and a `Last-Modified` header, and requests carrying `If-None-Match` or `If-Modified-Since` get a `304 Not Modified` (RFC 7232\). A browser revisiting a page no longer downloads what it already has.

Byte ranges are supported as well (RFC 7233\): responses advertise `Accept-Ranges`, a satisfiable `Range` yields `206 Partial Content` with the matching `Content-Range`, `If-Range` is honoured, and an unsatisfiable range gives `416`. This is what media players need to seek in a video, and what a download manager needs to resume.

## Compression: zstd, and a new backend

The Deflatemod extension now supports the zstd content encoding (RFC 8878\) in addition to gzip and deflate, and prefers it when the client offers several. Its backend moved from camlzip to [bytesrw](https://erratique.ch/software/bytesrw), so the package now depends on `bytesrw`, `conf-zlib` and `conf-zstd` instead of `camlzip`.

Compression is on by default in the one-command modes. Two long-standing correctness problems were fixed along the way: a compressed response used to keep the `Content-Length` of the uncompressed body, which truncated it, and its entity tag was mangled into something that was not a valid one. Compressed responses now also announce `Vary: Accept-Encoding`, without which a shared cache may hand a compressed body to a client that did not ask for one.

## Security

Several hardening changes ship in this release:

- the `<maxconnected>` limit is enforced again, by throttling the accept loop, instead of being silently ignored;
- error responses no longer include the raw OCaml exception in their body; the details stay in the logs;
- the command pipe is created with mode `0o600`, so that other local users of the server's group can no longer send it `shutdown` or `reload`;
- TLS requires version 1\.2 at minimum and prefers the server's cipher order, and the `<ciphers>`, `<dhfile>` and `<curve>` entries, until now parsed but never applied, reach the TLS context.
A new extension, Securityheaders, adds the usual security headers in one declaration. Its defaults are the ones that are safe everywhere (`X-Content-Type-Options`, `X-Frame-Options`, `Referrer-Policy`); `Strict-Transport-Security` and `Content-Security-Policy` are opt-in, because neither can be guessed from the outside and both are painful to undo.

One limitation to keep in mind if you are considering exposing the server directly: the `<timeout>` options are parsed but not enforced yet, so a client that sends its request one byte at a time still holds a connection. Until that is fixed, keep a reverse proxy or a filtering front in charge of slow clients.

## Logs

Accesses are logged in the Apache and nginx Combined Log Format, so the usual analysers can read them directly. The line reports the final status code, the response size and the authenticated user, which the previous custom format did not. Anything parsing the old format has to be updated.

When no `<logdir>` is configured, logs now go to the standard output and error instead of to files, which is what a container or a service manager expects.

## New module names

The public modules are now grouped under three wrappers:

- `ocsigenserver`: `Ocsigen.Server`, `Ocsigen.Config`, `Ocsigen.Extensions`, `Ocsigen.Request`, `Ocsigen.Response`, `Ocsigen.Messages`, ... replacing `Ocsigen_server`, `Ocsigen_config`, and so on;
- `ocsigenserver.baselib`: `Ocsigen_base.Lib`, `Ocsigen_base.Cache`, `Ocsigen_base.Loader`;
- `ocsigenserver.http`: `Ocsigen_http.Header`, `Ocsigen_http.Charset_mime`.
`Ocsigen_cohttp` and `Ocsigen_stream` keep their name, to avoid clashing with `Cohttp` and `Stdlib.Stream`.

Existing code does not have to be rewritten: the new `ocsigenserver-compat` package provides the old names as aliases of the new modules. Install it, and code written for 7\.0.0 compiles unchanged.

## Upgrading

```ocaml
$ opam update
$ opam install ocsigenserver
```
Add `ocsigenserver-compat` to your dependencies if you want to keep the old module names for now. Two other changes are worth checking before upgrading a deployment: log parsing, since the access log format changed, and the dependency on a zstd development package, which `conf-zstd` pulls in.

The full list of changes is in the [CHANGES](https://github.com/ocsigen/ocsigenserver/blob/master/CHANGES) file, and the manual is on [ocsigen.org](/ocsigenserver/).
