#!/bin/bash
# Build one version of the Js_of_ocaml documentation (manual + API) into
# wodoc/js_of_ocaml/<label>/, themed with the Ocsigen chrome.
#
# Js_of_ocaml is a modern dune project with SEVERAL packages (js_of_ocaml,
# js_of_ocaml-lwt, -tyxml, -toplevel, -ppx, -ppx_deriving_json, -compiler,
# wasm_of_ocaml-compiler) but NO client/server split, so `dune build @doc`
# (plain odoc) builds them all into one tree — no odoc-driver needed. The
# manual lives in the js_of_ocaml package (manual/*.mld, converted from
# manual/*.wiki on the doc branch) alongside the API; its few cross-package
# references (to -lwt/-tyxml/-toplevel) are linked by resolve-siblings.py since
# odoc only resolves along dependency edges.
#
# Every generated page is wrapped in the site template by `wodoc assemble`,
# mirroring odoc's whole package tree so relative page-to-page links keep
# working. Internal links stay version-relative via the literal {{base}} token
# (report §10 #3); only the version <select> is absolute, via {{pub}}.
#
# Js_of_ocaml is maintained externally: this builds from a detached worktree of
# a DOC branch (wodoc-doc off master = dev; wodoc-doc-6.3.1 off the 6.3.1 tag =
# latest) and never touches the maintainers' checkout.
#
# Usage: build.sh <label> <git-ref> [opam-switch]
#   label        output subdir / version label (e.g. dev, 6.3.1); NEVER "latest" (#11)
#   git-ref      branch/tag carrying manual/*.mld (wodoc-doc / wodoc-doc-6.3.1)
#   opam-switch  switch providing odoc + js_of_ocaml deps (default: ocsigen-modernize)
#
#   WODOC   path to the wodoc binary (default: wodoc from PATH/opam)
#   JSOO    path to the js_of_ocaml checkout
#   LATEST  if non-empty, also repoint the `latest` symlink at this build
#   DEMOS   if non-empty, build the interactive examples (toplevel, boulderdash,
#           …) and ship them under <label>/js_of_ocaml/files/ (heavier build)
set -e

LABEL="$1"
REF="$2"
SWITCH="${3:-ocsigen-modernize}"
[ -n "$LABEL" ] && [ -n "$REF" ] || { echo "usage: build.sh <label> <git-ref> [switch]" >&2; exit 2; }

HERE="$(cd "$(dirname "$0")" && pwd)"
WODOC="${WODOC:-wodoc}"
JSOO="${JSOO:-/home/balat/prog/kroko/ocsigen/js_of_ocaml}"
OUT="$HERE/$LABEL"
PUB="${PUB:-/wodoc/js_of_ocaml}"
LATEST="${LATEST:-}"

eval "$(opam env --switch="$SWITCH" --set-switch)"

# Build the doc in a detached worktree so the maintainers' checkout is untouched.
WT="$(mktemp -d /home/balat/temp/jsoo-doc-XXXXXX)"
cleanup() { git -C "$JSOO" worktree remove --force "$WT" 2>/dev/null || true; }
trap cleanup EXIT
git -C "$JSOO" worktree add --detach "$WT" "$REF"
(cd "$WT" && dune build @doc)
if [ -n "$DEMOS" ]; then
  # The interactive examples linked from the "Try it" manual section. The doc
  # Makefile's cp-examples target builds them and copies into manual/files/.
  (cd "$WT" && make -C doc cp-examples) || echo "WARN: demo build failed, skipping" >&2
fi
SRC="$WT/_build/default/_doc/_html"
[ -d "$SRC/js_of_ocaml" ] || { echo "no js_of_ocaml package output in $SRC" >&2; exit 1; }

rm -rf "$OUT"
mkdir -p "$OUT"

# Manual left-column nav, from a CANONICAL menu kept here (not the per-branch
# manual/menu.wiki, so the nav stays identical across versions). It points at the
# manual pages (under js_of_ocaml/) and the curated API page.
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

# Assemble every page across ALL package subtrees, mirroring odoc's layout. The
# current project is always js_of_ocaml. Skip odoc's own support dir and the
# top-level package-list index (replaced by a redirect below).
(cd "$SRC" && find . -name '*.html' -not -path './odoc.support/*' -not -path './index.html') \
  | while read -r page; do
  rel="${page#./}"
  [ "$rel" = "index.html" ] && continue
  slashes="${rel//[!\/]/}"; depth=${#slashes}
  if [ "$depth" -eq 0 ]; then base="."; else
    base=""; for _ in $(seq 1 "$depth"); do base="../$base"; done; base="${base%/}"
  fi
  mkdir -p "$OUT/$(dirname "$rel")"
  "$WODOC" assemble --template "$TMPL" --current "js_of_ocaml" --base "$base" \
    "$SRC/$rel" >"$OUT/$rel"
  # Link js_of_ocaml's cross-package refs (to sibling -lwt/-tyxml/-toplevel) to
  # their subtree in this same version output.
  python3 "$HERE/resolve-siblings.py" "$base" "$OUT/$rel"
done

rm -f "$TMPL" "$NAV_MANUAL" "$VERSIONS"

# Manual assets (the performance graphs referenced by {{image:files/…}}, plus
# any built demos) live under the manual's files/ dir; mirror them next to the
# manual pages (which odoc puts under js_of_ocaml/).
if [ -d "$WT/manual/files" ]; then
  mkdir -p "$OUT/js_of_ocaml/files"
  cp -R "$WT/manual/files/." "$OUT/js_of_ocaml/files/"
fi

# Interactive "Try it" demos (toplevel, boulderdash, …). They are version-
# independent and large (the toplevel alone is ~27 MB), so rather than rebuild
# and commit them per version we keep ONE pre-built copy in demos/ (taken from a
# past js_of_ocaml build) and symlink it into each version's files/. GitHub Pages
# follows directory symlinks (same as the `latest` symlink, report §10 #4).
if [ -d "$HERE/demos" ]; then
  mkdir -p "$OUT/js_of_ocaml/files"
  for d in "$HERE"/demos/*/; do
    name="$(basename "$d")"
    # from <ver>/js_of_ocaml/files/<demo> up to wodoc/js_of_ocaml/, then demos/
    ln -sfn "../../../demos/$name" "$OUT/js_of_ocaml/files/$name"
  done
fi

# Landing: the version root redirects to the package home (manual overview).
cat >"$OUT/index.html" <<EOF
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8"/>
  <meta http-equiv="refresh" content="0; url=js_of_ocaml/index.html"/>
  <link rel="canonical" href="js_of_ocaml/index.html"/>
  <title>Js_of_ocaml documentation</title>
</head>
<body><p>Redirecting to the <a href="js_of_ocaml/index.html">Js_of_ocaml documentation</a>.</p></body>
</html>
EOF

# odoc's bundled highlight.js + our tweaks, at the version root.
SF="$(mktemp -d)"; odoc support-files -o "$SF" >/dev/null 2>&1 \
  && cp "$SF/highlight.pack.js" "$OUT/highlight.pack.js"; rm -rf "$SF"
cp "$HERE/jsoo-highlight.js" "$OUT/jsoo-highlight.js"

if [ -n "$LATEST" ]; then
  ln -sfn "$LABEL" "$HERE/latest"
  echo "latest -> $LABEL"
fi

echo "built js_of_ocaml $LABEL: $(find "$OUT" -name '*.html' | wc -l) pages -> $OUT"
