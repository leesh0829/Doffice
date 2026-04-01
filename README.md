<p align="center">
  <img src="https://raw.githubusercontent.com/jjunhaa0211/Doffice/main/docs/hero.gif" width="160" alt="Doffice Character">
</p>

<h1 align="center">Doffice (도피스)</h1>

<p align="center">
  <strong>AI 코딩 어시스턴트를 위한 비주얼 워크스페이스</strong><br>
  <sub>Claude · Codex · Gemini — 멀티 에이전트를 픽셀 아트 오피스에서 관리하세요</sub>
</p>

<p align="center">
  <a href="https://github.com/jjunhaa0211/Doffice/releases/latest"><img src="https://img.shields.io/github/v/release/jjunhaa0211/Doffice?style=flat-square&color=blue" alt="Release"></a>
  <img src="https://img.shields.io/badge/platform-macOS%2014%2B-lightgrey?style=flat-square" alt="Platform">
  <img src="https://img.shields.io/badge/swift-5.0-orange?style=flat-square" alt="Swift">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-green?style=flat-square" alt="License"></a>
</p>

---

## 한눈에 보기

> 여러 AI 에이전트가 동시에 코드를 작성하는 모습을 **픽셀 아트 오피스**에서 실시간으로 확인하세요.

| 멀티 에이전트 | 픽셀 오피스 | Git 클라이언트 |
|:---:|:---:|:---:|
| Claude, Codex, Gemini를 하나의 앱에서 | 세션마다 캐릭터가 일하는 가상 사무실 | 내장 Git — 커밋, 브랜치, diff까지 |

---

## 주요 기능

### 🤖 멀티 AI 에이전트

Claude Code · OpenAI Codex · Gemini CLI를 **하나의 워크스페이스**에서 운영합니다. 프로젝트마다 다른 AI를 배정하고, 동시에 여러 세션을 실시간 모니터링하세요.

- Grid · Single · Office · Strip — **4가지 뷰 모드**
- 세션별 모델·권한·예산 개별 설정
- Shift+클릭 다중 선택 & 비교

### 🏢 픽셀 아트 오피스

각 AI 세션이 **픽셀 캐릭터**로 표현됩니다. 작업 상태에 따라 캐릭터가 움직이고, 생각하고, 코드를 작성합니다.

- 개발자 · QA · 기획자 · 디자이너 · SRE 등 **직업 시스템**
- 81종 캐릭터 수집 · 300개 도전과제 · 레벨업
- 가구 배치 & 오피스 커스터마이징

### 🔀 내장 Git 클라이언트

별도 Git 앱 없이 Doffice 안에서 모든 Git 작업을 수행합니다.

- 커밋 그래프 시각화 (레인, 머지 곡선, 태그)
- Stage · Commit · Branch · Tag · Stash · Diff
- Blame · 파일 히스토리 · 충돌 해결 UI

### ⏪ 프롬프트 히스토리

AI에게 보낸 모든 요청과 그로 인한 **파일 변경사항을 추적**합니다. 원하는 시점으로 되돌릴 수 있습니다.

- 프롬프트별 변경 파일 목록 & diff 확인
- 원클릭 되돌리기 (git 기반 복원)

### 🎨 커스텀 테마 & 단축키

- Hex 색상 · 그라데이션 · 커스텀 폰트 — JSON으로 내보내기/불러오기
- 모든 기능에 **사용자 정의 단축키** 매핑 (충돌 감지 포함)

### 🔒 보안 & 모니터링

- 토큰 사용량 (일간/주간) 실시간 추적 & 비용 한도 설정
- 위험 명령어 감지 · 민감 파일 접근 경고
- 메뉴바 위젯 · 다국어 (한국어 / English / 日本語)

---

## 설치

### Homebrew (권장)

```bash
brew tap jjunhaa0211/tap
brew install --cask doffice
```

### 수동 설치

