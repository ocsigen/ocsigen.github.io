#!/bin/bash
# Build one version of the Ocsigen tutorial (the main manual) into
# wodoc/tuto/<label>/, themed with the Ocsigen chrome.
#
# tuto is special among the Ocsigen projects:
#  * it is MANUAL-ONLY — there is no library and no API, so there is no
#    dune/odoc-driver step: we drive odoc directly on the .mld pages (like
#    eliom's build-manual.sh), giving them a common --package parent so their
#    inter-chapter {{!page-X}} references resolve.
#  * its two versions (8.0 and dev) both live in the project's MAIN branch, as
#    sibling directories tutos/<version>/manual/ — there is no wikidoc branch
#    and no git worktree dance. The doc sources are already .mld (translated
#    from the old wikicreole with `wodoc convert`); we read them in place.
#
# All API cross-references in the manual point at OTHER Ocsigen projects (eliom,
# js_of_ocaml, …): they are emitted as native odoc refs {!Eliom...}, which do
# not resolve in this standalone build (no package loaded) and odoc renders as
# <span class="xref-unresolved">. resolve-deps.py then turns the hosted ones
# (eliom, toolkit, start, ocsigenserver) into RELATIVE cross-project links.
#
# Internal links (nav + template) stay version-relative via the literal {{base}}
# token, filled by `wodoc assemble --base` per page, so the tree works unchanged
# under both /<version>/ and the `latest` symlink (report piège #3). Only the
# version <select> is absolute, via {{pub}}.
#
# Usage: build.sh <label> [tuto-version-dir]
#   label              output subdir and version label (e.g. 8.0 or dev);
#                      NEVER "latest" (report piège #11)
#   tuto-version-dir   the tutos/<dir>/ to read .mld from (default: <label>)
#
#   WODOC   path to the wodoc binary (default: wodoc from PATH/opam)
#   TUTO    path to the tuto checkout (default: the sibling clone)
#   PUB     public URL base of the version dirs (default: /wodoc/tuto)
#   LATEST  if non-empty, also repoint the `latest` symlink at this build
set -e

LABEL="$1"
VERDIR="${2:-$LABEL}"
[ -n "$LABEL" ] || { echo "usage: build.sh <label> [tuto-version-dir]" >&2; exit 2; }

HERE="$(cd "$(dirname "$0")" && pwd)"
WODOC="${WODOC:-wodoc}"
TUTO="${TUTO:-/home/balat/prog/kroko/ocsigen/tuto}"
SRC_MANUAL="$TUTO/tutos/$VERDIR/manual"
OUT="$HERE/$LABEL"
BASE="{{base}}"
PUB="${PUB:-/wodoc/tuto}"
LATEST="${LATEST:-}"

[ -d "$SRC_MANUAL" ] || { echo "no manual dir at $SRC_MANUAL" >&2; exit 1; }

eval "$(opam env)" 2>/dev/null || true

WORK="$(mktemp -d /home/balat/temp/tuto-doc-XXXXXX)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/odoc" "$WORK/html"
rm -rf "$OUT"; mkdir -p "$OUT"

# 1. preprocess every .mld page, then odoc compile them all under one --package
#    parent so cross-chapter {{!page-X}} references resolve. menu.wiki (nav) and
#    the empty basics.md are not pages.
for mld in "$SRC_MANUAL"/*.mld; do
  name="$(basename "$mld" .mld)"
  "$WODOC" preprocess "$mld" > "$WORK/pp-$name.mld"
  odoc compile "$WORK/pp-$name.mld" --package tuto -I "$WORK/odoc" \
    -o "$WORK/odoc/page-$name.odoc" 2>>"$WORK/odoc.log"
done

# 2. link + html-generate
for o in "$WORK"/odoc/page-*.odoc; do
  odoc link "$o" -I "$WORK/odoc" -o "${o}l" 2>>"$WORK/odoc.log"
done
for ol in "$WORK"/odoc/page-*.odocl; do
  odoc html-generate "$ol" -o "$WORK/html" 2>>"$WORK/odoc.log"
done

SRC="$WORK/html/tuto"
[ -d "$SRC" ] || { echo "no tuto output in $SRC" >&2; cat "$WORK/odoc.log"; exit 1; }

# 3. cross-project API links: rewrite unresolved/ocaml.org dep refs to relative
#    links into the hosted wodoc docs. Manual pages carry no side, so default to
#    server (the manual's bare API references are overwhelmingly server-side).
#    <relroot> is the path from a page up to the shared /wodoc root that holds
#    eliom/, ocsigen-toolkit/, …: a page at <pub>/<label>/X.html sits two levels
#    below it.
python3 "$HERE/../resolve-deps.py" --self tuto server "../.." "$SRC"/*.html

# 4. left-column navigation, from this version's wikicreole menu.
NAV_MANUAL="$(mktemp)"
python3 "$HERE/gen-manual-nav.py" "$SRC_MANUAL/menu.wiki" "$BASE" >"$NAV_MANUAL"

# version <select> options: every sibling version directory (label `latest` is
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

# 5. build the page template: expand {{leftnav}} into BOTH slots (left column and
#    burger drawer), then fill the version/manual holes and the publish base.
TMPL="$(mktemp)"
sed -e "/{{leftnav}}/r $HERE/leftnav.html" -e "/{{leftnav}}/d" "$HERE/template.html" \
  | sed -e "s#{{pub}}#$PUB#g" \
        -e "/{{versions}}/r $VERSIONS" -e "/{{versions}}/d" \
        -e "/{{manual_nav}}/r $NAV_MANUAL" -e "/{{manual_nav}}/d" \
  >"$TMPL"

# 6. assemble each generated page (all at the version root). --current highlights
#    the matching manual-nav entry by page name.
for f in "$SRC"/*.html; do
  name="$(basename "$f")"
  # --flat: render odoc's preamble and content together, so a docblock/concept
  # wrapper that straddles the preamble/content boundary (e.g. a page whose
  # first content is a <<section class="docblock">>) keeps balanced markers
  # (report §6quinquies; otherwise its opening marker is lost in the preamble).
  "$WODOC" assemble --template "$TMPL" --current "${name%.html}" --base "." \
    --flat "$f" >"$OUT/$name"
done

# version-root landing: intro is the tutorial's entry point.
[ -f "$OUT/intro.html" ] && cp "$OUT/intro.html" "$OUT/index.html"

rm -f "$TMPL" "$NAV_MANUAL" "$VERSIONS"

# 7. assets: the manual's images/downloads (referenced as files/...), odoc's
#    bundled highlight.js at the version root (so {{base}}/highlight.pack.js
#    resolves), plus our ppx-aware highlighting tweaks.
[ -d "$SRC_MANUAL/files" ] && cp -r "$SRC_MANUAL/files" "$OUT/files"
SF="$(mktemp -d)"; odoc support-files -o "$SF" >/dev/null 2>&1 \
  && cp "$SF/highlight.pack.js" "$OUT/highlight.pack.js"; rm -rf "$SF"
cp "$HERE/tuto-highlight.js" "$OUT/tuto-highlight.js"

# 8. optionally (re)point `latest` at this build: a relative git symlink.
if [ -n "$LATEST" ]; then
  ln -sfn "$LABEL" "$HERE/latest"
  echo "latest -> $LABEL"
fi

echo "built tuto $LABEL: $(find "$OUT" -name '*.html' | wc -l) pages -> $OUT"
