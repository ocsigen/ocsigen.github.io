#!/bin/bash
# Build one version of the Eliom documentation (server + client + ppx API) into
# wodoc/eliom/<label>/, themed with the Ocsigen chrome and a client/server
# switch.
#
# Eliom packages the server and client APIs as two libraries of the SAME package
# (eliom.server / eliom.client) with the SAME module names, so `dune build @doc`
# collides. We use odoc-driver (the engine ocaml.org uses) on the *installed*
# eliom package — so the documented version is whatever is installed in the
# given opam switch:
#   dev    -> ocsigen-modernize switch  (eliom = deriving branch)
#   stable -> 5.4.0 switch              (eliom = released master)
# `--remap` keeps only eliom's pages (deps are not hosted; their cross-references
# go to ocaml.org). We then rewrite the Ocsigen-family deps to ocsigen.org, and
# theme each page with `wodoc assemble`, colouring the API by side.
#
# Usage: build.sh <label> <opam-switch>
#   label        output subdir / version label (e.g. latest, dev)
#   opam-switch  switch with odoc-driver + the installed eliom (5.4.0 /
#                ocsigen-modernize)
#
#   WODOC  path to the wodoc binary (default: wodoc from PATH/opam)
set -e

LABEL="$1"
SWITCH="$2"
[ -n "$LABEL" ] && [ -n "$SWITCH" ] || { echo "usage: build.sh <label> <opam-switch>" >&2; exit 2; }

HERE="$(cd "$(dirname "$0")" && pwd)"
WODOC="${WODOC:-wodoc}"
OUT="$HERE/$LABEL"
# Internal links (nav + template) are kept version-relative: they use the
# literal {{base}} token, which `wodoc assemble` fills per page with the
# relative path to the version root (".", "..", "../.."). This way a version's
# pages never mention the version, so the whole tree works unchanged under both
# /<version>/ and the `latest` symlink (the scheme the eliom gh-pages uses).
BASE="{{base}}"
# Absolute publish base, used only for the cross-version <select> (which by
# definition jumps between versions). /wodoc/eliom while previewing here; on the
# eliom gh-pages it will be /eliom.
PUB="${PUB:-/wodoc/eliom}"
# Also (re)point `latest` at this build (LATEST=1) — a git symlink, served fine
# by GitHub Pages, as on the current eliom site (latest -> 11.x).
LATEST="${LATEST:-}"

eval "$(opam env --switch="$SWITCH" --set-switch)"

# Eliom source (for the curated per-side index) and the git ref matching the
# switch (modernize builds the deriving/dev API, 5.4.0 the released master).
ELIOM_SRC="${ELIOM_SRC:-/home/balat/prog/kroko/ocsigen/eliom}"
case "$SWITCH" in
  *modernize*) ELIOM_REF="${ELIOM_REF:-deriving}" ;;
  *)           ELIOM_REF="${ELIOM_REF:-master}" ;;
esac

WORK="$(mktemp -d /home/balat/temp/eliom-doc-XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

# 1. Build the manual + API together with odoc-driver on the installed eliom
#    package (manual .mld declared by the package's (documentation) stanza, so
#    {{!page-X}} and {!Module} references resolve in the same run). The package
#    must be installed from the documented branch (prerequisite). The installed
#    manual .mld carry {%wodoc:%} markers; preprocess them in place so odoc keeps
#    them as HTML comments for the render pass (idempotent — safe to re-run).
#    Set REUSE_HTML=<dir> (containing eliom/) to skip this slow step.
if [ -n "$REUSE_HTML" ]; then
  SRC="$REUSE_HTML/eliom"
else
  PAGES="$(opam var --switch="$SWITCH" doc)/eliom/odoc-pages"
  if [ -d "$PAGES" ]; then
    for f in "$PAGES"/*.mld; do "$WODOC" preprocess "$f" >"$f.pp" && mv "$f.pp" "$f"; done
  fi
  odoc_driver eliom --remap --html-dir "$WORK/html" >/dev/null 2>&1
  SRC="$WORK/html/eliom"
fi
[ -d "$SRC" ] || { echo "no eliom output in $SRC" >&2; exit 1; }

rm -rf "$OUT"
mkdir -p "$OUT"

# 2. Left-column navigation: the manual (from menu.wiki) AND the curated,
#    section-grouped module list per side (from server/client.indexdoc, internal
#    modules excluded). Both are shown on every page so one can move between the
#    manual and the API. Built once; injected into the template.
NAV_MANUAL="$(mktemp)"; NAV_SERVER="$(mktemp)"; NAV_CLIENT="$(mktemp)"
git -C "$ELIOM_SRC" show "$ELIOM_REF:doc/server.indexdoc" >"$WORK/server.indexdoc"
git -C "$ELIOM_SRC" show "$ELIOM_REF:doc/client.indexdoc" >"$WORK/client.indexdoc"
git -C "$ELIOM_SRC" show "wikidoc:doc/dev/manual/menu.wiki" >"$WORK/menu.wiki"
python3 "$HERE/gen-nav.py" "$WORK/server.indexdoc" "$BASE" eliom.server >"$NAV_SERVER"
python3 "$HERE/gen-nav.py" "$WORK/client.indexdoc" "$BASE" eliom.client >"$NAV_CLIENT"
python3 "$HERE/gen-manual-nav.py" "$WORK/menu.wiki" "$BASE" >"$NAV_MANUAL"

# 2b. Version <select> options: `latest` plus every sibling version directory.
#     The option value is the bare version name; wodocVersion() swaps just that
#     segment of the current URL so the reader stays on the same page / API
#     module. The selected option is set client-side from the URL (not here):
#     the same files are served under <version>/ and the `latest` symlink, so a
#     build-time "selected" would be wrong under one of the two paths. $OUT
#     exists (mkdir above) so this build's dir is already listed.
VERSIONS="$(mktemp)"
{
  echo "              <option value=\"latest\">latest</option>"
  for d in "$HERE"/*/; do
    v="$(basename "$d")"
    [ "$v" = latest ] && continue
    echo "              <option value=\"$v\">$v</option>"
  done
} >"$VERSIONS"

