import Foundation

// ═══════════════════════════════════════════════════════
// MARK: - Plugin Manifest (plugin.json)
// ═══════════════════════════════════════════════════════

/// 플러그인이 제공하는 확장 포인트 선언
public struct PluginManifest: Codable {
    public var name: String
    public var version: String
    public var description: String?
    public var author: String?

    // 의존성 선언 (다른 플러그인 ID + 최소 버전)
    public var requires: [PluginDependency]?

    // 확장 포인트
    public var contributes: PluginContributions?

    /// 플러그인 의존성 선언
    public struct PluginDependency: Codable, Equatable {
        public var pluginId: String        // 의존하는 플러그인 ID
        public var minVersion: String?     // 최소 버전 (semver, 옵션)
    }

    public struct PluginContributions: Codable {
        public var characters: String?         // "characters.json" 경로
        public var panels: [PanelDecl]?        // 커스텀 패널 (WebView)
        public var commands: [CommandDecl]?    // 명령어 (커맨드 팔레트 연동)
        public var statusBar: [StatusBarDecl]? // 상태바 위젯

        // ── 네이티브 확장 (JSON 선언으로 앱 내부 기능 제어) ──
        public var themes: [ThemeDecl]?        // 커스텀 테마 색상 프리셋
        public var furniture: [FurnitureDecl]? // 오피스 커스텀 가구
        public var officePresets: [OfficePresetDecl]? // 오피스 레이아웃 프리셋
        public var achievements: [AchievementDecl]?   // 커스텀 업적
        public var bossLines: [String]?        // 사장 대사 추가
        public var effects: [EffectDecl]?      // 인터랙티브 이펙트
    }

    /// 테마 프리셋 — 앱 전체 색상을 바꿈
    public struct ThemeDecl: Codable, Identifiable {
        public var id: String
        public var name: String            // "Monokai", "Solarized Dark" 등
        public var isDark: Bool
        public var accentHex: String       // 메인 accent 색상
        public var bgHex: String?          // 배경색 (옵션)
        public var cardHex: String?        // 카드 배경 (옵션)
        public var textHex: String?        // 텍스트 색상 (옵션)
        public var greenHex: String?
        public var redHex: String?
        public var yellowHex: String?
        public var purpleHex: String?
        public var cyanHex: String?
        public var useGradient: Bool?
        public var gradientStartHex: String?
        public var gradientEndHex: String?
        public var fontName: String?       // 커스텀 폰트
    }

    /// 오피스 가구
    public struct FurnitureDecl: Codable, Identifiable {
        public var id: String
        public var name: String
        public var sprite: [[String]]      // 2D 픽셀 배열 (hex 색상)
        public var width: Int              // 타일 단위
        public var height: Int
        public var zone: String?           // "mainOffice" | "pantry" | "meetingRoom"
    }

    /// 오피스 레이아웃 프리셋
    public struct OfficePresetDecl: Codable, Identifiable {
        public var id: String
        public var name: String
        public var description: String?
        public var tileMap: [[Int]]?       // 타일맵 (옵션)
        public var furniture: [FurniturePlacementDecl]?
    }

    public struct FurniturePlacementDecl: Codable {
        public var furnitureId: String
        public var col: Int
        public var row: Int
    }

    /// 커스텀 업적
    public struct AchievementDecl: Codable, Identifiable {
        public var id: String
        public var name: String
        public var description: String
        public var icon: String
        public var rarity: String
        public var xp: Int
    }

    /// 이펙트 — 이벤트 트리거 + 시각 효과
    public struct EffectDecl: Codable, Identifiable {
        public var id: String
        public var trigger: String         // PluginEventType rawValue
        public var type: String            // PluginEffectType rawValue
        public var config: [String: EffectValue]?
        public var enabled: Bool?
    }

    /// 커스텀 패널 — HTML/JS를 WKWebView로 렌더링
    public struct PanelDecl: Codable, Identifiable {
        public var id: String          // 고유 ID
        public var title: String       // 탭 제목
        public var icon: String?       // SF Symbol 이름
        public var entry: String       // HTML 파일 경로 (plugin 디렉토리 기준)
        public var position: String?   // "sidebar" | "panel" | "tab" (기본 "panel")
        public var width: Int?         // 고정 너비 (옵션)
        public var height: Int?        // 고정 높이 (옵션)
    }

    /// 명령어 — 스크립트 실행 + 커맨드 팔레트 등록
    public struct CommandDecl: Codable, Identifiable {
        public var id: String          // 고유 ID
        public var title: String       // 표시 이름
        public var icon: String?       // SF Symbol 이름
        public var script: String      // 실행할 스크립트 경로 (plugin 디렉토리 기준)
        public var keybinding: String? // 키바인딩 (옵션, 예: "cmd+shift+g")
    }

    /// 상태바 위젯
    public struct StatusBarDecl: Codable, Identifiable {
        public var id: String
        public var script: String      // JSON 출력하는 스크립트 ({"text": "...", "icon": "...", "color": "..."})
        public var interval: Int?      // 갱신 주기 (초, 기본 30)
    }
}
