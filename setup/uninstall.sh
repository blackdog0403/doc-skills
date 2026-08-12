#!/usr/bin/env bash
# Safely uninstall selected doc-skills targets.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
# shellcheck source=setup/lib.sh
source "$SCRIPT_DIR/lib.sh"

REMOVE_KIRO=false
REMOVE_CLAUDE=false
REMOVE_QUICK=false
REMOVE_CLI=false
REMOVE_VENV=false
ASSUME_YES=false
TARGET_SUPPLIED=false
REMOVED=0
SKIPPED=0
FAILED=0

usage() {
    cat <<'EOF'
Usage: ./setup/uninstall.sh [options]

Options:
  --target kiro|claude|quick|cli|all  Remove one target; may be repeated
  --remove-venv                       Also remove the marked private CLI environment
  --yes                               Skip the confirmation prompt
  -h, --help                          Show this help

Only links and wrappers owned by this repository are removed. Existing backup
paths and unrelated files are preserved. The private environment is removed only
when --remove-venv is supplied and its ownership marker is present.
EOF
}

select_target() {
    case "$1" in
        kiro) REMOVE_KIRO=true ;;
        claude) REMOVE_CLAUDE=true ;;
        quick) REMOVE_QUICK=true ;;
        cli) REMOVE_CLI=true ;;
        all)
            REMOVE_KIRO=true
            REMOVE_CLAUDE=true
            REMOVE_QUICK=true
            REMOVE_CLI=true
            ;;
        *)
            printf 'ERROR: Unknown target: %s\n' "$1" >&2
            return 2
            ;;
    esac
}

interactive_menu() {
    local choice
    cat <<'EOF'

doc-skills uninstaller

  1) Everything (Kiro + Claude Code + Quick Desktop + CLI)
  2) Kiro only
  3) Claude Code only
  4) Amazon Quick Desktop only
  5) CLI tools only
  6) Custom
EOF
    printf 'Choose [1-6]: '
    read -r choice
    case "$choice" in
        1) select_target all ;;
        2) select_target kiro ;;
        3) select_target claude ;;
        4) select_target quick ;;
        5) select_target cli ;;
        6)
            printf 'Enter comma-separated targets (kiro,claude,quick,cli): '
            read -r choice
            local item old_ifs
            old_ifs="$IFS"
            IFS=','
            for item in $choice; do
                item="$(printf '%s' "$item" | tr -d '[:space:]')"
                select_target "$item"
            done
            IFS="$old_ifs"
            ;;
        *)
            printf 'ERROR: Invalid choice: %s\n' "$choice" >&2
            return 2
            ;;
    esac
}

print_plan() {
    printf '\nSelected uninstall targets:\n'
    [ "$REMOVE_KIRO" = true ] && printf '  - Kiro global skills\n'
    [ "$REMOVE_CLAUDE" = true ] && printf '  - Claude Code global skills\n'
    [ "$REMOVE_QUICK" = true ] && printf '  - Amazon Quick Desktop global skills\n'
    [ "$REMOVE_CLI" = true ] && printf '  - CLI wrappers\n'
    if [ "$REMOVE_CLI" = true ] && [ "$REMOVE_VENV" = true ]; then
        printf '  - Marked private CLI environment\n'
    fi
    printf 'Backups and paths not owned by this repository will be preserved.\n'
}

confirm_plan() {
    local answer
    if [ "$ASSUME_YES" = true ]; then
        return 0
    fi
    if [ ! -t 0 ]; then
        printf 'ERROR: Confirmation requires a terminal; pass --yes for non-interactive use.\n' >&2
        return 2
    fi
    printf 'Continue? [y/N]: '
    read -r answer
    case "$answer" in
        y|Y|yes|YES|Yes) return 0 ;;
        *) printf 'Uninstall cancelled.\n'; exit 0 ;;
    esac
}

removed() {
    REMOVED=$((REMOVED + 1))
    printf 'REMOVED: %s\n' "$1"
}

skipped() {
    SKIPPED=$((SKIPPED + 1))
    printf 'SKIPPED: %s\n' "$1"
}

preserved_error() {
    FAILED=$((FAILED + 1))
    printf 'PRESERVED: %s\n' "$1" >&2
}

remove_managed_link() {
    local description="$1"
    local path="$2"
    local expected="$3"
    local actual_canonical expected_canonical

    if [ ! -e "$path" ] && [ ! -L "$path" ]; then
        skipped "$description is not installed"
        return
    fi
    if [ ! -L "$path" ]; then
        preserved_error "$description is not a symlink: $path"
        return
    fi
    if [ ! -e "$path" ]; then
        preserved_error "$description is a broken symlink: $path"
        return
    fi

    actual_canonical="$(canonical_path "$path" 2>/dev/null || true)"
    expected_canonical="$(canonical_path "$expected" 2>/dev/null || true)"
    if [ -z "$actual_canonical" ] || [ "$actual_canonical" != "$expected_canonical" ]; then
        preserved_error "$description points outside this repository: $path"
        return
    fi

    rm "$path"
    removed "$description"
}

remove_agent() {
    local platform="$1"
    local destination_root="$2"
    local skill
    while IFS= read -r skill; do
        [ -n "$skill" ] || continue
        remove_managed_link "$platform $skill" \
            "$destination_root/$skill" "$REPO_ROOT/skills/$skill"
    done < <(list_skill_names "$REPO_ROOT/skills")
    rmdir "$destination_root" 2>/dev/null || true
}

