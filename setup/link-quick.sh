#!/usr/bin/env bash
# Register doc-skills for Amazon Quick Desktop.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
# shellcheck source=setup/lib.sh
source "$SCRIPT_DIR/lib.sh"

QUICK_DIR="$REPO_ROOT/quick"
SCRIPTS_DIR="$REPO_ROOT/scripts"
DESTINATION_ROOT="$HOME/.quickwork/profiles/federate-prod/skills"

printf 'Preparing Quick runtime helpers...\n'
safe_link "$SCRIPTS_DIR/translate_pptx_native.py" \
    "$QUICK_DIR/translate-pptx/scripts/translate_pptx_native.py" \
    'Quick translate-pptx helper'
safe_link "$SCRIPTS_DIR/generate_styled_docx.py" \
    "$QUICK_DIR/md-to-docx/scripts/generate_styled_docx.py" \
    'Quick md-to-docx helper'
safe_link "$REPO_ROOT/skills/stop-slop/references" \
    "$QUICK_DIR/stop-slop/references" \
    'Quick stop-slop references'

printf 'Linking doc-skills for Amazon Quick Desktop...\n'
link_skill_tree "$QUICK_DIR" "$DESTINATION_ROOT" "Quick Desktop"
printf 'Done. Verify with: %s/test-setup.sh --target quick\n' "$SCRIPT_DIR"
