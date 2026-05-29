#!/bin/bash
# Build one version of the Ocsigen Server documentation (manual + API) into
# wodoc/ocsigenserver/<label>/, themed with the Ocsigen chrome.
#
# The manual (doc/*.mld) and the API (.mli) are compiled together by
# `dune build @doc` (odoc) in a detached worktree of the requested ref, so the
# package's cross-references resolve. Each generated HTML page is then wrapped
# in the site template by `wodoc assemble`, mirroring odoc's directory layout
# so odoc's relative page-to-page links keep working. Asset paths in the
# template are absolute (/wodoc/..., /css/...), so they are depth-independent.
# odoc's own stylesheet is intentionally not used (see /wodoc/ocsigen-odoc.css).
#
# Usage: build.sh <label> <git-ref> [opam-switch]
#   label        output subdir and version label (e.g. latest, dev)
#   git-ref      branch or tag of ocsigenserver to build (must carry doc/*.mld)
#   opam-switch  switch providing odoc + the project deps (default: 5.4.0)
#
#   WODOC          path to the wodoc binary (default: wodoc from PATH/opam)
#   OCSIGENSERVER  path to the ocsigenserver checkout
set -e

LABEL="$1"
REF="$2"
SWITCH="${3:-5.4.0}"
[ -n "$LABEL" ] && [ -n "$REF" ] || { echo "usage: build.sh <label> <git-ref> [switch]" >&2; exit 2; }

HERE="$(cd "$(dirname "$0")" && pwd)"
WODOC="${WODOC:-wodoc}"
SERVER="${OCSIGENSERVER:-/home/balat/prog/kroko/ocsigen/ocsigenserver}"
OUT="$HERE/$LABEL"
BASE="/wodoc/ocsigenserver/$LABEL"

eval "$(opam env --switch="$SWITCH" --set-switch)"

# Build the doc in a detached worktree so the main checkout is untouched.
WT="$(mktemp -d /home/balat/temp/oss-doc-XXXXXX)"
cleanup() { git -C "$SERVER" worktree remove --force "$WT" 2>/dev/null || true; }
trap cleanup EXIT
git -C "$SERVER" worktree add --detach "$WT" "$REF"
(cd "$WT" && dune build @doc)
HTML="$WT/_build/default/_doc/_html"

rm -rf "$OUT"
mkdir -p "$OUT"

# Per-version template: substitute the absolute base path and pre-select the
# current version in the version selector.
TMPL="$(mktemp)"
sed -e "s#{{base}}#$BASE#g" \
    -e "s#<option value=\"$BASE/#<option selected value=\"$BASE/#" \
    "$HERE/template.html" >"$TMPL"

# Assemble every generated page, mirroring odoc's ocsigenserver/ subtree.
# The "current" id is the page's own name so the matching entry is highlighted
# in the left-column navigation: a manual page x.html -> x; module pages keep
# their subtree name (not in the manual nav, so nothing is highlighted).
(cd "$HTML/ocsigenserver" && find . -name '*.html') | while read -r page; do
  rel="${page#./}"
  dir="$(dirname "$rel")"
  if [ "$dir" = "." ]; then current="$(basename "$rel" .html)"; else current="$dir"; fi
  mkdir -p "$OUT/$dir"
  "$WODOC" assemble --template "$TMPL" --current "$current" \
    "$HTML/ocsigenserver/$rel" >"$OUT/$rel"
done

rm -f "$TMPL"

# The project home redirects to the first manual page (Quick start). The API
# reference lives on its own page (api.html); the manual navigation is the
# left-column doctree, so the landing needs no table of contents of its own.
cat >"$OUT/index.html" <<EOF
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8"/>
  <meta http-equiv="refresh" content="0; url=quickstart.html"/>
  <link rel="canonical" href="quickstart.html"/>
  <title>Ocsigen Server documentation</title>
</head>
<body><p>Redirecting to the <a href="quickstart.html">Ocsigen Server manual</a>.</p></body>
</html>
EOF

echo "built $LABEL: $(find "$OUT" -name '*.html' | wc -l) pages -> $OUT"
