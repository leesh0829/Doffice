import SwiftUI
import DesignSystem
import OrderedCollections

// ═══════════════════════════════════════════════════
// MARK: - Floor Tiles (Rich Detail)
// ═══════════════════════════════════════════════════

extension OfficeSpriteRenderer {

    func drawFloorTiles(_ ctx: GraphicsContext) {
        let ts: CGFloat = 16
        for r in 0..<map.rows {
            for c in 0..<map.cols {
                let tile = map.tiles[r][c]
                guard tile.isWalkable || tile == .door else { continue }
                let x = CGFloat(c) * ts
                let y = CGFloat(r) * ts

                switch tile {
                case .floor1:
                    // Main office: neutral grey tiles with subtle pattern
                    drawOfficeTile(ctx, x: x, y: y, ts: ts, r: r, c: c)
                case .floor2:
                    // Pantry: beige/cream ceramic tiles with grout lines
                    drawPantryTile(ctx, x: x, y: y, ts: ts, r: r, c: c)
                case .floor3:
                    // Wood floor: warm brown planks with grain and variation
                    drawWoodFloor(ctx, x: x, y: y, ts: ts, r: r, c: c)
                case .carpet:
                    // Meeting room: dark blue/navy carpet with subtle texture
                    drawCarpetTile(ctx, x: x, y: y, ts: ts, r: r, c: c)
                case .door:
                    drawDoorTile(ctx, x: x, y: y, ts: ts, r: r, c: c)
                default: break
                }
            }
        }
    }

    /// Main office: warm parquet floor inspired by cozy farm sims
    internal func drawOfficeTile(_ ctx: GraphicsContext, x: CGFloat, y: CGFloat, ts: CGFloat, r: Int, c: Int) {
        let seed = (r * 37 + c * 19) & 0xFF
        let floorPalette = palette.officeFloor
        let outline = floorPalette[3]
        let highlight = floorPalette[2]
        let baseColor = Color(hex: floorPalette[seed % min(floorPalette.count, 2)])
        let half = ts / 2

        ctx.fill(Path(CGRect(x: x, y: y, width: ts, height: ts)), with: .color(baseColor))

        for row in 0..<2 {
            for col in 0..<2 {
                let tileX = x + CGFloat(col) * half
                let tileY = y + CGFloat(row) * half
                let tint = (row + col + r + c) % 2 == 0 ? 0.98 : 0.88
                ctx.fill(
                    Path(CGRect(x: tileX + 0.6, y: tileY + 0.6, width: half - 1.2, height: half - 1.2)),
                    with: .color(baseColor.opacity(tint))
                )
            }
        }

        ctx.fill(Path(CGRect(x: x, y: y, width: ts, height: 0.7)),
                 with: .color(Color(hex: highlight).opacity(0.45)))
        ctx.fill(Path(CGRect(x: x, y: y, width: 0.7, height: ts)),
                 with: .color(Color(hex: highlight).opacity(0.25)))
        ctx.fill(Path(CGRect(x: x, y: y + half - 0.25, width: ts, height: 0.5)),
                 with: .color(Color(hex: outline).opacity(0.22)))
        ctx.fill(Path(CGRect(x: x + half - 0.25, y: y, width: 0.5, height: ts)),
                 with: .color(Color(hex: outline).opacity(0.18)))
        ctx.fill(Path(CGRect(x: x, y: y + ts - 0.6, width: ts, height: 0.6)),
                 with: .color(Color(hex: outline).opacity(0.3)))

        if seed % 6 == 0 {
            let knotX = x + CGFloat(3 + seed % 8)
            let knotY = y + CGFloat(4 + (seed / 7) % 7)
            ctx.fill(Path(ellipseIn: CGRect(x: knotX, y: knotY, width: 2.2, height: 1.4)),
                     with: .color(Color(hex: outline).opacity(0.18)))
        }
    }

