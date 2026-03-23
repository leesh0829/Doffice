import SwiftUI

// ═══════════════════════════════════════════════════════
// MARK: - App Settings (전역 설정)
// ═══════════════════════════════════════════════════════

class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @AppStorage("isDarkMode") var isDarkMode: Bool = false {
        didSet { objectWillChange.send() }
    }
    @AppStorage("fontSizeScale") var fontSizeScale: Double = 1.2 {
        didSet { objectWillChange.send() }
    }

    // ── 배경 테마 ──
    @AppStorage("backgroundTheme") var backgroundTheme: String = "auto" {
        didSet { objectWillChange.send() }
    }

    // ── 휴게실 가구 설정 ──
    @AppStorage("breakRoomShowSofa") var breakRoomShowSofa: Bool = true {
        didSet { objectWillChange.send() }
    }
    @AppStorage("breakRoomShowCoffeeMachine") var breakRoomShowCoffeeMachine: Bool = true {
        didSet { objectWillChange.send() }
    }
    @AppStorage("breakRoomShowPlant") var breakRoomShowPlant: Bool = true {
        didSet { objectWillChange.send() }
    }
    @AppStorage("breakRoomShowSideTable") var breakRoomShowSideTable: Bool = true {
        didSet { objectWillChange.send() }
    }
    @AppStorage("breakRoomShowClock") var breakRoomShowClock: Bool = true {
        didSet { objectWillChange.send() }
    }
    @AppStorage("breakRoomShowPicture") var breakRoomShowPicture: Bool = true {
        didSet { objectWillChange.send() }
    }
    @AppStorage("breakRoomShowNeonSign") var breakRoomShowNeonSign: Bool = true {
        didSet { objectWillChange.send() }
    }
    @AppStorage("breakRoomShowRug") var breakRoomShowRug: Bool = true {
        didSet { objectWillChange.send() }
    }

    // ── 가구 위치 (JSON) ──
    @AppStorage("furniturePositionsJSON") var furniturePositionsJSON: String = "" {
        didSet { objectWillChange.send() }
    }

    // ── 앱/회사 이름 ──
    @AppStorage("appDisplayName") var appDisplayName: String = "My World" {
        didSet { objectWillChange.send() }
    }
    @AppStorage("companyName") var companyName: String = "" {
        didSet { objectWillChange.send() }
    }

    // ── 편집 모드 ──
    @Published var isEditMode: Bool = false

    var colorScheme: ColorScheme { isDarkMode ? .dark : .light }

    // ── 가구 위치 헬퍼 ──
    func furniturePosition(for id: String) -> CGPoint? {
        guard !furniturePositionsJSON.isEmpty,
              let data = furniturePositionsJSON.data(using: .utf8),
              let dict = try? JSONDecoder().decode([String: [Double]].self, from: data),
              let arr = dict[id], arr.count == 2 else { return nil }
        return CGPoint(x: arr[0], y: arr[1])
    }

    func setFurniturePosition(_ pos: CGPoint, for id: String) {
        var dict: [String: [Double]] = [:]
        if !furniturePositionsJSON.isEmpty,
           let data = furniturePositionsJSON.data(using: .utf8),
           let existing = try? JSONDecoder().decode([String: [Double]].self, from: data) {
            dict = existing
        }
        dict[id] = [Double(pos.x), Double(pos.y)]
        if let data = try? JSONEncoder().encode(dict), let json = String(data: data, encoding: .utf8) {
            furniturePositionsJSON = json
        }
    }

    func resetFurniturePositions() {
        furniturePositionsJSON = ""
        objectWillChange.send()
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - Background Theme
// ═══════════════════════════════════════════════════════

enum BackgroundTheme: String, CaseIterable, Identifiable {
    case auto, sunny, clearSky, sunset, goldenHour, dusk
    case moonlit, starryNight, aurora, milkyWay
    case storm, rain, snow, fog
    case cherryBlossom, autumn, forest
    case neonCity, ocean, desert, volcano

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .auto: return "자동"
        case .sunny: return "맑은 낮"
        case .clearSky: return "파란 하늘"
        case .sunset: return "노을"
        case .goldenHour: return "골든아워"
        case .dusk: return "황혼"
        case .moonlit: return "달빛"
        case .starryNight: return "별밤"
        case .aurora: return "오로라"
        case .milkyWay: return "은하수"
        case .storm: return "먹구름"
        case .rain: return "비"
        case .snow: return "눈"
        case .fog: return "안개"
        case .cherryBlossom: return "벚꽃"
        case .autumn: return "단풍"
        case .forest: return "숲"
        case .neonCity: return "네온시티"
        case .ocean: return "바다"
        case .desert: return "사막"
        case .volcano: return "화산"
        }
    }

    var icon: String {
        switch self {
        case .auto: return "sparkles"
        case .sunny: return "sun.max.fill"
        case .clearSky: return "cloud.sun.fill"
        case .sunset: return "sunset.fill"
        case .goldenHour: return "sun.haze.fill"
        case .dusk: return "sun.horizon.fill"
        case .moonlit: return "moon.fill"
        case .starryNight: return "star.fill"
        case .aurora: return "wand.and.stars"
        case .milkyWay: return "sparkles"
        case .storm: return "cloud.bolt.fill"
        case .rain: return "cloud.rain.fill"
        case .snow: return "cloud.snow.fill"
        case .fog: return "cloud.fog.fill"
        case .cherryBlossom: return "leaf.fill"
        case .autumn: return "leaf.fill"
        case .forest: return "tree.fill"
        case .neonCity: return "building.2.fill"
        case .ocean: return "water.waves"
        case .desert: return "sun.dust.fill"
        case .volcano: return "mountain.2.fill"
        }
    }

    var skyColors: (top: String, bottom: String) {
        switch self {
        case .auto: return ("0a0d18", "0a0d18")
        case .sunny: return ("4a90d9", "87ceeb")
        case .clearSky: return ("2070c0", "60b0e8")
        case .sunset: return ("1a1040", "e06030")
        case .goldenHour: return ("d08030", "f0c060")
        case .dusk: return ("1a1838", "4a3060")
        case .moonlit: return ("0a1020", "1a2040")
        case .starryNight: return ("050810", "0a1020")
        case .aurora: return ("051018", "0a2030")
        case .milkyWay: return ("030508", "0a0d18")
        case .storm: return ("1a1e28", "2a3040")
        case .rain: return ("2a3040", "3a4858")
        case .snow: return ("b0c0d0", "d0d8e0")
        case .fog: return ("8090a0", "a0a8b0")
        case .cherryBlossom: return ("e8b0c0", "f0d0d8")
        case .autumn: return ("c06030", "d09040")
        case .forest: return ("2a5030", "4a8050")
        case .neonCity: return ("0a0818", "1a1030")
        case .ocean: return ("1040a0", "2060c0")
        case .desert: return ("c09050", "e0c080")
        case .volcano: return ("200808", "401010")
        }
    }

    var floorColors: (base: String, dot: String) {
        switch self {
        case .snow: return ("e0e4e8", "c8ccd4")
        case .desert: return ("d0a860", "c09848")
        case .ocean: return ("1a3050", "1a2840")
        case .volcano: return ("2a1010", "3a1818")
        case .forest: return ("1a3020", "2a4030")
        case .neonCity: return ("0e0818", "1a1030")
        case .autumn: return ("6a4020", "5a3818")
        case .cherryBlossom: return ("d0c0c4", "c0b0b8")
        default: return ("", "")
        }
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - Furniture Item Model
// ═══════════════════════════════════════════════════════

struct FurnitureItem: Identifiable {
    let id: String
    let name: String
    let icon: String
    let defaultNormX: CGFloat  // 0-1 normalized within room
    let defaultNormY: CGFloat  // 0-1 normalized (0=top wall, 1=floor)
    let width: CGFloat
    let height: CGFloat
    let isWallItem: Bool       // constrained to upper wall zone

    static let all: [FurnitureItem] = [
        FurnitureItem(id: "sofa", name: "소파", icon: "sofa.fill", defaultNormX: 0.0, defaultNormY: 0.7, width: 49, height: 30, isWallItem: false),
        FurnitureItem(id: "sideTable", name: "사이드테이블", icon: "table.furniture.fill", defaultNormX: 0.45, defaultNormY: 0.75, width: 18, height: 14, isWallItem: false),
        FurnitureItem(id: "coffeeMachine", name: "커피머신", icon: "cup.and.saucer.fill", defaultNormX: 0.45, defaultNormY: 0.5, width: 16, height: 28, isWallItem: false),
        FurnitureItem(id: "plant", name: "화분", icon: "leaf.fill", defaultNormX: 0.7, defaultNormY: 0.65, width: 14, height: 28, isWallItem: false),
        FurnitureItem(id: "clock", name: "시계", icon: "clock.fill", defaultNormX: 0.15, defaultNormY: 0.1, width: 14, height: 14, isWallItem: true),
        FurnitureItem(id: "picture", name: "액자", icon: "photo.artframe", defaultNormX: 0.55, defaultNormY: 0.1, width: 20, height: 16, isWallItem: true),
        FurnitureItem(id: "neonSign", name: "네온간판", icon: "lightbulb.fill", defaultNormX: 0.1, defaultNormY: 0.25, width: 64, height: 16, isWallItem: true),
        FurnitureItem(id: "rug", name: "러그", icon: "rectangle.fill", defaultNormX: 0.0, defaultNormY: 0.95, width: 100, height: 14, isWallItem: false),
    ]
}

// ═══════════════════════════════════════════════════════
// MARK: - Theme (동적 테마)
// ═══════════════════════════════════════════════════════

enum Theme {
    private static var dark: Bool { AppSettings.shared.isDarkMode }
    private static var scale: CGFloat { CGFloat(AppSettings.shared.fontSizeScale) }

    // Backgrounds
    static var bg: Color { dark ? Color(hex: "0c0e14") : Color(hex: "f5f5f7") }
    static var bgCard: Color { dark ? Color(hex: "13161e") : .white }
    static var bgSurface: Color { dark ? Color(hex: "191d28") : Color(hex: "f0f0f2") }
    static var bgTerminal: Color { dark ? Color(hex: "0c0e14") : .white }
    static var bgInput: Color { dark ? Color(hex: "141822") : Color(hex: "fafafa") }
    static var bgHover: Color { dark ? Color(hex: "1c2030") : Color(hex: "e8e8ec") }
    static var bgSelected: Color { dark ? Color(hex: "1a2038") : Color(hex: "e3edf7") }

    // Borders
    static var border: Color { dark ? Color(hex: "252a36") : Color(hex: "d8dae0") }
    static var borderActive: Color { Color(hex: "4a90d9") }

    // Text
    static var textPrimary: Color { dark ? Color(hex: "e8ecf4") : Color(hex: "1a1a2e") }
    static var textSecondary: Color { dark ? Color(hex: "8892a4") : Color(hex: "5a5e6e") }
    static var textDim: Color { dark ? Color(hex: "4a5168") : Color(hex: "9a9eb0") }
    static var textTerminal: Color { dark ? Color(hex: "d0d8e8") : Color(hex: "2a2e3e") }

    // Accents
    static var accent: Color { dark ? Color(hex: "5b9cf6") : Color(hex: "3478f6") }
    static var green: Color { dark ? Color(hex: "56d97e") : Color(hex: "30a854") }
    static var red: Color { dark ? Color(hex: "f06e6e") : Color(hex: "e44040") }
    static var yellow: Color { dark ? Color(hex: "e8b84a") : Color(hex: "d49a00") }
    static var purple: Color { dark ? Color(hex: "b07ee8") : Color(hex: "8b5cf6") }
    static var orange: Color { dark ? Color(hex: "e89858") : Color(hex: "e07830") }
    static var cyan: Color { dark ? Color(hex: "4ec9b0") : Color(hex: "0ea5a5") }
    static var pink: Color { dark ? Color(hex: "e88aaf") : Color(hex: "e05090") }

    // Fonts (scaled)
    static var monoTiny: Font { .system(size: round(9 * scale), design: .monospaced) }
    static var monoSmall: Font { .system(size: round(10 * scale), design: .monospaced) }
    static var monoNormal: Font { .system(size: round(12 * scale), design: .monospaced) }
    static var monoBold: Font { .system(size: round(11 * scale), weight: .semibold, design: .monospaced) }
    static var pixel: Font { .system(size: round(8 * scale), weight: .bold, design: .monospaced) }

    // Scaled font helper
    static func mono(_ baseSize: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: round(baseSize * scale), weight: weight, design: .monospaced)
    }

    // Worker colors
    static var workerColors: [Color] {
        dark ? [
            Color(hex: "f08080"), Color(hex: "72d6a0"), Color(hex: "f0c05a"),
            Color(hex: "78b4f0"), Color(hex: "c490e8"), Color(hex: "f0a060"),
            Color(hex: "60d0c0"), Color(hex: "f080c0")
        ] : [
            Color(hex: "e05555"), Color(hex: "30a854"), Color(hex: "d49a00"),
            Color(hex: "3478f6"), Color(hex: "8b5cf6"), Color(hex: "e07830"),
            Color(hex: "0ea5a5"), Color(hex: "e05090")
        ]
    }

    // Gradients
    static var bgGradient: LinearGradient {
        dark ? LinearGradient(colors: [Color(hex: "0c0e14"), Color(hex: "101420")], startPoint: .top, endPoint: .bottom)
             : LinearGradient(colors: [Color(hex: "f5f5f7"), Color(hex: "eeeef2")], startPoint: .top, endPoint: .bottom)
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - Settings View
// ═══════════════════════════════════════════════════════

struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    @Environment(\.dismiss) var dismiss

    @ObservedObject private var tokenTracker = TokenTracker.shared
    @State private var editingAppName: String = ""
    @State private var editingCompanyName: String = ""

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Image(systemName: "gearshape.fill").font(.system(size: 14)).foregroundColor(Theme.accent)
                Text("Settings").font(Theme.mono(14, weight: .bold)).foregroundColor(Theme.textPrimary)
                Spacer()
            }

            // Profile
            VStack(alignment: .leading, spacing: 10) {
                Text("PROFILE").font(Theme.pixel).foregroundColor(Theme.textDim).tracking(1.5)

                VStack(spacing: 8) {
                    HStack(spacing: 10) {
                        Text("이름").font(Theme.mono(10, weight: .medium)).foregroundColor(Theme.textSecondary).frame(width: 50, alignment: .trailing)
                        TextField("앱 이름", text: $editingAppName)
                            .textFieldStyle(.plain).font(Theme.mono(11, weight: .semibold))
                            .foregroundColor(Theme.textPrimary)
                            .padding(.horizontal, 8).padding(.vertical, 5)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Theme.bgSurface)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.border.opacity(0.5), lineWidth: 1)))
                            .onSubmit { settings.appDisplayName = editingAppName }
                            .onChange(of: editingAppName) { settings.appDisplayName = $0 }
                    }
                    HStack(spacing: 10) {
                        Text("회사").font(Theme.mono(10, weight: .medium)).foregroundColor(Theme.textSecondary).frame(width: 50, alignment: .trailing)
                        TextField("회사 이름 (선택)", text: $editingCompanyName)
                            .textFieldStyle(.plain).font(Theme.mono(11))
                            .foregroundColor(Theme.textPrimary)
                            .padding(.horizontal, 8).padding(.vertical, 5)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Theme.bgSurface)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.border.opacity(0.5), lineWidth: 1)))
                            .onSubmit { settings.companyName = editingCompanyName }
                            .onChange(of: editingCompanyName) { settings.companyName = $0 }
                    }
                }
            }

            // Theme
            VStack(alignment: .leading, spacing: 10) {
                Text("THEME").font(Theme.pixel).foregroundColor(Theme.textDim).tracking(1.5)

                HStack(spacing: 8) {
                    themeButton(title: "Light", icon: "sun.max.fill", isDark: false)
                    themeButton(title: "Dark", icon: "moon.fill", isDark: true)
                }
            }

            // Font Size
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("FONT SIZE").font(Theme.pixel).foregroundColor(Theme.textDim).tracking(1.5)
                    Spacer()
                    Text(fontSizeLabel).font(Theme.mono(10, weight: .semibold)).foregroundColor(Theme.accent)
                }

                HStack(spacing: 6) {
                    ForEach(fontSizeOptions, id: \.value) { opt in
                        Button(action: { withAnimation(.easeInOut(duration: 0.15)) { settings.fontSizeScale = opt.value } }) {
                            VStack(spacing: 4) {
                                Text("Aa")
                                    .font(.system(size: CGFloat(10 * opt.value), weight: .medium, design: .monospaced))
                                    .foregroundColor(isSelectedSize(opt.value) ? Theme.accent : Theme.textSecondary)
                                Text(opt.label)
                                    .font(.system(size: 8, design: .monospaced))
                                    .foregroundColor(isSelectedSize(opt.value) ? Theme.accent : Theme.textDim)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(RoundedRectangle(cornerRadius: 6)
                                .fill(isSelectedSize(opt.value) ? Theme.accent.opacity(0.1) : Theme.bgSurface)
                                .overlay(RoundedRectangle(cornerRadius: 6)
                                    .stroke(isSelectedSize(opt.value) ? Theme.accent.opacity(0.4) : Theme.border.opacity(0.5), lineWidth: 1)))
                        }.buttonStyle(.plain)
                    }
                }

                // Preview
                VStack(alignment: .leading, spacing: 4) {
                    Text("미리보기").font(.system(size: round(8 * CGFloat(settings.fontSizeScale)), weight: .bold, design: .monospaced))
                        .foregroundColor(Theme.textDim)
                    HStack(spacing: 6) {
                        Circle().fill(Theme.green).frame(width: 6, height: 6)
                        Text("Read").font(Theme.mono(10, weight: .bold)).foregroundColor(Theme.accent)
                        Text("(Models.swift)").font(Theme.mono(10)).foregroundColor(Theme.textSecondary)
                    }
                    .padding(.vertical, 4).padding(.horizontal, 6)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Theme.accent.opacity(0.06)))

                    Text("일반 텍스트가 이렇게 보입니다.").font(Theme.monoNormal).foregroundColor(Theme.textPrimary)
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 8).fill(Theme.bgTerminal)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border, lineWidth: 0.5)))
            }

            // Token Limits
            VStack(alignment: .leading, spacing: 10) {
                Text("TOKEN LIMITS").font(Theme.pixel).foregroundColor(Theme.textDim).tracking(1.5)

                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("일간 한도").font(Theme.mono(9, weight: .medium)).foregroundColor(Theme.textSecondary)
                        HStack(spacing: 4) {
                            TextField("", value: $tokenTracker.dailyTokenLimit, format: .number)
                                .textFieldStyle(.plain).font(Theme.mono(11, weight: .semibold))
                                .foregroundColor(Theme.textPrimary)
                                .padding(.horizontal, 8).padding(.vertical, 5)
                                .background(RoundedRectangle(cornerRadius: 6).fill(Theme.bgSurface)
                                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.border.opacity(0.5), lineWidth: 1)))
                                .frame(width: 100)
                            Text("tokens").font(Theme.mono(8)).foregroundColor(Theme.textDim)
                        }
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("주간 한도").font(Theme.mono(9, weight: .medium)).foregroundColor(Theme.textSecondary)
                        HStack(spacing: 4) {
                            TextField("", value: $tokenTracker.weeklyTokenLimit, format: .number)
                                .textFieldStyle(.plain).font(Theme.mono(11, weight: .semibold))
                                .foregroundColor(Theme.textPrimary)
                                .padding(.horizontal, 8).padding(.vertical, 5)
                                .background(RoundedRectangle(cornerRadius: 6).fill(Theme.bgSurface)
                                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.border.opacity(0.5), lineWidth: 1)))
                                .frame(width: 100)
                            Text("tokens").font(Theme.mono(8)).foregroundColor(Theme.textDim)
                        }
                    }
                }
            }

            // Secret Key
            VStack(alignment: .leading, spacing: 10) {
                Text("SECRET KEY").font(Theme.pixel).foregroundColor(Theme.textDim).tracking(1.5)
                HStack(spacing: 8) {
                    SecureField("시크릿 키 입력", text: $secretKeyInput)
                        .textFieldStyle(.plain).font(Theme.mono(11))
                        .foregroundColor(Theme.textPrimary)
                        .padding(.horizontal, 8).padding(.vertical, 5)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Theme.bgSurface)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.border.opacity(0.5), lineWidth: 1)))
                        .onSubmit { applySecretKey() }
                    Button(action: { applySecretKey() }) {
                        Text("적용").font(Theme.mono(10, weight: .bold)).foregroundColor(.white)
                            .padding(.horizontal, 12).padding(.vertical, 5)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Theme.accent))
                    }.buttonStyle(.plain)
                }
                if secretKeyResult == .success {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill").font(.system(size: 10)).foregroundColor(Theme.green)
                        Text("전체 캐릭터가 해금되었습니다!").font(Theme.mono(9, weight: .medium)).foregroundColor(Theme.green)
                    }
                } else if secretKeyResult == .wrong {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark.circle.fill").font(.system(size: 10)).foregroundColor(Theme.red)
                        Text("올바르지 않은 키입니다.").font(Theme.mono(9, weight: .medium)).foregroundColor(Theme.red)
                    }
                }
            }

            Spacer(minLength: 0)

            // Close
            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.return)
                    .keyboardShortcut(.escape)
            }
        }
        .padding(24)
        .frame(width: 420, height: 680)
        .background(Theme.bgCard)
        .onAppear {
            editingAppName = settings.appDisplayName
            editingCompanyName = settings.companyName
        }
    }

    private func themeButton(title: String, icon: String, isDark: Bool) -> some View {
        let selected = settings.isDarkMode == isDark
        return Button(action: { withAnimation(.easeInOut(duration: 0.2)) { settings.isDarkMode = isDark } }) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(selected ? (isDark ? Theme.yellow : Theme.orange) : Theme.textDim)
                Text(title)
                    .font(Theme.mono(11, weight: selected ? .bold : .regular))
                    .foregroundColor(selected ? Theme.textPrimary : Theme.textSecondary)
                Spacer()
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12)).foregroundColor(Theme.accent)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 8)
                .fill(selected ? Theme.bgSelected : Theme.bgSurface)
                .overlay(RoundedRectangle(cornerRadius: 8)
                    .stroke(selected ? Theme.accent.opacity(0.3) : Theme.border.opacity(0.5), lineWidth: 1)))
        }.buttonStyle(.plain)
    }

    struct FontSizeOption {
        let value: Double
        let label: String
    }

    private var fontSizeOptions: [FontSizeOption] {
        [
            FontSizeOption(value: 0.85, label: "S"),
            FontSizeOption(value: 1.0, label: "M"),
            FontSizeOption(value: 1.2, label: "L"),
            FontSizeOption(value: 1.4, label: "XL"),
            FontSizeOption(value: 1.7, label: "XXL"),
        ]
    }

    private func isSelectedSize(_ v: Double) -> Bool {
        abs(settings.fontSizeScale - v) < 0.05
    }

    private var fontSizeLabel: String {
        fontSizeOptions.first(where: { isSelectedSize($0.value) })?.label ?? "\(Int(settings.fontSizeScale * 100))%"
    }

    // ── Secret Key ──
    @State private var secretKeyInput = ""
    @State private var secretKeyResult: SecretKeyResult = .none
    enum SecretKeyResult { case none, success, wrong }

    private static let validKeys: Set<String> = [
        "I don't like Snatch",
        "I don't like snatch",
        "i don't like snatch",
    ]

    private func applySecretKey() {
        let key = secretKeyInput.trimmingCharacters(in: .whitespaces)
        if Self.validKeys.contains(key) {
            CharacterRegistry.shared.hireAll()
            withAnimation(.easeInOut(duration: 0.3)) { secretKeyResult = .success }
            secretKeyInput = ""
        } else {
            withAnimation(.easeInOut(duration: 0.3)) { secretKeyResult = .wrong }
        }
        // 3초 후 결과 메시지 숨기기
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation { secretKeyResult = .none }
        }
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - Accessory View (휴게실 배치 & 가구 설정)
// ═══════════════════════════════════════════════════════

