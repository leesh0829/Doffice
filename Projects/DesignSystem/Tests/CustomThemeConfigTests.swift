import XCTest
@testable import DesignSystem

final class CustomThemeConfigTests: XCTestCase {

    func testDefaultValues() {
        let config = CustomThemeConfig.default
        XCTAssertNil(config.accentHex)
        XCTAssertNil(config.fontName)
        XCTAssertNil(config.fontSize)
        XCTAssertFalse(config.useGradient)
        XCTAssertNil(config.bgHex)
        XCTAssertNil(config.bgCardHex)
        XCTAssertNil(config.bgSurfaceHex)
        XCTAssertNil(config.bgTertiaryHex)
        XCTAssertNil(config.textPrimaryHex)
        XCTAssertNil(config.textSecondaryHex)
        XCTAssertNil(config.textDimHex)
        XCTAssertNil(config.textMutedHex)
        XCTAssertNil(config.borderHex)
        XCTAssertNil(config.borderStrongHex)
        XCTAssertNil(config.greenHex)
        XCTAssertNil(config.redHex)
        XCTAssertNil(config.yellowHex)
        XCTAssertNil(config.purpleHex)
        XCTAssertNil(config.orangeHex)
        XCTAssertNil(config.cyanHex)
        XCTAssertNil(config.pinkHex)
    }

    func testCodableRoundTrip() throws {
        let original = CustomThemeConfig(
            accentHex: "ff0000",
            useGradient: true,
            gradientStartHex: "ff0000",
            gradientEndHex: "0000ff",
            fontName: "Menlo",
            fontSize: 14,
            bgHex: "111111",
            textPrimaryHex: "eeeeee",
            greenHex: "00ff00"
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CustomThemeConfig.self, from: data)

        XCTAssertEqual(original, decoded)
        XCTAssertEqual(decoded.accentHex, "ff0000")
        XCTAssertEqual(decoded.useGradient, true)
        XCTAssertEqual(decoded.fontName, "Menlo")
        XCTAssertEqual(decoded.fontSize, 14)
        XCTAssertEqual(decoded.bgHex, "111111")
        XCTAssertEqual(decoded.textPrimaryHex, "eeeeee")
        XCTAssertEqual(decoded.greenHex, "00ff00")
    }

    func testEquatable() {
        let a = CustomThemeConfig(accentHex: "ff0000")
        let b = CustomThemeConfig(accentHex: "ff0000")
        let c = CustomThemeConfig(accentHex: "00ff00")

        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    func testEmptyHexTreatedAsNil() {
        let config = CustomThemeConfig(accentHex: "")
        // Empty string should be treated same as nil in color lookups
        let color = ColorTokens.accent(dark: true, custom: config)
        let defaultColor = ColorTokens.accent(dark: true)
        XCTAssertEqual(color.hexString, defaultColor.hexString)
    }

    func testPartialOverride() {
        // Only override some fields; the rest should remain nil
        let config = CustomThemeConfig(accentHex: "ff0000", bgHex: "222222")
        XCTAssertEqual(config.accentHex, "ff0000")
        XCTAssertEqual(config.bgHex, "222222")
        XCTAssertNil(config.fontName)
        XCTAssertNil(config.greenHex)
    }

    func testCodableWithPartialFields() throws {
        // JSON with only some fields set should decode fine
        let json = """
        {"accentHex":"abcdef","useGradient":false}
        """
        let data = json.data(using: .utf8)!
        let config = try JSONDecoder().decode(CustomThemeConfig.self, from: data)
        XCTAssertEqual(config.accentHex, "abcdef")
        XCTAssertFalse(config.useGradient)
        XCTAssertNil(config.fontName)
        XCTAssertNil(config.bgHex)
    }

    func testGradientConfig() {
        let config = CustomThemeConfig(
            useGradient: true,
            gradientStartHex: "ff0000",
            gradientEndHex: "0000ff"
        )
        XCTAssertTrue(config.useGradient)
        XCTAssertEqual(config.gradientStartHex, "ff0000")
        XCTAssertEqual(config.gradientEndHex, "0000ff")
    }

    func testAllSemanticColorOverrides() {
        let config = CustomThemeConfig(
            greenHex: "00ff00",
            redHex: "ff0000",
            yellowHex: "ffff00",
            purpleHex: "800080",
            orangeHex: "ffa500",
            cyanHex: "00ffff",
            pinkHex: "ff69b4"
        )

        XCTAssertEqual(ColorTokens.green(dark: true, custom: config).hexString, "00FF00")
        XCTAssertEqual(ColorTokens.red(dark: true, custom: config).hexString, "FF0000")
        XCTAssertEqual(ColorTokens.yellow(dark: true, custom: config).hexString, "FFFF00")
        XCTAssertEqual(ColorTokens.purple(dark: true, custom: config).hexString, "800080")
        XCTAssertEqual(ColorTokens.orange(dark: true, custom: config).hexString, "FFA500")
        XCTAssertEqual(ColorTokens.cyan(dark: true, custom: config).hexString, "00FFFF")
        XCTAssertEqual(ColorTokens.pink(dark: true, custom: config).hexString, "FF69B4")
    }

    func testTextColorOverrides() {
        let config = CustomThemeConfig(
            textPrimaryHex: "ffffff",
            textSecondaryHex: "cccccc",
            textDimHex: "888888",
            textMutedHex: "444444"
        )

        XCTAssertEqual(ColorTokens.textPrimary(dark: true, custom: config).hexString, "FFFFFF")
        XCTAssertEqual(ColorTokens.textSecondary(dark: true, custom: config).hexString, "CCCCCC")
        XCTAssertEqual(ColorTokens.textDim(dark: true, custom: config).hexString, "888888")
        XCTAssertEqual(ColorTokens.textMuted(dark: true, custom: config).hexString, "444444")
    }

    func testBorderOverrides() {
        let config = CustomThemeConfig(
            borderHex: "333333",
            borderStrongHex: "666666"
        )

        XCTAssertEqual(ColorTokens.border(dark: true, custom: config).hexString, "333333")
        XCTAssertEqual(ColorTokens.borderStrong(dark: true, custom: config).hexString, "666666")
    }

    func testBgLayerOverrides() {
        let config = CustomThemeConfig(
            bgHex: "111111",
            bgCardHex: "222222",
            bgSurfaceHex: "333333",
            bgTertiaryHex: "444444"
        )

        XCTAssertEqual(ColorTokens.bg(dark: true, custom: config).hexString, "111111")
        XCTAssertEqual(ColorTokens.bgCard(dark: true, custom: config).hexString, "222222")
        XCTAssertEqual(ColorTokens.bgSurface(dark: true, custom: config).hexString, "333333")
        XCTAssertEqual(ColorTokens.bgTertiary(dark: true, custom: config).hexString, "444444")
    }
}
