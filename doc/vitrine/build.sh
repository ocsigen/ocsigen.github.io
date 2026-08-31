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
  # the Markdown twin, for AI/LLM consumption (the .md version of the page).
  # `render --markdown` drops the {%wodoc:%} markers, which odoc's Markdown
  # backend passes through verbatim (`wodoc build` does this for the projects).
  odoc markdown-generate "$WORK/page-$name.odocl" -o "$WORK/md"
  "$WODOC" render --markdown "$WORK/md/$name.md" >"$OUT/$name.md"
  echo "built $name.html + $name.md"
done
# the homepage (/) is the intro page
cp "$OUT/intro.html" "$OUT/index.html"
cp "$OUT/intro.md" "$OUT/index.md"
rm -rf "$WORK"

# The root llms.txt (llmstxt.org): the AI/LLM entry point for the whole site.
# It features the two main tutorial pages first, then the vitrine pages, then one
# link per project to that project's own llms.txt. Each active project ships it
# via wodoc in its CI-rebuilt /dev/ docs (always current); the two archived
# projects, which are built once, are served from /latest/. Regenerated on every
# build.
#
# The PROJECT LIST is read from doc/menu.html, the single source of truth for
# what Ocsigen ships, so that adding, renaming or dropping a project there is
# picked up here too. This file only holds what the menu cannot carry: the
# display name and the one-line description. The two lists are checked against
# each other below and a mismatch fails the build, because the failure mode is
# otherwise silent: this list drifts, and the site ships an llms.txt whose links
# 404 (which is exactly how the two archived projects came to be dead in it).
#
#   <menu id>|<display name>|<one-line description>
projects_table="
tuto|Tutorial|the Ocsigen tutorials
eliom|Eliom|the core client/server web framework (shared client/server code, services, reactive UI)
ocsigen-start|Ocsigen Start|a ready-to-use base for client/server applications (users, sessions, notifications)
ocsigen-toolkit|Ocsigen Toolkit|client/server UI widgets
ocsigenserver|Ocsigen Server|the web server
js_of_ocaml|js_of_ocaml|the OCaml-to-JavaScript and WebAssembly compiler
lwt|Lwt|cooperative threading (promises) for OCaml
tyxml|TyXML|build statically correct HTML and SVG
ocsipersist|Ocsipersist|persistent key/value storage
ocsigen-i18n|Ocsigen i18n|internationalisation
reactiveData|ReactiveData|incremental reactive data structures
wodoc|Wodoc|the documentation tool that builds this site
"
# The projects the menu declares, in its own order; tuto is the doc entry point
# rather than a library, so the menu files it under Doc and it leads here.
menu_projects="tuto $(sed -n 's/.*drawermainmenu-project" data-wodoc-page="\([^"]*\)".*/\1/p' "$MENU")"

for id in $menu_projects; do
  grep -q "^$id|" <<<"$projects_table" ||
    { echo "build.sh: doc/menu.html has project '$id' with no entry in projects_table (add its name and description above)" >&2; exit 1; }
done
while IFS='|' read -r id _; do
  [ -n "$id" ] || continue
  grep -qw "$id" <<<"$menu_projects" ||
    { echo "build.sh: projects_table lists '$id', which doc/menu.html no longer declares (drop it above, or restore it in the menu)" >&2; exit 1; }
done <<<"$projects_table"

{
cat <<'EOF'
# Ocsigen

> Ocsigen is an advanced framework for developing client/server web and mobile
> applications in OCaml, with strong static typing all the way across the
> client/server boundary. This file indexes the Markdown documentation of the
> whole project for AI/LLM consumption; every linked page is available as
> Markdown, and each project also ships a full dump at
> /<project>/dev/llms-full.txt.

## Start here
- [Tutorial: basics](https://ocsigen.org/tuto/dev/basics.md): write a complete client/server application, the recommended starting point
- [Tutorial: server-side basics](https://ocsigen.org/tuto/dev/basics-server.md): server-side web programming with Eliom

## About Ocsigen
- [Home](https://ocsigen.org/index.md): overview of the framework
- [Installation](https://ocsigen.org/install.md): how to install the Ocsigen packages
- [Projects](https://ocsigen.org/projects.md): the libraries and tools that make up Ocsigen
- [Contributing](https://ocsigen.org/contributing.md): how to contribute

## Projects
EOF
for id in $menu_projects; do
  IFS='|' read -r _ name desc <<<"$(grep "^$id|" <<<"$projects_table")"
  echo "- [$name](https://ocsigen.org/$id/dev/llms.txt): $desc"
done
cat <<'EOF'

## Optional
- [Credits](https://ocsigen.org/credits.md): authors and history
- [Papers](https://ocsigen.org/papers.md): academic publications about Ocsigen
- [Ocsimore](https://ocsigen.org/ocsimore/latest/llms.txt): archived, a wiki/CMS built with Ocsigen
- [html_of_wiki](https://ocsigen.org/html_of_wiki/latest/llms.txt): archived, the former documentation tool
EOF
} >"$OUT/llms.txt"
echo "built llms.txt"
echo "vitrine built into $OUT"
