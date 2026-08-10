#!/usr/bin/env bash
# Register doc-skills globally for Claude Code only.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
# shellcheck source=setup/lib.sh
source "$SCRIPT_DIR/lib.sh"

SOURCE_ROOT="$REPO_ROOT/skills"
DESTINATION_ROOT="$HOME/.claude/skills"

printf 'Preparing Claude Code runtime helpers...\n'
prepare_agent_runtime_links "$REPO_ROOT"
printf 'Linking doc-skills for Claude Code...\n'
link_skill_tree "$SOURCE_ROOT" "$DESTINATION_ROOT" "Claude Code"
printf 'Done. Verify with: %s/test-setup.sh --target claude\n' "$SCRIPT_DIR"
