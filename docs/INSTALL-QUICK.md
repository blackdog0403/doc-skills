# Installing Skills for Amazon Quick Desktop

## 🇺🇸 English

### What You'll Need

- Amazon Quick Desktop installed and signed in
- The skill ZIP file (download from [Releases](../../releases))

### Installation via Quick Desktop UI

1. **Download** the ZIP file for the skill you want
   - Individual: `stop-slop-quick-*.zip`, `doc-fact-check-quick-*.zip`, etc.
   - All-in-one: `doc-skills-all-quick-*.zip`

2. **Open Amazon Quick Desktop**

3. **Go to Settings**
   - Click **Settings** at the bottom of the left sidebar

4. **Navigate to Capabilities → Skills**
   - Click **Capabilities**
   - Select the **Skills** tab

5. **Import the skill**
   - Click **Upload** (or drag & drop the ZIP into the Skills panel)
   - Select the downloaded ZIP file
   - The skill will be automatically extracted and registered

6. **Verify**
   - Start a new conversation
   - Type: "what skills do you have?" — your new skill should appear
   - Or try it directly: "stop slop this text" / "AI 티 빼줘"

### Available Skills

| ZIP File | Skill | What it does |
|----------|-------|--------------|
| `stop-slop-quick-*.zip` | ✂️ Stop Slop | Remove AI writing patterns from prose |
| `doc-fact-check-quick-*.zip` | 🔍 Document Fact Checker | Verify claims against AWS official sources |
| `md-to-docx-quick-*.zip` | 📄 Markdown to DOCX | Convert MD → styled Word document |
| `translate-pptx-quick-*.zip` | 🌐 Translate PPTX | Translate presentations between languages |
| `doc-skills-all-quick-*.zip` | 📦 All Skills | Everything in one package |

### Updating a Skill

1. Download the new version from [Releases](../../releases)
2. Go to **Settings → Capabilities → Skills**
3. Remove the old version (click the skill → **Remove**)
4. Import the new ZIP

### Uninstalling

1. Go to **Settings → Capabilities → Skills**
2. Click the skill you want to remove
3. Click **Remove**

### Alternative: Manual Installation (Advanced)

If you prefer manual installation or the UI import isn't available:

1. Unzip the downloaded file
2. Move the extracted folder to:

| OS | Path |
|----|------|
| **Mac** | `~/.quickwork/profiles/federate-prod/skills/` |
| **Windows** | `%USERPROFILE%\.quickwork\profiles\federate-prod\skills\` |

3. Restart Amazon Quick Desktop

> 💡 **Windows tip:** Press `Win+R`, paste `%USERPROFILE%\.quickwork\profiles\federate-prod\skills` and hit Enter to open the folder.

> 💡 **Mac tip:** In Finder, press `Cmd+Shift+G` and paste `~/.quickwork/profiles/federate-prod/skills/`

---

## 🇰🇷 한국어

### 준비물

- Amazon Quick Desktop 설치 및 로그인 완료
- 스킬 ZIP 파일 ([Releases](../../releases)에서 다운로드)

### Quick Desktop UI로 설치하기

1. **ZIP 파일 다운로드**
   - 개별: `stop-slop-quick-*.zip`, `doc-fact-check-quick-*.zip` 등
   - 전체: `doc-skills-all-quick-*.zip`

2. **Amazon Quick Desktop 열기**

3. **Settings 이동**
   - 왼쪽 사이드바 하단의 **Settings** 클릭

4. **Capabilities → Skills 탭 이동**
   - **Capabilities** 클릭
   - **Skills** 탭 선택

5. **스킬 임포트**
   - **Upload** 버튼 클릭 (또는 ZIP 파일을 Skills 패널에 드래그 & 드롭)
   - 다운로드한 ZIP 파일 선택
   - 자동으로 압축 해제 및 등록됨

6. **확인**
   - 새 대화를 시작
   - "what skills do you have?" 입력 — 새 스킬이 목록에 표시되면 성공
   - 바로 사용해보기: "AI 티 빼줘" / "이 문서 팩트체크해줘"

### 제공 스킬

| ZIP 파일 | 스킬 | 설명 |
|----------|------|------|
| `stop-slop-quick-*.zip` | ✂️ Stop Slop | AI가 쓴 티가 나는 문체 패턴 제거 |
| `doc-fact-check-quick-*.zip` | 🔍 문서 팩트체커 | AWS 공식 소스 기반 팩트 검증 |
| `md-to-docx-quick-*.zip` | 📄 MD → DOCX | 마크다운을 스타일링된 Word로 변환 |
| `translate-pptx-quick-*.zip` | 🌐 PPTX 번역 | 프레젠테이션 다국어 번역 |
| `doc-skills-all-quick-*.zip` | 📦 전체 | 모든 스킬 한 번에 |

### 업데이트

1. [Releases](../../releases)에서 새 버전 다운로드
2. **Settings → Capabilities → Skills** 이동
3. 기존 버전 제거 (스킬 클릭 → **Remove**)
4. 새 ZIP 임포트

### 삭제

1. **Settings → Capabilities → Skills** 이동
2. 제거할 스킬 클릭
3. **Remove** 클릭

### 수동 설치 (고급 사용자)

UI 임포트를 사용하지 않는 경우:

1. ZIP 압축 해제
2. 추출된 폴더를 아래 경로로 이동:

| OS | 경로 |
|----|------|
| **Mac** | `~/.quickwork/profiles/federate-prod/skills/` |
| **Windows** | `%USERPROFILE%\.quickwork\profiles\federate-prod\skills\` |

3. Amazon Quick Desktop 재시작

> 💡 **Windows 팁:** `Win+R` → `%USERPROFILE%\.quickwork\profiles\federate-prod\skills` 붙여넣기 → Enter

> 💡 **Mac 팁:** Finder에서 `Cmd+Shift+G` → `~/.quickwork/profiles/federate-prod/skills/` 붙여넣기
