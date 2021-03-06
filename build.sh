#!/bin/bash
set -e

[ -z "$OHOW" ] && OHOW=ohow

$OHOW --version >/dev/null || {
    echo "html_of_wiki doesn't seem to be installed properly. Check your installation." >&2
    exit 1
}

OUT=home
[ "$1" = '-l' ] && local=--local || local=

# NOTE redirections have to be done this way because: GitHub Pages uses
# symlinks to change the displayed page but the URL is not
# updated. Since the links generated by html_of_wiki are relative and dependant
# of the location of the file, the links from the redirected page are all wrong.
# `make-redir A B' creates B which redirects to A using `http-equiv'.
make-redir() {
    cat >$2 <<EOF
<!DOCTYPE html>
<html>
    <head><meta http-equiv="refresh" content="0; URL=$1" /></head>
    <body></body>
</html>
EOF
}

options="--project githubio --api api --manual manual --images img --assets download --template template/homepage-template.wiki"
mkdir -p $OUT
find manual -name '*.wiki' -exec basename {} \; | while read -r wiki; do
    html=${wiki%wiki}html
    $OHOW $options $local -o $OUT/$html manual/$wiki || exit 2
    make-redir "$OUT/$(basename $html)" $html
done
make-redir "$OUT/intro.html" index.html
