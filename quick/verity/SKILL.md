---
name: verity
display_name: Verity — Factual Verification
description: "Verify factual accuracy of AI-generated responses. Decomposes responses into atomic claims, checks grounding against retrieved sources (AWS docs, account data, API results), and produces a FARM trust score. Use when: 'verify this', 'is this accurate', 'fact check my answer', '검증해줘', '이거 맞아?', 'trust score', 'grounding check'."
icon: "🔍"
trigger: verify this response
inputs:
  - name: response_text
    description: "The AI-generated response to verify — typically 'last response' to auto-verify"
    type: string
    required: true
  - name: original_question
    description: "The original question/prompt that produced the response"
    type: string
    required: true
  - name: depth
    description: "Verification depth: 'quick' (source check only), 'standard' (full pipeline), 'deep' (multi-source triangulation)"
    type: string
    default: quick
  - name: threshold
    description: "Minimum FARM score to pass (0.0–1.0 scale)"
    type: number
    default: 0.6
  - name: output_format
    description: "Output format: 'summary' (inline markdown — DEFAULT), 'card' (visual HTML artifact), 'json' (structured)"
    type: string
    default: summary
tools: [web_search, url_fetch, file_read, file_write, run_python, open_in_session_tab]
---

# VERITY — Verification & Evidence Rating for Intelligent Trust Yielding

## Overview

Automatic verification framework that checks AI responses for factual grounding. Runs on substantive questions — any question that requires facts from documentation, account data, or infrastructure state.

**Core principle:** Every factual claim must be traceable to a retrieved source. Claims based only on training data must be flagged.

## ⚠️ RENDERING CONTRACT

- **`summary` is the default and preferred format.** Pure markdown, renders inline everywhere.
- **Never emit raw HTML into the chat body.**
- **Use `card` only** when the user explicitly wants the full visual report.

## Auto-Trigger Rules

### ✅ DO trigger verification on:
- AWS service questions (features, pricing, limits, configuration, setup)
- Infrastructure questions (what resources exist, current state, metrics)
- "How do I..." technical questions
- "What happened..." incident/change questions
- Best practice and recommendation questions
- Any question requiring current, accurate, or account-specific data

### ❌ DO NOT trigger on:
- Greetings: "hi", "hello", "hey", "good morning"
- Small talk: "how are you", "what's up", "thanks"
- Creative requests: "write a poem", "brainstorm ideas"
- Pure opinion: "what do you think", "which do you prefer"
- Agent meta questions: "what can you do", "help"
- Code generation without factual claims
- Simple yes/no confirmations

## Grounding Categories

Classify every claim by its grounding source:

| Grounding | Icon | Score | Description |
|-----------|------|-------|-------------|
| **DOC_VERIFIED** | 📚 | 1.0 | Verified against official documentation |
| **ACCOUNT_VERIFIED** | 🔍 | 1.0 | Verified against live account data |
| **SOURCE_CITED** | 📄 | 0.9 | Source cited but not independently verified |
| **TRAINING_DATA** | ⚠️ | 0.3 | From training data only — NOT grounded |
| **HALLUCINATION_RISK** | 🚨 | 0.1 | Specific but no grounding — high risk |
| **OUTDATED_RISK** | ⏰ | 0.4 | May be outdated (training cutoff issue) |

## Workflow

### Step 1: Trigger Check (agentic)

Evaluate the original question against auto-trigger rules:
- If greeting/small talk/creative/opinion → **SKIP**, return nothing
- If substantive factual question → **PROCEED**

### Step 2: Decompose into Atomic Claims (deterministic)

Extract all factual claims from the response. Classify each:

| Type | Action |
|------|--------|
| **FACTUAL** | Must verify grounding |
| **SELF_REFERENTIAL** | Flag as TRAINING_DATA |
| **NUMERIC** | Must verify (high hallucination risk) |
| **TEMPORAL** | Check for OUTDATED_RISK |
| **OPINION** | Skip |
| **META** | Skip |

**Bias:** When in doubt, classify as FACTUAL and verify.

### Step 3: Check Grounding Sources (agentic)

For each FACTUAL claim:

1. **Was documentation retrieved?**
   - Yes + matches → DOC_VERIFIED
   - Yes + partial → SOURCE_CITED
   - No → continue

2. **Was account data retrieved?**
   - Yes + matches → ACCOUNT_VERIFIED
   - No → continue

3. **No retrieved source found**
   - Specific (names, numbers, dates) → HALLUCINATION_RISK 🚨
   - General knowledge → TRAINING_DATA ⚠️
   - Recent features/dates → OUTDATED_RISK ⏰

