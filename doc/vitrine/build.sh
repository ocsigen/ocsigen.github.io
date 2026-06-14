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
rm -rf "$WORK"; mkdir -p "$WORK/html"

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
    $extra "$WORK/html/$name.html" >"$OUT/$name.html"
  echo "built $name.html"
done
# the homepage (/) is the intro page
cp "$OUT/intro.html" "$OUT/index.html"
rm -rf "$WORK"
echo "vitrine built into $OUT"
