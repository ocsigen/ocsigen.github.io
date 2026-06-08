#!/bin/bash
# Build one version of the ReactiveData documentation into wodoc/reactiveData/<label>/.
#
# Everything is declared in ./wodoc (project, packages, nav, …) and assembled by
# `wodoc build`; this script only checks out the requested version in a detached
# worktree and runs the build there. ReactiveData is a single package with one
# library and no client/server split, so a plain `dune build @doc` (run by
# `wodoc build`, profile from the config) is enough — no odoc-driver.
#
# Usage: build.sh <label> <git-ref> [opam-switch]
#   label        output subdir / version label (e.g. dev, 0.3.1); NEVER "latest" (#11)
#   git-ref      branch/tag to document (e.g. master, 0.3.1)
#   opam-switch  switch providing odoc + reactiveData deps (default: 5.4.0)
#
#   WODOC         path to the wodoc binary (default: wodoc from PATH/opam)
#   REACTIVEDATA  path to the reactiveData checkout
#   LATEST        if non-empty, also repoint the `latest` symlink at this build
set -e

LABEL="$1"
REF="$2"
SWITCH="${3:-5.4.0}"
[ -n "$LABEL" ] && [ -n "$REF" ] || { echo "usage: build.sh <label> <git-ref> [switch]" >&2; exit 2; }

HERE="$(cd "$(dirname "$0")" && pwd)"
WODOC="${WODOC:-wodoc}"
REACTIVEDATA="${REACTIVEDATA:-/home/balat/prog/kroko/ocsigen/reactiveData}"

eval "$(opam env --switch="$SWITCH" --set-switch)"

WT="$(mktemp -d /home/balat/temp/reactiveData-doc-XXXXXX)"
trap 'git -C "$REACTIVEDATA" worktree remove --force "$WT" 2>/dev/null || true' EXIT
git -C "$REACTIVEDATA" worktree add --detach "$WT" "$REF"

# Build + theme in one go: `wodoc build` runs `dune build @doc` (profile from the
# config) in the worktree, then assembles the whole tree into <label>/.
( cd "$WT" && "$WODOC" build --config "$HERE/wodoc" --out "$HERE/$LABEL" \
    --label "$LABEL" --menu "$HERE/../menu.html" ${LATEST:+--latest} )

echo "built reactiveData $LABEL: $(find "$HERE/$LABEL" -name '*.html' | wc -l) pages -> $HERE/$LABEL"
