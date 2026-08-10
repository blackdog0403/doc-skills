---
name: translate-pptx
description: |
  Translate PowerPoint presentations between languages natively — no external
  dependencies. The agent IS the translator (Claude/LLM). Uses bundled Python
  script for PPTX manipulation (text extraction, translation application, font
  normalization). Activate when the user says "translate pptx",
  "translate this presentation", "translate slides", or makes an equivalent
  request in Korean to translate any .pptx file between languages.
allowed-tools: [Bash, Read, Write, Edit, Glob]
---

## Overview

Translates a PowerPoint (.pptx) file from one language to another. The agent itself is the translator, and the bundled `translate_pptx_native.py` script handles PPTX manipulation (text extraction, translation application, font normalization, XML patching).

**Advantages over external CLI script:**
- Zero setup — no boto3, no credentials, no Python environment issues
- Interactive — can ask the user about ambiguous terms mid-translation
- Same quality — the LLM does the translation directly
- Better context — sees full slide context when translating

## Output Language Safety

- The explicit target language is the sole authority for generated text; source language, trigger phrases, and examples must not override it.
- When the target is not Korean, never generate or retain Korean text unless the user explicitly asks to preserve specific original-script text.
- Transliterate non-Latin names into the target script by default. Retain original-script names only after an explicit user request.

## Arguments

```
/translate-pptx <pptx_path> [source:ko] [target:en] [glossary:path.json]
```

- **pptx_path** (required): Path to .pptx file
- **source** (optional, default: "ko"): Source language code (ko, en, ja, zh, es, fr, de, pt, it)
- **target** (optional, default: "en"): Target language code
- **glossary** (optional): JSON file with term → translation mapping

## Workflow

### Step 1: Validate Inputs & Locate File

- Validate PPTX file exists and is readable
- If filename given without path, search for it. Confirm if multiple matches.

### Step 2: Extract Translatable Text

Resolve the native helper. Prefer the private CLI wrapper when installed because it carries an isolated Python environment:

```bash
HELPER=""
for candidate in \
  "$HOME/.local/bin/translate_pptx_native.py" \
  "$HOME/.kiro/skills/translate-pptx/scripts/translate_pptx_native.py" \
  "$HOME/.claude/skills/translate-pptx/scripts/translate_pptx_native.py"; do
  if [ -x "$candidate" ]; then HELPER="$candidate"; break; fi
done
[ -n "$HELPER" ] || { echo "translate_pptx_native.py is not installed" >&2; exit 1; }
"$HELPER" extract "<pptx_path>" --source-lang <source> --output extract.json
```

Show summary (slide count, paragraph count, char count) and confirm before proceeding.

- **Validate**: `total_paragraphs > 0`
- **On failure**: If 0 paragraphs found, source_lang may be wrong. Ask user.

### Step 3: Translate in Batches

Process slide-by-slide, up to ~30 paragraphs at a time.

**Translation rules:**
- Produce natural, fluent target language — not word-by-word
- Localize date formats naturally for the target language (for example, month-year ordering)
- Keep technical terms, product names (AWS, EKS, DynamoDB, etc.) as-is
- For company/person names in non-Latin scripts, transliterate into the target script; retain the original script only if explicitly requested
- Preserve bullet points, line breaks, and formatting markers
- If glossary provided, use those exact translations for matching terms

**Batching strategy:**
1. Load extracted JSON
2. For each slide, collect all paragraph texts
3. Translate them (agent generates translations directly)
4. Save progress to `translations.json` after each batch

For large presentations (>100 paragraphs): Process in chunks of ~30 per turn. Save progress between chunks.

- **Validate**: Every paragraph has a non-empty "translated" field
- **On failure**: Re-translate individual failed paragraphs.

### Step 4: Apply Translations & Normalize

```bash
"$HELPER" apply "<pptx_path>" \
  --translations translations.json \
  --output "<output_path>" \
  --target-lang <target>
```

Output filename: `{original_name}_{target_lang}.pptx`

- **Validate**: Output file exists and `paragraphs_applied > 0`
- **On failure**: Re-extract and start over if index mismatch.

### Step 5: Review Pass

```bash
"$HELPER" review "<output_path>" --source-lang <source> --output review.json
```

If non-intentional remaining source text found:
1. Show user what remains
2. Re-extract just those slides → translate → apply again
3. After 2 review passes, stop and report unresolved text; do not deliver a non-Korean output that still contains Korean unless the user explicitly requested that exact text be preserved

### Step 6: Deliver

1. Open translated PPTX for preview
2. Copy to original file's directory
3. Report: paragraphs translated, fonts normalized, review status

## Output

A translated `.pptx` file with:
- All text translated from source to target language
- Original formatting preserved (paragraph-level, first-run strategy)
- Fonts normalized: Korean to Malgun Gothic, English to Amazon Ember, Japanese to Yu Gothic UI, and Chinese to Microsoft YaHei
- XML-level font patching from NanumSquare families to Malgun Gothic
- Saved as `{original_name}_{target_lang}.pptx`

## Lessons Learned

### Do
- Always show extraction summary before starting translation
- Save progress after each batch — allows resume on interruption
- Translate paragraph-level (not run-level) to preserve sentence context
- Use first-run strategy: translated text into first run, remaining cleared
- Run review pass after translation
- Copy final output to original directory

### Don't
- Don't translate run-by-run — splits sentences
- Don't skip font normalization — mixed fonts look broken
- Don't translate technical terms or AWS service names
- Don't translate >30 paragraphs in one batch — quality degrades
- Don't modify the original file — always write to new path

### Common Failures
- **"0 paragraphs found"** — Wrong source_lang. Ask user to confirm.
- **Index mismatch** — PPTX modified between extract and apply. Re-extract.
- **Broken characters** — Font issue. Normalize pass should fix.

## Prerequisites
- Bundled helper: `scripts/translate_pptx_native.py`
- Runtime dependency: `python-pptx`; `setup/install-cli.sh` installs it in a private environment
