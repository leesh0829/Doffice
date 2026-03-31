import SwiftUI

// ═══════════════════════════════════════════════════════
// MARK: - Theme (동적 테마 — Foundation 위임)
// ═══════════════════════════════════════════════════════
//
// 모든 기존 call-site와 100% 호환.
// 내부적으로 ColorTokens / Typography / DSSpacing 에 위임.

public enum Theme {
    // ── Cache ──
    private static var _cachedDark: Bool = false
    private static var _cachedIsCustom: Bool = false
    private static var _cachedCustomConfig: CustomThemeConfig?
    private static var _cacheValid: Bool = false

    private static var _lastDarkValue: Bool = false
    private static var _lastThemeMode: String = ""

    /// 설정 변경 시 캐시 무효화 (NotificationCenter 기반)
    private static let _observer: Void = {
        NotificationCenter.default.addObserver(
            forName: .dofficeRefresh, object: nil, queue: .main
        ) { _ in
            _cacheValid = false
            Typography.invalidateCache()
        }
    }()

    private static func ensureCache() {
        _ = _observer  // lazy init observer
        guard !_cacheValid else { return }
        let settings = AppSettings.shared
        let newDark = settings.isDarkMode
        let newThemeMode = settings.themeMode
        let themeChanged = newDark != _lastDarkValue || newThemeMode != _lastThemeMode
        _cachedDark = newDark
        _cachedIsCustom = newThemeMode == "custom"
        _cachedCustomConfig = _cachedIsCustom ? settings.customTheme : nil
        _lastDarkValue = newDark
        _lastThemeMode = newThemeMode
        if themeChanged { Typography.invalidateCache() }
        _cacheValid = true
    }

    private static var dark: Bool { ensureCache(); return _cachedDark }
    public static var isCustomMode: Bool { ensureCache(); return _cachedIsCustom }
    private static var cachedCustomConfig: CustomThemeConfig? { ensureCache(); return _cachedCustomConfig }

    private static var scale: CGFloat { CGFloat(AppSettings.shared.fontSizeScale) }
    /// UI 크롬(툴바, 사이드바, 필터 등)용 완화된 스케일 — 콘텐츠보다 덜 커짐
    private static var chromeScale: CGFloat { 1 + (scale - 1) * 0.5 }

