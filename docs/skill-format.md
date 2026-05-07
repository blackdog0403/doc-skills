# Multi-Agent SKILL.md Format Guide

## Overview

This repo maintains skills that work across three AI agents:
- **Kiro** — `.kiro/skills/{name}/SKILL.md`
- **Claude Code** — `.claude/skills/{name}/SKILL.md`
- **Amazon Quick** — `~/.quickwork/profiles/federate-prod/skills/{name}/SKILL.md`

## Directory Structure

```
doc-skills/
├── skills/          ← Kiro + Claude Code shared (slash command format)
├── quick/           ← Amazon Quick (additional frontmatter)
└── scripts/         ← Python code (referenced by both)
```

## Slash Command Format (skills/)

Kiro and Claude Code share an identical SKILL.md format:

```yaml
---
name: my-skill                          # Required (Kiro), Optional (CC uses dir name)
description: |                          # Required (both)
  What the skill does and when to activate it.
  Include trigger phrases for auto-activation.
allowed-tools: [Bash, Read, Write]      # Optional (CC only — Kiro ignores)
---

# Skill Title

Instructions in Markdown...
```

### Frontmatter Fields (Kiro + Claude Code)

| Field | Kiro | Claude Code | Notes |
|-------|:----:|:-----------:|-------|
| `name` | Required | Optional | Lowercase, hyphens only. CC uses dir name if omitted |
| `description` | Required | Recommended | Max ~1536 chars combined with when_to_use |
| `allowed-tools` | Ignored | Optional | Pre-approves tools (no confirmation prompt) |
| `when_to_use` | Ignored | Optional | Appended to description |
| `disable-model-invocation` | Ignored | Optional | Prevent auto-activation |

**Key insight:** Unknown fields are silently ignored by both. So a single file works for both agents.

## Amazon Quick Format (quick/)

Quick requires additional frontmatter:

```yaml
---
name: my-skill
display_name: My Skill                  # Human-readable name
icon: "🔧"                              # Emoji icon
description: "..."                      # What it does
trigger: keyword phrase                 # Auto-activation trigger
inputs:                                 # Structured inputs
  - name: file_path
    type: path
    required: true
tools: [run_python, file_write, ...]    # Quick tool names
---
```

### Quick Tool Names

| Kiro/CC Tool | Quick Tool |
|-------------|-----------|
| Bash | run_python / run_python_with_write |
| Read | file_read / file_read_docx / file_read_pdf |
| Write | file_write |
| Edit | file_edit |
| Grep | ripgrep |
| Glob | fdfind |
| Agent | start_task |
| WebFetch | url_fetch |
| WebSearch | web_search |

## Adding a New Skill

1. Create `skills/{name}/SKILL.md` with slash command format
2. Create `quick/{name}/SKILL.md` with Quick format (if needed)
3. Add Python scripts to `scripts/` (if needed)
4. Run `./setup/link-slash.sh` and `./setup/link-quick.sh`

## Scripts Convention

- **`{name}_native.py`** — Sandbox-safe, no network/boto3 (used by Quick + Kiro)
- **`{name}_cli.py`** — Standalone CLI, may use boto3/network (installed to ~/.local/bin/)
- Scripts are referenced from SKILL.md by relative path or `~/.local/bin/` path
