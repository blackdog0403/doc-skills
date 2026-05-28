<p align="center">
  <a href="./README.md"><strong>English</strong></a> ·
  <a href="./README.ko.md">한국어</a>
</p>

<p align="center">
  <h1 align="center">🧠 doc-skills</h1>
  <p align="center">
    Multi-agent AI skills for document workflows — <a href="https://kiro.dev">Kiro</a> · <a href="https://docs.anthropic.com/en/docs/claude-code">Claude Code</a> · <a href="https://aws.amazon.com/quick/desktop/">Amazon Quick Desktop</a>
  </p>
  <p align="center">
    <img src="https://img.shields.io/badge/agents-Kiro%20%7C%20Claude%20Code%20%7C%20Amazon%20Quick-blue" alt="Agents"/>
    <img src="https://img.shields.io/badge/skills-4-green" alt="Skills"/>
    <img src="https://img.shields.io/badge/license-MIT-brightgreen" alt="License"/>
    <img src="https://img.shields.io/badge/python-3.10%2B-yellow" alt="Python"/>
  </p>
</p>

A unified skill repository that lets you write AI agent instructions once and deploy them to Kiro, Claude Code, and Amazon Quick Desktop together. Built for AWS Solutions Architects, useful for anyone producing technical documents.

📖 **Documentation:** [docs/skill-format.md](docs/skill-format.md)

---

## Table of Contents

