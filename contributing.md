<!--wodoc:div class="project-page"--> <!--wodoc:div class="rightcol"-->


# Contributing to Ocsigen


## For individual contributors

To contribute to an Ocsigen project, first see the guidelines it provides. It will give you the directives on how to make your contribution. Once ready, create a *Pull Request* on the repository and wait for feedback\!

**Every contribution has to be documented\!** The documentation now lives **in the project's own repository**, alongside the code: hand-written manual pages as `doc/*.mld` files and API documentation as comments in the `.mli` files, all in [odoc](https://ocaml.github.io/odoc/) syntax. A single pull request on the project's main branch therefore carries both your code *and* its documentation — there is no separate documentation branch anymore (the old `wikidoc` branch and the wikicréole format are gone).

The CI checks that the documentation builds without errors on every push to your branch, and, once merged, rebuilds and publishes it automatically to the project's `gh-pages` branch, served at [https://ocsigen.org](https://ocsigen.org). Do not hesitate to ask for help if you experience any trouble.


## Create a release (for package maintainers)

1. Make sure the documentation sources (`doc/*.mld` and the `.mli` comments) are **up to date** with the code on `master`; the CI rebuilds the `dev` docs on every push to `master`.
2. Freeze the current `dev` docs as the new version on the project's `gh-pages` branch: `wodoc release --site . --version X.Y.Z` (copies `dev/` to `X.Y.Z/` and repoints the `latest` symlink), then commit and push.
3. Update file CHANGES
4. On `master`, update opam configuration file.
5. `git tag <version>` then `git push --tags`
6. Create a release on GitHub.
7. `opam publish` and wait for the package to be accepted.
1. Add a file in directory `_posts` of repository `ocsigen.github.io` on Github to create a blog post that will be published on OCaml Planet and Twitter's OCaml page

## Local documentation generation

Every project's documentation is built by [wodoc](/wodoc/) (an odoc driver) from its `.mld` manual pages and `.mli` API comments, configured by a single `doc/wodoc` file in the project. To build it locally, from the project root:

```ocaml
wodoc build --config doc/wodoc --out _doc-site/dev --label dev \
  --menu https://ocsigen.org/doc/menu.html --local
```
`--local` also fetches the shared `/css/` and `/img/` assets so the result is viewable offline (`cd _doc-site && python3 -m http.server`, then open `localhost:8000/dev/`). See the project's `doc/README.md` for the exact command and the opam switch it needs.


## Main site

The vitrine (this site's home, projects, install, credits, papers, contributing) lives in repository `ocsigen.github.io`, branch `master`, directory `doc/vitrine/` (`.mld` sources). The two archived projects served directly from this repository, `ocsimore` and `html_of_wiki`, live in `doc/ocsimore/` and `doc/html_of_wiki/`. A GitHub Action (`.github/workflows/doc.yml`) rebuilds them with wodoc on every push to `master` — nothing to run by hand. Every other (active) project builds and publishes its own documentation to its own `gh-pages` branch, served at `ocsigen.org/<project>/`.

<!--wodoc:end--> <!--wodoc:end-->
