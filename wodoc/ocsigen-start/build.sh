#!/bin/bash
# Build one version of the Ocsigen Start documentation (server + client API +
# manual) into wodoc/ocsigen-start/<label>/, themed with the Ocsigen chrome and
# a client/server switch.
#
# Like Eliom, Start packages the server and client APIs as two libraries of the
# SAME package (ocsigen-start.server / ocsigen-start.client) with the SAME
# module names, so `dune build @doc` collides. We use odoc-driver (the engine
# ocaml.org uses, in its patched build — see report §10 #1) on the *installed*
# ocsigen-start package, so the documented version is whatever is installed in
# the given opam switch:
#   dev    -> ocsigen-modernize switch  (start 9.0.0~dev, modules Os.Xxx)
#   latest -> 5.4.0 switch              (start released master, modules Os_xxx)
# `--remap` keeps only start's pages (deps are not hosted; their cross-references
# go to ocaml.org). We then rewrite the Ocsigen-family deps to ocsigen.org, and
# theme each page with `wodoc assemble`, colouring the API by side.
#
# Usage: build.sh <label> <opam-switch>
#   label        output subdir / version label (e.g. latest, dev)
#   opam-switch  switch with odoc-driver + the installed ocsigen-start
#                (5.4.0 / ocsigen-modernize)
#
#   WODOC  path to the wodoc binary (default: wodoc from PATH/opam)
set -e

LABEL="$1"
SWITCH="$2"
[ -n "$LABEL" ] && [ -n "$SWITCH" ] || { echo "usage: build.sh <label> <opam-switch>" >&2; exit 2; }

HERE="$(cd "$(dirname "$0")" && pwd)"
WODOC="${WODOC:-wodoc}"
OUT="$HERE/$LABEL"
# Internal links (nav + template) are kept version-relative: they use the literal
# {{base}} token, which `wodoc assemble` fills per page with the relative path to
# the version root. This way a version's pages never mention the version, so the
# whole tree works unchanged under both /<version>/ and the `latest` symlink.
BASE="{{base}}"
# Absolute publish base, used only for the cross-version <select>.
PUB="${PUB:-/wodoc/ocsigen-start}"
# Also (re)point `latest` at this build (LATEST=1) — a git symlink, served fine
# by GitHub Pages.
LATEST="${LATEST:-}"

eval "$(opam env --switch="$SWITCH" --set-switch)"

# Start source (for the curated per-side index) and the git ref matching the
# switch. dev (deriving) wraps its modules in `Os`; the released master uses
# flat Os_xxx module names (no wrapper) and a different index file.
OS_SRC="${OS_SRC:-/home/balat/prog/kroko/ocsigen/ocsigen-start}"
case "$SWITCH" in
  *modernize*)
    OS_REF="${OS_REF:-deriving-mli-odoc}"
    WRAPPER="${WRAPPER:-Os}"
    IDX_SERVER="${IDX_SERVER:-doc/server.indexdoc}"
    IDX_CLIENT="${IDX_CLIENT:-doc/client.indexdoc}"
    MANUAL_VER="${MANUAL_VER:-dev}"
    ;;
  *)
    OS_REF="${OS_REF:-latest-mli-odoc}"
    WRAPPER="${WRAPPER:-}"
    IDX_SERVER="${IDX_SERVER:-doc/indexdoc.server}"
    IDX_CLIENT="${IDX_CLIENT:-doc/indexdoc.client}"
    MANUAL_VER="${MANUAL_VER:-6.x}"
    ;;
esac
# {{wrapper}} token used by the template's client/server switch fallback URL:
# "Os/" on dev (modules live under the Os wrapper), "" on master (flat modules).
WRAP_SEG=""
[ -n "$WRAPPER" ] && WRAP_SEG="$WRAPPER/"

WORK="$(mktemp -d /home/balat/temp/start-doc-XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

# 1. Build the manual + API together with odoc-driver on the installed toolkit
#    package (manual .mld declared by the package's (documentation) stanza, so
#    {{!page-X}} and {!Module} references resolve in the same run). The package
#    must be installed from the documented branch (prerequisite). The installed
#    manual .mld carry {%wodoc:%} markers; preprocess them in place so odoc keeps
#    them as HTML comments for the render pass (idempotent — safe to re-run).
#    Set REUSE_HTML=<dir> (containing ocsigen-start/) to skip this slow step.
if [ -n "$REUSE_HTML" ]; then
  SRC="$REUSE_HTML/ocsigen-start"
