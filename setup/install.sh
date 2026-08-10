#!/usr/bin/env bash
# Interactive or non-interactive installer for doc-skills.
# Examples:
#   ./setup/install.sh
#   ./setup/install.sh --target kiro
#   ./setup/install.sh --target kiro --target cli

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
# shellcheck source=setup/lib.sh
source "$SCRIPT_DIR/lib.sh"

SKILLS_DIR="$REPO_ROOT/skills"

INSTALL_KIRO=false
INSTALL_CLAUDE=false
INSTALL_QUICK=false
INSTALL_CLI=false
SKIP_DEPENDENCIES=false
TARGET_SUPPLIED=false

usage() {
    cat <<'EOF'
Usage: ./setup/install.sh [options]

Options:
  --target kiro|claude|quick|cli|all  Install one target; may be repeated
  --skip-dependencies                Do not create/update the CLI virtual environment
  -h, --help                         Show this help

With no --target option, an interactive menu is shown.
EOF
}

select_target() {
    case "$1" in
        kiro) INSTALL_KIRO=true ;;
        claude) INSTALL_CLAUDE=true ;;
        quick) INSTALL_QUICK=true ;;
        cli) INSTALL_CLI=true ;;
        all)
            INSTALL_KIRO=true
            INSTALL_CLAUDE=true
            INSTALL_QUICK=true
            INSTALL_CLI=true
            ;;
        *)
            printf 'ERROR: Unknown target: %s\n' "$1" >&2
            usage >&2
            return 2
            ;;
    esac
}

ask_yes_no() {
    local prompt="$1"
    local default="${2:-y}"
    local answer
    if [ "$default" = "y" ]; then
        printf '%s [Y/n]: ' "$prompt"
    else
        printf '%s [y/N]: ' "$prompt"
    fi
    read -r answer
    answer="${answer:-$default}"
    case "$answer" in
        y|Y|yes|YES|Yes) return 0 ;;
        *) return 1 ;;
    esac
}

interactive_menu() {
    local choice
    cat <<'EOF'

doc-skills installer

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
            ask_yes_no 'Install for Kiro?' y && INSTALL_KIRO=true
            ask_yes_no 'Install for Claude Code?' n && INSTALL_CLAUDE=true
            ask_yes_no 'Install for Amazon Quick Desktop?' n && INSTALL_QUICK=true
            ask_yes_no 'Install standalone CLI tools?' n && INSTALL_CLI=true
            ;;
        *)
            printf 'ERROR: Invalid choice: %s\n' "$choice" >&2
            return 2
            ;;
    esac
}

python_version_supported() {
    local version major minor
    version="$(python3 -c 'import sys; print("%s.%s" % sys.version_info[:2])')"
    major="${version%%.*}"
    minor="${version#*.}"
    [ "$major" -gt 3 ] || { [ "$major" -eq 3 ] && [ "$minor" -ge 9 ]; }
}

check_module() {
    local module="$1"
    local purpose="$2"
    if python3 -c "import $module" >/dev/null 2>&1; then
        printf 'PASS: Python module %s is available\n' "$module"
    else
        printf 'WARNING: Python module %s is missing (%s)\n' "$module" "$purpose"
    fi
}

