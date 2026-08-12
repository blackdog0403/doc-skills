#!/usr/bin/env bash
# Install standalone doc-skills CLI wrappers and their private Python environment.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
# shellcheck source=setup/lib.sh
source "$SCRIPT_DIR/lib.sh"

BIN_DIR="${DOC_SKILLS_BIN_DIR:-$HOME/.local/bin}"
VENV_DIR="${DOC_SKILLS_VENV_DIR:-$HOME/.local/share/doc-skills-venv}"
SKIP_DEPENDENCIES=false

usage() {
    cat <<'EOF'
Usage: ./setup/install-cli.sh [--skip-dependencies]

By default, this creates a private virtual environment, installs requirements.txt,
and writes portable wrappers to ~/.local/bin. Use --skip-dependencies for offline
or installer-regression testing; wrappers then use the current python3.
EOF
}

python_version_supported() {
    python3 -c 'import sys; raise SystemExit(0 if sys.version_info >= (3, 9) else 1)'
}

while [ "$#" -gt 0 ]; do
    case "$1" in
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

if ! command -v python3 >/dev/null 2>&1; then
    printf 'ERROR: python3 is required.\n' >&2
    exit 1
fi
if ! python_version_supported; then
    printf 'ERROR: Python 3.9 or newer is required. Found: %s\n' "$(python3 --version 2>&1)" >&2
    exit 1
fi

if [ "$SKIP_DEPENDENCIES" = true ]; then
    RUNTIME_PYTHON="$(command -v python3)"
    printf 'Skipping dependency installation; wrappers will use %s\n' "$RUNTIME_PYTHON"
else
    printf 'Creating private Python environment at %s\n' "$VENV_DIR"
    python3 -m venv "$VENV_DIR"
    "$VENV_DIR/bin/python" -m pip install --disable-pip-version-check -r "$REPO_ROOT/requirements.txt"
    printf 'managed-by=doc-skills\nsource=%s\n' "$REPO_ROOT" > "$VENV_DIR/.doc-skills-managed"
    RUNTIME_PYTHON="$VENV_DIR/bin/python"
fi

create_wrapper() {
    local name="$1"
    local script="$2"
    local destination="$BIN_DIR/$name"
    local temporary

    if [ ! -f "$script" ]; then
        printf 'ERROR: CLI source is missing: %s\n' "$script" >&2
        return 1
    fi

    temporary="$(mktemp "${TMPDIR:-/tmp}/doc-skills-wrapper.XXXXXX")"
    printf '#!/usr/bin/env bash\n# Managed by doc-skills installer\nexec %q %q "$@"\n' "$RUNTIME_PYTHON" "$script" > "$temporary"
    safe_install_file "$temporary" "$destination" "$name"
}

printf 'Installing doc-skills CLI wrappers in %s\n' "$BIN_DIR"
create_wrapper generate_styled_docx.py "$REPO_ROOT/scripts/generate_styled_docx.py"
create_wrapper translate_pptx_native.py "$REPO_ROOT/scripts/translate_pptx_native.py"
create_wrapper translate_pptx.py "$REPO_ROOT/scripts/translate_pptx_cli.py"

printf 'CLI installation complete.\n'
if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
    printf 'Add this line to your shell configuration: export PATH="%s:$PATH"\n' "$BIN_DIR"
fi
printf 'Verify with: %s/test-setup.sh --target cli\n' "$SCRIPT_DIR"
