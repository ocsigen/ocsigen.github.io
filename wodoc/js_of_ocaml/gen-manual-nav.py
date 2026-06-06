#!/usr/bin/env python3
"""Build js_of_ocaml's manual left-column navigation from its wikicreole menu
(manual/menu.wiki). == / === headings become section labels; [[page|Title]]
links point at the manual pages, which odoc puts under the js_of_ocaml package
(<base>/js_of_ocaml/<page>.html in the multi-package output).

Two wiki wrappers also appear in the menu and are handled:
  <<a_api subproject="P" ...|index>>  -> the API landing for package P:
      js_of_ocaml      -> <base>/js_of_ocaml/api.html (curated overview)
      js_of_ocaml-lwt  -> <base>/js_of_ocaml-lwt/Js_of_ocaml_lwt/index.html
      (other)          -> <base>/<P>/index.html
  <<a_file src="S"|T>>                -> a downloadable asset: <base>/js_of_ocaml/files/S

Usage: gen-manual-nav.py <menu.wiki> <base-url>
"""
import html
import re
import sys

menu, base = sys.argv[1], sys.argv[2]
PKG = "js_of_ocaml"  # package dir that carries the manual pages + curated api.html

out = ['<nav class="api-nav manual-nav">', "<h3>Manual</h3>"]
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


def api_href(subproject):
    if subproject == "js_of_ocaml":
        return f"{base}/{PKG}/api.html"
    if subproject == "js_of_ocaml-lwt":
        return f"{base}/js_of_ocaml-lwt/Js_of_ocaml_lwt/index.html"
    return f"{base}/{subproject}/index.html"


for raw in open(menu):
    line = raw.rstrip("\n")
    m = re.match(r"^(=+)\s*(.*)$", line)
    if not m:
        continue
    level = len(m.group(1))  # number of '=' : the menu nesting depth
    text = m.group(2).strip()

    link = re.match(r"\[\[([^|\]]+)\|([^\]]+)\]\]", text)
    a_api = re.search(r'<<a_api\b([^>]*?)\|([^>]*?)>>', text)
    a_file = re.search(r'<<a_file\b[^>]*?src="([^"]+)"[^>]*?\|([^>]*?)>>', text)

    if link:
        page, title = link.group(1).strip(), link.group(2).strip()
        open_section()
        out.append(
            f'<li class="ml{level}" data-wodoc-page="{page}">'
            f'<a href="{base}/{PKG}/{page}.html">{html.escape(title)}</a></li>'
        )
    elif a_api:
        attrs, body = a_api.group(1), a_api.group(2).strip()
        sub = re.search(r'subproject="([^"]+)"', attrs)
        txt = re.search(r'text="([^"]+)"', attrs)
        subproject = sub.group(1) if sub else "js_of_ocaml"
        title = txt.group(1) if txt else body
        open_section()
        out.append(
            f'<li class="ml{level}">'
            f'<a href="{api_href(subproject)}">{html.escape(title)}</a></li>'
        )
    elif a_file:
        src, title = a_file.group(1), a_file.group(2).strip()
        open_section()
        out.append(
            f'<li class="ml{level}">'
            f'<a href="{base}/{PKG}/files/{src}">{html.escape(title)}</a></li>'
        )
    elif text and "<<" not in text and "[[" not in text:
        # a plain section heading (== Getting Started, == Compiler); the level
        # drives the left indentation (see ocsigen-odoc.css .mlN)
        close()
        out.append(f'<h4 class="ml{level}">{html.escape(text)}</h4>')

close()
out.append("</nav>")
sys.stdout.write("\n".join(out) + "\n")
