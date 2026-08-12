#!/usr/bin/env bash
# gen-release-notes.sh — Summarize commits since the previous tag, grouped by
# commit-message prefix (feat/docs/ci/<skill>:...). Prints Markdown to stdout.
# Usage: ./scripts/gen-release-notes.sh <version>
#
# Notes describe the *net* change since the previous tag, so intra-release churn
# is filtered: revert/reapply subjects are dropped, and subjects are de-duplicated
# because re-applying a reverted change repeats subjects already in the range.
# Caveat: a revert that is NOT re-applied within the same release is dropped too,
# so state the removal in the commit that reverts it if users need to see it.
set -euo pipefail

VERSION="${1:?usage: gen-release-notes.sh <version>}"
TAG="v${VERSION}"

# Previous *stable* tag by version order (ignore -rc/-beta/-alpha and the tag
# being released), so a stable release's notes aren't empty when an rc tagged
# the same commit.
PREV="$(git tag --sort=-version:refname | grep -vE -- '-(rc|beta|alpha)' | grep -vFx "$TAG" | head -n1 || true)"
RANGE="HEAD"; [ -n "$PREV" ] && RANGE="${PREV}..HEAD"

SUBJECTS="$(git log --no-merges --pretty='%s' "$RANGE" | grep -viE '^(revert|reapply)[ (:"]' || true)"
[ -z "$SUBJECTS" ] && { echo "_No changes._"; exit 0; }

KNOWN='^(feat|fix|docs|ci|build|chore|test|doc-fact-check|md-to-docx|translate-pptx|stop-slop|verity|aws-price-check)[(:]'

section() { # $1=title  $2=ERE prefix match
  local m; m="$(printf '%s\n' "$SUBJECTS" | grep -iE "$2" || true)"
  [ -z "$m" ] && return 0
  printf '### %s\n' "$1"
  # De-duplicate: re-applying a reverted change repeats subjects already in range.
  printf '%s\n' "$m" | sed -E 's/^[^:]+:[[:space:]]*/- /' | awk '!seen[$0]++'
  printf '\n'
}

printf "## What's Changed\n"
[ -n "$PREV" ] && printf '_Changes since %s_\n' "$PREV"
printf '\n'

section '✨ Skills & Features' '^(feat|doc-fact-check|md-to-docx|translate-pptx|stop-slop|verity|aws-price-check)[(:]'
section '🐛 Fixes'             '^fix[(:]'
section '📖 Documentation'     '^docs[(:]'
section '🔧 CI & Tooling'      '^(ci|build|chore|test)[(:]'

OTHER="$(printf '%s\n' "$SUBJECTS" | grep -ivE "$KNOWN" || true)"
if [ -n "$OTHER" ]; then
  printf '### 🔖 Other\n'
  printf '%s\n' "$OTHER" | sed 's/^/- /' | awk '!seen_other[$0]++'
  printf '\n'
fi