    /// Clear font cache (call when font settings change)
    public static func invalidateFontCache() {
        Typography.invalidateCache()
        _cacheValid = false
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // 1. COLOR TOKENS (delegate to ColorTokens)
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    // ── Background Surfaces (4-layer depth system) ──
    public static var bg: Color { ColorTokens.bg(dark: dark, custom: cachedCustomConfig) }
    public static var bgCard: Color { ColorTokens.bgCard(dark: dark, custom: cachedCustomConfig) }
    public static var bgSurface: Color { ColorTokens.bgSurface(dark: dark, custom: cachedCustomConfig) }
    public static var bgTertiary: Color { ColorTokens.bgTertiary(dark: dark, custom: cachedCustomConfig) }

    // ── Functional backgrounds ──
    public static var bgTerminal: Color { ColorTokens.bgTerminal(dark: dark, custom: cachedCustomConfig) }
    public static var bgInput: Color { ColorTokens.bgInput(dark: dark) }
    public static var bgHover: Color { ColorTokens.bgHover(dark: dark) }
    public static var bgSelected: Color { ColorTokens.bgSelected(dark: dark) }
    public static var bgPressed: Color { ColorTokens.bgPressed(dark: dark) }
    public static var bgDisabled: Color { ColorTokens.bgDisabled(dark: dark) }
    public static var bgOverlay: Color { ColorTokens.bgOverlay(dark: dark) }

    // ── Borders ──
    public static var border: Color { ColorTokens.border(dark: dark, custom: cachedCustomConfig) }
    public static var borderStrong: Color { ColorTokens.borderStrong(dark: dark, custom: cachedCustomConfig) }
    public static var borderActive: Color { ColorTokens.borderActive(dark: dark) }
    public static var borderSubtle: Color { ColorTokens.borderSubtle(dark: dark) }
    public static var focusRing: Color { ColorTokens.focusRing }

    // ── Text (5-step hierarchy) ──
    public static var textPrimary: Color { ColorTokens.textPrimary(dark: dark, custom: cachedCustomConfig) }
    public static var textSecondary: Color { ColorTokens.textSecondary(dark: dark, custom: cachedCustomConfig) }
    public static var textDim: Color { ColorTokens.textDim(dark: dark, custom: cachedCustomConfig) }
    public static var textMuted: Color { ColorTokens.textMuted(dark: dark, custom: cachedCustomConfig) }
    public static var textTerminal: Color { ColorTokens.textTerminal(dark: dark) }

    // ── System ──
    public static var textOnAccent: Color { ColorTokens.textOnAccent(dark: dark, custom: cachedCustomConfig) }
    public static var overlay: Color { ColorTokens.overlay(dark: dark) }
    public static var overlayBg: Color { ColorTokens.overlayBg(dark: dark) }

    // ── Semantic Accents ──
    public static var accent: Color { ColorTokens.accent(dark: dark, custom: cachedCustomConfig) }
    public static var green: Color { ColorTokens.green(dark: dark, custom: cachedCustomConfig) }
    public static var red: Color { ColorTokens.red(dark: dark, custom: cachedCustomConfig) }
    public static var yellow: Color { ColorTokens.yellow(dark: dark, custom: cachedCustomConfig) }
    public static var purple: Color { ColorTokens.purple(dark: dark, custom: cachedCustomConfig) }
    public static var orange: Color { ColorTokens.orange(dark: dark, custom: cachedCustomConfig) }
    public static var cyan: Color { ColorTokens.cyan(dark: dark, custom: cachedCustomConfig) }
    public static var pink: Color { ColorTokens.pink(dark: dark, custom: cachedCustomConfig) }

    // ── Semantic accent backgrounds ──
    public static func accentBg(_ color: Color) -> Color { ColorTokens.accentBg(color, dark: dark) }
    public static func accentBorder(_ color: Color) -> Color { ColorTokens.accentBorder(color, dark: dark) }

    /// 그라데이션 또는 단색 accent 배경 (AnyShapeStyle) — Custom 모드에서만 그라데이션 적용
    public static var accentBackground: AnyShapeStyle {
        if let config = cachedCustomConfig {
            if config.useGradient,
               let startHex = config.gradientStartHex, !startHex.isEmpty,
               let endHex = config.gradientEndHex, !endHex.isEmpty {
                return AnyShapeStyle(
                    LinearGradient(
                        colors: [Color(hex: startHex), Color(hex: endHex)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
            }
        }
        return AnyShapeStyle(accent)
    }

    /// 소프트 그라데이션 배경 (낮은 opacity) — 비 prominent accent 버튼 등에 사용
    public static var accentSoftBackground: AnyShapeStyle {
        if let config = cachedCustomConfig {
            if config.useGradient,
               let startHex = config.gradientStartHex, !startHex.isEmpty,
               let endHex = config.gradientEndHex, !endHex.isEmpty {
                let opacity = dark ? 0.14 : 0.10
                return AnyShapeStyle(
                    LinearGradient(
                        colors: [Color(hex: startHex).opacity(opacity), Color(hex: endHex).opacity(opacity)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
            }
        }
        return AnyShapeStyle(accentBg(accent))
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // 2. TYPOGRAPHY SYSTEM (delegate to Typography)
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    // Pre-scaled convenience fonts
    public static var monoTiny: Font { Typography.monoTiny(scale: scale) }
    public static var monoSmall: Font { Typography.monoSmall(scale: scale) }
    public static var monoNormal: Font { Typography.monoNormal(scale: scale) }
    public static var monoBold: Font { Typography.monoBold(scale: scale) }
    public static var pixel: Font { Typography.pixel(chromeScale: chromeScale) }

    /// 커스텀 테마에서 fontSize가 설정되어 있으면 해당 스케일 사용
    private static var customScale: CGFloat? {
        guard let config = cachedCustomConfig, let fs = config.fontSize, fs > 0 else { return nil }
        return CGFloat(fs / 11.0)
    }

    /// Primary UI text (Geist Sans equivalent — system san-serif)
    public static func mono(_ baseSize: CGFloat, weight: Font.Weight = .regular) -> Font {
        let effectiveScale = customScale ?? scale
        let fontName = cachedCustomConfig?.fontName
        return Typography.mono(baseSize, weight: weight, scale: effectiveScale, customFont: fontName)
    }

    /// Code, terminal, git hashes, file paths — 커스텀 폰트 미적용 (항상 monospaced)
    public static func code(_ baseSize: CGFloat, weight: Font.Weight = .regular) -> Font {
        Typography.code(baseSize, weight: weight, scale: scale)
    }

    /// General scaled font
    public static func scaled(_ baseSize: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> Font {
        let effectiveScale = customScale ?? scale
        let fontName = cachedCustomConfig?.fontName
        return Typography.scaled(baseSize, weight: weight, design: design, scale: effectiveScale, customFont: fontName)
    }

    /// Chrome-only font (sidebar, toolbar — less aggressive scaling)
    public static func chrome(_ baseSize: CGFloat, weight: Font.Weight = .regular) -> Font {
        let effectiveChromeScale: CGFloat = {
            if let cs = customScale { return 1 + (cs - 1) * 0.5 }
            return chromeScale
        }()
        let fontName = cachedCustomConfig?.fontName
        return Typography.chrome(baseSize, weight: weight, chromeScale: effectiveChromeScale, customFont: fontName)
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // 3. SPACING & SIZING (delegate to DSSpacing)
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    public static let sp1: CGFloat = DSSpacing.sp1
    public static let sp2: CGFloat = DSSpacing.sp2
    public static let sp3: CGFloat = DSSpacing.sp3
    public static let sp4: CGFloat = DSSpacing.sp4
    public static let sp5: CGFloat = DSSpacing.sp5
    public static let sp6: CGFloat = DSSpacing.sp6
    public static let sp8: CGFloat = DSSpacing.sp8

    // Row heights
    public static let rowCompact: CGFloat = DSSpacing.rowCompact
    public static let rowDefault: CGFloat = DSSpacing.rowDefault
    public static let rowComfortable: CGFloat = DSSpacing.rowComfortable

    // Panel padding
    public static let panelPadding: CGFloat = DSSpacing.panelPadding
    public static let cardPadding: CGFloat = DSSpacing.cardPadding
    public static let toolbarHeight: CGFloat = DSSpacing.toolbarHeight
    public static let sidebarItemHeight: CGFloat = DSSpacing.sidebarItemHeight

    // Icon sizes
    public static func iconSize(_ baseSize: CGFloat) -> CGFloat { round(baseSize * scale) }
    public static func chromeIconSize(_ baseSize: CGFloat) -> CGFloat { round(baseSize * chromeScale) }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // 4. RADIUS / BORDER / SURFACE (delegate to DSCorners / DSBorder)
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    public static let cornerSmall: CGFloat = DSCorners.small
    public static let cornerMedium: CGFloat = DSCorners.medium
    public static let cornerLarge: CGFloat = DSCorners.large
    public static let cornerXL: CGFloat = DSCorners.xl

    // Border defaults (for modifier compatibility)
    public static let borderDefault: CGFloat = DSBorder.width
    public static let borderActiveOpacity: CGFloat = DSBorder.activeOpacity
    public static let borderLight: CGFloat = DSBorder.lightOpacity

    // Interaction state opacities
    public static let hoverOpacity: CGFloat = DSBorder.hoverOpacity
    public static let activeOpacity: CGFloat = DSBorder.pressedOpacity
    public static let strokeActiveOpacity: CGFloat = DSBorder.strokeActiveOpacity
    public static let strokeInactiveOpacity: CGFloat = DSBorder.strokeInactiveOpacity

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // 5. PRESERVED TOKENS (pixel world)
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    public static var workerColors: [Color] { ColorTokens.workerColors(dark: dark) }

    public static var bgGradient: LinearGradient {
        dark ? LinearGradient(colors: [Color(hex: "000000"), Color(hex: "0a0a0a")], startPoint: .top, endPoint: .bottom)
             : LinearGradient(colors: [Color(hex: "ffffff"), Color(hex: "fafafa")], startPoint: .top, endPoint: .bottom)
    }
}

public enum AppChromeTone: Equatable {
    case neutral
    case accent
    case green
    case red
    case yellow
    case purple
    case cyan
    case orange

    public var color: Color {
        switch self {
        case .neutral: return Theme.textSecondary
        case .accent: return Theme.accent
        case .green: return Theme.green
        case .red: return Theme.red
        case .yellow: return Theme.yellow
        case .purple: return Theme.purple
        case .cyan: return Theme.cyan
        case .orange: return Theme.orange
        }
    }
}
