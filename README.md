<p align="center">
  <img src="docs/doffice_run.gif?v=3" width="160" alt="Doffice Character">
</p>

<h1 align="center">Doffice (도피스)</h1>

<p align="center">
  <strong>Claude Code 세션을 시각적으로 관리하는 macOS 네이티브 앱</strong><br>
  <sub>AI 코딩 어시스턴트를 위한 픽셀 아트 오피스</sub>
</p>

<p align="center">
  <a href="https://github.com/jjunhaa0211/Doffice/releases/latest"><img src="https://img.shields.io/github/v/release/jjunhaa0211/Doffice?style=flat-square&color=blue" alt="Release"></a>
  <img src="https://img.shields.io/badge/platform-macOS%2014%2B-lightgrey?style=flat-square" alt="Platform">
  <img src="https://img.shields.io/badge/swift-5.0-orange?style=flat-square" alt="Swift">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-green?style=flat-square" alt="License"></a>
</p>

---

## 주요 기능

### 멀티 세션 관리
- 동시에 여러 Claude Code 세션을 운영하고 실시간 모니터링
- Grid / Single / Office / Strip **4가지 뷰 모드**
- Shift+클릭으로 세션 다중 선택 & 비교
- 세션 카드 우클릭 → Finder, 경로 복사, 터미널 열기

### 픽셀 아트 오피스
- 각 세션이 픽셀 캐릭터로 표현되는 가상 오피스
- 개발자, QA, 기획자, 디자이너, 리뷰어, SRE 등 **직업 시스템**
- 작업 상태에 따라 캐릭터가 자동으로 움직이고 행동
- 81종 캐릭터 수집, 300개 도전과제 & 레벨 시스템

### Git 클라이언트
- GitKraken 스타일 3패널 레이아웃 (사이드바 + 커밋 그래프 + 상세)
- 커밋 그래프 시각화 (레인, 머지 곡선, 태그 노드)
- stage / unstage / commit / branch / tag / stash
- Diff 뷰어 (추가/삭제 하이라이팅, Hunk 구분)

### 커스텀 테마 엔진
- **Hex 코드**로 강조 색상 자유 설정
- **그라데이션** 배경 지원 (시작/끝 색상)
- 시스템 폰트 목록에서 **커스텀 폰트** 선택 + 크기 조절
- JSON 파일로 테마 **내보내기/불러오기**
- 배경 밝기 기반 **자동 텍스트 대비** 처리

### 커스텀 단축키
- 모든 주요 기능에 대한 **사용자 정의 단축키** 매핑
- 키 레코더 UI — 원하는 키 조합을 직접 눌러서 캡처
- **충돌 감지** — 다른 기능 및 macOS 시스템 단축키와의 중복 경고
- 개별/전체 기본값 복원 및 할당 해제(Unassigned) 지원

### 실시간 추적 & 보안
- 토큰 사용량 (일간/주간) 실시간 모니터링 & 비용 한도
- 메뉴바 위젯으로 빠른 상태 확인
- 다국어 지원 (한국어 / English / 日本語)

---

## 설치

### Homebrew (권장)

```bash
brew tap jjunhaa0211/tap
brew install --cask doffice
```

### 수동 설치

