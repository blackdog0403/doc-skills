---
name: md-to-docx
display_name: Markdown to DOCX
description: "Convert markdown files to professionally styled Word documents (.docx) with AWS branding. Supports English/Korean, custom footers, badges, and batch conversion. Uses the generate_styled_docx.py script from Claude Code."
icon: "📄"
trigger: convert markdown to docx
inputs:
  - name: file_path
    description: "Path to the markdown file(s) to convert. Can be absolute or relative."
    type: path
    required: true
  - name: output_path
    description: "Custom output .docx file path. Defaults to same name as input with .docx extension."
    type: path
    required: false
  - name: language
    description: "Language for generated labels and headings — 'en'/'English' (default choice) or 'ko'/'Korean'. The skill asks if omitted; this does not translate the Markdown."
    type: string
    required: true
  - name: footer
    description: "Footer text to use. The skill asks for this if omitted. Use {date} for today's UTC date, or reply 'default' for '{date} | Confidential'."
    type: string
    required: true
  - name: title_page
    description: "Whether to add a title page — 'true' or 'false'. Supplying title metadata also enables it."
    type: string
    required: false
    default: "false"
  - name: title
    description: "Title-page title. Defaults to the first H1 or filename."
    type: string
    required: false
  - name: subtitle
    description: "Optional title-page subtitle."
    type: string
    required: false
  - name: author
    description: "Optional title-page author and DOCX author property."
    type: string
    required: false
  - name: team
    description: "Optional title-page team and DOCX category property."
    type: string
    required: false
  - name: version
    description: "Optional title-page document version."
    type: string
    required: false
  - name: classification
    description: "Optional title-page classification, such as Public, Internal, or Confidential."
    type: string
    required: false
  - name: toc
    description: "Whether to add an auto-updating table of contents — 'true' or 'false'."
    type: string
    required: false
    default: "false"
  - name: page_numbers
    description: "Whether to append Page X of Y to the footer — 'true' or 'false'."
    type: string
    required: false
    default: "false"
  - name: header
    description: "Optional header text."
    type: string
    required: false
  - name: logo_path
    description: "Optional path to a PNG, JPEG, GIF, BMP, or TIFF header logo."
    type: path
    required: false
  - name: page_size
    description: "Page size — 'letter', 'a4', or 'legal'."
    type: string
    required: false
    default: "letter"
  - name: orientation
    description: "Page orientation — 'portrait' or 'landscape'."
    type: string
    required: false
    default: "portrait"
  - name: margins
    description: "Page margins in cm as 'top,bottom,left,right' (e.g. '2.54,2.54,2.0,2.0'). Default: top/bottom 2.54, left/right 2.0. Empty string keeps defaults."
    type: string
    required: false
tools: [run_python, file_read, file_write, open_in_session_tab, fdfind, file_copy]
---

## Overview

Converts Markdown files to professionally styled Word documents using the bundled `generate_styled_docx.py` helper, with `~/.local/bin/generate_styled_docx.py` as a developer-install fallback.

## Output Language Safety

- Conversion must not translate or rewrite the source document.
- Before conversion, explicitly ask which language to use for generated labels and headings: English (default) or Korean.
- Treat `default` as English. Korean is used only when the user selects it.
- Source text, filename suffixes, and the language of the request must never determine this choice.
- Never introduce Korean into non-Korean output.

## Styling Features

