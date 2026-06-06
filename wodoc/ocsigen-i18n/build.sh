#!/bin/bash
# Build one version of the Ocsigen i18n documentation (manual + API) into
# wodoc/ocsigen-i18n/<label>/, themed with the Ocsigen chrome.
#
# ocsigen-i18n is a single package with one (ppx) library and no client/server
# split, so — unlike Eliom/Toolkit — `dune build @doc` (plain odoc) is enough;
# no odoc-driver, no two-switch dance (report §10 #1 does not apply). The manual
# (doc/*.mld) and the API are compiled together in a detached worktree of the
# requested ref, so the package's {{!page-X}} / {!Module} references resolve.
# Each generated HTML page is then wrapped in the site template by
# `wodoc assemble`, mirroring odoc's directory layout so its relative
# page-to-page links keep working.
#
# Internal links (nav + template) stay version-relative: they use the literal
# {{base}} token, filled by `wodoc assemble --base` per page with the relative
# path to the version root, so a version's pages never mention the version and
# the tree works unchanged under both /<version>/ and the `latest` symlink
# (report §10 #3). Only the version <select> is absolute, via {{pub}}.
#
# Usage: build.sh <label> <git-ref> [opam-switch]
#   label        output subdir and version label (e.g. 5.0); NEVER "latest" (#11)
#   git-ref      branch or tag of ocsigen-i18n carrying doc/*.mld (latest-mli-odoc)
#   opam-switch  switch providing odoc + the project deps (default: 5.4.0)
#
#   WODOC          path to the wodoc binary (default: wodoc from PATH/opam)
#   I18N           path to the ocsigen-i18n checkout
#   MANUAL_VER     wikidoc manual version directory (default: 5.0)
#   LATEST         if non-empty, also repoint the `latest` symlink at this build
set -e

LABEL="$1"
REF="$2"
SWITCH="${3:-5.4.0}"
[ -n "$LABEL" ] && [ -n "$REF" ] || { echo "usage: build.sh <label> <git-ref> [switch]" >&2; exit 2; }

HERE="$(cd "$(dirname "$0")" && pwd)"
WODOC="${WODOC:-wodoc}"
I18N="${I18N:-/home/balat/prog/kroko/ocsigen/ocsigen-i18n}"
OUT="$HERE/$LABEL"
BASE="{{base}}"
PUB="${PUB:-/wodoc/ocsigen-i18n}"
MANUAL_VER="${MANUAL_VER:-5.0}"
LATEST="${LATEST:-}"

eval "$(opam env --switch="$SWITCH" --set-switch)"

# Build the doc in a detached worktree so the main checkout is untouched.
WT="$(mktemp -d /home/balat/temp/i18n-doc-XXXXXX)"
cleanup() { git -C "$I18N" worktree remove --force "$WT" 2>/dev/null || true; }
trap cleanup EXIT
git -C "$I18N" worktree add --detach "$WT" "$REF"
(cd "$WT" && dune build @doc)
SRC="$WT/_build/default/_doc/_html/ocsigen-i18n"
[ -d "$SRC" ] || { echo "no ocsigen-i18n output in $SRC" >&2; exit 1; }

rm -rf "$OUT"
mkdir -p "$OUT"

# Left-column navigation: the manual (from the wikidoc menu of the right version).
NAV_MANUAL="$(mktemp)"
git -C "$I18N" show "wikidoc:doc/$MANUAL_VER/manual/menu.wiki" >"$WT/menu.wiki"
python3 "$HERE/gen-manual-nav.py" "$WT/menu.wiki" "$BASE" >"$NAV_MANUAL"

# Version <select> options: every sibling version directory (label `latest` is
# the symlink, listed first; the JS marks the one matching the URL).
VERSIONS="$(mktemp)"
{
  echo "              <option value=\"latest\">latest</option>"
  for d in "$HERE"/*/; do
    v="$(basename "$d")"
    [ "$v" = latest ] && continue
    echo "              <option value=\"$v\">$v</option>"
  done
} >"$VERSIONS"

# Build the page template: expand {{leftnav}} into BOTH slots (left column and
# burger drawer), then fill the version/manual holes and the publish base.
TMPL="$(mktemp)"
sed -e "/{{leftnav}}/r $HERE/leftnav.html" -e "/{{leftnav}}/d" "$HERE/template.html" \
  | sed -e "s#{{pub}}#$PUB#g" \
        -e "/{{versions}}/r $VERSIONS" -e "/{{versions}}/d" \
        -e "/{{manual_nav}}/r $NAV_MANUAL" -e "/{{manual_nav}}/d" \
  >"$TMPL"

# Assemble every generated page, mirroring odoc's ocsigen-i18n/ subtree. The
# "current" id highlights the matching nav entry: a manual page x.html -> x;
# an API module page -> its top module name (Ppx).
(cd "$SRC" && find . -name '*.html') | while read -r page; do
  rel="${page#./}"
  case "$rel" in
    */*) current="${rel%%/*}" ;;            # API module pages: top dir (Ppx)
    *.html) current="${rel%.html}" ;;       # manual pages at the root
  esac
  # relative path from this page to the version root.
  slashes="${rel//[!\/]/}"; depth=${#slashes}
  if [ "$depth" -eq 0 ]; then base="."; else
    base=""; for _ in $(seq 1 "$depth"); do base="../$base"; done; base="${base%/}"
  fi
  mkdir -p "$OUT/$(dirname "$rel")"
  "$WODOC" assemble --template "$TMPL" --current "$current" --base "$base" \
    "$SRC/$rel" >"$OUT/$rel"
done

rm -f "$TMPL" "$NAV_MANUAL" "$VERSIONS"

# Ship odoc's bundled highlight.js at the version root so
# {{base}}/highlight.pack.js resolves, plus our ppx-aware tweaks.
SF="$(mktemp -d)"; odoc support-files -o "$SF" >/dev/null 2>&1 \
  && cp "$SF/highlight.pack.js" "$OUT/highlight.pack.js"; rm -rf "$SF"
cp "$HERE/i18n-highlight.js" "$OUT/i18n-highlight.js"

# Optionally (re)point `latest` at this build: a relative git symlink.
if [ -n "$LATEST" ]; then
  ln -sfn "$LABEL" "$HERE/latest"
  echo "latest -> $LABEL"
fi

echo "built ocsigen-i18n $LABEL: $(find "$OUT" -name '*.html' | wc -l) pages -> $OUT"
