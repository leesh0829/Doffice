import XCTest
@testable import DesignSystem

final class ThemeIntegrationTests: XCTestCase {

    // MARK: - Spacing Delegation

    func testThemeSpacingMatchesFoundation() {
        XCTAssertEqual(Theme.sp1, DSSpacing.sp1)
        XCTAssertEqual(Theme.sp2, DSSpacing.sp2)
        XCTAssertEqual(Theme.sp3, DSSpacing.sp3)
        XCTAssertEqual(Theme.sp4, DSSpacing.sp4)
        XCTAssertEqual(Theme.sp5, DSSpacing.sp5)
        XCTAssertEqual(Theme.sp6, DSSpacing.sp6)
        XCTAssertEqual(Theme.sp8, DSSpacing.sp8)
    }

    func testThemeRowHeightsMatchFoundation() {
        XCTAssertEqual(Theme.rowCompact, DSSpacing.rowCompact)
        XCTAssertEqual(Theme.rowDefault, DSSpacing.rowDefault)
        XCTAssertEqual(Theme.rowComfortable, DSSpacing.rowComfortable)
    }

    func testThemePanelSizesMatchFoundation() {
        XCTAssertEqual(Theme.panelPadding, DSSpacing.panelPadding)
        XCTAssertEqual(Theme.cardPadding, DSSpacing.cardPadding)
        XCTAssertEqual(Theme.toolbarHeight, DSSpacing.toolbarHeight)
        XCTAssertEqual(Theme.sidebarItemHeight, DSSpacing.sidebarItemHeight)
    }

    // MARK: - Corners Delegation

    func testThemeCornersMatchFoundation() {
        XCTAssertEqual(Theme.cornerSmall, DSCorners.small)
        XCTAssertEqual(Theme.cornerMedium, DSCorners.medium)
        XCTAssertEqual(Theme.cornerLarge, DSCorners.large)
        XCTAssertEqual(Theme.cornerXL, DSCorners.xl)
    }

    // MARK: - Border Delegation

    func testThemeBorderMatchesFoundation() {
        XCTAssertEqual(Theme.borderDefault, DSBorder.width)
        XCTAssertEqual(Theme.hoverOpacity, DSBorder.hoverOpacity)
        XCTAssertEqual(Theme.activeOpacity, DSBorder.pressedOpacity)
        XCTAssertEqual(Theme.strokeActiveOpacity, DSBorder.strokeActiveOpacity)
        XCTAssertEqual(Theme.strokeInactiveOpacity, DSBorder.strokeInactiveOpacity)
        XCTAssertEqual(Theme.borderActiveOpacity, DSBorder.activeOpacity)
        XCTAssertEqual(Theme.borderLight, DSBorder.lightOpacity)
    }

    // MARK: - Color Access (smoke tests)

    func testThemeColorAccessDoesNotCrash() {
        // Access all color properties -- should not crash
        _ = Theme.bg
        _ = Theme.bgCard
        _ = Theme.bgSurface
        _ = Theme.bgTertiary
        _ = Theme.bgTerminal
        _ = Theme.bgInput
        _ = Theme.bgHover
        _ = Theme.bgSelected
        _ = Theme.bgPressed
        _ = Theme.bgDisabled
        _ = Theme.bgOverlay
        _ = Theme.border
        _ = Theme.borderStrong
        _ = Theme.borderActive
        _ = Theme.borderSubtle
        _ = Theme.focusRing
        _ = Theme.textPrimary
        _ = Theme.textSecondary
        _ = Theme.textDim
        _ = Theme.textMuted
        _ = Theme.textTerminal
        _ = Theme.textOnAccent
        _ = Theme.accent
        _ = Theme.green
        _ = Theme.red
        _ = Theme.yellow
        _ = Theme.purple
        _ = Theme.orange
        _ = Theme.cyan
        _ = Theme.pink
        _ = Theme.workerColors
        _ = Theme.bgGradient
        _ = Theme.overlay
        _ = Theme.overlayBg
    }

    // MARK: - Font Access (smoke tests)

    func testThemeFontAccessDoesNotCrash() {
        _ = Theme.monoTiny
        _ = Theme.monoSmall
        _ = Theme.monoNormal
        _ = Theme.monoBold
        _ = Theme.pixel
        _ = Theme.mono(10)
        _ = Theme.mono(12, weight: .bold)
        _ = Theme.code(10)
        _ = Theme.code(11, weight: .semibold)
        _ = Theme.scaled(10)
        _ = Theme.chrome(9)
        _ = Theme.chrome(10, weight: .medium)
    }

    // MARK: - Icon Size

    func testThemeIconSizeScaling() {
        let baseSize: CGFloat = 10
        let iconSize = Theme.iconSize(baseSize)
        XCTAssertGreaterThanOrEqual(iconSize, baseSize) // Scale >= 1.0
    }

    func testThemeChromeIconSizeScaling() {
        let baseSize: CGFloat = 10
        let iconSize = Theme.chromeIconSize(baseSize)
        XCTAssertGreaterThanOrEqual(iconSize, baseSize) // Chrome scale >= 1.0
    }

    // MARK: - Cache Invalidation

    func testInvalidateFontCacheDoesNotCrash() {
        _ = Theme.mono(12)
        Theme.invalidateFontCache()
        _ = Theme.mono(12)
    }

    // MARK: - Accent Helpers

    func testAccentBgDoesNotCrash() {
        let color = Theme.accent
        _ = Theme.accentBg(color)
        _ = Theme.accentBorder(color)
    }

    func testAccentBackgroundDoesNotCrash() {
        _ = Theme.accentBackground
        _ = Theme.accentSoftBackground
    }

    // MARK: - AppChromeTone

    func testAppChromeToneColors() {
        let tones: [AppChromeTone] = [.neutral, .accent, .green, .red, .yellow, .purple, .cyan, .orange]
        for tone in tones {
            // Each tone should produce a valid color without crashing
            _ = tone.color
        }
    }

    func testAppChromeToneEquatable() {
        XCTAssertEqual(AppChromeTone.neutral, AppChromeTone.neutral)
        XCTAssertNotEqual(AppChromeTone.accent, AppChromeTone.green)
    }
}
