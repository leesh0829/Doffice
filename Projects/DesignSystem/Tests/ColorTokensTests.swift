import XCTest
@testable import DesignSystem

final class ColorTokensTests: XCTestCase {

    // MARK: - Background Colors

    func testBgDarkMode() {
        let dark = ColorTokens.bg(dark: true)
        let light = ColorTokens.bg(dark: false)
        // Dark bg should be darker than light bg
        XCTAssertLessThan(dark.luminance, light.luminance)
    }

    func testBgLayerHierarchy() {
        // Each layer should be progressively lighter in dark mode
        let bg = ColorTokens.bg(dark: true)
        let card = ColorTokens.bgCard(dark: true)
        let surface = ColorTokens.bgSurface(dark: true)
        let tertiary = ColorTokens.bgTertiary(dark: true)

        XCTAssertLessThanOrEqual(bg.luminance, card.luminance)
        XCTAssertLessThanOrEqual(card.luminance, surface.luminance)
        XCTAssertLessThanOrEqual(surface.luminance, tertiary.luminance)
    }

    func testBgLayerHierarchyLight() {
        // In light mode, bg is near-white (#fafafa), card is white (#ffffff)
        // Surface is #f5f5f5, tertiary is #ebebeb — progressively darker
        let bg = ColorTokens.bg(dark: false)
        let card = ColorTokens.bgCard(dark: false)
        let surface = ColorTokens.bgSurface(dark: false)
        let tertiary = ColorTokens.bgTertiary(dark: false)

        // Card (white) should be brightest
        XCTAssertGreaterThanOrEqual(card.luminance, bg.luminance)
        // Surface should be dimmer than bg
        XCTAssertLessThanOrEqual(surface.luminance, bg.luminance)
        // Tertiary should be dimmest
        XCTAssertLessThanOrEqual(tertiary.luminance, surface.luminance)
    }

    // MARK: - Text Hierarchy

    func testTextHierarchyDark() {
        let primary = ColorTokens.textPrimary(dark: true)
        let secondary = ColorTokens.textSecondary(dark: true)
        let dim = ColorTokens.textDim(dark: true)
        let muted = ColorTokens.textMuted(dark: true)

        // Primary should be brightest, muted should be dimmest
        XCTAssertGreaterThan(primary.luminance, secondary.luminance)
        XCTAssertGreaterThan(secondary.luminance, dim.luminance)
        XCTAssertGreaterThan(dim.luminance, muted.luminance)
    }

    func testTextHierarchyLight() {
        let primary = ColorTokens.textPrimary(dark: false)
        let secondary = ColorTokens.textSecondary(dark: false)
        let dim = ColorTokens.textDim(dark: false)
        let muted = ColorTokens.textMuted(dark: false)

        // In light mode, primary should be darkest (lowest luminance)
        XCTAssertLessThan(primary.luminance, secondary.luminance)
        XCTAssertLessThan(secondary.luminance, dim.luminance)
        XCTAssertLessThan(dim.luminance, muted.luminance)
    }

    // MARK: - Semantic Colors

    func testSemanticColorsExist() {
        // All semantic colors should produce non-nil, non-clear colors
        let colors = [
            ColorTokens.accent(dark: true),
            ColorTokens.green(dark: true),
            ColorTokens.red(dark: true),
            ColorTokens.yellow(dark: true),
            ColorTokens.purple(dark: true),
            ColorTokens.orange(dark: true),
            ColorTokens.cyan(dark: true),
            ColorTokens.pink(dark: true),
        ]

        for color in colors {
            XCTAssertGreaterThan(color.luminance, 0, "Semantic color should not be pure black")
        }
    }

    func testSemanticColorsDifferBetweenModes() {
        // Dark and light mode should produce different accent colors
        let accentDark = ColorTokens.accent(dark: true)
        let accentLight = ColorTokens.accent(dark: false)
        XCTAssertNotEqual(accentDark.hexString, accentLight.hexString)
    }

    // MARK: - Custom Theme Override

