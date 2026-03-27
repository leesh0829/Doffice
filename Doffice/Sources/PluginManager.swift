import Foundation
import SwiftUI
import WebKit

// ═══════════════════════════════════════════════════════
// MARK: - Plugin Manifest (plugin.json)
// ═══════════════════════════════════════════════════════

/// 플러그인이 제공하는 확장 포인트 선언
struct PluginManifest: Codable {
    var name: String
    var version: String
    var description: String?
    var author: String?

    // 확장 포인트
    var contributes: PluginContributions?

    struct PluginContributions: Codable {
        var characters: String?         // "characters.json" 경로
        var panels: [PanelDecl]?        // 커스텀 패널 (WebView)
        var commands: [CommandDecl]?    // 명령어 (커맨드 팔레트 연동)
        var statusBar: [StatusBarDecl]? // 상태바 위젯

        // ── 네이티브 확장 (JSON 선언으로 앱 내부 기능 제어) ──
        var themes: [ThemeDecl]?        // 커스텀 테마 색상 프리셋
        var furniture: [FurnitureDecl]? // 오피스 커스텀 가구
        var officePresets: [OfficePresetDecl]? // 오피스 레이아웃 프리셋
        var achievements: [AchievementDecl]?   // 커스텀 업적
        var bossLines: [String]?        // 사장 대사 추가
        var effects: [EffectDecl]?      // 인터랙티브 이펙트
    }

    /// 테마 프리셋 — 앱 전체 색상을 바꿈
    struct ThemeDecl: Codable, Identifiable {
        var id: String
        var name: String            // "Monokai", "Solarized Dark" 등
        var isDark: Bool
        var accentHex: String       // 메인 accent 색상
        var bgHex: String?          // 배경색 (옵션)
        var cardHex: String?        // 카드 배경 (옵션)
        var textHex: String?        // 텍스트 색상 (옵션)
        var greenHex: String?
        var redHex: String?
        var yellowHex: String?
        var purpleHex: String?
        var cyanHex: String?
        var useGradient: Bool?
        var gradientStartHex: String?
        var gradientEndHex: String?
        var fontName: String?       // 커스텀 폰트
    }

    /// 오피스 가구
    struct FurnitureDecl: Codable, Identifiable {
        var id: String
        var name: String
        var sprite: [[String]]      // 2D 픽셀 배열 (hex 색상)
        var width: Int              // 타일 단위
        var height: Int
        var zone: String?           // "mainOffice" | "pantry" | "meetingRoom"
    }

    /// 오피스 레이아웃 프리셋
    struct OfficePresetDecl: Codable, Identifiable {
        var id: String
        var name: String
        var description: String?
        var tileMap: [[Int]]?       // 타일맵 (옵션)
        var furniture: [FurniturePlacementDecl]?
    }

    struct FurniturePlacementDecl: Codable {
        var furnitureId: String
        var col: Int
        var row: Int
    }

    /// 커스텀 업적
    struct AchievementDecl: Codable, Identifiable {
        var id: String
        var name: String
        var description: String
        var icon: String
        var rarity: String
        var xp: Int
    }

    /// 이펙트 — 이벤트 트리거 + 시각 효과
    struct EffectDecl: Codable, Identifiable {
        var id: String
        var trigger: String         // PluginEventType rawValue
        var type: String            // PluginEffectType rawValue
        var config: [String: EffectValue]?
        var enabled: Bool?
    }

    /// 커스텀 패널 — HTML/JS를 WKWebView로 렌더링
    struct PanelDecl: Codable, Identifiable {
        var id: String          // 고유 ID
        var title: String       // 탭 제목
        var icon: String?       // SF Symbol 이름
        var entry: String       // HTML 파일 경로 (plugin 디렉토리 기준)
        var position: String?   // "sidebar" | "panel" | "tab" (기본 "panel")
        var width: Int?         // 고정 너비 (옵션)
        var height: Int?        // 고정 높이 (옵션)
    }

    /// 명령어 — 스크립트 실행 + 커맨드 팔레트 등록
    struct CommandDecl: Codable, Identifiable {
        var id: String          // 고유 ID
        var title: String       // 표시 이름
        var icon: String?       // SF Symbol 이름
        var script: String      // 실행할 스크립트 경로 (plugin 디렉토리 기준)
        var keybinding: String? // 키바인딩 (옵션, 예: "cmd+shift+g")
    }

    /// 상태바 위젯
    struct StatusBarDecl: Codable, Identifiable {
        var id: String
        var script: String      // JSON 출력하는 스크립트 ({"text": "...", "icon": "...", "color": "..."})
        var interval: Int?      // 갱신 주기 (초, 기본 30)
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - Plugin Event / Effect Types
// ═══════════════════════════════════════════════════════

enum PluginEventType: String, Codable {
    case onPromptKeyPress
    case onPromptSubmit
    case onSessionComplete
    case onSessionError
    case onAchievementUnlock
    case onCharacterHire
    case onLevelUp
}

enum PluginEffectType: String, Codable {
    case comboCounter = "combo-counter"
    case particleBurst = "particle-burst"
    case screenShake = "screen-shake"
    case flash
    case sound
    case toast
    case confetti
}

/// JSON config 값 (String / Int / Double / Bool / [String])
enum EffectValue: Codable, Equatable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case stringArray([String])

    var stringValue: String? { if case .string(let v) = self { return v }; return nil }
    var intValue: Int? { if case .int(let v) = self { return v }; return nil }
    var doubleValue: Double? {
        switch self { case .double(let v): return v; case .int(let v): return Double(v); default: return nil }
    }
    var boolValue: Bool? { if case .bool(let v) = self { return v }; return nil }
    var stringArrayValue: [String]? { if case .stringArray(let v) = self { return v }; return nil }

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let v = try? c.decode(Bool.self) { self = .bool(v) }
        else if let v = try? c.decode(Int.self) { self = .int(v) }
        else if let v = try? c.decode(Double.self) { self = .double(v) }
        else if let v = try? c.decode([String].self) { self = .stringArray(v) }
        else { self = .string(try c.decode(String.self)) }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let v): try c.encode(v)
        case .int(let v): try c.encode(v)
        case .double(let v): try c.encode(v)
        case .bool(let v): try c.encode(v)
        case .stringArray(let v): try c.encode(v)
        }
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - Plugin Host (런타임 플러그인 관리)
// ═══════════════════════════════════════════════════════

/// 활성 플러그인에서 로드된 확장 포인트들을 관리
class PluginHost: ObservableObject {
    static let shared = PluginHost()

    /// 활성 패널 목록
    @Published var panels: [LoadedPanel] = []
    /// 활성 명령어 목록
    @Published var commands: [LoadedCommand] = []
    /// 상태바 위젯 목록
    @Published var statusBarItems: [LoadedStatusBarItem] = []
    /// 상태바 위젯 실행 결과 (key = item id)
    @Published var statusBarResults: [String: StatusBarResult] = [:]

    // ── 네이티브 확장 ──
    @Published var themes: [LoadedTheme] = []
    @Published var furniture: [LoadedFurniture] = []
    @Published var officePresets: [LoadedOfficePreset] = []
    @Published var achievements: [PluginManifest.AchievementDecl] = []
    @Published var bossLines: [String] = []
    @Published var effects: [LoadedEffect] = []

    struct LoadedPanel: Identifiable {
        let id: String
        let pluginName: String
        let title: String
        let icon: String
        let htmlURL: URL
        let position: String
        let width: Int?
        let height: Int?
    }

    struct LoadedCommand: Identifiable {
        let id: String
        let pluginName: String
        let title: String
        let icon: String
        let scriptPath: String
    }

    struct LoadedStatusBarItem: Identifiable {
        let id: String
        let pluginName: String
        let scriptPath: String
        let interval: Int
        var text: String = ""
        var icon: String = ""
        var color: String = ""
    }

    struct LoadedTheme: Identifiable {
        let id: String
        let pluginName: String
        let decl: PluginManifest.ThemeDecl
    }

    struct LoadedFurniture: Identifiable {
        let id: String
        let pluginName: String
        let decl: PluginManifest.FurnitureDecl
    }

    struct LoadedOfficePreset: Identifiable {
        let id: String
        let pluginName: String
        let decl: PluginManifest.OfficePresetDecl
    }

    struct LoadedEffect: Identifiable {
        let id: String
        let pluginName: String
        let trigger: PluginEventType
        let effectType: PluginEffectType
        let config: [String: EffectValue]
        let enabled: Bool
    }

    /// 상태바 위젯 스크립트 실행 결과
    struct StatusBarResult {
        var text: String
        var icon: String
        var color: String
    }

    // MARK: - 이벤트 발행

    func fireEvent(_ event: PluginEventType, context: [String: Any] = [:]) {
        NotificationCenter.default.post(
            name: .pluginEffectEvent,
            object: nil,
            userInfo: ["event": event, "context": context]
        )
    }