else
  PAGES="$(opam var --switch="$SWITCH" doc)/ocsigen-start/odoc-pages"
  if [ -d "$PAGES" ]; then
    for f in "$PAGES"/*.mld; do "$WODOC" preprocess "$f" >"$f.pp" && mv "$f.pp" "$f"; done
  fi
  odoc_driver ocsigen-start --remap --html-dir "$WORK/html" >/dev/null 2>&1
  SRC="$WORK/html/ocsigen-start"
fi
[ -d "$SRC" ] || { echo "no ocsigen-start output in $SRC" >&2; exit 1; }

rm -rf "$OUT"
mkdir -p "$OUT"

# 2. Left-column navigation: the manual (from menu.wiki) AND the curated module
#    list per side (from the per-side index). Both shown on every page.
NAV_MANUAL="$(mktemp)"; NAV_SERVER="$(mktemp)"; NAV_CLIENT="$(mktemp)"
git -C "$OS_SRC" show "$OS_REF:$IDX_SERVER" >"$WORK/server.indexdoc"
git -C "$OS_SRC" show "$OS_REF:$IDX_CLIENT" >"$WORK/client.indexdoc"
git -C "$OS_SRC" show "wikidoc:doc/$MANUAL_VER/manual/menu.wiki" >"$WORK/menu.wiki"
python3 "$HERE/gen-nav.py" "$WORK/server.indexdoc" "$BASE" ocsigen-start.server "$WRAPPER" >"$NAV_SERVER"
python3 "$HERE/gen-nav.py" "$WORK/client.indexdoc" "$BASE" ocsigen-start.client "$WRAPPER" >"$NAV_CLIENT"
python3 "$HERE/gen-manual-nav.py" "$WORK/menu.wiki" "$BASE" >"$NAV_MANUAL"

# 2b. Version <select> options: `latest` plus every sibling version directory.
VERSIONS="$(mktemp)"
{
  echo "              <option value=\"latest\">latest</option>"
  for d in "$HERE"/*/; do
    v="$(basename "$d")"
    [ "$v" = latest ] && continue
    echo "              <option value=\"$v\">$v</option>"
  done
} >"$VERSIONS"

# 3. Per-side templates. Expand {{leftnav}} into BOTH its slots (left column and
#    burger drawer), then set side/publish base/wrapper and fill the holes.
mk_template() {
  side="$1"; apinav="$2"
  sed -e "/{{leftnav}}/r $HERE/leftnav.html" -e "/{{leftnav}}/d" \
      "$HERE/template.html" \
  | sed -e "s#{{side}}#$side#g" \
        -e "s#{{pub}}#$PUB#g" \
        -e "s#{{wrapper}}#$WRAP_SEG#g" \
        -e "/{{versions}}/r $VERSIONS" -e "/{{versions}}/d" \
        -e "/{{manual_nav}}/r $NAV_MANUAL" -e "/{{manual_nav}}/d" \
        -e "/{{api_nav}}/r $apinav" -e "/{{api_nav}}/d"
}
TMPL_SERVER="$(mktemp)"; mk_template server "$NAV_SERVER" >"$TMPL_SERVER"
TMPL_CLIENT="$(mktemp)"; mk_template client "$NAV_CLIENT" >"$TMPL_CLIENT"
TMPL_OTHER="$(mktemp)";  mk_template ""      "$NAV_SERVER" >"$TMPL_OTHER"

