#!/usr/bin/env python3
"""Build the left-column module navigation for one side of the Eliom API from
its curated index (doc/server.indexdoc or doc/client.indexdoc).

The index groups the *public* modules into sections (so internal modules such as
Mod_*, *_base, *_sigs are naturally excluded), e.g.:

    {1 Server API}
    {!modules: Lib Client ... }
    {2 Service creation}
    {!modules: Service Parameter Registration Registration.Html ... }

We turn it into a sectioned <nav>; a module path A.B.C maps to the odoc page
<base>/<lib>/Eliom/A/B/C/index.html.

Usage: gen-nav.py <indexdoc> <base-url> <lib-dir>
   e.g. gen-nav.py server.indexdoc /wodoc/eliom/dev eliom.server
"""
import html
import re
import sys

indexdoc, base, lib = sys.argv[1], sys.argv[2], sys.argv[3]
text = open(indexdoc).read()

# Tokenise into section headings ({2 ...}/{3 ...}) and module lists ({!modules: ...}).
sections = []  # list of (title|None, [modules])
pos = 0
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
        # the page title ({1 ...}) is not a section; skip "Index"
        pending_title = title


def page_url(mod):
    return f"{base}/{lib}/Eliom/" + "/".join(mod.split(".")) + "/index.html"


out = ['<nav class="api-nav">', "<h3>Modules</h3>"]
first = True
for title, mods in sections:
    if not mods:
        continue
    if title and title not in ("Server API", "Client API", "Index"):
        out.append(f"<h4>{html.escape(title)}</h4>")
    out.append('<ul class="api-section">')
    for mod in mods:
        out.append(f'<li><a href="{page_url(mod)}">{html.escape(mod)}</a></li>')
    out.append("</ul>")
    first = False
out.append("</nav>")
sys.stdout.write("\n".join(out) + "\n")
