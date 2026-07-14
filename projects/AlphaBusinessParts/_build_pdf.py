#!/usr/bin/env python3
"""Converte os documentos markdown da proposta AlphaBusinessParts em PDF.

Uso:
  python3 -m venv .venv && .venv/bin/pip install xhtml2pdf markdown
  .venv/bin/python _build_pdf.py
"""
import sys
from pathlib import Path
import markdown
from xhtml2pdf import pisa

BASE = Path(__file__).parent

CSS = """
@page { size: A4; margin: 2cm 1.8cm; }
body { font-family: Helvetica, Arial, sans-serif; font-size: 10pt; color: #1a1a1a; line-height: 1.45; }
h1 { font-size: 19pt; color: #0f2a4a; border-bottom: 2px solid #0f2a4a; padding-bottom: 4px; margin-top: 6px; }
h2 { font-size: 14pt; color: #14406b; margin-top: 18px; border-bottom: 1px solid #cdd9e6; padding-bottom: 2px; }
h3 { font-size: 11.5pt; color: #1f5288; margin-top: 12px; }
p, li { font-size: 10pt; }
code { background: #f0f2f5; font-family: Courier, monospace; font-size: 9pt; padding: 1px 3px; }
blockquote { background: #f5f8fb; border-left: 3px solid #1f5288; margin: 8px 0; padding: 6px 10px; color: #33424f; font-size: 9.5pt; }
table { width: 100%; border-collapse: collapse; margin: 10px 0; }
th { background: #14406b; color: #ffffff; font-size: 8.5pt; padding: 5px 6px; text-align: left; }
td { border: 0.5px solid #cdd9e6; font-size: 8.5pt; padding: 4px 6px; vertical-align: top; }
tr:nth-child(even) td { background: #f5f8fb; }
hr { border: 0; border-top: 1px solid #cdd9e6; margin: 14px 0; }
strong { color: #0f2a4a; }
"""


def convert(md_path: Path, pdf_path: Path) -> bool:
    text = md_path.read_text(encoding="utf-8")
    html_body = markdown.markdown(
        text, extensions=["tables", "fenced_code", "sane_lists"]
    )
    html = (
        f"<html><head><meta charset='utf-8'><style>{CSS}</style></head>"
        f"<body>{html_body}</body></html>"
    )
    with open(pdf_path, "wb") as out:
        result = pisa.CreatePDF(html, dest=out, encoding="utf-8")
    return not result.err


docs = [
    ("RESEARCH-ALPHABUSINESSPARTS.md", "RESEARCH-ALPHABUSINESSPARTS.pdf"),
    ("PROPOSTA-ALPHABUSINESSPARTS.md", "PROPOSTA-ALPHABUSINESSPARTS.pdf"),
]

ok = True
for md, pdf in docs:
    success = convert(BASE / md, BASE / pdf)
    print(f"{'[OK]' if success else '[FALHA]'} {pdf}")
    ok = ok and success

sys.exit(0 if ok else 1)
