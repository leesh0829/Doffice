import SwiftUI
import DesignSystem

// ═══════════════════════════════════════════════════════
// MARK: - Office Scene Theme Support
// ═══════════════════════════════════════════════════════

public enum OfficeSceneBackdropKind {
    case bright
    case sunset
    case night
    case weather
    case blossom
    case forest
    case neon
    case ocean
    case desert
    case volcano
}

public struct OfficeScenePalette {
    public let backdropTop: String
    public let backdropBottom: String
    public let backdropGlow: String
    public let wallBase: String
    public let wallHighlight: String
    public let wallBright: String
    public let wallShadow: String
    public let trim: String
    public let trimHighlight: String
    public let windowFrame: String
    public let windowSill: String
    public let windowGlow: String
    public let beamColor: String
    public let beamOpacity: Double
    public let outdoorAccent: String
    public let outdoorAccent2: String
    public let officeFloor: [String]
    public let pantryFloor: [String]
    public let carpetFloor: [String]
    public let labelOpacity: Double

    // Memberwise init (커스텀 init이 있으면 자동 생성 안 됨)
    public init(backdropTop: String, backdropBottom: String, backdropGlow: String,
         wallBase: String, wallHighlight: String, wallBright: String, wallShadow: String,
         trim: String, trimHighlight: String,
         windowFrame: String, windowSill: String, windowGlow: String,
         beamColor: String, beamOpacity: Double,
         outdoorAccent: String, outdoorAccent2: String,
         officeFloor: [String], pantryFloor: [String], carpetFloor: [String],
         labelOpacity: Double) {
        self.backdropTop = backdropTop; self.backdropBottom = backdropBottom; self.backdropGlow = backdropGlow
        self.wallBase = wallBase; self.wallHighlight = wallHighlight; self.wallBright = wallBright; self.wallShadow = wallShadow
        self.trim = trim; self.trimHighlight = trimHighlight
        self.windowFrame = windowFrame; self.windowSill = windowSill; self.windowGlow = windowGlow
        self.beamColor = beamColor; self.beamOpacity = beamOpacity
        self.outdoorAccent = outdoorAccent; self.outdoorAccent2 = outdoorAccent2
        self.officeFloor = officeFloor; self.pantryFloor = pantryFloor; self.carpetFloor = carpetFloor
        self.labelOpacity = labelOpacity
    }

