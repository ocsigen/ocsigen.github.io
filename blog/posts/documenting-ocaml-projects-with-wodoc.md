# Documenting OCaml projects with wodoc

Published on 2026-06-07 by The Ocsigen team.

[wodoc](/wodoc/) turns `.mld` and `.mli` sources into a complete, styled website — not just API documentation. The very site you are reading is built with it.

The same sources render as plain semantic documentation with a stock odoc (for example on [ocaml.org](https://ocaml.org)) and as the full themed website when built with wodoc, with no fork of odoc and no separate dialect to learn. This blog is one more thing wodoc now does out of the box.

## The whole site is migrated

We have now migrated the entire Ocsigen website to wodoc: the documentation is entirely in the odoc format, and so is the full website — the home page, the project pages, this blog and the rest. There is a single, uniform toolchain from the API reference all the way to the landing page.

## Still experimental — tell us what breaks

wodoc is still **experimental**, and a migration this large is bound to have left rough edges: a broken link, a misrendered page, a missing style. If you spot anything that looks wrong, please **report it** on the [wodoc issue tracker](https://github.com/ocsigen/wodoc/issues) — it is a great help and will make the tool better for everyone.
