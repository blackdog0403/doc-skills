#!/usr/bin/env bash
# gen-release-notes.sh — Summarize commits since the previous tag, grouped by
# commit-message prefix (feat/docs/ci/<skill>:...). Prints Markdown to stdout.
# Usage: ./scripts/gen-release-notes.sh <version>
set -euo pipefail

VERSION="${1:?usage: gen-release-notes.sh <version>}"
TAG="v${VERSION}"

# Previous *stable* tag by version order (ignore -rc/-beta/-alpha and the tag
# being released), so a stable release's notes aren't empty when an rc tagged
# the same commit.
PREV="$(git tag --sort=-version:refname | grep -vE -- '-(rc|beta|alpha)' | grep -vFx "$TAG" | head -n1 || true)"
RANGE="HEAD"; [ -n "$PREV" ] && RANGE="${PREV}..HEAD"

SUBJECTS="$(git log --no-merges --pretty='%s' "$RANGE")"
[ -z "$SUBJECTS" ] && { echo "_No changes._"; exit 0; }

KNOWN='^(feat|docs|ci|build|chore|doc-fact-check|md-to-docx|translate-pptx|stop-slop)[(:]'

section() { # $1=title  $2=ERE prefix match
  local m; m="$(printf '%s\n' "$SUBJECTS" | grep -iE "$2" || true)"
  [ -z "$m" ] && return 0
  printf '### %s\n' "$1"
  printf '%s\n' "$m" | sed -E 's/^[^:]+:[[:space:]]*/- /'
  printf '\n'
}

printf "## What's Changed\n"
[ -n "$PREV" ] && printf '_Changes since %s_\n' "$PREV"
printf '\n'

section '✨ Skills & Features' '^(feat|doc-fact-check|md-to-docx|translate-pptx|stop-slop)[(:]'
section '📖 Documentation'     '^docs[(:]'
section '🔧 CI & Tooling'      '^(ci|build|chore)[(:]'

OTHER="$(printf '%s\n' "$SUBJECTS" | grep -ivE "$KNOWN" || true)"
if [ -n "$OTHER" ]; then
  printf '### 🔖 Other\n'
  printf '%s\n' "$OTHER" | sed 's/^/- /'
  printf '\n'
fi
