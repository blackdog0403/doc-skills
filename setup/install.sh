#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════
# doc-skills installer — Interactive setup for all agents
# Usage: ./setup/install.sh
# ══════════════════════════════════════════════════════════════════════

set -euo pipefail

# ─── Colors & Symbols ────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'  # No Color

CHECK="${GREEN}✓${NC}"
CROSS="${RED}✗${NC}"
WARN="${YELLOW}⚠${NC}"
ARROW="${CYAN}→${NC}"
BULLET="${DIM}•${NC}"

# ─── Paths ───────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
SKILLS_DIR="$REPO_ROOT/skills"
QUICK_DIR="$REPO_ROOT/quick"
SCRIPTS_DIR="$REPO_ROOT/scripts"

KIRO_SKILLS="$HOME/.kiro/skills"
CLAUDE_SKILLS="$HOME/.claude/skills"
QUICK_SKILLS="$HOME/.quickwork/profiles/federate-prod/skills"
BIN_DIR="$HOME/.local/bin"

# ─── Helper Functions ────────────────────────────────────────────────
print_header() {
    echo ""
    echo -e "${BOLD}${BLUE}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${BLUE}║${NC}  ${BOLD}🧠 doc-skills installer${NC}                             ${BOLD}${BLUE}║${NC}"
    echo -e "${BOLD}${BLUE}║${NC}  ${DIM}Multi-agent skill deployment tool${NC}                   ${BOLD}${BLUE}║${NC}"
    echo -e "${BOLD}${BLUE}╚══════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_section() {
    echo ""
    echo -e "${BOLD}─── $1 ───${NC}"
    echo ""
}

progress_bar() {
    local current=$1
    local total=$2
    local width=30
    local percent=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))
    printf "\r  [${GREEN}"
    printf "%0.s█" $(seq 1 $filled 2>/dev/null) || true
    printf "${DIM}"
    printf "%0.s░" $(seq 1 $empty 2>/dev/null) || true
    printf "${NC}] %d/%d (%d%%)" "$current" "$total" "$percent"
}

ask_yes_no() {
    local prompt="$1"
    local default="${2:-y}"
    local yn
    if [ "$default" = "y" ]; then
        printf "  ${prompt} [${BOLD}Y${NC}/n]: "
    else
        printf "  ${prompt} [y/${BOLD}N${NC}]: "
    fi
    read -r yn
    yn="${yn:-$default}"
    [[ "$yn" =~ ^[Yy] ]]
}

create_symlink() {
    local src="$1"
    local dst="$2"
    local name="$3"
    
    if [ -L "$dst" ]; then
        rm "$dst"
    elif [ -d "$dst" ]; then
        mv "$dst" "${dst}.bak.$(date +%s)"
        echo -e "    ${WARN} Backed up existing: ${DIM}${name}${NC}"
    elif [ -f "$dst" ]; then
        mv "$dst" "${dst}.bak.$(date +%s)"
        echo -e "    ${WARN} Backed up existing: ${DIM}${name}${NC}"
    fi
    ln -sf "$src" "$dst"
}