struct AccessoryView: View {
    @ObservedObject var settings = AppSettings.shared
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("🛋️").font(.system(size: 16))
                Text("악세서리").font(Theme.mono(14, weight: .bold)).foregroundColor(Theme.textPrimary)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 16)).foregroundColor(Theme.textDim)
                }.buttonStyle(.plain)
            }.padding(.bottom, 16)

            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 20) {
                    // ── 배경 테마 ──
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("배경 테마").font(Theme.pixel).foregroundColor(Theme.textDim).tracking(1.5)
                            Spacer()
                            Text(currentTheme.displayName).font(Theme.mono(9, weight: .bold)).foregroundColor(Theme.purple)
                        }

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
                            ForEach(BackgroundTheme.allCases) { theme in
                                bgThemeButton(theme)
                            }
                        }
                    }

                    // ── 가구 설정 ──
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("가구 설정").font(Theme.pixel).foregroundColor(Theme.textDim).tracking(1.5)
                            Spacer()
                            Text("\(furnitureOnCount)/8").font(Theme.mono(9, weight: .bold)).foregroundColor(Theme.purple)
                        }

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            furnitureToggle("소파", icon: "sofa.fill", isOn: $settings.breakRoomShowSofa)
                            furnitureToggle("커피머신", icon: "cup.and.saucer.fill", isOn: $settings.breakRoomShowCoffeeMachine)
                            furnitureToggle("화분", icon: "leaf.fill", isOn: $settings.breakRoomShowPlant)
                            furnitureToggle("사이드테이블", icon: "table.furniture.fill", isOn: $settings.breakRoomShowSideTable)
                            furnitureToggle("시계", icon: "clock.fill", isOn: $settings.breakRoomShowClock)
                            furnitureToggle("액자", icon: "photo.artframe", isOn: $settings.breakRoomShowPicture)
                            furnitureToggle("네온간판", icon: "lightbulb.fill", isOn: $settings.breakRoomShowNeonSign)
                            furnitureToggle("러그", icon: "rectangle.fill", isOn: $settings.breakRoomShowRug)
                        }
                    }

                    // ── 가구 배치 ──
                    VStack(alignment: .leading, spacing: 10) {
                        Text("가구 배치").font(Theme.pixel).foregroundColor(Theme.textDim).tracking(1.5)

                        Button(action: { settings.isEditMode = true; dismiss() }) {
                            HStack(spacing: 8) {
                                Image(systemName: "hand.draw.fill").font(.system(size: 12)).foregroundColor(.white)
                                Text("드래그로 가구 배치하기").font(Theme.mono(11, weight: .bold)).foregroundColor(.white)
                                Spacer()
                                Image(systemName: "arrow.right.circle.fill").font(.system(size: 14)).foregroundColor(.white.opacity(0.7))
                            }
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 10).fill(
                                LinearGradient(colors: [Theme.purple, Theme.accent], startPoint: .leading, endPoint: .trailing)))
                        }.buttonStyle(.plain)

                        Button(action: { settings.resetFurniturePositions() }) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.counterclockwise").font(.system(size: 10)).foregroundColor(Theme.textDim)
                                Text("기본 배치로 초기화").font(Theme.mono(10)).foregroundColor(Theme.textSecondary)
                            }
                            .padding(.vertical, 8).padding(.horizontal, 12)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Theme.bgSurface)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border.opacity(0.3), lineWidth: 0.5)))
                        }.buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(24)
        .background(Theme.bgCard)
    }

    private var currentTheme: BackgroundTheme {
        BackgroundTheme(rawValue: settings.backgroundTheme) ?? .auto
    }

    private var furnitureOnCount: Int {
        [settings.breakRoomShowSofa, settings.breakRoomShowCoffeeMachine,
         settings.breakRoomShowPlant, settings.breakRoomShowSideTable,
         settings.breakRoomShowClock, settings.breakRoomShowPicture,
         settings.breakRoomShowNeonSign, settings.breakRoomShowRug].filter { $0 }.count
    }

    private func bgThemeButton(_ theme: BackgroundTheme) -> some View {
        let selected = settings.backgroundTheme == theme.rawValue
        return Button(action: { withAnimation(.easeInOut(duration: 0.15)) { settings.backgroundTheme = theme.rawValue } }) {
            VStack(spacing: 4) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(LinearGradient(
                            colors: [Color(hex: theme.skyColors.top), Color(hex: theme.skyColors.bottom)],
                            startPoint: .top, endPoint: .bottom))
                        .frame(height: 28)
                    Image(systemName: theme.icon)
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.9))
                }
                Text(theme.displayName)
                    .font(.system(size: 7, weight: selected ? .bold : .medium, design: .monospaced))
                    .foregroundColor(selected ? Theme.purple : Theme.textDim)
                    .lineLimit(1)
            }
            .padding(4)
            .background(RoundedRectangle(cornerRadius: 8)
                .fill(selected ? Theme.purple.opacity(0.1) : .clear)
                .overlay(RoundedRectangle(cornerRadius: 8)
                    .stroke(selected ? Theme.purple.opacity(0.5) : Theme.border.opacity(0.2), lineWidth: selected ? 1.5 : 0.5)))
        }.buttonStyle(.plain)
    }

    private func furnitureToggle(_ label: String, icon: String, isOn: Binding<Bool>) -> some View {
        Button(action: { withAnimation(.easeInOut(duration: 0.15)) { isOn.wrappedValue.toggle() } }) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundColor(isOn.wrappedValue ? Theme.purple : Theme.textDim)
                Text(label)
                    .font(Theme.mono(10, weight: .medium))
                    .foregroundColor(isOn.wrappedValue ? Theme.textPrimary : Theme.textDim)
                Spacer()
                Image(systemName: isOn.wrappedValue ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 12))
                    .foregroundColor(isOn.wrappedValue ? Theme.green : Theme.textDim.opacity(0.5))
            }
            .padding(.horizontal, 10).padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 8)
                .fill(isOn.wrappedValue ? Theme.purple.opacity(0.08) : Theme.bgSurface)
                .overlay(RoundedRectangle(cornerRadius: 8)
                    .stroke(isOn.wrappedValue ? Theme.purple.opacity(0.3) : Theme.border.opacity(0.3), lineWidth: 0.5)))
        }.buttonStyle(.plain)
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - Color hex init
// ═══════════════════════════════════════════════════════

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6: (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default: (r, g, b) = (0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
    }
}
