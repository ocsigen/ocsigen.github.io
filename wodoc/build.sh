#!/bin/bash
# Build the wodoc version of the site into this directory, alongside the current
# site, so both can be compared (e.g. ocsigen.org/projects vs
# ocsigen.org/wodoc/projects). No existing page is touched.
#
#   WODOC   path to the wodoc binary   (default: wodoc, from PATH/opam)
#   odoc    must be on PATH
#
# Per page, the pipeline is: preprocess -> odoc compile/link/html-generate ->
# assemble (which renders the content fragment and fills the template).
set -e

HERE="$(cd "$(dirname "$0")" && pwd)"
WODOC="${WODOC:-wodoc}"
WORK="$HERE/_work"
rm -rf "$WORK"
mkdir -p "$WORK/html"

for mld in "$HERE"/src/*.mld; do
  name="$(basename "$mld" .mld)"
  # All vitrine pages highlight "Home" in the menu. Per-page tweaks below.
  current="githubio"
  template="$HERE/template.html"
  extra=""
  case "$name" in
  projects) extra="--no-preamble" ;;             # no visible page title
  intro) template="$HERE/template-home.html"; extra="--flat" ;; # full-width home
  credits | papers | contributing)
    # converted pages carry their own project-page/rightcol layout
    template="$HERE/template-page.html"
    extra="--flat"
    ;;
  esac

  "$WODOC" preprocess "$mld" >"$WORK/$name.mld"
  odoc compile "$WORK/$name.mld" -o "$WORK/page-$name.odoc"
  odoc link "$WORK/page-$name.odoc" -o "$WORK/page-$name.odocl"
  odoc html-generate "$WORK/page-$name.odocl" -o "$WORK/html"
  "$WODOC" assemble --template "$template" --menu "$HERE/menu.html" \
    --current "$current" $extra \
    "$WORK/html/$name.html" >"$HERE/$name.html"
  echo "built $name.html"
done
