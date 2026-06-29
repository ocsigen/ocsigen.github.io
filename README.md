# Ocsigen Web site

The site lives in this [Git repository][repo] and is served by [GitHub
Pages][githubpages] (CNAME `ocsigen.org`).

## How the documentation is organised

All documentation across Ocsigen is written in **odoc** syntax (`.mld` manual
pages + `.mli` API comments) and rendered by [**wodoc**][wodoc], an odoc driver
that themes the pages with the shared Ocsigen chrome (top menu, drawer, version
selector). There is no more `html_of_wiki`/`ohow` and no `wikidoc` branch.

The documentation is split in two by *where it is hosted*:

- **Each active project** (eliom, js_of_ocaml, lwt, ocsigenserver, ocsigen-start,
  ocsigen-toolkit, ocsipersist, reactiveData, tyxml, ocsigen-i18n, tuto, …) keeps
  its doc sources in its **own repository** (`doc/wodoc` config + `doc/*.mld`) and
  builds + publishes them to its **own `gh-pages` branch** via its own
  `.github/workflows/doc.yml`. They are served at `ocsigen.org/<project>/` (the
  GitHub project page of `ocsigen/<project>`). This repository does **not** build
  or contain those — see each project's `doc/README.md`.

- **This repository** builds, with wodoc, only what it hosts directly:
  - the **vitrine** (home + `projects`/`install`/`credits`/`papers`/
    `contributing`), from [`doc/vitrine/`](doc/vitrine) `*.mld`, into the site
    **root**;
  - the **blog**, from [`doc/blog/`](doc/blog) `*.mld`, into `/blog/` plus the
    Atom feed at `/feed.xml` — see [Blog](#blog) below;
  - two **archived** projects whose own repos no longer build:
    [`ocsimore`](doc/ocsimore) → `/ocsimore/` and
    [`html_of_wiki`](doc/html_of_wiki) → `/html_of_wiki/` (static `.mld` sites);
  - the **canonical shared menu** [`doc/menu.html`](doc/menu.html) — the single
    source of truth for the header/menu/drawer of *every* doc page; every
    project's build fetches it from `https://ocsigen.org/doc/menu.html`.

### Building the site (this repository)

[`.github/workflows/doc.yml`](.github/workflows/doc.yml) rebuilds the vitrine, the
blog and the two archived sites with wodoc on **every push to `master`** and
commits the generated pages back (GitHub Pages serves the repo). Nothing to run by
hand.

To build locally, install [wodoc][wodoc] + odoc, then:

```
( cd doc/vitrine && OUT="$PWD/../.." bash build.sh )                            # vitrine -> root
( cd doc/blog    && OUT="$PWD/../.." bash build.sh )                            # blog -> /blog + /feed.xml
( cd doc/ocsimore     && wodoc build --config wodoc --out ../../ocsimore/0.5     --label 0.5 --menu ../menu.html --latest )
( cd doc/html_of_wiki && wodoc build --config wodoc --out ../../html_of_wiki/2.0 --label 2.0 --menu ../menu.html --latest )
```

## Blog

The Ocsigen blog (served at `/blog/`) is built with wodoc from
[`doc/blog/`](doc/blog), like the rest of the site — there is no more Jekyll. A
post is a plain odoc `.mld` page.

**To add an article**, drop a file named `YYYY-MM-DD-slug.mld` in
[`doc/blog/posts/`](doc/blog/posts) and open a [pull request][githubpr]. The date
in the file name is the publication date (posts are listed newest-first, with no
metadata file); the **author** comes from odoc's `@author` tag, the **title** from
the page heading, and the **excerpt** (shown in the listing and the feed) from the
first paragraph:

```
{0 My post title}

@author Jane Doe

The first paragraph, which becomes the excerpt.

{1 A section}

…the rest of the article: text, code, images, links.
```

[`doc/blog/build.sh`](doc/blog/build.sh) (run by `doc.yml` on every push to
`master`; see [Building the site](#building-the-site-this-repository) for the
local command) builds each post to `/blog/posts/<slug>.html`, generates the post
list (the left-nav section and the landing's `{%wodoc:blog-latest%}` widget) and
the Atom feed at `/feed.xml` — the URL the [OCaml Planet][planet] aggregator
follows. New posts automatically get the Ocsigen badge as their social-card /
OCaml Planet thumbnail, via the `og:image` in
[`doc/blog/template.html`](doc/blog/template.html).

**Unlisted drafts.** To share a work-in-progress article by direct link without
publishing it, drop its `YYYY-MM-DD-slug.mld` in
[`doc/blog/hidden/`](doc/blog/hidden) instead of `doc/blog/posts/`. `build.sh`
renders it to the same `/blog/posts/<slug>.html` URL, but because it lives
outside the `(blog (dir posts))` config it is **absent from the left-nav, the
landing's latest-posts widget and `/feed.xml`** — so it never reaches OCaml
Planet and nothing links to it. To publish such a draft for real, move its
`.mld` into `doc/blog/posts/` (and let CI regenerate the page).

[githubpages]: https://pages.github.com/
[githubpr]: https://help.github.com/articles/using-pull-requests/
[repo]: https://www.github.com/ocsigen/ocsigen.github.io
[wodoc]: https://github.com/ocsigen/wodoc
[planet]: https://ocaml.org/ocaml-planet
