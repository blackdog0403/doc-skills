#!/usr/bin/env bash
# build-release.sh — Build ZIP release artifacts for Amazon Quick Desktop skills
# Usage: ./scripts/build-release.sh [version]
#
# Generates individual skill ZIPs + an all-in-one ZIP.
# Output goes to dist/ directory.
#
# Each ZIP contains the skill folder ready to drop into:
#   Mac:     ~/.quickwork/profiles/federate-prod/skills/
#   Windows: %USERPROFILE%\.quickwork\profiles\federate-prod\skills\

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
QUICK_DIR="$REPO_ROOT/quick"
SKILLS_DIR="$REPO_ROOT/skills"
SCRIPTS_DIR="$REPO_ROOT/scripts"
DIST_DIR="$REPO_ROOT/dist"
INSTALL_GUIDE="$REPO_ROOT/docs/INSTALL-QUICK.md"
VERSION="${1:-$(date +%Y%m%d)}"

# Ensure script-bundling symlinks exist (CI checkout doesn't have them).
# These are normally created by setup/link-quick.sh; the build needs them
# present so cp -L can resolve into the staging area. Skip if already linked
# (e.g., quick/stop-slop/references is committed as a relative symlink).
ensure_link() {
    local target="$1" link="$2"
    [ -e "$link" ] && return 0   # already exists (real or symlink); leave alone
    mkdir -p "$(dirname "$link")"
    ln -s "$target" "$link"
}
# Use absolute paths only for install-time links (gitignored, build-only)
ensure_link "$SCRIPTS_DIR/generate_styled_docx.py"  "$QUICK_DIR/md-to-docx/scripts/generate_styled_docx.py"
ensure_link "$SCRIPTS_DIR/translate_pptx_native.py" "$QUICK_DIR/translate-pptx/scripts/translate_pptx_native.py"

# Clean and recreate dist/
rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

echo "📦 Building release artifacts (v$VERSION)..."
echo "   Source: $QUICK_DIR"
echo "   Output: $DIST_DIR"
echo ""

# Temporary staging area
STAGING="$(mktemp -d)"
trap "rm -rf $STAGING" EXIT

# Build individual skill ZIPs
for skill_dir in "$QUICK_DIR"/*/; do
    [ -d "$skill_dir" ] || continue
    name="$(basename "$skill_dir")"

    echo "   📁 Packaging: $name"

    # Create staging copy (resolves symlinks)
    skill_staging="$STAGING/$name"
    mkdir -p "$skill_staging"

    # Copy SKILL.md
    cp "$skill_dir/SKILL.md" "$skill_staging/"

    # Copy references/ if it exists (resolve symlinks)
    if [ -d "$skill_dir/references" ] || [ -L "$skill_dir/references" ]; then
        cp -rL "$skill_dir/references" "$skill_staging/"
    fi

    # Copy scripts/ if it exists (resolve symlinks)
    if [ -d "$skill_dir/scripts" ] || [ -L "$skill_dir/scripts" ]; then
        cp -rL "$skill_dir/scripts" "$skill_staging/"
    fi

    # Include install guide for non-technical users
    if [ -f "$INSTALL_GUIDE" ]; then
        cp "$INSTALL_GUIDE" "$skill_staging/INSTALL.md"
    fi

    # Create individual ZIP
    (cd "$STAGING" && zip -rq "$DIST_DIR/${name}-quick-v${VERSION}.zip" "$name/")
    echo "      ✅ ${name}-quick-v${VERSION}.zip"
done

echo ""

# Build all-in-one ZIP — copy each staged skill folder as a sibling under doc-skills-all/
echo "   📦 Packaging: all-in-one"
ALL_STAGING="$STAGING/doc-skills-all"
mkdir -p "$ALL_STAGING"

for skill_dir in "$STAGING"/*/; do
    [ -d "$skill_dir" ] || continue
    name="$(basename "$skill_dir")"
    [ "$name" = "doc-skills-all" ] && continue
    # Strip the per-skill INSTALL.md so the all-in-one carries one top-level guide
    rm -f "$skill_dir/INSTALL.md"
    cp -r "$skill_dir" "$ALL_STAGING/$name"
done

# Top-level install guide for the bundle
if [ -f "$INSTALL_GUIDE" ]; then
    cp "$INSTALL_GUIDE" "$ALL_STAGING/INSTALL.md"
fi

(cd "$STAGING" && zip -rq "$DIST_DIR/doc-skills-all-quick-v${VERSION}.zip" "doc-skills-all/")
echo "      ✅ doc-skills-all-quick-v${VERSION}.zip"

echo ""
echo "✅ Release artifacts ready in: $DIST_DIR/"
echo ""
ls -lh "$DIST_DIR/"
