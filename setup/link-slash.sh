#!/usr/bin/env bash
# link-slash.sh — Register skills for Kiro + Claude Code (slash commands)
# Usage: ./setup/link-slash.sh
#
# Creates symlinks from doc-skills/skills/* to:
#   ~/.kiro/skills/{name}
#   ~/.claude/skills/{name}

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
SKILLS_DIR="$REPO_ROOT/skills"

KIRO_SKILLS="$HOME/.kiro/skills"
CLAUDE_SKILLS="$HOME/.claude/skills"

# Ensure target directories exist
mkdir -p "$KIRO_SKILLS"
mkdir -p "$CLAUDE_SKILLS"

echo "🔗 Linking skills for Kiro + Claude Code..."
echo "   Source: $SKILLS_DIR"
echo ""

for skill_dir in "$SKILLS_DIR"/*/; do
    [ -d "$skill_dir" ] || continue
    name="$(basename "$skill_dir")"

    # Kiro
    target="$KIRO_SKILLS/$name"
    if [ -L "$target" ]; then
        rm "$target"
    elif [ -d "$target" ]; then
        echo "   ⚠️  Kiro: $name exists (not a symlink) — backing up"
        mv "$target" "${target}.bak.$(date +%s)"
    fi
    ln -sf "$skill_dir" "$target"
    echo "   ✅ Kiro:  /$(basename "$target")"

    # Claude Code
    target="$CLAUDE_SKILLS/$name"
    if [ -L "$target" ]; then
        rm "$target"
    elif [ -d "$target" ]; then
        echo "   ⚠️  Claude: $name exists (not a symlink) — backing up"
        mv "$target" "${target}.bak.$(date +%s)"
    fi
    ln -sf "$skill_dir" "$target"
    echo "   ✅ Claude: /$(basename "$target")"

    echo ""
done

echo "✅ Done! Skills registered:"
echo "   Kiro:   $KIRO_SKILLS"
echo "   Claude: $CLAUDE_SKILLS"
echo ""
echo "Test with: /doc-fact-check, /md-to-docx, /translate-pptx"
