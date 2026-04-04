# Windows Port Status

목표: macOS SwiftUI/AppKit/Xcode 앱과 사용자 체감상 동일한 Windows 포트를 만든다.

## 현재 구조

- `src/windows/MainView.tsx`
  macOS `Doffice/Sources/MainView.swift` 대응
- `src/windows/SidebarView.tsx`
  macOS `Doffice/Sources/SidebarView.swift` 대응
- `src/windows/TerminalAreaView.tsx`
  macOS `Doffice/Sources/TerminalAreaView.swift` 대응
- `src/windows/OfficeSceneView.tsx`
  macOS `Doffice/Sources/Office/OfficeSceneView.swift` 대응
- `src/windows/PixelStripView.tsx`
  macOS `Doffice/Sources/PixelStripView.swift` 대응
- `src/windows/GitPanelView.tsx`
  macOS `Doffice/Sources/GitPanelView.swift` 대응
- `src/theme/Theme.ts`
  macOS `Doffice/Sources/Theme.swift` 핵심 토큰 대응

## 아직 미완료

- 픽셀 오피스 렌더링 1:1 복제
- `Theme.swift` 전체 타이포/컴포넌트 시스템 이식
- 오버레이들 (`ActionCenterView`, `CommandPaletteView`, 설정/업적/캐릭터/리포트 등)
- 세션 저장/복원 형식 완전 호환
- 컨텍스트 메뉴/단축키/윈도우 동작 미세 복제

## 원칙

- 새로운 UI를 설계하지 않는다.
- 원본 mac 화면 구조와 상태 흐름을 기준으로 화면별로 포팅한다.
- 플랫폼 차이는 OS 통합 지점만 허용한다.
