#!/bin/bash
# Build the html_of_wiki documentation into wodoc/html_of_wiki/<label>/, themed
# with the Ocsigen chrome.
#
# html_of_wiki is the legacy wikicreole site generator being superseded by wodoc.
# Its opam package exposes NO public library API (common/client are internal,
# ohow/wit are executables), so there is nothing useful for `dune build @doc` to
# render. Its documentation is a single-page MANUAL (doc/2.0/manual/intro.wiki,
# self-describing wikicreole) whose menu links to in-page anchors.
#
# So, like tuto, this is a MANUAL-ONLY build driven by odoc directly (no
# dune/odoc-driver). The page was converted once with `wodoc convert` and is
# kept here as a tracked source (mld/index.mld), like ocsimore — the legacy repo
# is not touched. The in-page anchor menu drives a custom left nav
# (gen-anchor-nav.py: each [[#a|T]] -> index.html#a).
#
# Single version (2.0, the only manual version). Internal links stay relative via
# {{base}} (one page, so base="."); the version <select> uses {{pub}}.
#
# Usage: build.sh [label] [opam-switch]
#   label        output subdir / version label (default: 2.0); NEVER "latest" (#11)
#   opam-switch  switch providing odoc (default: 5.4.0)
#
#   WODOC   path to the wodoc binary (default: wodoc from PATH/opam)
#   LATEST  if non-empty (default here: set), also repoint the `latest` symlink
set -e

LABEL="${1:-2.0}"
SWITCH="${2:-5.4.0}"

HERE="$(cd "$(dirname "$0")" && pwd)"
WODOC="${WODOC:-wodoc}"
OUT="$HERE/$LABEL"
PUB="${PUB:-/wodoc/html_of_wiki}"
LATEST="${LATEST-1}"   # single version: keep `latest` pointed here by default

eval "$(opam env --switch="$SWITCH" --set-switch)"

WORK="$(mktemp -d /home/balat/temp/how-doc-XXXXXX)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/odoc" "$WORK/html"
rm -rf "$OUT"; mkdir -p "$OUT"

# 1. preprocess the single .mld page ({%wodoc:%} markers -> sentinels), then odoc
#    compile/link/html-generate under the html_of_wiki package.
"$WODOC" preprocess "$HERE/mld/index.mld" > "$WORK/pp-index.mld"
odoc compile "$WORK/pp-index.mld" --package html_of_wiki -I "$WORK/odoc" \
  -o "$WORK/odoc/page-index.odoc" 2>>"$WORK/odoc.log"
odoc link "$WORK/odoc/page-index.odoc" -I "$WORK/odoc" \
  -o "$WORK/odoc/page-index.odocl" 2>>"$WORK/odoc.log"
odoc html-generate "$WORK/odoc/page-index.odocl" -o "$WORK/html" 2>>"$WORK/odoc.log"

SRC="$WORK/html/html_of_wiki"
[ -f "$SRC/index.html" ] || { echo "no html_of_wiki output in $SRC" >&2; cat "$WORK/odoc.log"; exit 1; }

# 2. left-column navigation, from the in-page-anchor menu.
NAV_MANUAL="$(mktemp)"
python3 "$HERE/gen-anchor-nav.py" "$HERE/menu.wiki" "{{base}}" >"$NAV_MANUAL"

# version <select> options: every sibling version directory.
VERSIONS="$(mktemp)"
{
  echo "              <option value=\"latest\">latest</option>"
  for d in "$HERE"/*/; do
    v="$(basename "$d")"
    [ "$v" = latest ] && continue
    echo "              <option value=\"$v\">$v</option>"
  done
} >"$VERSIONS"

# 3. build the page template: expand {{leftnav}} into both slots, fill holes.
TMPL="$(mktemp)"
sed -e "/{{leftnav}}/r $HERE/leftnav.html" -e "/{{leftnav}}/d" "$HERE/template.html" \
  | sed -e "s#{{pub}}#$PUB#g" \
        -e "/{{versions}}/r $VERSIONS" -e "/{{versions}}/d" \
        -e "/{{manual_nav}}/r $NAV_MANUAL" -e "/{{manual_nav}}/d" \
  >"$TMPL"

# 4. assemble the page (renders {%wodoc:%} markers + wraps in chrome). --flat
#    because the first content is a <<div class="chapterintro">> wrapper that
#    straddles odoc's preamble/content boundary (report §6quinquies).
"$WODOC" assemble --template "$TMPL" --current index --base "." --flat \
  "$SRC/index.html" >"$OUT/index.html"

rm -f "$TMPL" "$NAV_MANUAL" "$VERSIONS"

# 5. assets: odoc's bundled highlight.js + our starter at the version root.
SF="$(mktemp -d)"; odoc support-files -o "$SF" >/dev/null 2>&1 \
  && cp "$SF/highlight.pack.js" "$OUT/highlight.pack.js"; rm -rf "$SF"
cp "$HERE/how-highlight.js" "$OUT/how-highlight.js"

if [ -n "$LATEST" ]; then
  ln -sfn "$LABEL" "$HERE/latest"
  echo "latest -> $LABEL"
fi

echo "built html_of_wiki $LABEL: $(find "$OUT" -name '*.html' | wc -l) pages -> $OUT"