# 3b. Assemble every page, mirroring odoc-driver's ocsigen-start/ subtree so the
#    relative cross-links keep working. The side (from the path) picks the template.
(cd "$SRC" && find . -name '*.html') | while read -r page; do
  rel="${page#./}"
  case "$rel" in
    ocsigen-start.server*) tmpl="$TMPL_SERVER" ;;
    ocsigen-start.client*) tmpl="$TMPL_CLIENT" ;;
    *)                       tmpl="$TMPL_OTHER" ;;
  esac
  # highlight the current entry: the module in the API nav, or the page name in
  # the manual nav (manual pages sit at the package root).
  current=""
  if [ -n "$WRAPPER" ]; then
    case "$rel" in
      ocsigen-start.server/$WRAPPER/*/index.html | ocsigen-start.client/$WRAPPER/*/index.html)
        m="${rel#ocsigen-start.*/$WRAPPER/}"; m="${m%/index.html}"; current="${m//\//.}" ;;
      */*) ;;
      *.html) current="${rel%.html}" ;;
    esac
  else
    case "$rel" in
      ocsigen-start.server/*/index.html | ocsigen-start.client/*/index.html)
        m="${rel#ocsigen-start.*/}"; m="${m%/index.html}"; current="${m//\//.}" ;;
      */*) ;;
      *.html) current="${rel%.html}" ;;
    esac
  fi
  # relative path from this page to the version root.
  slashes="${rel//[!\/]/}"; depth=${#slashes}
  if [ "$depth" -eq 0 ]; then base="."; else
    base=""; for _ in $(seq 1 "$depth"); do base="../$base"; done; base="${base%/}"
  fi
  mkdir -p "$OUT/$(dirname "$rel")"
  "$WODOC" assemble --template "$tmpl" --current "$current" --base "$base" \
    "$SRC/$rel" >"$OUT/$rel"
done

rm -f "$TMPL_SERVER" "$TMPL_CLIENT" "$TMPL_OTHER" \
      "$NAV_MANUAL" "$NAV_SERVER" "$NAV_CLIENT" "$VERSIONS"

# 4. Redirect cross-references to Ocsigen-family dependencies from ocaml.org
#    (odoc --remap's target) to ocsigen.org, where they will all live under
#    /wodoc/<project>/latest/. The module path after /doc/ is identical between
#    odoc and our wodoc output, so this is a clean prefix rewrite.
redirect_dep() { # <pkg> <project>
  find "$OUT" -name '*.html' -exec sed -i -E \
    "s#https://ocaml.org/p/$1/[^/]+/doc/#https://ocsigen.org/wodoc/$2/latest/#g" {} +
}
redirect_dep ocsigenserver   ocsigenserver
redirect_dep ocsigen-toolkit ocsigen-toolkit
redirect_dep lwt             lwt
redirect_dep tyxml           tyxml
redirect_dep js_of_ocaml     js_of_ocaml
redirect_dep reactiveData    reactiveData

# 4a-bis. Eliom needs special handling (it is a multi-library package): its
#    modules live under eliom.server/ and eliom.client/ in the Eliom wodoc doc,
#    and eliom 12's wrapped-module odoc metadata leaves some canonical refs
#    unresolved. resolve-eliom-refs.py rewrites BOTH the resolved
#    ocaml.org/p/eliom links and the unresolved spans to the matching
#    eliom.<side>/<flat-module> page (the flat layout exists on both sides), so
#    every Eliom reference points at the deployed Eliom doc. The side comes from
#    the page's library subtree; manual pages (no side) carry no such refs.
find "$OUT/ocsigen-start.server" -name '*.html' -exec \
  python3 "$HERE/resolve-eliom-refs.py" server {} + 2>/dev/null || true
find "$OUT/ocsigen-start.client" -name '*.html' -exec \
  python3 "$HERE/resolve-eliom-refs.py" client {} + 2>/dev/null || true

# 4b. Ship odoc's bundled highlight.js at the version root so
#     {{base}}/highlight.pack.js resolves.
PACK="$(dirname "$SRC")/highlight.pack.js"
if [ -f "$PACK" ]; then
  cp "$PACK" "$OUT/highlight.pack.js"
else
  SF="$(mktemp -d)"; odoc support-files -o "$SF" >/dev/null 2>&1 \
    && cp "$SF/highlight.pack.js" "$OUT/highlight.pack.js"; rm -rf "$SF"
fi
cp "$HERE/start-highlight.js" "$OUT/start-highlight.js"

# 5. Optionally (re)point `latest` at this build: a relative git symlink.
if [ -n "$LATEST" ]; then
  ln -sfn "$LABEL" "$HERE/latest"
  echo "latest -> $LABEL"
fi

echo "built ocsigen-start $LABEL: $(find "$OUT" -name '*.html' | wc -l) pages -> $OUT"