**Active verification:** When grounding is unclear, use `web_search` or `url_fetch` to check against:
- AWS official documentation (docs.aws.amazon.com)
- AWS What's New (aws.amazon.com/about-aws/whats-new/)
- AWS blog posts (aws.amazon.com/blogs/)

### Step 4: Score with FARM Rubric (deterministic)

```
grounding = (doc_verified × 1.0 + account_verified × 1.0 + source_cited × 0.9 +
             training_data × 0.3 + outdated_risk × 0.4 + hallucination_risk × 0.1) / total_claims

farm_total = (grounding × 0.50 + consistency × 0.15 + calibration × 0.20 + scope × 0.15)
```

Trust levels:
- 🟢 HIGH (≥0.85) — Well-grounded in retrieved sources
- 🟡 MODERATE (≥0.65) — Mostly grounded, some training data
- 🟠 LOW (≥0.40) — Significant ungrounded claims
- 🔴 UNRELIABLE (<0.40) — Mostly training data or hallucination risk

### Step 5: Generate Report (deterministic)

#### Default: `summary` format (markdown)

**5a. Trust badge (blockquote, always first):**

```markdown
> 🟢 **TRUST: HIGH · 0.95** — 12 claims · all doc-verified · 0 flagged
```

**5b. FARM bars (fenced code block):**

```
FARM   Grounding    ██████████ 1.00
       Calibration  █████████░ 0.92
       Consistency  █████████░ 0.90
       Scope        ████████░░ 0.85
       ─────────────────────────────
       TOTAL        █████████░ 0.95
```

**5c. Grounding breakdown (table):**

```markdown
| Grounding | Claims |
|-----------|:------:|
| 📚 Doc Verified | 12 |
| 🔍 Account Verified | 0 |
| ⚠️ Training Data | 0 |
| 🚨 Hallucination Risk | 0 |
```

**5d. Flagged claims (ONLY if any exist):**

```markdown
### ⚠️ Flagged claims
- 🚨 "{claim}" — no source found; recommend verifying via {source}
- ⚠️ "{claim}" — training data only; not independently grounded
```

If zero flagged claims → OMIT this section entirely.

**5e. Sources (compact one-liner):**

```markdown
Sources: [Doc title](url) · [Doc title](url) · +N more
```

**Inline rendering rules:**
- Lead with the verdict (badge first)
- Clean pass (0 flagged): badge + FARM bars + grounding table + sources. Skip per-claim table.
- Flagged pass: surface flagged claims prominently under badge
- Never exceed ~15 lines inline

#### `card` format (HTML artifact via `open_in_session_tab`)

Generate an HTML file with:
- Visual trust meter (green/yellow/orange/red gradient)
- FARM score breakdown as bar chart
- Per-claim verification table with expandable details
- Source links
- Save to `artifacts/verity-report.html` and open in session tab

#### `json` format

```json
{
  "farm_score": 0.95,
  "trust_level": "HIGH",
  "total_claims": 12,
  "flagged_claims": 0,
  "claims": [
    {
      "text": "...",
      "type": "FACTUAL",
      "grounding": "DOC_VERIFIED",
      "score": 1.0,
      "source": "https://..."
    }
  ],
  "sources": ["..."]
}
```

## FARM Dimensions Explained

| Dimension | Weight | What it Measures |
|-----------|--------|-----------------|
| **F — Factual Grounding** | 50% | Are claims traceable to retrieved sources? |
| **A — Accuracy/Calibration** | 20% | Does the response hedge appropriately on uncertain claims? |
| **R — Relevance/Consistency** | 15% | Are claims internally consistent and on-topic? |
| **M — Measured Scope** | 15% | Does the response stay within what sources support? |

## Lessons Learned

### Do
- Always run post-response verification after substantive answers
- Classify EVERY claim — don't skip numerics or temporals
- Use active verification (web_search/url_fetch) when grounding is unclear
- Present the trust badge FIRST — it's the whole point
- Keep inline reports under 15 lines
- Flag specific ungrounded claims with recommended verification paths

### Don't
- Don't trigger on greetings, small talk, or creative requests
- Don't assert "verified" without actually checking a source
- Don't skip numeric claims — they have the highest hallucination risk
- Don't generate HTML inline — use markdown summary as default
- Don't conflate "I said it confidently" with "it's grounded"
- Don't report 0 flagged claims as reassuring if no verification was actually done
