#!/usr/bin/env python3
"""Build the left-column navigation for html_of_wiki's single-page manual.

Unlike the other projects, html_of_wiki's manual is ONE page (index.mld) whose
menu (doc/2.0/manual/menu.wiki) links to in-page anchors: [[#install|...]]. The
.mld keeps those anchors as odoc heading labels ({1:install ...}), so each entry
becomes a link to index.html#anchor. == / === / ==== headings give the nesting
(left indent via .mlN); plain headings (no link) are section labels.

Markup cleanups: ##x## (monospace) -> x, {{{x}}} (code) -> x.
Usage: gen-anchor-nav.py <menu.wiki> <base-url>
"""
import html
import re
import sys

menu, base = sys.argv[1], sys.argv[2]


def clean(t):
    t = re.sub(r"\{\{\{(.*?)\}\}\}", r"\1", t)  # {{{code}}} -> code
    t = re.sub(r"##(.*?)##", r"\1", t)  # ##mono## -> mono
    return t.strip()


out = ['<nav class="api-nav manual-nav">', "<h3>Manual</h3>"]
open_ul = False


def close():
    global open_ul
    if open_ul:
        out.append("</ul>")
        open_ul = False


for raw in open(menu):
    line = raw.rstrip("\n")
    m = re.match(r"^(=+)\s*(.*)$", line)
    if not m:
        continue
    level = len(m.group(1))
    text = m.group(2).strip()
    link = re.match(r"\[\[#([^|\]]+)\|([^\]]+)\]\]", text)
    if link:
        anchor, title = link.group(1).strip(), clean(link.group(2))
        if not open_ul:
            out.append('<ul class="api-section">')
            open_ul = True
        out.append(
            f'<li class="ml{level}"><a href="{base}/index.html#{anchor}">'
            f"{html.escape(title)}</a></li>"
        )
    else:
        title = clean(text)
        if not title or "[[" in text or "<<" in text:
            continue
        close()
        out.append(f'<h4 class="ml{level}">{html.escape(title)}</h4>')
close()
out.append("</nav>")
sys.stdout.write("\n".join(out) + "\n")
