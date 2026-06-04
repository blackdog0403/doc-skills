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
9. **No impact assertions without AWS source** — Never write "no customer impact", "unaffected", or "zero downtime" unless AWS explicitly stated this in a post-event summary. Use factual scope descriptions only.
10. **No undefined severity labels** — AWS does not publish a severity classification. Terms like "major incident" or "minor event" are subjective and must not be used without explicit definition.
11. **Qualified language ≠ verified number** — When AWS docs use hedging words ("typically", "usually", "less than", "up to", "in most cases"), the claim is NOT fully verified. It must be flagged as requiring actual testing for the customer's specific environment.
12. **Negative claims require equal rigor** — Asserting absence ("None", "No events", "Not available") is a factual claim that must be verified with the same effort as asserting presence. "No incidents" is WRONG if a PES exists.
13. **URL dates are unreliable** — Never infer publication dates from URL paths. Always fetch the page and extract the actual "Posted on" / "Last updated" date.
14. **Corrections must not create new errors** — After fixing a claim, verify the fix is consistent with surrounding context (table headers, other tables, summary sections).

## Source Hierarchy (Trustworthiness)

| Tier | Source Type | Action |
|---|---|---|
| **Tier 1 (Use)** | AWS official documentation (docs.aws.amazon.com) | ✅ Cite directly |
| **Tier 1 (Use)** | AWS What's New announcements | ✅ Cite directly |
| **Tier 1 (Use)** | AWS blog posts (aws.amazon.com/blogs/) | ✅ Cite directly |
| **Tier 1 (Use)** | AWS press releases (press.aboutamazon.com) | ✅ Cite directly |
| **Tier 1 (Use)** | AWS service pages (aws.amazon.com/{service}/) | ✅ Cite directly |
| **Tier 1 (Use)** | AWS Post-Event Summaries (aws.amazon.com/premiumsupport/technology/pes/) | ✅ Authoritative incident source |
| **Tier 2 (Acceptable)** | Customer's own measurements (first-party data) | ✅ Note source + date |
| **Tier 2 (Acceptable)** | Organization's internal wiki/tools | ✅ For internal docs only |
| **Tier 3 (Flag)** | Third-party monitoring tools (Economize, IsDown, CloudPing, aws-services.info) | ⚠️ Flag |
| **Tier 3 (Flag)** | Community posts, re:Post user answers | ⚠️ Flag |
| **Tier 4 (Remove)** | Unattributed claims, "it is known that..." | ❌ Remove/rewrite |

## Negative Claim Verification Rule (v7)

**Problem:** Documents often assert absence — "No outages", "None reported", "Not available", "No events in last 12 months." These negative claims are just as likely to be wrong as positive claims, but are psychologically easier to skip verification on.

**Rule:** Any negative claim ("None", "No", "Not", "0 events", "Never") MUST be actively verified. The burden of proof for "nothing happened" is the same as "something happened."

**Mandatory verification for negative incident claims:**
1. Fetch the AWS Post-Event Summaries page: `url_fetch("https://aws.amazon.com/premiumsupport/technology/pes/")`
2. Search for the region name in the PES list
3. If ANY PES exists for that region → the "None" claim is ❌ INCORRECT
4. Additionally: `web_search("[region name] outage post-event summary site:aws.amazon.com")`

**Mandatory verification for negative availability claims ("Not available", "❌"):**
1. `web_search("[service name] [region name] site:aws.amazon.com/about-aws/whats-new")`
2. Check the Regional Services List
3. If service IS available → the "❌" claim is INCORRECT

**Why this matters:** Asserting "no incidents" when incidents DID occur is worse than missing a positive claim — it misleads the reader into false confidence about reliability.

## Cross-Table Consistency Rule (v7)

**Problem:** Documents often present the same data in multiple places (detail table + summary table + prose). Correcting one location without updating others creates internal contradictions.

**Rule:** After identifying a correction, scan the ENTIRE document for other references to the same data point. All instances must be corrected together.

**Verification steps:**
1. When a claim is flagged ❌, search the document for ALL occurrences of that value
2. Check: Does the correction fit the context of each location? (e.g., table header says "last 12 months" but the corrected event is from 7 years ago)
3. If the correction creates a new inconsistency, flag it and propose a resolution that maintains consistency across ALL locations

## URL Date Verification Rule (v7)

**Problem:** AWS What's New URL paths often contain a date segment (e.g., `/2026/02/...`) that differs from the actual publication date shown on the page. This happens when posts are created internally then published later.

**Rule:** Never trust URL path dates. Always fetch the page and extract the actual "Posted on" date.

**Verification steps:**
1. `url_fetch(url, max_chars=2000)` — look for "Posted on:", "Last updated:", or date metadata
2. Compare extracted date vs. URL path date
3. If they differ, use the PAGE date (not the URL date)
4. In the report, note the discrepancy if it affects any claim in the document

## Qualified Language Rule (v6)

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

**Qualified language indicators (trigger words):**
- "typically", "usually", "generally", "in most cases"
- "less than", "under", "up to", "approximately"
- "designed to", "expected to", "aims to"
- Any number followed by "or less", "or more", "or better"

**Fix mode behavior:**
- Preserve the qualifier, cite the source, add "actual test required" disclaimer
- Pattern: `<number> (per AWS docs: "typically X") — actual test required to confirm for your environment`

## Workflow