    func reload() {
        // 파일 I/O를 백그라운드에서 수행하여 메인 스레드 블로킹 방지
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?._reloadOnBackground()
        }
    }

    private func _reloadOnBackground() {
        var newPanels: [LoadedPanel] = []
        var newCommands: [LoadedCommand] = []
        var newStatusBars: [LoadedStatusBarItem] = []
        var newThemes: [LoadedTheme] = []
        var newFurniture: [LoadedFurniture] = []
        var newOfficePresets: [LoadedOfficePreset] = []
        var newEffects: [LoadedEffect] = []
        var newAchievements: [PluginManifest.AchievementDecl] = []
        var newBossLines: [String] = []

        for pluginPath in PluginManager.shared.activePluginPaths {
            let baseURL = URL(fileURLWithPath: pluginPath)
            let manifestURL = baseURL.appendingPathComponent("plugin.json")

            // Use cached manifest to avoid redundant disk I/O + JSON decoding
            let manifest: PluginManifest
            if let cached = PluginManager.shared.manifestCache[pluginPath] {
                manifest = cached
            } else {
                guard let data = try? Data(contentsOf: manifestURL),
                      let decoded = try? JSONDecoder().decode(PluginManifest.self, from: data) else { continue }
                manifest = decoded
                PluginManager.shared.manifestCache[pluginPath] = manifest
            }
            guard let contributes = manifest.contributes else { continue }

            let pluginName = manifest.name

            // 패널
            if let panelDecls = contributes.panels {
                for decl in panelDecls {
                    let htmlURL = baseURL.appendingPathComponent(decl.entry)
                    guard FileManager.default.fileExists(atPath: htmlURL.path) else { continue }
                    newPanels.append(LoadedPanel(
                        id: "\(pluginName)::\(decl.id)",
                        pluginName: pluginName,
                        title: decl.title,
                        icon: decl.icon ?? "puzzlepiece.fill",
                        htmlURL: htmlURL,
                        position: decl.position ?? "panel",
                        width: decl.width,
                        height: decl.height
                    ))
                }
            }

            // 명령어
            if let cmdDecls = contributes.commands {
                for decl in cmdDecls {
                    let scriptPath = baseURL.appendingPathComponent(decl.script).path
                    guard FileManager.default.fileExists(atPath: scriptPath) else { continue }
                    newCommands.append(LoadedCommand(
                        id: "\(pluginName)::\(decl.id)",
                        pluginName: pluginName,
                        title: decl.title,
                        icon: decl.icon ?? "terminal",
                        scriptPath: scriptPath
                    ))
                }
            }

            // 상태바
            if let statusDecls = contributes.statusBar {
                for decl in statusDecls {
                    let scriptPath = baseURL.appendingPathComponent(decl.script).path
                    guard FileManager.default.fileExists(atPath: scriptPath) else { continue }
                    newStatusBars.append(LoadedStatusBarItem(
                        id: "\(pluginName)::\(decl.id)",
                        pluginName: pluginName,
                        scriptPath: scriptPath,
                        interval: decl.interval ?? 30
                    ))
                }
            }

            // ── 네이티브 확장 ──

            // 테마
            if let themeDecls = contributes.themes {
                for decl in themeDecls {
                    newThemes.append(LoadedTheme(
                        id: "\(pluginName)::\(decl.id)",
                        pluginName: pluginName,
                        decl: decl
                    ))
                }
            }

            // 가구
            if let furnitureDecls = contributes.furniture {
                for decl in furnitureDecls {
                    newFurniture.append(LoadedFurniture(
                        id: "\(pluginName)::\(decl.id)",
                        pluginName: pluginName,
                        decl: decl
                    ))
                }
            }

            // 오피스 프리셋
            if let presetDecls = contributes.officePresets {
                for decl in presetDecls {
                    newOfficePresets.append(LoadedOfficePreset(
                        id: "\(pluginName)::\(decl.id)",
                        pluginName: pluginName,
                        decl: decl
                    ))
                }
            }

            // 업적
            if let achDecls = contributes.achievements {
                newAchievements.append(contentsOf: achDecls)
            }

            // 사장 대사
            if let lines = contributes.bossLines {
                newBossLines.append(contentsOf: lines)
            }

            // 이펙트
            if let effectDecls = contributes.effects {
                for decl in effectDecls {
                    guard let trigger = PluginEventType(rawValue: decl.trigger),
                          let effectType = PluginEffectType(rawValue: decl.type) else { continue }
                    newEffects.append(LoadedEffect(
                        id: "\(pluginName)::\(decl.id)",
                        pluginName: pluginName,
                        trigger: trigger,
                        effectType: effectType,
                        config: decl.config ?? [:],
                        enabled: decl.enabled ?? true
                    ))
                }
            }
        }

        DispatchQueue.main.async {
            self.panels = newPanels
            self.commands = newCommands
            self.statusBarItems = newStatusBars
            self.themes = newThemes
            self.furniture = newFurniture
            self.officePresets = newOfficePresets
            self.effects = newEffects
            self.achievements = newAchievements
            self.bossLines = newBossLines
            self.startStatusBarTimers()

            // 플러그인 캐릭터도 즉시 동기화 — 설치/활성화 시 재시작 없이 반영
            CharacterRegistry.shared.removeInactivePluginCharacters()
            CharacterRegistry.shared.loadPluginCharacters()
        }
    }

    // MARK: - 테마 적용

    func applyTheme(_ theme: LoadedTheme) {
        let d = theme.decl
        // 설정만 저장하고 앱 재시작 — 라이브 전환 race condition 방지
        AppSettings.shared.performBatchUpdate {
            var config = AppSettings.shared.customTheme
            config.accentHex = d.accentHex
            config.useGradient = d.useGradient ?? false
            config.gradientStartHex = d.gradientStartHex
            config.gradientEndHex = d.gradientEndHex
            config.fontName = d.fontName
            AppSettings.shared.isDarkMode = d.isDark
            AppSettings.shared.themeMode = "custom"
            AppSettings.shared.saveCustomTheme(config)
        }
    }

    // MARK: - 오피스 프리셋 적용

    /// 플러그인 오피스 프리셋을 현재 맵에 적용
    func applyOfficePreset(_ preset: LoadedOfficePreset, to map: OfficeMap) {
        let decl = preset.decl
        guard let placements = decl.furniture else { return }

        for placement in placements {
            // 해당 가구의 스프라이트 정보 찾기
            guard let furnitureDecl = furniture.first(where: { $0.decl.id == placement.furnitureId })?.decl else { continue }

            // 스프라이트 데이터가 실제로 존재하는지 검증
            guard !furnitureDecl.sprite.isEmpty,
                  furnitureDecl.sprite.contains(where: { $0.contains(where: { !$0.isEmpty }) }) else { continue }

            // 맵 범위 내에 있는지 검증
            guard placement.col >= 0, placement.row >= 0,
                  placement.col + furnitureDecl.width <= map.cols,
                  placement.row + furnitureDecl.height <= map.rows else { continue }

            let zone: OfficeZone
            switch furnitureDecl.zone ?? "mainOffice" {
            case "pantry": zone = .pantry
            case "meetingRoom": zone = .meetingRoom
            case "hallway": zone = .hallway
            default: zone = .mainOffice
            }

            let fp = FurniturePlacement(
                id: "plugin_\(preset.pluginName)_\(placement.furnitureId)_\(placement.col)_\(placement.row)",
                type: .plugin,
                position: TileCoord(col: placement.col, row: placement.row),
                size: TileSize(w: furnitureDecl.width, h: furnitureDecl.height),
                zone: zone,
                pluginFurnitureId: furnitureDecl.id
            )

            // 기존 가구와 겹치지 않는지 확인
            let collidesWithExisting = map.furniture.contains { existing in
                guard existing.type != .rug else { return false }  // 러그는 겹침 허용
                let eMinCol = existing.position.col
                let eMaxCol = existing.position.col + existing.size.w
                let eMinRow = existing.position.row
                let eMaxRow = existing.position.row + existing.size.h
                let pMinCol = placement.col
                let pMaxCol = placement.col + furnitureDecl.width
                let pMinRow = placement.row
                let pMaxRow = placement.row + furnitureDecl.height
                return pMinCol < eMaxCol && pMaxCol > eMinCol && pMinRow < eMaxRow && pMaxRow > eMinRow
            }
            guard !collidesWithExisting else { continue }

            // 중복 방지
            if !map.furniture.contains(where: { $0.id == fp.id }) {
                map.furniture.append(fp)
            }
        }
        map.rebuildWalkability()
    }

    /// 활성 플러그인의 모든 가구를 맵에 추가 (프리셋 없이 개별 배치용)
    func addPluginFurnitureToMap(_ map: OfficeMap) {
        // 가구 스프라이트 데이터가 로드되었는지 확인
        guard !furniture.isEmpty else { return }
        for preset in officePresets {
            applyOfficePreset(preset, to: map)
        }
    }

    // MARK: - 명령어 실행

    func executeCommand(_ command: LoadedCommand, projectPath: String? = nil) {
        #if os(macOS)
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-c", command.scriptPath]
            if let path = projectPath {
                process.currentDirectoryURL = URL(fileURLWithPath: path)
            }
            process.environment = ProcessInfo.processInfo.environment
            try? process.run()
            process.waitUntilExit()
        }
        #endif
    }

    // MARK: - 상태바 타이머

    private var statusTimers: [String: Timer] = [:]

    private func startStatusBarTimers() {
        #if os(macOS)
        for timer in statusTimers.values { timer.invalidate() }
        statusTimers.removeAll()

        for item in statusBarItems {
            refreshStatusBarItem(item.id)
            let timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(item.interval), repeats: true) { [weak self] _ in
                self?.refreshStatusBarItem(item.id)
            }
            statusTimers[item.id] = timer
        }
        #endif
    }

    #if os(macOS)
    private func refreshStatusBarItem(_ id: String) {
        guard let idx = statusBarItems.firstIndex(where: { $0.id == id }) else { return }
        let item = statusBarItems[idx]

        DispatchQueue.global(qos: .utility).async { [weak self] in
            let process = Process()
            let pipe = Pipe()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-c", item.scriptPath]
            process.standardOutput = pipe
            process.environment = ProcessInfo.processInfo.environment
            try? process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

            DispatchQueue.main.async {
                guard let self = self,
                      let idx = self.statusBarItems.firstIndex(where: { $0.id == id }) else { return }
                let text = json["text"] as? String ?? ""
                let icon = json["icon"] as? String ?? ""
                let color = json["color"] as? String ?? ""
                self.statusBarItems[idx].text = text
                self.statusBarItems[idx].icon = icon
                self.statusBarItems[idx].color = color
                self.statusBarResults[id] = StatusBarResult(text: text, icon: icon, color: color)
            }
        }
    }
    #endif
}

// ═══════════════════════════════════════════════════════
// MARK: - Plugin Panel View (WKWebView 래퍼)
// ═══════════════════════════════════════════════════════

#if os(macOS)
struct PluginPanelView: NSViewRepresentable {
    let htmlURL: URL
    let pluginName: String

    func makeNSView(context: Context) -> WKWebView {
        makeWebView()
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        loadContent(webView)
    }

    private func makeWebView() -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")
        let handler = PluginMessageHandler()
        config.userContentController.add(handler, name: "doffice")
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }

    private func loadContent(_ webView: WKWebView) {
        webView.loadFileURL(htmlURL, allowingReadAccessTo: htmlURL.deletingLastPathComponent())
    }
}
#elseif os(iOS)
struct PluginPanelView: UIViewRepresentable {
    let htmlURL: URL
    let pluginName: String

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let handler = PluginMessageHandler()
        config.userContentController.add(handler, name: "doffice")
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        webView.loadFileURL(htmlURL, allowingReadAccessTo: htmlURL.deletingLastPathComponent())
    }
}
#endif

/// 플러그인 JS → 앱 통신 핸들러
class PluginMessageHandler: NSObject, WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any],
              let action = body["action"] as? String else { return }

        switch action {
        case "getSessionInfo":
            // 세션 정보를 JS에 전달
            NotificationCenter.default.post(name: .pluginRequestSessionInfo, object: message.webView)
        case "notify":
            if let text = body["text"] as? String {
                NotificationCenter.default.post(name: .pluginNotify, object: nil, userInfo: ["text": text])
            }
        default:
            break
        }
    }
}

extension Notification.Name {
    static let pluginRequestSessionInfo = Notification.Name("pluginRequestSessionInfo")
    static let pluginNotify = Notification.Name("pluginNotify")
    static let pluginReload = Notification.Name("pluginReload")
    static let pluginEffectEvent = Notification.Name("pluginEffectEvent")
}

// ═══════════════════════════════════════════════════════
// MARK: - Plugin Manager (Homebrew 플러그인 관리)
// ═══════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════
// MARK: - Registry Item (마켓플레이스 항목)
// ═══════════════════════════════════════════════════════

/// 원격 레지스트리에 등록된 플러그인 (GitHub registry.json)
struct RegistryPlugin: Codable, Identifiable, Equatable {
    let id: String              // 고유 식별자
    var name: String            // 표시 이름
    var author: String          // 제작자
    var description: String     // 설명
    var version: String         // 최신 버전
    var downloadURL: String     // tar.gz / zip 다운로드 URL
    var characterCount: Int     // 포함된 캐릭터 수
    var tags: [String]          // 태그 (예: ["cat", "pixel-art", "korean"])
    var previewImageURL: String? // 미리보기 이미지 URL (옵션)
    var stars: Int?             // 인기도 (옵션)
}

/// 플러그인 메타데이터
struct PluginEntry: Codable, Identifiable, Equatable {
    let id: String          // UUID
    var name: String        // 표시 이름
    var source: String      // brew formula 또는 tap URL (예: "user/tap/formula")
    var localPath: String   // 설치된 로컬 경로
    var version: String     // 버전
    var installedAt: Date
    var enabled: Bool
    var sourceType: SourceType

    enum SourceType: String, Codable {
        case brewFormula    // brew install <formula>
        case brewTap        // brew tap <user/repo> → brew install <formula>
        case rawURL         // curl로 직접 다운로드
        case local          // 로컬 디렉토리 직접 링크
    }
}

class PluginManager: ObservableObject {
    static let shared = PluginManager()

    @Published var plugins: [PluginEntry] = []
    @Published var isInstalling: Bool = false
    @Published var installProgress: String = ""
    @Published var lastError: String?

    // 마켓플레이스
    @Published var registryPlugins: [RegistryPlugin] = []
    @Published var isLoadingRegistry: Bool = false
    @Published var registryError: String?

