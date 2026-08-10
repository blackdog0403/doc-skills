#!/usr/bin/env bash
# Register doc-skills globally for both Kiro and Claude Code.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
# shellcheck source=setup/lib.sh
source "$SCRIPT_DIR/lib.sh"

SOURCE_ROOT="$REPO_ROOT/skills"

printf 'Preparing agent runtime helpers...\n'
prepare_agent_runtime_links "$REPO_ROOT"
printf 'Linking doc-skills for Kiro and Claude Code...\n'
link_skill_tree "$SOURCE_ROOT" "$HOME/.kiro/skills" "Kiro"
link_skill_tree "$SOURCE_ROOT" "$HOME/.claude/skills" "Claude Code"
printf 'Done. Verify with: %s/test-setup.sh --target kiro --target claude\n' "$SCRIPT_DIR"
