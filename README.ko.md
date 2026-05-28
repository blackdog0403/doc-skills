<p align="center">
  <a href="./README.md">English</a> ·
  <a href="./README.ko.md"><strong>한국어</strong></a>
</p>

<p align="center">
  <h1 align="center">🧠 doc-skills</h1>
  <p align="center">
    문서 작업용 멀티 에이전트 AI 스킬 — <a href="https://kiro.dev">Kiro</a> · <a href="https://docs.anthropic.com/en/docs/claude-code">Claude Code</a> · <a href="https://aws.amazon.com/quick/desktop/">Amazon Quick Desktop</a>
  </p>
  <p align="center">
    <img src="https://img.shields.io/badge/agents-Kiro%20%7C%20Claude%20Code%20%7C%20Amazon%20Quick-blue" alt="Agents"/>
    <img src="https://img.shields.io/badge/skills-4-green" alt="Skills"/>
    <img src="https://img.shields.io/badge/license-MIT-brightgreen" alt="License"/>
    <img src="https://img.shields.io/badge/python-3.10%2B-yellow" alt="Python"/>
  </p>
</p>

AI 에이전트 지시문을 한 번 작성해 Kiro · Claude Code · Amazon Quick Desktop 세 도구에 동시 배포하는 통합 스킬 레포입니다. AWS Solutions Architect를 위해 만들었지만, 기술 문서를 작성하는 누구나 사용할 수 있습니다.

📖 **문서:** [docs/skill-format.md](docs/skill-format.md)

---

## 목차

