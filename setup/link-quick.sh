#!/usr/bin/env bash
# link-quick.sh — Register skills for Amazon Quick Desktop
# Usage: ./setup/link-quick.sh
#
# Creates symlinks from doc-skills/quick/* to:
#   ~/.quickwork/profiles/federate-prod/skills/{name}
#
# Also creates inner symlinks for scripts/ that Quick needs bundled.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
QUICK_DIR="$REPO_ROOT/quick"
SCRIPTS_DIR="$REPO_ROOT/scripts"

QUICK_SKILLS="$HOME/.quickwork/profiles/federate-prod/skills"

# Ensure target directory exists
mkdir -p "$QUICK_SKILLS"

echo "🔗 Linking skills for Amazon Quick..."
echo "   Source: $QUICK_DIR"
echo ""

for skill_dir in "$QUICK_DIR"/*/; do
    [ -d "$skill_dir" ] || continue
    name="$(basename "$skill_dir")"

    target="$QUICK_SKILLS/$name"
    if [ -L "$target" ]; then
        rm "$target"
    elif [ -d "$target" ]; then
        echo "   ⚠️  $name exists (not a symlink) — backing up"
        mv "$target" "${target}.bak.$(date +%s)"
    fi
    ln -sf "$skill_dir" "$target"
    echo "   ✅ Quick: $name"
done

echo ""

# Create scripts symlinks inside quick/{name}/scripts/ pointing to central scripts
echo "🔗 Linking scripts for Quick bundling..."

# translate-pptx needs translate_pptx_native.py
TPPTX_SCRIPTS="$QUICK_DIR/translate-pptx/scripts"
mkdir -p "$TPPTX_SCRIPTS"
ln -sf "$SCRIPTS_DIR/translate_pptx_native.py" "$TPPTX_SCRIPTS/translate_pptx_native.py" 2>/dev/null || true
echo "   ✅ translate-pptx/scripts/translate_pptx_native.py"

# md-to-docx needs generate_styled_docx.py
MDOCX_SCRIPTS="$QUICK_DIR/md-to-docx/scripts"
mkdir -p "$MDOCX_SCRIPTS"
ln -sf "$SCRIPTS_DIR/generate_styled_docx.py" "$MDOCX_SCRIPTS/generate_styled_docx.py" 2>/dev/null || true
echo "   ✅ md-to-docx/scripts/generate_styled_docx.py"

# stop-slop needs references/ from skills/ (single source of truth)
STOPSLOP_REFS="$QUICK_DIR/stop-slop/references"
if [ ! -L "$STOPSLOP_REFS" ]; then
    [ -d "$STOPSLOP_REFS" ] && rm -rf "$STOPSLOP_REFS"
    ln -sf "$REPO_ROOT/skills/stop-slop/references" "$STOPSLOP_REFS"
fi
echo "   ✅ stop-slop/references/ (→ skills/stop-slop/references/)"

echo ""
echo "✅ Done! Skills registered at: $QUICK_SKILLS"
echo ""
echo "Verify: ls -la $QUICK_SKILLS/{doc-fact-check,md-to-docx,translate-pptx,stop-slop}"
