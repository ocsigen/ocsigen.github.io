#!/usr/bin/env python3
"""Build the manual's left-column navigation from its wikicreole menu
(doc/dev/manual/menu.wiki): == / === headings become section labels and
[[page|Title]] links become entries pointing at <base>/manual/<page>.html.

External <<a_manual project="tuto" ...>> entries are skipped (they live in the
tutorial). Usage: gen-manual-nav.py <menu.wiki> <base-url>
"""
import html
import re
import sys

menu, base = sys.argv[1], sys.argv[2]
out = ['<nav class="api-nav">', "<h3>Manual</h3>"]
for raw in open(menu):
    line = raw.rstrip("\n")
    m = re.match(r"^(=+)\s*(.*)$", line)
    if not m:
        continue
    text = m.group(2).strip()
    link = re.match(r"\[\[([^|\]]+)\|([^\]]+)\]\]", text)
    if link:
        page, title = link.group(1).strip(), link.group(2).strip()
        out.append(
            f'<a class="manual-link" href="{base}/manual/{page}.html">'
            f"{html.escape(title)}</a>"
        )
    elif text and "<<" not in text and "[[" not in text:
        # a plain section heading (== Server-side programming, === Services)
        out.append(f"<h4>{html.escape(text)}</h4>")
out.append("</nav>")
sys.stdout.write("\n".join(out) + "\n")
