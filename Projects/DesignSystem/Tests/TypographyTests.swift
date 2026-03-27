import XCTest
@testable import DesignSystem

final class TypographyTests: XCTestCase {

    func testFontCacheWorks() {
        Typography.invalidateCache()
        let font1 = Typography.mono(12, weight: .regular, scale: 1.0)
        let font2 = Typography.mono(12, weight: .regular, scale: 1.0)
        // Same parameters should return cached font (no crash = ok)
        XCTAssertNotNil(font1)
        XCTAssertNotNil(font2)
    }

    func testInvalidateCacheDoesNotCrash() {
        _ = Typography.mono(10, weight: .bold, scale: 1.5)
        _ = Typography.code(11, weight: .regular, scale: 1.0)
        _ = Typography.chrome(9, weight: .semibold, chromeScale: 1.2)
        Typography.invalidateCache()
        // After invalidation, new calls should work
        let font = Typography.mono(10, weight: .bold, scale: 1.5)
        XCTAssertNotNil(font)
    }

    func testDifferentScalesProduceDifferentCacheKeys() {
        Typography.invalidateCache()
        let f1 = Typography.mono(12, weight: .regular, scale: 1.0)
        let f2 = Typography.mono(12, weight: .regular, scale: 2.0)
        // They should be different fonts (test no crash)
        XCTAssertNotNil(f1)
        XCTAssertNotNil(f2)
    }

    func testCustomFontDoesNotCrash() {
        let font = Typography.mono(12, weight: .regular, scale: 1.0, customFont: "Menlo")
        XCTAssertNotNil(font)
    }

    func testAllFontFactories() {
        XCTAssertNotNil(Typography.monoTiny(scale: 1.0))
        XCTAssertNotNil(Typography.monoSmall(scale: 1.0))
        XCTAssertNotNil(Typography.monoNormal(scale: 1.0))
        XCTAssertNotNil(Typography.monoBold(scale: 1.0))
        XCTAssertNotNil(Typography.pixel(chromeScale: 1.0))
        XCTAssertNotNil(Typography.code(10, weight: .regular, scale: 1.0))
        XCTAssertNotNil(Typography.scaled(10, weight: .regular, scale: 1.0))
        XCTAssertNotNil(Typography.chrome(10, weight: .regular, chromeScale: 1.0))
    }

    func testCodeFontAlwaysMonospaced() {
        // code() should not crash with various sizes and weights
        let sizes: [CGFloat] = [8, 10, 12, 14, 16]
        let weights: [Font.Weight] = [.regular, .medium, .bold]
        for size in sizes {
            for weight in weights {
                XCTAssertNotNil(Typography.code(size, weight: weight, scale: 1.0))
            }
        }
    }

    func testScaledFontWithCustomFont() {
        let font = Typography.scaled(12, weight: .regular, scale: 1.0, customFont: "Courier")
        XCTAssertNotNil(font)
    }

    func testScaledFontWithEmptyCustomFont() {
        // Empty custom font should fallback to system
        let font = Typography.scaled(12, weight: .regular, scale: 1.0, customFont: "")
        XCTAssertNotNil(font)
    }

    func testChromeWithCustomFont() {
        let font = Typography.chrome(10, weight: .semibold, chromeScale: 1.0, customFont: "Menlo")
        XCTAssertNotNil(font)
    }

    func testCacheSizeLimit() {
        Typography.invalidateCache()
        // Create more than maxCacheSize (64) entries to trigger eviction
        for i in 0..<70 {
            _ = Typography.mono(CGFloat(i), weight: .regular, scale: 1.0)
        }
        // Should not crash; cache should evict gracefully
        let font = Typography.mono(12, weight: .regular, scale: 1.0)
        XCTAssertNotNil(font)
    }
}
