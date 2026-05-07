---
name: doc-fact-check
display_name: Document Fact Checker
description: "Verify factual claims in technical documents against authoritative sources. Removes/flags third-party unverifiable data, validates claims against AWS official documentation and announcements, adds proper citations, and produces a correction report. Use when: 'fact check this', '검증해줘', 'verify the claims', 'check sources', 'remove third-party data', 'add citations', '출처 확인', 'AWS 공식 데이터로 바꿔줘'."
icon: "🔍"
trigger: fact check this document
inputs:
  - name: file_path
    description: "Path to the document to fact-check (.md, .docx, .pdf, .txt)"
    type: path
    required: true
  - name: check_scope
    description: "What to check: 'all' (default), 'latency', 'services', 'reliability', 'pricing', or custom keywords. When not 'all', only claims in that category are verified."
    type: string
    required: false
    default: "all"
  - name: output_format
    description: "Output mode: 'report' (correction report only), 'inline' (annotate document only), 'both' (default — report + annotations), or 'fix' (auto-correct all ❌/⚠️ issues directly in the document + produce report with diffs)"
    type: string
    required: false
    default: "both"
tools: [web_search, url_fetch, file_read, file_read_docx, file_read_pdf, file_write, file_edit, open_in_session_tab, run_python, start_task, fdfind]
---

## Overview

Verify factual claims in technical documents against **authoritative sources only**. Produces a correction report with a quality score, optionally annotates the source document, or auto-fixes all issues.