### Step 1: Read & Extract Claims (with Scope Filtering)

- Read the document and extract ALL factual claims — both positive AND negative
- Categorize: `latency`, `service_availability`, `capacity`, `pricing`, `reliability`, `date/timeline`, `incident`
- **Range claim splitting:** "0.5-1.5s" → TWO claims: lower bound + upper bound (each needs sourcing)
- **Scope filtering:** If scope ≠ "all", only retain matching category claims
- **Negative claim extraction:** Flag ALL "None", "No events", "Not available", "❌", "0", "Never" statements as requiring active verification
- **Impact language extraction:** Flag any statement containing impact assertions
- **Qualified language extraction:** Flag any claim containing hedging words

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
**CRITICAL: Verify negative claims with the same rigor as positive claims.**

#### 3a. Incident History Verification (MANDATORY for any reliability/incident section)

**Step 1 — Fetch the PES index:**
```
url_fetch("https://aws.amazon.com/premiumsupport/technology/pes/", max_chars=10000)
```
Extract ALL post-event summaries listed. Note which regions are mentioned.

**Step 2 — For EACH region in the document's incident table:**
- If document claims "No events" / "None" → check PES list for ANY entry mentioning that region
- If PES exists for the region → the "None" claim is ❌ INCORRECT
- Additionally search: `web_search("[region] outage post-event summary site:aws.amazon.com")`

**Step 3 — For positive incident claims:**
- Fetch the cited PES URL and verify: correct region, correct date, correct scope description
- Cross-check the event date against the table's stated time range

#### 3b. Service Availability & Date Verification

**Instance type verification — search EACH family separately:**
- `"C8g" "Osaka" site:aws.amazon.com/about-aws/whats-new`
- `"M8g" "Osaka" site:aws.amazon.com/about-aws/whats-new`

**Date verification — always fetch the page**

**SLA verification — fetch the actual SLA page:**
- Fetch `https://aws.amazon.com/{service}/sla/` → extract exact percentage

**Negative availability claims — search What's New + Regional Services List**

#### 3c. Qualified Language Verification
- Fetch source page, extract EXACT wording, compare with document's presentation

#### 3d. URL Validation
- Fetch each cited URL, flag broken/redirected, extract actual posted dates

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

### Step 4: Cross-Table Consistency Check (v7)

- For EACH correction identified in Step 3:
  1. Search the entire document for ALL occurrences of that value
  2. Verify the correction fits the context of each location (e.g., table header says "last 12 months" but the corrected event is from 7 years ago)
  3. If the correction creates a new inconsistency, flag it and propose a resolution that maintains consistency across ALL locations

### Step 5: Generate Correction Report + Quality Score

**Quality Score calculation:**
```
pass_rate = (fully_verified + qualified×0.5) ÷ total_claims × 100
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

### Step 6: Apply Changes (based on output format)

- **report** → Report only, no document changes
- **inline** or **both** → Add footnotes/annotations. Mark ⚠️ items. Replace Tier 3/4 sources.
- **fix** → Auto-correct ALL ❌ and ⚠️ items directly, record diffs in report

### Step 7: Deliver

- Open correction report
- If document was modified, open it too
- Present: quality score, critical issues count, negative claims verified count

## Lessons Learned

### Do
- **Verify negative claims actively** — "None" and "No events" are factual claims that can be wrong
- **Fetch the PES page first** — https://aws.amazon.com/premiumsupport/technology/pes/
- **Check cross-table consistency** — a fix in one table may conflict with another
- **Extract actual page dates** — URL paths lie; "Posted on" dates are truth
- **Fetch before flagging** — check service pages before asserting "not published"
- **Search each instance family separately** — C8g, M8g, R8g launch at different times
- **Fetch SLA pages directly** — percentages change
- **Split range claims** — verify both bounds independently
- **Validate all URLs** — broken links erode credibility
- **Describe incidents by scope, not impact**
- Be conservative — flag as "unverifiable" over asserting without source

### Don't
- **Don't skip negative claims** — "No outages reported" is a verifiable factual assertion
- **Don't trust URL path dates** — `/2026/02/` might actually be posted in May 2026
- **Don't fix one table and forget others** — same data often appears in 3+ locations
- **Don't assert "AWS doesn't publish X" without checking**
- **Don't mark "typically <1s" as ✅ verified** — it's sourced but qualified
- **Don't use "no customer impact" / "unaffected" / "zero downtime"** unless quoting AWS
- **Don't use "major" / "minor" severity labels** without explicit definition
- Don't trust third-party aggregators as authoritative
- Don't lump instance families — they have different availability
- Don't assume NMIP publishes static reference data
- Don't restate "typically" as an SLA

### Common Pitfalls (verify by fetching before applying)

> ⚠️ **HEURISTICS — not absolute rules.** Fetch the actual page before applying.

- **"No events / None"** — ALWAYS check PES page. Seoul had DNS outage 2018. Tokyo had cooling incident 2019.
- **Service availability "❌"** — regions add services continuously; can become stale within months
- **What's New dates** — URL date ≠ actual posted date. ALWAYS fetch and check.
- **"100% parity"** — Almost never true
- **AZ counts** — Usable may differ from listed
- **S3 SLA** — 99.9% (SLA) vs 99.99% (design goal)
- **NMIP** — Measurement tool, not data publication
- **Impact language** — Requires explicit AWS sourcing
- **Severity labels** — AWS has no official taxonomy
