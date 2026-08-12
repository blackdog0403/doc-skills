---
name: md-to-docx
description: |
  Convert markdown files to professionally styled Word documents (.docx) with
  AWS branding. Supports English/Korean, custom footers, badges, tables, and
  batch conversion. Trigger on: "markdown to word", "convert to docx",
  "/md-to-docx", or any English or Korean request to turn a .md file into a
  styled Word document.
allowed-tools: [Bash, Read, Write]
---

# Markdown to DOCX Converter

Convert markdown files to styled Word documents (.docx) with AWS branding.

## Output Language Safety

- Conversion must not translate or rewrite the source document.
- Before conversion, explicitly ask which language to use for generated labels and headings: English (default) or Korean.
- Treat `default` as English. Korean is used only when the user selects it.
- Source text, filename suffixes, and the language of the request must never determine this choice.
- Never introduce Korean into non-Korean output.

## When to Use

- User asks to convert a markdown file to Word/DOCX
- User asks in English or Korean to convert Markdown into a Word document
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

## Required Conversion Preflight

Before starting any conversion, collect the generated-label language, footer, and customization choices. Ask only for items the user has not already supplied, and combine missing questions into one message.

1. **Generated-label language** — Ask: **"Which language should the generated document labels use: English (default) or Korean? This controls labels such as the table-of-contents title, metadata labels, badges, and page numbering; it does not translate or rewrite the Markdown."**
   - If the user supplied `lang:en` or `lang:ko`, do not ask again.
   - Map `English`, `en`, or `default` to `en`; map `Korean` or `ko` to `ko`.
   - Never infer the answer from the source text, filename, filename suffix, or language used to invoke the skill.
2. **Footer** — Ask: **"What should the footer say? You can use `{date}` for today's UTC date (for example, `{date} | Team Name | Confidential`). Reply `default` to use `{date} | Confidential`."**
   - If the user supplied `footer:<text>`, do not ask again.
   - If the answer is `default`, omit `--footer`. Otherwise, pass the answer unchanged to `--footer`.
3. **Optional customization** — Ask: **"Any other document customization? Reply `default`, or specify a title page (title, subtitle, author, team, version, classification), table of contents, Page X of Y numbering, header text/logo, page size (Letter/A4/Legal), orientation, or margins."**
   - Do not ask if the user already selected customizations or explicitly requested defaults.
   - `default` means no title page, TOC, page numbering, header, or logo; Letter portrait with standard margins.

Do not run the converter until the required preflight answers are available. For multiple files, apply shared answers to all files unless the user provides per-file settings.

## Behavior

Resolve and execute the bundled helper. Prefer the private CLI wrapper when installed because it carries an isolated Python environment:

```bash
LANGUAGE="<en-or-ko-from-preflight>"
HELPER=""
for candidate in \
  "$HOME/.local/bin/generate_styled_docx.py" \
  "$HOME/.kiro/skills/md-to-docx/scripts/generate_styled_docx.py" \
  "$HOME/.claude/skills/md-to-docx/scripts/generate_styled_docx.py"; do
  if [ -x "$candidate" ]; then HELPER="$candidate"; break; fi
done
[ -n "$HELPER" ] || { echo "generate_styled_docx.py is not installed" >&2; exit 1; }
"$HELPER" "<file_path>" -l "$LANGUAGE" [options]
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
- `title-page:true` → `--title-page`
- `title`, `subtitle`, `author`, `team`, `version`, `classification` → corresponding `--<name> "<value>"` flags; any supplied metadata automatically enables the title page
- `toc:true` → `--toc`
- `page-numbers:true` → `--page-numbers`
- `header:<text>` → `--header "<text>"`
- `logo:<path>` → `--logo "<path>"`
- `page-size:letter|a4|legal` → `--page-size <value>`
- `orientation:portrait|landscape` → `--orientation <value>`
- `margin:<top,bottom,left,right>` (cm) → `--margin-top <t> --margin-bottom <b> --margin-left <l> --margin-right <r>`

If no language is specified in the initial request, ask the generated-label language question. `default` selects English. Always invoke the helper with exactly one explicit `-l en` or `-l ko` flag; filename suffixes do not select language.

### Core Options
- `-o` / `--output`: Output .docx file path (default: same name as input with .docx extension)
- `-l` / `--lang`: Language for badge rules and labels — `en` or `ko` (default: `en`)
- `-s` / `--style`: Document style — `aws` (branded, default) or `meridian` (classic Amazon narrative)
- `--footer`: Footer text; `{date}` expands at generation time (default: `{date} | Confidential`; `Amazon Confidential` under `-s meridian`)
- `--title-page`: Add a title page. `--title`, `--subtitle`, `--author`, `--team`, `--version`, and `--classification` populate it; metadata flags enable the page automatically. Title defaults to the first H1 or filename.
- `--toc`: Add a Word table-of-contents field covering Heading 1 through Heading 3. Word-compatible editors refresh it when the file opens.
- `--page-numbers`: Append auto-updating `Page X of Y` fields to the footer. `-s meridian` already places them in its footer.
- `--header`, `--logo`: Add header text and/or a 2.5 cm-wide image. Supported image formats depend on `python-docx` (PNG, JPEG, GIF, BMP, or TIFF).
- `--page-size`: `letter`, `a4`, or `legal` (default: `letter`)
- `--orientation`: `portrait` or `landscape` (default: `portrait`)
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
- `en`: English generated labels and English badge rules (e.g., "on the roadmap" → ON ROADMAP badge)
- `ko`: Korean generated labels and Korean-language badge matching
- Ask whenever language is omitted. The answer `default` selects `en`; Korean requires an explicit user selection. Filenames and source text are not language signals.

### Batch Conversion

When multiple files are provided, pass them all at once:

```bash
"$HELPER" "report.md" -l en
"$HELPER" "report-ko.md" -l ko
```

If the user explicitly asks to convert both English and Korean versions, locate the counterpart and run each conversion with an explicit `-l en` or `-l ko` flag.

## Examples

```
/md-to-docx 'meeting-notes.md'                                          # Preflight asks; `default` selects English
/md-to-docx 'meeting-notes.md, output:final-report.docx'                # Custom output path
/md-to-docx 'meeting-notes.md, lang:ko'                                 # Force Korean mode
/md-to-docx 'one-pager.md, style:meridian'                              # Amazon narrative style
/md-to-docx 'meeting-notes.md, footer:Team Meeting | May 2026'          # Custom footer
/md-to-docx 'report.md' 'report-ko.md'                                  # Convert both versions
```

## Prerequisites
- Bundled helper: `scripts/generate_styled_docx.py`
- Runtime dependency: `python-docx`; `setup/install-cli.sh` installs it in a private environment
- Optional: `npx` (Node.js) for rendering ` ```mermaid ` blocks as diagrams
