#!/bin/bash
# Build the Ocsimore documentation into wodoc/ocsimore/<label>/, themed with the
# Ocsigen chrome.
#
# Ocsimore is an ARCHIVED project (last touched 2014, oasis/ocamlbuild, depends
# on a dev-era Eliom). It no longer builds with the modern dune/odoc toolchain,
# so — unlike the live projects — we do NOT run `dune build @doc`. Instead:
#
#   * Manual: the wikicreole manual (doc/manual-wiki/*.wiki in the ocsimore repo)
#     was converted once to odoc .mld pages, kept in mld/ here. Each .mld is a
#     standalone odoc page (compile -> link -> html-generate), then wrapped in the
#     site template by `wodoc assemble`. The manual documents the wikicreole
#     syntax itself, so its <<...>>, [[...]], @@...@@ examples are kept verbatim
#     inside odoc code spans / verbatim blocks — never interpreted.
#   * API: the .mli can't be recompiled (dead Eliom deps), so the existing
#     generated API (the old html_of_wiki/ocamldoc output, still live) was
#     mirrored once into api-snapshot/ with its site-root chrome paths made
#     absolute. build.sh copies it verbatim into <label>/api/. It keeps its
#     original (old) theme — it is a frozen archive.
#
# Internal manual links use the literal {{base}} token, filled per page by
# `wodoc assemble --base` with the relative path to the version root, so the tree
# works under both /<version>/ and the `latest` symlink (report §10 #3). Only the
# version <select> is absolute, via {{pub}}.
#
# Usage: build.sh <label> [opam-switch]
#   label        output subdir and version label (e.g. 0.5); NEVER "latest" (#11)
#   opam-switch  switch providing odoc (default: 5.4.0)
#
#   WODOC    path to the wodoc binary (default: wodoc from PATH/opam)
#   OCSIMORE path to the ocsimore checkout (for menu.wiki); falls back to ./menu.wiki
#   LATEST   if non-empty, also repoint the `latest` symlink at this build
set -e

LABEL="$1"
SWITCH="${2:-5.4.0}"
[ -n "$LABEL" ] || { echo "usage: build.sh <label> [switch]" >&2; exit 2; }

HERE="$(cd "$(dirname "$0")" && pwd)"
WODOC="${WODOC:-wodoc}"
OUT="$HERE/$LABEL"
PUB="${PUB:-/wodoc/ocsimore}"
LATEST="${LATEST:-}"

# Manual pages, in menu order (index is the landing).
PAGES="index intro wiki forum user misc guidelines config admin-interface"

eval "$(opam env --switch="$SWITCH" --set-switch)"

WORK="$(mktemp -d /home/balat/temp/ocsimore-doc-XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

# 1. Compile each standalone .mld page to HTML with odoc.
mkdir -p "$WORK/html"
for p in $PAGES; do
  odoc compile "$HERE/mld/$p.mld" -o "$WORK/page-$p.odoc" 2>/dev/null
  odoc link "$WORK/page-$p.odoc" -o "$WORK/page-$p.odocl" 2>/dev/null
  odoc html-generate "$WORK/page-$p.odocl" -o "$WORK/html" 2>/dev/null
done
SRC="$WORK/html"

rm -rf "$OUT"
mkdir -p "$OUT"

# 2. Manual left-column navigation, from the wikicreole menu.
MENU="$HERE/menu.wiki"
[ -n "$OCSIMORE" ] && [ -f "$OCSIMORE/doc/manual-wiki/menu.wiki" ] && MENU="$OCSIMORE/doc/manual-wiki/menu.wiki"
NAV_MANUAL="$(mktemp)"
python3 "$HERE/gen-manual-nav.py" "$MENU" "{{base}}" >"$NAV_MANUAL"

# 3. Version <select> options: every sibling version directory.
VERSIONS="$(mktemp)"
{
  echo "              <option value=\"latest\">latest</option>"
  for d in "$HERE"/*/; do
    v="$(basename "$d")"
    [ "$v" = latest ] && continue
    echo "              <option value=\"$v\">$v</option>"
  done
} >"$VERSIONS"

# 4. Page template: expand {{leftnav}} into both slots, fill the holes.
TMPL="$(mktemp)"
sed -e "/{{leftnav}}/r $HERE/leftnav.html" -e "/{{leftnav}}/d" "$HERE/template.html" \
  | sed -e "s#{{pub}}#$PUB#g" \
        -e "/{{versions}}/r $VERSIONS" -e "/{{versions}}/d" \
        -e "/{{manual_nav}}/r $NAV_MANUAL" -e "/{{manual_nav}}/d" \
  >"$TMPL"

# 5. Assemble each manual page (current = page name highlights its nav entry).
for p in $PAGES; do
  [ -f "$SRC/$p.html" ] || continue
  "$WODOC" assemble --template "$TMPL" --current "$p" --base "." \
    "$SRC/$p.html" >"$OUT/$p.html"
done

rm -f "$TMPL" "$NAV_MANUAL" "$VERSIONS"

# 6. Manual assets: the wikicreole cheat-sheet image referenced by wiki.mld.
[ -f "$HERE/mld/creole_cheat_sheet.png" ] && cp "$HERE/mld/creole_cheat_sheet.png" "$OUT/"

# 7. API: copy the frozen mirror of the original generated API verbatim.
if [ -d "$HERE/api-snapshot" ]; then
  cp -a "$HERE/api-snapshot" "$OUT/api"
fi

# 8. odoc's bundled highlight.js + our tweaks, at the version root.
SF="$(mktemp -d)"; odoc support-files -o "$SF" >/dev/null 2>&1 \
  && cp "$SF/highlight.pack.js" "$OUT/highlight.pack.js"; rm -rf "$SF"
cp "$HERE/ocsimore-highlight.js" "$OUT/ocsimore-highlight.js"

# 9. Optionally (re)point `latest` at this build.
if [ -n "$LATEST" ]; then
  ln -sfn "$LABEL" "$HERE/latest"
  echo "latest -> $LABEL"
fi

echo "built ocsimore $LABEL: $(find "$OUT" -name '*.html' | wc -l) html files -> $OUT"