[최신 릴리스](https://github.com/jjunhaa0211/Doffice/releases/latest)에서 `Doffice-v0.0.43.zip` 다운로드 → 압축 해제 → `Doffice.app`을 Applications로 이동

### 소스에서 빌드

```bash
git clone https://github.com/jjunhaa0211/Doffice.git
cd Doffice
open Doffice/Doffice.xcodeproj
# Xcode에서 Cmd+R로 빌드 & 실행
```

---

## 요구사항

| 항목 | 최소 사양 |
|------|----------|
| **macOS** | 14.0 (Sonoma) |
| **Claude Code** | `npm install -g @anthropic-ai/claude-code` |

---

## 키보드 단축키

> 모든 단축키는 **설정 → 단축키** 탭에서 자유롭게 변경할 수 있습니다.

| 단축키 | 동작 |
|--------|------|
| `⌘T` | 새 세션 |
| `⌘W` | 세션 닫기 |
| `⌘1~9` | 세션 전환 |
| `⌘R` | 세션 재시작 |
| `⌘P` | 커맨드 팔레트 |
| `⌘J` | 액션 센터 |
| `⌘\` | 분할 뷰 전환 |
| `⌘⇧O` | 오피스 뷰 전환 |
| `⌘⇧T` | 터미널 뷰 전환 |
| `⌘⇧E` | 세션 로그 내보내기 |
| `⌘K` | 터미널 지우기 |
| `⌘.` | 작업 취소 |

---

## 기술 스택

- **SwiftUI** — 네이티브 macOS UI
- **Canvas** — 픽셀 아트 렌더링 & Git 그래프
- **Combine** — 리액티브 상태 관리
- **NSEvent Monitor** — 동적 단축키 라우팅
- **Process/Pipe** — Git CLI 래핑
- **Claude Code CLI** — AI 세션 관리

---

## 플러그인 개발 & GitHub 배포 가이드

Doffice는 JSON 기반 플러그인 시스템을 지원합니다. 누구나 플러그인을 만들어 마켓플레이스에 등록할 수 있습니다.

### 플러그인 구조

```
my-plugin/
├── plugin.json          # 매니페스트 (필수)
├── characters.json      # 캐릭터 정의 (선택)
├── panel/index.html     # 커스텀 패널 (선택)
└── slash-commands/      # 슬래시 명령어 (선택)
```

### plugin.json 매니페스트

```json
{
  "name": "My Plugin",
  "version": "1.0.0",
  "description": "플러그인 설명",
  "author": "작성자",
  "requires": [
    { "pluginId": "other-plugin", "minVersion": "0.5.0" }
  ],
  "contributes": {
    "characters": "characters.json",
    "themes": [
      {
        "id": "my-theme",
        "name": "My Theme",
        "isDark": true,
        "accentHex": "5b9cf6",
        "bgHex": "1a1d23",
        "useGradient": true,
        "gradientStartHex": "1a1d23",
        "gradientEndHex": "2a2d35"
      }
    ],
    "effects": [
      {
        "id": "my-effect",
        "trigger": "onPromptSubmit",
        "type": "confetti",
        "config": { "count": 50, "duration": 3.0 },
        "enabled": true
      }
    ],
    "furniture": [
      {
        "id": "my-desk",
        "name": "커스텀 책상",
        "sprite": [["8B4513", "8B4513"], ["D2691E", "D2691E"]],
        "width": 2, "height": 2
      }
    ],
    "achievements": [
      {
        "id": "first-plugin",
        "name": "플러그인 마스터",
        "description": "첫 플러그인을 설치했습니다",
        "icon": "puzzlepiece.fill",
        "rarity": "rare",
        "xp": 100
      }
    ],
    "bossLines": ["새로운 사장 대사!"]
  }
}
```

### 지원하는 이펙트 타입

| 타입 | 설명 | 주요 config |
|------|------|-------------|
| `combo-counter` | 타이핑 콤보 카운터 | `decaySeconds`, `shakeOnMilestone` |
| `particle-burst` | 이모지 파티클 | `emojis`, `count`, `duration` |
| `screen-shake` | 화면 흔들기 | `intensity`, `duration` |
| `flash` | 색상 플래시 | `colorHex`, `duration` |
| `sound` | 시스템 사운드 | `name` |
| `toast` | 알림 토스트 | `text`, `icon`, `tint`, `duration` |
| `confetti` | 컨페티 효과 | `colors`, `count`, `duration` |
| `typewriter` | 타자기 텍스트 | `text`, `speed`, `colorHex`, `fontSize`, `position` |
| `progress-bar` | 프로그레스 바 | `label`, `barColorHex`, `duration` |
| `glow` | 테두리 글로우 | `colorHex`, `intensity`, `pulseSpeed`, `duration` |

### 이벤트 트리거

| 트리거 | 발동 시점 |
|--------|----------|
| `onPromptKeyPress` | 터미널 키 입력 |
| `onPromptSubmit` | 명령어 제출 |
| `onSessionComplete` | 세션 완료 |
| `onSessionError` | 세션 에러 |
| `onAchievementUnlock` | 업적 해제 |
| `onCharacterHire` | 캐릭터 고용 |
| `onLevelUp` | 레벨업 |

### GitHub에 플러그인 배포하기

**1. 플러그인 레포지토리 생성**

```bash
mkdir my-doffice-plugin && cd my-doffice-plugin
# plugin.json, characters.json 등 파일 작성
git init && git add -A && git commit -m "Initial plugin"
gh repo create my-doffice-plugin --public --push
```

**2. GitHub Release로 배포**

```bash
# tar.gz 아카이브 생성
tar -czf my-doffice-plugin-v1.0.0.tar.gz -C . plugin.json characters.json

# GitHub Release 생성
gh release create v1.0.0 my-doffice-plugin-v1.0.0.tar.gz \
  --title "v1.0.0" --notes "Initial release"
```

**3. Doffice 마켓플레이스에 등록** (registry.json에 PR)

```bash
# Doffice 레포를 포크
gh repo fork jjunhaa0211/Doffice --clone
cd Doffice
```

`registry.json`에 플러그인 항목 추가:

```json
{
  "id": "my-doffice-plugin",
  "name": "나의 플러그인",
  "author": "내 GitHub ID",
  "description": "플러그인 설명",
  "version": "1.0.0",
  "downloadURL": "https://github.com/USERNAME/my-doffice-plugin/releases/download/v1.0.0/my-doffice-plugin-v1.0.0.tar.gz",
  "characterCount": 3,
  "tags": ["characters", "theme", "effects"],
  "stars": 0
}
```

```bash
git add registry.json
git commit -m "Add my-doffice-plugin to registry"
gh pr create --title "Add my-doffice-plugin" --body "새 플러그인 등록 요청"
```

**4. 사용자 직접 설치 (마켓플레이스 없이)**

사용자는 설정 > 플러그인에서 아래 형식으로 직접 설치할 수 있습니다:
- **URL**: `https://github.com/USERNAME/REPO/releases/download/v1.0.0/plugin.tar.gz`
- **Homebrew**: `brew install formula-name` 또는 `user/tap/formula`
- **로컬**: `~/my-plugins/my-plugin`

### 의존성 선언

다른 플러그인에 의존하는 경우 `requires` 필드를 사용합니다:

```json
{
  "requires": [
    { "pluginId": "typing-combo-pack", "minVersion": "1.0.0" }
  ]
}
```

설치 시 의존성이 충족되지 않으면 경고가 표시됩니다.

---

## 버전 히스토리

| 버전 | 주요 변경 |
|------|----------|
| **v0.0.43** | 브라우저 세션 복원, Provider별 토큰 계산기, 하드코딩 20건 수정, 투명 창 수정 |
| v0.0.42 | 코드 모듈화 리팩토링, provider 전환 버그 수정, 브라우저 네비게이션 수정, CJK 말풍선 수정 |
| v0.0.41 | Gemini CLI 지원, 응답 렌더링 개선, provider 전환 안정화, UI 마스킹 |
| v0.0.40 | 안정화 릴리즈 — 설정 재시작, UI 오버플로, 사이드바 클릭 전면 수정 |
| v0.0.39 | 테마/언어/폰트 변경 재시작 크래시 수정, 패널 크기 축소, 탭 클릭 수정 |
| v0.0.38 | 사이드바 탭 클릭 불가 수정, Cmd+Delete 탭 닫기, 필터칩 오버플로 수정 |
| v0.0.37 | 회색 오버레이 렌더링 아티팩트 수정, compositingGroup 제거 |
| v0.0.36 | 테마/폰트/언어 변경 시 앱 재시작으로 안정성 확보, UI 오버플로 수정 |
| v0.0.35 | UI 안정화 — 패널 반응형 너비, 하드 클리핑, 레이아웃 오버플로 근절 |
| v0.0.34 | 캐릭터 패널 오버플로 수정 (overlay 구조 전환), 코드 고도화 |
| v0.0.33 | 오피스 캐릭터 패널 UI 겹침 수정, 신뢰 프롬프트 크래시 수정 |
| v0.0.32 | 신뢰 프롬프트 승인 시 크래시 수정 (dismiss 레이스 컨디션) |
| v0.0.31 | 신뢰 프롬프트 미표시·무한 로딩·크래시 수정 |
| v0.0.30 | 프로젝트 신뢰 경로 시스템, 신뢰 프롬프트 모달 오버레이 UI 개선 |
| v0.0.29 | Git 선택 커밋, 커밋/스태시 미리보기, 시트 충돌 방지, 새 세션 시트 레이아웃 안정화 |
| v0.0.28 | dofi 워크플로우 추가 |
| v0.0.22 | 커스텀 단축키 시스템 (키 레코더, 충돌 감지, 카테고리별 설정) |
| v0.0.21 | 커스텀 테마 엔진 (Hex 색상, 그라데이션, 폰트, JSON Import/Export) |
| v0.0.20 | 오피스 프리셋, 권한, 아키타입 로컬라이즈 |
| v0.0.19 | 완전 다국어 — 모든 UI 문자열 ko/en/ja |
| v0.0.10 | Doffice 리브랜딩, Git 클라이언트, UI 전면 개편 |
| v0.0.8 | 오피스 뷰, 다크/라이트 모드 |
| v0.0.1 | 최초 릴리스 (MyWorkStudio) |

---

## 라이선스

MIT

---

<p align="center">
  <sub>Built with Claude Code + SwiftUI</sub>
</p>

asdfasdf
