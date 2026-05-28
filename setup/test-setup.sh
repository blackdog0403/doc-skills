#!/usr/bin/env bash
# test-setup.sh — Verify installation is correct
# Usage: ./setup/test-setup.sh
#
# Checks that all symlinks are in place and scripts are importable.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

echo "🧪 Testing doc-skills installation..."
echo ""

PASS=0
FAIL=0

check() {
    local desc="$1"
    local path="$2"
    if [ -L "$path" ] || [ -f "$path" ] || [ -d "$path" ]; then
        echo "  ✅ $desc"
        PASS=$((PASS+1))
    else
        echo "  ❌ $desc — NOT FOUND: $path"
        FAIL=$((FAIL+1))
    fi
}

echo "── Kiro Skills ──"
check "/doc-fact-check" "$HOME/.kiro/skills/doc-fact-check"
check "/md-to-docx" "$HOME/.kiro/skills/md-to-docx"
check "/translate-pptx" "$HOME/.kiro/skills/translate-pptx"
check "/stop-slop" "$HOME/.kiro/skills/stop-slop"

echo ""
echo "── Claude Code Skills ──"
check "/doc-fact-check" "$HOME/.claude/skills/doc-fact-check"
check "/md-to-docx" "$HOME/.claude/skills/md-to-docx"
check "/translate-pptx" "$HOME/.claude/skills/translate-pptx"
check "/stop-slop" "$HOME/.claude/skills/stop-slop"

echo ""
echo "── Amazon Quick Desktop Skills ──"
check "doc-fact-check" "$HOME/.quickwork/profiles/federate-prod/skills/doc-fact-check"
check "md-to-docx" "$HOME/.quickwork/profiles/federate-prod/skills/md-to-docx"
check "translate-pptx" "$HOME/.quickwork/profiles/federate-prod/skills/translate-pptx"
check "stop-slop" "$HOME/.quickwork/profiles/federate-prod/skills/stop-slop"
check "stop-slop/references" "$HOME/.quickwork/profiles/federate-prod/skills/stop-slop/references"

echo ""
echo "── CLI Scripts ──"
check "generate_styled_docx.py" "$HOME/.local/bin/generate_styled_docx.py"
check "translate_pptx.py" "$HOME/.local/bin/translate_pptx.py"

echo ""
echo "── Python Import Test ──"
if python3 -c "import ast; ast.parse(open('$REPO_ROOT/scripts/generate_styled_docx.py').read())" 2>/dev/null; then
    echo "  ✅ generate_styled_docx.py — valid syntax"
    PASS=$((PASS+1))
else
    echo "  ❌ generate_styled_docx.py — syntax error"
    FAIL=$((FAIL+1))
fi

if python3 -c "import ast; ast.parse(open('$REPO_ROOT/scripts/translate_pptx_native.py').read())" 2>/dev/null; then
    echo "  ✅ translate_pptx_native.py — valid syntax"
    PASS=$((PASS+1))
else
    echo "  ❌ translate_pptx_native.py — syntax error"
    FAIL=$((FAIL+1))
fi

if python3 -c "import ast; ast.parse(open('$REPO_ROOT/scripts/translate_pptx_cli.py').read())" 2>/dev/null; then
    echo "  ✅ translate_pptx_cli.py — valid syntax"
    PASS=$((PASS+1))
else
    echo "  ❌ translate_pptx_cli.py — syntax error"
    FAIL=$((FAIL+1))
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Results: $PASS passed, $FAIL failed"
if [ "$FAIL" -eq 0 ]; then
    echo "  🎉 All checks passed!"
else
    echo "  ⚠️  Some checks failed — run the relevant setup script."
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━"