    /// Pantry: warm cream ceramic tiles with visible grout grid
    internal func drawPantryTile(_ ctx: GraphicsContext, x: CGFloat, y: CGFloat, ts: CGFloat, r: Int, c: Int) {
        let pantryPalette = palette.pantryFloor
        let checker = (r + c) % 2 == 0
        let baseHex = checker ? pantryPalette[0] : pantryPalette[1]
        ctx.fill(Path(CGRect(x: x, y: y, width: ts, height: ts)), with: .color(Color(hex: baseHex)))

        // Grout lines (darker, visible)
        let groutHex = pantryPalette[2]
        // Bottom grout
        ctx.fill(Path(CGRect(x: x, y: y + ts - 0.8, width: ts, height: 0.8)),
                 with: .color(Color(hex: groutHex).opacity(0.5)))
        // Right grout
        ctx.fill(Path(CGRect(x: x + ts - 0.8, y: y, width: 0.8, height: ts)),
                 with: .color(Color(hex: groutHex).opacity(0.5)))
        // Top highlight
        let hiHex = palette.windowGlow
        ctx.fill(Path(CGRect(x: x, y: y, width: ts, height: 0.5)),
                 with: .color(Color(hex: hiHex).opacity(0.3)))
        // Left highlight
        ctx.fill(Path(CGRect(x: x, y: y, width: 0.5, height: ts)),
                 with: .color(Color(hex: hiHex).opacity(0.2)))

        // Subtle tile variation (soft flower-like center)
        let seed = (r * 13 + c * 29) & 0xFF
        if seed % 7 == 0 {
            let dx = x + CGFloat(seed % 10) + 3
            let dy = y + CGFloat((seed / 5) % 10) + 3
            let dotHex = palette.trim
            ctx.fill(Path(ellipseIn: CGRect(x: dx, y: dy, width: 1.7, height: 1.7)),
                     with: .color(Color(hex: dotHex).opacity(0.2)))
        }
    }

    /// Wood floor: warm brown planks with grain lines and alternating widths
    internal func drawWoodFloor(_ ctx: GraphicsContext, x: CGFloat, y: CGFloat, ts: CGFloat, r: Int, c: Int) {
        // Base warm wood color with variation per tile
        let seed = (r * 37 + c * 53) & 0xFF
        let variant = seed % 4
        let baseHex: String
        if dark {
            baseHex = ["6C4C31", "61452B", "734F35", "5B4228"][variant]
        } else {
            baseHex = ["B77E48", "AF7641", "BE8851", "A7703E"][variant]
        }
        ctx.fill(Path(CGRect(x: x, y: y, width: ts, height: ts)), with: .color(Color(hex: baseHex)))

        // Draw individual plank lines (horizontal grain)
        let plankPositions: [(CGFloat, CGFloat)] = [
            (0, 4.5), (4.5, 3.5), (8, 4), (12, 4)
        ]
        let grainHex = dark ? "4A3320" : "8B5B2D"
        let grainHiHex = dark ? "8E6642" : "D5A56C"

        for (py, ph) in plankPositions {
            let gy = y + py
            // Plank top edge (lighter)
            ctx.fill(Path(CGRect(x: x + 0.5, y: gy, width: ts - 1, height: 0.4)),
                     with: .color(Color(hex: grainHiHex).opacity(0.3)))
            // Plank bottom edge / gap (darker)
            ctx.fill(Path(CGRect(x: x + 0.5, y: gy + ph - 0.4, width: ts - 1, height: 0.5)),
                     with: .color(Color(hex: grainHex).opacity(0.45)))
        }

        // Horizontal wood grain lines within planks
        let grainSeed = (r * 11 + c * 7) & 0x3F
        for i in 0..<3 {
            let gy = y + CGFloat(2 + i * 5 + grainSeed % 3)
            let gx = x + CGFloat((grainSeed + i * 13) % 6)
            let gw = CGFloat(6 + (grainSeed + i * 7) % 6)
            if gy < y + ts - 1 {
                ctx.fill(Path(CGRect(x: gx, y: gy, width: gw, height: 0.3)),
                         with: .color(Color(hex: grainHex).opacity(0.2)))
            }
        }

        // Occasional knot (small dark circle)
        if seed % 11 == 0 {
            let kx = x + CGFloat(3 + seed % 10)
            let ky = y + CGFloat(3 + (seed / 3) % 10)
            let knotHex = dark ? "2A2018" : "B09870"
            ctx.fill(Path(ellipseIn: CGRect(x: kx, y: ky, width: 2, height: 1.5)),
                     with: .color(Color(hex: knotHex).opacity(0.4)))
        }

        // Vertical plank seam (staggered per row)
        let seamOffset = (r % 2 == 0) ? 0 : 8
        let seamX = x + CGFloat(seamOffset)
        if seamX > x && seamX < x + ts {
            let seamHex = dark ? "3C2816" : "84562D"
            ctx.fill(Path(CGRect(x: seamX - 0.2, y: y, width: 0.5, height: ts)),
                     with: .color(Color(hex: seamHex).opacity(0.35)))
        }
    }

