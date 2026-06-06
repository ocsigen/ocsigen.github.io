#!/bin/bash
# Build one version of the Lwt documentation (manual + API) into wodoc/lwt/<label>/,
# themed with the Ocsigen chrome.
#
# Lwt is a modern dune project with SEVERAL packages (lwt, lwt_ppx, lwt_react,
# lwt_retry) but NO client/server split, so `dune build @doc` (plain odoc) builds
# them all into one tree — no odoc-driver needed. The manual is ALREADY .mld
# (docs/manual.mld) and lives in the lwt package (docs/dune:
# `(documentation (package lwt))`); the package landing is src/core/index.mld.
# The API already uses native odoc refs ({!…}, 0 <<a_api>>) so no conversion is
# needed. The manual's one cross-package reference ({!Ppx_lwt}) is linked by
# resolve-siblings.py since odoc only resolves along dependency edges.
#
# Every generated page is wrapped in the site template by `wodoc assemble`,
# mirroring odoc's whole package tree so relative page-to-page links keep
# working. Internal links stay version-relative via the literal {{base}} token
# (report §10 #3); only the version <select> is absolute, via {{pub}}.
#
# Lwt is maintained externally: this builds from a detached worktree of a DOC
# branch (wodoc-doc off master = dev; wodoc-doc-6.0.0-beta01 off the tag =
# latest) and never touches the maintainers' checkout.
#
# Usage: build.sh <label> <git-ref> [opam-switch]
#   label        output subdir / version label (e.g. dev, 6.0.0-beta01); NEVER "latest" (#11)
#   git-ref      branch/tag to build the doc from
#   opam-switch  switch providing odoc + lwt deps (default: ocsigen-modernize)
#
#   WODOC   path to the wodoc binary (default: wodoc from PATH/opam)
#   LWT     path to the lwt checkout
#   LATEST  if non-empty, also repoint the `latest` symlink at this build
set -e

LABEL="$1"
REF="$2"
SWITCH="${3:-ocsigen-modernize}"
[ -n "$LABEL" ] && [ -n "$REF" ] || { echo "usage: build.sh <label> <git-ref> [switch]" >&2; exit 2; }

HERE="$(cd "$(dirname "$0")" && pwd)"
WODOC="${WODOC:-wodoc}"
LWT="${LWT:-/home/balat/prog/kroko/ocsigen/lwt}"
OUT="$HERE/$LABEL"
PUB="${PUB:-/wodoc/lwt}"
LATEST="${LATEST:-}"

eval "$(opam env --switch="$SWITCH" --set-switch)"

# Build the doc in a detached worktree so the maintainers' checkout is untouched.
WT="$(mktemp -d /home/balat/temp/lwt-doc-XXXXXX)"
cleanup() { git -C "$LWT" worktree remove --force "$WT" 2>/dev/null || true; }
trap cleanup EXIT
git -C "$LWT" worktree add --detach "$WT" "$REF"
(cd "$WT" && dune build @doc)
SRC="$WT/_build/default/_doc/_html"
[ -d "$SRC/lwt" ] || { echo "no lwt package output in $SRC" >&2; exit 1; }

rm -rf "$OUT"
mkdir -p "$OUT"

# Manual left-column nav, from a CANONICAL menu kept here (not a per-branch
# menu.wiki, so the nav stays identical across versions). It points at the manual
# pages and API modules (under lwt/) plus the sibling packages.
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
# current project is always lwt. Skip odoc's own support dir and the top-level
# package-list index (replaced by a redirect below).
(cd "$SRC" && find . -name '*.html' -not -path './odoc.support/*' -not -path './index.html') \
  | while read -r page; do
  rel="${page#./}"
  [ "$rel" = "index.html" ] && continue
  slashes="${rel//[!\/]/}"; depth=${#slashes}
  if [ "$depth" -eq 0 ]; then base="."; else
    base=""; for _ in $(seq 1 "$depth"); do base="../$base"; done; base="${base%/}"
  fi
  mkdir -p "$OUT/$(dirname "$rel")"
  "$WODOC" assemble --template "$TMPL" --current "lwt" --base "$base" \
    "$SRC/$rel" >"$OUT/$rel"
  # Link lwt's cross-package refs (to sibling lwt_ppx/lwt_react/lwt_retry) to
  # their subtree in this same version output.
  python3 "$HERE/resolve-siblings.py" "$base" "$OUT/$rel"
done

rm -f "$TMPL" "$NAV_MANUAL" "$VERSIONS"

# Manual assets, if the manual ever references {{image:files/…}} (none today).
if [ -d "$WT/docs/files" ]; then
  mkdir -p "$OUT/lwt/files"
  cp -R "$WT/docs/files/." "$OUT/lwt/files/"
fi

# Landing: the version root redirects to the package home (the lwt landing page).
cat >"$OUT/index.html" <<EOF
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8"/>
  <meta http-equiv="refresh" content="0; url=lwt/index.html"/>
  <link rel="canonical" href="lwt/index.html"/>
  <title>Lwt documentation</title>
</head>
<body><p>Redirecting to the <a href="lwt/index.html">Lwt documentation</a>.</p></body>
</html>
EOF

# odoc's bundled highlight.js + our tweaks, at the version root.
SF="$(mktemp -d)"; odoc support-files -o "$SF" >/dev/null 2>&1 \
  && cp "$SF/highlight.pack.js" "$OUT/highlight.pack.js"; rm -rf "$SF"
cp "$HERE/lwt-highlight.js" "$OUT/lwt-highlight.js"

if [ -n "$LATEST" ]; then
  ln -sfn "$LABEL" "$HERE/latest"
  echo "latest -> $LABEL"
fi

echo "built lwt $LABEL: $(find "$OUT" -name '*.html' | wc -l) pages -> $OUT"
