#!/usr/bin/env python3
"""Briefkist website builder — stdlib only, no dependencies.

Reads page bodies from src/pages/**/*.html (each with a leading
`<!-- key: value -->` metadata comment), wraps them with the shared head,
src/partials/nav.html and footer.html, substitutes {{variables}}, and
writes the result to dist/. Assets are copied verbatim.

Usage: python3 build.py
"""
import re
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
SRC, DIST = ROOT / "src", ROOT / "dist"

HEAD = """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{{title}}</title>
<meta name="description" content="{{description}}">
<link rel="stylesheet" href="{{root}}assets/site.css">
<script>try{if(localStorage.getItem("bk-theme")==="dark")document.documentElement.setAttribute("data-theme","dark")}catch(e){}</script>
<script src="{{root}}assets/site.js" defer></script>
</head>
<body>
"""
FOOT = "\n</body>\n</html>\n"
META_RE = re.compile(r"\A\s*<!--(.*?)-->\s*", re.S)
VAR_RE = re.compile(r"\{\{(\w+)\}\}")
NAV_SECTIONS = ("home", "pricing", "security", "docs")


def parse_page(text):
    """Split a page into (metadata dict, body)."""
    m = META_RE.match(text)
    if not m:
        return {}, text
    meta = {}
    for line in m.group(1).splitlines():
        if ":" in line:
            key, _, val = line.partition(":")
            if key.strip():
                meta[key.strip()] = val.strip()
    return meta, text[m.end():]


def substitute(text, variables):
    return VAR_RE.sub(lambda m: variables.get(m.group(1), ""), text)


def build():
    if DIST.exists():
        shutil.rmtree(DIST)
    DIST.mkdir(parents=True)
    shutil.copytree(SRC / "assets", DIST / "assets")

    nav = (SRC / "partials" / "nav.html").read_text()
    footer = (SRC / "partials" / "footer.html").read_text()

    pages = sorted((SRC / "pages").rglob("*.html"))
    for page in pages:
        rel = page.relative_to(SRC / "pages")
        meta, body = parse_page(page.read_text())
        variables = dict(meta)
        variables.setdefault("root", "../" * (len(rel.parts) - 1))
        active = meta.get("active", "")
        for section in NAV_SECTIONS:
            variables[f"active_{section}"] = "is-active" if active == section else ""
            variables[f"aria_{section}"] = 'aria-current="page"' if active == section else ""

        parts = [HEAD]
        if meta.get("chrome") != "none":
            parts.append(nav)
        parts.append(body)
        if meta.get("chrome") != "none":
            parts.append(footer)
        parts.append(FOOT)
        html = substitute("".join(parts), variables)

        out = DIST / rel
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(html)
        print(f"built {rel}")
    print(f"{len(pages)} pages -> {DIST}")


if __name__ == "__main__":
    sys.exit(build())
