#!/usr/bin/env python3
"""Build the left-column module navigation for one side of the Ocsigen Toolkit
API from its curated index (doc/server.indexdoc / doc/client.indexdoc on dev,
doc/indexdoc.server / doc/indexdoc.client on the released master).

The index groups the public modules into sections, e.g.:

    {1 Ocsigen Toolkit server API}
    {!modules: Lib }
    {2 Widgets}
    {!modules: Buttons Calendar Carousel ... }

We turn it into a sectioned <nav>. A module short name M maps to the odoc page
<base>/<lib>/<wrapper>/M/index.html on dev (modules live under the Ot wrapper),
or <base>/<lib>/M/index.html when <wrapper> is empty (the released master uses
flat Ot_xxx module names).

Usage: gen-nav.py <indexdoc> <base-url> <lib-dir> [<wrapper>]
   e.g. gen-nav.py server.indexdoc {{base}} ocsigen-toolkit.server Ot
"""
import html
import re
import sys

indexdoc, base, lib = sys.argv[1], sys.argv[2], sys.argv[3]
wrapper = sys.argv[4] if len(sys.argv) > 4 else ""
text = open(indexdoc).read()

# Tokenise into section headings ({2 ...}/{3 ...}) and module lists ({!modules: ...}).
sections = []  # list of (title|None, [modules])
heading_re = re.compile(r"\{[1-9]\s+([^}]*)\}")
modules_re = re.compile(r"\{!modules:\s*(.*?)\}", re.S)
pending_title = None
for m in re.finditer(r"\{[1-9]\s+[^}]*\}|\{!modules:.*?\}", text, re.S):
    tok = m.group(0)
    if tok.startswith("{!modules:"):
        mods = modules_re.match(tok).group(1).split()
        sections.append((pending_title, mods))
        pending_title = None
    else:
        title = heading_re.match(tok).group(1).strip()
        pending_title = title

prefix = (wrapper + "/") if wrapper else ""


def page_url(mod):
    return f"{base}/{lib}/{prefix}" + "/".join(mod.split(".")) + "/index.html"


# Titles that are page titles or index markers, not real sections.
skip_titles = (
    "Ocsigen Start server API",
    "Ocsigen Start client API",
    "Ocsigen-start server API",
    "Ocsigen-start client API",
    "Server API",
    "Client API",
    "Index",
    "Indexes",
)

out = ['<nav class="api-nav">', "<h3>Modules</h3>"]
for title, mods in sections:
    mods = [m for m in mods if m != "{!indexlist}" and not m.startswith("{!")]
    if not mods:
        continue
    if title and title not in skip_titles:
        out.append(f"<h4>{html.escape(title)}</h4>")
    out.append('<ul class="api-section">')
    for mod in mods:
        out.append(
            f'<li data-wodoc-page="{html.escape(mod)}">'
            f'<a href="{page_url(mod)}">{html.escape(mod)}</a></li>'
        )
    out.append("</ul>")
out.append("</nav>")
sys.stdout.write("\n".join(out) + "\n")
