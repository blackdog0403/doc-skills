---
name: aws-price-check
description: |
  Verify AWS price claims in a document against official AWS pricing data for a
  specific region. Cross-checks every dollar figure and per-unit rate against
  three authoritative AWS sources (Price List Query API, S3/service bulk offer
  files, the calculator.aws data feed), catches region mismatches (e.g. numbers
  computed with us-east-1 rates), recomputes derived totals, and produces a
  per-claim verdict table with corrections and a quality score.
  Use when: "price check", "가격 검증", "이 가격 맞는지 확인", "verify the pricing",
  "check AWS prices for <region>", "리전 기준 가격 맞아?", "가격 팩트체크",
  "is this priced right for ap-northeast-2".
allowed-tools: [Bash, Read, Write, Edit, WebFetch, WebSearch]
---

## Overview

Verify **AWS price claims** in a document are correct **for a specific region**, using
**only official AWS pricing data**. Produces a per-claim verdict table, corrected
figures, and a quality score.

This is the pricing-specialist sibling of `doc-fact-check`. Use `doc-fact-check`
for general factual claims (service availability, dates, incidents, latency).
Use **this skill** when the claims are dollar amounts, per-GB/per-request rates,
or derived cost totals that must match a named region.

**Core principle:** every price traces to an authoritative AWS source for the
**stated region**, or it is flagged. The #1 real-world error is a number that is
correct for `us-east-1` but wrong for the customer's region — always pin the region.

## Arguments

```
/aws-price-check <file_path> [region:<code|name>] [output:report|inline|both|fix]
```

- **file_path** (required): document with price claims (.md, .txt, .docx, .pdf)
- **region** (optional but strongly recommended): e.g. `ap-northeast-2` or
  `Asia Pacific (Seoul)`. If absent, infer from the doc; if you cannot, **ask**.
- **output** (default `both`): `report` | `inline` (annotate) | `both` | `fix` (auto-correct)

## Source Hierarchy (use Tier 1 only for prices)

| Tier | Source | How to access |
|---|---|---|
| **1** | AWS Price List Query API | `aws pricing get-products` (call from **us-east-1** only) |
| **1** | AWS bulk offer file | `curl .../offers/v1.0/aws/<Service>/current/<region>/index.json` |
| **1** | calculator.aws data feed | `curl --compressed .../meteredUnitMaps/<svc>/USD/current/<svc>.json` |
| **1** | AWS pricing web page (region dropdown) | `WebFetch` / browser, last resort for gaps |
| ❌ | Third-party calculators, blogs, cached numbers | Do not use for price values |

If two Tier-1 sources disagree, prefer the one whose `publicationDate` / manifest
date is newer, and note the discrepancy.

## Region → usagetype prefix map (extend as needed)

The Price List data tags each line with a region usagetype prefix. Confirm the
prefix before trusting a match.

| Region code | Location filter value | usagetype prefix |
|---|---|---|
| us-east-1 | US East (N. Virginia) | (none / bare) |
| us-west-2 | US West (Oregon) | `USW2-` |
| ap-northeast-1 | Asia Pacific (Tokyo) | `APN1-` |
| ap-northeast-2 | Asia Pacific (Seoul) | `APN2-` |
| ap-northeast-3 | Asia Pacific (Osaka) | `APN3-` |
| ap-southeast-1 | Asia Pacific (Singapore) | `APS1-` |
| eu-west-1 | EU (Ireland) | `EUW1-` |
| eu-central-1 | EU (Frankfurt) | `EUC1-` |

> Inter-region data transfer is tagged `<FROM>-<TO>-AWS-Out-Bytes`, e.g. Seoul→Tokyo = `APN2-APN1-AWS-Out-Bytes`.

## Workflow

### Step 1 — Pin the region, extract price claims

- Determine the target region. If the doc names a region, use it; else ask the user.
  **Do not silently assume us-east-1.**
- Extract every price claim into a list, each tagged with a category:
  `storage_rate`, `request_rate`, `retrieval/restore`, `data_transfer`,
  `derived_total` (a $ figure computed from a rate × quantity), `effective/modeled`.
- For each `derived_total`, also capture the **stated unit basis** (binary GB:
  1 PB = 1,048,576 GB, vs decimal GB: 1 PB = 1,000,000 GB). Cost math must use the
  same basis the doc uses; state which.

### Step 2 — Pull authoritative rates for the region

Run the queries in **Reference: Commands** below for each service touched
(AmazonS3, AWSDataTransfer, AWSCloudTrail, AmazonEC2, …). Save raw JSON to `/tmp`.
Build a table of `usagetype → USD rate → description` filtered to the region prefix.

