#!/usr/bin/env python3
"""Rewrite an Ocsigen doc page's cross-references to sibling Ocsigen projects
into RELATIVE links to their wodoc docs. Shared by every project's build.sh.

Two kinds of references are handled, per page side (server/client/""):

1. Resolved dep links. odoc_driver --remap emits dependency refs as
   https://ocaml.org/p/<pkg>/<ver>/doc/<module-path>. For a project we host
   under /wodoc we rewrite them to <relroot>/<project>/latest/…; deps we don't
   host (lwt, tyxml, js_of_ocaml, …) are left on ocaml.org, where they have a
   real doc.

2. Unresolved refs. A multi-library package (eliom, ocsigen-toolkit) documents
   its server and client libs side by side, and its wrapped-module odoc
   metadata sometimes fails to resolve cross-package, so odoc renders e.g.
   `Eliom.Content.Html.elt` as <span class="xref-unresolved">Eliom</span>.Content…
   (plain text). We turn those into links too.

Multi-library packages keep their modules under <pkg>.server/ and <pkg>.client/
(same module names on both sides), so the link must carry the page side and the
matching lib dir. We always target the FLAT module layout (`Eliom_content`,
`Ot_buttons`, …): it exists on both sides and on the released `latest` docs,
whereas the wrapped `Eliom/…`/`Ot/…` tree is only complete on some sides/versions.

Links are RELATIVE: <relroot> is the path from the page up to the shared root
that holds eliom/, ocsigen-toolkit/, … This keeps them correct wherever that
root is mounted (preview /wodoc/… or the final layout) and under the `latest`
symlink — exactly like the manual's cross-project links (report piège #10).

Usage: resolve-deps.py <server|client|""> <relroot> <file.html>...
"""
import html
import re
import sys

SIDE = sys.argv[1] or "server"  # manual pages (no side) seldom carry API refs
RELROOT = sys.argv[2]

# Hosted Ocsigen projects we redirect into /wodoc. Per pkg: (project dir under
# the shared root, is-multi-library, wrapper module). The wrapper is the module
# that re-exports the flat modules (`Eliom.Content` == `Eliom_content`,
# `Ocsigen.Extensions` == `Ocsigen_extensions`), used to map wrapped canonical
# paths to the flat layout that the deployed docs actually use. Multi-library
# packages (eliom, toolkit, start) document server and client side by side, so
# their links also carry the page side and the matching <pkg>.<side>/ lib dir;
# single-library ones (ocsigenserver) keep their modules at the doc root.
HOSTED = {  # pkg -> (dir, multilib, wrapper)
    "eliom": ("eliom", True, "Eliom"),
    "ocsigen-toolkit": ("ocsigen-toolkit", True, "Ot"),
    "ocsigen-start": ("ocsigen-start", True, "Os"),
    "ocsigenserver": ("ocsigenserver", False, "Ocsigen"),
}


def flat_module(comp, wrapper):
    """Flat module name for a component directly under <wrapper>:
    (`Content`, `Eliom`) -> `Eliom_content`; an already-prefixed re-export such
    as `Eliom_react` stays as-is."""
    pre = wrapper + "_"
    return comp if comp.startswith(pre) else pre + comp.lower()


def flat_path(path, wrapper):
    """Collapse a leading wrapped `<wrapper>/<Comp>` segment to its flat module.
    `Eliom/Content/Html/index.html` -> `Eliom_content/Html/index.html`;
    an already-flat path is returned unchanged."""
    m = re.match(rf"{wrapper}/([A-Z][A-Za-z0-9_']*)(/.*)?$", path)
    if m:
        return flat_module(m.group(1), wrapper) + (m.group(2) or "")
    return path


def dep_base(pkg):
    d, multilib, _ = HOSTED[pkg]
    base = f"{RELROOT}/{d}/latest"
    return f"{base}/{d}.{SIDE}" if multilib else base


def fix_resolved(m):
    pkg, path = m.group(1), m.group(2)
    # Source-view links (.../src/<lib>/<file>.ml.html): not all our docs render
    # source, but ocaml.org always does — leave them there so they never 404.
    if pkg in HOSTED and not path.startswith("src/"):
        return f'href="{dep_base(pkg)}/{flat_path(path, HOSTED[pkg][2])}"'
    return m.group(0)  # not hosted / source view: keep the ocaml.org link


RESOLVED = re.compile(r'href="https://ocaml\.org/p/([^/"]+)/[^/"]+/doc/([^"]+)"')

# Unresolved refs to a hosted project. odoc renders an unresolved reference as
# <span class="xref-unresolved" title="Fully.Qualified.name">visible text</span>
# (sometimes with extra classes, e.g. "xref-unresolved row"). The `title` carries
# the full qualified path, which is the reliable source for the link; the visible
# text (a leaf, or a "val M.x" form) is kept as the link label. When there is no
# title we fall back to the visible text. A leading kind word and the
# "(Module.x ())" wrapping that odoc sometimes adds are stripped.
WRAPPERS = {w: pkg for pkg, (_, _, w) in HOSTED.items()}
UNRESOLVED = re.compile(
    r'<span class="xref-unresolved[^"]*"(?:\s+title="([^"]*)")?>([^<]*)</span>'
)
KIND = re.compile(r"^(val|type|module|exception|method|class)\s+")


def fix_unresolved(m):
    title, text = m.group(1), m.group(2)
    name = title if title else text
    name = KIND.sub("", name.strip()).strip("() ")
    toks = [t for t in name.split(".") if t]
    if not toks:
        return m.group(0)
    head = toks[0]
    wrapper = next((w for w in WRAPPERS if head == w or head.startswith(w + "_")), None)
    if wrapper is None:
        return m.group(0)  # a dep we don't host (lwt, tyxml, …): leave as text
    pkg = WRAPPERS[wrapper]
    if head == wrapper:  # bare wrapper: next token is the (flat) module
        if len(toks) < 2:
            return m.group(0)
        modhead, rest = flat_module(toks[1], wrapper), toks[2:]
    else:  # head is already a flat module name
        modhead, rest = head, toks[1:]
    # a lowercase trailing token is a value/type leaf living on its parent page;
    # default the anchor to #val- (the common case) — a wrong guess still lands
    # on the right page, just without scrolling.
    if rest and rest[-1][:1].islower():
        dirs, anchor = rest[:-1], f"#val-{rest[-1]}"
    else:
        dirs, anchor = rest, ""
    url = f"{dep_base(pkg)}/{modhead}"
    url += "".join("/" + d for d in dirs) + f"/index.html{anchor}"
    return f'<a href="{url}">{html.escape(text)}</a>'


for path in sys.argv[3:]:
    src = open(path).read()
    out = UNRESOLVED.sub(fix_unresolved, RESOLVED.sub(fix_resolved, src))
    if out != src:
        open(path, "w").write(out)
