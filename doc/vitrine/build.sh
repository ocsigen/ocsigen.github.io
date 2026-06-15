#!/bin/bash
# Build the Ocsigen site vitrine (home + projects/install/credits/papers/
# contributing) from .mld sources into the site root, themed with the shared
# Ocsigen chrome (wodoc), with absolute /css//img//<project>/ links.
#
# Per page: preprocess -> odoc compile/link/html-generate -> assemble (renders the
# {%wodoc:%} markers and fills the template). Links/assets are absolute (/css/,
# /img/, /<project>/) so the output is correct at the site root.
#
#   WODOC  path to the wodoc binary (default: wodoc from PATH/opam)
#   odoc   must be on PATH
#   OUT    output dir (default: the repo root, two levels up)
set -e

HERE="$(cd "$(dirname "$0")" && pwd)"
WODOC="${WODOC:-wodoc}"
OUT="${OUT:-$(cd "$HERE/../.." && pwd)}"
MENU="$HERE/../menu.html"
WORK="$HERE/_work"
rm -rf "$WORK"; mkdir -p "$WORK/html" "$WORK/md"

for mld in "$HERE"/src/*.mld; do
  name="$(basename "$mld" .mld)"
  current="githubio"            # every vitrine page highlights "Home" in the menu
  template="$HERE/template.html"
  extra=""
  case "$name" in
  projects) extra="--no-preamble" ;;                       # no visible page title
  intro)    template="$HERE/template-home.html"
            # full-width home; expand its {%wodoc:blog-latest%} with the latest
            # posts of the blog declared in doc/blog (served at /blog)
            extra="--flat --blog-config $HERE/../blog/wodoc --blog-base blog" ;;
  credits | papers | contributing)
    template="$HERE/template-page.html"; extra="--flat" ;; # carry their own layout
  esac
  "$WODOC" preprocess "$mld" >"$WORK/$name.mld"
  odoc compile "$WORK/$name.mld" -o "$WORK/page-$name.odoc"
  odoc link "$WORK/page-$name.odoc" -o "$WORK/page-$name.odocl"
  odoc html-generate "$WORK/page-$name.odocl" -o "$WORK/html"
  "$WODOC" assemble --template "$template" --menu "$MENU" --current "$current" \
    --mdlink "/$name.md" $extra "$WORK/html/$name.html" >"$OUT/$name.html"
  # the Markdown twin, for AI/LLM consumption (the .md version of the page)
  odoc markdown-generate "$WORK/page-$name.odocl" -o "$WORK/md"
  cp "$WORK/md/$name.md" "$OUT/$name.md"
  echo "built $name.html + $name.md"
done
# the homepage (/) is the intro page
cp "$OUT/intro.html" "$OUT/index.html"
cp "$OUT/intro.md" "$OUT/index.md"
rm -rf "$WORK"

# The root llms.txt (llmstxt.org): the AI/LLM entry point for the whole site.
# It features the two main tutorial pages first, then the vitrine pages, then one
# link per project to that project's own llms.txt (each project ships it via
# wodoc, served at /<project>/latest/llms.txt). Regenerated on every build.
cat >"$OUT/llms.txt" <<'EOF'
# Ocsigen

> Ocsigen is an advanced framework for developing client/server web and mobile
> applications in OCaml, with strong static typing all the way across the
> client/server boundary. This file indexes the Markdown documentation of the
> whole project for AI/LLM consumption; every linked page is available as
> Markdown, and each project also ships a full dump at
> /<project>/latest/llms-full.txt.

## Start here
- [Tutorial — basics](https://ocsigen.org/tuto/latest/basics.md): write a complete client/server application, the recommended starting point
- [Tutorial — server-side basics](https://ocsigen.org/tuto/latest/basics-server.md): server-side web programming with Eliom

## About Ocsigen
- [Home](https://ocsigen.org/index.md): overview of the framework
- [Installation](https://ocsigen.org/install.md): how to install the Ocsigen packages
- [Projects](https://ocsigen.org/projects.md): the libraries and tools that make up Ocsigen
- [Contributing](https://ocsigen.org/contributing.md): how to contribute

## Projects
- [Eliom](https://ocsigen.org/eliom/latest/llms.txt): the core client/server web framework (shared client/server code, services, reactive UI)
- [Ocsigen Start](https://ocsigen.org/ocsigen-start/latest/llms.txt): a ready-to-use base for client/server applications (users, sessions, notifications)
- [Ocsigen Toolkit](https://ocsigen.org/ocsigen-toolkit/latest/llms.txt): client/server UI widgets
- [Ocsigen Server](https://ocsigen.org/ocsigenserver/latest/llms.txt): the web server
- [js_of_ocaml](https://ocsigen.org/js_of_ocaml/latest/llms.txt): the OCaml-to-JavaScript and WebAssembly compiler
- [Lwt](https://ocsigen.org/lwt/latest/llms.txt): cooperative threading (promises) for OCaml
- [TyXML](https://ocsigen.org/tyxml/latest/llms.txt): build statically correct HTML and SVG
- [Ocsipersist](https://ocsigen.org/ocsipersist/latest/llms.txt): persistent key/value storage
- [Ocsigen i18n](https://ocsigen.org/ocsigen-i18n/latest/llms.txt): internationalisation
- [ReactiveData](https://ocsigen.org/reactiveData/latest/llms.txt): incremental reactive data structures
- [Tutorial](https://ocsigen.org/tuto/latest/llms.txt): the Ocsigen tutorials
- [Wodoc](https://ocsigen.org/wodoc/latest/llms.txt): the documentation tool that builds this site

## Optional
- [Credits](https://ocsigen.org/credits.md): authors and history
- [Papers](https://ocsigen.org/papers.md): academic publications about Ocsigen
- [Ocsimore](https://ocsigen.org/ocsimore/latest/llms.txt): archived — a wiki/CMS built with Ocsigen
- [html_of_wiki](https://ocsigen.org/html_of_wiki/latest/llms.txt): archived — the former documentation tool
EOF
echo "built llms.txt"
echo "vitrine built into $OUT"
