#!/usr/bin/env python3
"""Build the left-column module navigation for one side of the Eliom API from
its curated index (doc/server.indexdoc or doc/client.indexdoc).

The index groups the *public* modules into sections (so internal modules such as
Mod_*, *_base, *_sigs are naturally excluded), e.g.:

    {1 Server API}
    {!modules: Lib Client ... }
    {2 Service creation}
    {!modules: Service Parameter Registration Registration.Html ... }

We turn it into a sectioned <nav>; a module path A.B.C maps to an odoc page whose
layout depends on the documented version:
  - wrapped builds (eliom >= 13 / dev): <lib>/Eliom/A/B/C/index.html
  - flat builds    (eliom 12.x latest): <lib>/A/B/C/index.html (no Eliom/ wrapper)
We therefore probe the generated HTML tree (given as <src-root>) and pick the
layout that actually exists, instead of hard-coding the Eliom/ wrapper.

Usage: gen-nav.py <indexdoc> <base-url> <lib-dir> [<src-root>]
   e.g. gen-nav.py server.indexdoc /wodoc/eliom/dev eliom.server _work/html/eliom
"""
import html
import os
import re
import sys

indexdoc, base, lib = sys.argv[1], sys.argv[2], sys.argv[3]
src_root = sys.argv[4] if len(sys.argv) > 4 else None
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


def page_rel(mod):
    """Path of [mod]'s page under [lib], picking the layout that exists on disk.
    Wrapped (Eliom/<path>) for eliom >= 13, flat (<path>) for 12.x. When the tree
    is not available, default to wrapped to preserve the dev (wrapped) behaviour."""
    segs = mod.split(".")
    wrapped = "/".join([lib, "Eliom"] + segs) + "/index.html"
    flat = "/".join([lib] + segs) + "/index.html"
    if src_root:
        if os.path.exists(os.path.join(src_root, *wrapped.split("/"))):
            return wrapped
        if os.path.exists(os.path.join(src_root, *flat.split("/"))):
            return flat
    return wrapped


def page_url(mod):
    return f"{base}/{page_rel(mod)}"


out = ['<nav class="api-nav">', "<h3>Modules</h3>"]
first = True
for title, mods in sections:
    if not mods:
        continue
    if title and title not in ("Server API", "Client API", "Index"):
        out.append(f"<h4>{html.escape(title)}</h4>")
    out.append('<ul class="api-section">')
    for mod in mods:
        out.append(
            f'<li data-wodoc-page="{html.escape(mod)}">'
            f'<a href="{page_url(mod)}">{html.escape(mod)}</a></li>'
        )
    out.append("</ul>")
    first = False
out.append("</nav>")
sys.stdout.write("\n".join(out) + "\n")
