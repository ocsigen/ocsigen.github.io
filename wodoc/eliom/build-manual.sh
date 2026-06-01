#!/bin/bash
# Build the Eliom manual (wikicreole, in the project's wikidoc branch) as themed
# .mld pages under wodoc/eliom/<label>/manual/.
#
# Unlike the API (odoc-driver), the manual goes through the wodoc pipeline so its
# presentational markers work: convert (wiki -> .mld) -> preprocess -> odoc
# (compile/link/html-generate) -> assemble. Cross-page references resolve because
# all pages are compiled together; API references are best-effort.
#
# Usage: build-manual.sh <label> [opam-switch] [eliom-git-ref]
set -e

LABEL="$1"
SWITCH="${2:-ocsigen-modernize}"
REF="${3:-wikidoc}"   # the manual lives in the wikidoc branch
[ -n "$LABEL" ] || { echo "usage: build-manual.sh <label> [switch] [ref]" >&2; exit 2; }

HERE="$(cd "$(dirname "$0")" && pwd)"
WODOC="${WODOC:-wodoc}"
ELIOM_SRC="${ELIOM_SRC:-/home/balat/prog/kroko/ocsigen/eliom}"
OUT="$HERE/$LABEL/manual"
BASE="/wodoc/eliom/$LABEL"

eval "$(opam env --switch="$SWITCH" --set-switch)"

WORK="$(mktemp -d /home/balat/temp/eliom-man-XXXXXX)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/odoc" "$WORK/html"
rm -rf "$OUT"; mkdir -p "$OUT"

PAGES=$(git -C "$ELIOM_SRC" ls-tree -r --name-only "$REF" -- doc/dev/manual \
        | grep '\.wiki$' | grep -vE 'menu\.wiki|illustrations')

# 1. wiki -> .mld -> preprocess -> odoc compile (all pages, so cross-refs resolve)
for path in $PAGES; do
  name=$(basename "$path" .wiki)
  git -C "$ELIOM_SRC" show "$REF:$path" > "$WORK/$name.wiki"
  # the manual has no side; its bare <<a_api|...>> references are server-side,
  # linked relatively into the server API (../eliom.server/...).
  "$WODOC" convert --api-side server "$WORK/$name.wiki" > "$WORK/$name.mld"
  "$WODOC" preprocess "$WORK/$name.mld" > "$WORK/pp-$name.mld"
  # --package gives the pages a common parent so inter-chapter {{!page-X}}
  # references resolve.
  odoc compile "$WORK/pp-$name.mld" --package eliom -I "$WORK/odoc" \
    -o "$WORK/odoc/page-$name.odoc" 2>/dev/null
done

# 2. link + html-generate
for o in "$WORK"/odoc/page-*.odoc; do
  odoc link "$o" -I "$WORK/odoc" -o "${o}l" 2>/dev/null
done
for ol in "$WORK"/odoc/page-*.odocl; do
  odoc html-generate "$ol" -o "$WORK/html" 2>/dev/null
done

# 3. manual navigation (from the wikicreole menu) + per-version template
# The left column shows both the manual nav (from menu.wiki) and the API nav
# (server side by default; from the deriving branch's server.indexdoc), so one
# can jump from the manual to the API. The unified template.html is used with an
# empty side (manual prose carries no server/client colour).
API_REF="${API_REF:-deriving}"
NAV_MANUAL="$(mktemp)"; NAV_API="$(mktemp)"
git -C "$ELIOM_SRC" show "$REF:doc/dev/manual/menu.wiki" > "$WORK/menu.wiki"
git -C "$ELIOM_SRC" show "$API_REF:doc/server.indexdoc" > "$WORK/server.indexdoc"
python3 "$HERE/gen-manual-nav.py" "$WORK/menu.wiki" "$BASE" > "$NAV_MANUAL"
python3 "$HERE/gen-nav.py" "$WORK/server.indexdoc" "$BASE" eliom.server > "$NAV_API"
TMPL="$(mktemp)"
sed -e "s#{{base}}#$BASE#g" \
    -e "s#{{side}}##g" \
    -e "s#<option value=\"$BASE/#<option selected value=\"$BASE/#" \
    -e "/{{manual_nav}}/r $NAV_MANUAL" -e "/{{manual_nav}}/d" \
    -e "/{{api_nav}}/r $NAV_API" -e "/{{api_nav}}/d" \
    "$HERE/template.html" > "$TMPL"

# 4. assemble each generated page (odoc puts them under html/<package>/); the
#    current page is highlighted in the manual nav via --current <page>.
for f in "$WORK"/html/eliom/*.html; do
  name=$(basename "$f")
  "$WODOC" assemble --template "$TMPL" --current "${name%.html}" "$f" > "$OUT/$name"
done

rm -f "$NAV_MANUAL" "$NAV_API" "$TMPL"
echo "built eliom manual $LABEL: $(find "$OUT" -name '*.html' | wc -l) pages -> $OUT"
