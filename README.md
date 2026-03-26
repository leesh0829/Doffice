<p align="center">
  <img src="Doffice/Resources/Assets.xcassets/AppIcon.appiconset/icon_256x256@2x.png" width="128" height="128" alt="Doffice">
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

[최신 릴리스](https://github.com/jjunhaa0211/Doffice/releases/latest)에서 `Doffice-v0.0.22.zip` 다운로드 → 압축 해제 → `Doffice.app`을 Applications로 이동

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

## 버전 히스토리

| 버전 | 주요 변경 |
|------|----------|
| **v0.0.22** | 커스텀 단축키 시스템 (키 레코더, 충돌 감지, 카테고리별 설정) |
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