# ─── Pre-flight Check ────────────────────────────────────────────────
preflight_check() {
    print_section "Pre-flight Check"
    
    local pass=0
    local fail=0
    local warnings=0
    
    # Python
    if command -v python3 &>/dev/null; then
        local pyver=$(python3 --version 2>&1 | awk '{print $2}')
        local pymajor=$(echo "$pyver" | cut -d. -f1)
        local pyminor=$(echo "$pyver" | cut -d. -f2)
        if [ "$pymajor" -ge 3 ] && [ "$pyminor" -ge 10 ]; then
            echo -e "  ${CHECK} Python ${pyver} (≥3.10 required)"
            ((pass++))
        else
            echo -e "  ${CROSS} Python ${pyver} — need 3.10+"
            ((fail++))
        fi
    else
        echo -e "  ${CROSS} Python not found"
        ((fail++))
    fi
    
    # Git
    if command -v git &>/dev/null; then
        local gitver=$(git --version | awk '{print $3}')
        echo -e "  ${CHECK} Git ${gitver}"
        ((pass++))
    else
        echo -e "  ${CROSS} Git not found"
        ((fail++))
    fi
    
    # python-docx
    if python3 -c "import docx" 2>/dev/null; then
        local docxver=$(python3 -c "import docx; print(docx.__version__)" 2>/dev/null || echo "?")
        echo -e "  ${CHECK} python-docx ${docxver}"
        ((pass++))
    else
        echo -e "  ${WARN} python-docx not installed ${DIM}(needed for md-to-docx CLI)${NC}"
        ((warnings++))
    fi
    
    # python-pptx
    if python3 -c "import pptx" 2>/dev/null; then
        local pptxver=$(python3 -c "import pptx; print(pptx.__version__)" 2>/dev/null || echo "?")
        echo -e "  ${CHECK} python-pptx ${pptxver}"
        ((pass++))
    else
        echo -e "  ${WARN} python-pptx not installed ${DIM}(needed for translate-pptx CLI)${NC}"
        ((warnings++))
    fi
    
    # boto3
    if python3 -c "import boto3" 2>/dev/null; then
        local b3ver=$(python3 -c "import boto3; print(boto3.__version__)" 2>/dev/null || echo "?")
        echo -e "  ${CHECK} boto3 ${b3ver} ${DIM}(translate CLI)${NC}"
        ((pass++))
    else
        echo -e "  ${BULLET} boto3 not installed ${DIM}(optional — only for translate CLI)${NC}"
    fi
    
    # AWS credentials
    if aws sts get-caller-identity &>/dev/null 2>&1; then
        echo -e "  ${CHECK} AWS credentials active"
        ((pass++))
    else
        echo -e "  ${BULLET} AWS credentials not configured ${DIM}(optional — only for translate CLI)${NC}"
    fi
    
    # Kiro
    if [ -d "$HOME/.kiro" ]; then
        echo -e "  ${CHECK} Kiro detected (~/.kiro/)"
        ((pass++))
    else
        echo -e "  ${BULLET} Kiro not detected ${DIM}(will create ~/.kiro/skills/)${NC}"
    fi
    
    # Claude Code
    if [ -d "$HOME/.claude" ]; then
        echo -e "  ${CHECK} Claude Code detected (~/.claude/)"
        ((pass++))
    else
        echo -e "  ${BULLET} Claude Code not detected ${DIM}(will create ~/.claude/skills/)${NC}"
    fi
    
    # Amazon Quick Desktop
    if [ -d "$HOME/.quickwork" ]; then
        echo -e "  ${CHECK} Amazon Quick Desktop detected"
        ((pass++))
    else
        echo -e "  ${BULLET} Amazon Quick Desktop not detected"
    fi
    
    echo ""
    echo -e "  ${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  Results: ${GREEN}${pass} passed${NC}, ${YELLOW}${warnings} warnings${NC}, ${RED}${fail} failed${NC}"
    
    if [ "$fail" -gt 0 ]; then
        echo ""
        echo -e "  ${CROSS} Critical requirements missing. Fix above issues first."
        exit 1
    fi
    
    echo ""
}

# ─── Install Menu ────────────────────────────────────────────────────
install_menu() {
    print_section "What would you like to install?"
    
    echo -e "  ${BOLD}1)${NC} Everything ${DIM}(Kiro + Claude Code + Quick Desktop + CLI)${NC}"
    echo -e "  ${BOLD}2)${NC} Slash commands only ${DIM}(Kiro + Claude Code)${NC}"
    echo -e "  ${BOLD}3)${NC} Amazon Quick Desktop only"
    echo -e "  ${BOLD}4)${NC} CLI scripts only ${DIM}(~/.local/bin/)${NC}"
    echo -e "  ${BOLD}5)${NC} Custom ${DIM}(pick individually)${NC}"
    echo ""
    printf "  Choose [1-5]: "
    read -r choice
    
    case "$choice" in
        1) INSTALL_SLASH=true; INSTALL_QUICK=true; INSTALL_CLI=true ;;
        2) INSTALL_SLASH=true; INSTALL_QUICK=false; INSTALL_CLI=false ;;
        3) INSTALL_SLASH=false; INSTALL_QUICK=true; INSTALL_CLI=false ;;
        4) INSTALL_SLASH=false; INSTALL_QUICK=false; INSTALL_CLI=true ;;
        5)
            INSTALL_SLASH=false; INSTALL_QUICK=false; INSTALL_CLI=false
            ask_yes_no "Install for Kiro + Claude Code?" "y" && INSTALL_SLASH=true
            ask_yes_no "Install for Amazon Quick Desktop?" "y" && INSTALL_QUICK=true
            ask_yes_no "Install CLI scripts to ~/.local/bin/?" "y" && INSTALL_CLI=true
            ;;
        *) echo -e "  ${CROSS} Invalid choice"; exit 1 ;;
    esac
}