preflight_check() {
    local needs_runtime=false
    if [ "$INSTALL_KIRO" = true ] || [ "$INSTALL_CLAUDE" = true ] || [ "$INSTALL_CLI" = true ]; then
        needs_runtime=true
    fi

    printf '\nPreflight checks\n'
    if [ "$needs_runtime" = true ]; then
        if ! command -v python3 >/dev/null 2>&1; then
            if [ "$INSTALL_CLI" = true ]; then
                printf 'ERROR: Python 3 is required for CLI installation.\n' >&2
                return 1
            fi
            printf 'WARNING: Python 3 is missing; document conversion helpers will be unavailable.\n'
        elif ! python_version_supported; then
            if [ "$INSTALL_CLI" = true ]; then
                printf 'ERROR: Python 3.9 or newer is required for CLI installation.\n' >&2
                return 1
            fi
            printf 'WARNING: Python 3.9 or newer is recommended for runtime helpers.\n'
        else
            printf 'PASS: %s\n' "$(python3 --version 2>&1)"
            if [ "$INSTALL_KIRO" = true ] || [ "$INSTALL_CLAUDE" = true ]; then
                check_module docx 'required by md-to-docx'
                check_module pptx 'required by translate-pptx'
            fi
        fi
    else
        printf 'PASS: Selected target does not require local Python.\n'
    fi

    if command -v git >/dev/null 2>&1; then
        printf 'INFO: %s\n' "$(git --version)"
    else
        printf 'INFO: Git is not required when installing from this local checkout.\n'
    fi
}

install_selected_targets() {
    if [ "$INSTALL_KIRO" = true ] || [ "$INSTALL_CLAUDE" = true ]; then
        printf '\nPreparing agent runtime helpers\n'
        prepare_agent_runtime_links "$REPO_ROOT"
    fi
    if [ "$INSTALL_KIRO" = true ]; then
        printf '\nInstalling Kiro skills\n'
        link_skill_tree "$SKILLS_DIR" "$HOME/.kiro/skills" "Kiro"
    fi
    if [ "$INSTALL_CLAUDE" = true ]; then
        printf '\nInstalling Claude Code skills\n'
        link_skill_tree "$SKILLS_DIR" "$HOME/.claude/skills" "Claude Code"
    fi
    if [ "$INSTALL_QUICK" = true ]; then
        printf '\nInstalling Amazon Quick Desktop skills\n'
        "$SCRIPT_DIR/link-quick.sh"
    fi
    if [ "$INSTALL_CLI" = true ]; then
        printf '\nInstalling CLI tools\n'
        if [ "$SKIP_DEPENDENCIES" = true ]; then
            "$SCRIPT_DIR/install-cli.sh" --skip-dependencies
        else
            "$SCRIPT_DIR/install-cli.sh"
        fi
    fi
}

verify_selected_targets() {
    local args=()
    [ "$INSTALL_KIRO" = true ] && args+=(--target kiro)
    [ "$INSTALL_CLAUDE" = true ] && args+=(--target claude)
    [ "$INSTALL_QUICK" = true ] && args+=(--target quick)
    [ "$INSTALL_CLI" = true ] && args+=(--target cli)
    "$SCRIPT_DIR/test-setup.sh" "${args[@]}"
}

print_summary() {
    printf '\nInstallation complete.\n'
    [ "$INSTALL_KIRO" = true ] && printf '  Kiro: %s\n' "$HOME/.kiro/skills"
    [ "$INSTALL_CLAUDE" = true ] && printf '  Claude Code: %s\n' "$HOME/.claude/skills"
    [ "$INSTALL_QUICK" = true ] && printf '  Quick Desktop: %s\n' "$HOME/.quickwork/profiles/federate-prod/skills"
    [ "$INSTALL_CLI" = true ] && printf '  CLI tools: %s\n' "$HOME/.local/bin"
    printf 'Example requests: fact check this document; convert markdown to DOCX; translate this presentation.\n'
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --target)
            [ "$#" -ge 2 ] || { printf 'ERROR: --target requires a value.\n' >&2; exit 2; }
            TARGET_SUPPLIED=true
            select_target "$2"
            shift 2
            ;;
        --skip-dependencies)
            SKIP_DEPENDENCIES=true
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

if [ "$INSTALL_KIRO" = false ] && [ "$INSTALL_CLAUDE" = false ] \
    && [ "$INSTALL_QUICK" = false ] && [ "$INSTALL_CLI" = false ]; then
    printf 'ERROR: No installation target selected.\n' >&2
    exit 2
fi

preflight_check
install_selected_targets
verify_selected_targets
print_summary
