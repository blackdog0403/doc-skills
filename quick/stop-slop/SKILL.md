---
name: stop-slop
display_name: Stop Slop
description: "Remove AI writing patterns from prose. Eliminate predictable AI tells — filler phrases, formulaic structures, passive voice, false agency, vague declaratives, and metronomic rhythm. Use when: 'stop slop', 'remove AI patterns', 'make this sound human', 'clean up the writing', 'edit for authenticity', 'AI 티 빼줘', '문체 다듬어줘'."
icon: "✂️"
trigger: remove AI patterns from this text
inputs:
  - name: text_or_file
    description: "Text to edit, or path to a file (.md, .docx, .txt) containing prose to clean up"
    type: string
    required: true
  - name: output_mode
    description: "'edit' (default — return cleaned text), 'score' (score only), 'both' (cleaned text + score breakdown)"
    type: string
    required: false
    default: "both"
tools: [file_read, file_read_docx, file_write, file_edit, open_in_session_tab]
---

## Overview

Eliminate predictable AI writing patterns from prose.

**Author:** Hardik Pandya (https://hvpandya.com)
**License:** MIT
**Source:** https://github.com/hardikpandya/stop-slop

## Core Rules

1. **Cut filler phrases.** Remove throat-clearing openers, emphasis crutches, and all adverbs. See `references/phrases.md`.
2. **Break formulaic structures.** Avoid binary contrasts, negative listings, dramatic fragmentation, rhetorical setups, false agency. See `references/structures.md`.
3. **Use active voice.** Every sentence needs a human subject doing something. No passive constructions. No inanimate objects performing human actions ("the complaint becomes a fix").
4. **Be specific.** No vague declaratives ("The reasons are structural"). Name the specific thing. No lazy extremes ("every," "always," "never") doing vague work.
5. **Put the reader in the room.** No narrator-from-a-distance voice. "You" beats "People." Specifics beat abstractions.
6. **Vary rhythm.** Mix sentence lengths. Two items beat three. End paragraphs differently. No em dashes.
7. **Trust readers.** State facts directly. Skip softening, justification, hand-holding.
8. **Cut quotables.** If it sounds like a pull-quote, rewrite it.

## Quick Checks

Before delivering prose:

- Any adverbs? Kill them.
- Any passive voice? Find the actor, make them the subject.
- Inanimate thing doing a human verb ("the decision emerges")? Name the person.
- Sentence starts with a Wh- word? Restructure it.
- Any "here's what/this/that" throat-clearing? Cut to the point.
- Any "not X, it's Y" contrasts? State Y directly.
- Three consecutive sentences match length? Break one.
- Paragraph ends with punchy one-liner? Vary it.
- Em-dash anywhere? Remove it.
- Vague declarative ("The implications are significant")? Name the specific implication.
- Narrator-from-a-distance ("Nobody designed this")? Put the reader in the scene.
- Meta-joiners ("The rest of this essay...")? Delete. Let the essay move.

## Scoring

Rate 1-10 on each dimension:

| Dimension | Question |
|-----------|----------|
| Directness | Statements or announcements? |
| Rhythm | Varied or metronomic? |
| Trust | Respects reader intelligence? |
| Authenticity | Sounds human? |
| Density | Anything cuttable? |

Below 35/50: revise.

## Workflow

### Step 1: Read the text
- **Mode**: `deterministic`
- **Tool**: `file_read` / `file_read_docx`
- **Input**: `{{text_or_file}}`
- **Output**: Raw prose to edit
- If input is a file path, read it. If inline text, use directly.

### Step 2: Apply Core Rules
- **Mode**: `agentic`
- **Input**: Raw prose from Step 1
- **Output**: Revised prose with all violations fixed
- Scan for all banned phrases (see `references/phrases.md`)
- Scan for all banned structures (see `references/structures.md`)
- Apply Quick Checks checklist
- Rewrite violations while preserving meaning

### Step 3: Score
- **Mode**: `agentic`
- **Input**: Revised prose
- **Output**: Score breakdown (5 dimensions, 1-10 each)
- Rate each dimension 1-10
- If below 35/50, revise further (loop back to Step 2)

### Step 4: Deliver
- **Mode**: `deterministic`
- **Tool**: `file_write` or inline response
- **Input**: Revised prose + score, `{{output_mode}}`
- **Output**: Final deliverable
- If `output_mode` = "edit": output revised text only
- If `output_mode` = "score": output score breakdown only
- If `output_mode` = "both": output revised text + score breakdown
- If input was a file, write revised version and open it

## References

- `references/phrases.md` — Full list of banned phrases by category
- `references/structures.md` — Structural patterns to avoid with examples
- `references/examples.md` — Before/after transformations

## Examples

See `references/examples.md` for before/after transformations.
