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
    description: "Language for badge rules and labels — 'en' or 'ko'. Auto-detects from filename (-ko.md → Korean)."
    type: string
    required: false
    default: "auto"
  - name: footer
    description: "Custom footer text. Default: auto-generated with today's date."
    type: string
    required: false
tools: [run_python, file_read, file_write, open_in_session_tab, fdfind, file_copy]
---

## Overview

Converts Markdown files to professionally styled Word documents using the `generate_styled_docx.py` script (located at `~/.local/bin/generate_styled_docx.py`). This is the same script used by the Claude Code `/md-to-docx` command.

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

### Step 1: Validate Inputs & Locate File
- **Mode**: `agentic`
- Confirm the markdown file exists. If filename only (no path), search with `fdfind`.
- Determine language: check filename for `-ko.md` suffix, or use user-specified language.

### Step 2: Execute Conversion
- **Mode**: `deterministic`
- **Tool**: `run_python`

```python
import subprocess, os

file_path = "{{file_path}}"
output_path = "{{output_path}}"  # may be empty
language = "{{language}}"  # "en", "ko", or "auto"
footer = "{{footer}}"  # may be empty

cmd = ["python3", os.path.expanduser("~/.local/bin/generate_styled_docx.py"), file_path]

if output_path:
    cmd.extend(["-o", output_path])
if language and language != "auto":
    cmd.extend(["-l", language])
if footer:
    cmd.extend(["--footer", footer])

result = subprocess.run(cmd, capture_output=True, text=True, cwd=os.path.dirname(file_path) or ".")
print(result.stdout)
if result.returncode != 0:
    print(f"ERROR: {result.stderr}")
```

- **Validate**: Output .docx file exists
- **On failure**: Check if python-docx is installed. If not, suggest `pip install python-docx`.

### Step 3: Deliver
- **Mode**: `deterministic`
- Open the generated .docx in session tab with `open_in_session_tab`
- Report: input file, output file, language used

## Batch Conversion

When multiple files are provided, pass them all to the script:

```python
cmd = ["python3", os.path.expanduser("~/.local/bin/generate_styled_docx.py"), file1, file2, ...]
```

If user asks for "both English and Korean versions", look for the `-ko.md` counterpart automatically.

## Lessons Learned

### Do
- Auto-detect language from filename suffix (`-ko.md` → Korean)
- Open the output .docx in session tab after conversion
- Copy output to same directory as input by default

### Don't
- Don't try to replicate the styling in Python — always use the script
- Don't assume python-docx is installed in the sandbox — call via subprocess from the user's Python environment

### Prerequisites
- `python-docx` must be installed in the user's system Python (`pip install python-docx`)
- Script location: `~/.local/bin/generate_styled_docx.py`
