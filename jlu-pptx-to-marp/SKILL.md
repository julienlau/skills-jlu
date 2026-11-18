---
name: jlu-pptx-to-marp
description: Convert presentations from PPTX to PDF and Marp-compatible Markdown slides. Use when the user asks to convert pptx files to pdf, generate Marp MD versions of slides, extract slide decks, or make markdown handouts from PowerPoint presentations. Use ONLY for presentation conversion tasks, not general document conversion.
---

# PPTX to PDF + Marp Markdown

Convert every `*.pptx` in the current directory to PDF (LibreOffice), then
produce a Marp-flavored Markdown version of each deck. Figures are NOT
reproduced: they are only flagged with a placeholder note.

Do not commit anything. At the end, list the produced files (PDF + MD).

## Step 1 — Convert PPTX to PDF

```bash
libreoffice --headless --convert-to pdf --outdir . *.pptx
```

The `javaldx` warning is harmless.

## Step 2 — Extract text page by page

Do NOT parse the PPTX XML. Extract from the PDFs instead: one PDF page =
one Marp slide, and pages are separated by form feeds (`\f`).

```bash
pdftotext -layout file.pdf file.txt   # for each PDF
```

`python-pptx` is not needed.

## Step 3 — Generate the Marp MD files

Use this script (adapt the `.txt` list; title = first meaningful line of the
title slide, date = date in the filename or title slide):

```python
#!/usr/bin/env python3
import re, pathlib

OUT = pathlib.Path(".").resolve()
FIG_NOTE = "> _[figure — voir PDF source]_"
SENT = "\x00GAP\x00"

def collapse_blanks(lines):
    out, blank = [], 0
    for ln in lines:
        if ln.strip() == "":
            blank += 1; continue
        if blank >= 2 and out and out[-1] != "": out.append(SENT)
        elif blank >= 1: out.append("")
        blank = 0; out.append(ln.rstrip())
    while out and (out[0] == "" or out[0] == SENT): out.pop(0)
    while out and (out[-1] == "" or out[-1] == SENT): out.pop()
    return out

def fmt_body(body):
    out, pending = [], ""
    for ln in body:
        if ln == "": pending = pending or "blank"; continue
        if ln == SENT: pending = "gap"; continue
        if pending == "gap" and out: out += ["", FIG_NOTE, ""]
        elif pending == "blank" and out: out.append("")
        pending = ""
        indent = len(ln) - len(ln.lstrip(" ")); s = ln.strip()
        if s.startswith("•"): out.append("- " + s[1:].strip())
        elif re.match(r"^o\s+", s): out.append("    - " + re.sub(r"^o\s+", "", s))
        elif re.match(r"^\d+\.\s", s): out.append("    " + s)
        elif indent > 0: out.append("  " + s)
        else: out.append(s)
    return out

def convert(txt_path, base, title, date, author, subtitle):
    pages = pathlib.Path(txt_path).read_text().split("\f")
    md = ["---", "marp: true", "paginate: true", "", f"# {title}", "",
          subtitle, "", author, "", date, "", "<!-- _class: lead -->", ""]
    for page in pages[1:]:
        lines = collapse_blanks(page.split("\n"))
        if not lines: continue
        md += ["---", ""]
        if len(lines) == 1:  # section divider slide
            md += [f"# {lines[0]}", "", "<!-- _class: lead -->", ""]
            continue
        md += [f"## {lines[0]}", ""]
        md += fmt_body(lines[1:]); md.append("")
    (OUT / f"{base}.md").write_text("\n".join(md).rstrip() + "\n")
```

Slide conventions:

- Frontmatter: `marp: true`, `paginate: true`.
- Title slide: `# Title`, then author, date, `<!-- _class: lead -->`.
- Section dividers (single-line pages): `# Title` + `<!-- _class: lead -->`.
- Normal slides: `## Title` + body; bullets `- `; sub-bullets `    - `;
  numbered sub-items indented with 4 spaces; continuation lines indented 2
  spaces.

## Step 4 — Manual fixes (systematic)

PDF text extraction always breaks these cases; check every slide:

- **Figures**: keep the `> _[figure — voir PDF source]_` note inserted by the
  script for big blank gaps, and also add it to test/dashboard slides (fio
  results, Grafana) where the gap precedes the first text.
- **Callout slides split in two titles** (e.g. a slide titled `Minio` with the
  real title `hardware` in the callout): merge into one slide
  (`## Minio hardware`) + figure note + callout text as a bullet.
- **Words/URLs wrapped mid-token** (e.g. `erasure-coding-cal\nculator/`):
  rejoin them.
- **Screenshot notes** (e.g. `To Be Cheked: Uncomment` next to a
  `minio.service` capture): replace with
  `- To Be Checked: Uncomment options in \`minio.service\``.
- **Raw-text tables**: rebuild as proper markdown tables.
- **Two-column jumbled text** (SQL blocks, Grafana readings, pros/cons next to
  code): restructure into a clean ```sql block and/or readable bullets; mark
  unrecoverable values as `_[valeur dans la figure]_`.
- **Typos of the original**: keep them (faithful conversion), except an
  obvious copy-paste error in the title-slide date (then use the filename
  date).

## Step 5 — Validate

Render each MD with marp-cli:

```bash
npx --yes @marp-team/marp-cli@latest -o /tmp/check.pdf file.md
```

Success = no error; page count must roughly match the slide count.

## Required tools

`libreoffice`, `pdftotext` (poppler-utils), `node`/`npx` (for marp-cli).