- [🟢 Quick Desktop UI로 설치](#-quick-desktop-ui로-설치)
- [⚡ Quick Start (개발자용)](#-quick-start-개발자용)
- [📦 스킬 목록](#-스킬-목록)
- [🏗 아키텍처](#-아키텍처)
- [📁 레포 구조](#-레포-구조)
- [📖 에이전트별 사용 가이드](#-에이전트별-사용-가이드)
- [➕ 새 스킬 추가하기](#-새-스킬-추가하기)
- [🐍 Scripts](#-scripts)
- [🔧 사전 요구사항](#-사전-요구사항)
- [🤝 기여하기](#-기여하기)
- [📜 라이선스](#-라이선스)

---

## 🟢 Quick Desktop UI로 설치

git, 터미널, Python 설치 다 필요 없습니다. 앱 UI에서 ZIP을 임포트만 하면 됩니다.

1. [최신 릴리스](../../releases/latest)에서 ZIP **다운로드**:
   - `doc-skills-all-quick-*.zip` — 4개 스킬 한 번에 (권장)
   - 또는 개별 스킬 ZIP (`stop-slop-quick-*.zip`, `doc-fact-check-quick-*.zip` 등)
2. **Amazon Quick Desktop 열기** → 왼쪽 사이드바 하단 **Settings** 클릭
3. **Capabilities → Skills** 이동 후 **Upload** 클릭 (또는 패널에 ZIP 드래그)
4. 다운로드한 ZIP 선택 — Quick Desktop이 자동으로 압축 해제 후 등록
5. 새 대화에서 **사용해보기**:
   - `> AI 티 빼줘`
   - `> 이 문서 팩트체크해줘`
   - `> md를 docx로 변환해줘`

📖 스크린샷 포함 상세 가이드 (영문 + 한국어): [docs/INSTALL-QUICK.md](docs/INSTALL-QUICK.md)

> ℹ️ Kiro · Claude Code 사용자거나 `git pull` 자동 업데이트가 필요하면 아래 [Quick Start (개발자용)](#-quick-start-개발자용)로.

---

## ⚡ Quick Start (개발자용)

### 1. Clone

```bash
git clone git@github.com:blackdog0403/doc-skills.git ~/Documents/dev/doc-skills
cd ~/Documents/dev/doc-skills
```

### 2. 설치

```bash
chmod +x setup/*.sh

# 인터랙티브 설치 (권장)
./setup/install.sh
```

설치 스크립트가 하는 일:
1. ✅ 환경 점검 (Python, 패키지, 에이전트)
2. 📋 설치 대상 선택 (Kiro / Claude Code / Quick / CLI)
3. 🔗 진행률 표시와 함께 symlink 생성
4. ✓ 링크 검증

<details>
<summary>수동 설치 (개별 스크립트)</summary>

```bash
./setup/link-slash.sh     # Kiro + Claude Code 만
./setup/link-quick.sh     # Amazon Quick Desktop 만
./setup/install-cli.sh    # CLI 스크립트를 ~/.local/bin/ 으로
```
</details>

### 3. 사용

```
# Kiro 또는 Claude Code:
> /doc-fact-check report.md
> /md-to-docx meeting-notes.md
> /translate-pptx deck.pptx source:ko target:en
> /stop-slop draft.md

# Amazon Quick Desktop:
> 이 문서 팩트체크 해줘
> md를 docx로 변환해줘
> pptx 번역해줘
> AI 티 빼줘 / 문체 다듬어줘
```

---

## 📦 스킬 목록

| 스킬 | 하는 일 | 에이전트 | 사내 전용 여부 |
|-------|-------------|:------:|:---:|
| 🔍 **[doc-fact-check](skills/doc-fact-check/)** | 기술 문서의 사실 주장을 AWS 공식 출처에 대조해 검증 — 품질 점수와 함께 교정 보고서 생성. | Kiro · CC · Quick | 🌐 Public |
| 📄 **[md-to-docx](skills/md-to-docx/)** | Markdown을 AWS Orange 브랜드 컬러, 배지, 표가 적용된 Word(.docx)로 변환. | Kiro · CC · Quick | 🌐 Public |
| 🌐 **[translate-pptx](skills/translate-pptx/)** | LLM 기반으로 PowerPoint 번역 — 외부 API 호출 없음. | Kiro · CC · Quick | 🌐 Public |
| ✂️ **[stop-slop](skills/stop-slop/)** | 산문에서 AI 작문 패턴 제거 — 군더더기 표현, 형식적 구조, 수동태, 가짜 주어, 단조로운 리듬. [hardikpandya/stop-slop](https://github.com/hardikpandya/stop-slop) 기반. | Kiro · CC · Quick | 🌐 Public |

### 왜 doc-skills인가?

| 특징 | 설명 |
|---------|-------------|
| 🔄 멀티 에이전트 배포 | 스킬 하나가 Kiro · Claude Code · Amazon Quick Desktop에서 모두 작동 |
| 📎 Symlink 아키텍처 | `git pull` 한 번으로 모든 에이전트 일괄 업데이트 — 수동 복사 없음 |
| 🐍 스크립트 분리 | 지시문과 별개로 Python 코드 버전 관리 |
| 🧪 테스트 가능 | 스크립트는 `tests/`로 CI/CD 검증 |
| 📦 휴대성 | 클론 → 설치 → `/slash-command`로 바로 사용 |
| 🔒 비밀 없음 | 스킬은 공개 API나 로컬 처리만 사용 — 자격 증명을 레포에 두지 않음 |

---

## 🏗 아키텍처

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

### 왜 SKILL.md 두 가지 버전이 필요한가?

| | `skills/` (Slash Command) | `quick/` (Amazon Quick Desktop) |
|---|---|---|
| **호출** | `/skill-name` | 자연어 트리거 |
| **Frontmatter** | `name` + `description` + `allowed-tools` | + `display_name`, `icon`, `trigger`, `inputs`, `tools` |
| **Tool 이름** | `Bash`, `Read`, `Write` | `run_python`, `file_read`, `file_write` |
| **본문** | 동일한 지시문 | 동일 (Quick tool 이름 사용) |

Kiro와 Claude Code는 [Agent Skills 오픈 표준](https://kiro.dev/docs/cli/skills/)을 따라 같은 파일을 쓸 수 있습니다. Amazon Quick Desktop은 UI 메타데이터가 추가된 상위 호환 포맷입니다.

---

## 📁 레포 구조

```
doc-skills/
├── skills/                          # Kiro + Claude Code 공유
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
├── quick/                           # Amazon Quick Desktop (확장 frontmatter)
│   ├── doc-fact-check/
│   │   └── SKILL.md
│   ├── md-to-docx/
│   │   ├── SKILL.md
│   │   └── scripts/                 #   → scripts/ 로 symlink
│   ├── translate-pptx/
│   │   ├── SKILL.md
│   │   └── scripts/                 #   → scripts/ 로 symlink
│   └── stop-slop/
│       ├── SKILL.md
│       └── references/              #   → skills/stop-slop/references/ 로 symlink
│
├── scripts/                         # 🐍 중앙 Python 코드
│   ├── generate_styled_docx.py      #   32KB — MD→DOCX 변환기
│   ├── translate_pptx_native.py     #   11KB — 샌드박스 안전 PPTX 처리
│   ├── translate_pptx_cli.py        #   30KB — 독립 실행 (boto3)
│   └── tests/
│       └── test_placeholder.py
│
├── setup/                           # 설치 스크립트
│   ├── install.sh                   #   인터랙티브 설치 스크립트
│   ├── link-slash.sh                #   Kiro + Claude Code
│   ├── link-quick.sh                #   Amazon Quick Desktop
│   ├── install-cli.sh               #   CLI을 ~/.local/bin/ 으로
│   └── test-setup.sh                #   설치 검증
│
├── docs/
│   └── skill-format.md              # 멀티 에이전트 스킬 작성법
├── LICENSE                          # MIT
├── .gitignore
└── README.md                        # 영문판
```

---

## 📖 에이전트별 사용 가이드

### <img src="https://kiro.dev/favicon.ico" width="16"/> Kiro

스킬은 `~/.kiro/skills/`에서 자동 인식됩니다. `link-slash.sh` 실행 후:

```
# Slash command로 직접 호출
> /translate-pptx deck.pptx source:ko target:en
> /md-to-docx report.md
> /doc-fact-check whitepaper.md

# 의도를 자연어로 표현하면 Kiro가 description으로 매칭
> 이 발표자료 영어로 번역해줘
> 이 문서 팩트체크해줘
```

**Kiro 관련 메모:**
- 스킬이 `Bash` tool을 쓰므로 Kiro가 셸 명령을 직접 실행
- 큰 문서용 `references/` 서브디렉토리 지원
- 로드된 스킬 확인: `/context show`

### <img src="https://code.claude.com/favicon.ico" width="16"/> Claude Code

스킬은 `~/.claude/skills/`에서 자동 인식됩니다. `link-slash.sh` 실행 후:

```
# Slash command (Kiro와 동일)
> /translate-pptx deck.pptx source:ko target:en
> /md-to-docx meeting-notes.md
> /doc-fact-check report.md scope:latency output:fix

# 또는 description 기반 자동 호출
> Translate this Korean deck to English
> Convert this markdown to a styled Word doc
```

**Claude Code 관련 메모:**
- `allowed-tools` 필드로 tool을 사전 승인 — 확인 프롬프트 없음
- SKILL.md 안에서 `!`backtick`` 으로 동적 컨텍스트 주입 가능
- `context: fork`로 서브에이전트 컨텍스트에서 실행 가능
- 프로젝트 레벨 스킬(`.claude/skills/` 레포 루트)이 글로벌보다 우선

### 🖥️ Amazon Quick Desktop

스킬은 `~/.quickwork/profiles/federate-prod/skills/`에서 로드됩니다. `link-quick.sh` 실행 후:

```
# 자연어 트리거 (한국어/영어)
> 이 문서 팩트체크 해줘
> 이 마크다운 워드로 변환해줘
> pptx 번역해줘 (한국어에서 영어로)
> translate-pptx 가지고 이 파일 번역해
```

**Amazon Quick Desktop 관련 메모:**
- `trigger:` 필드로 활성화 (slash command 아님)
- `inputs:`로 구조화된 파라미터 정의 (UI에 표시됨)
- `tools:`는 Quick tool 이름(`run_python`, `file_write` 등) 사용 필수
- 스킬 폴더 안의 `scripts/` 서브디렉토리는 자동 번들링
- `open_in_session_tab`으로 생성 파일 라이브 미리보기 지원

---

## ➕ 새 스킬 추가하기

1. **Slash command 버전 작성:**
   ```bash
   mkdir skills/my-new-skill
   ```
   `skills/my-new-skill/SKILL.md` 작성:
   ```yaml
   ---
   name: my-new-skill
   description: |
     무엇을 하는 스킬인지, 언제 활성화되는지.
   allowed-tools: [Bash, Read, Write]
   ---

   # 지시문 작성...
   ```

2. **Quick 버전 작성** (선택):
   ```bash
   mkdir quick/my-new-skill
   ```
   Quick 전용 frontmatter 추가 (`display_name`, `icon`, `trigger`, `tools`).

3. **스크립트 추가** (필요 시):
   ```bash
   # 샌드박스 안전 버전
   scripts/my_script_native.py
   # CLI 버전 (boto3/네트워크 필요 시)
   scripts/my_script_cli.py
   ```

4. **등록:**
   ```bash
   ./setup/link-slash.sh    # 새 스킬 자동 인식
   ./setup/link-quick.sh    # Quick 버전 있으면
   ```

5. **테스트:**
   ```
   # Kiro 또는 Claude Code:
   > /my-new-skill
   ```

전체 포맷 레퍼런스는 [docs/skill-format.md](docs/skill-format.md)에 있습니다.

---

## 🐍 Scripts

| 스크립트 | 종류 | 크기 | 사용처 | 설명 |
|--------|:----:|-----:|---------|-------------|
| `generate_styled_docx.py` | CLI | 32KB | md-to-docx | Markdown → AWS Orange 스타일·배지·표가 적용된 Word |
| `translate_pptx_native.py` | Sandbox | 11KB | translate-pptx | PPTX 텍스트 추출, 폰트 정규화 (네트워크 미사용) |
| `translate_pptx_cli.py` | CLI | 30KB | translate-pptx | AWS Bedrock(Claude) 기반 독립 번역기 |

**스크립트 종류:**
- **Sandbox** — 네트워크 없음, boto3 없음. Kiro와 Quick의 샌드박스 환경에서 안전.
- **CLI** — boto3, AWS 자격 증명, 네트워크 접근이 필요할 수 있음. 터미널 직접 사용을 위해 `~/.local/bin/`에 설치.

---

## 🔧 사전 요구사항

### 시스템 요구사항

| 항목 | 버전 | 확인 명령 | 비고 |
|-------------|---------|-------|-------|
| **macOS / Linux** | — | — | Windows는 WSL2 사용 |
| **Python** | 3.10+ | `python3 --version` | macOS: `brew install python@3.12` |
| **Git** | 2.x+ | `git --version` | Symlink 추적용 |
| **Kiro** | 최신 | `kiro --version` | [kiro.dev](https://kiro.dev) |
| **Claude Code** | 최신 | `claude --version` | [code.claude.com](https://code.claude.com) |
| **Amazon Quick Desktop** | 최신 | — | 사내 배포 앱 |

<details>
<summary><b>Python 의존성</b></summary>

| 패키지 | PyPI 이름 | 버전 | 사용처 | 용도 |
|---------|-----------|---------|---------|---------|
| `python-docx` | `python-docx` | ≥0.8.11 | `generate_styled_docx.py` | Word 문서 생성 (.docx) |
| `python-pptx` | `python-pptx` | ≥0.6.21 | `translate_pptx_native.py`, `translate_pptx_cli.py` | PPTX 읽기/쓰기 |
| `boto3` | `boto3` | ≥1.28 | `translate_pptx_cli.py` **만** | AWS Bedrock 호출 (CLI 전용) |
| `pytest` | `pytest` | ≥7.0 | `scripts/tests/` | 테스트 실행 (개발 시) |

**Option A: venv (권장, 격리 환경)**
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

**Option C: 최소 설치 (스킬만 사용, 스크립트 미사용)**
```bash
# Python 패키지 설치 불필요.
# SKILL.md만 읽으면 되므로 link-slash.sh만 실행하면 끝.
./setup/link-slash.sh
```

> ℹ️ **doc-fact-check** 스킬은 Python 스크립트를 사용하지 않으므로 패키지 설치 없이 바로 사용 가능합니다.
</details>

<details>
<summary><b>AWS 자격 증명 (CLI 번역 전용)</b></summary>

`translate_pptx_cli.py`를 터미널에서 직접 실행할 때만 AWS 자격 증명이 필요합니다.
에이전트(Kiro · Claude Code · Quick) 안에서 사용할 때는 자격 증명이 필요 없습니다 — LLM이 직접 번역하기 때문입니다.

**일반 AWS 사용자**

```bash
# Option 1: AWS SSO (권장)
aws sso login --profile my-profile
export AWS_PROFILE=my-profile

# Option 2: Static credentials
aws configure

# Option 3: 환경 변수
export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...
export AWS_REGION=us-west-2

# 확인
aws sts get-caller-identity
```

**Amazon 사내 사용자**

사내 인증 도구로 AWS 자격 증명을 미리 설정해두세요. 자세한 방법은 조직 내부 문서를 참고하세요.

```bash
aws sts get-caller-identity   # 정상 출력 확인
```

> 💡 **필요 권한:** `translate_pptx_cli.py`는 **Amazon Bedrock**(`bedrock:InvokeModel`)만 호출합니다. Bedrock이 활성화된 계정 + `anthropic.claude-*` 모델 접근 권한이면 충분합니다.
</details>

<details>
<summary><b>설치 검증</b></summary>

```bash
# 전체 환경 검증 (설치 후)
./setup/test-setup.sh

# 개별 확인
python3 -c "import docx; print(f'python-docx {docx.__version__}')"
python3 -c "import pptx; print(f'python-pptx {pptx.__version__}')"
python3 -c "import boto3; print(f'boto3 {boto3.__version__}')"  # CLI 전용
```
</details>

<details>
<summary><b>venv에서 스크립트 테스트</b></summary>

배포 전에 격리된 가상 환경에서 스크립트를 테스트할 수 있습니다.

```bash
cd ~/Documents/dev/doc-skills

# venv 생성 및 활성화
python3 -m venv .venv
source .venv/bin/activate

# 의존성 설치
pip install python-docx python-pptx pytest

# 테스트 실행
pytest scripts/tests/ -v

# 개별 스크립트 수동 테스트
python3 scripts/generate_styled_docx.py test-input.md -o /tmp/test.docx
python3 -c "from scripts.translate_pptx_native import extract_texts; print('OK')"

# 끝나면 비활성화
deactivate
```

빠른 점검 (venv 없이):

```bash
python3 -c "import ast; ast.parse(open('scripts/generate_styled_docx.py').read()); print('✅ generate_styled_docx.py')"
python3 -c "import ast; ast.parse(open('scripts/translate_pptx_native.py').read()); print('✅ translate_pptx_native.py')"
python3 -c "import ast; ast.parse(open('scripts/translate_pptx_cli.py').read()); print('✅ translate_pptx_cli.py')"

ls -la ~/.kiro/skills/ | grep -E "doc-fact|md-to|translate|stop-slop"
ls -la ~/.claude/skills/ | grep -E "doc-fact|md-to|translate|stop-slop"
```
</details>

---

## 🤝 기여하기

1. `main`에서 fork 또는 branch
2. [docs/skill-format.md](docs/skill-format.md)에 따라 스킬 추가/수정
3. 최소 한 개 에이전트(Kiro · Claude Code · Quick)에서 테스트
4. 어떤 스킬이고 어떤 에이전트를 지원하는지 PR 설명에 적어 제출

**컨벤션:**
- 스킬 이름: 소문자, 하이픈 (`my-new-skill`)
- 스크립트 이름: snake_case + 접미사 (`_native.py` 또는 `_cli.py`)
- 스킬 디렉토리당 SKILL.md 하나 (진입점)
- SKILL.md는 실행 가능한 지시문 위주로 유지하고, 레퍼런스 문서는 `references/` 서브디렉토리에 둡니다

---

## 📜 라이선스

MIT — [LICENSE](LICENSE) 참고.

---

<p align="center">
  <sub>Built with ❤️ by <a href="https://github.com/blackdog0403">Kwangyoung Kim</a> — AWS Solutions Architect</sub>
</p>
