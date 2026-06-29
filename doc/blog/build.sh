#!/bin/bash
# Build the Ocsigen blog (served at /blog) from doc/blog/src + doc/blog/posts
# into the site, themed with the shared Ocsigen chrome (wodoc). Like the vitrine
# (doc/vitrine), this is a flat build using the low-level wodoc commands, not the
# versioned `wodoc build`:
#   - the left nav (the post list) comes from `wodoc blog-nav`;
#   - the landing's {%wodoc:blog-latest%} marker is expanded by `assemble
#     --blog-config`;
#   - the Atom feed at /feed.xml (consumed by OCaml Planet) comes from
#     `wodoc blog-feed`.
# Per page: preprocess -> odoc compile/link/html-generate -> assemble.
#
#   WODOC  path to the wodoc binary (default: wodoc from PATH/opam)
#   odoc   must be on PATH
#   OUT    output dir (default: the repo root, two levels up)
set -e

HERE="$(cd "$(dirname "$0")" && pwd)"
WODOC="${WODOC:-wodoc}"
OUT="${OUT:-$(cd "$HERE/../.." && pwd)}"
MENU="$HERE/../menu.html"
TMPL="$HERE/template.html"
WORK="$HERE/_work"
rm -rf "$WORK"; mkdir -p "$WORK/html"
mkdir -p "$OUT/blog/posts"

cd "$HERE"   # so the config's (dir posts) resolves relative to doc/blog
CONFIG=wodoc

build_page() { # <preprocessed.mld src> <odoc page name> <leftnav file> <out html> <assemble extra...>
  local src="$1" name="$2" nav="$3" out="$4"; shift 4
  "$WODOC" preprocess "$src" >"$WORK/$name.mld"
  odoc compile "$WORK/$name.mld" -o "$WORK/page-$name.odoc"
  odoc link "$WORK/page-$name.odoc" -o "$WORK/page-$name.odocl"
  odoc html-generate "$WORK/page-$name.odocl" -o "$WORK/html"
  "$WODOC" assemble --template "$TMPL" --menu "$MENU" --subproject Blog \
    --menu-current blog --leftnav "$nav" "$@" "$WORK/html/$name.html" >"$out"
}

# the post list for the left nav, once per depth (index at /blog, posts at /blog/posts)
"$WODOC" blog-nav --config "$CONFIG" --base .  >"$WORK/nav-index.html"
"$WODOC" blog-nav --config "$CONFIG" --base .. >"$WORK/nav-post.html"

# landing: lists the latest posts via the marker (--blog-config expands it)
build_page src/index.mld index "$WORK/nav-index.html" "$OUT/blog/index.html" \
  --base . --blog-config "$CONFIG" --blog-base .
echo "built blog/index.html"

# one page per post
for mld in posts/*.mld; do
  name="$(basename "$mld" .mld)"      # YYYY-MM-DD-slug
  slug="${name#????-??-??-}"          # slug (matches (out posts) => posts/<slug>.html)
  date="${name:0:10}"                 # the YYYY-MM-DD publication date
  author="$(sed -n 's/^@author[[:space:]]*//p' "$mld" | head -1)"
  byline="$date"; [ -n "$author" ] && byline="$date — $author"
  build_page "$mld" "$slug" "$WORK/nav-post.html" "$OUT/blog/posts/$slug.html" \
    --base .. --current "posts/$slug.html" --byline "$byline"
  echo "built blog/posts/$slug.html"
done

# Unlisted pages: doc/blog/hidden/YYYY-MM-DD-slug.mld build to /blog/posts/<slug>.html
# exactly like a post, but they live OUTSIDE the (blog (dir posts)) config, so
# `blog-nav`, `assemble --blog-config` and `blog-feed` never see them: they are
# absent from the left-nav, the landing's latest widget and the Atom feed (hence
# off OCaml Planet). They are reachable only by their direct URL — for drafts
# shared privately before publication. To publish one for real, move its .mld to
# posts/ (and delete the generated hidden html).
if [ -d hidden ]; then
  for mld in hidden/*.mld; do
    [ -e "$mld" ] || continue          # no-match glob guard
    name="$(basename "$mld" .mld)"     # YYYY-MM-DD-slug
    slug="${name#????-??-??-}"
    date="${name:0:10}"
    author="$(sed -n 's/^@author[[:space:]]*//p' "$mld" | head -1)"
    byline="$date"; [ -n "$author" ] && byline="$date — $author"
    build_page "$mld" "$slug" "$WORK/nav-post.html" "$OUT/blog/posts/$slug.html" \
      --base .. --current "posts/$slug.html" --byline "$byline"
    echo "built blog/posts/$slug.html (unlisted)"
  done
fi

# the Atom feed at the site root /feed.xml (same URL OCaml Planet already follows)
"$WODOC" blog-feed --config "$CONFIG" --base-url https://ocsigen.org \
  --blog-path /blog --feed-path /feed.xml \
  --title "Ocsigen Blog" --author "Ocsigen Project" >"$OUT/feed.xml"
echo "built feed.xml"

rm -rf "$WORK"   # the intermediate odoc/html work tree is never committed
