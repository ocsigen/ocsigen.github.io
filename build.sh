#!/bin/bash

set -e

declare -a on_exit_items

function on_exit()
{
    for i in "${on_exit_items[@]}"
    do
        echo "on_exit: $i"
        eval $i
    done
}

function add_on_exit()
{
    local n=${#on_exit_items[*]}
    on_exit_items[$n]="$*"
    if [[ $n -eq 0 ]]; then
        echo "Setting trap"
        trap on_exit EXIT
    fi
}

first_that_exists() {
    local tst=$1
    shift
    for x in $*; do
        if [ $tst $x ]; then
            echo $x
            break
        fi
    done
}

docversions() {
    find "$1" -maxdepth 1 -type d -exec basename {} \; | grep -E '([0-9][0-9.]*(\.x)?|dev)$' | sort -Vr
}

find_wikis() {
    find "$1" -name '[a-zA-Z]*.wiki' | sort
}

make-redir() {
    cat >$2 <<EOF
<!DOCTYPE html>
<html>
    <head><meta http-equiv="refresh" content="0; URL=$1.html" /></head>
    <body></body>
</html>
EOF
}

if [[ -z "$1" ]]; then
   echo "Usage: ./build.sh DESTDIR"
   exit 1
fi

dest=$1
shift

gen_doc() {
    local p=$1
    shift
    local pdir=$1
    shift
    local index=$1
    shift
    dv="$(docversions $pdir)"
    dvtmp=$(mktemp)
    add_on_exit rm -f $dvtmp
    csw=$(mktemp)
    add_on_exit rm -f $csw
    for v in $dv; do
	echo $v >> $dvtmp;
    done
    for v in $dv; do
	echo "generating doc for $p.$v"
	mkdir -p $dest/$p
	cp -r $pdir/$v $dest/$p/$v
	for wiki in $(find_wikis $dest/$p/$v | grep -v menu.wiki); do
	    CSW=""
	    if [[ "$wiki" =~ /client/ ]] && [[ -f "${wiki/\/client\//\/server\/}" ]]; then
		echo $(basename $wiki) > $csw
	    elif [[ "$wiki" =~ /server/ ]] && [[ -f "${wiki/\/server\//\/client\/}" ]]; then
		echo $(basename $wiki) > $csw
	    else
		echo "" > $csw
	    fi
	    ohow --root $dest/$p/$v --local --project $p --csw $csw --manual manual --api api --assets manual/files --images manual/files --docversions $dvtmp --template how_template/template.wiki $wiki
	done
	for wiki in $(cd $pdir/$v && find_wikis .); do
	    rm -f $dest/$p/$v/$wiki
	done
    done
    HOW_LATEST=$(cat $dvtmp | sort -Vr | grep -v dev | head -n 1)
    if [[ -z "$HOW_LATEST" ]]; then
	HOW_LATEST=$(cat $dvtmp | sort -Vr | grep dev | head -n 1)
    fi
    if [[ ! -z "$HOW_LATEST" ]]; then
	ln -s $HOW_LATEST $dest/$p/latest
    fi
    make-redir $index $dest/$p/index.html

}

rm -rf $dest
cp -r ocsigen.github.io $dest

for wiki in $(cd $dest/ && find manual -name "*.wiki"); do
    html=../${wiki%wiki}html
    ohow --root $dest --local --project githubio --api api --manual manual --images img --assets download --template $dest/template/homepage-template.wiki -o $dest/home/$html $dest/$wiki
done

make-redir "home/intro" $dest/index.html

export HOW_IN_PROJECT=t

gen_doc "eliom" "eliom/doc" "latest/manual/intro" &
gen_doc "lwt" "lwt/docs" "latest/manual/manual" &
gen_doc "js_of_ocaml" "js_of_ocaml/doc" "latest/manual/overview" &
gen_doc "server" "ocsigenserver/doc" "latest/manual/quickstart" &
gen_doc "html_of_wiki" "html_of_wiki/doc" "latest/manual/intro" &
gen_doc "ocsimore" "ocsimore/doc" "latest/manual/intro" &
gen_doc "deriving" "deriving/doc" "latest/manual/intro" &
gen_doc "ocsigen-start" "ocsigen-start/doc" "latest/manual/intro" &
gen_doc "ocsigen-toolkit" "ocsigen-toolkit/doc" "latest/manual/intro" &
gen_doc "tyxml" "tyxml/docs" "latest/manual/intro" &
gen_doc "tuto" "tuto/tutos" "latest/manual/intro" &
wait