[최신 릴리스](https://github.com/jjunhaa0211/Doffice/releases/latest)에서 `.zip` 다운로드 → 압축 해제 → `Doffice.app`을 Applications로 이동

### 소스에서 빌드

```bash
git clone https://github.com/jjunhaa0211/Doffice.git
cd Doffice
open Doffice/Doffice.xcodeproj
# Xcode에서 Cmd+R
```

---

## 요구사항

| 항목 | 최소 사양 |
|------|----------|
| **macOS** | 14.0 (Sonoma) |
| **AI CLI** | 아래 중 하나 이상 설치 |

```bash
# Claude Code
npm install -g @anthropic-ai/claude-code

# OpenAI Codex (선택)
npm install -g @openai/codex

# Gemini CLI (선택)
npm install -g @google/gemini-cli
```

---

## 키보드 단축키

> 모든 단축키는 **설정 → 단축키**에서 변경할 수 있습니다.

| 단축키 | 동작 | 단축키 | 동작 |
|--------|------|--------|------|
| `⌘T` | 새 세션 | `⌘P` | 커맨드 팔레트 |
| `⌘W` | 세션 닫기 | `⌘J` | 액션 센터 |
| `⌘1~9` | 세션 전환 | `⌘K` | 터미널 지우기 |
| `⌘R` | 세션 재시작 | `⌘.` | 작업 취소 |

---

## 플러그인

Doffice는 JSON 기반 플러그인 시스템을 지원합니다. 캐릭터 · 테마 · 이펙트 · 가구를 추가할 수 있습니다.

<details>
<summary><strong>플러그인 개발 가이드</strong></summary>

### 구조

```
my-plugin/
├── plugin.json          # 매니페스트 (필수)
├── characters.json      # 캐릭터 정의 (선택)
├── panel/index.html     # 커스텀 패널 (선택)
└── slash-commands/      # 슬래시 명령어 (선택)
```

### plugin.json

```json
{
  "name": "My Plugin",
  "version": "1.0.0",
  "description": "플러그인 설명",
  "author": "작성자",
  "contributes": {
    "characters": "characters.json",
    "themes": [{ "id": "my-theme", "name": "My Theme", "isDark": true, "accentHex": "5b9cf6" }],
    "effects": [{ "id": "my-effect", "trigger": "onPromptSubmit", "type": "confetti" }],
    "furniture": [{ "id": "my-desk", "name": "커스텀 책상", "width": 2, "height": 2 }]
  }
}
```

### 이펙트 타입

| 타입 | 설명 |
|------|------|
| `confetti` | 컨페티 효과 |
| `particle-burst` | 이모지 파티클 |
| `screen-shake` | 화면 흔들기 |
| `combo-counter` | 타이핑 콤보 |
| `flash` · `glow` · `toast` · `sound` | 시각/청각 피드백 |

### 배포

```bash
# GitHub Release로 배포
tar -czf my-plugin-v1.0.0.tar.gz -C . plugin.json characters.json
gh release create v1.0.0 my-plugin-v1.0.0.tar.gz

# Doffice 마켓플레이스 등록 → registry.json에 PR
```

사용자는 **설정 → 플러그인**에서 URL · Homebrew · 로컬 경로로 직접 설치할 수도 있습니다.

</details>

---

## 버전 히스토리

| 버전 | 주요 변경 |
|------|----------|
| **v0.0.43** | 브라우저 세션 복원, Provider별 토큰 계산기, 투명 창 수정 |
| v0.0.42 | 코드 모듈화 리팩토링, provider 전환 버그 수정 |
| v0.0.41 | Gemini CLI 지원, 응답 렌더링 개선 |
| v0.0.40 | 안정화 — 설정 재시작, UI 오버플로 수정 |
| v0.0.22 | 커스텀 단축키 시스템 |
| v0.0.21 | 커스텀 테마 엔진 |
| v0.0.19 | 완전 다국어 (ko/en/ja) |
| v0.0.10 | Git 클라이언트, UI 전면 개편 |
| v0.0.1 | 최초 릴리스 |

---

## 라이선스

MIT

---

<p align="center">
  <sub>Built with SwiftUI · Powered by Claude Code, Codex & Gemini</sub>
</p>