    private let storageKey = "WorkManPlugins"
    private let pluginBaseDir: URL
    private var currentFetchTask: URLSessionDataTask?
    /// Manifest cache to avoid redundant disk I/O + JSON decoding during reload
    private var manifestCache: [String: PluginManifest] = [:]

    /// 레지스트리 URL — GitHub Pages 또는 raw 파일
    /// 기여자는 이 저장소에 PR로 registry.json에 자기 플러그인을 추가
    static let registryURL = "https://raw.githubusercontent.com/jjunhaa0211/Doffice/main/registry.json"

    private init() {
        // ~/Library/Application Support/WorkMan/Plugins
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            pluginBaseDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("WorkManPlugins")
            try? FileManager.default.createDirectory(at: pluginBaseDir, withIntermediateDirectories: true)
            loadPlugins()
            return
        }
        pluginBaseDir = appSupport.appendingPathComponent("WorkMan").appendingPathComponent("Plugins")
        try? FileManager.default.createDirectory(at: pluginBaseDir, withIntermediateDirectories: true)
        loadPlugins()
    }

    // MARK: - Persistence

    private func loadPlugins() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([PluginEntry].self, from: data) else { return }
        plugins = decoded
    }

    private func savePlugins() {
        if let data = try? JSONEncoder().encode(plugins) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
        manifestCache.removeAll()
    }

    // MARK: - 활성 플러그인 경로 목록 (세션에 주입)

    var activePluginPaths: [String] {
        plugins.filter { $0.enabled && FileManager.default.fileExists(atPath: $0.localPath) }
            .map { $0.localPath }
    }

    // MARK: - 마켓플레이스 (레지스트리)

    func fetchRegistry() {
        // 중복 호출 방지: 기존 요청 취소
        currentFetchTask?.cancel()
        currentFetchTask = nil

        isLoadingRegistry = true
        registryError = nil

        // 번들 플러그인을 즉시 표시 (네트워크 완료 전에도 보이도록)
        let bundled = Self.mergedRegistry(remote: [])
        if registryPlugins.isEmpty {
            registryPlugins = bundled
        }

        guard let url = URL(string: Self.registryURL) else {
            registryPlugins = bundled
            isLoadingRegistry = false
            return
        }

        // 타임아웃 10초 설정
        var request = URLRequest(url: url)
        request.timeoutInterval = 10

        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.currentFetchTask = nil
                self.isLoadingRegistry = false

                // 취소된 요청은 무시
                if let urlError = error as? URLError, urlError.code == .cancelled {
                    return
                }

                let remoteItems = Self.resolveRegistryItems(data: data, response: response, error: error)
                self.registryPlugins = Self.mergedRegistry(remote: remoteItems)
                self.registryError = nil
            }
        }
        currentFetchTask = task
        task.resume()
    }

    /// 레지스트리에서 설치
    func installFromRegistry(_ item: RegistryPlugin) {
        if let bundledID = Self.bundledPluginID(from: item.downloadURL) {
            installBundledPlugin(item, bundledID: bundledID)
            return
        }
        install(source: item.downloadURL)
    }

    /// 이미 설치되어 있는지 확인
    func isInstalled(_ registryItem: RegistryPlugin) -> Bool {
        plugins.contains { $0.source == registryItem.downloadURL || $0.name == registryItem.name }
    }

    // MARK: - 소스 타입 자동 감지

    func detectSourceType(_ input: String) -> PluginEntry.SourceType {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        // 로컬 경로 (/, ~/ 로 시작)
        let expanded = NSString(string: trimmed).expandingTildeInPath
        if trimmed.hasPrefix("/") || trimmed.hasPrefix("~/") || trimmed.hasPrefix("./") {
            if FileManager.default.fileExists(atPath: expanded) {
                return .local
            }
        }
        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
            return .rawURL
        }
        // "user/tap/formula" 형식 → brew tap
        let components = trimmed.split(separator: "/")
        if components.count >= 3 && !trimmed.hasPrefix("/") {
            return .brewTap
        }
        // 단순 formula 이름
        return .brewFormula
    }

    // MARK: - 설치

    func install(source: String) {
        let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isInstalling = true
        lastError = nil
        installProgress = NSLocalizedString("plugin.progress.analyzing", comment: "")

        let sourceType = detectSourceType(trimmed)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            switch sourceType {
            #if os(macOS)
            case .brewFormula:
                self.installBrewFormula(trimmed)
            case .brewTap:
                self.installBrewTap(trimmed)
            #else
            case .brewFormula, .brewTap:
                self.finishWithError(NSLocalizedString("plugin.error.brew.not.supported", comment: ""))
            #endif
            case .rawURL:
                self.installFromURL(trimmed)
            case .local:
                self.installLocal(trimmed)
            }
        }
    }

    private func installBundledPlugin(_ item: RegistryPlugin, bundledID: String) {
        guard let bundled = Self.bundledPluginDefinition(for: bundledID) else {
            finishWithError(NSLocalizedString("plugin.error.path.not.found", comment: ""))
            return
        }

        isInstalling = true
        lastError = nil
        installProgress = String(format: NSLocalizedString("plugin.progress.installing", comment: ""), item.name)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let fm = FileManager.default
            let pluginDir = self.pluginBaseDir.appendingPathComponent(bundled.directoryName)

            do {
                if fm.fileExists(atPath: pluginDir.path) {
                    try fm.removeItem(at: pluginDir)
                }
                try fm.createDirectory(at: pluginDir, withIntermediateDirectories: true)

                for file in bundled.files {
                    let destination = pluginDir.appendingPathComponent(file.path)
                    let parentDir = destination.deletingLastPathComponent()
                    try fm.createDirectory(at: parentDir, withIntermediateDirectories: true)
                    try file.contents.write(to: destination, atomically: true, encoding: .utf8)
                }
            } catch {
                self.finishWithError(error.localizedDescription)
                return
            }

            let entry = PluginEntry(
                id: UUID().uuidString,
                name: item.name,
                source: item.downloadURL,
                localPath: pluginDir.path,
                version: item.version,
                installedAt: Date(),
                enabled: true,
                sourceType: .rawURL
            )
            self.finishInstall(entry)
        }
    }

    #if os(macOS)
    private func installBrewFormula(_ formula: String) {
        updateProgress(NSLocalizedString("plugin.progress.brew.install", comment: ""))

        let brewPath = Self.findBrewPath()
        guard let brew = brewPath else {
            finishWithError(NSLocalizedString("plugin.error.brew.not.found", comment: ""))
            return
        }

        // brew install
        let (installOk, installOut) = runShell("\(brew) install \(shellEscape(formula))")
        if !installOk && !installOut.contains("already installed") {
            finishWithError(String(format: NSLocalizedString("plugin.error.install.failed", comment: ""), installOut))
            return
        }

        // brew --prefix로 설치 경로 가져오기
        let (_, prefixOut) = runShell("\(brew) --prefix \(shellEscape(formula))")
        let prefix = prefixOut.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !prefix.isEmpty && FileManager.default.fileExists(atPath: prefix) else {
            finishWithError(NSLocalizedString("plugin.error.path.not.found", comment: ""))
            return
        }

        // 버전 확인
        let (_, versionOut) = runShell("\(brew) list --versions \(shellEscape(formula))")
        let version = versionOut.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: " ").last ?? "unknown"

        let entry = PluginEntry(
            id: UUID().uuidString,
            name: formula,
            source: formula,
            localPath: prefix,
            version: version,
            installedAt: Date(),
            enabled: true,
            sourceType: .brewFormula
        )

        finishInstall(entry)
    }

    private func installBrewTap(_ tapFormula: String) {
        let parts = tapFormula.split(separator: "/")
        guard parts.count >= 3 else {
            finishWithError(NSLocalizedString("plugin.error.invalid.tap", comment: ""))
            return
        }

        let tapName = "\(parts[0])/\(parts[1])"
        let formula = String(parts[2...].joined(separator: "/"))

        let brewPath = Self.findBrewPath()
        guard let brew = brewPath else {
            finishWithError(NSLocalizedString("plugin.error.brew.not.found", comment: ""))
            return
        }

        // brew tap
        updateProgress(String(format: NSLocalizedString("plugin.progress.tapping", comment: ""), tapName))
        let (tapOk, tapOut) = runShell("\(brew) tap \(shellEscape(String(tapName)))")
        if !tapOk && !tapOut.contains("already tapped") {
            finishWithError(String(format: NSLocalizedString("plugin.error.tap.failed", comment: ""), tapOut))
            return
        }

        // brew install
        updateProgress(String(format: NSLocalizedString("plugin.progress.installing", comment: ""), formula))
        let (installOk, installOut) = runShell("\(brew) install \(shellEscape(tapFormula))")
        if !installOk && !installOut.contains("already installed") {
            finishWithError(String(format: NSLocalizedString("plugin.error.install.failed", comment: ""), installOut))
            return
        }

        // 경로 가져오기
        let (_, prefixOut) = runShell("\(brew) --prefix \(shellEscape(tapFormula))")
        let prefix = prefixOut.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !prefix.isEmpty && FileManager.default.fileExists(atPath: prefix) else {
            finishWithError(NSLocalizedString("plugin.error.path.not.found", comment: ""))
            return
        }

        let (_, versionOut) = runShell("\(brew) list --versions \(shellEscape(tapFormula))")
        let version = versionOut.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: " ").last ?? "unknown"

        let entry = PluginEntry(
            id: UUID().uuidString,
            name: formula,
            source: tapFormula,
            localPath: prefix,
            version: version,
            installedAt: Date(),
            enabled: true,
            sourceType: .brewTap
        )

        finishInstall(entry)
    }
    #endif

    private func installFromURL(_ urlString: String) {
        guard let url = URL(string: urlString) else {
            finishWithError(NSLocalizedString("plugin.error.invalid.url", comment: ""))
            return
        }

        let fileName = url.lastPathComponent.isEmpty ? "plugin" : url.lastPathComponent
        let pluginName = (fileName as NSString).deletingPathExtension
        let pluginDir = pluginBaseDir.appendingPathComponent(pluginName)

        updateProgress(String(format: NSLocalizedString("plugin.progress.downloading", comment: ""), fileName))
        try? FileManager.default.createDirectory(at: pluginDir, withIntermediateDirectories: true)

        // URLSession으로 다운로드 (macOS + iOS 모두 동작)
        let destURL = pluginDir.appendingPathComponent(fileName)
        URLSession.shared.downloadTask(with: url) { [weak self] tempURL, _, error in
            guard let self = self else { return }
            guard let tempURL = tempURL, error == nil else {
                self.finishWithError(String(format: NSLocalizedString("plugin.error.download.failed", comment: ""), error?.localizedDescription ?? ""))
                return
            }

            do {
                if FileManager.default.fileExists(atPath: destURL.path) {
                    try FileManager.default.removeItem(at: destURL)
                }
                try FileManager.default.moveItem(at: tempURL, to: destURL)
            } catch {
                self.finishWithError(String(format: NSLocalizedString("plugin.error.download.failed", comment: ""), error.localizedDescription))
                return
            }

            // 압축 해제
            self.extractIfNeeded(destURL, to: pluginDir, fileName: fileName)

            let entry = PluginEntry(
                id: UUID().uuidString,
                name: pluginName,
                source: urlString,
                localPath: pluginDir.path,
                version: "1.0.0",
                installedAt: Date(),
                enabled: true,
                sourceType: .rawURL
            )
            self.finishInstall(entry)
        }.resume()
    }

    private func extractIfNeeded(_ fileURL: URL, to dir: URL, fileName: String) {
        #if os(macOS)
        if fileName.hasSuffix(".tar.gz") || fileName.hasSuffix(".tgz") {
            updateProgress(NSLocalizedString("plugin.progress.extracting", comment: ""))
            let (ok, out) = runShell("tar -xzf \(shellEscape(fileURL.path)) -C \(shellEscape(dir.path))")
            if ok { try? FileManager.default.removeItem(at: fileURL) }
            else { finishWithError(String(format: NSLocalizedString("plugin.error.extract.failed", comment: ""), out)); return }
        } else if fileName.hasSuffix(".zip") {
            updateProgress(NSLocalizedString("plugin.progress.extracting", comment: ""))
            let (ok, out) = runShell("unzip -o \(shellEscape(fileURL.path)) -d \(shellEscape(dir.path))")
            if ok { try? FileManager.default.removeItem(at: fileURL) }
            else { finishWithError(String(format: NSLocalizedString("plugin.error.extract.failed", comment: ""), out)); return }
        }
        #else
        // iOS: zip만 Foundation으로 지원 (tar.gz는 미지원)
        if fileName.hasSuffix(".zip") {
            updateProgress(NSLocalizedString("plugin.progress.extracting", comment: ""))
            // FileManager에서 직접 압축해제는 미지원 → 파일 그대로 유지
        }
        #endif
    }

    // MARK: - 로컬 디렉토리 등록

    private func installLocal(_ path: String) {
        let expanded = NSString(string: path).expandingTildeInPath
        guard FileManager.default.fileExists(atPath: expanded) else {
            finishWithError(NSLocalizedString("plugin.error.path.not.found", comment: ""))
            return
        }

        let name = URL(fileURLWithPath: expanded).lastPathComponent
        let validation = Self.validatePluginDir(expanded)

        let entry = PluginEntry(
            id: UUID().uuidString,
            name: name,
            source: path,
            localPath: expanded,
            version: validation.version ?? "dev",
            installedAt: Date(),
            enabled: true,
            sourceType: .local
        )

        finishInstall(entry)
    }

    // MARK: - 플러그인 유효성 검증

    struct PluginValidation {
        var isValid: Bool
        var hasClaudeMD: Bool
        var hasHooks: Bool
        var hasSlashCommands: Bool
        var hasMCPServers: Bool
        var hasSettings: Bool
        var hasCharacters: Bool
        var characterCount: Int
        var version: String?
        var warnings: [String]
    }

    static func validatePluginDir(_ path: String) -> PluginValidation {
        let fm = FileManager.default
        let base = URL(fileURLWithPath: path)

        let claudeMD = base.appendingPathComponent("CLAUDE.md")
        let hooksDir = base.appendingPathComponent("hooks")
        let slashDir = base.appendingPathComponent("slash-commands")
        let mcpDir = base.appendingPathComponent("mcp-servers")
        let settingsFile = base.appendingPathComponent("settings.json")
        let packageJSON = base.appendingPathComponent("package.json")

        let charactersFile = base.appendingPathComponent("characters.json")

        let hasClaudeMD = fm.fileExists(atPath: claudeMD.path)
        let hasHooks = fm.fileExists(atPath: hooksDir.path)
        let hasSlashCommands = fm.fileExists(atPath: slashDir.path)
        let hasMCPServers = fm.fileExists(atPath: mcpDir.path)
        let hasSettings = fm.fileExists(atPath: settingsFile.path)
        let hasCharacters = fm.fileExists(atPath: charactersFile.path)

        var characterCount = 0
        if hasCharacters,
           let data = try? Data(contentsOf: charactersFile),
           let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            characterCount = arr.count
        }

        var version: String?
        if let data = try? Data(contentsOf: packageJSON),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let v = json["version"] as? String {
            version = v
        }

        var warnings: [String] = []
        let hasAnything = hasClaudeMD || hasHooks || hasSlashCommands || hasMCPServers || hasSettings || hasCharacters
        if !hasAnything {
            warnings.append(NSLocalizedString("plugin.warn.empty", comment: ""))
        }

        return PluginValidation(
            isValid: hasAnything,
            hasClaudeMD: hasClaudeMD,
            hasHooks: hasHooks,
            hasSlashCommands: hasSlashCommands,
            hasMCPServers: hasMCPServers,
            hasSettings: hasSettings,
            hasCharacters: hasCharacters,
            characterCount: characterCount,
            version: version,
            warnings: warnings
        )
    }

    // MARK: - 새 플러그인 스캐폴딩

    func scaffold(name: String, at parentDir: String, options: ScaffoldOptions = ScaffoldOptions()) -> String? {
        let pluginDir = URL(fileURLWithPath: parentDir).appendingPathComponent(name)
        let fm = FileManager.default

        do {
            try fm.createDirectory(at: pluginDir, withIntermediateDirectories: true)

            // CLAUDE.md
            let claudeMD = """
            # \(name) Plugin

            이 플러그인은 도피스(Doffice)용 Claude Code 플러그인입니다.

            ## 설명
            플러그인 설명을 여기에 작성하세요.
            """
            try claudeMD.write(to: pluginDir.appendingPathComponent("CLAUDE.md"), atomically: true, encoding: .utf8)

            // hooks/
            if options.includeHooks {
                let hooksDir = pluginDir.appendingPathComponent("hooks")
                try fm.createDirectory(at: hooksDir, withIntermediateDirectories: true)

                let preHook = """
                // preToolUse hook — 도구 실행 전에 호출됩니다.
                // return { decision: "allow" } 또는 { decision: "deny", reason: "..." }
                export default function preToolUse({ tool, input }) {
                  // 예: 특정 디렉토리 보호
                  // if (tool === "Write" && input.file_path?.startsWith("/protected/")) {
                  //   return { decision: "deny", reason: "보호된 디렉토리입니다" };
                  // }
                  return { decision: "allow" };
                }
                """
                try preHook.write(to: hooksDir.appendingPathComponent("preToolUse.js"), atomically: true, encoding: .utf8)
            }

            // slash-commands/
            if options.includeSlashCommands {
                let slashDir = pluginDir.appendingPathComponent("slash-commands")
                try fm.createDirectory(at: slashDir, withIntermediateDirectories: true)

                let exampleCmd = """
                # /\(name)-hello

                사용자에게 인사를 건네세요.
                이 명령은 \(name) 플러그인의 예제입니다.
                """
                try exampleCmd.write(to: slashDir.appendingPathComponent("\(name)-hello.md"), atomically: true, encoding: .utf8)
            }

            // settings.json
            if options.includeSettings {
                let settings: [String: Any] = [
                    "name": name,
                    "version": "0.1.0",
                    "description": "\(name) plugin for Doffice"
                ]
                let data = try JSONSerialization.data(withJSONObject: settings, options: .prettyPrinted)
                try data.write(to: pluginDir.appendingPathComponent("settings.json"))
            }

            // characters.json (캐릭터 팩)
            if options.includeCharacters {
                let exampleCharacters: [[String: Any]] = [
                    [
                        "id": "example_char",
                        "name": "Example",
                        "archetype": "예제 캐릭터",
                        "hairColor": "4a3728",
                        "skinTone": "ffd5b8",
                        "shirtColor": "f08080",
                        "pantsColor": "3a4050",
                        "hatType": "none",
                        "accessory": "glasses",
                        "species": "Human",
                        "jobRole": "developer"
                    ]
                ]
                let charData = try JSONSerialization.data(withJSONObject: exampleCharacters, options: .prettyPrinted)
                try charData.write(to: pluginDir.appendingPathComponent("characters.json"))

                // README
                let readme = """
                # \(name) 캐릭터 팩

                ## characters.json 형식

                ```json
                [
                  {
                    "id": "고유ID",
                    "name": "표시 이름",
                    "archetype": "성격/설명",
                    "hairColor": "hex (6자리, # 없이)",
                    "skinTone": "hex",
                    "shirtColor": "hex",
                    "pantsColor": "hex",
                    "hatType": "none|beanie|cap|hardhat|wizard|crown|headphones|beret",
                    "accessory": "none|glasses|sunglasses|scarf|mask|earring",
                    "species": "Human|Cat|Dog|Rabbit|Bear|Penguin|Fox|Robot|Claude|Alien|Ghost|Dragon|Chicken|Owl|Frog|Panda|Unicorn|Skeleton",
                    "jobRole": "developer|qa|reporter|boss|planner|reviewer|designer|sre"
                  }
                ]
                ```

                ## 배포 방법
                1. GitHub에 올리고 Homebrew tap 생성
                2. 또는 tar.gz로 묶어서 Release에 올리기
                3. 도피스 설정 > 플러그인에서 설치
                """
                try readme.write(to: pluginDir.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)
            }

            // plugin.json (매니페스트 — 확장 포인트 선언)
            var contributes: [String: Any] = [:]
            if options.includeCharacters {
                contributes["characters"] = "characters.json"
            }
            if options.includePanel {
                contributes["panels"] = [[
                    "id": "main-panel",
                    "title": "\(name) Panel",
                    "icon": "puzzlepiece.fill",
                    "entry": "panel/index.html",
                    "position": "panel"
                ]]

                // panel/index.html 생성
                let panelDir = pluginDir.appendingPathComponent("panel")
                try fm.createDirectory(at: panelDir, withIntermediateDirectories: true)
                let panelHTML = """
                <!DOCTYPE html>
                <html>
                <head>
                <meta charset="utf-8">
                <style>
                  * { margin: 0; padding: 0; box-sizing: border-box; }
                  body {
                    font-family: 'SF Mono', 'Menlo', monospace;
                    background: transparent;
                    color: #e0e0e0;
                    padding: 16px;
                  }
                  h1 { font-size: 14px; margin-bottom: 12px; color: #5b9cf6; }
                  .card {
                    background: rgba(255,255,255,0.05);
                    border: 1px solid rgba(255,255,255,0.1);
                    border-radius: 8px;
                    padding: 12px;
                    margin-bottom: 8px;
                  }
                  button {
                    background: #5b9cf6;
                    color: white;
                    border: none;
                    border-radius: 6px;
                    padding: 8px 16px;
                    font-family: inherit;
                    font-size: 12px;
                    cursor: pointer;
                  }
                  button:hover { opacity: 0.8; }
                </style>
                </head>
                <body>
                  <h1>\(name) Plugin</h1>
                  <div class="card">
                    <p>이 패널은 플러그인의 예제입니다.</p>
                    <p>HTML/CSS/JS로 자유롭게 UI를 만들 수 있습니다.</p>
                  </div>
                  <button onclick="window.webkit.messageHandlers.doffice.postMessage({action:'notify', text:'Hello from \(name)!'})">
                    앱에 알림 보내기
                  </button>
                  <script>
                    // window.webkit.messageHandlers.doffice.postMessage({action: 'getSessionInfo'})
                    // → 앱이 세션 정보를 이 WebView에 전달
                  </script>
                </body>
                </html>
                """
                try panelHTML.write(to: panelDir.appendingPathComponent("index.html"), atomically: true, encoding: .utf8)
            }

            let pluginJSON: [String: Any] = [
                "name": name,
                "version": "0.1.0",
                "description": "\(name) — Doffice plugin",
                "author": Self.currentUserName,
                "contributes": contributes
            ]
            let pluginData = try JSONSerialization.data(withJSONObject: pluginJSON, options: [.prettyPrinted, .sortedKeys])
            try pluginData.write(to: pluginDir.appendingPathComponent("plugin.json"))

            // package.json (버전 추적용)
            let packageJSON: [String: Any] = [
                "name": name,
                "version": "0.1.0",
                "description": "\(name) — Doffice plugin"
            ]
            let pkgData = try JSONSerialization.data(withJSONObject: packageJSON, options: .prettyPrinted)
            try pkgData.write(to: pluginDir.appendingPathComponent("package.json"))

            return pluginDir.path
        } catch {
            return nil
        }
    }

    struct ScaffoldOptions {
        var includeHooks: Bool = true
        var includeSlashCommands: Bool = true
        var includeCharacters: Bool = true
        var includeSettings: Bool = true
        var includePanel: Bool = true
    }

    // MARK: - Finder에서 열기

    func revealInFinder(_ plugin: PluginEntry) {
        #if os(macOS)
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: plugin.localPath)
        #endif
    }

    // MARK: - 삭제

    func uninstall(_ plugin: PluginEntry) {
        switch plugin.sourceType {
        case .brewFormula, .brewTap:
            #if os(macOS)
            if let brew = Self.findBrewPath() {
                _ = runShell("\(brew) uninstall \(shellEscape(plugin.source))")
            }
            #endif
        case .rawURL:
            try? FileManager.default.removeItem(atPath: plugin.localPath)
        case .local:
            break
        }

        DispatchQueue.main.async {
            self.plugins.removeAll { $0.id == plugin.id }
            self.savePlugins()
            // 제거된 플러그인 정리
            CharacterRegistry.shared.removeInactivePluginCharacters()
            PluginHost.shared.reload()
        }
    }

    // MARK: - 토글

    func toggleEnabled(_ plugin: PluginEntry) {
        if let idx = plugins.firstIndex(where: { $0.id == plugin.id }) {
            plugins[idx].enabled.toggle()
            savePlugins()
            // 즉시 반영: 캐릭터/테마/가구/업적 등 모든 플러그인 리소스 재로드
            PluginHost.shared.reload()
        }
    }

    // MARK: - 업데이트 (brew upgrade)

    #if os(macOS)
    func upgrade(_ plugin: PluginEntry) {
        guard plugin.sourceType != .rawURL else { return }
        guard let brew = Self.findBrewPath() else { return }

        isInstalling = true
        installProgress = String(format: NSLocalizedString("plugin.progress.upgrading", comment: ""), plugin.name)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let (ok, output) = self.runShell("\(brew) upgrade \(self.shellEscape(plugin.source))")

            if !ok && !output.contains("already installed") && !output.contains("already the newest") {
                self.finishWithError(String(format: NSLocalizedString("plugin.error.upgrade.failed", comment: ""), output))
                return
            }

            // 새 버전 확인
            let (_, versionOut) = self.runShell("\(brew) list --versions \(self.shellEscape(plugin.source))")
            let version = versionOut.trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: " ").last ?? plugin.version

            DispatchQueue.main.async {
                if let idx = self.plugins.firstIndex(where: { $0.id == plugin.id }) {
                    self.plugins[idx].version = version
                    self.savePlugins()
                }
                self.isInstalling = false
                self.installProgress = ""
            }
        }
    }
    #endif

    // MARK: - Platform Helpers

    private static var currentUserName: String {
        #if os(macOS)
        return NSUserName()
        #else
        return "user"
        #endif
    }

    // MARK: - Shell Helpers

    #if os(macOS)
    private static func findBrewPath() -> String? {
        let candidates = ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]
        return candidates.first { FileManager.default.fileExists(atPath: $0) }
    }

    @discardableResult
    private func runShell(_ command: String) -> (Bool, String) {
        let process = Process()
        let pipe = Pipe()
        let errorPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", command]
        process.standardOutput = pipe
        process.standardError = errorPipe
        process.environment = ProcessInfo.processInfo.environment

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return (false, error.localizedDescription)
        }

        let outData = pipe.fileHandleForReading.readDataToEndOfFile()
        let errData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outData, encoding: .utf8) ?? ""
        let errOutput = String(data: errData, encoding: .utf8) ?? ""

        let success = process.terminationStatus == 0
        return (success, success ? output : (errOutput.isEmpty ? output : errOutput))
    }

    private func shellEscape(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
    #endif

    // MARK: - Progress Helpers

    private func updateProgress(_ msg: String) {
        DispatchQueue.main.async { self.installProgress = msg }
    }

    private func finishWithError(_ msg: String) {
        DispatchQueue.main.async {
            self.lastError = msg
            self.isInstalling = false
            self.installProgress = ""
        }
    }

    /// 설치 완료 후 앱 재시작 필요 여부
    @Published var needsRestart: Bool = false

    private func finishInstall(_ entry: PluginEntry) {
        DispatchQueue.main.async {
            if let idx = self.plugins.firstIndex(where: { $0.source == entry.source }) {
                self.plugins[idx].name = entry.name
                self.plugins[idx].localPath = entry.localPath
                self.plugins[idx].version = entry.version
                self.plugins[idx].installedAt = entry.installedAt
                self.plugins[idx].enabled = entry.enabled
                self.plugins[idx].sourceType = entry.sourceType
            } else {
                self.plugins.append(entry)
            }
            self.savePlugins()
            self.lastError = nil
            self.isInstalling = false
            self.installProgress = ""
            // 즉시 반영: 설치된 플러그인의 캐릭터/테마/가구/업적 로드
            PluginHost.shared.reload()
        }
    }

    /// 안전하게 앱 재시작
    func restartApp() {
        #if os(macOS)
        let url = Bundle.main.bundleURL
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-n", url.path]
        try? task.run()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NSApplication.shared.terminate(nil)
        }
        #endif
    }

    // MARK: - Registry Helpers

    static func decodeRegistryPayload(_ data: Data) -> [RegistryPlugin]? {
        guard let json = try? JSONSerialization.jsonObject(with: data) else { return nil }

        let rawItems: [[String: Any]]
        if let array = json as? [[String: Any]] {
            rawItems = array
        } else if let object = json as? [String: Any],
                  let array = object["plugins"] as? [[String: Any]] {
            rawItems = array
        } else {
            return nil
        }

        let items = rawItems.compactMap(Self.registryPlugin(from:))
        return items.isEmpty ? nil : items
    }

    static func bundledRegistryCatalog() -> [RegistryPlugin] {
        [
            RegistryPlugin(
                id: "flea-market-hidden-pack",
                name: "플리 마켓 히든 캐릭터 팩",
                author: "WorkMan",
                description: "플리 마켓에서 바로 고용할 수 있는 히든 캐릭터 3종을 추가합니다.",
                version: "1.0.0",
                downloadURL: "bundled://flea-market-hidden-pack",
                characterCount: 3,
                tags: ["hidden", "market", "characters"],
                previewImageURL: nil,
                stars: 42
            ),
            RegistryPlugin(
                id: "typing-combo-pack",
                name: "타이핑 콤보 팩",
                author: "WorkMan",
                description: "터미널 외부에서 타이핑할 때 콤보 카운터, 파티클, 화면 흔들림 이펙트가 발동합니다.",
                version: "1.0.0",
                downloadURL: "bundled://typing-combo-pack",
                characterCount: 0,
                tags: ["effects", "combo", "typing", "particles"],
                previewImageURL: nil,
                stars: 128
            ),
            RegistryPlugin(
                id: "premium-furniture-pack",
                name: "프리미엄 가구 팩",
                author: "WorkMan",
                description: "아쿠아리움, 아케이드 머신, 네온사인, 빈백, 관엽식물 등 프리미엄 가구 8종을 추가합니다.",
                version: "1.0.0",
                downloadURL: "bundled://premium-furniture-pack",
                characterCount: 0,
                tags: ["furniture", "decoration", "premium", "office"],
                previewImageURL: nil,
                stars: 95
            ),
            RegistryPlugin(
                id: "vacation-beach-pack",
                name: "바캉스 비치 팩",
                author: "WorkMan",
                description: "사무실을 해변으로 변신! 야자수, 서핑보드, 파라솔 아래에서 코딩하는 바캉스 컨셉 오피스.",
                version: "1.0.0",
                downloadURL: "bundled://vacation-beach-pack",
                characterCount: 2,
                tags: ["theme", "beach", "vacation", "tropical", "office-preset"],
                previewImageURL: nil,
                stars: 210
            ),
            RegistryPlugin(
                id: "battleground-pack",
                name: "배틀그라운드 팩",
                author: "WorkMan",
                description: "사무실이 전장으로! 나무, 바위, 수풀에 숨어 코딩하는 배그 컨셉 오피스. 에어드랍 이펙트 포함.",
                version: "1.0.0",
                downloadURL: "bundled://battleground-pack",
                characterCount: 3,
                tags: ["theme", "battleground", "military", "survival", "office-preset"],
                previewImageURL: nil,
                stars: 187
            )
        ]
    }

    private static func resolveRegistryItems(data: Data?, response: URLResponse?, error: Error?) -> [RegistryPlugin] {
        if error != nil {
            return []
        }

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            return []
        }

        guard let data else { return [] }
        return decodeRegistryPayload(data) ?? []
    }

    private static func mergedRegistry(remote: [RegistryPlugin]) -> [RegistryPlugin] {
        var seenIDs = Set<String>()
        var seenNames = Set<String>()
        var merged: [RegistryPlugin] = []

        for item in bundledRegistryCatalog() + remote {
            let idKey = item.id.lowercased()
            let nameKey = item.name.lowercased()
            guard !seenIDs.contains(idKey), !seenNames.contains(nameKey) else { continue }
            seenIDs.insert(idKey)
            seenNames.insert(nameKey)
            merged.append(item)
        }

        return merged
    }

    private static func registryPlugin(from raw: [String: Any]) -> RegistryPlugin? {
        guard let name = firstString(in: raw, keys: ["name", "title"]),
              let downloadURL = firstString(in: raw, keys: ["downloadURL", "downloadUrl", "download_url", "url"]) else {
            return nil
        }

        let id = firstString(in: raw, keys: ["id"]) ?? slugifiedRegistryID(from: name)
        let author = firstString(in: raw, keys: ["author", "creator", "maker"]) ?? "Unknown"
        let description = firstString(in: raw, keys: ["description", "summary"]) ?? ""
        let version = firstString(in: raw, keys: ["version"]) ?? "1.0.0"
        let previewImageURL = firstString(in: raw, keys: ["previewImageURL", "previewImageUrl", "preview_image_url"])
        let tags = stringArray(in: raw, keys: ["tags"])
        let stars = firstInt(in: raw, keys: ["stars", "starCount", "star_count"])
        let characterCount = firstInt(in: raw, keys: ["characterCount", "character_count"])
            ?? ((raw["characters"] as? [[String: Any]])?.count ?? 0)

        return RegistryPlugin(
            id: id,
            name: name,
            author: author,
            description: description,
            version: version,
            downloadURL: downloadURL,
            characterCount: characterCount,
            tags: tags,
            previewImageURL: previewImageURL,
            stars: stars
        )
    }

    private static func bundledPluginID(from source: String) -> String? {
        guard let url = URL(string: source), url.scheme == "bundled" else { return nil }

        let host = url.host?.trimmingCharacters(in: CharacterSet(charactersIn: "/")) ?? ""
        let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let identifier = host.isEmpty ? path : host
        return identifier.isEmpty ? nil : identifier
    }

    private struct BundledPluginFile {
        let path: String
        let contents: String
    }

    private struct BundledPluginDefinition {
        let directoryName: String
        let files: [BundledPluginFile]
    }

    private static func bundledPluginDefinition(for id: String) -> BundledPluginDefinition? {
        switch id {
        case "flea-market-hidden-pack":
            let characters = """
            [
              {
                "id": "night_vendor",
                "name": "히든 야시장",
                "archetype": "플리 마켓의 비밀 셀러",
                "hairColor": "3b2f2f",
                "skinTone": "e8c4a0",
                "shirtColor": "6d597a",
                "pantsColor": "2b2d42",
                "hatType": "cap",
                "accessory": "glasses",
                "species": "Fox",
                "jobRole": "reviewer"
              },
              {
                "id": "lucky_tag",
                "name": "히든 럭키태그",
                "archetype": "숨겨둔 딜을 먼저 찾는 흥정 장인",
                "hairColor": "b08968",
                "skinTone": "f1d3b3",
                "shirtColor": "84a59d",
                "pantsColor": "3d405b",
                "hatType": "beanie",
                "accessory": "earring",
                "species": "Cat",
                "jobRole": "planner"
              },
              {
                "id": "ghost_dealer",
                "name": "히든 고스트딜러",
                "archetype": "새벽에만 등장하는 히든 캐릭터",
                "hairColor": "d9d9ff",
                "skinTone": "d9d9ff",
                "shirtColor": "adb5bd",
                "pantsColor": "495057",
                "hatType": "wizard",
                "accessory": "mask",
                "species": "Ghost",
                "jobRole": "designer"
              }
            ]
            """

            let pluginJSON = """
            {
              "name": "플리 마켓 히든 캐릭터 팩",
              "version": "1.0.0",
              "description": "플리 마켓에서 바로 고용할 수 있는 히든 캐릭터 3종 팩",
              "author": "WorkMan",
              "contributes": {
                "characters": "characters.json"
              }
            }
            """

            let packageJSON = """
            {
              "name": "flea-market-hidden-pack",
              "version": "1.0.0",
              "description": "Bundled hidden character pack for the WorkMan marketplace"
            }
            """

            let readme = """
            # 플리 마켓 히든 캐릭터 팩

            WorkMan 마켓플레이스에서 바로 설치할 수 있는 기본 캐릭터 플러그인입니다.
            설치하면 히든 캐릭터 3종이 캐릭터 목록에 추가됩니다.
            """

            return BundledPluginDefinition(
                directoryName: "flea-market-hidden-pack",
                files: [
                    BundledPluginFile(path: "plugin.json", contents: pluginJSON),
                    BundledPluginFile(path: "package.json", contents: packageJSON),
                    BundledPluginFile(path: "characters.json", contents: characters),
                    BundledPluginFile(path: "README.md", contents: readme)
                ]
            )
        // ── 타이핑 콤보 팩 ──
        case "typing-combo-pack":
            let pluginJSON = """
            {
              "name": "타이핑 콤보 팩",
              "version": "1.0.0",
              "description": "터미널 외부에서 타이핑할 때 콤보 카운터와 파티클 이펙트가 발동합니다",
              "author": "WorkMan",
              "contributes": {
                "effects": [
                  {
                    "id": "typing-combo",
                    "trigger": "onPromptKeyPress",
                    "type": "combo-counter",
                    "config": {
                      "decaySeconds": 2.5,
                      "shakeOnMilestone": true
                    },
                    "enabled": true
                  },
                  {
                    "id": "typing-particles",
                    "trigger": "onPromptKeyPress",
                    "type": "particle-burst",
                    "config": {
                      "emojis": ["⌨️", "💥", "🔥", "⚡", "✨", "💫"],
                      "count": 5,
                      "duration": 0.8
                    },
                    "enabled": true
                  },
                  {
                    "id": "submit-confetti",
                    "trigger": "onPromptSubmit",
                    "type": "confetti",
                    "config": {
                      "colors": ["3291ff", "3ecf8e", "f5a623", "f14c4c", "8e4ec6"],
                      "count": 30,
                      "duration": 2.5
                    },
                    "enabled": true
                  },
                  {
                    "id": "submit-flash",
                    "trigger": "onPromptSubmit",
                    "type": "flash",
                    "config": {
                      "colorHex": "3291ff",
                      "duration": 0.2
                    },
                    "enabled": true
                  },
                  {
                    "id": "submit-sound",
                    "trigger": "onPromptSubmit",
                    "type": "sound",
                    "config": {
                      "name": "Pop"
                    },
                    "enabled": true
                  },
                  {
                    "id": "error-shake",
                    "trigger": "onSessionError",
                    "type": "screen-shake",
                    "config": {
                      "intensity": 6.0,
                      "duration": 0.4
                    },
                    "enabled": true
                  },
                  {
                    "id": "complete-toast",
                    "trigger": "onSessionComplete",
                    "type": "toast",
                    "config": {
                      "text": "세션 완료! GG 🎮",
                      "icon": "checkmark.circle.fill",
                      "tint": "3ecf8e",
                      "duration": 4.0
                    },
                    "enabled": true
                  },
                  {
                    "id": "levelup-confetti",
                    "trigger": "onLevelUp",
                    "type": "confetti",
                    "config": {
                      "colors": ["f5a623", "f14c4c", "8e4ec6", "3ecf8e", "3291ff"],
                      "count": 60,
                      "duration": 4.0
                    },
                    "enabled": true
                  }
                ]
              }
            }
            """

            let readme = """
            # 타이핑 콤보 팩

            터미널 외부(프롬프트 입력)에서 타이핑할 때 콤보 카운터가 올라가고,
            파티클 이펙트가 터집니다. 프롬프트 제출 시 컨페티 + 플래시!

            ## 포함 이펙트
            - 타이핑 콤보 카운터 (2.5초 디케이)
            - 키 입력 파티클 (⌨️💥🔥⚡)
            - 프롬프트 제출 시 컨페티 + 플래시 + 사운드
            - 에러 발생 시 화면 흔들림
            - 세션 완료 토스트
            - 레벨업 대형 컨페티
            """

            return BundledPluginDefinition(
                directoryName: "typing-combo-pack",
                files: [
                    BundledPluginFile(path: "plugin.json", contents: pluginJSON),
                    BundledPluginFile(path: "README.md", contents: readme)
                ]
            )

        // ── 프리미엄 가구 팩 ──
        case "premium-furniture-pack":
            let pluginJSON = """
            {
              "name": "프리미엄 가구 팩",
              "version": "1.0.0",
              "description": "프리미엄 가구 8종을 추가합니다",
              "author": "WorkMan",
              "contributes": {
                "furniture": [
                  {
                    "id": "aquarium",
                    "name": "아쿠아리움",
                    "sprite": [
                      ["4a90d9", "4a90d9", "4a90d9", "4a90d9"],
                      ["5bb8f5", "7ec8e3", "5bb8f5", "7ec8e3"],
                      ["5bb8f5", "f5a623", "7ec8e3", "f14c4c"],
                      ["5bb8f5", "7ec8e3", "5bb8f5", "7ec8e3"],
                      ["3ecf8e", "5bb8f5", "3ecf8e", "5bb8f5"],
                      ["8b7355", "8b7355", "8b7355", "8b7355"]
                    ],
                    "width": 2,
                    "height": 2,
                    "zone": "pantry"
                  },
                  {
                    "id": "arcade-machine",
                    "name": "아케이드 머신",
                    "sprite": [
                      ["", "2d2d2d", "2d2d2d", ""],
                      ["2d2d2d", "1a1a2e", "1a1a2e", "2d2d2d"],
                      ["2d2d2d", "3291ff", "3ecf8e", "2d2d2d"],
                      ["2d2d2d", "f14c4c", "f5a623", "2d2d2d"],
                      ["2d2d2d", "1a1a2e", "1a1a2e", "2d2d2d"],
                      ["", "f14c4c", "3291ff", ""],
                      ["2d2d2d", "2d2d2d", "2d2d2d", "2d2d2d"]
                    ],
                    "width": 2,
                    "height": 2,
                    "zone": "pantry"
                  },
                  {
                    "id": "neon-sign",
                    "name": "네온사인 'CODE'",
                    "sprite": [
                      ["ff6ec7", "3291ff", "3ecf8e", "f5a623"],
                      ["ff6ec7", "", "", "f5a623"],
                      ["ff6ec7", "3291ff", "3ecf8e", "f5a623"]
                    ],
                    "width": 2,
                    "height": 1,
                    "zone": "mainOffice"
                  },
                  {
                    "id": "bean-bag",
                    "name": "빈백 의자",
                    "sprite": [
                      ["", "8e4ec6", "8e4ec6", ""],
                      ["8e4ec6", "a06cd5", "a06cd5", "8e4ec6"],
                      ["8e4ec6", "a06cd5", "a06cd5", "8e4ec6"],
                      ["", "8e4ec6", "8e4ec6", ""]
                    ],
                    "width": 2,
                    "height": 1,
                    "zone": "pantry"
                  },
                  {
                    "id": "monstera",
                    "name": "몬스테라 화분",
                    "sprite": [
                      ["", "2d8a4e", "", ""],
                      ["2d8a4e", "3ecf8e", "2d8a4e", ""],
                      ["", "3ecf8e", "2d8a4e", "3ecf8e"],
                      ["", "2d8a4e", "3ecf8e", ""],
                      ["", "", "6b4226", ""],
                      ["", "8b5e3c", "8b5e3c", ""]
                    ],
                    "width": 1,
                    "height": 2,
                    "zone": "mainOffice"
                  },
                  {
                    "id": "standing-desk",
                    "name": "스탠딩 데스크",
                    "sprite": [
                      ["5a5a5a", "5a5a5a", "5a5a5a", "5a5a5a", "5a5a5a", "5a5a5a"],
                      ["8b7355", "d4a574", "d4a574", "d4a574", "d4a574", "8b7355"],
                      ["", "8b7355", "", "", "8b7355", ""],
                      ["", "8b7355", "", "", "8b7355", ""],
                      ["", "5a5a5a", "", "", "5a5a5a", ""]
                    ],
                    "width": 3,
                    "height": 2,
                    "zone": "mainOffice"
                  },
                  {
                    "id": "vending-machine",
                    "name": "자판기",
                    "sprite": [
                      ["3a3a3a", "3a3a3a", "3a3a3a", "3a3a3a"],
                      ["3a3a3a", "5bb8f5", "5bb8f5", "3a3a3a"],
                      ["3a3a3a", "f14c4c", "3ecf8e", "3a3a3a"],
                      ["3a3a3a", "f5a623", "3291ff", "3a3a3a"],
                      ["3a3a3a", "1a1a2e", "1a1a2e", "3a3a3a"],
                      ["3a3a3a", "3a3a3a", "3a3a3a", "3a3a3a"]
                    ],
                    "width": 2,
                    "height": 2,
                    "zone": "pantry"
                  },
                  {
                    "id": "ping-pong-table",
                    "name": "탁구대",
                    "sprite": [
                      ["2d6a4f", "2d6a4f", "ffffff", "2d6a4f", "2d6a4f", "2d6a4f"],
                      ["2d6a4f", "3ecf8e", "ffffff", "3ecf8e", "2d6a4f", ""],
                      ["", "8b7355", "", "", "8b7355", ""]
                    ],
                    "width": 3,
                    "height": 1,
                    "zone": "meetingRoom"
                  }
                ],
                "achievements": [
                  {
                    "id": "furniture-collector",
                    "name": "가구 컬렉터",
                    "description": "프리미엄 가구 팩을 설치했습니다",
                    "icon": "sofa.fill",
                    "rarity": "rare",
                    "xp": 200
                  }
                ]
              }
            }
            """

            let readme = """
            # 프리미엄 가구 팩

            사무실을 더욱 풍성하게 꾸밀 수 있는 프리미엄 가구 8종!

            ## 포함 가구
            - 🐠 아쿠아리움 — 팬트리에 놓는 수족관
            - 🕹️ 아케이드 머신 — 레트로 게임기
            - 💡 네온사인 'CODE' — 벽에 거는 네온
            - 🫘 빈백 의자 — 편안한 휴식 공간
            - 🌿 몬스테라 화분 — 대형 관엽식물
            - 🖥️ 스탠딩 데스크 — 일어서서 코딩
            - 🥤 자판기 — 음료 자판기
            - 🏓 탁구대 — 미팅룸 레크리에이션
            """

            return BundledPluginDefinition(
                directoryName: "premium-furniture-pack",
                files: [
                    BundledPluginFile(path: "plugin.json", contents: pluginJSON),
                    BundledPluginFile(path: "README.md", contents: readme)
                ]
            )

        // ── 바캉스 비치 팩 ──
        case "vacation-beach-pack":
            let characters = """
            [
              {
                "id": "beach_lifeguard",
                "name": "비치 라이프가드",
                "archetype": "해변 안전 요원 겸 시니어 개발자",
                "hairColor": "f5d380",
                "skinTone": "d4a574",
                "shirtColor": "f14c4c",
                "pantsColor": "f5d380",
                "hatType": "cap",
                "accessory": "sunglasses",
                "species": "Human",
                "jobRole": "developer"
              },
              {
                "id": "coconut_coder",
                "name": "코코넛 코더",
                "archetype": "코코넛 워터를 마시며 코딩하는 디지털 노마드",
                "hairColor": "2d2d2d",
                "skinTone": "e8c4a0",
                "shirtColor": "4ac6b7",
                "pantsColor": "3291ff",
                "hatType": "straw",
                "accessory": "sunglasses",
                "species": "Human",
                "jobRole": "developer"
              }
            ]
            """

            let pluginJSON = """
            {
              "name": "바캉스 비치 팩",
              "version": "1.0.0",
              "description": "사무실을 열대 해변으로! 야자수 아래에서 코딩하는 바캉스 오피스",
              "author": "WorkMan",
              "contributes": {
                "characters": "characters.json",
                "themes": [
                  {
                    "id": "beach-day",
                    "name": "비치 데이",
                    "isDark": false,
                    "accentHex": "00bcd4",
                    "bgHex": "e0f7fa",
                    "cardHex": "ffffff",
                    "textHex": "263238",
                    "greenHex": "4caf50",
                    "redHex": "ff5722",
                    "yellowHex": "ffc107",
                    "purpleHex": "9c27b0",
                    "cyanHex": "00bcd4",
                    "useGradient": true,
                    "gradientStartHex": "00bcd4",
                    "gradientEndHex": "ff9800"
                  },
                  {
                    "id": "sunset-beach",
                    "name": "선셋 비치",
                    "isDark": true,
                    "accentHex": "ff6f00",
                    "bgHex": "1a0a2e",
                    "cardHex": "2d1b4e",
                    "textHex": "ffe0b2",
                    "greenHex": "66bb6a",
                    "redHex": "ff7043",
                    "yellowHex": "ffca28",
                    "purpleHex": "ab47bc",
                    "cyanHex": "4dd0e1",
                    "useGradient": true,
                    "gradientStartHex": "ff6f00",
                    "gradientEndHex": "e91e63"
                  }
                ],
                "furniture": [
                  {
                    "id": "palm-tree",
                    "name": "야자수",
                    "sprite": [
                      ["", "", "2d8a4e", "3ecf8e", "2d8a4e", ""],
                      ["", "3ecf8e", "2d8a4e", "2d8a4e", "3ecf8e", "3ecf8e"],
                      ["3ecf8e", "2d8a4e", "", "", "2d8a4e", "3ecf8e"],
                      ["", "", "", "8b5e3c", "", ""],
                      ["", "", "", "8b5e3c", "", ""],
                      ["", "", "", "8b5e3c", "", ""],
                      ["", "", "", "8b5e3c", "", ""],
                      ["", "", "8b5e3c", "8b5e3c", "", ""]
                    ],
                    "width": 2,
                    "height": 3,
                    "zone": "mainOffice"
                  },
                  {
                    "id": "beach-parasol",
                    "name": "파라솔",
                    "sprite": [
                      ["", "f14c4c", "ffffff", "f14c4c", "ffffff", ""],
                      ["f14c4c", "ffffff", "f14c4c", "ffffff", "f14c4c", "ffffff"],
                      ["", "", "", "8b7355", "", ""],
                      ["", "", "", "8b7355", "", ""]
                    ],
                    "width": 2,
                    "height": 2,
                    "zone": "mainOffice"
                  },
                  {
                    "id": "surfboard",
                    "name": "서핑보드",
                    "sprite": [
                      ["", "3291ff", ""],
                      ["3291ff", "ffffff", "3291ff"],
                      ["3291ff", "00bcd4", "3291ff"],
                      ["3291ff", "ffffff", "3291ff"],
                      ["3291ff", "00bcd4", "3291ff"],
                      ["", "3291ff", ""]
                    ],
                    "width": 1,
                    "height": 2,
                    "zone": "mainOffice"
                  },
                  {
                    "id": "beach-chair",
                    "name": "비치 체어",
                    "sprite": [
                      ["", "ff9800", "ff9800", "ff9800", ""],
                      ["8b5e3c", "ffffff", "ff9800", "ffffff", "8b5e3c"],
                      ["", "8b5e3c", "", "8b5e3c", ""]
                    ],
                    "width": 2,
                    "height": 1,
                    "zone": "mainOffice"
                  },
                  {
                    "id": "tiki-bar",
                    "name": "티키 바",
                    "sprite": [
                      ["8b5e3c", "d4a574", "d4a574", "d4a574", "8b5e3c"],
                      ["8b5e3c", "d4a574", "d4a574", "d4a574", "8b5e3c"],
                      ["6b4226", "3ecf8e", "6b4226", "3ecf8e", "6b4226"],
                      ["8b5e3c", "", "", "", "8b5e3c"]
                    ],
                    "width": 2,
                    "height": 2,
                    "zone": "pantry"
                  },
                  {
                    "id": "sand-castle",
                    "name": "모래성",
                    "sprite": [
                      ["", "f5d380", ""],
                      ["f5d380", "e8c4a0", "f5d380"],
                      ["f5d380", "f5d380", "f5d380"]
                    ],
                    "width": 1,
                    "height": 1,
                    "zone": "mainOffice"
                  }
                ],
                "officePresets": [
                  {
                    "id": "beach-office",
                    "name": "비치 오피스",
                    "description": "야자수와 파라솔이 있는 해변 사무실",
                    "furniture": [
                      {"furnitureId": "palm-tree", "col": 2, "row": 1},
                      {"furnitureId": "palm-tree", "col": 18, "row": 1},
                      {"furnitureId": "beach-parasol", "col": 6, "row": 3},
                      {"furnitureId": "beach-parasol", "col": 14, "row": 3},
                      {"furnitureId": "surfboard", "col": 1, "row": 5},
                      {"furnitureId": "beach-chair", "col": 7, "row": 5},
                      {"furnitureId": "beach-chair", "col": 15, "row": 5},
                      {"furnitureId": "tiki-bar", "col": 10, "row": 2},
                      {"furnitureId": "sand-castle", "col": 5, "row": 8},
                      {"furnitureId": "sand-castle", "col": 16, "row": 7}
                    ]
                  }
                ],
                "effects": [
                  {
                    "id": "wave-sound",
                    "trigger": "onPromptSubmit",
                    "type": "toast",
                    "config": {
                      "text": "🌊 파도가 밀려옵니다... 코드도 밀어넣자!",
                      "icon": "water.waves",
                      "tint": "00bcd4",
                      "duration": 3.0
                    },
                    "enabled": true
                  },
                  {
                    "id": "beach-complete",
                    "trigger": "onSessionComplete",
                    "type": "confetti",
                    "config": {
                      "colors": ["00bcd4", "ff9800", "ffeb3b", "4caf50", "e91e63"],
                      "count": 50,
                      "duration": 3.5
                    },
                    "enabled": true
                  }
                ],
                "achievements": [
                  {
                    "id": "beach-coder",
                    "name": "비치 코더",
                    "description": "바캉스 비치 팩을 설치하고 해변에서 코딩을 시작했습니다",
                    "icon": "sun.max.fill",
                    "rarity": "epic",
                    "xp": 300
                  }
                ],
                "bossLines": [
                  "여기가 사무실이야, 해변이야? 코드 리뷰나 해!",
                  "파라솔 아래서 코딩하면 버그가 선크림처럼 묻어나온다고!",
                  "서핑보드 치워! 스프린트 보드에 집중해!",
                  "코코넛 워터 마시면서 코딩? ...나도 한 잔 줘."
                ]
              }
            }
            """

            let readme = """
            # 바캉스 비치 팩

            사무실을 열대 해변으로 변신시키는 테마 플러그인!
            야자수 아래에서, 파라솔 그늘에서, 티키 바 옆에서 코딩하세요.

            ## 포함 콘텐츠
            - 🌴 비치 테마 2종 (비치 데이 / 선셋 비치)
            - 🏖️ 해변 가구 6종 (야자수, 파라솔, 서핑보드, 비치체어, 티키바, 모래성)
            - 🏄 비치 오피스 프리셋
            - 🌊 서핑 이펙트 + 토스트
            - 👤 비치 캐릭터 2종 (라이프가드, 코코넛 코더)
            - 💬 사장 대사 4종 추가
            """

            return BundledPluginDefinition(
                directoryName: "vacation-beach-pack",
                files: [
                    BundledPluginFile(path: "plugin.json", contents: pluginJSON),
                    BundledPluginFile(path: "characters.json", contents: characters),
                    BundledPluginFile(path: "README.md", contents: readme)
                ]
            )

        // ── 배틀그라운드 팩 ──
        case "battleground-pack":
            let characters = """
            [
              {
                "id": "sniper_dev",
                "name": "스나이퍼 개발자",
                "archetype": "먼 거리에서 버그를 정조준하는 저격수",
                "hairColor": "3b3b3b",
                "skinTone": "c4a882",
                "shirtColor": "4b5320",
                "pantsColor": "3b3b2e",
                "hatType": "helmet",
                "accessory": "scope",
                "species": "Human",
                "jobRole": "developer"
              },
              {
                "id": "medic_coder",
                "name": "메딕 코더",
                "archetype": "쓰러진 코드를 되살리는 전장의 의무병",
                "hairColor": "8b4513",
                "skinTone": "e8c4a0",
                "shirtColor": "ffffff",
                "pantsColor": "4b5320",
                "hatType": "medic",
                "accessory": "cross",
                "species": "Human",
                "jobRole": "qa"
              },
              {
                "id": "scout_hacker",
                "name": "정찰병 해커",
                "archetype": "적진을 정찰하며 취약점을 찾는 침투 전문가",
                "hairColor": "2d2d2d",
                "skinTone": "d4a574",
                "shirtColor": "556b2f",
                "pantsColor": "3b3b2e",
                "hatType": "beret",
                "accessory": "radio",
                "species": "Human",
                "jobRole": "sre"
              }
            ]
            """

            let pluginJSON = """
            {
              "name": "배틀그라운드 팩",
              "version": "1.0.0",
              "description": "사무실이 전장으로! 나무와 바위에 은신하며 코딩하는 배그 컨셉",
              "author": "WorkMan",
              "contributes": {
                "characters": "characters.json",
                "themes": [
                  {
                    "id": "battleground-day",
                    "name": "배틀그라운드 (낮)",
                    "isDark": false,
                    "accentHex": "4b5320",
                    "bgHex": "e8e0d0",
                    "cardHex": "f0ead6",
                    "textHex": "2b2b1b",
                    "greenHex": "556b2f",
                    "redHex": "b22222",
                    "yellowHex": "daa520",
                    "purpleHex": "6b4226",
                    "cyanHex": "708090",
                    "useGradient": true,
                    "gradientStartHex": "4b5320",
                    "gradientEndHex": "8b7355"
                  },
                  {
                    "id": "battleground-night",
                    "name": "배틀그라운드 (밤)",
                    "isDark": true,
                    "accentHex": "556b2f",
                    "bgHex": "0d0d0d",
                    "cardHex": "1a1a1a",
                    "textHex": "a0a080",
                    "greenHex": "556b2f",
                    "redHex": "8b0000",
                    "yellowHex": "b8860b",
                    "purpleHex": "483d28",
                    "cyanHex": "4a5859",
                    "useGradient": true,
                    "gradientStartHex": "1a2e1a",
                    "gradientEndHex": "0d0d0d"
                  }
                ],
                "furniture": [
                  {
                    "id": "oak-tree",
                    "name": "참나무 (은엄폐)",
                    "sprite": [
                      ["", "2d5a1e", "3ecf8e", "2d5a1e", ""],
                      ["2d5a1e", "3ecf8e", "2d8a4e", "3ecf8e", "2d5a1e"],
                      ["3ecf8e", "2d8a4e", "3ecf8e", "2d8a4e", "3ecf8e"],
                      ["2d5a1e", "3ecf8e", "2d8a4e", "3ecf8e", "2d5a1e"],
                      ["", "", "6b4226", "", ""],
                      ["", "", "6b4226", "", ""],
                      ["", "6b4226", "6b4226", "6b4226", ""]
                    ],
                    "width": 2,
                    "height": 3,
                    "zone": "mainOffice"
                  },
                  {
                    "id": "boulder",
                    "name": "바위 (엄폐물)",
                    "sprite": [
                      ["", "808080", "808080", ""],
                      ["696969", "808080", "a9a9a9", "808080"],
                      ["808080", "a9a9a9", "808080", "696969"],
                      ["", "808080", "808080", ""]
                    ],
                    "width": 2,
                    "height": 1,
                    "zone": "mainOffice"
                  },
                  {
                    "id": "bush-cover",
                    "name": "수풀 (은신처)",
                    "sprite": [
                      ["", "2d8a4e", "3ecf8e", "2d8a4e", ""],
                      ["2d8a4e", "3ecf8e", "2d5a1e", "3ecf8e", "2d8a4e"],
                      ["3ecf8e", "2d5a1e", "3ecf8e", "2d5a1e", "3ecf8e"]
                    ],
                    "width": 2,
                    "height": 1,
                    "zone": "mainOffice"
                  },
                  {
                    "id": "sandbag-wall",
                    "name": "모래주머니 바리케이드",
                    "sprite": [
                      ["c2b280", "c2b280", "c2b280", "c2b280", "c2b280", "c2b280"],
                      ["b8a070", "c2b280", "b8a070", "c2b280", "b8a070", "c2b280"],
                      ["c2b280", "b8a070", "c2b280", "b8a070", "c2b280", "b8a070"]
                    ],
                    "width": 3,
                    "height": 1,
                    "zone": "mainOffice"
                  },
                  {
                    "id": "supply-crate",
                    "name": "보급 상자",
                    "sprite": [
                      ["5a5a3e", "5a5a3e", "5a5a3e", "5a5a3e"],
                      ["5a5a3e", "f5a623", "f5a623", "5a5a3e"],
                      ["5a5a3e", "5a5a3e", "5a5a3e", "5a5a3e"]
                    ],
                    "width": 2,
                    "height": 1,
                    "zone": "mainOffice"
                  },
                  {
                    "id": "watchtower",
                    "name": "감시탑",
                    "sprite": [
                      ["8b7355", "8b7355", "8b7355", "8b7355"],
                      ["", "5a5a3e", "5a5a3e", ""],
                      ["", "6b4226", "6b4226", ""],
                      ["", "6b4226", "6b4226", ""],
                      ["", "6b4226", "6b4226", ""],
                      ["6b4226", "6b4226", "6b4226", "6b4226"]
                    ],
                    "width": 2,
                    "height": 3,
                    "zone": "mainOffice"
                  },
                  {
                    "id": "military-tent",
                    "name": "군용 텐트",
                    "sprite": [
                      ["", "", "4b5320", "", ""],
                      ["", "4b5320", "556b2f", "4b5320", ""],
                      ["4b5320", "556b2f", "3b3b2e", "556b2f", "4b5320"],
                      ["4b5320", "3b3b2e", "3b3b2e", "3b3b2e", "4b5320"]
                    ],
                    "width": 2,
                    "height": 2,
                    "zone": "meetingRoom"
                  },
                  {
                    "id": "barbed-wire",
                    "name": "철조망",
                    "sprite": [
                      ["808080", "", "808080", "", "808080", "", "808080"],
                      ["", "808080", "", "808080", "", "808080", ""],
                      ["808080", "", "808080", "", "808080", "", "808080"]
                    ],
                    "width": 3,
                    "height": 1,
                    "zone": "mainOffice"
                  }
                ],
                "officePresets": [
                  {
                    "id": "battleground-map",
                    "name": "배틀그라운드 맵",
                    "description": "나무, 바위, 수풀로 가득한 전장. 엄폐하며 코딩하라!",
                    "furniture": [
                      {"furnitureId": "oak-tree", "col": 2, "row": 1},
                      {"furnitureId": "oak-tree", "col": 16, "row": 2},
                      {"furnitureId": "oak-tree", "col": 9, "row": 7},
                      {"furnitureId": "boulder", "col": 5, "row": 4},
                      {"furnitureId": "boulder", "col": 13, "row": 6},
                      {"furnitureId": "boulder", "col": 19, "row": 8},
                      {"furnitureId": "bush-cover", "col": 3, "row": 6},
                      {"furnitureId": "bush-cover", "col": 11, "row": 3},
                      {"furnitureId": "bush-cover", "col": 17, "row": 5},
                      {"furnitureId": "sandbag-wall", "col": 7, "row": 2},
                      {"furnitureId": "sandbag-wall", "col": 14, "row": 8},
                      {"furnitureId": "supply-crate", "col": 10, "row": 5},
                      {"furnitureId": "watchtower", "col": 1, "row": 8},
                      {"furnitureId": "military-tent", "col": 18, "row": 1},
                      {"furnitureId": "barbed-wire", "col": 6, "row": 9}
                    ]
                  }
                ],
                "effects": [
                  {
                    "id": "airdrop-alert",
                    "trigger": "onPromptSubmit",
                    "type": "toast",
                    "config": {
                      "text": "📦 에어드랍 투하! 프롬프트 전송 완료",
                      "icon": "shippingbox.fill",
                      "tint": "f5a623",
                      "duration": 3.0
                    },
                    "enabled": true
                  },
                  {
                    "id": "zone-shrink",
                    "trigger": "onSessionError",
                    "type": "screen-shake",
                    "config": {
                      "intensity": 8.0,
                      "duration": 0.5
                    },
                    "enabled": true
                  },
                  {
                    "id": "zone-warning",
                    "trigger": "onSessionError",
                    "type": "flash",
                    "config": {
                      "colorHex": "b22222",
                      "duration": 0.4
                    },
                    "enabled": true
                  },
                  {
                    "id": "zone-warning-toast",
                    "trigger": "onSessionError",
                    "type": "toast",
                    "config": {
                      "text": "⚠️ 자기장이 줄어들고 있습니다! 버그를 처치하세요!",
                      "icon": "exclamationmark.triangle.fill",
                      "tint": "b22222",
                      "duration": 4.0
                    },
                    "enabled": true
                  },
                  {
                    "id": "chicken-dinner",
                    "trigger": "onSessionComplete",
                    "type": "confetti",
                    "config": {
                      "colors": ["f5a623", "4b5320", "daa520", "556b2f", "8b7355"],
                      "count": 60,
                      "duration": 4.0
                    },
                    "enabled": true
                  },
                  {
                    "id": "winner-toast",
                    "trigger": "onSessionComplete",
                    "type": "toast",
                    "config": {
                      "text": "🍗 이겼닭! 오늘 저녁은 치킨이닭!",
                      "icon": "trophy.fill",
                      "tint": "f5a623",
                      "duration": 5.0
                    },
                    "enabled": true
                  },
                  {
                    "id": "kill-combo",
                    "trigger": "onPromptKeyPress",
                    "type": "combo-counter",
                    "config": {
                      "decaySeconds": 3.0,
                      "shakeOnMilestone": true
                    },
                    "enabled": true
                  }
                ],
                "achievements": [
                  {
                    "id": "chicken-dinner",
                    "name": "이겼닭! 오늘 저녁은 치킨이닭!",
                    "description": "배틀그라운드 테마에서 첫 세션을 완료했습니다",
                    "icon": "trophy.fill",
                    "rarity": "legendary",
                    "xp": 500
                  },
                  {
                    "id": "bush-camper",
                    "name": "수풀 캠퍼",
                    "description": "수풀에 숨어서 30분 이상 코딩했습니다",
                    "icon": "leaf.fill",
                    "rarity": "epic",
                    "xp": 350
                  }
                ],
                "bossLines": [
                  "적이 접근 중이다! 코드 커밋 서둘러!",
                  "자기장 밖에 있으면 CR 리젝당한다!",
                  "에어드랍에 핫픽스가 들어있다! 빨리 수거해!",
                  "수풀에 숨어있지 말고 PR 올려!",
                  "보급 상자에서 새 라이브러리 발견! 도입 검토 해봐!",
                  "이겼닭? 아직 배포 안 했잖아!"
                ]
              }
            }
            """

            let readme = """
            # 배틀그라운드 팩

            사무실이 전장으로 변합니다! 나무와 바위 사이에서 은신하며 코딩하세요.
            에러가 나면 자기장이 줄어들고, 세션 완료하면 치킨 디너!

            ## 포함 콘텐츠
            - 🎯 배틀그라운드 테마 2종 (낮/밤)
            - 🌲 전장 가구 8종 (참나무, 바위, 수풀, 모래주머니, 보급상자, 감시탑, 군용텐트, 철조망)
            - 🗺️ 배틀그라운드 맵 프리셋
            - 📦 에어드랍 토스트 + 자기장 이펙트
            - 🍗 치킨 디너 컨페티
            - 👤 전장 캐릭터 3종 (스나이퍼, 메딕, 정찰병)
            - 💬 전장 사장 대사 6종
            - 🏆 업적 2종 (치킨 디너, 수풀 캠퍼)
            """

            return BundledPluginDefinition(
                directoryName: "battleground-pack",
                files: [
                    BundledPluginFile(path: "plugin.json", contents: pluginJSON),
                    BundledPluginFile(path: "characters.json", contents: characters),
                    BundledPluginFile(path: "README.md", contents: readme)
                ]
            )

        default:
            return nil
        }
    }

    private static func firstString(in raw: [String: Any], keys: [String]) -> String? {
        for key in keys {
            if let value = raw[key] as? String {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    return trimmed
                }
            }
        }
        return nil
    }

    private static func firstInt(in raw: [String: Any], keys: [String]) -> Int? {
        for key in keys {
            if let value = raw[key] as? Int {
                return max(0, value)
            }
            if let value = raw[key] as? NSNumber {
                return max(0, value.intValue)
            }
            if let value = raw[key] as? String,
               let parsed = Int(value.trimmingCharacters(in: .whitespacesAndNewlines)) {
                return max(0, parsed)
            }
        }
        return nil
    }

    private static func stringArray(in raw: [String: Any], keys: [String]) -> [String] {
        for key in keys {
            if let values = raw[key] as? [String] {
                return values.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            }
            if let value = raw[key] as? String {
                return value
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            }
        }
        return []
    }

    private static func slugifiedRegistryID(from text: String) -> String {
        let allowed = CharacterSet.alphanumerics
        let components = text.lowercased()
            .components(separatedBy: allowed.inverted)
            .filter { !$0.isEmpty }
        return components.isEmpty ? UUID().uuidString.lowercased() : components.joined(separator: "-")
    }
}
