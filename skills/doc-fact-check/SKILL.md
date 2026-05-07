---
name: doc-fact-check
description: |
  Verify factual claims in technical documents against authoritative sources.
  Removes/flags third-party unverifiable data, validates claims against AWS
  official documentation and announcements, adds proper citations, and produces
  a correction report with quality score.
  Use when: "fact check this", "검증해줘", "verify the claims", "check sources",
  "remove third-party data", "add citations", "출처 확인", "AWS 공식 데이터로 바꿔줘".
allowed-tools: [Bash, Read, Write, Edit, WebFetch, WebSearch, Agent]
---

## Overview

Verify factual claims in technical documents against **authoritative sources only**. Produces a correction report with a quality score, optionally annotates the source document, or auto-fixes all issues.

**Core principle:** Every factual claim must trace to an authoritative source (AWS docs, What's New, press releases) or be explicitly marked as unverifiable.

**Anti-hallucination rule:** The Common Pitfalls section contains heuristics that may become outdated. When a pitfall says "AWS does NOT publish X" — **always verify by fetching the actual service page** before flagging. If the page DOES contain the data, the claim is verified regardless of what the pitfall says.

## Arguments

```
/doc-fact-check <file_path> [scope:all|latency|services|reliability|pricing] [output:report|inline|both|fix]
```

- **file_path** (required): Path to document to check (.md, .docx, .pdf, .txt)
- **scope** (optional, default: "all"): Category filter — only verify claims in that category
- **output** (optional, default: "both"): 
  - `report` — correction report only
  - `inline` — annotate document only
  - `both` — report + annotations
  - `fix` — auto-correct all issues + produce report with diffs

## Philosophy

1. **Only authoritative sources** — AWS official docs, AWS What's New, AWS blogs, press releases
2. **Remove or flag third-party sources** — Third-party measurement tools, user-reported data
3. **Customer's own measurements are acceptable** — First-party data is valid (Tier 2)
4. **Conservative when uncertain** — Flag as unverifiable rather than asserting correctness
5. **Citations must be clickable** — Every claim should link to its source
6. **Range values need both bounds sourced** — "0.5-1.5s" requires sourcing for BOTH numbers
7. **"Typically" ≠ guarantee** — "Typically under 1 second" ≠ "< 1s SLA"
8. **Verify before flagging** — Never assert "AWS doesn't publish X" without fetching the page first
9. **No impact assertions without AWS source** — Never write "no customer impact", "unaffected", or "zero downtime" unless AWS explicitly stated this in a post-event summary
10. **No undefined severity labels** — AWS does not publish a severity classification. Terms like "major incident" or "minor event" are subjective and must not be used without explicit definition.

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

## Workflow

### Step 1: Read & Extract Claims (with Scope Filtering)

- Read the document and extract all factual claims (numbers, dates, service availability, latency, pricing, AZ counts, instance types, etc.)
- Categorize: `latency`, `service_availability`, `capacity`, `pricing`, `reliability`, `date/timeline`, `incident`
- **Range claim splitting:** "0.5-1.5s" → TWO claims: lower bound + upper bound (each needs sourcing)
- **Scope filtering:** If scope ≠ "all", only retain matching category claims
- **Impact language extraction:** Flag any statement containing impact assertions for verification

### Step 2: Identify Sources Used

- Classify each cited source against the Source Hierarchy
- Flag Tier 3/4 sources
- **Check misleading framing:**
  - "AWS Network Manager reference data" — NMIP does NOT publish static reference data
  - "AWS confirmed" without a citation
  - "per AWS documentation" without a link
  - Ranges with unsourced upper bounds
  - **Undefined severity labels** without definition
  - **Impact assertions without source**

### Step 3: Verify Against Authoritative Sources + URL Validation

**CRITICAL: Always fetch before flagging.**

**Instance type verification — search EACH family separately:**
- `"C8g" "Osaka" site:aws.amazon.com/about-aws/whats-new`
- `"M8g" "Osaka" site:aws.amazon.com/about-aws/whats-new`

**SLA verification — fetch the actual SLA page:**
- Fetch `https://aws.amazon.com/{service}/sla/` → extract exact percentage

**Replication latency — fetch service page:**
- Verify BOTH bounds of range claims

**Incident descriptions — factual scope only:**
- Check if the document uses subjective impact language
- **Correct pattern:** "Single AZ (apne1-az4); Xen instance launches only; 88 min duration. Other AZs were not part of this event per [AWS post-event summary](url)."
- **Flag:** "No customer impact" / "Multi-AZ unaffected" / "0 major incidents"

**URL validation:**
- Fetch each cited URL — flag broken/empty/redirected URLs

| Claim Type | Where to Verify | Trap |
|---|---|---|
| Service in region | Regional Services List | Changes weekly |
| Instance in region | EC2 Types by Region + What's New | Search each family separately |
| AZ count | AWS Global Infrastructure | Usable ≠ listed |
| Launch date | What's New | Exact date searchable |
| Latency | AWS does NOT publish | Tier 2 only |
| SLA | SLA pages | Fetch exact number |
| Replication | Service page | Fetch first |
| Incidents | Post-Event Summaries | Scope only, no impact assertions |

### Step 4: Generate Correction Report + Quality Score

**Quality Score calculation:**
```
pass_rate = verified ÷ total_claims × 100
score = round(pass_rate / 10, 1)  # e.g., 85.7% → 8.6/10

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
**Scope:** {scope}
**Checked by:** Document Fact Checker skill

## Quality Score: X.X/10 ({rating})
- Total claims checked: X
- ✅ Verified: X
- ⚠️ Partially correct: X
- ❌ Incorrect: X
- ❓ Unverifiable: X

## Corrections
| # | Claim | Location | Issue | Correction | Source |
|---|---|---|---|---|---|

## Third-Party Sources Flagged
| Source | Used For | Replacement |
|---|---|---|

## Broken URLs
| URL | Status | Replacement |
|---|---|---|

## Misleading Framing
| Phrase | Issue | Correction |
|---|---|---|
```

### Step 5: Apply Changes (based on output format)

- **report** → Report only, no document changes
- **inline** or **both** → Add footnotes/annotations. Mark ⚠️ items. Replace Tier 3/4 sources.
- **fix** → Auto-correct ALL ❌ and ⚠️ items directly, record diffs in report

### Step 6: Deliver

- Open correction report
- If document was modified, open it too
- Present: quality score, pass rate, critical issues count

## Lessons Learned

### Do
- **Fetch before flagging** — check service pages before asserting "not published"
- **Search each instance family separately** — C8g, M8g, R8g launch at different times
- **Fetch SLA pages directly** — percentages change
- **Split range claims** — verify both bounds independently
- **Validate all URLs** — broken links erode credibility
- **Describe incidents by scope, not impact**
- Be conservative — flag as "unverifiable" over asserting without source

### Don't
- **Don't assert "AWS doesn't publish X" without checking**
- **Don't use "no customer impact" / "unaffected" / "zero downtime"** unless quoting AWS
- **Don't use "major" / "minor" severity labels** without explicit definition
- Don't trust third-party aggregators as authoritative
- Don't lump instance families — they have different availability
- Don't assume NMIP publishes static reference data
- Don't restate "typically" as an SLA

### Common Pitfalls (verify by fetching before applying)

> ⚠️ **HEURISTICS — not absolute rules.** Fetch the actual page before applying.

- **"100% parity"** — Almost never true
- **AZ counts** — Usable may differ from listed
- **S3 SLA** — 99.9% (SLA) vs 99.99% (design goal)
- **NMIP** — Measurement tool, not data publication
- **Impact language** — Requires explicit AWS sourcing
- **Severity labels** — AWS has no official taxonomy
