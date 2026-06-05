#!/usr/bin/env python3
"""Point ocsigen-start's Eliom API cross-references at the Eliom wodoc doc.

Two problems are fixed, per page side (server/client):

1. Resolved refs. odoc_driver --remap emits dependency refs as
   https://ocaml.org/p/eliom/<ver>/doc/<module-path> WITHOUT the library
   directory. But our Eliom wodoc build (also odoc_driver) puts modules under
   eliom.server/ and eliom.client/ (server and client expose the same module
   names). A bare prefix rewrite therefore 404s. We insert the matching lib dir.

2. Unresolved refs. eliom 12's wrapped-module (`Eliom.Content`, `Eliom.Service`,
   …) odoc metadata doesn't fully resolve cross-package, so odoc renders e.g.
   `Eliom.Content.Html.elt` as <span class="xref-unresolved">Eliom</span>.Content.Html.elt
   (plain text). We turn those into real links too.

Both are mapped to the FLAT module layout (`Eliom_content/Html/…`), which exists
on both sides (the wrapped `Eliom/…` tree is only complete on the client), so the
target always exists regardless of the page side.

Usage: resolve-eliom-refs.py <server|client> <file.html>...
"""
import html
import re
import sys

SIDE = sys.argv[1]
BASE = f"https://ocsigen.org/wodoc/eliom/latest/eliom.{SIDE}"


def flat_module(comp):
    """Flat module name for a component sitting directly under the `Eliom`
    wrapper: `Content` -> `Eliom_content`, but an already-prefixed re-export
    such as `Eliom_react` / `Eliom_form` stays as-is."""
    return comp if comp.startswith("Eliom_") else "Eliom_" + comp.lower()


def flat_path(path):
    """Collapse a leading wrapped `Eliom/<Cap>` segment to its flat module.
    `Eliom/Content/Html/D/index.html` -> `Eliom_content/Html/D/index.html`,
    `Eliom/Eliom_react/Down/...` -> `Eliom_react/Down/...`; an already-flat
    `Eliom_content/Html/...` is returned unchanged."""
    m = re.match(r"Eliom/([A-Z][A-Za-z0-9_']*)(/.*)?$", path)
    if m:
        return flat_module(m.group(1)) + (m.group(2) or "")
    return path


def fix_resolved(m):
    return f'href="{BASE}/{flat_path(m.group(1))}"'


# 1. Resolved dependency links: ocaml.org/p/eliom/<ver>/doc/<path> -> our doc.
RESOLVED = re.compile(r'href="https://ocaml\.org/p/eliom/[^/"]+/doc/([^"]+)"')

# 2. Unresolved refs: <span class="xref-unresolved">Eliom</span>.A.B.leaf
UNRESOLVED = re.compile(
    r'<span class="xref-unresolved">Eliom</span>((?:\.[A-Za-z_][A-Za-z0-9_\']*)+)'
)


def fix_unresolved(m):
    comps = m.group(1).lstrip(".").split(".")  # e.g. ["Content","Html","elt"]
    leaf = comps[-1]
    if leaf[:1].islower():  # a value/type leaf -> module = everything before it
        mods, anchor = comps[:-1], f"#type-{leaf}"
    else:  # the whole path is a module
        mods, anchor = comps, ""
    if not mods:
        return m.group(0)  # nothing to point at; leave as plain text
    # mods is the wrapped path under Eliom; map its head to the flat module.
    url = f"{BASE}/{flat_module(mods[0])}" + "".join("/" + c for c in mods[1:])
    url += f"/index.html{anchor}"
    text = "Eliom" + m.group(1)
    return f'<a href="{url}">{html.escape(text)}</a>'


for path in sys.argv[2:]:
    src = open(path).read()
    out = UNRESOLVED.sub(fix_unresolved, RESOLVED.sub(fix_resolved, src))
    if out != src:
        open(path, "w").write(out)
