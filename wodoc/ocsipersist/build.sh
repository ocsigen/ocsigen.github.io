#!/bin/bash
# Build one version of the Ocsipersist documentation (API only) into
# wodoc/ocsipersist/<label>/, themed with the Ocsigen chrome.
#
# Ocsipersist is a multi-PACKAGE dune project (the frontend `ocsipersist`, the
# shared `ocsipersist-lib`, and three backends sqlite/dbm/pgsql each with a
# `-config` companion) but has NO client/server split and NO wikicreole manual,
# so — like tyxml/i18n — plain `dune build @doc` (odoc) is enough; no
# odoc-driver. We assemble the WHOLE _doc/_html tree (all packages), with the
# main package landing (doc/index.mld) as the version home. The cross-package
# links between the backend index.mld pages are explicit relative URLs that
# already resolve inside the tree, so no resolve-siblings pass is needed.
#
# Each generated page is wrapped in the site template by `wodoc assemble`,
# mirroring odoc's directory layout so its relative page-to-page links keep
# working. Internal links stay version-relative via the literal {{base}} token
# (report §10 #3), filled per page with the path to the version root; only the
# version <select> is absolute, via {{pub}}.
#
# Usage: build.sh <label> <git-ref> [opam-switch]
#   label        output subdir / version label (e.g. dev, 2.0.0); NEVER "latest" (#11)
#   git-ref      branch/tag carrying doc/index.mld (wodoc-doc / wodoc-doc-latest)
#   opam-switch  switch providing odoc + ocsipersist deps (default: 5.4.0)
#
#   WODOC        path to the wodoc binary (default: wodoc from PATH/opam)
#   OCSIPERSIST  path to the ocsipersist checkout
#   LATEST       if non-empty, also repoint the `latest` symlink at this build
set -e

LABEL="$1"
REF="$2"
SWITCH="${3:-5.4.0}"
[ -n "$LABEL" ] && [ -n "$REF" ] || { echo "usage: build.sh <label> <git-ref> [switch]" >&2; exit 2; }

HERE="$(cd "$(dirname "$0")" && pwd)"
WODOC="${WODOC:-wodoc}"
OCSIPERSIST="${OCSIPERSIST:-/home/balat/prog/kroko/ocsigen/ocsipersist}"
OUT="$HERE/$LABEL"
PUB="${PUB:-/wodoc/ocsipersist}"
LATEST="${LATEST:-}"

eval "$(opam env --switch="$SWITCH" --set-switch)"

# Build the doc in a detached worktree so the main checkout is untouched.
WT="$(mktemp -d /home/balat/temp/ocsipersist-doc-XXXXXX)"
cleanup() { git -C "$OCSIPERSIST" worktree remove --force "$WT" 2>/dev/null || true; }
trap cleanup EXIT
git -C "$OCSIPERSIST" worktree add --detach "$WT" "$REF"
# --profile release: the dev profile treats warning 67 (unused functor
# parameter, in ocsipersist_lib) as an error, like tyxml.
(cd "$WT" && dune build @doc --profile release)
SRC="$WT/_build/default/_doc/_html"
[ -d "$SRC/ocsipersist" ] || { echo "no ocsipersist package output in $SRC" >&2; exit 1; }

rm -rf "$OUT"
mkdir -p "$OUT"

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

# Page template: fill only the version/pub holes. The shared top menu comes from
# ../menu.html (via `wodoc assemble --menu`), and the left navigation from the
# leftnav fragment below (via --leftnav, expanded by the tool into BOTH the left
# column and the burger drawer). The nav is hand-written (no manual).
TMPL="$(mktemp)"
sed -e "s#{{pub}}#$PUB#g" "$HERE/template.html" >"$TMPL"

# Left navigation fragment: fill the version <select> and the static API nav;
# {{base}} and {{toc}} stay as holes, filled per page by `wodoc assemble`.
LEFTNAV="$(mktemp)"
sed -e "/{{versions}}/r $VERSIONS" -e "/{{versions}}/d" \
    -e "/{{manual_nav}}/r $HERE/nav.html" -e "/{{manual_nav}}/d" \
    "$HERE/leftnav.html" >"$LEFTNAV"

# Assemble every package page, mirroring odoc's tree. --current highlights the
# matching left-nav entry: the top package directory of the page (ocsipersist,
# ocsipersist-sqlite, ...); --menu-current highlights Ocsipersist in the shared
# top menu. Skip odoc's own global index/support assets.
(cd "$SRC" && find ocsipersist ocsipersist-lib ocsipersist-dbm ocsipersist-sqlite \
   ocsipersist-pgsql ocsipersist-dbm-config ocsipersist-sqlite-config \
   ocsipersist-pgsql-config -name '*.html') | while read -r rel; do
  current="${rel%%/*}"
  slashes="${rel//[!\/]/}"; depth=${#slashes}
  base=""; for _ in $(seq 1 "$depth"); do base="../$base"; done; base="${base%/}"
  mkdir -p "$OUT/$(dirname "$rel")"
  "$WODOC" assemble --template "$TMPL" --menu "$HERE/../menu.html" \
    --subproject '<p class="logo-subproject">Ocsipersist</p>' \
    --menu-current ocsipersist --leftnav "$LEFTNAV" \
    --current "$current" --base "$base" \
    "$SRC/$rel" >"$OUT/$rel"
done

rm -f "$TMPL" "$LEFTNAV" "$VERSIONS"

# Landing: the version root redirects to the main package overview.
cat >"$OUT/index.html" <<EOF
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8"/>
  <meta http-equiv="refresh" content="0; url=ocsipersist/index.html"/>
  <link rel="canonical" href="ocsipersist/index.html"/>
  <title>Ocsipersist documentation</title>
</head>
<body><p>Redirecting to the <a href="ocsipersist/index.html">Ocsipersist documentation</a>.</p></body>
</html>
EOF

# odoc's bundled highlight.js + our starter, at the version root.
SF="$(mktemp -d)"; odoc support-files -o "$SF" >/dev/null 2>&1 \
  && cp "$SF/highlight.pack.js" "$OUT/highlight.pack.js"; rm -rf "$SF"
cp "$HERE/ocsipersist-highlight.js" "$OUT/ocsipersist-highlight.js"

if [ -n "$LATEST" ]; then
  ln -sfn "$LABEL" "$HERE/latest"
  echo "latest -> $LABEL"
fi

echo "built ocsipersist $LABEL: $(find "$OUT" -name '*.html' | wc -l) pages -> $OUT"
