#!/bin/bash
# One-shot migration: translate the tutorial manual from extended wikicreole to
# wodoc .mld, in place, for a given version directory of the tuto repo.
#
# The tuto repo keeps BOTH versions in its main branch (tutos/8.0, tutos/dev);
# per the doc-in-main-branch decision we translate the sources to .mld there and
# keep them committed (the build then reads .mld directly — no convert-on-build).
# menu.wiki is left as-is (it is navigation metadata, consumed by
# gen-manual-nav.py, not a content page).
#
# a_api references become native odoc refs ({!Eliom...}); a_manual references to
# other projects become relative ../<proj>/<page>.html links; references to the
# tutorial itself (project="tuto"/"tutorial") are folded back to local links so
# they also resolve in the /wodoc/tuto/<version>/ preview.
#
# Usage: convert-manual.sh <tutos-version-dir>   (e.g. 8.0 or dev)
set -e
VERDIR="$1"
[ -n "$VERDIR" ] || { echo "usage: convert-manual.sh <version-dir>" >&2; exit 2; }

WODOC="${WODOC:-wodoc}"
TUTO="${TUTO:-/home/balat/prog/kroko/ocsigen/tuto}"
MAN="$TUTO/tutos/$VERDIR/manual"
[ -d "$MAN" ] || { echo "no manual dir $MAN" >&2; exit 1; }

for wiki in "$MAN"/*.wiki; do
  name="$(basename "$wiki" .wiki)"
  [ "$name" = menu ] && continue   # navigation, not a content page
  out="$MAN/$name.mld"
  "$WODOC" convert --odoc-refs "$wiki" >"$out"
  # tuto self-references (a_manual project="tuto"/"tutorial") came out as
  # ../tuto/... or ../tutorial/...: fold them to local links so they work in
  # both the preview and the final layout.
  sed -i -E 's#\{\{:\.\./tutorial?/#{{:#g' "$out"
done

echo "converted $(ls "$MAN"/*.mld | wc -l) pages in tutos/$VERDIR/manual/"
