#!/usr/bin/env python3
"""Link js_of_ocaml's cross-PACKAGE references inside one version's output.

`dune build @doc` documents every js_of_ocaml* package into the same tree, but
odoc only resolves references along dependency edges. The base library
js_of_ocaml does NOT depend on its sibling packages (js_of_ocaml-lwt, -tyxml,
-toplevel), so a manual/api reference like {!Js_of_ocaml_lwt.Lwt_js} is left
unresolved and rendered as

  <span class="xref-unresolved" title="Js_of_ocaml_lwt.Lwt_js">Lwt_js</span>

even though that module IS built, in a sibling directory of the same version.
We rewrite those spans into RELATIVE links to the sibling package's subtree, so
the cross-package links work in the preview and in the final flat layout alike
(the sibling dir sits next to js_of_ocaml/ under every version). References that
don't match a known sibling wrapper (Stdlib, internal modules, real deps) are
left as text — acceptable, exactly like odoc/ocamldoc (report piège #6).

odoc's wrapped layout puts module M of package P (wrapper module W) at
  <P>/<W>/<M1>/<M2>/.../index.html
with a #val-x / #type-x anchor for a leaf value/type.

Usage: resolve-siblings.py <base> <file.html>...
  <base>  relative path from the page to the version root (e.g. "..", "../../..")
"""
import html
import re
import sys

BASE = sys.argv[1]
FILES = sys.argv[2:]

# wrapper module -> package directory (its modules live at <dir>/<wrapper>/...).
SIBLINGS = {
    "Js_of_ocaml_lwt": "js_of_ocaml-lwt",
    "Js_of_ocaml_tyxml": "js_of_ocaml-tyxml",
    "Js_of_ocaml_toplevel": "js_of_ocaml-toplevel",
}

UNRESOLVED = re.compile(
    r'<span class="xref-unresolved[^"]*"(?:\s+title="([^"]*)")?>([^<]*)</span>'
    r"((?:\.[A-Za-z_][A-Za-z0-9_']*)*)"  # optional trailing .members outside span
)
# A bare unresolved reference ({!Js_of_ocaml_lwt.X}, no replacement text) is NOT
# rendered as an xref-unresolved span by odoc — it becomes a plain inline
# <code>Js_of_ocaml_lwt.X</code>. Link those too, but only the qualified names
# rooted at a known sibling wrapper (so ordinary code spans are left alone).
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
    pkgdir = SIBLINGS[toks[0]]
    rest = toks[1:]  # module path below the wrapper, possibly ending in a leaf
    # a lowercase trailing token is a value/type leaf on its parent's page.
    if rest and (kind in ("val", "method") or (not kind and rest[-1][:1].islower())):
        dirs, anchor = rest[:-1], f"#val-{rest[-1]}"
    elif rest and kind == "type":
        dirs, anchor = rest[:-1], f"#type-{rest[-1]}"
    else:
        dirs, anchor = rest, ""
    # path = <base>/<pkgdir>/<wrapper>/<dirs...>/index.html
    segs = [toks[0]] + dirs
    url = f"{BASE}/{pkgdir}/" + "/".join(segs) + f"/index.html{anchor}"
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
