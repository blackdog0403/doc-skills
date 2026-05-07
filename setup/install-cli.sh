#!/usr/bin/env bash
# install-cli.sh — Install standalone CLI scripts to ~/.local/bin/
# Usage: ./setup/install-cli.sh
#
# Creates symlinks for scripts that can run as standalone CLI tools.
# These scripts typically need boto3 or other deps not available in sandboxes.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
SCRIPTS_DIR="$REPO_ROOT/scripts"

BIN_DIR="$HOME/.local/bin"
mkdir -p "$BIN_DIR"

echo "🔗 Installing CLI scripts to $BIN_DIR..."
echo ""

# translate_pptx_cli.py → translate_pptx.py
SRC="$SCRIPTS_DIR/translate_pptx_cli.py"
DST="$BIN_DIR/translate_pptx.py"
if [ -L "$DST" ]; then
    rm "$DST"
elif [ -f "$DST" ]; then
    echo "   ⚠️  $DST exists (not a symlink) — backing up"
    mv "$DST" "${DST}.bak.$(date +%s)"
fi
ln -sf "$SRC" "$DST"
echo "   ✅ translate_pptx.py → $SRC"

# generate_styled_docx.py
SRC="$SCRIPTS_DIR/generate_styled_docx.py"
DST="$BIN_DIR/generate_styled_docx.py"
if [ -L "$DST" ]; then
    rm "$DST"
elif [ -f "$DST" ]; then
    echo "   ⚠️  $DST exists (not a symlink) — backing up"
    mv "$DST" "${DST}.bak.$(date +%s)"
fi
ln -sf "$SRC" "$DST"
echo "   ✅ generate_styled_docx.py → $SRC"

echo ""
echo "✅ Done! Ensure $BIN_DIR is in your PATH."
echo "   Add to ~/.zshrc if not already: export PATH=\"\$HOME/.local/bin:\$PATH\""