# 3. Per-side templates: set the side class and the absolute publish base (for
#    the version <select>), inject the version options and the manual + side
#    module nav. {{base}} is left as a token: `wodoc assemble` fills it per page
#    with the relative path to the version root, so links stay version-relative.
mk_template() {
  side="$1"; apinav="$2"
  sed -e "s#{{side}}#$side#g" \
      -e "s#{{pub}}#$PUB#g" \
      -e "/{{versions}}/r $VERSIONS" -e "/{{versions}}/d" \
      -e "/{{manual_nav}}/r $NAV_MANUAL" -e "/{{manual_nav}}/d" \
      -e "/{{api_nav}}/r $apinav" -e "/{{api_nav}}/d" \
      "$HERE/template.html"
}
TMPL_SERVER="$(mktemp)"; mk_template server "$NAV_SERVER" >"$TMPL_SERVER"
TMPL_CLIENT="$(mktemp)"; mk_template client "$NAV_CLIENT" >"$TMPL_CLIENT"
TMPL_OTHER="$(mktemp)";  mk_template ""      "$NAV_SERVER" >"$TMPL_OTHER"

# 3. Assemble every page, mirroring odoc-driver's eliom/ subtree so the relative
#    cross-links keep working. The side (from the path) selects the template,
#    which sets the colour and the active switch button.
(cd "$SRC" && find . -name '*.html') | while read -r page; do
  rel="${page#./}"
  case "$rel" in
    eliom.server*) tmpl="$TMPL_SERVER" ;;
    eliom.client*) tmpl="$TMPL_CLIENT" ;;
    *)             tmpl="$TMPL_OTHER" ;;
  esac
  # highlight the current entry: the module (Eliom.X) in the API nav, or the
  # page name in the manual nav (manual pages sit at the package root).
  current=""
  case "$rel" in
    eliom.server/Eliom/*/index.html | eliom.client/Eliom/*/index.html)
      m="${rel#eliom.*/Eliom/}"; m="${m%/index.html}"; current="${m//\//.}" ;;
    */*) ;;
    *.html) current="${rel%.html}" ;;
  esac
  # relative path from this page to the version root (".", "..", "../..", …),
  # so the {{base}} links never mention the version.
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
#    odoc and our wodoc output, so this is a clean prefix rewrite. Until a
#    project's wodoc doc is actually deployed these links 404 on ocsigen.org —
#    acceptable for now, as the whole ecosystem is migrated before going live.
#    Non-Ocsigen deps (stdlib, react, cohttp, …) keep their ocaml.org links so
#    they work from both sites.
redirect_dep() { # <pkg> <project> : ocaml.org/p/<pkg> -> ocsigen.org/wodoc/<project>/latest
  find "$OUT" -name '*.html' -exec sed -i -E \
    "s#https://ocaml.org/p/$1/[^/]+/doc/#https://ocsigen.org/wodoc/$2/latest/#g" {} +
}
redirect_dep ocsigenserver ocsigenserver
redirect_dep lwt           lwt
redirect_dep tyxml         tyxml
redirect_dep js_of_ocaml   js_of_ocaml
redirect_dep reactiveData  reactiveData
redirect_dep ocsipersist   ocsipersist

# 4b. odoc emits code blocks as <pre class="language-..">, highlighted client-side.
#     Ship odoc's bundled highlight.js at the version root so {{base}}/highlight.pack.js
#     resolves (odoc-driver already produced it next to the eliom/ tree; fall back
#     to `odoc support-files` in REUSE mode if absent).
PACK="$(dirname "$SRC")/highlight.pack.js"
if [ -f "$PACK" ]; then
  cp "$PACK" "$OUT/highlight.pack.js"
else
  SF="$(mktemp -d)"; odoc support-files -o "$SF" >/dev/null 2>&1 \
    && cp "$SF/highlight.pack.js" "$OUT/highlight.pack.js"; rm -rf "$SF"
fi
# Eliom ppx highlighting tweaks + highlighting start-up
cp "$HERE/eliom-highlight.js" "$OUT/eliom-highlight.js"

# 5. Optionally (re)point `latest` at this build: a relative git symlink, served
#    fine by GitHub Pages (as the live eliom site does with latest -> 11.x).
if [ -n "$LATEST" ]; then
  ln -sfn "$LABEL" "$HERE/latest"
  echo "latest -> $LABEL"
fi

echo "built eliom $LABEL: $(find "$OUT" -name '*.html' | wc -l) pages -> $OUT"
