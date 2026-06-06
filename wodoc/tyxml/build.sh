#!/bin/bash
# Build one version of the TyXML documentation (manual + API) into
# wodoc/tyxml/<label>/, themed with the Ocsigen chrome.
#
# TyXML is a modern dune project with several packages but NO client/server
# split, so — like ocsigenserver/i18n — `dune build @doc` (plain odoc) is enough
# (no odoc-driver). We document the main package `tyxml`, which carries the
# manual (docs/*.mld, converted from docs/manual-wiki) AND the public API
# (Tyxml, Tyxml_html, Tyxml_svg, the functor libs Html_sigs/Svg_sigs/…). The
# auxiliary packages (tyxml-ppx/syntax/jsx) live on ocaml.org; the manual's ppx
# and jsx pages document their usage. Build runs in a detached worktree of the
# doc branch (dev-mli-odoc / latest-mli-odoc), with --profile release because the
# dev profile treats warning 67 (unused functor parameter) as an error.
#
# Each generated page is wrapped in the site template by `wodoc assemble`,
# mirroring odoc's tyxml/ subtree so relative page-to-page links keep working.
# Internal links stay version-relative via the literal {{base}} token (report
# §10 #3); only the version <select> is absolute, via {{pub}}.
#
# Usage: build.sh <label> <git-ref> [opam-switch]
#   label        output subdir / version label (e.g. dev, 4.6.0); NEVER "latest" (#11)
#   git-ref      branch/tag carrying docs/*.mld (dev-mli-odoc / latest-mli-odoc)
#   opam-switch  switch providing odoc + tyxml deps (default: 5.4.0)
#
#   WODOC   path to the wodoc binary (default: wodoc from PATH/opam)
#   TYXML   path to the tyxml checkout
#   LATEST  if non-empty, also repoint the `latest` symlink at this build
set -e

LABEL="$1"
REF="$2"
SWITCH="${3:-5.4.0}"
[ -n "$LABEL" ] && [ -n "$REF" ] || { echo "usage: build.sh <label> <git-ref> [switch]" >&2; exit 2; }

HERE="$(cd "$(dirname "$0")" && pwd)"
WODOC="${WODOC:-wodoc}"
TYXML="${TYXML:-/home/balat/prog/kroko/ocsigen/tyxml}"
OUT="$HERE/$LABEL"
PUB="${PUB:-/wodoc/tyxml}"
LATEST="${LATEST:-}"

eval "$(opam env --switch="$SWITCH" --set-switch)"

# Build the doc in a detached worktree so the main checkout is untouched.
WT="$(mktemp -d /home/balat/temp/tyxml-doc-XXXXXX)"
cleanup() { git -C "$TYXML" worktree remove --force "$WT" 2>/dev/null || true; }
trap cleanup EXIT
git -C "$TYXML" worktree add --detach "$WT" "$REF"
(cd "$WT" && dune build @doc --profile release)
SRC="$WT/_build/default/_doc/_html/tyxml"
[ -d "$SRC" ] || { echo "no tyxml package output in $SRC" >&2; exit 1; }

rm -rf "$OUT"
mkdir -p "$OUT"

# Manual left-column nav, from a CANONICAL menu kept here (not the per-branch
# docs/manual-wiki/menu.wiki, which drifts between versions — e.g. 4.6.0 lacks the
# "TyXML - API" heading and uses different indent levels). The manual pages are the
# same across versions, so one menu keeps the nav identical everywhere. It already
# includes the API section pointing at the curated docs/api.mld -> api.html.
NAV_MANUAL="$(mktemp)"
python3 "$HERE/gen-manual-nav.py" "$HERE/menu.wiki" "{{base}}" >"$NAV_MANUAL"

# Version <select> options: every sibling version directory.
VERSIONS="$(mktemp)"
{
  echo "              <option value=\"latest\">latest</option>"
  for d in "$HERE"/*/; do
    v="$(basename "$d")"
    [ "$v" = latest ] && continue
    echo "              <option value=\"$v\">$v</option>"
  done
} >"$VERSIONS"

# Page template: expand {{leftnav}} into both slots, fill version/manual/pub holes.
TMPL="$(mktemp)"
sed -e "/{{leftnav}}/r $HERE/leftnav.html" -e "/{{leftnav}}/d" "$HERE/template.html" \
  | sed -e "s#{{pub}}#$PUB#g" \
        -e "/{{versions}}/r $VERSIONS" -e "/{{versions}}/d" \
        -e "/{{manual_nav}}/r $NAV_MANUAL" -e "/{{manual_nav}}/d" \
  >"$TMPL"

# Assemble every page, mirroring odoc's tyxml/ subtree. Manual pages sit at the
# root (x.html -> current x); API module pages keep their subtree (top dir).
(cd "$SRC" && find . -name '*.html') | while read -r page; do
  rel="${page#./}"
  case "$rel" in
    */*) current="${rel%%/*}" ;;       # API module pages -> top module dir
    *.html) current="${rel%.html}" ;;  # manual pages at the root
  esac
  slashes="${rel//[!\/]/}"; depth=${#slashes}
  if [ "$depth" -eq 0 ]; then base="."; else
    base=""; for _ in $(seq 1 "$depth"); do base="../$base"; done; base="${base%/}"
  fi
  mkdir -p "$OUT/$(dirname "$rel")"
  "$WODOC" assemble --template "$TMPL" --current "$current" --base "$base" \
    "$SRC/$rel" >"$OUT/$rel"
done

rm -f "$TMPL" "$NAV_MANUAL" "$VERSIONS"

# Landing: the version root redirects to the manual's first page (Introduction),
# matching the historical .../manual/intro entry point.
cat >"$OUT/index.html" <<EOF
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8"/>
  <meta http-equiv="refresh" content="0; url=intro.html"/>
  <link rel="canonical" href="intro.html"/>
  <title>TyXML documentation</title>
</head>
<body><p>Redirecting to the <a href="intro.html">TyXML manual</a>.</p></body>
</html>
EOF

# odoc's bundled highlight.js + our tweaks, at the version root.
SF="$(mktemp -d)"; odoc support-files -o "$SF" >/dev/null 2>&1 \
  && cp "$SF/highlight.pack.js" "$OUT/highlight.pack.js"; rm -rf "$SF"
cp "$HERE/tyxml-highlight.js" "$OUT/tyxml-highlight.js"

if [ -n "$LATEST" ]; then
  ln -sfn "$LABEL" "$HERE/latest"
  echo "latest -> $LABEL"
fi

echo "built tyxml $LABEL: $(find "$OUT" -name '*.html' | wc -l) pages -> $OUT"