**Always cross-check at least two Tier-1 sources** when a number is load-bearing
(e.g. a headline cost). The API and the bulk offer file occasionally differ in
coverage — see Pitfalls.

### Step 3 — Verdict each claim

| Status | Meaning |
|---|---|
| ✅ Verified | Matches the region's authoritative rate exactly |
| ❌ Incorrect | Wrong number, or right number but **wrong region** (state which rate it actually matches) |
| ⚠️ Modeled | Derived/"effective" value; base rate verified but multiplier is an assumption |
| ❓ Unverifiable | No Tier-1 source publishes it for this region (say so explicitly) |

- For `derived_total`: recompute = rate × quantity (with the doc's GB basis) and compare.
- For `data_transfer`: confirm the exact `FROM-TO` usagetype; note transfer-only
  vs. total (replication also adds request + destination-storage charges).
- For `effective/modeled` (e.g. Object Lock 2×): verify the **base** rate, then
  label the multiplier as a modeled assumption, not a list price.

### Step 4 — Cross-check region-mismatch hypothesis

When a `derived_total` is off, **test whether it matches another region's rate**
(usually us-east-1). If `claim ≈ rate(us-east-1) × qty` but `≠ rate(target) × qty`,
report it as "computed with us-east-1 rate" — this is the most common defect and
the most useful thing to tell the author.

### Step 5 — Report + quality score

```
pass_rate = (verified + modeled×0.5) ÷ total_price_claims × 100
score = round(pass_rate / 10, 1)
  9–10 Excellent · 8–8.9 Good · 6–7.9 Needs work · <6 Critical
```

Report template:
```markdown
# Price Check: {doc} — {region}
**Date:** {today}   **Region:** {code} ({location}, prefix {APNx-})
**Sources:** Price List API · bulk offer file · calculator.aws feed (pub {date})

## Quality Score: X.X/10 ({rating})
Total price claims: N · ✅ M · ❌ K · ⚠️ J · ❓ I

## Verdicts
| # | Location | Claim | Region authoritative value | Verdict |

## Region mismatches (most important)
| Claim | Doc value | Matches which region | Correct {region} value |

## Recommended edits
（corrected block ready to paste）

## Caveats / out-of-scope
（unit basis, transfer-only vs total, modeled multipliers, unpublished lines, non-price claims）
```

### Step 6 — Apply (per output mode)

- `report` → report only
- `inline`/`both` → annotate doc with ✅/❌ + correct value + source line
- `fix` → replace incorrect figures in place; record diffs in the report

## Reference: Commands (copy-paste; sub the region)

> `REGION_NAME` = the `location` filter value, e.g. `Asia Pacific (Seoul)`.
> The `aws pricing` API is global — **always** call it with `--region us-east-1`,
> regardless of the region whose prices you want (that comes from the filter).

**S3 storage rates**
```bash
aws pricing get-products --service-code AmazonS3 --region us-east-1 \
  --filters "Type=TERM_MATCH,Field=location,Value=Asia Pacific (Seoul)" \
            "Type=TERM_MATCH,Field=productFamily,Value=Storage" \
  --max-results 100 --output json
```

**A specific usagetype (retrieval/restore, requests, etc.)**
```bash
aws pricing get-products --service-code AmazonS3 --region us-east-1 \
  --filters "Type=TERM_MATCH,Field=location,Value=Asia Pacific (Seoul)" \
            "Type=TERM_MATCH,Field=usagetype,Value=APN2-Standard-Retrieval-Bytes" \
  --max-results 10 --output json
```

**Inter-region data transfer (e.g. Seoul→Tokyo)**
```bash
aws pricing get-products --service-code AWSDataTransfer --region us-east-1 \
  --filters "Type=TERM_MATCH,Field=fromLocation,Value=Asia Pacific (Seoul)" \
            "Type=TERM_MATCH,Field=transferType,Value=InterRegion Outbound" \
  --max-items 40 --output json
# find toLocation == Asia Pacific (Tokyo); usagetype APN2-APN1-AWS-Out-Bytes
```

**CloudTrail (data events, etc.)**
```bash
aws pricing get-products --service-code AWSCloudTrail --region us-east-1 \
  --filters "Type=TERM_MATCH,Field=location,Value=Asia Pacific (Seoul)" \
  --max-items 60 --output json   # line: APN2-DataEventsRecorded
```

**Bulk offer file (more products than API; good cross-check)**
```bash
curl -s "https://pricing.us-east-1.amazonaws.com/offers/v1.0/aws/AmazonS3/current/ap-northeast-2/index.json" -o /tmp/s3_apn2.json
curl -s "https://pricing.us-east-1.amazonaws.com/offers/v1.0/aws/AmazonS3/current/us-east-1/index.json"     -o /tmp/s3_use1.json   # for region-mismatch hypothesis
# structure: products[sku].attributes.usagetype  ↔
#            terms.OnDemand[sku][*].priceDimensions[*].pricePerUnit.USD
```

**calculator.aws feed (the public pricing page's own data; gzip!)**
```bash
curl -s --compressed \
  "https://calculator.aws/pricing/2.0/meteredUnitMaps/s3/USD/current/s3.json" -o /tmp/web_s3.json
# structure: d['regions']['Asia Pacific (Seoul)'][<item name>]['price']
# d['manifest']['hawkFilePublicationDate'] = publication date
```

**Parsing snippet (Price List API JSON)**
```python
import sys, json
data = json.load(sys.stdin)
for p in data.get('PriceList', []):
    j = json.loads(p); a = j['product']['attributes']
    u = a.get('usagetype',''); vt = a.get('volumeType','')
    for _, ov in j.get('terms', {}).get('OnDemand', {}).items():
        for _, dv in ov['priceDimensions'].items():
            print('%-40s|%-26s|%s| %s' % (
                u, vt, dv['pricePerUnit'].get('USD'), dv['description'][:55]))
```

**Paginating the API safely (shell token escaping breaks `--starting-token`)**
```python
import json, subprocess
def page(tok=None):
    cmd = ['aws','pricing','get-products','--service-code','AmazonS3',
           '--region','us-east-1',
           '--filters','Type=TERM_MATCH,Field=location,Value=Asia Pacific (Seoul)',
           '--max-items','100','--output','json']
    if tok: cmd += ['--starting-token', tok]
    r = subprocess.run(cmd, capture_output=True, text=True)
    return json.loads(r.stdout) if r.stdout.strip() else None
tok=None; rows=[]
while True:
    d = page(tok)
    if not d: break
    rows += d.get('PriceList', [])
    tok = d.get('NextToken')
    if not tok: break
```

## Pitfalls (learned the hard way — verify, don't assume)

- **Region mismatch is the #1 defect.** A cost total that "looks about right" is
  often computed with us-east-1 rates. Always pin the region prefix and, when a
  total is off, test it against us-east-1 to confirm the cause.
- **`aws pricing` only runs in us-east-1.** It's a global endpoint; the *target*
  region comes from the `location` filter, not `--region`.
- **calculator.aws responses are gzip** — use `curl --compressed` or they're garbled.
- **Pagination token escaping** — looping `--starting-token` in bash can yield empty
  output. Use the Python `subprocess` loop above.
- **Some storage classes have no standalone line in the structured feeds.**
  Notably **S3 Glacier Deep Archive storage** is absent from the Price List API,
  the bulk offer file, AND the calculator feed — for *every* region (us-east-1 too).
  Verify Deep Archive storage via the **Intelligent-Tiering Deep Archive Access**
  tier (`...INT-DAA-ByteHrs` / `IntelligentTieringDeepArchiveAccess`), which AWS
  prices identically per region, or via the pricing web page region dropdown.
  Never assert "$X is wrong" for these without checking the proxy/web page first.
- **Tiered storage.** S3 Standard etc. have volume tiers (first 50 TB / next 450 TB /
  over 500 TB). A headline rate (first-50-TB) is *correct* but a PB-scale total
  should use the lower over-500-TB tier — flag as a scale caveat, not an error.
- **Binary vs decimal GB.** 1 PB = 1,048,576 GB (binary) vs 1,000,000 GB (decimal).
  Use the doc's basis; state which. This alone shifts a 100 PB total by ~4.9%.
- **Data transfer ≠ total replication cost.** CRR also bills replication PUT
  requests + destination-region storage. A transfer-only figure is fine if labeled.
- **"Effective"/multiplier prices** (e.g. Object Lock 2× from versioning) are
  models, not list prices. Verify the base rate; mark the multiplier as an assumption.
- **Throughput/quota claims aren't prices** — out of scope here; hand to docs/Service
  Quotas verification (or `doc-fact-check`).

## Do / Don't

**Do** — pin the region first · cross-check two Tier-1 sources for headline numbers ·
recompute every derived total · name the exact usagetype as evidence · test the
us-east-1 hypothesis when a total is off · state the GB basis.

**Don't** — assume us-east-1 · trust a number because it "looks right" · use
third-party calculators · assert a Deep Archive storage number is wrong without
the INT-DAA proxy or web page · conflate transfer-only with total replication cost ·
mark a modeled multiplier as ✅ verified.
