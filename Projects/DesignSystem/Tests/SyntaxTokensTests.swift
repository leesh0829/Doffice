import XCTest
@testable import DesignSystem

final class SyntaxTokensTests: XCTestCase {

    // MARK: - Syntax Token Access (smoke tests)
    // Note: DSSyntax tokens depend on AppSettings.shared.isDarkMode internally.
    // These tests verify that all tokens can be accessed without crashing
    // and produce valid colors.

    func testAllTokensProduceValidColors() {
        let tokens = [
            DSSyntax.keyword, DSSyntax.control, DSSyntax.type, DSSyntax.declaration,
            DSSyntax.string, DSSyntax.number, DSSyntax.boolean,
            DSSyntax.function, DSSyntax.method, DSSyntax.parameter,
            DSSyntax.comment, DSSyntax.docComment,
            DSSyntax.operator, DSSyntax.punctuation,
            DSSyntax.property, DSSyntax.variable, DSSyntax.constant,
            DSSyntax.regex, DSSyntax.escape, DSSyntax.annotation,
        ]

        for color in tokens {
            XCTAssertGreaterThan(color.luminance, 0, "Syntax token should not be pure black")
        }
    }

    func testTerminalColors() {
        let termColors = [
            DSSyntax.termRed, DSSyntax.termGreen, DSSyntax.termYellow,
            DSSyntax.termBlue, DSSyntax.termMagenta, DSSyntax.termCyan, DSSyntax.termWhite,
        ]

        // All terminal colors should be distinct
        let hexSet = Set(termColors.map { $0.hexString })
        XCTAssertEqual(hexSet.count, termColors.count, "Terminal colors should all be unique")
    }

    func testTerminalBlackExists() {
        let black = DSSyntax.termBlack
        XCTAssertNotNil(black)
        // termBlack is not pure black in either mode
        XCTAssertGreaterThan(black.luminance, 0)
    }

    func testDiffColorsContrast() {
        // Added and removed text colors should be non-black
        XCTAssertGreaterThan(DSSyntax.diffAddedText.luminance, 0)
        XCTAssertGreaterThan(DSSyntax.diffRemovedText.luminance, 0)
    }

    func testDiffBackgroundColors() {
        // Diff background colors (with opacity) should be accessible
        _ = DSSyntax.diffAdded
        _ = DSSyntax.diffRemoved
    }

    func testDiffAddedAndRemovedAreDifferent() {
        XCTAssertNotEqual(DSSyntax.diffAddedText.hexString, DSSyntax.diffRemovedText.hexString)
    }

    func testKeywordAndTypeAreDifferent() {
        // Keywords and types should have different colors for readability
        XCTAssertNotEqual(DSSyntax.keyword.hexString, DSSyntax.type.hexString)
    }

    func testStringAndCommentAreDifferent() {
        XCTAssertNotEqual(DSSyntax.string.hexString, DSSyntax.comment.hexString)
    }

    func testAllTerminalColorsAccessible() {
        // Verify all 8 terminal ANSI colors can be accessed
        _ = DSSyntax.termBlack
        _ = DSSyntax.termRed
        _ = DSSyntax.termGreen
        _ = DSSyntax.termYellow
        _ = DSSyntax.termBlue
        _ = DSSyntax.termMagenta
        _ = DSSyntax.termCyan
        _ = DSSyntax.termWhite
    }
}
