<p align="center">
  <h1 align="center">🧠 doc-skills</h1>
  <p align="center">
    <strong>Multi-agent AI skills for document workflows</strong><br/>
    Built for AWS Solutions Architects — useful for anyone producing technical documents<br/>
    One repo, three agents — Kiro · Claude Code · Amazon Quick Desktop
  </p>
  <p align="center">
    <img src="https://img.shields.io/badge/agents-Kiro%20%7C%20Claude%20Code%20%7C%20Amazon%20Quick-blue" alt="Agents"/>
    <img src="https://img.shields.io/badge/skills-3-green" alt="Skills"/>
    <img src="https://img.shields.io/badge/license-MIT-brightgreen" alt="License"/>
    <img src="https://img.shields.io/badge/python-3.10%2B-yellow" alt="Python"/>
  </p>
</p>

---

## 🎯 What is this?

**doc-skills** is a unified skill repository that lets you write AI agent instructions once and deploy them to multiple AI coding assistants simultaneously.

Each skill is a portable instruction package (`SKILL.md`) — a structured Markdown file with YAML frontmatter that teaches your AI agent a specific document workflow: fact-checking, format conversion, translation, and more.

### 🤔 Problem

As AI-assisted work matures, SA teams accumulate specialized prompts scattered across different tools:
- Kiro has one version of your translation skill
- Claude Code has a slightly different copy
- Amazon Quick Desktop has yet another format
- Nobody knows which version is latest
- Sharing with teammates means copy-pasting and manual adaptation

### 💡 Solution

**doc-skills** solves this with:

1. **Single Source of Truth** — One Git repo, version-controlled, shareable
2. **Multi-Agent Compatibility** — Write once, deploy to Kiro + Claude Code + Amazon Quick Desktop via symlinks
3. **Open Standard** — Follows the [Agent Skills open standard](https://kiro.dev/docs/cli/skills/) used by both Kiro and Claude Code
4. **Central Script Management** — Python utilities live in `scripts/`, shared across all skill variants
5. **Zero-friction Setup** — `./setup/link-slash.sh` and you're done. New skills auto-detected.

### 🎯 Who is this for?

- **AWS Solutions Architects** who produce technical documents, customer deliverables, and presentations
- **Teams** who want to standardize document workflows across members
- **Anyone** using multiple AI coding tools who wants consistent, reusable skills

### ✨ Key Features

| Feature | Description |
|---------|-------------|
| 🔄 Multi-agent deploy | One skill works across Kiro, Claude Code, and Amazon Quick Desktop |
| 📎 Symlink architecture | `git pull` instantly updates all agents — no manual copy |
| 🐍 Script separation | Python logic versioned independently from instructions |
| 🧪 Testable | Scripts have `tests/` for CI/CD validation |
| 📦 Portable | Clone → run setup script → immediately available as `/slash-command` |
| 🔒 No secrets | All skills use public APIs or local processing — no credentials in repo |

---

## 📦 Skills

| Skill | What it does | Agents | Internal Access |
|-------|-------------|:------:|:---:|
| 🔍 **[doc-fact-check](skills/doc-fact-check/)** | Verify factual claims in technical documents against AWS official sources. Produces a correction report with quality score. | Kiro · CC · Quick | 🌐 Public |
| 📄 **[md-to-docx](skills/md-to-docx/)** | Convert Markdown → professionally styled Word (.docx) with AWS Orange branding, badges, and tables. | Kiro · CC · Quick | 🌐 Public |
| 🌐 **[translate-pptx](skills/translate-pptx/)** | Translate PowerPoint presentations between languages using LLM-native translation. No external API calls. | Kiro · CC · Quick | 🌐 Public |

---

## ⚡ Quick Start

### 1. Clone

```bash
git clone git@github.com:blackdog0403/doc-skills.git ~/Documents/dev/doc-skills
cd ~/Documents/dev/doc-skills
```

### 2. Install

```bash
chmod +x setup/*.sh

# Interactive installer (recommended)
./setup/install.sh
```

The installer will:
1. ✅ Check your environment (Python, packages, agents)
2. 📋 Let you choose what to install (Kiro / Claude Code / Quick / CLI)
3. 🔗 Create symlinks with progress tracking
4. ✓ Verify everything is correctly linked

<details>
<summary>Manual install (individual scripts)</summary>

```bash
./setup/link-slash.sh     # Kiro + Claude Code only
./setup/link-quick.sh     # Amazon Quick Desktop only
./setup/install-cli.sh    # CLI scripts to ~/.local/bin/ only
```
</details>

### 3. Use

```
# In Kiro or Claude Code:
> /doc-fact-check report.md
> /md-to-docx meeting-notes.md
> /translate-pptx deck.pptx source:ko target:en

# In Amazon Quick Desktop:
> fact check this document
> md를 docx로 변환해줘
> pptx 번역해줘
```

---

## 🏗️ Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                         doc-skills repo                          │
│                     (Single Source of Truth)                     │
├────────────────────┬────────────────────┬────────────────────────┤
│  skills/           │  quick/            │  scripts/              │
│  (Kiro + CC)       │  (Quick Desktop)   │  (Python code)         │
└─────────┬──────────┴─────────┬──────────┴───────────┬────────────┘
          │                    │                      │
          ▼                    ▼                      ▼
┌──────────────────┐  ┌──────────────────┐  ┌──────────────────────┐
│ ~/.kiro/skills/  │  │ ~/.quickwork/    │  │ ~/.local/bin/        │
│                  │  │   profiles/      │  │   generate_styled_   │
│ ~/.claude/       │  │   federate-prod/ │  │     docx.py          │
│   skills/        │  │   skills/        │  │   translate_pptx.py  │
└──────────────────┘  └──────────────────┘  └──────────────────────┘
       symlink              symlink                 symlink
```

### Why Two SKILL.md Versions?

| | `skills/` (Slash Command) | `quick/` (Amazon Quick Desktop) |
|---|---|---|
| **Invocation** | `/skill-name` | Natural language trigger |
| **Frontmatter** | `name` + `description` + `allowed-tools` | + `display_name`, `icon`, `trigger`, `inputs`, `tools` |
| **Tool names** | `Bash`, `Read`, `Write` | `run_python`, `file_read`, `file_write` |
| **Body** | Same instructional content | Same (with Quick tool names) |

Kiro and Claude Code both follow the [Agent Skills open standard](https://kiro.dev/docs/cli/skills/) — so one file works for both. Amazon Quick Desktop uses a superset format with additional metadata for its UI.

---

## 📁 Repository Structure

```
doc-skills/
├── skills/                          # Kiro + Claude Code shared
│   ├── doc-fact-check/
│   │   └── SKILL.md                 #   /doc-fact-check
│   ├── md-to-docx/
│   │   └── SKILL.md                 #   /md-to-docx
│   └── translate-pptx/
│       └── SKILL.md                 #   /translate-pptx
│
├── quick/                           # Amazon Quick Desktop (extra frontmatter)
│   ├── doc-fact-check/
│   │   └── SKILL.md
│   ├── md-to-docx/
│   │   ├── SKILL.md
│   │   └── scripts/                 #   → symlink to scripts/
│   └── translate-pptx/
│       ├── SKILL.md
│       └── scripts/                 #   → symlink to scripts/
│
├── scripts/                         # 🐍 Central Python code
│   ├── generate_styled_docx.py      #   32KB — MD→DOCX converter
│   ├── translate_pptx_native.py     #   11KB — Sandbox-safe PPTX ops
│   ├── translate_pptx_cli.py        #   30KB — Standalone (boto3)
│   └── tests/
│       └── test_placeholder.py
│
├── setup/                           # Installation scripts
│   ├── link-slash.sh                #   Kiro + Claude Code
│   ├── link-quick.sh                #   Amazon Quick Desktop
│   └── install-cli.sh               #   CLI → ~/.local/bin/
│
├── docs/
│   └── skill-format.md              # How to write multi-agent skills
├── LICENSE                          # MIT
├── .gitignore
└── README.md                        # ← You are here
```

---

## 🧪 Testing (venv)

Scripts can be tested in an isolated virtual environment before deploying:

```bash
cd ~/Documents/dev/doc-skills

# Create and activate venv
python3 -m venv .venv
source .venv/bin/activate

# Install dependencies
pip install python-docx python-pptx pytest

# Run tests
pytest scripts/tests/ -v

# Test individual scripts manually
python3 scripts/generate_styled_docx.py test-input.md -o /tmp/test.docx
python3 -c "from scripts.translate_pptx_native import extract_texts; print('OK')"

# Deactivate when done
deactivate
```

### Quick Smoke Test (no venv)

```bash
# Verify scripts are syntactically valid
python3 -c "import ast; ast.parse(open('scripts/generate_styled_docx.py').read()); print('✅ generate_styled_docx.py')"
python3 -c "import ast; ast.parse(open('scripts/translate_pptx_native.py').read()); print('✅ translate_pptx_native.py')"
python3 -c "import ast; ast.parse(open('scripts/translate_pptx_cli.py').read()); print('✅ translate_pptx_cli.py')"

# Verify symlinks are correct
ls -la ~/.kiro/skills/ | grep -E "doc-fact|md-to|translate"
ls -la ~/.claude/skills/ | grep -E "doc-fact|md-to|translate"
```

---

## 📖 Agent-Specific Usage Guide

### <img src="https://kiro.dev/favicon.ico" width="16"/> Kiro

Skills are auto-discovered from `~/.kiro/skills/`. After running `link-slash.sh`:

```
# Invoke directly as slash command
> /translate-pptx deck.pptx source:ko target:en
> /md-to-docx report.md
> /doc-fact-check whitepaper.md

# Or describe your intent — Kiro auto-matches skill descriptions
> 이 발표자료 영어로 번역해줘
> 이 문서 팩트체크해줘
```

**Kiro-specific notes:**
- Skills use `Bash` tool → Kiro executes shell commands directly
- `references/` subdirectory supported for large docs
- Check loaded skills: `/context show`

### <img src="https://code.claude.com/favicon.ico" width="16"/> Claude Code

Skills are auto-discovered from `~/.claude/skills/`. After running `link-slash.sh`:

```
# Slash command (same as Kiro)
> /translate-pptx deck.pptx source:ko target:en
> /md-to-docx meeting-notes.md
> /doc-fact-check report.md scope:latency output:fix

# Or let Claude auto-invoke based on description
> Translate this Korean deck to English
> Convert this markdown to a styled Word doc
```

**Claude Code-specific notes:**
- `allowed-tools` field pre-approves tools (no confirmation prompt)
- Supports `!`backtick`` for dynamic context injection in SKILL.md
- Skills can run in subagent context with `context: fork`
- Project-level skills (`.claude/skills/` in repo root) override global

### 🖥️ Amazon Quick Desktop

Skills are loaded from `~/.quickwork/profiles/federate-prod/skills/`. After running `link-quick.sh`:

```
# Natural language triggers (Korean or English)
> fact check this document
> 이 마크다운 워드로 변환해줘
> pptx 번역해줘 — 한국어에서 영어로
> translate-pptx 가지고 이 파일 번역해
```

**Amazon Quick Desktop-specific notes:**
- Uses `trigger:` field for activation (not slash commands)
- `inputs:` define structured parameters (shown in UI)
- `tools:` must use Quick tool names (`run_python`, `file_write`, etc.)
- `scripts/` subdirectory within skill folder is bundled automatically
- Supports `open_in_session_tab` for live preview of generated files

---

## 🐍 Scripts

| Script | Type | Size | Used By | Description |
|--------|:----:|-----:|---------|-------------|
| `generate_styled_docx.py` | CLI | 32KB | md-to-docx | Markdown → Word with AWS Orange styling, badges, tables |
| `translate_pptx_native.py` | Sandbox | 11KB | translate-pptx | PPTX text extraction & font normalization (no network) |
| `translate_pptx_cli.py` | CLI | 30KB | translate-pptx | Standalone translator via AWS Bedrock (Claude) |

### Script Types

- **Sandbox** — No network, no boto3. Safe for Kiro/Quick sandboxed environments.
- **CLI** — May require boto3, AWS credentials, or network access. Installed to `~/.local/bin/` for direct terminal use.

---

## ➕ Adding a New Skill

1. **Create the slash command version:**
   ```bash
   mkdir skills/my-new-skill
   ```
   Write `skills/my-new-skill/SKILL.md`:
   ```yaml
   ---
   name: my-new-skill
   description: |
     What it does. When to activate.
   allowed-tools: [Bash, Read, Write]
   ---
   
   # Instructions here...
   ```

2. **Create Quick version** (optional):
   ```bash
   mkdir quick/my-new-skill
   ```
   Add Quick-specific frontmatter (`display_name`, `icon`, `trigger`, `tools`).

3. **Add scripts** (if needed):
   ```bash
   # Sandbox-safe version
   scripts/my_script_native.py
   # CLI version (if needs boto3/network)
   scripts/my_script_cli.py
   ```

4. **Register:**
   ```bash
   ./setup/link-slash.sh    # Detects new skill automatically
   ./setup/link-quick.sh    # If Quick version exists
   ```

5. **Test:**
   ```
   # In Kiro or Claude Code:
   > /my-new-skill
   ```

See [docs/skill-format.md](docs/skill-format.md) for the full format reference.

---

## 🔧 Prerequisites

### System Requirements

| Requirement | Version | Check | Notes |
|-------------|---------|-------|-------|
| **macOS / Linux** | — | — | Windows는 WSL2 권장 |
| **Python** | 3.10+ | `python3 --version` | macOS: `brew install python@3.12` |
| **Git** | 2.x+ | `git --version` | Symlink 추적 용도 |
| **Kiro** | Latest | `kiro --version` | [kiro.dev](https://kiro.dev) |
| **Claude Code** | Latest | `claude --version` | [code.claude.com](https://code.claude.com) |
| **Amazon Quick Desktop** | Latest | — | 사내 배포 앱 |

### Python Dependencies

| Package | PyPI Name | Version | Used By | Purpose |
|---------|-----------|---------|---------|---------|
| `python-docx` | `python-docx` | ≥0.8.11 | `generate_styled_docx.py` | Word 문서 생성 (.docx) |
| `python-pptx` | `python-pptx` | ≥0.6.21 | `translate_pptx_native.py`, `translate_pptx_cli.py` | PPTX 읽기/쓰기 |
| `boto3` | `boto3` | ≥1.28 | `translate_pptx_cli.py` **only** | AWS Bedrock 호출 (CLI 전용) |
| `pytest` | `pytest` | ≥7.0 | `scripts/tests/` | 테스트 실행 (개발 시) |

### Installation Options

**Option A: venv (권장 — 격리된 환경)**
```bash
cd ~/Documents/dev/doc-skills
python3 -m venv .venv
source .venv/bin/activate
pip install python-docx python-pptx pytest
# CLI 번역 사용 시:
pip install boto3
```

**Option B: 시스템 Python에 직접 설치**
```bash
pip3 install --user python-docx python-pptx
# CLI 번역 사용 시:
pip3 install --user boto3
```

**Option C: 최소 설치 (스킬만 사용, 스크립트 안 씀)**
```bash
# Python 패키지 설치 불필요!
# SKILL.md만 읽으면 되므로 link-slash.sh만 실행하면 끝
./setup/link-slash.sh
```

> ℹ️ **doc-fact-check** 스킬은 Python 스크립트를 사용하지 않으므로 패키지 설치 없이 바로 사용 가능합니다.

### AWS Credentials (translate CLI only)

`translate_pptx_cli.py`를 터미널에서 직접 사용할 경우에만 AWS 자격 증명이 필요합니다.
**Agent 안에서 사용할 때 (Quick/Kiro)는 자격 증명이 필요 없습니다** — LLM이 직접 번역합니다.

#### 일반 AWS 사용자

```bash
# Option 1: AWS SSO (권장)
aws sso login --profile my-profile
export AWS_PROFILE=my-profile

# Option 2: Static credentials
aws configure

# Option 3: Environment variables
export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...
export AWS_REGION=us-west-2

# 확인
aws sts get-caller-identity
```

#### AWS Internal 사용자 (Amazon employees)

사내 인증 도구를 통해 AWS 자격 증명을 미리 설정해두세요.
자세한 방법은 조직 내부 문서를 참고하시기 바랍니다.

```bash
# 사내 인증 도구로 credential 획득 후:
aws sts get-caller-identity   # 정상 출력 확인
```

> 💡 **필요한 권한**: `translate_pptx_cli.py`는 **Amazon Bedrock** (`bedrock:InvokeModel`)만 호출합니다.
> Bedrock이 활성화된 계정 + `anthropic.claude-*` 모델 접근 권한이 있으면 됩니다.

### Verify Installation

```bash
# 전체 환경 검증 (설치 후)
./setup/test-setup.sh

# 개별 확인
python3 -c "import docx; print(f'python-docx {docx.__version__}')"
python3 -c "import pptx; print(f'python-pptx {pptx.__version__}')"
python3 -c "import boto3; print(f'boto3 {boto3.__version__}')"  # CLI only
```

---

## 🤝 Contributing

1. Fork or branch from `main`
2. Add/modify skills following the format in `docs/skill-format.md`
3. Test with at least one agent (Kiro, Claude Code, or Quick)
4. Submit PR with description of what the skill does and which agents it supports

### Conventions

- Skill names: lowercase, hyphenated (`my-new-skill`)
- Script names: snake_case with suffix (`_native.py` or `_cli.py`)
- One SKILL.md per skill directory (entry point)
- Keep SKILL.md actionable — reference docs go in `references/` subdirectory

---

## 📜 License

MIT — see [LICENSE](LICENSE)

---

<p align="center">
  <sub>Built with ❤️ by <a href="https://github.com/blackdog0403">Kwangyoung Kim</a> — AWS Solutions Architect</sub>
</p>