    /// Meeting room carpet: deep navy with subtle cross-hatch texture
    internal func drawCarpetTile(_ ctx: GraphicsContext, x: CGFloat, y: CGFloat, ts: CGFloat, r: Int, c: Int) {
        let carpetPalette = palette.carpetFloor
        let checker = (r + c) % 2 == 0
        let baseHex = checker ? carpetPalette[0] : carpetPalette[1]
        ctx.fill(Path(CGRect(x: x, y: y, width: ts, height: ts)), with: .color(Color(hex: baseHex)))

        // Carpet weave texture: alternating tiny dots
        let texHex = carpetPalette[2]
        let seed = (r * 19 + c * 23) & 0xFF
        for i in stride(from: 0, to: Int(ts), by: 2) {
            for j in stride(from: (i + seed) % 2, to: Int(ts), by: 3) {
                let dotX = x + CGFloat(i)
                let dotY = y + CGFloat(j)
                ctx.fill(Path(CGRect(x: dotX, y: dotY, width: 0.6, height: 0.6)),
                         with: .color(Color(hex: texHex).opacity(0.15)))
            }
        }

        // Subtle sheen highlight along diagonal
        if (r + c) % 4 == 0 {
            let sheenHex = palette.windowGlow
            ctx.fill(Path(CGRect(x: x + 2, y: y + 2, width: ts - 4, height: 0.4)),
                     with: .color(Color(hex: sheenHex).opacity(0.15)))
        }
    }

    /// Door tile: warm wooden door with panel detail
    internal func drawDoorTile(_ ctx: GraphicsContext, x: CGFloat, y: CGFloat, ts: CGFloat, r: Int, c: Int) {
        let baseHex = palette.trim
        ctx.fill(Path(CGRect(x: x, y: y, width: ts, height: ts)), with: .color(Color(hex: baseHex)))
        // Raised panel
        let panelHex = palette.trimHighlight
        ctx.fill(Path(CGRect(x: x + 2, y: y + 1.5, width: ts - 4, height: ts - 3)),
                 with: .color(Color(hex: panelHex)))
        // Panel bevel top
        let bevelHi = palette.windowGlow
        ctx.fill(Path(CGRect(x: x + 2, y: y + 1.5, width: ts - 4, height: 0.6)),
                 with: .color(Color(hex: bevelHi).opacity(0.5)))
        // Panel bevel bottom
        let bevelLo = palette.wallShadow
        ctx.fill(Path(CGRect(x: x + 2, y: y + ts - 2, width: ts - 4, height: 0.6)),
                 with: .color(Color(hex: bevelLo).opacity(0.4)))
        // Doorknob
        let knobHex = dark ? "C5A15B" : "E7C36C"
        ctx.fill(Path(ellipseIn: CGRect(x: x + ts - 5, y: y + ts / 2 - 1, width: 2, height: 2)),
                 with: .color(Color(hex: knobHex)))
    }

    func drawBackdrop(_ ctx: GraphicsContext) {
        let width = CGFloat(map.cols) * 16
        let height = CGFloat(map.rows) * 16
        let sceneRect = CGRect(x: 0, y: 0, width: width, height: height)
        let base = Color(hex: palette.backdropBottom)
        let topGlow = Color(hex: palette.backdropTop)
        let middleGlow = Color(hex: palette.backdropGlow)

        ctx.fill(Path(sceneRect), with: .color(base))
        ctx.fill(Path(CGRect(x: 0, y: 0, width: width, height: height * 0.45)),
                 with: .color(topGlow.opacity(0.85)))
        ctx.fill(Path(CGRect(x: 0, y: height * 0.18, width: width, height: height * 0.24)),
                 with: .color(middleGlow.opacity(dark ? 0.10 : 0.18)))
        ctx.fill(Path(CGRect(x: 0, y: height * 0.55, width: width, height: height * 0.45)),
                 with: .color(base.opacity(0.70)))
    }
}
