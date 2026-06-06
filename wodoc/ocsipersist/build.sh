#!/bin/bash
# Build one version of the Ocsipersist documentation into wodoc/ocsipersist/<label>/.
#
# Everything is now declared in ./wodoc (project, packages, nav, …) and assembled
# by `wodoc build`; this script only checks out the requested version in a
# detached worktree and runs the build there. No per-page logic, no menu.wiki,
# no template/nav HTML — those are gone (see ./wodoc and `wodoc build`).
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

eval "$(opam env --switch="$SWITCH" --set-switch)"

WT="$(mktemp -d /home/balat/temp/ocsipersist-doc-XXXXXX)"
trap 'git -C "$OCSIPERSIST" worktree remove --force "$WT" 2>/dev/null || true' EXIT
git -C "$OCSIPERSIST" worktree add --detach "$WT" "$REF"

# Build + theme in one go: `wodoc build` runs `dune build @doc` (profile from the
# config) in the worktree, then assembles the whole tree into <label>/.
( cd "$WT" && "$WODOC" build --config "$HERE/wodoc" --out "$HERE/$LABEL" \
    --label "$LABEL" --menu "$HERE/../menu.html" ${LATEST:+--latest} )

echo "built ocsipersist $LABEL: $(find "$HERE/$LABEL" -name '*.html' | wc -l) pages -> $HERE/$LABEL"
