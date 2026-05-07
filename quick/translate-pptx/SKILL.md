---
name: translate-pptx
display_name: Translate PPTX
description: "Translate PowerPoint presentations between languages natively inside Quick — no external dependencies. The agent IS the translator (Claude). Activate when user says 'translate pptx', 'pptx 번역', 'translate this presentation', 'translate slides', or asks to translate any .pptx file between languages."
icon: "🌐"
trigger: translate pptx
inputs:
  - name: pptx_path
    description: "Path to the PPTX file to translate. Can be a full path, filename, or description — the skill will search if needed."
    type: path
    required: true
  - name: source_lang
    description: "Source language code: ko, en, ja, zh, es, fr, de, pt, it"
    type: string
    default: "ko"
  - name: target_lang
    description: "Target language code: ko, en, ja, zh, es, fr, de, pt, it"
    type: string
    default: "en"
  - name: glossary
    description: "Optional glossary — either a JSON file path (term → translation mapping) or inline dict in the user's message"
    type: string
    required: false
scripts: [translate_pptx_native.py]
tools: [run_python, file_write, file_read, file_copy, open_in_session_tab, fdfind]
---

## Overview

Translates a PowerPoint (.pptx) file from one language to another **entirely inside Quick** — no boto3, no AWS credentials, no network calls, no shell scripts. The agent itself is the translator (it's Claude), and the bundled `translate_pptx_native.py` script handles PPTX manipulation (text extraction, translation application, font normalization, XML patching).

**Advantages over the external `~/.local/bin/translate_pptx.py` script:**
- Zero setup — no boto3, no credential configuration, no Python environment issues
- Interactive — can ask the user about ambiguous terms mid-translation
- Live preview — opens translated PPTX in session tab as it progresses
- Same quality — this IS Claude doing the translation
- Better context — can see the full slide context when translating (not just isolated paragraphs)
- Review pass with human-in-the-loop — shows remaining issues and lets user decide

## Workflow

### Step 1: Validate Inputs & Locate File
- **Mode**: `agentic`
- **Input**: `{{pptx_path}}`, `{{source_lang}}`, `{{target_lang}}`, `{{glossary}}`
- **Output**: Validated absolute file path, confirmed language codes
- **Validate**: PPTX file exists and is readable
- **On failure**: Search with `fdfind` if filename is given without path. Ask user if ambiguous.

If the user gives a filename or description (e.g. "the KRO deck"), search for it. Confirm the file if multiple matches.

### Step 2: Extract Translatable Text
- **Mode**: `deterministic`
- **Tool**: `run_python`
- **Input**: Validated PPTX path from Step 1
- **Output**: JSON structure with all translatable paragraphs, saved to `artifacts/extract.json`

```python
import sys, json
sys.path.insert(0, 'skill/translate-pptx')
from translate_pptx_native import extract_texts

result = extract_texts("{{pptx_path}}", source_lang="{{source_lang}}")
with open("artifacts/extract.json", "w") as f:
    json.dump(result, f, ensure_ascii=False, indent=2)

stats = result["stats"]
print(f"Slides: {result['total_slides']}")
print(f"Slides with content: {stats['slides_with_content']}")
print(f"Paragraphs to translate: {stats['total_paragraphs']}")
print(f"Total characters: {stats['total_chars']:,}")
```

Show the user a summary and confirm before proceeding. For large decks (>200 paragraphs), warn that it may take several turns.

- **Validate**: `total_paragraphs > 0`
- **On failure**: If 0 paragraphs found, the file may already be in the target language or the source_lang is wrong. Ask user to confirm.

### Step 3: Translate in Batches
- **Mode**: `agentic`
- **Input**: The extracted JSON from Step 2
- **Output**: Translated JSON with "translated" field added to each paragraph

This is the core step where the agent translates. Process slide-by-slide, up to ~30 paragraphs at a time.

**Translation prompt pattern (use this internally, do NOT show to user):**

For each batch of paragraphs, translate them following these rules:
- Produce natural, fluent target language — not word-by-word
- Localize date formats (e.g. '2024년 10월' → 'October 2024')
- Keep technical terms, product names (AWS, EKS, DynamoDB, etc.) as-is
- For company/person names in non-Latin scripts, keep original + romanization in parentheses
- Preserve bullet points, line breaks, and formatting markers
- If a glossary is provided, use those exact translations for matching terms

**Batching strategy:**
1. Load the extracted JSON
2. For each slide with content, collect all paragraph texts
3. Translate them (the agent generates translations directly in its response)
4. Write results back to the JSON with "translated" field added
5. Save progress to `artifacts/translations.json` after each batch

The agent should output translations as a JSON array, then use `run_python` to merge them into the translation file. This allows resuming if interrupted.

**For large presentations (>100 paragraphs):** Process in chunks of ~30 paragraphs per turn. Save progress between chunks so translation can resume if the conversation is interrupted.

- **Validate**: Every paragraph has a non-empty "translated" field
- **On failure**: Re-translate individual failed paragraphs. If a paragraph is ambiguous, ask the user.

### Step 4: Apply Translations & Normalize
- **Mode**: `deterministic`
- **Tool**: `run_python`
- **Input**: Completed translations JSON from Step 3
- **Output**: Translated PPTX file

```python
import sys, json
sys.path.insert(0, 'skill/translate-pptx')
from translate_pptx_native import apply_translations

with open("artifacts/translations.json") as f:
    translations = json.load(f)["slides"]

output_path = "artifacts/{{output_filename}}"
result = apply_translations("{{pptx_path}}", translations, output_path, target_lang="{{target_lang}}")
print(json.dumps(result, indent=2))
```

The output filename follows the pattern: `{original_name}_{target_lang}.pptx`

- **Validate**: Output file exists and `paragraphs_applied > 0`
- **On failure**: Check if the translation JSON structure matches expectations. Common issue: frame_idx/para_idx mismatch if the PPTX was modified between extract and apply.

### Step 5: Review Pass
- **Mode**: `agentic`
- **Tool**: `run_python`
- **Input**: The translated PPTX from Step 4
- **Output**: Review results — list of any remaining source language text

```python
import sys, json
sys.path.insert(0, 'skill/translate-pptx')
from translate_pptx_native import review

result = review("artifacts/{{output_filename}}", source_lang="{{source_lang}}")
print(json.dumps(result, indent=2))
```

If issues are found (non-intentional remaining source text):
1. Show the user what remains
2. Re-extract just those slides → translate → apply again
3. Run review again (max 2 review passes)

If only intentional items remain (e.g. Korean names with romanization), report as clean.

- **Validate**: `issues` list is empty or contains only acceptable items
- **On failure**: After 2 review passes, show remaining issues and let user decide whether to accept or fix manually.

### Step 6: Deliver & Copy
- **Mode**: `deterministic`
- **Tool**: `open_in_session_tab`, `file_copy`
- **Input**: Final translated PPTX
- **Output**: File opened in Quick + copied to the same directory as the original

1. Open translated PPTX in session tab for preview
2. Copy to the original file's directory (alongside the source file)
3. Report final stats: paragraphs translated, fonts normalized, review status

## Output

A translated `.pptx` file with:
- All text translated from `{{source_lang}}` to `{{target_lang}}`
- Original formatting preserved (paragraph-level, first-run strategy)
- Fonts normalized: Korean → 맑은 고딕, English → Amazon Ember, Japanese → Yu Gothic UI, Chinese → Microsoft YaHei
- XML-level font patching (NanumSquare* → 맑은 고딕)
- docProps/app.xml font list patched
- _x000B_ artifacts cleaned
- Saved as `{original_name}_{target_lang}.pptx`

## Lessons Learned

### Do
- Always show the extraction summary (slide count, paragraph count) before starting translation — let user confirm
- Save translation progress after each batch to `artifacts/translations.json` — allows resume on interruption
- Translate paragraph-level (not run-level) to preserve sentence context and meaning
- Use first-run strategy: translated text goes into first run, remaining runs cleared (preserves formatting)
- Run review pass after translation to catch any missed text
- Copy final output to original directory so it's alongside the source file

### Don't
- Don't try to translate run-by-run — splits sentences and produces garbage
- Don't skip font normalization — mixed fonts make the deck look broken
- Don't translate technical terms, AWS service names, or product names
- Don't translate in one massive batch — context degrades with very large batches. Keep ≤30 paragraphs per batch.
- Don't modify the original file — always write to a new output path

### Common Failures
- **"0 paragraphs found"** — Wrong source language specified, or the file is already translated. Ask user to confirm source_lang.
- **Frame/paragraph index mismatch** — Can happen if PPTX was edited between extract and apply. Re-extract and start over.
- **Broken characters in output** — Usually a font issue. The normalize_fonts pass should fix this, but if not, check if the target language font is installed on the system.
- **Very long slides (>50 paragraphs per slide)** — Split into smaller translation batches to maintain quality.

### When to Ask the User
- If source/target language isn't clear from context
- If multiple PPTX files match a filename search
- Before starting translation (show summary, confirm)
- If ambiguous terms appear that could be translated multiple ways
- If review pass shows remaining issues after 2 fix passes — let user decide