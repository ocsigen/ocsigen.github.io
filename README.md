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
  - two **archived** projects whose own repos no longer build:
    [`ocsimore`](doc/ocsimore) → `/ocsimore/` and
    [`html_of_wiki`](doc/html_of_wiki) → `/html_of_wiki/` (static `.mld` sites);
  - the **canonical shared menu** [`doc/menu.html`](doc/menu.html) — the single
    source of truth for the header/menu/drawer of *every* doc page; every
    project's build fetches it from `https://ocsigen.org/doc/menu.html`.

### Building the site (this repository)

[`.github/workflows/doc.yml`](.github/workflows/doc.yml) rebuilds the vitrine and
the two archived sites with wodoc on **every push to `master`** and commits the
generated pages back (GitHub Pages serves the repo). Nothing to run by hand.

To build locally, install [wodoc][wodoc] + odoc, then:

```
( cd doc/vitrine && OUT="$PWD/../.." bash build.sh )                            # vitrine -> root
( cd doc/ocsimore     && wodoc build --config wodoc --out ../../ocsimore/0.5     --label 0.5 --menu ../menu.html --latest )
( cd doc/html_of_wiki && wodoc build --config wodoc --out ../../html_of_wiki/2.0 --label 2.0 --menu ../menu.html --latest )
```

## Blog

This repository also contains the Ocsigen blog (Jekyll). We welcome
contributions! Fork the repository, add a [Markdown][markdown]-formatted article
under `_posts/`, and open a [pull request][githubpr]. Preview locally with
`jekyll serve`.

[githubpages]: https://pages.github.com/
[githubpr]: https://help.github.com/articles/using-pull-requests/
[repo]: https://www.github.com/ocsigen/ocsigen.github.io
[markdown]: https://help.github.com/articles/github-flavored-markdown/
[wodoc]: https://github.com/ocsigen/wodoc