**Core principle:** Every factual claim must trace to an authoritative source (AWS docs, What's New, press releases) or be explicitly marked as unverifiable.

**Anti-hallucination rule:** The Common Pitfalls section contains heuristics that may become outdated. When a pitfall says "AWS does NOT publish X" — **always verify by fetching the actual service page** before flagging. If the page DOES contain the data, the claim is verified regardless of what the pitfall says.

## Philosophy

1. **Only authoritative sources** — AWS official docs, AWS What's New, AWS blogs, press releases
2. **Remove or flag third-party sources** — Third-party measurement tools, user-reported data
3. **Customer's own measurements are acceptable** — First-party data is valid (Tier 2)
4. **Conservative when uncertain** — Flag as unverifiable rather than asserting correctness
5. **Citations must be clickable** — Every claim should link to its source
6. **Range values need both bounds sourced** — "0.5-1.5s" requires sourcing for BOTH numbers
7. **"Typically" ≠ guarantee** — "Typically under 1 second" ≠ "< 1s SLA"
8. **Verify before flagging** — Never assert "AWS doesn't publish X" without fetching the page first
9. **No impact assertions without AWS source** — Never write "no customer impact", "unaffected", or "zero downtime" unless AWS explicitly stated this in a post-event summary. Use factual scope descriptions only.
10. **No undefined severity labels** — AWS does not publish a severity classification. Terms like "major incident" or "minor event" are subjective and must not be used without explicit definition.
11. **Qualified language ≠ verified number** — When AWS docs use hedging words ("typically", "usually", "less than", "up to", "in most cases"), the claim is NOT fully verified. It must be flagged as requiring actual testing for the customer's specific environment. These are design-goal statements, not guarantees.

## Source Hierarchy (Trustworthiness)

| Tier | Source Type | Action |
|---|---|---|
| **Tier 1 (Use)** | AWS official documentation (docs.aws.amazon.com) | ✅ Cite directly |
| **Tier 1 (Use)** | AWS What's New announcements | ✅ Cite directly |
| **Tier 1 (Use)** | AWS blog posts (aws.amazon.com/blogs/) | ✅ Cite directly |
| **Tier 1 (Use)** | AWS press releases (press.aboutamazon.com) | ✅ Cite directly |
| **Tier 1 (Use)** | AWS service pages (aws.amazon.com/{service}/) | ✅ Cite directly |
| **Tier 2 (Acceptable)** | Customer's own measurements (first-party data) | ✅ Note source + date |
| **Tier 2 (Acceptable)** | Organization's internal wiki/tools | ✅ For internal docs only |
| **Tier 3 (Flag)** | Third-party monitoring tools (Economize, IsDown, CloudPing, aws-services.info) | ⚠️ Flag |
| **Tier 3 (Flag)** | Community posts, re:Post user answers | ⚠️ Flag |
| **Tier 4 (Remove)** | Unattributed claims, "it is known that..." | ❌ Remove/rewrite |

## Qualified Language Rule (NEW in v6)

**Problem:** AWS documentation frequently uses hedging language:
- "typically under 1 second"
- "less than 1 hour"
- "usually completes in seconds"
- "in most cases"
- "up to 5 secondary regions"
- "designed to replicate 99.99% within 15 minutes"

**Rule:** When a document presents these qualified numbers as facts to the customer, they must NOT be marked ✅ (fully verified). Instead:

| Verification Status | Meaning | When to Use |
|---|---|---|
| ✅ Verified | Hard SLA/guarantee with specific number | SLA pages, contractual guarantees, exact counts |
| ✅ Sourced + ⚠️ Qualified | AWS docs say it, but with hedging language | "typically", "usually", "less than", "up to", "designed to" |
| ⚠️ Unverified | No authoritative source found | General guidance, estimates |
| ❌ Incorrect | Contradicts authoritative source | Wrong numbers, outdated info |

**For customer-facing documents:**
- Claims using qualified language get status: **✅ Sourced (qualified) — actual test required**
- The document must annotate these claims with a note that actual testing is needed
- In the correction report, these appear in a dedicated section: "Qualified Claims Requiring Validation"

**Qualified language indicators (trigger words):**
- "typically", "usually", "generally", "in most cases"
- "less than", "under", "up to", "approximately"
- "designed to", "expected to", "aims to"
- Any number followed by "or less", "or more", "or better"

**Fix mode behavior:**
- When `output_format="fix"`, qualified claims should be rewritten to include: source citation + "actual test required" disclaimer
- Pattern: `<number> (per AWS docs) — actual test required to confirm for your environment`

## Workflow

### Step 1: Read & Extract Claims (with Scope Filtering)
- **Mode**: `deterministic`
- **Tool**: `file_read` / `file_read_docx` / `file_read_pdf`
- **Input**: `{{file_path}}`, `{{check_scope}}`
- **Output**: List of factual claims with locations, filtered by scope
- Extract all factual claims (numbers, dates, service availability, latency, pricing, AZ counts, instance types, etc.)
- Categorize: `latency`, `service_availability`, `capacity`, `pricing`, `reliability`, `date/timeline`, `incident`
- **Range claim splitting:** "0.5-1.5s" → TWO claims: lower bound + upper bound (each needs sourcing)
- **Scope filtering:** If `{{check_scope}}` ≠ "all", only retain matching category claims
- **Impact language extraction:** Flag any statement containing impact assertions ("no impact", "unaffected", "zero downtime", "no customer disruption") for verification in Step 3
- **Qualified language extraction:** Flag any claim containing hedging words (typically, usually, less than, up to, designed to, etc.) for special handling in Step 3

### Step 2: Identify Sources Used
- **Mode**: `agentic`
- **Input**: Extracted claims from Step 1
- **Output**: Source classification per claim
- Classify each cited source against the Source Hierarchy
- Flag Tier 3/4 sources
- **Check misleading framing:**
  - "AWS Network Manager reference data" — NMIP does NOT publish static reference data
  - "AWS confirmed" without a citation
  - "per AWS documentation" without a link
  - Ranges with unsourced upper bounds
  - **Undefined severity labels:** "major incident", "minor event", "critical outage" without definition
  - **Impact assertions without source:** "no customer impact", "unaffected", "Multi-AZ architectures were not impacted"
- **Check qualified language presentation:**
  - Does the document present "typically <1s" as if it were a guaranteed "<1s"?
  - Does it strip the hedging word when citing the number?
  - Does it lack a disclaimer about actual testing needed?

### Step 3: Verify Against Authoritative Sources + URL Validation
- **Mode**: `agentic`
- **Tools**: `web_search`, `url_fetch`
- **Input**: Claims needing verification
- **Output**: Verification results

**CRITICAL: Always fetch before flagging.**

**Qualified language verification:**
- Fetch the source page and extract the EXACT wording AWS uses
- If AWS says "typically under 1 second" and the document says "<1s" → flag as qualified, note the hedging word was stripped
- If AWS says "typically under 1 second" and the document says "typically under 1 second" → sourced but still qualified (not a hard SLA)
- **Key question:** Does the document present the number WITH or WITHOUT the qualifier? If without, the document is overstating the claim.
- **For customer-facing docs:** Even if the qualifier is preserved, add note that actual testing is required for their specific workload/region pair

**Instance type verification — search EACH family separately:**
- `"C8g" "Osaka" site:aws.amazon.com/about-aws/whats-new`
- `"M8g" "Osaka" site:aws.amazon.com/about-aws/whats-new`
- `"R8g" "Osaka" site:aws.amazon.com/about-aws/whats-new`

**SLA verification — fetch the actual SLA page:**
- `url_fetch("https://aws.amazon.com/s3/sla/")` → extract exact percentage
- S3 = 99.9%, EC2 Multi-AZ = 99.99%, EKS standard = 99.95%

**Replication latency — fetch service page:**
- Use `url_fetch` on service page to get exact AWS wording
- Verify BOTH bounds of range claims
- **Note whether the source uses qualified language** — if so, mark as "sourced but qualified"

**Incident descriptions — factual scope only:**
- When verifying incident claims, check if the document uses subjective impact language
- **Correct pattern:** "Single AZ (apne1-az4); Xen instance launches only; 88 min duration. Other AZs were not part of this event per [AWS post-event summary](url)."
- **Flag this:** "No customer impact" / "Multi-AZ unaffected" / "0 major incidents" — unless AWS explicitly stated this in their post-event summary
- **Flag undefined severity:** "major" / "minor" labels without definition — AWS has no official severity taxonomy for service events

**URL validation:**
- `url_fetch(url, max_chars=500)` on each cited URL
- Flag broken/empty/redirected URLs

| Claim Type | Where to Verify | Trap |
|---|---|---|
| Service in region | Regional Services List | Changes weekly |
| Instance in region | EC2 Types by Region + What's New | **Search each family separately** |
| AZ count | AWS Global Infrastructure | Usable ≠ listed (Tokyo) |
| Launch date | What's New | Exact date searchable |
| Latency | AWS does NOT publish hard numbers | Tier 2 only; qualified language common |
| SLA | SLA pages | **Fetch exact number** |
| Replication | Service page | **Fetch first; note qualified language** |
| Incidents | [Post-Event Summaries](https://aws.amazon.com/premiumsupport/technology/pes/) | **Scope only, no impact assertions** |

### Step 4: Generate Correction Report + Quality Score
- **Mode**: `deterministic`
- **Tool**: `file_write`
- **Input**: Verification results from Step 3
- **Output**: `artifacts/fact-check-report.md`

**Quality Score calculation:**
```
# Qualified claims count as 0.5 (half-verified)
fully_verified = count of ✅ (no qualifier)
qualified = count of ✅ sourced but qualified
score_numerator = fully_verified + (qualified × 0.5)
pass_rate = score_numerator ÷ total_claims × 100
score = round(pass_rate / 10, 1)

Rating:
  9-10: Excellent — ready for customer delivery
  8-8.9: Good — minor fixes needed
  6-7.9: Needs Work — significant corrections required
  <6: Critical — document has major accuracy issues
```

**Report template:**
```markdown
# Fact Check Report: {document_name}
**Date:** {today}
**Scope:** {{check_scope}}
**Checked by:** Document Fact Checker skill (v6)

## Quality Score: X.X/10 ({rating})
- Pass rate: XX% (verified ÷ total)
- Total claims checked: X
- ✅ Verified (hard facts): X
- ✅⚠️ Sourced but qualified (actual test required): X
- ⚠️ Partially correct: X
- ❌ Incorrect: X
- ❓ Unverifiable: X
- 🔄 Source upgraded: X
- 🔗 Broken URLs: X

## Corrections
| # | Claim | Location | Issue | Correction | Source |
|---|---|---|---|---|---|

## Qualified Claims Requiring Validation
| # | Claim | Location | AWS Exact Wording | Qualifier Used | Recommended Annotation |
|---|---|---|---|---|---|
| 1 | "<1s replication" | §3 table | "typically replicated within a second" | "typically" | Add: "per AWS docs — actual test required for Seoul→Tokyo P50/P99" |

## Third-Party Sources Flagged
| Source | Used For | Replacement |
|---|---|---|

## Broken URLs
| URL | Status | Replacement |
|---|---|---|

## Misleading Framing
| Phrase | Issue | Correction |
|---|---|---|

## Impact Language Flagged
| Statement | Issue | Suggested Rewrite |
|---|---|---|

## Unverifiable Claims
| Claim | Why | Action |
|---|---|---|
```

### Step 5: Apply Changes (based on output_format)
- **Mode**: `agentic`
- **Tool**: `file_edit`
- **Input**: Correction report + original document + `{{output_format}}`
- **Output**: Modified document (if applicable)

**Branching:**
- `{{output_format}}` = **"report"** → Skip. Report only.
- `{{output_format}}` = **"inline"** or **"both"** → Add footnotes/annotations. Mark ⚠️ items. Replace Tier 3/4 sources. **Add "actual test required" notes to qualified claims.**
- `{{output_format}}` = **"fix"** → **Auto-correct ALL ❌ and ⚠️ items:**
  1. Replace incorrect values with verified correct values
  2. Replace Tier 3/4 sources with Tier 1 URLs
  3. Fix broken URLs
  4. Remove misleading framing
  5. Rewrite impact assertions as factual scope descriptions
  6. Replace undefined severity labels with factual event descriptions
  7. Add missing citations
  8. **Annotate qualified claims:** Add "(per AWS docs)" + "actual test required" disclaimer
  9. **Do not strip qualifiers:** If AWS says "typically", keep "typically" in the document
  10. Record each change as a diff in the report (old → new)
  11. Do NOT ask user for confirmation — apply all fixes directly

**Qualified claim fix pattern:**
- Original: `<1s replication latency`
- Fixed: `<1s replication latency (per AWS docs: "typically within a second") — **actual test required** to confirm for your workload`

### Step 6: Deliver
- **Mode**: `deterministic`
- **Tool**: `open_in_session_tab`
- **Input**: Generated files
- **Output**: Files opened for review
- Open correction report
- If document was modified (inline/fix), open it too
- Present: quality score, pass rate, critical issues count, changes applied
- **Highlight qualified claims count** — these are items the customer should validate through testing

## Lessons Learned

### Do
- **Fetch before flagging** — check service pages before asserting "not published"
- **Search each instance family separately** — C8g, M8g, R8g launch at different times
- **Fetch SLA pages directly** — percentages change (EKS updated Mar 2026)
- **Split range claims** — verify both bounds independently
- **Validate all URLs** — broken links erode credibility
- **Describe incidents by scope, not impact** — state which AZ, which service, how long, and cite the AWS post-event summary. Never assert "no impact" on your own.
- **Preserve qualified language** — if AWS says "typically", keep it. Do not upgrade to a guarantee.
- **Add testing disclaimers** — for any qualified number in customer-facing docs, note that actual testing is required
- Be conservative — flag as "unverifiable" over asserting without source

### Don't
- **Don't assert "AWS doesn't publish X" without checking**
- **Don't use "no customer impact" / "unaffected" / "zero downtime"** unless quoting directly from an AWS post-event summary
- **Don't use "major" / "minor" severity labels** without explicit definition — AWS has no official classification
- **Don't mark "typically <1s" as ✅ verified** — it's sourced but qualified; flag it for testing
- **Don't strip qualifiers** — presenting "typically <1s" as "<1s" overstates the claim
- Don't trust third-party aggregators as authoritative
- Don't lump instance families — they have different availability
- Don't assume NMIP publishes static reference data
- Don't restate "typically" as an SLA

### Common Pitfalls (verify by fetching before applying)

> ⚠️ **HEURISTICS — not absolute rules.** Fetch the actual page before applying. Page wins over pitfall.

- **"100% parity"** — Almost never true
- **AZ counts** — Usable may differ from listed (Tokyo 4 vs 3)
- **S3 SLA** — 99.9% (SLA) vs 99.99% (design goal)
- **Replication "typical"** — Valid Tier 1 source, but NOT a P99 guarantee. Always add "actual test required" for customer docs.
- **NMIP** — Measurement tool, not data publication
- **Impact language** — "no customer impact", "unaffected", "zero downtime", "Multi-AZ architectures were not impacted" — these are impact assertions that require explicit AWS sourcing. **Correct approach:** describe factual scope only: "Event scope: single AZ. Other AZs were not part of this event per [AWS post-event summary](url)."
- **Severity labels** — "major incident", "minor event", "0 major" — AWS does not publish a severity taxonomy for service events. **Correct approach:** describe events by factual scope (which AZ, which service, duration, what was/wasn't in scope per AWS summary) without assigning severity labels.
- **Qualified numbers presented as guarantees** — "typically under 1 second" written as "<1s" without qualifier. **Correct approach:** preserve the qualifier, cite the source, and add "actual test required for your environment."
