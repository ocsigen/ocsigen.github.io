#!/usr/bin/env python3
"""Build the tutorial's left-column navigation from its wikicreole menu
(tutos/<version>/manual/menu.wiki).

The tuto menu is richer than the other projects':
  = Section                       -> a section label (level 1)
  =@@class="howto"@@ HOW-TO        -> a section label, class markup stripped
  ==[[page|Title]]                 -> a link to <base>/page.html (level 2)
  ==[[site:/install|Title]]        -> a link to an absolute site path (/install)
  == How to put elements          -> a sub-section label (no link, level 2)
  ===[[page|Title]]                -> a link (level 3)
  <<|...>>                         -> a commented-out entry: skipped
  >>                               -> an orphan comment close in the source: ignored

`site:/path` links point at the site root (the institutional pages / talks);
plain `[[page|Title]]` links stay version-relative via <base>. Usage:
gen-manual-nav.py <menu.wiki> <base-url>
"""
import html
import re
import sys

menu, base = sys.argv[1], sys.argv[2]
out = ['<nav class="api-nav manual-nav">', "<h3>Manual</h3>"]
open_ul = False


def close():
    global open_ul
    if open_ul:
        out.append("</ul>")
        open_ul = False


def link_href(page):
    # site:/foo -> /foo (institutional site pages, served at the root);
    # an absolute http(s) link is kept as-is; otherwise a sibling tuto page.
    if page.startswith("site:"):
        return page[len("site:"):]
    if page.startswith(("http://", "https://", "/")):
        return page
    return f"{base}/{page}.html"


for raw in open(menu):
    line = raw.strip()
    if not line or line == ">>" or line.startswith("<<|"):
        # blank, orphan comment close, or a fully commented-out entry
        continue
    m = re.match(r"^(=+)\s*(.*)$", line)
    if not m:
        continue
    level = len(m.group(1))  # number of '=' : the menu nesting depth
    text = m.group(2).strip()
    # strip a leading @@class="..."@@ attribute marker from a section heading
    text = re.sub(r'^@@[^@]*@@\s*', "", text).strip()
    link = re.match(r"\[\[([^|\]]+)\|([^\]]+)\]\]", text)
    if link:
        page, title = link.group(1).strip(), link.group(2).strip()
        if not open_ul:
            out.append('<ul class="api-section">')
            open_ul = True
        # data-wodoc-page lets --current highlight the active entry (only useful
        # for sibling tuto pages; absolute links never become "current").
        wid = "" if page.startswith(("site:", "http", "/")) else page
        out.append(
            f'<li class="ml{level}" data-wodoc-page="{html.escape(wid)}">'
            f'<a href="{html.escape(link_href(page))}">{html.escape(title)}</a></li>'
        )
    elif text:
        # a plain section heading (= Programmer's guide, == How to ...);
        # the level drives the left indentation (see ocsigen-odoc.css .mlN)
        close()
        out.append(f'<h4 class="ml{level}">{html.escape(text)}</h4>')
close()
out.append("</nav>")
sys.stdout.write("\n".join(out) + "\n")
