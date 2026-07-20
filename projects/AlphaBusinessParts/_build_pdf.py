#!/usr/bin/env python3
"""Converte markdown da pasta AlphaBusinessParts em PDF (WeasyPrint)."""
from __future__ import annotations

import sys
from pathlib import Path

import markdown
from weasyprint import HTML

BASE = Path(__file__).parent

CSS = """
@page { size: A4; margin: 16mm 15mm; }
body {
  font-family: "DejaVu Sans", Helvetica, Arial, sans-serif;
  font-size: 10pt; color: #1a1a1a; line-height: 1.45;
}
h1 { font-size: 17pt; color: #0f2a4a; border-bottom: 2px solid #0f2a4a;
     padding-bottom: 4px; margin: 0 0 10px 0; }
h2 { font-size: 13pt; color: #14406b; margin: 16px 0 6px 0;
     border-bottom: 1px solid #cdd9e6; padding-bottom: 2px; }
h3 { font-size: 11pt; color: #1f5288; margin: 12px 0 4px 0; }
p, li { font-size: 10pt; margin: 4px 0; }
code { background: #f0f2f5; font-family: "DejaVu Sans Mono", monospace;
       font-size: 8.5pt; padding: 1px 3px; }
blockquote { background: #f5f8fb; border-left: 3px solid #1f5288;
  margin: 8px 0; padding: 6px 10px; color: #33424f; font-size: 9.5pt; }
table { width: 100%; border-collapse: collapse; margin: 8px 0 12px 0;
        table-layout: fixed; }
th { background: #14406b; color: #fff; font-size: 8pt; font-weight: bold;
     padding: 5px 6px; text-align: left; }
td { border: 0.5pt solid #cdd9e6; font-size: 8pt; padding: 5px 6px;
     vertical-align: top; overflow-wrap: break-word; word-wrap: break-word; }
tr:nth-child(even) td { background: #f5f8fb; }
tr.tot td { background: #e8eef5; }
hr { border: 0; border-top: 1px solid #cdd9e6; margin: 12px 0; }
strong { color: #0f2a4a; }
td.val, th.val { text-align: right; white-space: nowrap; }

/* Investimento: larguras fixas em mm (área útil ~180mm) */
table.valores3 { width: 180mm; }
table.valores3 col.c1 { width: 55mm; }
table.valores3 col.c2 { width: 90mm; }
table.valores3 col.c3 { width: 35mm; }
table.valores3 td:nth-child(3), table.valores3 th:nth-child(3) {
  text-align: right; white-space: nowrap;
}

table.valores4 { width: 180mm; }
table.valores4 col.d1 { width: 14mm; }
table.valores4 col.d2 { width: 40mm; }
table.valores4 col.d3 { width: 91mm; }
table.valores4 col.d4 { width: 35mm; }
table.valores4 td:nth-child(4), table.valores4 th:nth-child(4) {
  text-align: right; white-space: nowrap;
}
"""


def md_to_html(md_path: Path) -> str:
    text = md_path.read_text(encoding="utf-8")
    body = markdown.markdown(
        text,
        extensions=["tables", "fenced_code", "sane_lists", "md_in_html"],
    )
    return (
        "<!DOCTYPE html><html><head><meta charset='utf-8'/>"
        f"<style>{CSS}</style></head><body>{body}</body></html>"
    )


def convert(md_path: Path, pdf_path: Path) -> None:
    HTML(string=md_to_html(md_path), base_url=str(BASE)).write_pdf(str(pdf_path))


docs = [
    ("RESEARCH-ALPHABUSINESSPARTS.md", "RESEARCH-ALPHABUSINESSPARTS.pdf"),
    ("PROPOSTA-ALPHABUSINESSPARTS.md", "PROPOSTA-ALPHABUSINESSPARTS.pdf"),
    ("STATUS-ONBOARDING.md", "STATUS-ONBOARDING.pdf"),
]

ok = True
for md, pdf in docs:
    try:
        convert(BASE / md, BASE / pdf)
        print(f"[OK] {pdf}")
    except Exception as exc:  # noqa: BLE001
        print(f"[FALHA] {pdf}: {exc}")
        ok = False

sys.exit(0 if ok else 1)