remove_quick() {
    local destination_root="$HOME/.quickwork/profiles/federate-prod/skills"
    local skill
    while IFS= read -r skill; do
        [ -n "$skill" ] || continue
        remove_managed_link "Quick Desktop $skill" \
            "$destination_root/$skill" "$REPO_ROOT/quick/$skill"
    done < <(list_skill_names "$REPO_ROOT/quick")
    rmdir "$destination_root" 2>/dev/null || true
}

is_managed_wrapper() {
    local path="$1"
    local script="$2"

    if [ -L "$path" ]; then
        [ -e "$path" ] || return 1
        [ "$(canonical_path "$path" 2>/dev/null || true)" = \
          "$(canonical_path "$script" 2>/dev/null || true)" ]
        return
    fi

    [ -f "$path" ] || return 1
    [ "$(head -n 1 "$path")" = '#!/usr/bin/env bash' ] || return 1
    grep -Fq "$script" "$path" || return 1
    grep -Fq 'exec ' "$path" || return 1
    grep -Fq '"$@"' "$path" || return 1
}

remove_wrapper() {
    local name="$1"
    local script="$2"
    local path="${DOC_SKILLS_BIN_DIR:-$HOME/.local/bin}/$name"

    if [ ! -e "$path" ] && [ ! -L "$path" ]; then
        skipped "$name is not installed"
        return
    fi
    if ! is_managed_wrapper "$path" "$script"; then
        preserved_error "$name is not recognized as a doc-skills wrapper: $path"
        return
    fi
    rm "$path"
    removed "$name"
}

legacy_venv_is_managed() {
    local bin_root="$1"
    local venv_root="$2"
    local name script path

    for name in generate_styled_docx.py translate_pptx_native.py translate_pptx.py; do
        case "$name" in
            generate_styled_docx.py) script="$REPO_ROOT/scripts/generate_styled_docx.py" ;;
            translate_pptx_native.py) script="$REPO_ROOT/scripts/translate_pptx_native.py" ;;
            translate_pptx.py) script="$REPO_ROOT/scripts/translate_pptx_cli.py" ;;
        esac
        path="$bin_root/$name"
        is_managed_wrapper "$path" "$script" || return 1
        [ ! -L "$path" ] || return 1
        grep -Fq "$venv_root/bin/python" "$path" || return 1
    done
}

remove_cli() {
    local bin_root="${DOC_SKILLS_BIN_DIR:-$HOME/.local/bin}"
    local venv_root="${DOC_SKILLS_VENV_DIR:-$HOME/.local/share/doc-skills-venv}"
    local marker="$venv_root/.doc-skills-managed"
    local venv_owned=false

    if [ -f "$marker" ] && grep -Fqx 'managed-by=doc-skills' "$marker"; then
        venv_owned=true
    elif [ -d "$venv_root" ] && legacy_venv_is_managed "$bin_root" "$venv_root"; then
        venv_owned=true
    fi

    remove_wrapper generate_styled_docx.py "$REPO_ROOT/scripts/generate_styled_docx.py"
    remove_wrapper translate_pptx_native.py "$REPO_ROOT/scripts/translate_pptx_native.py"
    remove_wrapper translate_pptx.py "$REPO_ROOT/scripts/translate_pptx_cli.py"
    rmdir "$bin_root" 2>/dev/null || true

    if [ "$REMOVE_VENV" = true ]; then
        if [ ! -e "$venv_root" ]; then
            skipped 'private CLI environment is not installed'
        elif [ "$venv_owned" = true ]; then
            rm -rf "$venv_root"
            removed 'private CLI environment'
        else
            preserved_error "private CLI environment has no verified doc-skills ownership: $venv_root"
        fi
    fi
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --target)
            [ "$#" -ge 2 ] || { printf 'ERROR: --target requires a value.\n' >&2; exit 2; }
            TARGET_SUPPLIED=true
            select_target "$2"
            shift 2
            ;;
        --remove-venv)
            REMOVE_VENV=true
            shift
            ;;
        --yes)
            ASSUME_YES=true
            shift
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
    interactive_menu
fi
if [ "$REMOVE_KIRO" = false ] && [ "$REMOVE_CLAUDE" = false ] \
    && [ "$REMOVE_QUICK" = false ] && [ "$REMOVE_CLI" = false ]; then
    printf 'ERROR: No uninstall target selected.\n' >&2
    exit 2
fi
if [ "$REMOVE_VENV" = true ] && [ "$REMOVE_CLI" = false ]; then
    printf 'ERROR: --remove-venv requires --target cli or --target all.\n' >&2
    exit 2
fi

print_plan
confirm_plan

if [ "$REMOVE_KIRO" = true ]; then
    remove_agent Kiro "$HOME/.kiro/skills"
fi
if [ "$REMOVE_CLAUDE" = true ]; then
    remove_agent 'Claude Code' "$HOME/.claude/skills"
fi
if [ "$REMOVE_QUICK" = true ]; then
    remove_quick
fi
if [ "$REMOVE_CLI" = true ]; then
    remove_cli
fi

printf '\nUninstall results: %s removed, %s skipped, %s preserved with warnings\n' \
    "$REMOVED" "$SKIPPED" "$FAILED"
if [ "$FAILED" -gt 0 ]; then
    exit 1
fi