- [⚡ Quick Start](#-quick-start)
- [📦 Skills](#-skills)
- [🏗️ Architecture](#️-architecture)
- [📁 Repository Structure](#-repository-structure)
- [📖 Agent-Specific Usage](#-agent-specific-usage)
- [➕ Adding a New Skill](#-adding-a-new-skill)
- [🐍 Scripts](#-scripts)
- [🔧 Prerequisites](#-prerequisites)
- [🤝 Contributing](#-contributing)
- [📜 License](#-license)

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

The installer:
1. ✅ Checks your environment (Python, packages, agents)
2. 📋 Lets you pick what to install (Kiro / Claude Code / Quick / CLI)
3. 🔗 Creates symlinks with progress tracking
4. ✓ Verifies the links

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
> /stop-slop draft.md

# In Amazon Quick Desktop:
> fact check this document
> convert this markdown to docx
> translate this pptx
> stop slop this draft
```

> Korean trigger phrases also work. See [README.ko.md](./README.ko.md).

---

## 📦 Skills

| Skill | What it does | Agents | Internal Access |
|-------|-------------|:------:|:---:|
| 🔍 **[doc-fact-check](skills/doc-fact-check/)** | Verify factual claims in technical documents against AWS official sources — produces a correction report with quality score. | Kiro · CC · Quick | 🌐 Public |
| 📄 **[md-to-docx](skills/md-to-docx/)** | Convert Markdown to styled Word (.docx) with AWS Orange branding, badges, and tables. | Kiro · CC · Quick | 🌐 Public |
| 🌐 **[translate-pptx](skills/translate-pptx/)** | Translate PowerPoint presentations between languages using LLM-native translation — no external API calls. | Kiro · CC · Quick | 🌐 Public |
| ✂️ **[stop-slop](skills/stop-slop/)** | Remove AI writing patterns from prose — filler phrases, formulaic structures, passive voice, false agency, metronomic rhythm. Based on [hardikpandya/stop-slop](https://github.com/hardikpandya/stop-slop). | Kiro · CC · Quick | 🌐 Public |

### Why doc-skills?

| Feature | Description |
|---------|-------------|
| 🔄 Multi-agent deploy | One skill works across Kiro, Claude Code, and Amazon Quick Desktop |
| 📎 Symlink architecture | `git pull` updates every agent at once — no manual copy |
| 🐍 Script separation | Python logic versioned independently from instructions |
| 🧪 Testable | Scripts have `tests/` for CI/CD validation |
| 📦 Portable | Clone → run setup → invoke as `/slash-command` |
| 🔒 No secrets | Skills use public APIs or local processing — no credentials in repo |

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

### Why two SKILL.md versions?

| | `skills/` (Slash Command) | `quick/` (Amazon Quick Desktop) |
|---|---|---|
| **Invocation** | `/skill-name` | Natural language trigger |
| **Frontmatter** | `name` + `description` + `allowed-tools` | + `display_name`, `icon`, `trigger`, `inputs`, `tools` |
| **Tool names** | `Bash`, `Read`, `Write` | `run_python`, `file_read`, `file_write` |
| **Body** | Same instructional content | Same (with Quick tool names) |

Kiro and Claude Code follow the [Agent Skills open standard](https://kiro.dev/docs/cli/skills/), so one file works for both. Amazon Quick Desktop uses a superset format with extra metadata for its UI.

---

## 📁 Repository Structure

```
doc-skills/
├── skills/                          # Kiro + Claude Code shared
│   ├── doc-fact-check/
│   │   └── SKILL.md                 #   /doc-fact-check
│   ├── md-to-docx/
│   │   └── SKILL.md                 #   /md-to-docx
│   ├── translate-pptx/
│   │   └── SKILL.md                 #   /translate-pptx
│   └── stop-slop/
│       ├── SKILL.md                 #   /stop-slop
│       └── references/
│           ├── phrases.md
│           ├── structures.md
│           └── examples.md
│
├── quick/                           # Amazon Quick Desktop (extra frontmatter)
│   ├── doc-fact-check/
│   │   └── SKILL.md
│   ├── md-to-docx/
│   │   ├── SKILL.md
│   │   └── scripts/                 #   → symlink to scripts/
│   ├── translate-pptx/
│   │   ├── SKILL.md
│   │   └── scripts/                 #   → symlink to scripts/
│   └── stop-slop/
│       ├── SKILL.md
│       └── references/              #   → symlink to skills/stop-slop/references/
│
├── scripts/                         # 🐍 Central Python code
│   ├── generate_styled_docx.py      #   32KB — MD→DOCX converter
│   ├── translate_pptx_native.py     #   11KB — Sandbox-safe PPTX ops
│   ├── translate_pptx_cli.py        #   30KB — Standalone (boto3)
│   └── tests/
│       └── test_placeholder.py
│
├── setup/                           # Installation scripts
│   ├── install.sh                   #   Interactive installer
│   ├── link-slash.sh                #   Kiro + Claude Code
│   ├── link-quick.sh                #   Amazon Quick Desktop
│   ├── install-cli.sh               #   CLI to ~/.local/bin/
│   └── test-setup.sh                #   Verify installation
│
├── docs/
│   └── skill-format.md              # How to write multi-agent skills
├── LICENSE                          # MIT
├── .gitignore
└── README.md                        # You are here
```

---

## 📖 Agent-Specific Usage

### <img src="https://kiro.dev/favicon.ico" width="16"/> Kiro

Skills are auto-discovered from `~/.kiro/skills/`. After running `link-slash.sh`:

```
# Invoke directly as slash command
> /translate-pptx deck.pptx source:ko target:en
> /md-to-docx report.md
> /doc-fact-check whitepaper.md

# Or describe your intent — Kiro matches against skill descriptions
> Translate this deck to English
> Fact-check this document
```

**Kiro-specific notes:**
- Skills use the `Bash` tool, so Kiro runs shell commands directly
- `references/` subdirectory supported for large docs
- Check loaded skills: `/context show`

### <img src="https://code.claude.com/favicon.ico" width="16"/> Claude Code

Skills are auto-discovered from `~/.claude/skills/`. After running `link-slash.sh`:

```
# Slash command (same as Kiro)
> /translate-pptx deck.pptx source:ko target:en
> /md-to-docx meeting-notes.md
> /doc-fact-check report.md scope:latency output:fix

# Or let Claude pick the skill from your intent
> Translate this Korean deck to English
> Convert this markdown to a styled Word doc
```

**Claude Code-specific notes:**
- `allowed-tools` field pre-approves tools — no confirmation prompt
- Supports `!`backtick`` for dynamic context injection in SKILL.md
- Skills can run in subagent context with `context: fork`
- Project-level skills (`.claude/skills/` in repo root) override global

### 🖥️ Amazon Quick Desktop

Skills are loaded from `~/.quickwork/profiles/federate-prod/skills/`. After running `link-quick.sh`:

```
# Natural language triggers
> fact check this document
> convert this markdown to a Word file
> translate this pptx from Korean to English
> use translate-pptx on this file
```

**Amazon Quick Desktop-specific notes:**
- Activates on the `trigger:` field, not slash commands
- `inputs:` define structured parameters shown in the UI
- `tools:` must use Quick tool names like `run_python`, `file_write`
- `scripts/` subdirectory within a skill folder is bundled automatically
- Supports `open_in_session_tab` for live preview of generated files

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
   ./setup/link-slash.sh    # Detects new skills on each run
   ./setup/link-quick.sh    # If a Quick version exists
   ```

5. **Test:**
   ```
   # In Kiro or Claude Code:
   > /my-new-skill
   ```

See [docs/skill-format.md](docs/skill-format.md) for the full format reference.

---

## 🐍 Scripts

| Script | Type | Size | Used By | Description |
|--------|:----:|-----:|---------|-------------|
| `generate_styled_docx.py` | CLI | 32KB | md-to-docx | Markdown → Word with AWS Orange styling, badges, tables |
| `translate_pptx_native.py` | Sandbox | 11KB | translate-pptx | PPTX text extraction & font normalization (no network) |
| `translate_pptx_cli.py` | CLI | 30KB | translate-pptx | Standalone translator via AWS Bedrock (Claude) |

**Script types:**
- **Sandbox** — No network, no boto3. Safe for Kiro and Quick sandboxed environments.
- **CLI** — May require boto3, AWS credentials, or network access. Installed to `~/.local/bin/` for direct terminal use.

---

## 🔧 Prerequisites

### System Requirements

| Requirement | Version | Check | Notes |
|-------------|---------|-------|-------|
| **macOS / Linux** | — | — | Windows: use WSL2 |
| **Python** | 3.10+ | `python3 --version` | macOS: `brew install python@3.12` |
| **Git** | 2.x+ | `git --version` | For tracking symlinks |
| **Kiro** | Latest | `kiro --version` | [kiro.dev](https://kiro.dev) |
| **Claude Code** | Latest | `claude --version` | [code.claude.com](https://code.claude.com) |
| **Amazon Quick Desktop** | Latest | — | Amazon-internal app |

<details>
<summary><b>Python Dependencies</b></summary>

| Package | PyPI Name | Version | Used By | Purpose |
|---------|-----------|---------|---------|---------|
| `python-docx` | `python-docx` | ≥0.8.11 | `generate_styled_docx.py` | Word document generation (.docx) |
| `python-pptx` | `python-pptx` | ≥0.6.21 | `translate_pptx_native.py`, `translate_pptx_cli.py` | PPTX read/write |
| `boto3` | `boto3` | ≥1.28 | `translate_pptx_cli.py` **only** | AWS Bedrock calls (CLI only) |
| `pytest` | `pytest` | ≥7.0 | `scripts/tests/` | Test runner (dev only) |

**Option A: venv (recommended, isolated)**
```bash
cd ~/Documents/dev/doc-skills
python3 -m venv .venv
source .venv/bin/activate
pip install python-docx python-pptx pytest
# For the CLI translator:
pip install boto3
```

**Option B: System Python**
```bash
pip3 install --user python-docx python-pptx
# For the CLI translator:
pip3 install --user boto3
```

**Option C: Minimal (skills only, no scripts)**
```bash
# No Python packages needed.
# Skills run from SKILL.md alone, so link-slash.sh is enough.
./setup/link-slash.sh
```

> ℹ️ The **doc-fact-check** skill uses no Python scripts, so it works without any package install.
</details>

<details>
<summary><b>AWS Credentials (translate CLI only)</b></summary>

You need AWS credentials only when running `translate_pptx_cli.py` from a terminal.
Inside an agent (Kiro, Claude Code, Quick) you don't need credentials — the LLM handles translation directly.

**Standard AWS users**

```bash
# Option 1: AWS SSO (recommended)
aws sso login --profile my-profile
export AWS_PROFILE=my-profile

# Option 2: Static credentials
aws configure

# Option 3: Environment variables
export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...
export AWS_REGION=us-west-2

# Verify
aws sts get-caller-identity
```

**Amazon employees**

Use your internal credential tool to set AWS credentials before running the CLI. See your team's internal docs for details.

```bash
aws sts get-caller-identity   # Should print your identity
```

> 💡 **Required permissions:** `translate_pptx_cli.py` calls only **Amazon Bedrock** (`bedrock:InvokeModel`). A Bedrock-enabled account with access to `anthropic.claude-*` models is enough.
</details>

<details>
<summary><b>Verify Installation</b></summary>

```bash
# Full environment check (after install)
./setup/test-setup.sh

# Individual checks
python3 -c "import docx; print(f'python-docx {docx.__version__}')"
python3 -c "import pptx; print(f'python-pptx {pptx.__version__}')"
python3 -c "import boto3; print(f'boto3 {boto3.__version__}')"  # CLI only
```
</details>

<details>
<summary><b>Testing scripts in venv</b></summary>

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

Quick smoke test (no venv):

```bash
python3 -c "import ast; ast.parse(open('scripts/generate_styled_docx.py').read()); print('✅ generate_styled_docx.py')"
python3 -c "import ast; ast.parse(open('scripts/translate_pptx_native.py').read()); print('✅ translate_pptx_native.py')"
python3 -c "import ast; ast.parse(open('scripts/translate_pptx_cli.py').read()); print('✅ translate_pptx_cli.py')"

ls -la ~/.kiro/skills/ | grep -E "doc-fact|md-to|translate|stop-slop"
ls -la ~/.claude/skills/ | grep -E "doc-fact|md-to|translate|stop-slop"
```
</details>

---

## 🤝 Contributing

1. Fork or branch from `main`
2. Add or modify skills following the format in [docs/skill-format.md](docs/skill-format.md)
3. Test with at least one agent (Kiro, Claude Code, or Quick)
4. Submit a PR with a description of what the skill does and which agents it supports

**Conventions:**
- Skill names: lowercase, hyphenated (`my-new-skill`)
- Script names: snake_case with suffix (`_native.py` or `_cli.py`)
- One SKILL.md per skill directory (entry point)
- Keep SKILL.md actionable — reference docs go in the `references/` subdirectory

---

## 📜 License

MIT — see [LICENSE](LICENSE).

---

<p align="center">
  <sub>Built with ❤️ by <a href="https://github.com/blackdog0403">Kwangyoung Kim</a> — AWS Solutions Architect</sub>
</p>
