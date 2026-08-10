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
- English is the default language for generated labels and headings.
- Korean labels are allowed only when the user explicitly supplies `lang:ko`; filename suffixes never select Korean mode.
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
/md-to-docx '<file_path>, lang:ko, footer:AWS Meeting Notes | 2026-05-05 | Confidential'
/md-to-docx '<file_path1>' '<file_path2>'
```

## Behavior

Resolve and execute the bundled helper. Prefer the private CLI wrapper when installed because it carries an isolated Python environment:

```bash
HELPER=""
for candidate in \
  "$HOME/.local/bin/generate_styled_docx.py" \
  "$HOME/.kiro/skills/md-to-docx/scripts/generate_styled_docx.py" \
  "$HOME/.claude/skills/md-to-docx/scripts/generate_styled_docx.py"; do
  if [ -x "$candidate" ]; then HELPER="$candidate"; break; fi
done
[ -n "$HELPER" ] || { echo "generate_styled_docx.py is not installed" >&2; exit 1; }
"$HELPER" "<file_path>" [options]
```

### Argument Parsing

Parse user input to extract file paths and options:

1. **Single file**: `/md-to-docx 'report.md'` → convert one file
2. **Multiple files**: `/md-to-docx 'report.md' 'notes.md'` → convert each file separately
3. **With options**: `/md-to-docx 'report.md, output:out.docx, lang:ko, footer:custom text'`

Map options to CLI flags:
- `output:<path>` → `-o <path>`
- `lang:en` or `lang:ko` → `-l en` or `-l ko`
- `footer:<text>` → `--footer "<text>"`
- `margin:<top,bottom,left,right>` (cm) → `--margin-top <t> --margin-bottom <b> --margin-left <l> --margin-right <r>`

If no language is specified, use English. Filename suffixes do not select the output language.

### Core Options
- `-o` / `--output`: Output .docx file path (default: same name as input with .docx extension)
- `-l` / `--lang`: Language for badge rules and labels — `en` or `ko` (default: `en`)
- `--footer`: Custom footer text (default: auto-generated with today's date)
- `--margin-top`, `--margin-bottom`, `--margin-left`, `--margin-right`: Page margins in cm. Default: top/bottom 2.54, left/right 2.0

### Styling Features
- **AWS-branded**: Calibri 11pt font, AWS Orange (#FF9900) accents
- **Headings**: H1-H6 support with orange underline on H2
- **Key Takeaways**: Orange-accented callout box (auto-detected from blockquotes)
- **Blockquotes**: General blockquotes rendered with gray left border
- **Code blocks**: Fenced code blocks rendered as monospace shaded boxes
- **Tables**: Dark navy header, alternating row colors, thin borders
- **Badges**: Auto-detected status badges (ON ROADMAP, NOT TODAY, LIMITED, LIMITATION)
- **Priority badges**: High (red), Medium (orange), Low (green) in table cells
- **Inline markdown**: Bold, italic, code, and links rendered properly
- **Numbered & bullet lists**: Orange-accented numbering and bullets

### Language Support
- `en`: English badge rules (e.g., "on the roadmap" → ON ROADMAP badge)
- `ko`: Korean-language badge matching, including roadmap-status phrases
- Korean mode requires an explicit `lang:ko` request; filenames are not language signals

### Batch Conversion

When multiple files are provided, pass them all at once:

```bash
"$HELPER" "report.md" -l en
"$HELPER" "report-ko.md" -l ko
```

If the user explicitly asks to convert both English and Korean versions, locate the counterpart and run each conversion with an explicit `-l en` or `-l ko` flag.

## Examples

```
/md-to-docx 'meeting-notes.md'                                          # Defaults to English
/md-to-docx 'meeting-notes.md, output:final-report.docx'                # Custom output path
/md-to-docx 'meeting-notes.md, lang:ko'                                 # Force Korean mode
/md-to-docx 'meeting-notes.md, footer:Team Meeting | May 2026'          # Custom footer
/md-to-docx 'report.md' 'report-ko.md'                                  # Convert both versions
```

## Prerequisites
- Bundled helper: `scripts/generate_styled_docx.py`
- Runtime dependency: `python-docx`; `setup/install-cli.sh` installs it in a private environment
