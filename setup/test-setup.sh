#!/usr/bin/env bash
# Verify selected doc-skills installation targets.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
# shellcheck source=setup/lib.sh
source "$SCRIPT_DIR/lib.sh"

CHECK_KIRO=false
CHECK_CLAUDE=false
CHECK_QUICK=false
CHECK_CLI=false
TARGET_SUPPLIED=false
PASS=0
FAIL=0

usage() {
    cat <<'EOF'
Usage: ./setup/test-setup.sh [--target kiro|claude|quick|cli|all]...

With no target, all targets are checked. The command exits nonzero if any selected
check fails.
EOF
}

select_target() {
    case "$1" in
        kiro) CHECK_KIRO=true ;;
        claude) CHECK_CLAUDE=true ;;
        quick) CHECK_QUICK=true ;;
        cli) CHECK_CLI=true ;;
        all)
            CHECK_KIRO=true
            CHECK_CLAUDE=true
            CHECK_QUICK=true
            CHECK_CLI=true
            ;;
        *)
            printf 'ERROR: Unknown target: %s\n' "$1" >&2
            return 2
            ;;
    esac
}

pass() {
    PASS=$((PASS + 1))
    printf 'PASS: %s\n' "$1"
}

fail() {
    FAIL=$((FAIL + 1))
    printf 'FAIL: %s\n' "$1" >&2
}

check_link() {
    local description="$1"
    local path="$2"
    local expected="$3"
    local actual actual_path actual_canonical expected_canonical

    if [ ! -L "$path" ]; then
        fail "$description is not a symlink: $path"
        return
    fi
    if [ ! -e "$path" ]; then
        fail "$description is a broken symlink: $path"
        return
    fi

    actual="$(readlink "$path")"
    case "$actual" in
        /*) actual_path="$actual" ;;
        *) actual_path="$(dirname "$path")/$actual" ;;
    esac
    actual_canonical="$(canonical_path "$actual_path" 2>/dev/null || true)"
    expected_canonical="$(canonical_path "$expected" 2>/dev/null || true)"
    if [ -z "$actual_canonical" ] || [ "$actual_canonical" != "$expected_canonical" ]; then
        fail "$description resolves to ${actual_canonical:-unknown} instead of ${expected_canonical:-$expected}"
        return
    fi
    pass "$description"
}

check_file() {
    local description="$1"
    local path="$2"
    if [ -f "$path" ]; then
        pass "$description"
    else
        fail "$description is missing: $path"
    fi
}

check_executable() {
    local description="$1"
    local path="$2"
    if [ -f "$path" ] && [ -x "$path" ]; then
        pass "$description"
    else
        fail "$description is missing or not executable: $path"
    fi
}

check_agent() {
    local platform="$1"
    local destination_root="$2"
    local skill expected

    printf '\nChecking %s\n' "$platform"
    while IFS= read -r skill; do
        [ -n "$skill" ] || continue
        expected="$REPO_ROOT/skills/$skill"
        check_link "$platform $skill" "$destination_root/$skill" "$expected"
        check_file "$platform $skill SKILL.md" "$destination_root/$skill/SKILL.md"
    done < <(list_skill_names "$REPO_ROOT/skills")
    check_executable "$platform md-to-docx bundled helper" \
        "$destination_root/md-to-docx/scripts/generate_styled_docx.py"
    check_executable "$platform translate-pptx bundled helper" \
        "$destination_root/translate-pptx/scripts/translate_pptx_native.py"
}

check_quick() {
    local root="$HOME/.quickwork/profiles/federate-prod/skills"
    local skill expected

    printf '\nChecking Amazon Quick Desktop\n'
    while IFS= read -r skill; do
        [ -n "$skill" ] || continue
        expected="$REPO_ROOT/quick/$skill"
        check_link "Quick Desktop $skill" "$root/$skill" "$expected"
        check_file "Quick Desktop $skill SKILL.md" "$root/$skill/SKILL.md"
    done < <(list_skill_names "$REPO_ROOT/quick")
    check_executable 'Quick md-to-docx bundled helper' \
        "$root/md-to-docx/scripts/generate_styled_docx.py"
    check_executable 'Quick translate-pptx bundled helper' \
        "$root/translate-pptx/scripts/translate_pptx_native.py"
    check_link 'Quick stop-slop references' \
        "$root/stop-slop/references" "$REPO_ROOT/skills/stop-slop/references"
}

check_cli() {
    local root="${DOC_SKILLS_BIN_DIR:-$HOME/.local/bin}"
    printf '\nChecking CLI tools\n'
    check_executable 'generate_styled_docx.py wrapper' "$root/generate_styled_docx.py"
    check_executable 'translate_pptx_native.py wrapper' "$root/translate_pptx_native.py"
    check_executable 'translate_pptx.py wrapper' "$root/translate_pptx.py"
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --target)
            [ "$#" -ge 2 ] || { printf 'ERROR: --target requires a value.\n' >&2; exit 2; }
            TARGET_SUPPLIED=true
            select_target "$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            printf 'ERROR: Unknown option: %s\n' "$1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

if [ "$TARGET_SUPPLIED" = false ]; then
    select_target all
fi

if [ "$CHECK_KIRO" = true ]; then
    check_agent Kiro "$HOME/.kiro/skills"
fi
if [ "$CHECK_CLAUDE" = true ]; then
    check_agent 'Claude Code' "$HOME/.claude/skills"
fi
if [ "$CHECK_QUICK" = true ]; then
    check_quick
fi
if [ "$CHECK_CLI" = true ]; then
    check_cli
fi

printf '\nResults: %s passed, %s failed\n' "$PASS" "$FAIL"
if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
printf 'All selected installation checks passed.\n'
