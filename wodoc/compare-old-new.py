#!/usr/bin/env python3
# QA: systematic content-regression check, old site vs new wodoc site.
# For each manual page, compares the content-area section headings (after the
# .rightcol marker; nav is before it) and text length of ocsigen.org/<proj>/...
# (old html_of_wiki/ocamldoc) vs ocsigen.org/wodoc/<proj>/... (new). A heading in
# the old not found in the new = a section lost in conversion. Run: python3 this.
import re, urllib.request, sys

def fetch(u):
    try: return urllib.request.urlopen(u, timeout=25).read().decode('utf-8','replace')
    except Exception: return None

def content(h):
    i = h.find('class="rightcol"'); return h[i:] if i>0 else h

def norm(t):
    t = re.sub(r'<!--.*?-->','',t); t = re.sub(r'<[^>]+>','',t)
    t = t.replace('&#182;','').replace('¶','').replace('&amp;','&')
    return re.sub(r'[\s\W]+',' ',t).strip().lower()

def headings(h):
    out=[]
    for _,t in re.findall(r'<(h[1-4])\b[^>]*>(.*?)</\1>', content(h), re.S):
        t=norm(t)
        if t and t not in ('on this page','manual','modules'): out.append(t)
    return out

def run(name, OLD, NEW, pages):
    print(f"\n===== {name} =====")
    total_lost=0
    for p in pages:
        o=fetch(OLD%p); n=fetch(NEW%p)
        if o is None or n is None: print(f"  {p:26} FETCH old={o is not None} new={n is not None}"); continue
        oh,nh=headings(o),headings(n); nset=set(nh)
        lost=[x for x in oh if x not in nset]
        total_lost+=len(lost)
        if lost: print(f"  {p:26} ⚠ LOST {len(lost)}: {('; '.join(lost[:4]))[:70]}")
    print(f"  -> total lost section headings: {total_lost}")

eliom_pages="clientserver-applications clientserver-cache clientserver-communication clientserver-html clientserver-react clientserver-services clientserver-wrapping config eliom-language intro misc mobile-apps overview ppx-migration ppx-syntax scalability server-links server-outputs server-params server-security server-services server-state workflow-configuration workflow-distillery".split()
run("ELIOM latest (old 11.x vs new latest)", "https://ocsigen.org/eliom/11.x/manual/%s.html", "https://ocsigen.org/wodoc/eliom/latest/%s.html", eliom_pages)
run("ELIOM dev (old dev vs new dev)", "https://ocsigen.org/eliom/dev/manual/%s.html", "https://ocsigen.org/wodoc/eliom/dev/%s.html", eliom_pages)

oss_pages="accesscontrol authbasic config cors deflatemod eliom extend extendconfiguration launching outputfilter quickstart redirectmod revproxy rewritemod staticlink staticmod userconf".split()
run("OCSIGENSERVER latest (old 7.0 vs new latest)", "https://ocsigen.org/ocsigenserver/7.0/manual/%s", "https://ocsigen.org/wodoc/ocsigenserver/latest/%s.html", oss_pages)
run("OCSIGENSERVER dev (old dev vs new dev)", "https://ocsigen.org/ocsigenserver/dev/manual/%s", "https://ocsigen.org/wodoc/ocsigenserver/dev/%s.html", oss_pages)
