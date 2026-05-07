---
name: translate-pptx
description: |
  Translate PowerPoint presentations between languages natively — no external
  dependencies. The agent IS the translator (Claude/LLM). Uses bundled Python
  script for PPTX manipulation (text extraction, translation application, font
  normalization). Activate when user says "translate pptx", "pptx 번역",
  "translate this presentation", "translate slides", or asks to translate any
  .pptx file between languages.
allowed-tools: [Bash, Read, Write, Edit, Glob]
---

## Overview

Translates a PowerPoint (.pptx) file from one language to another. The agent itself is the translator, and the bundled `translate_pptx_native.py` script handles PPTX manipulation (text extraction, translation application, font normalization, XML patching).

**Advantages over external CLI script:**
- Zero setup — no boto3, no credentials, no Python environment issues
- Interactive — can ask the user about ambiguous terms mid-translation
- Same quality — the LLM does the translation directly
- Better context — sees full slide context when translating

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

```bash
python3 scripts/translate_pptx_native.py extract "<pptx_path>" --source-lang <source> --output extract.json
```

Or in Python:
```python
from translate_pptx_native import extract_texts
result = extract_texts("<pptx_path>", source_lang="<source>")
```

Show summary (slide count, paragraph count, char count) and confirm before proceeding.

- **Validate**: `total_paragraphs > 0`
- **On failure**: If 0 paragraphs found, source_lang may be wrong. Ask user.

### Step 3: Translate in Batches

Process slide-by-slide, up to ~30 paragraphs at a time.

**Translation rules:**
- Produce natural, fluent target language — not word-by-word
- Localize date formats (e.g. '2024년 10월' → 'October 2024')
- Keep technical terms, product names (AWS, EKS, DynamoDB, etc.) as-is
- For company/person names in non-Latin scripts, keep original + romanization in parentheses
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

```python
from translate_pptx_native import apply_translations
result = apply_translations("<pptx_path>", translations, output_path, target_lang="<target>")
```

Output filename: `{original_name}_{target_lang}.pptx`

- **Validate**: Output file exists and `paragraphs_applied > 0`
- **On failure**: Re-extract and start over if index mismatch.

### Step 5: Review Pass

```python
from translate_pptx_native import review
result = review("<output_path>", source_lang="<source>")
```

If non-intentional remaining source text found:
1. Show user what remains
2. Re-extract just those slides → translate → apply again
3. Max 2 review passes, then let user decide

### Step 6: Deliver

1. Open translated PPTX for preview
2. Copy to original file's directory
3. Report: paragraphs translated, fonts normalized, review status

## Output

A translated `.pptx` file with:
- All text translated from source to target language
- Original formatting preserved (paragraph-level, first-run strategy)
- Fonts normalized: Korean → 맑은 고딕, English → Amazon Ember, Japanese → Yu Gothic UI, Chinese → Microsoft YaHei
- XML-level font patching (NanumSquare* → 맑은 고딕)
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
- `python-pptx` installed (`pip install python-pptx`)
- Script: `translate_pptx_native.py` (from doc-skills/scripts/)
