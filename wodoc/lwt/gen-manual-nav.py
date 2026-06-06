#!/usr/bin/env python3
"""Build Lwt's left-column navigation from its wikicreole menu (menu.wiki).

== / === headings become section labels. Two link forms are used:

  [[page|Title]]            -> a manual page in the base lwt package:
                              <base>/lwt/<page>.html  (index, manual)
  <<mod PATH|Title>>        -> an API module, by its directory PATH under the
                              version root: <base>/<PATH>/index.html. PATH is
                              <pkgdir>/<Module…>, e.g. lwt/Lwt_io for a base lwt
                              module, lwt_react/Lwt_react or lwt_ppx/Lwt_ppx for a
                              sibling package (whose modules sit under a wrapper).

`dune build @doc` lays the lwt package out as <base>/lwt/ (curated index.mld
landing + manual.html + one dir per module) with sibling packages lwt_react,
lwt_ppx, lwt_retry next to it (each under a wrapper module of the package name).

Usage: gen-manual-nav.py <menu.wiki> <base-url>
"""
import html
import re
import sys

menu, base = sys.argv[1], sys.argv[2]
PKG = "lwt"  # package dir carrying the manual pages + landing

out = ['<nav class="api-nav manual-nav">', "<h3>Lwt</h3>"]
open_ul = False


def close():
    global open_ul
    if open_ul:
        out.append("</ul>")
        open_ul = False


def open_section():
    global open_ul
    if not open_ul:
        out.append('<ul class="api-section">')
        open_ul = True


for raw in open(menu):
    line = raw.rstrip("\n")
    m = re.match(r"^(=+)\s*(.*)$", line)
    if not m:
        continue
    level = len(m.group(1))  # number of '=' : the menu nesting depth
    text = m.group(2).strip()

    link = re.match(r"\[\[([^|\]]+)\|([^\]]+)\]\]", text)
    mod = re.match(r"<<mod\s+([^|>]+)\|([^>]+)>>", text)

    if link:
        page, title = link.group(1).strip(), link.group(2).strip()
        open_section()
        out.append(
            f'<li class="ml{level}" data-wodoc-page="{page}">'
            f'<a href="{base}/{PKG}/{page}.html">{html.escape(title)}</a></li>'
        )
    elif mod:
        path, title = mod.group(1).strip().strip("/"), mod.group(2).strip()
        open_section()
        out.append(
            f'<li class="ml{level}">'
            f'<a href="{base}/{path}/index.html">{html.escape(title)}</a></li>'
        )
    elif text and "<<" not in text and "[[" not in text:
        # a plain section heading (== Manual, == Core library); the level drives
        # the left indentation (see ocsigen-odoc.css .mlN)
        close()
        out.append(f'<h4 class="ml{level}">{html.escape(text)}</h4>')

close()
out.append("</nav>")
sys.stdout.write("\n".join(out) + "\n")
