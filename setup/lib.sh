#!/usr/bin/env bash
# Shared helpers for doc-skills installers.


canonical_path() {
    local path="$1"
    local directory base

    if command -v realpath >/dev/null 2>&1; then
        realpath "$path"
        return
    fi

    directory="$(dirname "$path")"
    base="$(basename "$path")"
    if [ ! -d "$directory" ]; then
        return 1
    fi
    directory="$(cd "$directory" && pwd -P)"
    printf '%s/%s\n' "$directory" "$base"
}
unique_backup_path() {
    local path="$1"
    local stamp candidate counter
    stamp="$(date +%Y%m%d%H%M%S)"
    candidate="${path}.bak.${stamp}"
    counter=0
    while [ -e "$candidate" ] || [ -L "$candidate" ]; do
        counter=$((counter + 1))
        candidate="${path}.bak.${stamp}.${counter}"
    done
    printf '%s\n' "$candidate"
}

backup_existing_path() {
    local path="$1"
    local label="${2:-$1}"
    local backup

    if [ ! -e "$path" ] && [ ! -L "$path" ]; then
        return 0
    fi

    backup="$(unique_backup_path "$path")"
    mv "$path" "$backup"
    printf '   Backed up %s to %s\n' "$label" "$backup"
}

safe_link() {
    local source="$1"
    local destination="$2"
    local label="${3:-$destination}"
    local current

    if [ ! -e "$source" ] && [ ! -L "$source" ]; then
        printf 'ERROR: Link source does not exist: %s\n' "$source" >&2
        return 1
    fi

    mkdir -p "$(dirname "$destination")"

    if [ -L "$destination" ]; then
        local current_path current_canonical source_canonical
        current="$(readlink "$destination")"
        case "$current" in
            /*) current_path="$current" ;;
            *) current_path="$(dirname "$destination")/$current" ;;
        esac
        current_canonical="$(canonical_path "$current_path" 2>/dev/null || true)"
        source_canonical="$(canonical_path "$source" 2>/dev/null || true)"
        if [ -n "$current_canonical" ] && [ "$current_canonical" = "$source_canonical" ]; then
            printf '   Up to date: %s\n' "$label"
            return 0
        fi
    fi

    backup_existing_path "$destination" "$label"
    ln -s "$source" "$destination"
    printf '   Linked %s -> %s\n' "$label" "$source"
}

safe_install_file() {
    local source="$1"
    local destination="$2"
    local label="${3:-$destination}"

    if [ ! -f "$source" ]; then
        printf 'ERROR: File source does not exist: %s\n' "$source" >&2
        return 1
    fi

    mkdir -p "$(dirname "$destination")"
    if [ -f "$destination" ] && [ ! -L "$destination" ] && cmp -s "$source" "$destination"; then
        rm -f "$source"
        printf '   Up to date: %s\n' "$label"
        return 0
    fi

    backup_existing_path "$destination" "$label"
    mv "$source" "$destination"
    chmod +x "$destination"
    printf '   Installed %s\n' "$label"
}

prepare_agent_runtime_links() {
    local repo_root="$1"
    safe_link "$repo_root/scripts/generate_styled_docx.py" \
        "$repo_root/skills/md-to-docx/scripts/generate_styled_docx.py" \
        'md-to-docx bundled helper'
    safe_link "$repo_root/scripts/translate_pptx_native.py" \
        "$repo_root/skills/translate-pptx/scripts/translate_pptx_native.py" \
        'translate-pptx bundled helper'
}

list_skill_names() {
    local source_root="$1"
    local skill_dir

    if [ ! -d "$source_root" ]; then
        printf 'ERROR: Skill source directory does not exist: %s\n' "$source_root" >&2
        return 1
    fi

    for skill_dir in "$source_root"/*/; do
        [ -f "$skill_dir/SKILL.md" ] || continue
        basename "$skill_dir"
    done
}

link_skill_tree() {
    local source_root="$1"
    local destination_root="$2"
    local platform="$3"
    local skill_dir name count

    if [ ! -d "$source_root" ]; then
        printf 'ERROR: Skill source directory does not exist: %s\n' "$source_root" >&2
        return 1
    fi

    mkdir -p "$destination_root"
    count=0
    for skill_dir in "$source_root"/*/; do
        [ -d "$skill_dir" ] || continue
        if [ ! -f "$skill_dir/SKILL.md" ]; then
            printf 'ERROR: Missing SKILL.md in %s\n' "$skill_dir" >&2
            return 1
        fi
        name="$(basename "$skill_dir")"
        safe_link "${skill_dir%/}" "$destination_root/$name" "$platform: $name"
        count=$((count + 1))
    done

    if [ "$count" -eq 0 ]; then
        printf 'ERROR: No skills found in %s\n' "$source_root" >&2
        return 1
    fi

    printf 'Installed %s skill(s) for %s in %s\n' "$count" "$platform" "$destination_root"
}
