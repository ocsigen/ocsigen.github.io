#!/usr/bin/env python3
"""Link Lwt's cross-PACKAGE references inside one version's output.

`dune build @doc` documents every lwt* package into the same tree, but odoc only
resolves references along dependency edges. The base library lwt does NOT depend
on its sibling packages (lwt_ppx, lwt_react, lwt_retry), so a manual/api
reference like {!Ppx_lwt} is left unresolved. odoc renders it either as

  <span class="xref-unresolved" title="Lwt_react.S">S</span>      (replacement text)

or, for a bare {!Ppx_lwt}, as a plain inline <code>Ppx_lwt</code> — even though
that module IS built, in a sibling directory of the same version. We rewrite
those into RELATIVE links to the sibling package's subtree, so the cross-package
links work in the preview and in the final flat layout alike (the sibling dir
sits next to lwt/ under every version). References that don't match a known
sibling wrapper (Stdlib, Unix, React, internal modules, real deps) are left as
text — acceptable, exactly like odoc/ocamldoc (report piège #6).

odoc's wrapped layout puts module M of package P (wrapper module W) at
  <P>/<W>/<M1>/.../index.html  with #val-x / #type-x anchors for leaves.
Lwt's sibling packages are flat (one top module each), so W == that module.

Usage: resolve-siblings.py <base> <file.html>...
  <base>  relative path from the page to the version root (e.g. "..", "../../..")
"""
import html
import re
import sys

BASE = sys.argv[1]
FILES = sys.argv[2:]

# referenced top module -> path segments (under the version root) of that
# module's own directory. Sibling packages are dune-wrapped under a module named
# after the package, so the user-facing module sits below it:
#   {!Ppx_lwt}    -> lwt_ppx/Lwt_ppx/Ppx_lwt/   (wrapper Lwt_ppx contains Ppx_lwt)
#   {!Lwt_react}  -> lwt_react/Lwt_react/        (lib name == module name, no double-wrap)
#   {!Lwt_retry}  -> lwt_retry/Lwt_retry/
SIBLINGS = {
    "Ppx_lwt": ["lwt_ppx", "Lwt_ppx", "Ppx_lwt"],
    "Lwt_react": ["lwt_react", "Lwt_react"],
    "Lwt_retry": ["lwt_retry", "Lwt_retry"],
}

UNRESOLVED = re.compile(
    r'<span class="xref-unresolved[^"]*"(?:\s+title="([^"]*)")?>([^<]*)</span>'
    r"((?:\.[A-Za-z_][A-Za-z0-9_']*)*)"  # optional trailing .members outside span
)
# A bare unresolved reference ({!Ppx_lwt}, no replacement text) is NOT rendered
# as an xref-unresolved span by odoc — it becomes a plain inline
# <code>Ppx_lwt</code>. Link those too, but only qualified names rooted at a
# known sibling wrapper (so ordinary code spans are left alone).
SIB_RE = "|".join(re.escape(w) for w in SIBLINGS)
CODE = re.compile(rf"<code>((?:{SIB_RE})(?:\.[A-Za-z_][A-Za-z0-9_']*)*)</code>")
# Protect <pre> code blocks: a qualified name there is example source, not a ref.
PRE = re.compile(r"<pre\b.*?</pre>", re.S)
KIND = re.compile(r"^(val|type|module|exception|method|class)\s+")


def link_for(raw, label):
    """Return an <a href> link for a qualified name rooted at a sibling wrapper,
    or None if it doesn't resolve to one."""
    kindm = KIND.match(raw.strip())
    kind = kindm.group(1) if kindm else ""
    name = KIND.sub("", raw.strip()).strip("() ")
    toks = [t for t in name.split(".") if t]
    if not toks or toks[0] not in SIBLINGS:
        return None  # not a known sibling package: leave as text (#6)
    base_segs = SIBLINGS[toks[0]]  # dir path to that module's own page
    rest = toks[1:]  # module path below the referenced module, possibly a leaf
    # a lowercase trailing token is a value/type leaf on its parent's page.
    if rest and (kind in ("val", "method") or (not kind and rest[-1][:1].islower())):
        dirs, anchor = rest[:-1], f"#val-{rest[-1]}"
    elif rest and kind == "type":
        dirs, anchor = rest[:-1], f"#type-{rest[-1]}"
    else:
        dirs, anchor = rest, ""
    # path = <base>/<base_segs...>/<dirs...>/index.html
    segs = base_segs + dirs
    url = f"{BASE}/" + "/".join(segs) + f"/index.html{anchor}"
    return url


def fix_span(m):
    title, visible, trailing = m.group(1), m.group(2), m.group(3)
    label = visible + trailing
    url = link_for(title if title else label, label)
    return f'<a href="{url}">{html.escape(label)}</a>' if url else m.group(0)


def fix_code(m):
    name = m.group(1)
    url = link_for(name, name)
    # keep the <code> styling inside the link, as odoc does for resolved refs
    return f'<a href="{url}"><code>{html.escape(name)}</code></a>' if url else m.group(0)


def process(segment):
    return CODE.sub(fix_code, UNRESOLVED.sub(fix_span, segment))


for path in FILES:
    src = open(path).read()
    # process only outside <pre> code blocks (qualified names there are examples)
    parts, last = [], 0
    for pm in PRE.finditer(src):
        parts.append(process(src[last : pm.start()]))
        parts.append(pm.group(0))
        last = pm.end()
    parts.append(process(src[last:]))
    out = "".join(parts)
    if out != src:
        open(path, "w").write(out)