# ─── Install Slash Commands ──────────────────────────────────────────
install_slash() {
    print_section "Registering slash commands (Kiro + Claude Code)"
    
    mkdir -p "$KIRO_SKILLS" "$CLAUDE_SKILLS"
    
    local skills=($(ls -d "$SKILLS_DIR"/*/))
    local total=${#skills[@]}
    local current=0
    
    for skill_dir in "${skills[@]}"; do
        ((current++))
        local name=$(basename "$skill_dir")
        
        # Kiro
        create_symlink "$skill_dir" "$KIRO_SKILLS/$name" "$name"
        # Claude Code
        create_symlink "$skill_dir" "$CLAUDE_SKILLS/$name" "$name"
        
        echo -e "  ${CHECK} /${name}"
        progress_bar $current $total
    done
    echo ""
    echo ""
    echo -e "  ${ARROW} Kiro:   ${DIM}$KIRO_SKILLS${NC}"
    echo -e "  ${ARROW} Claude: ${DIM}$CLAUDE_SKILLS${NC}"
}

# ─── Install Quick Desktop ───────────────────────────────────────────
install_quick() {
    print_section "Registering for Amazon Quick Desktop"
    
    mkdir -p "$QUICK_SKILLS"
    
    local skills=($(ls -d "$QUICK_DIR"/*/))
    local total=${#skills[@]}
    local current=0
    
    for skill_dir in "${skills[@]}"; do
        ((current++))
        local name=$(basename "$skill_dir")
        
        create_symlink "$skill_dir" "$QUICK_SKILLS/$name" "$name"
        echo -e "  ${CHECK} ${name}"
        progress_bar $current $total
    done
    
    # Script symlinks for Quick bundling
    echo ""
    echo ""
    echo -e "  ${DIM}Linking scripts for bundling...${NC}"
    
    local tp_scripts="$QUICK_DIR/translate-pptx/scripts"
    local md_scripts="$QUICK_DIR/md-to-docx/scripts"
    mkdir -p "$tp_scripts" "$md_scripts"
    
    ln -sf "$SCRIPTS_DIR/translate_pptx_native.py" "$tp_scripts/translate_pptx_native.py" 2>/dev/null || true
    ln -sf "$SCRIPTS_DIR/generate_styled_docx.py" "$md_scripts/generate_styled_docx.py" 2>/dev/null || true
    
    echo -e "  ${CHECK} Script bundles linked"
    echo ""
    echo -e "  ${ARROW} Quick: ${DIM}$QUICK_SKILLS${NC}"
}

# ─── Install CLI ─────────────────────────────────────────────────────
install_cli() {
    print_section "Installing CLI scripts"
    
    mkdir -p "$BIN_DIR"
    
    # translate_pptx_cli.py → translate_pptx.py
    create_symlink "$SCRIPTS_DIR/translate_pptx_cli.py" "$BIN_DIR/translate_pptx.py" "translate_pptx.py"
    echo -e "  ${CHECK} translate_pptx.py"
    
    # generate_styled_docx.py
    create_symlink "$SCRIPTS_DIR/generate_styled_docx.py" "$BIN_DIR/generate_styled_docx.py" "generate_styled_docx.py"
    echo -e "  ${CHECK} generate_styled_docx.py"
    
    echo ""
    echo -e "  ${ARROW} Installed to: ${DIM}$BIN_DIR${NC}"
    
    # Check PATH
    if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
        echo ""
        echo -e "  ${WARN} ${BIN_DIR} is not in your PATH!"
        echo -e "  ${DIM}  Add to ~/.zshrc:${NC}"
        echo -e "  ${DIM}  export PATH=\"\$HOME/.local/bin:\$PATH\"${NC}"
    fi
}

# ─── Post-install Verification ───────────────────────────────────────
verify_install() {
    print_section "Verification"
    
    local pass=0
    local fail=0
    
    if [ "$INSTALL_SLASH" = true ]; then
        for skill in doc-fact-check md-to-docx translate-pptx; do
            if [ -L "$KIRO_SKILLS/$skill" ] && [ -e "$KIRO_SKILLS/$skill/SKILL.md" ]; then
                ((pass++))
            else
                echo -e "  ${CROSS} Kiro: /$skill missing"; ((fail++))
            fi
            if [ -L "$CLAUDE_SKILLS/$skill" ] && [ -e "$CLAUDE_SKILLS/$skill/SKILL.md" ]; then
                ((pass++))
            else
                echo -e "  ${CROSS} Claude: /$skill missing"; ((fail++))
            fi
        done
    fi
    
    if [ "$INSTALL_QUICK" = true ]; then
        for skill in doc-fact-check md-to-docx translate-pptx; do
            if [ -L "$QUICK_SKILLS/$skill" ] && [ -e "$QUICK_SKILLS/$skill/SKILL.md" ]; then
                ((pass++))
            else
                echo -e "  ${CROSS} Quick: $skill missing"; ((fail++))
            fi
        done
    fi
    
    if [ "$INSTALL_CLI" = true ]; then
        for script in translate_pptx.py generate_styled_docx.py; do
            if [ -L "$BIN_DIR/$script" ] && [ -e "$BIN_DIR/$script" ]; then
                ((pass++))
            else
                echo -e "  ${CROSS} CLI: $script missing"; ((fail++))
            fi
        done
    fi
    
    if [ "$fail" -eq 0 ]; then
        echo -e "  ${CHECK} All ${pass} checks passed!"
    else
        echo -e "  ${pass} passed, ${fail} failed"
    fi
}

# ─── Summary ─────────────────────────────────────────────────────────
print_summary() {
    echo ""
    echo -e "${BOLD}${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${GREEN}║${NC}  ${BOLD}🎉 Installation complete!${NC}                            ${BOLD}${GREEN}║${NC}"
    echo -e "${BOLD}${GREEN}╚══════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    if [ "$INSTALL_SLASH" = true ]; then
        echo -e "  ${BOLD}Kiro / Claude Code:${NC}"
        echo -e "    ${DIM}> /doc-fact-check report.md${NC}"
        echo -e "    ${DIM}> /md-to-docx notes.md${NC}"
        echo -e "    ${DIM}> /translate-pptx deck.pptx source:ko target:en${NC}"
        echo ""
    fi
    
    if [ "$INSTALL_QUICK" = true ]; then
        echo -e "  ${BOLD}Amazon Quick Desktop:${NC}"
        echo -e "    ${DIM}> fact check this document${NC}"
        echo -e "    ${DIM}> md를 docx로 변환해줘${NC}"
        echo -e "    ${DIM}> pptx 번역해줘${NC}"
        echo ""
    fi
    
    if [ "$INSTALL_CLI" = true ]; then
        echo -e "  ${BOLD}CLI:${NC}"
        echo -e "    ${DIM}\$ generate_styled_docx.py report.md${NC}"
        echo -e "    ${DIM}\$ translate_pptx.py deck.pptx --source ko --target en${NC}"
        echo ""
    fi
    
    echo -e "  ${DIM}To update later: git pull && ./setup/install.sh${NC}"
    echo ""
}

# ─── Main ────────────────────────────────────────────────────────────
main() {
    print_header
    preflight_check
    install_menu
    
    [ "$INSTALL_SLASH" = true ] && install_slash
    [ "$INSTALL_QUICK" = true ] && install_quick
    [ "$INSTALL_CLI" = true ] && install_cli
    
    verify_install
    print_summary
}

main "$@"