    public init(theme: BackgroundTheme, dark: Bool) {
        let floorOverride = theme.floorColors

        switch theme.officeSceneBackdropKind {
        case .bright:
            self = OfficeScenePalette(
                backdropTop: theme.skyColors.top,
                backdropBottom: theme.skyColors.bottom,
                backdropGlow: dark ? "DDEFCB" : "F4F7E2",
                wallBase: dark ? "24344A" : "38506F",
                wallHighlight: dark ? "5A7394" : "7F9CC1",
                wallBright: dark ? "84A0C2" : "B8CCE4",
                wallShadow: dark ? "101723" : "203044",
                trim: dark ? "8D5C34" : "B87941",
                trimHighlight: dark ? "D19A60" : "EDBE7B",
                windowFrame: dark ? "ECF5FF" : "FFFDF8",
                windowSill: dark ? "8A6036" : "B97A47",
                windowGlow: dark ? "D8F4FF" : "FFFFFF",
                beamColor: dark ? "FFE7A6" : "FFF1BE",
                beamOpacity: dark ? 0.08 : 0.13,
                outdoorAccent: dark ? "D6EEF9" : "F7FFFF",
                outdoorAccent2: dark ? "84B87B" : "7AB76C",
                officeFloor: [floorOverride.base.isEmpty ? (dark ? "8A623A" : "D3A063") : floorOverride.base,
                              floorOverride.dot.isEmpty ? (dark ? "775230" : "BF8A4F") : floorOverride.dot,
                              dark ? "9E754A" : "E4BB82",
                              dark ? "634427" : "9E6734"],
                pantryFloor: dark ? ["4D443A", "423A31", "6B5F50"] : ["F1E4D1", "E2D3BD", "FBF2E5"],
                carpetFloor: dark ? ["35546C", "2E495E", "4C7088"] : ["5A85A5", "4D7494", "7EA4C1"],
                labelOpacity: 0.04
            )
        case .sunset:
            self = OfficeScenePalette(
                backdropTop: theme.skyColors.top,
                backdropBottom: theme.skyColors.bottom,
                backdropGlow: dark ? "F8C98E" : "FFE5B8",
                wallBase: dark ? "362E46" : "544A69",
                wallHighlight: dark ? "7A688F" : "A184A7",
                wallBright: dark ? "B191A8" : "D3B1BD",
                wallShadow: dark ? "181421" : "31263A",
                trim: dark ? "885132" : "B36C41",
                trimHighlight: dark ? "E0AB69" : "FFCB8C",
                windowFrame: dark ? "F9E5D3" : "FFF4EA",
                windowSill: dark ? "9B6138" : "C97E4B",
                windowGlow: "FFF4D8",
                beamColor: dark ? "FFC983" : "FFDDA1",
                beamOpacity: dark ? 0.12 : 0.18,
                outdoorAccent: dark ? "F1CAA9" : "FFF1D8",
                outdoorAccent2: dark ? "7A4E5A" : "B7756C",
                officeFloor: [floorOverride.base.isEmpty ? "C0854F" : floorOverride.base,
                              floorOverride.dot.isEmpty ? "A56C3C" : floorOverride.dot,
                              "E2AF73",
                              "7D4B27"],
                pantryFloor: dark ? ["5C463B", "503D33", "7A6254"] : ["F7E5D4", "E9D0BF", "FFF0E2"],
                carpetFloor: dark ? ["5B4A6A", "4B3D59", "836A8D"] : ["90799E", "7B6789", "B69EC0"],
                labelOpacity: 0.05
            )
        case .night:
            self = OfficeScenePalette(
                backdropTop: theme.skyColors.top,
                backdropBottom: theme.skyColors.bottom,
                backdropGlow: dark ? "94B8EA" : "C4D7F0",
                wallBase: dark ? "1B2740" : "314A6B",
                wallHighlight: dark ? "4A638A" : "6B87B0",
                wallBright: dark ? "7693B7" : "A7BDD8",
                wallShadow: dark ? "0A101B" : "1B2A40",
                trim: dark ? "5E6F8F" : "849ABA",
                trimHighlight: dark ? "9DB2D4" : "D6E4F6",
                windowFrame: dark ? "E4EEFF" : "F8FBFF",
                windowSill: dark ? "546784" : "758EB0",
                windowGlow: dark ? "CAE2FF" : "FFFFFF",
                beamColor: dark ? "B9D5FF" : "D8EAFF",
                beamOpacity: dark ? 0.05 : 0.08,
                outdoorAccent: dark ? "F7F8FF" : "FFFFFF",
                outdoorAccent2: dark ? "6A84B5" : "91A9D2",
                officeFloor: [floorOverride.base.isEmpty ? (dark ? "516075" : "6A7F99") : floorOverride.base,
                              floorOverride.dot.isEmpty ? (dark ? "404E61" : "54657D") : floorOverride.dot,
                              dark ? "6E7F95" : "8EA4BD",
                              dark ? "2B3748" : "40526A"],
                pantryFloor: dark ? ["384252", "313949", "556177"] : ["E4E8EE", "D5DCE5", "F8FBFF"],
                carpetFloor: dark ? ["274058", "20364C", "355570"] : ["587A9A", "4B6B89", "7EA0BD"],
                labelOpacity: 0.06
            )
        case .weather:
            self = OfficeScenePalette(
                backdropTop: theme.skyColors.top,
                backdropBottom: theme.skyColors.bottom,
                backdropGlow: dark ? "C9D8E1" : "EDF4F7",
                wallBase: dark ? "2A3440" : "4A5D72",
                wallHighlight: dark ? "657483" : "90A3B7",
                wallBright: dark ? "95A6B6" : "BCCCDC",
                wallShadow: dark ? "151B21" : "293544",
                trim: dark ? "707B85" : "919EA8",
                trimHighlight: dark ? "A7B3BC" : "C9D5DD",
                windowFrame: dark ? "EBF2F4" : "FCFEFF",
                windowSill: dark ? "7A858E" : "9CA8AF",
                windowGlow: dark ? "DCE8EF" : "FFFFFF",
                beamColor: dark ? "DCE8EF" : "EEF7FA",
                beamOpacity: dark ? 0.03 : 0.05,
                outdoorAccent: dark ? "DCEAF0" : "F9FFFF",
                outdoorAccent2: dark ? "7F919E" : "B5C1C8",
                officeFloor: [floorOverride.base.isEmpty ? (dark ? "7D8869" : "D0D4C2") : floorOverride.base,
                              floorOverride.dot.isEmpty ? (dark ? "697457" : "B7BDA9") : floorOverride.dot,
                              dark ? "97A086" : "E1E6D7",
                              dark ? "4F5842" : "949A82"],
                pantryFloor: dark ? ["424A52", "383F46", "5B656D"] : ["ECEEEF", "DEE2E6", "FBFDFF"],
                carpetFloor: dark ? ["496173", "405667", "627D90"] : ["7F95A5", "708593", "A3B4BF"],
                labelOpacity: 0.05
            )
        case .blossom:
            self = OfficeScenePalette(
                backdropTop: theme.skyColors.top,
                backdropBottom: theme.skyColors.bottom,
                backdropGlow: "FFF5FA",
                wallBase: dark ? "4A3850" : "6F566C",
                wallHighlight: dark ? "8C6E91" : "B490B2",
                wallBright: dark ? "D1AFC5" : "E8C9D7",
                wallShadow: dark ? "241A27" : "453245",
                trim: dark ? "A77587" : "C990A3",
                trimHighlight: dark ? "F0C3D2" : "FFE0EA",
                windowFrame: dark ? "FBEAF0" : "FFF8FB",
                windowSill: dark ? "A87A8A" : "CE9BAA",
                windowGlow: "FFFFFF",
                beamColor: "FFE6F0",
                beamOpacity: dark ? 0.08 : 0.12,
                outdoorAccent: dark ? "FAD9E4" : "FFF2F7",
                outdoorAccent2: dark ? "B47F92" : "E2B7C7",
                officeFloor: [floorOverride.base.isEmpty ? "D3C5C8" : floorOverride.base,
                              floorOverride.dot.isEmpty ? "C0B1B4" : floorOverride.dot,
                              "E7DADE",
                              "9E8C92"],
                pantryFloor: dark ? ["554650", "4B3D46", "75606D"] : ["F6EBF0", "EBDDE4", "FFF7FB"],
                carpetFloor: dark ? ["615170", "534561", "8B7799"] : ["AD98B9", "9985A5", "D3C1DD"],
                labelOpacity: 0.05
            )
        case .forest:
            self = OfficeScenePalette(
                backdropTop: theme.skyColors.top,
                backdropBottom: theme.skyColors.bottom,
                backdropGlow: dark ? "D3E2C2" : "EEF7D8",
                wallBase: dark ? "22382E" : "365948",
                wallHighlight: dark ? "537761" : "73977E",
                wallBright: dark ? "89AF92" : "B2D2B9",
                wallShadow: dark ? "0D1712" : "22372A",
                trim: dark ? "6B5333" : "92714A",
                trimHighlight: dark ? "AE8C60" : "D6B17D",
                windowFrame: dark ? "EEF6ED" : "FCFEFA",
                windowSill: dark ? "708B67" : "90AA82",
                windowGlow: "F6FFF0",
                beamColor: "E6F8C6",
                beamOpacity: dark ? 0.06 : 0.10,
                outdoorAccent: dark ? "BFE29A" : "E0F8BC",
                outdoorAccent2: dark ? "49693E" : "78A35C",
                officeFloor: [floorOverride.base.isEmpty ? "7C6A4A" : floorOverride.base,
                              floorOverride.dot.isEmpty ? "66573D" : floorOverride.dot,
                              "A48A61",
                              "54452E"],
                pantryFloor: dark ? ["3D493D", "334033", "596A57"] : ["E6ECD8", "D5DEC7", "F7FBEF"],
                carpetFloor: dark ? ["39584A", "2F4B3F", "4E7663"] : ["7DA392", "668C7B", "A8C8B8"],
                labelOpacity: 0.05
            )
        case .neon:
            self = OfficeScenePalette(
                backdropTop: theme.skyColors.top,
                backdropBottom: theme.skyColors.bottom,
                backdropGlow: dark ? "F66BC5" : "FF9DDD",
                wallBase: dark ? "241934" : "34224B",
                wallHighlight: dark ? "5F4A86" : "8162B4",
                wallBright: dark ? "A184D9" : "C5B1EF",
                wallShadow: dark ? "0C0915" : "1F1630",
                trim: dark ? "1CC6B2" : "22D6C4",
                trimHighlight: dark ? "73FFE6" : "B3FFF1",
                windowFrame: dark ? "F7E7FF" : "FFF9FF",
                windowSill: dark ? "683A83" : "9654BF",
                windowGlow: dark ? "F2B9FF" : "FFE0FF",
                beamColor: dark ? "FF76D1" : "FF9BE0",
                beamOpacity: dark ? 0.09 : 0.12,
                outdoorAccent: dark ? "5BF1FF" : "A8FFFF",
                outdoorAccent2: dark ? "FF69CC" : "FF8EDB",
                officeFloor: [floorOverride.base.isEmpty ? "352448" : floorOverride.base,
                              floorOverride.dot.isEmpty ? "261835" : floorOverride.dot,
                              "5F4580",
                              "160D24"],
                pantryFloor: dark ? ["2D2440", "231C34", "4C3D6A"] : ["F0E8FF", "E5DAFA", "FFF9FF"],
                carpetFloor: dark ? ["223754", "172A44", "395C84"] : ["5A84BC", "4C72A6", "88AEE2"],
                labelOpacity: 0.08
            )
        case .ocean:
            self = OfficeScenePalette(
                backdropTop: theme.skyColors.top,
                backdropBottom: theme.skyColors.bottom,
                backdropGlow: dark ? "D7F8FF" : "F2FFFF",
                wallBase: dark ? "123A5C" : "21557A",
                wallHighlight: dark ? "44759A" : "5A92BE",
                wallBright: dark ? "83B3D8" : "B8DDF3",
                wallShadow: dark ? "081723" : "153247",
                trim: dark ? "3C8A95" : "57AFC0",
                trimHighlight: dark ? "9FE7F2" : "D5FBFF",
                windowFrame: dark ? "EEFCFF" : "FDFFFF",
                windowSill: dark ? "5C98A4" : "79C0CC",
                windowGlow: "FFFFFF",
                beamColor: "C1F7FF",
                beamOpacity: dark ? 0.07 : 0.10,
                outdoorAccent: dark ? "B8EEFF" : "F3FFFF",
                outdoorAccent2: dark ? "2B8BB4" : "60B9D6",
                officeFloor: [floorOverride.base.isEmpty ? "21405B" : floorOverride.base,
                              floorOverride.dot.isEmpty ? "183248" : floorOverride.dot,
                              "3E6180",
                              "0E2235"],
                pantryFloor: dark ? ["1F4356", "193748", "316279"] : ["DDF1F5", "CCE5EB", "F6FDFF"],
                carpetFloor: dark ? ["185171", "123F5A", "24749A"] : ["3E8FB4", "2F7B9E", "69B7D7"],
                labelOpacity: 0.06
            )
        case .desert:
            self = OfficeScenePalette(
                backdropTop: theme.skyColors.top,
                backdropBottom: theme.skyColors.bottom,
                backdropGlow: dark ? "FFE6B0" : "FFF0CC",
                wallBase: dark ? "4A3627" : "705540",
                wallHighlight: dark ? "8B6C52" : "B7906D",
                wallBright: dark ? "C7A27D" : "E5C59D",
                wallShadow: dark ? "20150E" : "453224",
                trim: dark ? "A86E3C" : "D18D4F",
                trimHighlight: dark ? "F1BC76" : "FFD49A",
                windowFrame: dark ? "FFF2DB" : "FFF9EE",
                windowSill: dark ? "B07F4E" : "D7A06A",
                windowGlow: "FFFDF4",
                beamColor: "FFE3A0",
                beamOpacity: dark ? 0.08 : 0.12,
                outdoorAccent: dark ? "F8D5A1" : "FFECC7",
                outdoorAccent2: dark ? "C18D57" : "E4AF74",
                officeFloor: [floorOverride.base.isEmpty ? "B88A57" : floorOverride.base,
                              floorOverride.dot.isEmpty ? "A77946" : floorOverride.dot,
                              "D4AB74",
                              "8B6236"],
                pantryFloor: dark ? ["5C4C38", "53442F", "7A684D"] : ["F4E7D3", "E6D4B8", "FFF5E6"],
                carpetFloor: dark ? ["6D5533", "5C472C", "8F7145"] : ["B09162", "9B7C53", "D1B183"],
                labelOpacity: 0.05
            )
        case .volcano:
            self = OfficeScenePalette(
                backdropTop: theme.skyColors.top,
                backdropBottom: theme.skyColors.bottom,
                backdropGlow: dark ? "FF9071" : "FFB89C",
                wallBase: dark ? "3B1B1B" : "5A2B2B",
                wallHighlight: dark ? "7E4848" : "AD6363",
                wallBright: dark ? "B77C7C" : "E2B0A2",
                wallShadow: dark ? "150808" : "2E1414",
                trim: dark ? "B94F31" : "E16A41",
                trimHighlight: dark ? "FFB070" : "FFD09A",
                windowFrame: dark ? "FFF1E7" : "FFF8F3",
                windowSill: dark ? "A75034" : "D56C43",
                windowGlow: "FFF4EA",
                beamColor: "FFAF7E",
                beamOpacity: dark ? 0.07 : 0.11,
                outdoorAccent: dark ? "FFDAA6" : "FFF0D0",
                outdoorAccent2: dark ? "AD3D2F" : "E55B3B",
                officeFloor: [floorOverride.base.isEmpty ? "572626" : floorOverride.base,
                              floorOverride.dot.isEmpty ? "431A1A" : floorOverride.dot,
                              "794242",
                              "271010"],
                pantryFloor: dark ? ["4E3939", "432F2F", "664A4A"] : ["F0E1DE", "E2CFCB", "FFF7F4"],
                carpetFloor: dark ? ["632B2B", "4F1F1F", "904444"] : ["A95A5A", "944949", "CF8585"],
                labelOpacity: 0.06
            )
        }
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - Office Scene Store
// ═══════════════════════════════════════════════════════

public final class OfficeSceneStore: ObservableObject {
    public static let shared = OfficeSceneStore()

    public let map: OfficeMap
    public let controller: OfficeCharacterController
    @Published public var defaultLayout: OfficeLayoutSnapshot
    @Published public var currentPreset: OfficePreset
    @Published public var cameraCenter: CGPoint
    @Published public var cameraZoom: CGFloat = 1
    @Published public var followingCharacterId: String?
    @Published public var followZoomLevel: CGFloat = 1.85  // 팔로우 줌 배율 (1.2 ~ 3.0)
    @Published public var backgroundSnapshot: CGImage?

    @Published public var frame: Int = 0
    @Published public var needsRedraw: Bool = false
    public var chromeScreenshots: [String: CGImage] = [:]  // Canvas가 frame 타이머로 읽으므로 @Published 불필요

    /// Cached palette — invalidated when theme or dark mode changes.
    private var _cachedPalette: OfficeScenePalette?
    private var _cachedPaletteKey: Int = -1

    public func cachedPalette(theme: BackgroundTheme, dark: Bool) -> OfficeScenePalette {
        let key = theme.hashValue ^ (dark ? 1 : 0)
        if key == _cachedPaletteKey, let cached = _cachedPalette {
            return cached
        }
        let palette = OfficeScenePalette(theme: theme, dark: dark)
        _cachedPalette = palette
        _cachedPaletteKey = key
        return palette
    }

    private var lastAdvanceTime: TimeInterval = 0
    private var accumulatedAdvanceTime: TimeInterval = 0
    private var lastChromeCaptureTime: TimeInterval = 0
    private var lastSyncSignature: Int?
    private var backgroundSnapshotSignature: Int?
    private var isPreparingBackgroundSnapshot = false

    private init() {
        let preset = OfficePreset(rawValue: AppSettings.shared.officePreset) ?? .cozy
        let officeMap = OfficeMap.defaultOffice(preset: preset)
        let baseLayout = officeMap.layoutSnapshot()
        OfficeLayoutStore.shared.applyStoredLayout(to: officeMap, preset: preset)

        self.map = officeMap
        self.defaultLayout = baseLayout
        self.currentPreset = preset
        self.cameraCenter = CGPoint(
            x: CGFloat(officeMap.cols) * OfficeConstants.tileSize / 2,
            y: CGFloat(officeMap.rows) * OfficeConstants.tileSize / 2
        )
        self.controller = OfficeCharacterController(map: officeMap)
    }

    public func advance(with tabs: [TerminalTab], activeTabId: String?, focusMode: Bool, fps: Double = OfficeConstants.fps) {
        let now = Date().timeIntervalSinceReferenceDate
        let elapsed = lastAdvanceTime == 0 ? (1.0 / OfficeConstants.fps) : (now - lastAdvanceTime)
        lastAdvanceTime = now

        syncCharactersIfNeeded(with: tabs)

        let preferredFPS = max(fps, 1)
        let effectiveFPS = controller.hasAnimatedMovement ? OfficeConstants.fps : preferredFPS
        let step = 1.0 / effectiveFPS
        accumulatedAdvanceTime += min(elapsed, 0.25)  // cap delta to prevent physics jumps after long pauses

        guard accumulatedAdvanceTime >= step else { return }

        let prevCharacters = controller.characters
        let maxCatchUpSteps = max(1, Int(ceil(0.25 / step)))
        var steps = 0

        // Fixed-step simulation keeps pixel movement cadence stable even if the main-thread timer jitters.
        while accumulatedAdvanceTime >= step && steps < maxCatchUpSteps {
            frame += 1
            controller.tick(deltaTime: step)
            updateCamera(activeTabId: activeTabId, focusMode: focusMode)
            accumulatedAdvanceTime -= step
            steps += 1
        }

        if steps == maxCatchUpSteps {
            accumulatedAdvanceTime = min(accumulatedAdvanceTime, step)
        }

        // Mark redraw needed if any character state actually changed
        let changed = prevCharacters.count != controller.characters.count ||
            prevCharacters.contains { id, ch in
                guard let newCh = controller.characters[id] else { return true }
                return ch.pixelX != newCh.pixelX || ch.pixelY != newCh.pixelY || ch.frame != newCh.frame
            }
        needsRedraw = changed || steps > 0
    }

    public func refreshLayout(with tabs: [TerminalTab]) {
        controller.refreshLayout(with: tabs)
        lastSyncSignature = syncSignature(for: tabs)
        invalidateBackgroundSnapshot()
        objectWillChange.send()
    }

    public func applyPreset(_ preset: OfficePreset, with tabs: [TerminalTab]) {
        currentPreset = preset
        let baseLayout = OfficeMap.defaultLayoutSnapshot(preset: preset)
        defaultLayout = baseLayout
        map.applyLayoutSnapshot(baseLayout)
        OfficeLayoutStore.shared.applyStoredLayout(to: map, preset: preset)
        controller.refreshLayout(with: tabs)
        lastSyncSignature = syncSignature(for: tabs)
        invalidateBackgroundSnapshot()
        cameraCenter = CGPoint(
            x: CGFloat(map.cols) * OfficeConstants.tileSize / 2,
            y: CGFloat(map.rows) * OfficeConstants.tileSize / 2
        )
        cameraZoom = 1
        objectWillChange.send()
    }

    public func saveCurrentLayout() {
        OfficeLayoutStore.shared.saveLayout(from: map, preset: currentPreset)
    }

    public func resetCurrentLayout(with tabs: [TerminalTab]) {
        map.applyLayoutSnapshot(defaultLayout)
        controller.refreshLayout(with: tabs)
        lastSyncSignature = syncSignature(for: tabs)
        invalidateBackgroundSnapshot()
        OfficeLayoutStore.shared.resetSavedLayout(preset: currentPreset)
        objectWillChange.send()
    }

    @MainActor
    public func prepareBackgroundSnapshot(theme: BackgroundTheme, dark: Bool) {
        let signature = staticBackgroundSignature(theme: theme, dark: dark)
        if backgroundSnapshotSignature == signature, backgroundSnapshot != nil { return }
        if isPreparingBackgroundSnapshot { return }

        isPreparingBackgroundSnapshot = true
        defer { isPreparingBackgroundSnapshot = false }

        let size = CGSize(
            width: CGFloat(map.cols) * OfficeConstants.tileSize,
            height: CGFloat(map.rows) * OfficeConstants.tileSize
        )
        let renderer = ImageRenderer(
            content: OfficeStaticBackgroundSnapshotView(
                map: map,
                dark: dark,
                theme: theme
            )
            .frame(width: size.width, height: size.height)
        )
        renderer.scale = 1
        backgroundSnapshot = renderer.cgImage
        backgroundSnapshotSignature = signature
    }

    @MainActor
    public func refreshChromeScreenshots(for tabs: [TerminalTab], activeTabId: String? = nil) async {
        let chromeTabs = tabs.filter {
            $0.enableChrome && ($0.isProcessing || $0.id == activeTabId)
        }
        if chromeTabs.isEmpty {
            if !chromeScreenshots.isEmpty {
                chromeScreenshots.removeAll()
            }
            return
        }

        let now = Date().timeIntervalSinceReferenceDate
        if now - lastChromeCaptureTime < 1.5 {
            return
        }
        lastChromeCaptureTime = now

        if let image = await TerminalTab.captureBrowserWindow() {
            for tab in chromeTabs {
                chromeScreenshots[tab.id] = image
            }
        }
    }

    public func suspend() {
        chromeScreenshots.removeAll()
        lastChromeCaptureTime = 0
        lastSyncSignature = nil
        invalidateBackgroundSnapshot()
    }

    private func updateCamera(activeTabId: String?, focusMode: Bool) {
        let worldCenter = CGPoint(
            x: CGFloat(map.cols) * OfficeConstants.tileSize / 2,
            y: CGFloat(map.rows) * OfficeConstants.tileSize / 2
        )

        var targetCenter = worldCenter
        var targetZoom: CGFloat = 1

        // 캐릭터 팔로우 모드 (grid/side 모두 동작)
        if let followId = followingCharacterId,
           let character = controller.characters[followId] {
            targetCenter = CGPoint(
                x: character.pixelX,
                y: max(OfficeConstants.tileSize * 2, character.pixelY - 18)
            )
            targetZoom = followZoomLevel
        } else if focusMode,
           let activeTabId,
           let character = controller.characters[activeTabId] {
            targetCenter = CGPoint(
                x: character.pixelX,
                y: max(OfficeConstants.tileSize * 2, character.pixelY - 22)
            )
            targetZoom = 1.65
        }

        let isFollowing = followingCharacterId != nil
        let blend: CGFloat = isFollowing ? 0.18 : (focusMode ? 0.16 : 0.12)
        cameraCenter = CGPoint(
            x: cameraCenter.x + (targetCenter.x - cameraCenter.x) * blend,
            y: cameraCenter.y + (targetCenter.y - cameraCenter.y) * blend
        )
        cameraZoom += (targetZoom - cameraZoom) * blend
    }

    private func syncCharactersIfNeeded(with tabs: [TerminalTab]) {
        let signature = syncSignature(for: tabs)
        guard signature != lastSyncSignature else { return }
        lastSyncSignature = signature
        controller.sync(with: tabs)

        // 팔로우 중인 캐릭터가 사라지면 해제
        if let followId = followingCharacterId,
           controller.characters[followId] == nil {
            followingCharacterId = nil
        }
    }

    private func syncSignature(for tabs: [TerminalTab]) -> Int {
        var hasher = Hasher()
        hasher.combine(tabs.count)
        for tab in tabs.sorted(by: { $0.id < $1.id }) {
            hasher.combine(tab.id)
            hasher.combine(tab.groupId ?? "")
            hasher.combine(tab.isProcessing)
            hasher.combine(tab.claudeActivity.rawValue)
            hasher.combine(tab.officeSeatLockReason ?? "")
            hasher.combine(tab.isCompleted)
        }
        let hiredRoster = CharacterRegistry.shared.hiredCharacters.sorted { $0.id < $1.id }
        hasher.combine(hiredRoster.count)
        for character in hiredRoster {
            hasher.combine(character.id)
            hasher.combine(character.isOnVacation)
            hasher.combine(character.jobRole.rawValue)
            hasher.combine(character.name)
        }
        return hasher.finalize()
    }

    private func invalidateBackgroundSnapshot() {
        backgroundSnapshot = nil
        backgroundSnapshotSignature = nil
        isPreparingBackgroundSnapshot = false
        OfficeSpriteRenderer.invalidateBackgroundCache()
    }

    private func staticBackgroundSignature(theme: BackgroundTheme, dark: Bool) -> Int {
        var hasher = Hasher()
        hasher.combine(theme.rawValue)
        hasher.combine(dark)
        hasher.combine(map.cols)
        hasher.combine(map.rows)

        for row in map.tiles {
            for tile in row {
                hasher.combine(tile.rawValue)
            }
        }

        for furniture in map.furniture where OfficeSpriteRenderer.usesStaticBackgroundCache(for: furniture.type) {
            hasher.combine(furniture.id)
            hasher.combine(furniture.type.rawValue)
            hasher.combine(furniture.position.col)
            hasher.combine(furniture.position.row)
            hasher.combine(furniture.mirrored)
        }

        return hasher.finalize()
    }
}

private struct OfficeStaticBackgroundSnapshotView: View {
    let map: OfficeMap
    let dark: Bool
    let theme: BackgroundTheme

    var body: some View {
        Canvas { context, _ in
            let renderer = OfficeSpriteRenderer(
                map: map,
                characters: [:],
                tabs: [],
                frame: 0,
                dark: dark,
                theme: theme,
                selectedTabId: nil,
                selectedFurnitureId: nil
            )
            renderer.renderStaticBackground(context: context, scale: 1, offsetX: 0, offsetY: 0)
        }
    }
}

public func resolvedOfficeSceneTheme(_ settings: AppSettings) -> BackgroundTheme {
    let selected = BackgroundTheme(rawValue: settings.backgroundTheme) ?? .auto
    guard selected == .auto else { return selected }

    let hour = Calendar.current.component(.hour, from: Date())
    switch hour {
    case 6..<11: return .sunny
    case 11..<17: return .clearSky
    case 17..<19: return .goldenHour
    case 19..<21: return .dusk
    default: return settings.isDarkMode ? .moonlit : .sunny
    }
}

extension BackgroundTheme {
    public var officeSceneBackdropKind: OfficeSceneBackdropKind {
        switch self {
        case .sunny, .clearSky: return .bright
        case .sunset, .goldenHour, .dusk, .autumn: return .sunset
        case .moonlit, .starryNight, .aurora, .milkyWay: return .night
        case .storm, .rain, .snow, .fog: return .weather
        case .cherryBlossom: return .blossom
        case .forest: return .forest
        case .neonCity: return .neon
        case .ocean: return .ocean
        case .desert: return .desert
        case .volcano: return .volcano
        case .auto: return .bright
        }
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - Office Overlay Data
// ═══════════════════════════════════════════════════════

public struct OfficeToolBadge {
    public let label: String
    public let tint: Color

    public init(label: String, tint: Color) {
        self.label = label
        self.tint = tint
    }
}

extension ClaudeActivity {
    public var officeDisplayLabel: String {
        switch self {
        case .idle: return "Idle"
        case .thinking: return "Thinking"
        case .reading: return "Reading"
        case .writing: return "Editing"
        case .searching: return "Searching"
        case .running: return "Running"
        case .done: return "Done"
        case .error: return "Error"
        }
    }
}

extension TerminalTab {
    public var officeLatestToolBadge: OfficeToolBadge? {
        if pendingApproval != nil {
            return OfficeToolBadge(label: "WAIT", tint: Theme.yellow)
        }
        if claudeActivity == .error {
            return OfficeToolBadge(label: "ERR", tint: Theme.red)
        }

        // 마지막 블록만 확인 (전체 역순 탐색 대신)
        if let last = blocks.last {
            switch last.blockType {
            case .toolUse(let name, _):
                return badge(forToolName: name)
            case .fileChange(_, let action):
                return OfficeToolBadge(label: action.uppercased(), tint: Theme.green)
            case .completion:
                return OfficeToolBadge(label: "DONE", tint: Theme.green)
            case .error:
                return OfficeToolBadge(label: "ERR", tint: Theme.red)
            default: break
            }
        }

        if isProcessing {
            return OfficeToolBadge(label: claudeActivity.officeDisplayLabel.uppercased(), tint: officeActivityTint)
        }
        return nil
    }

    public var officeActivityTint: Color {
        switch claudeActivity {
        case .thinking: return Theme.purple
        case .reading: return Theme.accent
        case .writing: return Theme.green
        case .searching: return Theme.cyan
        case .running: return Theme.orange
        case .done: return Theme.green
        case .error: return Theme.red
        case .idle: return Theme.textDim
        }
    }

    public var officeRecentFileNames: [String] {
        Array(fileChanges.suffix(3)).reversed().map(\.fileName)
    }

    public var officeLatestFileName: String? {
        fileChanges.last?.fileName
    }

    public var officeCompactTokenText: String {
        compactOfficeCount(tokensUsed)
    }

    public var officeSelectionSubtitle: String {
        if let pendingApproval {
            return pendingApproval.reason.isEmpty ? "Approval pending" : pendingApproval.reason
        }
        if let badge = officeLatestToolBadge {
            return badge.label
        }
        return claudeActivity.officeDisplayLabel
    }

    private func badge(forToolName name: String) -> OfficeToolBadge {
        switch name {
        case "Read":
            return OfficeToolBadge(label: "READ", tint: Theme.accent)
        case "Edit", "Write":
            return OfficeToolBadge(label: "EDIT", tint: Theme.green)
        case "Bash":
            return OfficeToolBadge(label: "BASH", tint: Theme.orange)
        case "Grep", "Glob":
            return OfficeToolBadge(label: "FIND", tint: Theme.cyan)
        case "LS":
            return OfficeToolBadge(label: "LIST", tint: Theme.cyan)
        case "Task":
            return OfficeToolBadge(label: "PAR", tint: Theme.purple)
        default:
            return OfficeToolBadge(label: name.uppercased().prefix(4).description, tint: officeActivityTint)
        }
    }
}

private func compactOfficeCount(_ value: Int) -> String {
    if value >= 1000 {
        return String(format: "%.1fk", Double(value) / 1000.0)
    }
    return "\(value)"
}