- **AWS-branded**: Calibri 11pt font, AWS Orange (#FF9900) accents
- **Headings**: H1-H6 support with orange underline on H2
- **Key Takeaways**: Orange-accented callout box (auto-detected from blockquotes)
- **Code blocks**: Fenced code blocks rendered as monospace shaded boxes
- **Tables**: Dark navy header, alternating row colors, thin borders
- **Badges**: Auto-detected status badges (ON ROADMAP, NOT TODAY, LIMITED, LIMITATION)
- **Priority badges**: High (red), Medium (orange), Low (green) in table cells
- **Inline markdown**: Bold, italic, code, and links rendered properly
- **Numbered & bullet lists**: Orange-accented numbering and bullets

## Workflow

### Step 1: Validate Inputs & Collect Preferences
- **Mode**: `agentic`
- Confirm the markdown file exists. If filename only (no path), search with `fdfind`.
- Ask only for preferences the user has not already supplied, combining missing questions into one message:
  1. **Generated-label language**: **"Which language should the generated document labels use: English (default) or Korean? This controls labels such as the table-of-contents title, metadata labels, badges, and page numbering; it does not translate or rewrite the Markdown."**
     - Map `English`, `en`, or `default` to `en`; map `Korean` or `ko` to `ko`.
     - Never infer this choice from source text, filename, filename suffix, or invocation language.
  2. **Footer**: **"What should the footer say? You can use `{date}` for today's UTC date (for example, `{date} | Team Name | Confidential`). Reply `default` to use `{date} | Confidential`."**
  3. **Customization**: **"Any other document customization? Reply `default`, or specify a title page (title, subtitle, author, team, version, classification), table of contents, Page X of Y numbering, header text/logo, page size (Letter/A4/Legal), orientation, or margins."**
- Do not ask a question if the user already supplied its answer. Do not ask the customization question if the user explicitly requested defaults.
- Do not execute the conversion until the required preflight answers are available. Use shared answers for all files unless the user requests per-file settings.

### Step 2: Execute Conversion
- **Mode**: `deterministic`
- **Tool**: `run_python`

```python
import subprocess, os

file_path = "{{file_path}}"
output_path = "{{output_path}}"  # may be empty
language_answer = "{{language}}".strip().lower()
footer = "{{footer}}"
title_page = "{{title_page}}"
title = "{{title}}"
subtitle = "{{subtitle}}"
author = "{{author}}"
team = "{{team}}"
version = "{{version}}"
classification = "{{classification}}"
toc = "{{toc}}"
page_numbers = "{{page_numbers}}"
header = "{{header}}"
logo_path = "{{logo_path}}"
page_size = "{{page_size}}" or "letter"
orientation = "{{orientation}}" or "portrait"
margins = "{{margins}}"  # may be empty; format: "top,bottom,left,right" in cm

language_aliases = {
    "default": "en",
    "en": "en",
    "english": "en",
    "ko": "ko",
    "korean": "ko",
}
if language_answer not in language_aliases:
    raise SystemExit("ERROR: Choose English (en/default) or Korean (ko) for generated labels.")
language = language_aliases[language_answer]

def enabled(value):
    return value.strip().lower() in {"1", "true", "yes", "on"}

# "default" selects the converter's date-based default footer.
if footer.strip().lower() == "default":
    footer = ""

# Locate generate_styled_docx.py: prefer the skill bundle (ZIP install),
# fall back to ~/.local/bin/ (developer install via setup/install-cli.sh)
candidates = [
    "skill/md-to-docx/scripts/generate_styled_docx.py",
    os.path.expanduser("~/.local/bin/generate_styled_docx.py"),
]
script = next((p for p in candidates if os.path.exists(p)), None)
if not script:
    print("ERROR: generate_styled_docx.py not found.")
    print("Re-install the skill from the latest release ZIP, or run:")
    print("  ./setup/install-cli.sh   (developer setup)")
    raise SystemExit(1)

cmd = ["python3", script, file_path]

if output_path:
    cmd.extend(["-o", output_path])
cmd.extend(["-l", language])
if footer:
    cmd.extend(["--footer", footer])
if enabled(title_page):
    cmd.append("--title-page")
for flag, value in [
    ("--title", title),
    ("--subtitle", subtitle),
    ("--author", author),
    ("--team", team),
    ("--version", version),
    ("--classification", classification),
]:
    if value:
        cmd.extend([flag, value])
if enabled(toc):
    cmd.append("--toc")
if enabled(page_numbers):
    cmd.append("--page-numbers")
if header:
    cmd.extend(["--header", header])
if logo_path:
    cmd.extend(["--logo", logo_path])
cmd.extend(["--page-size", page_size.lower(), "--orientation", orientation.lower()])
if margins:
    parts = [p.strip() for p in margins.split(",")]
    if len(parts) == 4:
        t, b, l, r = parts
        cmd.extend(["--margin-top", t, "--margin-bottom", b, "--margin-left", l, "--margin-right", r])

result = subprocess.run(cmd, capture_output=True, text=True, cwd=os.path.dirname(file_path) or ".")
print(result.stdout)
if result.returncode != 0:
    print(f"ERROR: {result.stderr}")
```

- **Validate**: Output .docx file exists
- **On failure**: If the script reports a missing module (e.g., `python-docx`), inform the user. Quick Desktop ships these pre-installed; if absent, suggest updating Quick Desktop.

### Step 3: Deliver
- **Mode**: `deterministic`
- Open the generated .docx in session tab with `open_in_session_tab`
- Report: input file, output file, language used

## Batch Conversion

When multiple files share one explicitly selected language, pass them together to the resolved `script`. For mixed English and Korean files, run separate commands with explicit `-l en` and `-l ko` flags. Only look for a Korean counterpart when the user explicitly asks for both versions.

## Lessons Learned

### Do
- Ask for the generated-label language when omitted; map `default` to English and always pass explicit `-l en` or `-l ko`
- Keep source Markdown unchanged; the language option controls generated labels only
- Open the output .docx in session tab after conversion
- Copy output to same directory as input by default

### Don't
- Don't try to replicate the styling in Python — always use the script
- Don't hard-code `~/.local/bin/`; ZIP-installed users have the script at `skill/md-to-docx/scripts/generate_styled_docx.py`

### Prerequisites
- `python-docx` is pre-installed in Amazon Quick Desktop's sandbox
- Script: bundled at `skill/md-to-docx/scripts/generate_styled_docx.py` (ZIP install) or `~/.local/bin/generate_styled_docx.py` (developer install)
