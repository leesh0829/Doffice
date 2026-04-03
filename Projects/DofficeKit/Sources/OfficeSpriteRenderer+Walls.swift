import SwiftUI
import DesignSystem
import OrderedCollections

// ═══════════════════════════════════════════════════
// MARK: - Window & Wall Rendering
// ═══════════════════════════════════════════════════

extension OfficeSpriteRenderer {

    func drawWindowLight(_ ctx: GraphicsContext) {
        let beams: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (40, 32, 42, 118),
            (138, 30, 38, 108),
            (232, 34, 44, 112),
            (480, 32, 32, 92),
            (584, 34, 28, 76),
        ]

        for (x, y, w, h) in beams {
            var beam = Path()
            beam.move(to: CGPoint(x: x, y: y))
            beam.addLine(to: CGPoint(x: x + w, y: y))
            beam.addLine(to: CGPoint(x: x + w + 18, y: y + h))
            beam.addLine(to: CGPoint(x: x - 10, y: y + h))
            beam.closeSubpath()

            ctx.fill(
                beam,
                with: .color(Color(hex: palette.beamColor).opacity(palette.beamOpacity))
            )
        }
    }

    internal func drawWallWindow(_ ctx: GraphicsContext, x: CGFloat, y: CGFloat, ts: CGFloat) {
        let frameHex = palette.windowFrame
        let sillHex = palette.windowSill
        let skyHex = theme.skyColors.bottom
        let cloudHex = palette.outdoorAccent

        ctx.fill(Path(roundedRect: CGRect(x: x + 1.6, y: y + 2, width: ts - 3.2, height: ts - 5.2), cornerRadius: 1.2),
                 with: .color(Color(hex: frameHex)))
        ctx.fill(Path(CGRect(x: x + 3, y: y + 3.5, width: ts - 6, height: ts - 8)),
                 with: .color(Color(hex: skyHex)))
        ctx.fill(Path(CGRect(x: x + 3, y: y + 3.5, width: ts - 6, height: 1.6)),
                 with: .color(Color(hex: theme.skyColors.top).opacity(0.9)))
        ctx.fill(Path(CGRect(x: x + ts / 2 - 0.4, y: y + 3.5, width: 0.8, height: ts - 8)),
                 with: .color(Color(hex: frameHex).opacity(0.7)))
        ctx.fill(Path(CGRect(x: x + 3, y: y + ts / 2, width: ts - 6, height: 0.7)),
                 with: .color(Color(hex: frameHex).opacity(0.45)))
        ctx.fill(Path(CGRect(x: x + 2.3, y: y + ts - 3.2, width: ts - 4.6, height: 1.2)),
                 with: .color(Color(hex: sillHex)))
        ctx.fill(Path(ellipseIn: CGRect(x: x + 4.6, y: y + 4.8, width: 4.2, height: 1.8)),
                 with: .color(Color(hex: cloudHex).opacity(0.55)))
        drawWindowExteriorDetail(ctx, x: x, y: y, ts: ts)
        ctx.fill(Path(CGRect(x: x + 4, y: y + 4.3, width: 2.4, height: ts - 9)),
                 with: .color(Color(hex: palette.windowGlow).opacity(0.12)))
    }

    internal func drawWindowExteriorDetail(_ ctx: GraphicsContext, x: CGFloat, y: CGFloat, ts: CGFloat) {
        let detailFrame = CGRect(x: x + 3, y: y + 3.5, width: ts - 6, height: ts - 8)

        switch theme {
        case .rain, .storm, .fog:
            for index in 0..<3 {
                let rainX = detailFrame.minX + 1 + CGFloat(index) * 3.4
                ctx.fill(Path(CGRect(x: rainX, y: detailFrame.minY + 1, width: 0.45, height: detailFrame.height - 2)),
                         with: .color(Color(hex: palette.outdoorAccent).opacity(theme == .fog ? 0.14 : 0.22)))
            }
        case .snow:
            for index in 0..<4 {
                let flakeX = detailFrame.minX + CGFloat((index * 5) % 8)
                let flakeY = detailFrame.minY + CGFloat((index * 3) % 5) + 1
                ctx.fill(Path(ellipseIn: CGRect(x: flakeX, y: flakeY, width: 1, height: 1)),
                         with: .color(Color(hex: palette.windowGlow).opacity(0.6)))
            }
        case .forest, .autumn:
            ctx.fill(Path(CGRect(x: detailFrame.minX + 0.5, y: detailFrame.maxY - 2.2, width: detailFrame.width - 1, height: 1.3)),
                     with: .color(Color(hex: palette.outdoorAccent2).opacity(0.7)))
            ctx.fill(Path(ellipseIn: CGRect(x: detailFrame.minX + 0.8, y: detailFrame.maxY - 4.3, width: 2.8, height: 2.4)),
                     with: .color(Color(hex: palette.outdoorAccent).opacity(0.55)))
        case .cherryBlossom:
            ctx.fill(Path(ellipseIn: CGRect(x: detailFrame.minX + 1.2, y: detailFrame.minY + 1.5, width: 1.4, height: 1.2)),
                     with: .color(Color(hex: palette.outdoorAccent).opacity(0.7)))
            ctx.fill(Path(ellipseIn: CGRect(x: detailFrame.minX + 4.4, y: detailFrame.minY + 3.1, width: 1.2, height: 1.2)),
                     with: .color(Color(hex: palette.outdoorAccent2).opacity(0.65)))
        case .neonCity:
            ctx.fill(Path(CGRect(x: detailFrame.minX + 0.8, y: detailFrame.maxY - 4, width: 1.2, height: 3)),
                     with: .color(Color(hex: palette.outdoorAccent2).opacity(0.85)))
            ctx.fill(Path(CGRect(x: detailFrame.minX + 3.4, y: detailFrame.maxY - 5.3, width: 1.6, height: 4.3)),
                     with: .color(Color(hex: palette.outdoorAccent).opacity(0.55)))
        case .ocean:
            ctx.fill(Path(CGRect(x: detailFrame.minX + 0.5, y: detailFrame.maxY - 2.7, width: detailFrame.width - 1, height: 0.8)),
                     with: .color(Color(hex: palette.outdoorAccent2).opacity(0.7)))
            ctx.fill(Path(CGRect(x: detailFrame.minX + 0.5, y: detailFrame.maxY - 1.6, width: detailFrame.width - 1, height: 0.5)),
                     with: .color(Color(hex: palette.outdoorAccent).opacity(0.45)))
        case .desert:
            ctx.fill(Path(ellipseIn: CGRect(x: detailFrame.minX + 0.8, y: detailFrame.maxY - 3.2, width: detailFrame.width - 1.6, height: 2.1)),
                     with: .color(Color(hex: palette.outdoorAccent2).opacity(0.45)))
        case .volcano:
            var mountain = Path()
            mountain.move(to: CGPoint(x: detailFrame.minX + 1, y: detailFrame.maxY - 1))
            mountain.addLine(to: CGPoint(x: detailFrame.midX, y: detailFrame.minY + 2.2))
            mountain.addLine(to: CGPoint(x: detailFrame.maxX - 1, y: detailFrame.maxY - 1))
            mountain.closeSubpath()
            ctx.fill(mountain, with: .color(Color(hex: palette.outdoorAccent2).opacity(0.5)))
            ctx.fill(Path(CGRect(x: detailFrame.midX - 0.4, y: detailFrame.minY + 1.1, width: 0.8, height: 1.6)),
                     with: .color(Color(hex: palette.outdoorAccent).opacity(0.7)))
        default:
            break
        }
    }

    internal func tileAt(col: Int, row: Int) -> TileType {
        guard row >= 0, row < map.rows, col >= 0, col < map.cols else { return .void }
        return map.tiles[row][col]
    }

    internal func drawWallCornerAccents(
        _ ctx: GraphicsContext,
        x: CGFloat,
        y: CGFloat,
        ts: CGFloat,
        above: TileType,
        below: TileType,
        left: TileType,
        right: TileType,
        topLeft: TileType,
        topRight: TileType,
        bottomLeft: TileType,
        bottomRight: TileType
    ) {
        let exposedTop = above != .wall
        let exposedBottom = below != .wall
        let exposedLeft = left != .wall
        let exposedRight = right != .wall
        let wallHi = palette.wallHighlight
        let wallLo = palette.wallShadow
        let trimHi = palette.trimHighlight
        let trimLo = palette.trim

        if exposedTop && exposedLeft {
            ctx.fill(Path(CGRect(x: x, y: y, width: 3.2, height: 3.2)),
                     with: .color(Color(hex: wallHi).opacity(0.34)))
            ctx.fill(Path(CGRect(x: x, y: y + ts - 4.1, width: 2.8, height: 0.7)),
                     with: .color(Color(hex: trimHi).opacity(0.35)))
        }
        if exposedTop && exposedRight {
            ctx.fill(Path(CGRect(x: x + ts - 3.2, y: y, width: 3.2, height: 3.2)),
                     with: .color(Color(hex: wallHi).opacity(0.34)))
            ctx.fill(Path(CGRect(x: x + ts - 2.8, y: y + ts - 4.1, width: 2.8, height: 0.7)),
                     with: .color(Color(hex: trimHi).opacity(0.35)))
        }
        if exposedBottom && exposedLeft {
            ctx.fill(Path(CGRect(x: x, y: y + ts - 3.4, width: 3, height: 2.6)),
                     with: .color(Color(hex: trimLo).opacity(0.32)))
        }
        if exposedBottom && exposedRight {
            ctx.fill(Path(CGRect(x: x + ts - 3, y: y + ts - 3.4, width: 3, height: 2.6)),
                     with: .color(Color(hex: trimLo).opacity(0.32)))
        }

        if !exposedTop && !exposedLeft && topLeft != .wall {
            ctx.fill(Path(CGRect(x: x, y: y, width: 2.2, height: 2.2)),
                     with: .color(Color(hex: wallLo).opacity(0.22)))
        }
        if !exposedTop && !exposedRight && topRight != .wall {
            ctx.fill(Path(CGRect(x: x + ts - 2.2, y: y, width: 2.2, height: 2.2)),
                     with: .color(Color(hex: wallLo).opacity(0.22)))
        }
        if !exposedBottom && !exposedLeft && bottomLeft != .wall {
            ctx.fill(Path(CGRect(x: x, y: y + ts - 2.2, width: 2.2, height: 2.2)),
                     with: .color(Color(hex: wallLo).opacity(0.18)))
        }
        if !exposedBottom && !exposedRight && bottomRight != .wall {
            ctx.fill(Path(CGRect(x: x + ts - 2.2, y: y + ts - 2.2, width: 2.2, height: 2.2)),
                     with: .color(Color(hex: wallLo).opacity(0.18)))
        }
    }

    // ═══════════════════════════════════════════════════
    // MARK: - Walls (3D Bevel + Shadow)
    // ═══════════════════════════════════════════════════

    func drawWalls(_ ctx: GraphicsContext) {
        let ts: CGFloat = 16

        for r in 0..<map.rows {
            for c in 0..<map.cols {
                guard map.tiles[r][c] == .wall else { continue }
                let x = CGFloat(c) * ts, y = CGFloat(r) * ts
                let isTopOuterWall = r <= 1 && c > 0 && c < map.cols - 1
                let hasWindow = isTopOuterWall && Self.windowColumns.contains(c)

                // Main wall body
                let wallBase = palette.wallBase
                ctx.fill(Path(CGRect(x: x, y: y, width: ts, height: ts)),
                         with: .color(Color(hex: wallBase)))

                // Top bevel highlight (painted crown)
                let wallHi = palette.wallHighlight
                ctx.fill(Path(CGRect(x: x, y: y, width: ts, height: 2.5)),
                         with: .color(Color(hex: wallHi).opacity(0.7)))
                // Very top bright line
                let wallBright = palette.wallBright
                ctx.fill(Path(CGRect(x: x, y: y, width: ts, height: 1)),
                         with: .color(Color(hex: wallBright).opacity(0.6)))

                // Bottom trim and baseboard
                let wallLo = palette.wallShadow
                ctx.fill(Path(CGRect(x: x, y: y + ts - 1.5, width: ts, height: 1.5)),
                         with: .color(Color(hex: wallLo).opacity(0.5)))
                let trimHex = palette.trim
                ctx.fill(Path(CGRect(x: x, y: y + ts - 3.4, width: ts, height: 1.9)),
                         with: .color(Color(hex: trimHex)))
                ctx.fill(Path(CGRect(x: x, y: y + ts - 4.1, width: ts, height: 0.7)),
                         with: .color(Color(hex: palette.trimHighlight).opacity(0.35)))

                // Left bevel
                ctx.fill(Path(CGRect(x: x, y: y, width: 1, height: ts)),
                         with: .color(Color(hex: wallHi).opacity(0.2)))

                // Right shadow edge
                ctx.fill(Path(CGRect(x: x + ts - 1, y: y, width: 1, height: ts)),
                         with: .color(Color(hex: wallLo).opacity(0.25)))

                // Wallpaper subtle texture (reduced for clarity)
                if hasWindow {
                    drawWallWindow(ctx, x: x, y: y, ts: ts)
                }

                // Dark outline border
                let outHex = palette.wallShadow
                // Check neighbors to only draw border on exposed edges
                let above = r > 0 ? map.tiles[r-1][c] : .void
                let below = r < map.rows - 1 ? map.tiles[r+1][c] : .void
                let left = c > 0 ? map.tiles[r][c-1] : .void
                let right = c < map.cols - 1 ? map.tiles[r][c+1] : .void
                let topLeft = tileAt(col: c - 1, row: r - 1)
                let topRight = tileAt(col: c + 1, row: r - 1)
                let bottomLeft = tileAt(col: c - 1, row: r + 1)
                let bottomRight = tileAt(col: c + 1, row: r + 1)

                if above != .wall {
                    ctx.fill(Path(CGRect(x: x, y: y, width: ts, height: 0.8)),
                             with: .color(Color(hex: outHex).opacity(0.5)))
                }
                if below != .wall {
                    ctx.fill(Path(CGRect(x: x, y: y + ts - 0.8, width: ts, height: 0.8)),
                             with: .color(Color(hex: outHex).opacity(0.6)))
                }
                if left != .wall {
                    ctx.fill(Path(CGRect(x: x, y: y, width: 0.8, height: ts)),
                             with: .color(Color(hex: outHex).opacity(0.4)))
                }
                if right != .wall {
                    ctx.fill(Path(CGRect(x: x + ts - 0.8, y: y, width: 0.8, height: ts)),
                             with: .color(Color(hex: outHex).opacity(0.4)))
                }

                drawWallCornerAccents(
                    ctx,
                    x: x,
                    y: y,
                    ts: ts,
                    above: above,
                    below: below,
                    left: left,
                    right: right,
                    topLeft: topLeft,
                    topRight: topRight,
                    bottomLeft: bottomLeft,
                    bottomRight: bottomRight
                )

                // Cast shadow below wall onto floor
                if below != .wall && below != .void {
                    let shadowGradient: [(CGFloat, Double)] = [(0, 0.18), (1.5, 0.10), (3.5, 0.04), (5, 0)]
                    for (sy, alpha) in shadowGradient {
                        ctx.fill(Path(CGRect(x: x, y: CGFloat(r+1) * ts + sy, width: ts, height: 1.5)),
                                 with: .color(Color.black.opacity(dark ? alpha * 1.2 : alpha)))
                    }
                }
            }
        }
    }
}
