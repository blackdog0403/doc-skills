#!/usr/bin/env bash
# ai-release-notes.sh — AI-polished release highlights via Amazon Bedrock
# (Claude Opus 4.7), layered on top of the deterministic changelog.
# Falls back to the deterministic notes on ANY failure (no creds, no jq/aws,
# Bedrock error) so a release is never blocked.
#
# Usage: ./scripts/ai-release-notes.sh <version>
# Env:
#   BEDROCK_MODEL_ID  default: us.anthropic.claude-opus-4-7 (US geo inference profile)
#   AWS_REGION        default: us-west-2
set -euo pipefail

VERSION="${1:?usage: ai-release-notes.sh <version>}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODEL_ID="${BEDROCK_MODEL_ID:-us.anthropic.claude-opus-4-7}"
REGION="${AWS_REGION:-us-west-2}"

# Deterministic, factual changelog — always available, used as the backbone.
FACTS="$("$SCRIPT_DIR/gen-release-notes.sh" "$VERSION")"

ai_highlights() {
  command -v aws >/dev/null 2>&1 || return 1
  command -v jq  >/dev/null 2>&1 || return 1
  local prompt msgs out
  prompt="Write the intro for release ${VERSION}. Summarize ONLY the changes below into 2-4 concise, user-facing highlight bullets. Do not invent anything not listed. Output Markdown bullets only, no preamble.

${FACTS}"
  msgs="$(jq -nc --arg t "$prompt" '[{role:"user",content:[{text:$t}]}]')"
  out="$(aws bedrock-runtime converse \
    --region "$REGION" \
    --model-id "$MODEL_ID" \
    --messages "$msgs" \
    --inference-config '{"maxTokens":700}' \
    --query 'output.message.content[0].text' --output text 2>/dev/null)" || return 1
  if [ -z "$out" ] || [ "$out" = "None" ]; then return 1; fi
  printf '%s' "$out"
}

printf '## ✨ Highlights\n\n'
if HL="$(ai_highlights)"; then
  printf '%s\n\n' "$HL"
else
  printf '_AI summary unavailable — see full changelog below._\n\n'
fi
printf '%s\n' "$FACTS"
