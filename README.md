<p align="center">
  <img src="Doffice/Resources/Assets.xcassets/AppIcon.appiconset/icon_256x256@2x.png" width="128" height="128" alt="Doffice">
</p>

<h1 align="center">Doffice (도피스)</h1>

<p align="center">
  <strong>Claude Code 세션을 시각적으로 관리하는 macOS 네이티브 앱</strong>
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
- 동시에 여러 Claude Code 세션을 운영하고 실시간으로 모니터링
- Grid / Single / Office / Strip 4가지 뷰 모드
- Shift+클릭으로 원하는 세션만 골라 멀티 그리드 비교
- 세션 카드 우클릭 → Finder 열기, 경로 복사, 터미널 열기

### 픽셀 아트 오피스
- 각 세션이 픽셀 캐릭터로 표현되는 가상 오피스
- 개발자, QA, 기획자, 디자이너, 리뷰어, 보고자, SRE 등 직업 시스템
- 작업 상태에 따라 캐릭터가 자동으로 움직이고 행동
- 적응형 FPS (활성 24fps / 유휴 6fps)

### Git 클라이언트 (v3.0 신규)
- GitKraken 스타일 3패널 레이아웃 (사이드바 + 커밋 그래프 + 상세)
- 커밋 그래프 시각화 (레인, 머지 곡선, 태그 다이아몬드 노드)
- 직접 Git 작업: stage / unstage / commit / branch / tag / stash
- 파일 선택 커밋 (체크박스로 원하는 파일만 골라서 커밋)
- Diff 뷰어 (추가/삭제 하이라이팅, Hunk 구분)
- 충돌 감지 및 해결 UI
- 모든 Git 작업에 토스트 알림으로 결과 피드백

### 실시간 추적
- 토큰 사용량 (일간/주간) 실시간 모니터링
- 비용 추산 및 한도 설정
- 메뉴바 위젯으로 빠른 상태 확인

### 보고서 관리
- 보고자 역할 캐릭터가 자동 생성하는 Markdown 보고서
- 보고서 열람, Finder 열기, 경로 복사, 삭제 기능
- 프로젝트별 보고서 정리

### 게임 요소
- 81종 캐릭터 수집 (사람, 고양이, 강아지, 로봇, 드래곤 등 18종족)
- 300개 도전과제 & 레벨 시스템
- 악세서리 커스터마이징

---

## 설치

### Homebrew (권장)

```bash
brew tap jjunhaa0211/tap
brew install --cask doffice
```

> 기존 MyWorkStudio 사용자: `brew uninstall --cask myworkstudio && brew install --cask doffice`

### 수동 설치

1. [최신 릴리스](https://github.com/jjunhaa0211/Doffice/releases/latest)에서 `Doffice-vX.X.X.zip` 다운로드
2. 압축 해제 후 `Doffice.app`을 Applications 폴더로 이동

### 소스에서 빌드

```bash
git clone https://github.com/jjunhaa0211/Doffice.git
cd Doffice
open Doffice/Doffice.xcodeproj
# Xcode에서 Cmd+R로 빌드 & 실행
```

---

## 요구사항

- **macOS 14.0** (Sonoma) 이상
- **Claude Code** CLI 설치 필요

```bash
npm install -g @anthropic-ai/claude-code
```

---

## 키보드 단축키

| 단축키 | 동작 |
|--------|------|
| `Cmd+T` | 새 세션 |
| `Cmd+W` | 세션 닫기 |
| `Cmd+1~9` | 세션 전환 |
| `Cmd+R` | 새로고침 |
| `Cmd+P` | 커맨드 팔레트 |
| `Cmd+\` | 사이드바 토글 |
| `Cmd+Shift+E` | 로그 내보내기 |

---

## 기술 스택

- **SwiftUI** — 네이티브 macOS UI
- **Canvas** — 픽셀 아트 렌더링 & Git 그래프
- **Combine** — 리액티브 상태 관리
- **Process/Pipe** — Git CLI 래핑
- **Claude Code CLI** — AI 세션 관리

---

## 버전 히스토리

| 버전 | 주요 변경 |
|------|----------|
| **v3.0.0** | Doffice 리브랜딩, Git 클라이언트, UI 전면 개선 |
| v2.1.0 | Raw 터미널 모드, 세션 영속화 강화 |
| v2.0.1 | 오피스 뷰, 다크/라이트 모드 |
| v1.5.5 | 다크/라이트 모드 최적화 |
| v1.0.0 | 최초 릴리스 |

---

## 라이선스

MIT

---

<p align="center">
  <sub>Built with Claude Code + SwiftUI</sub>
</p>
