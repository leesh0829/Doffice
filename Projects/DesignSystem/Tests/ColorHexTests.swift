import XCTest
@testable import DesignSystem

final class ColorHexTests: XCTestCase {

    func testValidHex6() {
        let color = Color(hex: "ff0000")
        XCTAssertEqual(color.hexString, "FF0000")
    }

    func testValidHex3() {
        let color = Color(hex: "f00")
        XCTAssertEqual(color.hexString, "FF0000")
    }

    func testHexWithHash() {
        let color = Color(hex: "#00ff00")
        XCTAssertEqual(color.hexString, "00FF00")
    }

    func testHexRoundTrip() {
        let original = "3291FF"
        let color = Color(hex: original)
        XCTAssertEqual(color.hexString, original)
    }

    func testInvalidHexFallback() {
        let color = Color(hex: "xyz")
        XCTAssertEqual(color.hexString, "000000") // fallback to black
    }

    func testIsValidHex() {
        XCTAssertTrue(Color.isValidHex("ff0000"))
        XCTAssertTrue(Color.isValidHex("#ff0000"))
        XCTAssertTrue(Color.isValidHex("f00"))
        XCTAssertFalse(Color.isValidHex("xyz"))
        XCTAssertFalse(Color.isValidHex(""))
        XCTAssertFalse(Color.isValidHex("ff00"))
    }

    func testLuminanceBlack() {
        XCTAssertEqual(Color(hex: "000000").luminance, 0, accuracy: 0.01)
    }

    func testLuminanceWhite() {
        XCTAssertEqual(Color(hex: "ffffff").luminance, 1.0, accuracy: 0.01)
    }

    func testContrastingTextColor() {
        XCTAssertEqual(Color.white.contrastingTextColor, .black)
        XCTAssertEqual(Color.black.contrastingTextColor, .white)
    }

    func testLuminanceMidGray() {
        let gray = Color(hex: "808080")
        XCTAssertGreaterThan(gray.luminance, 0.1)
        XCTAssertLessThan(gray.luminance, 0.5)
    }

    func testHexCaseInsensitive() {
        let lower = Color(hex: "aabbcc")
        let upper = Color(hex: "AABBCC")
        XCTAssertEqual(lower.hexString, upper.hexString)
    }

    func testHex3Expansion() {
        // "abc" should expand to "aabbcc"
        let short = Color(hex: "abc")
        let long = Color(hex: "aabbcc")
        XCTAssertEqual(short.hexString, long.hexString)
    }

    func testIsValidHexWithLeadingHash() {
        XCTAssertTrue(Color.isValidHex("#abc"))
        XCTAssertTrue(Color.isValidHex("#aabbcc"))
    }

    func testIsValidHexRejectsInvalid() {
        XCTAssertFalse(Color.isValidHex("gggggg"))
        XCTAssertFalse(Color.isValidHex("12345"))   // 5 chars
        XCTAssertFalse(Color.isValidHex("1234567"))  // 7 chars
    }
}