    func testCustomThemeOverridesAccent() {
        let custom = CustomThemeConfig(accentHex: "ff0000")
        let color = ColorTokens.accent(dark: true, custom: custom)
        XCTAssertEqual(color.hexString, "FF0000")
    }

    func testCustomThemeOverridesBg() {
        let custom = CustomThemeConfig(bgHex: "123456")
        let color = ColorTokens.bg(dark: true, custom: custom)
        XCTAssertEqual(color.hexString, "123456")
    }

    func testCustomThemeNilFallsBackToDefault() {
        let custom = CustomThemeConfig() // all nil
        let defaultColor = ColorTokens.accent(dark: true)
        let customColor = ColorTokens.accent(dark: true, custom: custom)
        XCTAssertEqual(defaultColor.hexString, customColor.hexString)
    }

    // MARK: - WCAG Contrast

    func testContrastRatioBlackWhite() {
        let ratio = ColorTokens.contrastRatio(.white, .black)
        XCTAssertGreaterThan(ratio, 20.0) // Should be ~21:1
    }

    func testContrastRatioSameColor() {
        let ratio = ColorTokens.contrastRatio(.red, .red)
        XCTAssertEqual(ratio, 1.0, accuracy: 0.01) // Same color = 1:1
    }

    func testMeetsContrastAA() {
        XCTAssertTrue(ColorTokens.meetsContrastAA(foreground: .white, background: .black))
        XCTAssertTrue(ColorTokens.meetsContrastAA(foreground: .black, background: .white))
    }

    func testMeetsContrastAAA() {
        XCTAssertTrue(ColorTokens.meetsContrastAAA(foreground: .white, background: .black))
    }

    func testPrimaryTextContrast() {
        // Primary text on bg should meet AA
        let textDark = ColorTokens.textPrimary(dark: true)
        let bgDark = ColorTokens.bg(dark: true)
        XCTAssertTrue(ColorTokens.meetsContrastAA(foreground: textDark, background: bgDark))

        let textLight = ColorTokens.textPrimary(dark: false)
        let bgLight = ColorTokens.bg(dark: false)
        XCTAssertTrue(ColorTokens.meetsContrastAA(foreground: textLight, background: bgLight))
    }

    // MARK: - Worker Colors

    func testWorkerColorsCount() {
        XCTAssertEqual(ColorTokens.workerColors(dark: true).count, 8)
        XCTAssertEqual(ColorTokens.workerColors(dark: false).count, 8)
    }

    func testWorkerColorsUnique() {
        let colors = ColorTokens.workerColors(dark: true).map { $0.hexString }
        XCTAssertEqual(Set(colors).count, colors.count, "Worker colors should all be unique")
    }

    // MARK: - Functional Backgrounds

    func testBgInputDifference() {
        let dark = ColorTokens.bgInput(dark: true)
        let light = ColorTokens.bgInput(dark: false)
        XCTAssertNotEqual(dark.hexString, light.hexString)
    }

    func testBgHoverDifference() {
        let dark = ColorTokens.bgHover(dark: true)
        let light = ColorTokens.bgHover(dark: false)
        XCTAssertNotEqual(dark.hexString, light.hexString)
    }

    // MARK: - Border Colors

    func testBorderDarkLightDifference() {
        let dark = ColorTokens.border(dark: true)
        let light = ColorTokens.border(dark: false)
        XCTAssertNotEqual(dark.hexString, light.hexString)
    }

    func testBorderStrongIsBrighter() {
        let border = ColorTokens.border(dark: true)
        let strong = ColorTokens.borderStrong(dark: true)
        XCTAssertGreaterThan(strong.luminance, border.luminance)
    }

    // MARK: - Accent Helpers

    func testAccentBgProducesColor() {
        let accent = ColorTokens.accent(dark: true)
        let accentBg = ColorTokens.accentBg(accent, dark: true)
        // accentBg is the accent color with low opacity -- should not crash
        XCTAssertNotNil(accentBg)
    }
}
