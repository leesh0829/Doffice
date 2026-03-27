import XCTest
@testable import DesignSystem

final class SpacingTests: XCTestCase {

    func testSpacingGrid4px() {
        XCTAssertEqual(DSSpacing.sp1, 4)
        XCTAssertEqual(DSSpacing.sp2, 8)
        XCTAssertEqual(DSSpacing.sp3, 12)
        XCTAssertEqual(DSSpacing.sp4, 16)
        XCTAssertEqual(DSSpacing.sp5, 20)
        XCTAssertEqual(DSSpacing.sp6, 24)
        XCTAssertEqual(DSSpacing.sp8, 32)
    }

    func testSpacingAll4pxMultiples() {
        let values = [DSSpacing.sp1, DSSpacing.sp2, DSSpacing.sp3, DSSpacing.sp4, DSSpacing.sp5, DSSpacing.sp6, DSSpacing.sp8]
        for v in values {
            XCTAssertEqual(v.truncatingRemainder(dividingBy: 4), 0, "\(v) should be a multiple of 4")
        }
    }

    func testRowHeightsOrdered() {
        XCTAssertLessThan(DSSpacing.rowCompact, DSSpacing.rowDefault)
        XCTAssertLessThan(DSSpacing.rowDefault, DSSpacing.rowComfortable)
    }

    func testRowHeightsValues() {
        XCTAssertEqual(DSSpacing.rowCompact, 28)
        XCTAssertEqual(DSSpacing.rowDefault, 36)
        XCTAssertEqual(DSSpacing.rowComfortable, 44)
    }

    func testPanelAndToolbarValues() {
        XCTAssertEqual(DSSpacing.panelPadding, 16)
        XCTAssertEqual(DSSpacing.cardPadding, 12)
        XCTAssertEqual(DSSpacing.toolbarHeight, 36)
        XCTAssertEqual(DSSpacing.sidebarItemHeight, 30)
    }

    func testCornersOrdered() {
        XCTAssertLessThan(DSCorners.small, DSCorners.medium)
        XCTAssertLessThan(DSCorners.medium, DSCorners.large)
        XCTAssertLessThan(DSCorners.large, DSCorners.xl)
    }

    func testCornersValues() {
        XCTAssertEqual(DSCorners.small, 5)
        XCTAssertEqual(DSCorners.medium, 6)
        XCTAssertEqual(DSCorners.large, 8)
        XCTAssertEqual(DSCorners.xl, 12)
    }

    func testBorderWidth() {
        XCTAssertEqual(DSBorder.width, 1.0)
    }

    func testBorderOpacities() {
        XCTAssertEqual(DSBorder.activeOpacity, 1.0)
        XCTAssertEqual(DSBorder.lightOpacity, 0.6)
        XCTAssertEqual(DSBorder.hoverOpacity, 0.08)
        XCTAssertEqual(DSBorder.pressedOpacity, 0.12)
        XCTAssertEqual(DSBorder.strokeActiveOpacity, 0.25)
        XCTAssertEqual(DSBorder.strokeInactiveOpacity, 0.15)
    }

    func testAnimationDurations() {
        XCTAssertLessThan(DSAnimation.fast, DSAnimation.normal)
        XCTAssertLessThan(DSAnimation.normal, DSAnimation.slow)
        XCTAssertGreaterThan(DSAnimation.fast, 0)
    }

    func testAnimationValues() {
        XCTAssertEqual(DSAnimation.fast, 0.12)
        XCTAssertEqual(DSAnimation.normal, 0.2)
        XCTAssertEqual(DSAnimation.slow, 0.35)
    }

    func testOpacityRange() {
        let opacities = [DSOpacity.disabled, DSOpacity.dimmed, DSOpacity.subtle, DSOpacity.medium, DSOpacity.prominent, DSOpacity.overlay]
        for o in opacities {
            XCTAssertGreaterThan(o, 0)
            XCTAssertLessThanOrEqual(o, 1)
        }
    }

    func testOpacityValues() {
        XCTAssertEqual(DSOpacity.disabled, 0.4)
        XCTAssertEqual(DSOpacity.dimmed, 0.6)
        XCTAssertEqual(DSOpacity.subtle, 0.08)
        XCTAssertEqual(DSOpacity.medium, 0.15)
        XCTAssertEqual(DSOpacity.prominent, 0.25)
        XCTAssertEqual(DSOpacity.overlay, 0.7)
    }
}
