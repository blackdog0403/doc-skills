---
name: md-to-docx
description: |
  Convert markdown files to professionally styled Word documents (.docx) with
  AWS branding. Supports English/Korean, custom footers, badges, tables, and
  batch conversion. Trigger on: "md를 docx로", "markdown to word", "문서 변환",
  "convert to docx", "/md-to-docx", or any request to turn a .md file into a
  styled Word document.
allowed-tools: [Bash, Read, Write]
---

# Markdown to DOCX Converter

Convert markdown files to styled Word documents (.docx) with AWS branding.

## When to Use

- User asks to convert a markdown file to Word/DOCX
- User says "md를 docx로 변환해줘", "이거 워드로 만들어줘"
- User wants a polished meeting note, report, or deliverable in .docx format

## Usage

```
/md-to-docx '<file_path>'
/md-to-docx '<file_path>, output:report.docx'
/md-to-docx '<file_path>, lang:ko'
/md-to-docx '<file_path>, style:meridian'
/md-to-docx '<file_path>, lang:ko, footer:AWS Meeting Notes | 2026-05-05 | Confidential'
/md-to-docx '<file_path1>' '<file_path2>'
```

## Behavior

Execute the conversion script:

```bash
python3 ~/.local/bin/generate_styled_docx.py "<file_path>" [options]
```

### Argument Parsing

Parse user input to extract file paths and options:

1. **Single file**: `/md-to-docx 'report.md'` → convert one file
2. **Multiple files**: `/md-to-docx 'report.md' 'notes.md'` → convert each file separately
3. **With options**: `/md-to-docx 'report.md, output:out.docx, lang:ko, footer:custom text'`

Map options to CLI flags:
- `output:<path>` → `-o <path>`
- `lang:en` or `lang:ko` → `-l en` or `-l ko`
- `style:aws` or `style:meridian` → `-s aws` or `-s meridian`
- `footer:<text>` → `--footer "<text>"`
- `margin:<top,bottom,left,right>` (cm) → `--margin-top <t> --margin-bottom <b> --margin-left <l> --margin-right <r>`

If no language is specified, the script auto-detects from filename (`-ko.md` → Korean, otherwise English).

### Core Options
- `-o` / `--output`: Output .docx file path (default: same name as input with .docx extension)
- `-l` / `--lang`: Language for badge rules and labels — `en` or `ko` (default: auto-detect)
- `-s` / `--style`: Document style — `aws` (branded, default) or `meridian` (classic Amazon narrative)
- `--footer`: Custom footer text (default: auto-generated with today's date)
- `--margin-top`, `--margin-bottom`, `--margin-left`, `--margin-right`: Page margins in cm. Defaults come from the style — `aws`: top/bottom 2.54, left/right 2.0 · `meridian`: 1.27 all round

### Styles

| | `aws` (default) | `meridian` |
|---|---|---|
| Use for | Customer-facing reports, decks' companion docs | 1-pagers, 6-pagers, PR/FAQ — anything read as a narrative |
| Font | Amazon Ember 11pt | Calibri 10.5pt, justified |
| Color | AWS Orange accents, navy table headers | Pure black & white, gray table headers |
| Headings | Large H1/H2 with orange rule | Body-size bold with a thin black rule |
| Badges | Status + priority badges | Suppressed (plain text) |
| Footer | Centered date · Confidential | "Amazon Confidential" left · "Page X of Y" right |
| Margins | 2.54 / 2.0 cm | 1.27 cm all round |

Pick `meridian` when the user asks for an Amazon narrative, 1-pager/6-pager, PR/FAQ, or "흑백/내부 문서 스타일". Otherwise stay on `aws`.

### Mermaid Diagrams

A fenced ` ```mermaid ` block is rendered as an embedded, centered image (mermaid-cli via `npx`, Korean-safe font stack, high-DPI PNG). If `npx` is unavailable or rendering fails, the block silently falls back to a monospace code box — conversion never breaks because of a diagram.

To get rendered diagrams, `npx` (Node.js) must be on PATH; the first run downloads `@mermaid-js/mermaid-cli` and can take a minute.

### Styling Features
- **AWS-branded**: Amazon Ember 11pt font, AWS Orange (#FF9900) accents
- **Headings**: H1-H6 support with orange underline on H2
- **Key Takeaways**: Orange-accented callout box (auto-detected from blockquotes)
- **Blockquotes**: General blockquotes rendered with gray left border
- **Code blocks**: Fenced code blocks rendered as monospace shaded boxes
- **Mermaid**: ` ```mermaid ` blocks rendered as embedded diagrams (falls back to a code box)
- **Tables**: Dark navy header, alternating row colors, thin borders
- **Badges**: Auto-detected status badges (ON ROADMAP, NOT TODAY, LIMITED, LIMITATION)
- **Priority badges**: High (red), Medium (orange), Low (green) in table cells
- **Inline markdown**: Bold, italic, code, and links rendered properly
- **Numbered & bullet lists**: Orange-accented numbering and bullets

### Language Support
- `en`: English badge rules (e.g., "on the roadmap" → ON ROADMAP badge)
- `ko`: Korean badge rules (e.g., "로드맵에 있" → ON ROADMAP badge)
- Auto-detected from filename: files ending in `-ko.md` default to Korean

### Batch Conversion

When multiple files are provided, pass them all at once:

```bash
python3 ~/.local/bin/generate_styled_docx.py "report.md" "report-ko.md"
```

If the user asks to convert "both English and Korean versions", look for the `-ko.md` counterpart automatically.

## Examples

```
/md-to-docx 'meeting-notes.md'                                          # Auto-detect lang
/md-to-docx 'meeting-notes.md, output:final-report.docx'                # Custom output path
/md-to-docx 'meeting-notes.md, lang:ko'                                 # Force Korean mode
/md-to-docx 'one-pager.md, style:meridian'                              # Amazon narrative style
/md-to-docx 'meeting-notes.md, footer:Team Meeting | May 2026'          # Custom footer
/md-to-docx 'report.md' 'report-ko.md'                                  # Convert both versions
```

## Prerequisites
- `python-docx` installed (`pip install python-docx`)
- Script: `~/.local/bin/generate_styled_docx.py`
- Optional: `npx` (Node.js) for rendering ` ```mermaid ` blocks as diagrams
