#!/usr/bin/env bash
# Register doc-skills globally for Kiro only.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
# shellcheck source=setup/lib.sh
source "$SCRIPT_DIR/lib.sh"

SOURCE_ROOT="$REPO_ROOT/skills"
DESTINATION_ROOT="$HOME/.kiro/skills"

printf 'Preparing Kiro runtime helpers...\n'
prepare_agent_runtime_links "$REPO_ROOT"
printf 'Linking doc-skills for Kiro...\n'
link_skill_tree "$SOURCE_ROOT" "$DESTINATION_ROOT" "Kiro"
printf 'Done. Verify with: %s/test-setup.sh --target kiro\n' "$SCRIPT_DIR"
