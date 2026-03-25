import SwiftUI

// ═══════════════════════════════════════════════════════
// MARK: - Office Sprite Renderer (Z-sorted Canvas)
// ═══════════════════════════════════════════════════════

struct OfficeSpriteRenderer {
    let map: OfficeMap
    let characters: [String: OfficeCharacter]
    let tabs: [TerminalTab]
    let frame: Int
    let dark: Bool
    let theme: BackgroundTheme
    let selectedTabId: String?
    let selectedFurnitureId: String?
    var chromeScreenshots: [String: CGImage] = [:]  // tabId → chrome screenshot

    // Sprite cache: keyed by color combination string → CharacterSpriteSet
    private static var spriteCache: [String: CharacterSpriteSet] = [:]

    // Pre-allocated bubble text arrays to avoid per-frame allocation
    private static let greetTexts0 = ["(ᵔᴥᵔ)", "ヾ(＾∇＾)", "(◕‿◕)", "\\(^o^)/"]
    private static let greetTexts1 = ["(＾▽＾)", "(｡◕‿◕｡)", "٩(◕‿◕)۶", "(づ｡◕‿‿◕｡)づ"]
    private static let chatTexts0 = ["(¬‿¬)", "ᕕ(ᐛ)ᕗ", "(•̀ᴗ•́)و", "( ˘▽˘)っ♨"]
    private static let chatTexts1 = ["(≧◡≦)", "ʕ•ᴥ•ʔ", "(ノ◕ヮ◕)ノ*:・゚✧", "٩(♡ε♡)۶"]
    private static let brainTexts0 = ["(°ロ°)☝", "φ(._.)メモメモ", "(⌐■_■)", "ᕦ(ò_óˇ)ᕤ"]
    private static let brainTexts1 = ["(☞ﾟ∀ﾟ)☞", "( •_•)>⌐■-■", "ψ(._. )>", "(╯°□°)╯︵ ┻━┻"]
    private static let coffeeTexts0 = ["☕(◕‿◕)", "(っ˘ω˘c)♨", "( ˘⌣˘)❤☕", "✧(˘⌣˘)☕"]
    private static let coffeeTexts1 = ["(⊃˘▽˘)⊃☕", "☕(⌐■_■)", "(´∀`)♨", "☕✧(◕‿◕✿)"]
    private static let highFiveTexts0 = ["(つ≧▽≦)つ", "ε=ε=(ノ≧∇≦)ノ", "(ﾉ◕ヮ◕)ﾉ*:・゚✧", "( •̀ω•́ )σ"]
    private static let highFiveTexts1 = ["⊂(◉‿◉)つ", "(ノ´ヮ`)ノ*: ・゚✧", "\\(★ω★)/", "(*≧▽≦)ノシ"]

    // Pre-allocated activity reaction arrays to avoid per-frame allocation
    private static let typingReactions = ["⌨️ ᵗᵃᵏ", "✎ ᵗᵃᵏ", "⌨ᵈᵃᵈᵃ", "⚡⌨⚡"]
    private static let readingReactions = ["📖...", "🔍hmm", "👀...", "📄✓"]
    private static let searchingReactions = ["🔎...", "🧐?", "🗂️...", "📂✓"]
    private static let errorReactions = ["(╥_╥)", "╥﹏╥", "(ᗒᗣᗕ)՞", "( ꈨ◞ )"]
    private static let thinkingReactions = ["(·_·)", "🤔...", "φ(._.)", "(ᵕ≀ᵕ)"]
    private static let celebratingReactions = ["🎉✧", "\\(ᵔᵕᵔ)/", "٩(◕‿◕)۶", "★彡"]
    private static let idleReactions = ["(¬_¬)", "(-_-) zzZ", "(˘ω˘)", "( ˙꒳˙ )"]
    private let windowColumns: Set<Int> = [3, 4, 5, 9, 10, 11, 15, 16, 17, 21, 22, 23, 31, 32, 33, 37, 38, 39]
    private var palette: OfficeScenePalette { OfficeScenePalette(theme: theme, dark: dark) }

    // Static background cache: avoids redrawing ~8000 floor/wall draw calls every frame
    private static var cachedBackgroundImage: CGImage?
    private static var cachedBackgroundKey: String = ""
    static func usesStaticBackgroundCache(for type: FurnitureType) -> Bool {
        let cachedTypes: Set<FurnitureType> = [.rug, .bookshelf, .whiteboard, .pictureFrame, .clock]
        return cachedTypes.contains(type)
    }

    // MARK: - Main Render

    func render(context: GraphicsContext, scale: CGFloat, offsetX: CGFloat, offsetY: CGFloat) {
        renderStaticBackground(context: context, scale: scale, offsetX: offsetX, offsetY: offsetY)
        renderDynamicLayers(context: context, scale: scale, offsetX: offsetX, offsetY: offsetY)
    }

    func renderStaticBackground(context: GraphicsContext, scale: CGFloat, offsetX: CGFloat, offsetY: CGFloat) {
        let cacheKey = "\(theme.rawValue)-\(dark)-\(map.cols)-\(map.rows)"

        if cacheKey == Self.cachedBackgroundKey, let cached = Self.cachedBackgroundImage {
            var ctx = context
            ctx.translateBy(x: offsetX, y: offsetY)
            ctx.scaleBy(x: scale, y: scale)
            ctx.draw(
                Image(decorative: cached, scale: 1),
                in: CGRect(x: 0, y: 0,
                           width: CGFloat(map.cols) * 16,
                           height: CGFloat(map.rows) * 16)
            )
            return
        }

        // Cache miss — draw normally into the live context
        var ctx = context
        ctx.translateBy(x: offsetX, y: offsetY)
        ctx.scaleBy(x: scale, y: scale)
        drawBackdrop(ctx)
        drawFloorTiles(ctx)
        drawWindowLight(ctx)
        drawWalls(ctx)
        drawCachedStaticFurniture(ctx)

        // Generate cached CGImage for subsequent frames
        Task { @MainActor in
            Self.generateBackgroundCache(map: map, dark: dark, theme: theme, cacheKey: cacheKey)
        }
    }

    /// Renders the static background into an offscreen CGImage via ImageRenderer.
    @MainActor private static func generateBackgroundCache(map: OfficeMap, dark: Bool, theme: BackgroundTheme, cacheKey: String) {
        let size = CGSize(
            width: CGFloat(map.cols) * 16,
            height: CGFloat(map.rows) * 16
        )
        let snapshotView = Canvas { context, _ in
            let renderer = OfficeSpriteRenderer(
                map: map,
                characters: [:],
                tabs: [],
                frame: 0,
                dark: dark,
                theme: theme,
                selectedTabId: nil,
                selectedFurnitureId: nil
            )
            renderer.drawBackdrop(context)
            renderer.drawFloorTiles(context)
            renderer.drawWindowLight(context)
            renderer.drawWalls(context)
            renderer.drawCachedStaticFurniture(context)
        }
        .frame(width: size.width, height: size.height)

        let imageRenderer = ImageRenderer(content: snapshotView)
        imageRenderer.scale = 1
        if let cgImage = imageRenderer.cgImage {
            cachedBackgroundImage = cgImage
            cachedBackgroundKey = cacheKey
        }
    }

    /// Invalidates the static background cache (call when theme or layout changes).
    static func invalidateBackgroundCache() {
        cachedBackgroundImage = nil
        cachedBackgroundKey = ""
    }

    func renderDynamicLayers(context: GraphicsContext, scale: CGFloat, offsetX: CGFloat, offsetY: CGFloat) {
        var ctx = context
        ctx.translateBy(x: offsetX, y: offsetY)
        ctx.scaleBy(x: scale, y: scale)
        drawZSortedScene(ctx)
        drawOverlays(ctx, viewScale: scale)
    }

    // ═══════════════════════════════════════════════════
    // MARK: - Floor Tiles (Rich Detail)
    // ═══════════════════════════════════════════════════

    private func drawFloorTiles(_ ctx: GraphicsContext) {
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
    private func drawOfficeTile(_ ctx: GraphicsContext, x: CGFloat, y: CGFloat, ts: CGFloat, r: Int, c: Int) {
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
    private func drawPantryTile(_ ctx: GraphicsContext, x: CGFloat, y: CGFloat, ts: CGFloat, r: Int, c: Int) {
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
    private func drawWoodFloor(_ ctx: GraphicsContext, x: CGFloat, y: CGFloat, ts: CGFloat, r: Int, c: Int) {
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
    private func drawCarpetTile(_ ctx: GraphicsContext, x: CGFloat, y: CGFloat, ts: CGFloat, r: Int, c: Int) {
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
    private func drawDoorTile(_ ctx: GraphicsContext, x: CGFloat, y: CGFloat, ts: CGFloat, r: Int, c: Int) {
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

    private func drawBackdrop(_ ctx: GraphicsContext) {
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

    private func drawWindowLight(_ ctx: GraphicsContext) {
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

    private func drawWallWindow(_ ctx: GraphicsContext, x: CGFloat, y: CGFloat, ts: CGFloat) {
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

    private func drawWindowExteriorDetail(_ ctx: GraphicsContext, x: CGFloat, y: CGFloat, ts: CGFloat) {
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

    private func tileAt(col: Int, row: Int) -> TileType {
        guard row >= 0, row < map.rows, col >= 0, col < map.cols else { return .void }
        return map.tiles[row][col]
    }

    private func drawWallCornerAccents(
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

    private func drawWalls(_ ctx: GraphicsContext) {
        let ts: CGFloat = 16

        for r in 0..<map.rows {
            for c in 0..<map.cols {
                guard map.tiles[r][c] == .wall else { continue }
                let x = CGFloat(c) * ts, y = CGFloat(r) * ts
                let isTopOuterWall = r <= 1 && c > 0 && c < map.cols - 1
                let hasWindow = isTopOuterWall && windowColumns.contains(c)

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

    // ═══════════════════════════════════════════════════
    // MARK: - Z-Sorted Scene
    // ═══════════════════════════════════════════════════

    private func drawCachedStaticFurniture(_ ctx: GraphicsContext) {
        for furniture in map.furniture where Self.usesStaticBackgroundCache(for: furniture.type) {
            let fx = CGFloat(furniture.position.col) * 16
            let fy = CGFloat(furniture.position.row) * 16
            let fw = CGFloat(furniture.size.w) * 16
            let fh = CGFloat(furniture.size.h) * 16
            Self.drawDetailedFurniture(ctx, type: furniture.type, x: fx, y: fy, w: fw, h: fh, dark: dark, frame: frame)
        }
    }

    private func drawZSortedScene(_ ctx: GraphicsContext) {
        var drawables: [ZDrawable] = []
        drawables.reserveCapacity(map.furniture.count + characters.count)

        // Furniture
        for f in map.furniture {
            guard !Self.usesStaticBackgroundCache(for: f.type) else { continue }
            let fx = CGFloat(f.position.col) * 16
            let fy = CGFloat(f.position.row) * 16
            let fw = CGFloat(f.size.w) * 16
            let fh = CGFloat(f.size.h) * 16
            let zY = f.zY
            let fType = f.type
            let d = self.dark
            let frm = self.frame

            // 모니터의 경우 연결된 탭의 크롬 스크린샷 확인
            var chromeImg: CGImage? = nil
            if fType == .monitor {
                // 이 모니터의 deskId를 찾고 → 해당 좌석의 탭 → 크롬 스크린샷
                let monId = f.id.replacingOccurrences(of: "mon_", with: "seat_")
                if let seat = map.seats.first(where: { $0.id == monId }),
                   let tabId = seat.assignedTabId {
                    chromeImg = chromeScreenshots[tabId]
                }
            }
            let capturedImg = chromeImg

            drawables.append(ZDrawable(zY: zY) { c in
                Self.drawDetailedFurniture(c, type: fType, x: fx, y: fy, w: fw, h: fh, dark: d, frame: frm)
                // 크롬 스크린샷을 모니터 화면에 오버레이
                if fType == .monitor, let img = capturedImg {
                    let screenX = fx + 2.5
                    let screenY = fy + 1.5
                    let screenW = fw - 5
                    let screenH = fh - 7
                    c.draw(Image(decorative: img, scale: 1),
                           in: CGRect(x: screenX, y: screenY, width: screenW, height: screenH))
                }
            })
        }

        // Characters
        for (_, char) in characters {
            let tab = char.tabId.flatMap { tabId in tabs.first(where: { $0.id == tabId }) }
            let charCopy = char
            let rosterCharacter = CharacterRegistry.shared.character(with: char.rosterCharacterId)
            let workerColor = tab?.workerColor ?? Color(hex: Self.normalizedHex(char.accentColorHex))
            let hashSeed = tab?.id ?? char.rosterCharacterId ?? char.displayName
            let hashVal = hashSeed.hashValue
            let charDir = char.dir
            let charState = char.state
            let charFrame = char.frame
            let d = self.dark

            drawables.append(ZDrawable(zY: char.zY) { c in
                Self.drawCharacterSprite(c, char: charCopy, workerColor: workerColor,
                                         hashVal: hashVal, dir: charDir, state: charState,
                                         frame: charFrame, dark: d, rosterCharacter: rosterCharacter)
            })
        }

        drawables.sort { $0.zY < $1.zY }
        for d in drawables { d.draw(ctx) }
    }

    // ═══════════════════════════════════════════════════
    // MARK: - Detailed Furniture Drawing
    // ═══════════════════════════════════════════════════

    private static func drawDetailedFurniture(_ ctx: GraphicsContext, type: FurnitureType,
                                               x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat,
                                               dark: Bool, frame: Int) {
        drawFurnitureAmbientShadow(ctx, type: type, x: x, y: y, w: w, h: h, dark: dark)
        switch type {
        case .desk:      drawDesk(ctx, x: x, y: y, w: w, h: h, dark: dark)
        case .monitor:   drawMonitor(ctx, x: x, y: y, w: w, h: h, dark: dark, frame: frame)
        case .chair:     drawChair(ctx, x: x, y: y, w: w, h: h, dark: dark)
        case .plant:     drawPlant(ctx, x: x, y: y, w: w, h: h, dark: dark, frame: frame)
        case .coffeeMachine: drawCoffeeMachine(ctx, x: x, y: y, w: w, h: h, dark: dark, frame: frame)
        case .sofa:      drawSofa(ctx, x: x, y: y, w: w, h: h, dark: dark)
        case .whiteboard: drawWhiteboard(ctx, x: x, y: y, w: w, h: h, dark: dark)
        case .bookshelf: drawBookshelf(ctx, x: x, y: y, w: w, h: h, dark: dark)
        case .roundTable: drawRoundTable(ctx, x: x, y: y, w: w, h: h, dark: dark)
        case .waterCooler: drawWaterCooler(ctx, x: x, y: y, w: w, h: h, dark: dark, frame: frame)
        case .printer:   drawPrinter(ctx, x: x, y: y, w: w, h: h, dark: dark)
        case .trashBin:  drawTrashBin(ctx, x: x, y: y, w: w, h: h, dark: dark)
        case .lamp:      drawLamp(ctx, x: x, y: y, w: w, h: h, dark: dark, frame: frame)
        case .rug:       drawRug(ctx, x: x, y: y, w: w, h: h, dark: dark)
        case .pictureFrame: drawPictureFrame(ctx, x: x, y: y, w: w, h: h, dark: dark)
        case .clock:     drawClock(ctx, x: x, y: y, w: w, h: h, dark: dark, frame: frame)
        }
    }

    private static func drawFurnitureAmbientShadow(
        _ ctx: GraphicsContext,
        type: FurnitureType,
        x: CGFloat,
        y: CGFloat,
        w: CGFloat,
        h: CGFloat,
        dark: Bool
    ) {
        let alphaBase = dark ? 0.15 : 0.08

        switch type {
        case .pictureFrame, .clock, .whiteboard:
            ctx.fill(
                Path(roundedRect: CGRect(x: x + 1.2, y: y + 1.3, width: w - 1.8, height: h - 1.5), cornerRadius: 1),
                with: .color(Color.black.opacity(alphaBase * 0.95))
            )
        case .rug:
            ctx.fill(
                Path(roundedRect: CGRect(x: x + 0.8, y: y + 1.2, width: w - 1.6, height: h - 1.8), cornerRadius: 1.6),
                with: .color(Color.black.opacity(alphaBase * 0.35))
            )
        case .monitor:
            ctx.fill(
                Path(ellipseIn: CGRect(x: x + w * 0.18, y: y + h - 3.2, width: w * 0.64, height: 2.4)),
                with: .color(Color.black.opacity(alphaBase * 0.9))
            )
        case .desk, .sofa, .bookshelf, .roundTable:
            ctx.fill(
                Path(ellipseIn: CGRect(x: x + 2, y: y + h - 2.8, width: w - 4, height: max(3.5, h * 0.18))),
                with: .color(Color.black.opacity(alphaBase * 1.15))
            )
            ctx.fill(
                Path(CGRect(x: x + 1.2, y: y + 1.2, width: w - 2.4, height: max(3, h - 6))),
                with: .color(Color.black.opacity(alphaBase * 0.16))
            )
        case .chair, .plant, .coffeeMachine, .waterCooler, .printer, .trashBin, .lamp:
            ctx.fill(
                Path(ellipseIn: CGRect(x: x + w * 0.12, y: y + h - 2.4, width: w * 0.76, height: max(2.4, h * 0.14))),
                with: .color(Color.black.opacity(alphaBase))
            )
        }
    }

    // ── Desk: thick wood top with grain, front panel with drawer lines, legs ──
    private static func drawDesk(_ ctx: GraphicsContext, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, dark: Bool) {
        // Shadow under desk
        ctx.fill(Path(CGRect(x: x + 2, y: y + h - 2, width: w - 4, height: 2.5)),
                 with: .color(Color.black.opacity(dark ? 0.15 : 0.08)))

        // Legs
        let legHex = dark ? "5A4528" : "7A6548"
        for lx in [x + 2, x + 3, x + w - 5, x + w - 4] {
            ctx.fill(Path(CGRect(x: lx, y: y + h - 4, width: 1.5, height: 4)),
                     with: .color(Color(hex: legHex)))
        }

        // Front panel (darker wood)
        let frontHex = dark ? "5A4830" : "7A6548"
        ctx.fill(Path(CGRect(x: x + 1, y: y + 4, width: w - 2, height: h - 7)),
                 with: .color(Color(hex: frontHex)))

        // Drawer lines on front panel
        let drawerLine = dark ? "4A3C28" : "6A5838"
        let midX = x + w / 2
        // Horizontal drawer divider
        ctx.fill(Path(CGRect(x: x + 4, y: y + 7, width: w - 8, height: 0.5)),
                 with: .color(Color(hex: drawerLine).opacity(0.6)))
        ctx.fill(Path(CGRect(x: x + 4, y: y + 10, width: w - 8, height: 0.5)),
                 with: .color(Color(hex: drawerLine).opacity(0.6)))
        // Vertical drawer divider
        ctx.fill(Path(CGRect(x: midX - 0.25, y: y + 4, width: 0.5, height: h - 7)),
                 with: .color(Color(hex: drawerLine).opacity(0.5)))
        // Drawer handles (small dots)
        let handleHex = dark ? "706050" : "B0A080"
        ctx.fill(Path(ellipseIn: CGRect(x: midX - w * 0.2, y: y + 8, width: 2, height: 1)),
                 with: .color(Color(hex: handleHex)))
        ctx.fill(Path(ellipseIn: CGRect(x: midX + w * 0.15, y: y + 8, width: 2, height: 1)),
                 with: .color(Color(hex: handleHex)))

        // Table top (thick slab with grain)
        let topHex = dark ? "6A5838" : "A08B68"
        let topHi = dark ? "7A6848" : "B89C78"
        let topLo = dark ? "5A4828" : "8B7355"
        ctx.fill(Path(CGRect(x: x, y: y, width: w, height: 4.5)),
                 with: .color(Color(hex: topHex)))
        // Top surface highlight
        ctx.fill(Path(CGRect(x: x, y: y, width: w, height: 1.2)),
                 with: .color(Color(hex: topHi).opacity(0.6)))
        // Top front edge (darker)
        ctx.fill(Path(CGRect(x: x, y: y + 3.5, width: w, height: 1)),
                 with: .color(Color(hex: topLo).opacity(0.5)))

        // Wood grain on top
        let grainHex = dark ? "5E4C30" : "9A8058"
        for i in stride(from: 3, to: Int(w) - 3, by: 7) {
            ctx.fill(Path(CGRect(x: x + CGFloat(i), y: y + 1, width: 4, height: 0.3)),
                     with: .color(Color(hex: grainHex).opacity(0.3)))
        }
    }

    // ── Monitor: screen bezel, visible code content, stand ──
    private static func drawMonitor(_ ctx: GraphicsContext, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, dark: Bool, frame: Int) {
        // Stand base
        let standHex = dark ? "3A3E4A" : "606878"
        ctx.fill(Path(CGRect(x: x + w * 0.25, y: y + h - 3, width: w * 0.5, height: 2.5)),
                 with: .color(Color(hex: standHex)))
        // Stand neck
        ctx.fill(Path(CGRect(x: x + w * 0.4, y: y + h - 5, width: w * 0.2, height: 3)),
                 with: .color(Color(hex: standHex)))

        // Monitor bezel (outer frame)
        let bezelHex = dark ? "2A2E38" : "3A3E4A"
        ctx.fill(Path(roundedRect: CGRect(x: x + 1, y: y, width: w - 2, height: h - 4), cornerRadius: 1),
                 with: .color(Color(hex: bezelHex)))

        // Screen area
        let screenBg = dark ? "0E1420" : "1A2030"
        ctx.fill(Path(CGRect(x: x + 2.5, y: y + 1.5, width: w - 5, height: h - 7)),
                 with: .color(Color(hex: screenBg)))

        // Code lines on screen (colored)
        let screenW = w - 7
        let lineY0 = y + 3
        let lineH: CGFloat = 0.8
        let lineGap: CGFloat = 1.4
        let codeColors = ["4080D0", "40A060", "D0A040", "A060C0", "60B0B0", "D06040"]

        for i in 0..<5 {
            let ly = lineY0 + CGFloat(i) * lineGap
            if ly > y + h - 8 { break }
            let cHex = codeColors[i % codeColors.count]
            let lineLen = CGFloat(3 + (i * 7 + 5) % Int(max(1, screenW - 2)))
            let indent = CGFloat((i * 3) % 4)
            ctx.fill(Path(CGRect(x: x + 3.5 + indent, y: ly, width: min(lineLen, screenW - indent - 1), height: lineH)),
                     with: .color(Color(hex: cHex).opacity(0.7)))
        }

        // Cursor blink
        if frame % 20 < 12 {
            let cursorY = lineY0 + 2 * lineGap
            ctx.fill(Path(CGRect(x: x + 6, y: cursorY, width: 0.6, height: lineH)),
                     with: .color(Color(hex: "60D060").opacity(0.8)))
        }

        // Bezel bottom logo dot
        ctx.fill(Path(ellipseIn: CGRect(x: x + w / 2 - 0.5, y: y + h - 5.5, width: 1, height: 1)),
                 with: .color(Color(hex: dark ? "4A4E58" : "5A5E68").opacity(0.5)))

        // Screen reflection highlight
        ctx.fill(Path(CGRect(x: x + 3, y: y + 2, width: 2, height: 0.4)),
                 with: .color(Color.white.opacity(0.06)))
    }

    // ── Chair: visible cushion, back, armrests, wheels ──
    private static func drawChair(_ ctx: GraphicsContext, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, dark: Bool) {
        // Wheel shadow
        ctx.fill(Path(ellipseIn: CGRect(x: x + 2, y: y + h - 2, width: w - 4, height: 2)),
                 with: .color(Color.black.opacity(dark ? 0.12 : 0.06)))

        // Wheels (5 casters)
        let wheelHex = dark ? "2A2A3A" : "50505A"
        let wheelPositions: [CGFloat] = [3, 5.5, 8, 10.5, 13]
        for wx in wheelPositions.prefix(min(5, Int(w / 3))) {
            if wx < w - 1 {
                ctx.fill(Path(ellipseIn: CGRect(x: x + wx - 0.5, y: y + h - 2.5, width: 1.5, height: 1.5)),
                         with: .color(Color(hex: wheelHex)))
            }
        }

        // Center post
        let postHex = dark ? "3A3A4A" : "60606A"
        ctx.fill(Path(CGRect(x: x + w / 2 - 0.8, y: y + h - 5, width: 1.6, height: 3)),
                 with: .color(Color(hex: postHex)))

        // Seat cushion
        let cushionHex = dark ? "4A4A5A" : "6A6A7A"
        let cushionHi = dark ? "5A5A6A" : "7A7A8A"
        ctx.fill(Path(roundedRect: CGRect(x: x + 2.5, y: y + 5, width: w - 5, height: h - 9), cornerRadius: 1.5),
                 with: .color(Color(hex: cushionHex)))
        // Cushion highlight
        ctx.fill(Path(CGRect(x: x + 3, y: y + 5, width: w - 6, height: 1.5)),
                 with: .color(Color(hex: cushionHi).opacity(0.5)))
        // Cushion stitch line
        let stitchHex = dark ? "3E3E4E" : "5E5E6E"
        ctx.fill(Path(CGRect(x: x + w / 2 - 0.2, y: y + 6, width: 0.4, height: h - 12)),
                 with: .color(Color(hex: stitchHex).opacity(0.3)))

        // Backrest
        let backHex = dark ? "404050" : "585868"
        ctx.fill(Path(roundedRect: CGRect(x: x + 3, y: y + 1, width: w - 6, height: 5), cornerRadius: 1),
                 with: .color(Color(hex: backHex)))
        // Backrest highlight
        ctx.fill(Path(CGRect(x: x + 3.5, y: y + 1, width: w - 7, height: 1)),
                 with: .color(Color(hex: cushionHi).opacity(0.4)))

        // Armrests
        let armHex = dark ? "3A3A4A" : "50505A"
        ctx.fill(Path(CGRect(x: x + 1, y: y + 5, width: 2, height: 1.2)),
                 with: .color(Color(hex: armHex)))
        ctx.fill(Path(CGRect(x: x + w - 3, y: y + 5, width: 2, height: 1.2)),
                 with: .color(Color(hex: armHex)))
        // Armrest posts
        ctx.fill(Path(CGRect(x: x + 1.5, y: y + 6, width: 1, height: 3)),
                 with: .color(Color(hex: armHex).opacity(0.7)))
        ctx.fill(Path(CGRect(x: x + w - 2.5, y: y + 6, width: 1, height: 3)),
                 with: .color(Color(hex: armHex).opacity(0.7)))
    }

    // ── Plant: multiple leaves, detailed pot with rim, soil ──
    private static func drawPlant(_ ctx: GraphicsContext, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, dark: Bool, frame: Int) {
        let cx = x + w / 2
        // Pot shadow
        ctx.fill(Path(ellipseIn: CGRect(x: cx - 5, y: y + h - 2, width: 10, height: 2.5)),
                 with: .color(Color.black.opacity(dark ? 0.12 : 0.06)))

        // Pot body (terracotta, slightly tapered)
        let potBase = dark ? "8A5840" : "B08060"
        let potHi = dark ? "9A6850" : "C09070"
        let potLo = dark ? "7A4830" : "A07050"
        // Main pot
        ctx.fill(Path(CGRect(x: x + 3, y: y + h * 0.55, width: w - 6, height: h * 0.38)),
                 with: .color(Color(hex: potBase)))
        // Pot rim
        ctx.fill(Path(CGRect(x: x + 2, y: y + h * 0.52, width: w - 4, height: 2)),
                 with: .color(Color(hex: potHi)))
        // Rim highlight
        ctx.fill(Path(CGRect(x: x + 2, y: y + h * 0.52, width: w - 4, height: 0.6)),
                 with: .color(Color(hex: dark ? "AA7858" : "D0A080").opacity(0.5)))
        // Pot bottom (narrower)
        ctx.fill(Path(CGRect(x: x + 4, y: y + h * 0.88, width: w - 8, height: h * 0.08)),
                 with: .color(Color(hex: potLo)))
        // Pot highlight stripe
        ctx.fill(Path(CGRect(x: x + 4, y: y + h * 0.65, width: 1, height: h * 0.2)),
                 with: .color(Color(hex: potHi).opacity(0.3)))

        // Soil
        let soilHex = dark ? "3A2A1A" : "604830"
        ctx.fill(Path(ellipseIn: CGRect(x: x + 3.5, y: y + h * 0.50, width: w - 7, height: 3)),
                 with: .color(Color(hex: soilHex)))

        // Stem
        let stemHex = dark ? "2A5028" : "408040"
        ctx.fill(Path(CGRect(x: cx - 0.6, y: y + 3.5, width: 1.2, height: h * 0.45)),
                 with: .color(Color(hex: stemHex)))

        // Leaves (multiple, varied angles using small rects)
        let leafDark = dark ? "2A6028" : "408040"
        let leafBright = dark ? "389038" : "50A850"
        let leafMid = dark ? "308030" : "489048"

        // Main top cluster
        let sway = sin(Double(frame) * 0.06) * 0.5

        // Leaf 1: top center
        ctx.fill(Path(ellipseIn: CGRect(x: cx - 3 + sway, y: y, width: 6, height: 4)),
                 with: .color(Color(hex: leafBright)))
        // Leaf 2: left
        ctx.fill(Path(ellipseIn: CGRect(x: cx - 6 - sway * 0.5, y: y + 2, width: 5, height: 3.5)),
                 with: .color(Color(hex: leafDark)))
        // Leaf 3: right
        ctx.fill(Path(ellipseIn: CGRect(x: cx + 1.5 + sway * 0.5, y: y + 1.5, width: 5.5, height: 3.5)),
                 with: .color(Color(hex: leafMid)))
        // Leaf 4: bottom left
        ctx.fill(Path(ellipseIn: CGRect(x: cx - 5, y: y + 4, width: 4, height: 3)),
                 with: .color(Color(hex: leafMid)))
        // Leaf 5: bottom right
        ctx.fill(Path(ellipseIn: CGRect(x: cx + 2, y: y + 4, width: 4, height: 3)),
                 with: .color(Color(hex: leafDark)))

        // Leaf vein highlights
        ctx.fill(Path(CGRect(x: cx - 0.2, y: y + 0.5, width: 0.4, height: 3)),
                 with: .color(Color(hex: leafBright).opacity(0.4)))
    }

    // ── Coffee Machine: body, buttons, display, drip tray, cup ──
    private static func drawCoffeeMachine(_ ctx: GraphicsContext, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, dark: Bool, frame: Int) {
        // Shadow
        ctx.fill(Path(ellipseIn: CGRect(x: x + 2, y: y + h - 2, width: w - 4, height: 2.5)),
                 with: .color(Color.black.opacity(dark ? 0.12 : 0.06)))

        // Main body
        let bodyHex = dark ? "505868" : "707880"
        ctx.fill(Path(roundedRect: CGRect(x: x + 2, y: y + 1, width: w - 4, height: h - 3), cornerRadius: 1),
                 with: .color(Color(hex: bodyHex)))

        // Top cap
        let capHex = dark ? "606870" : "808890"
        ctx.fill(Path(CGRect(x: x + 1.5, y: y, width: w - 3, height: 2.5)),
                 with: .color(Color(hex: capHex)))
        ctx.fill(Path(CGRect(x: x + 1.5, y: y, width: w - 3, height: 0.8)),
                 with: .color(Color(hex: dark ? "707880" : "909CA0").opacity(0.5)))

        // Display panel
        let dispBg = dark ? "1A2028" : "A0B8C0"
        ctx.fill(Path(roundedRect: CGRect(x: x + 4, y: y + 3, width: w - 8, height: 3.5), cornerRadius: 0.5),
                 with: .color(Color(hex: dispBg)))
        // Display text
        let dispText = dark ? "60A0C0" : "205060"
        ctx.fill(Path(CGRect(x: x + 5, y: y + 4, width: 3, height: 0.6)),
                 with: .color(Color(hex: dispText).opacity(0.7)))
        ctx.fill(Path(CGRect(x: x + 5, y: y + 5.2, width: 2, height: 0.6)),
                 with: .color(Color(hex: dispText).opacity(0.5)))

        // Buttons
        let btnHex = dark ? "404850" : "606868"
        ctx.fill(Path(ellipseIn: CGRect(x: x + 4, y: y + 7.5, width: 2, height: 2)),
                 with: .color(Color(hex: btnHex)))
        ctx.fill(Path(ellipseIn: CGRect(x: x + 7, y: y + 7.5, width: 2, height: 2)),
                 with: .color(Color(hex: btnHex)))
        // LED indicator
        let ledOn = frame % 40 < 30
        ctx.fill(Path(ellipseIn: CGRect(x: x + 10, y: y + 8, width: 1.2, height: 1.2)),
                 with: .color(Color(hex: ledOn ? "40C040" : "204020")))

        // Drip area (recessed)
        let dripHex = dark ? "303840" : "505860"
        ctx.fill(Path(CGRect(x: x + 4, y: y + h * 0.6, width: w - 8, height: h * 0.28)),
                 with: .color(Color(hex: dripHex)))

        // Cup
        let cupHex = dark ? "D8D4C8" : "F0ECE0"
        let cupX = x + w / 2 - 2
        let cupY = y + h * 0.62
        ctx.fill(Path(CGRect(x: cupX, y: cupY, width: 4, height: 3.5)),
                 with: .color(Color(hex: cupHex)))
        // Cup handle
        ctx.fill(Path(CGRect(x: cupX + 4, y: cupY + 0.5, width: 1.2, height: 2.5)),
                 with: .color(Color(hex: cupHex)))
        // Coffee surface
        ctx.fill(Path(ellipseIn: CGRect(x: cupX + 0.3, y: cupY + 0.3, width: 3.4, height: 1.2)),
                 with: .color(Color(hex: dark ? "4A3020" : "6A4030").opacity(0.7)))

        // Steam
        if frame % 30 < 20 {
            let steamAlpha = 0.15 + sin(Double(frame) * 0.15) * 0.05
            ctx.fill(Path(CGRect(x: cupX + 1, y: cupY - 1.5, width: 0.5, height: 1.2)),
                     with: .color(Color.white.opacity(steamAlpha)))
            ctx.fill(Path(CGRect(x: cupX + 2.5, y: cupY - 2, width: 0.5, height: 1)),
                     with: .color(Color.white.opacity(steamAlpha * 0.7)))
        }

        // Drip tray grid
        let gridHex = dark ? "3A4248" : "585E68"
        for gx in stride(from: 5, to: Int(w) - 5, by: 2) {
            ctx.fill(Path(CGRect(x: x + CGFloat(gx), y: y + h - 3, width: 0.4, height: 1.5)),
                     with: .color(Color(hex: gridHex).opacity(0.3)))
        }
    }

    // ── Sofa: plush cushions with highlights, armrests, legs ──
    private static func drawSofa(_ ctx: GraphicsContext, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, dark: Bool) {
        // Shadow
        ctx.fill(Path(ellipseIn: CGRect(x: x + 4, y: y + h - 3, width: w - 8, height: 4)),
                 with: .color(Color.black.opacity(dark ? 0.12 : 0.06)))

        // Legs
        let legHex = dark ? "3A2850" : "5A4070"
        for lx in [x + 5, x + w - 7] {
            ctx.fill(Path(CGRect(x: lx, y: y + h - 4, width: 2, height: 4)),
                     with: .color(Color(hex: legHex)))
        }

        let sofaBase = dark ? "4A3868" : "6A5080"
        let armHex = dark ? "3A2858" : "5A4070"
        let cushionHex = dark ? "5A4878" : "7A6090"
        let cushionHi = dark ? "6A5888" : "8A70A0"

        // Backrest
        ctx.fill(Path(roundedRect: CGRect(x: x + 3, y: y + 1, width: w - 6, height: h * 0.35), cornerRadius: 2),
                 with: .color(Color(hex: sofaBase)))
        // Backrest highlight
        ctx.fill(Path(CGRect(x: x + 5, y: y + 1.5, width: w - 10, height: 1.5)),
                 with: .color(Color(hex: cushionHi).opacity(0.35)))

        // Armrests
        ctx.fill(Path(roundedRect: CGRect(x: x, y: y + 2, width: 5, height: h * 0.65), cornerRadius: 1.5),
                 with: .color(Color(hex: armHex)))
        ctx.fill(Path(roundedRect: CGRect(x: x + w - 5, y: y + 2, width: 5, height: h * 0.65), cornerRadius: 1.5),
                 with: .color(Color(hex: armHex)))
        // Armrest highlights
        ctx.fill(Path(CGRect(x: x + 0.5, y: y + 2, width: 4, height: 1)),
                 with: .color(Color(hex: cushionHi).opacity(0.25)))
        ctx.fill(Path(CGRect(x: x + w - 4.5, y: y + 2, width: 4, height: 1)),
                 with: .color(Color(hex: cushionHi).opacity(0.25)))

        // Seat cushions (2 or 3 segments)
        let seatY = y + h * 0.35
        let seatH = h * 0.45
        let cushionW = (w - 14) / 2
        for i in 0..<2 {
            let cx = x + 6 + CGFloat(i) * (cushionW + 2)
            ctx.fill(Path(roundedRect: CGRect(x: cx, y: seatY, width: cushionW, height: seatH), cornerRadius: 2),
                     with: .color(Color(hex: cushionHex)))
            // Cushion top highlight
            ctx.fill(Path(CGRect(x: cx + 1, y: seatY + 1, width: cushionW - 2, height: 2)),
                     with: .color(Color(hex: cushionHi).opacity(0.4)))
            // Cushion center dimple
            ctx.fill(Path(ellipseIn: CGRect(x: cx + cushionW / 2 - 2, y: seatY + seatH * 0.3, width: 4, height: 2)),
                     with: .color(Color(hex: sofaBase).opacity(0.25)))
        }
    }

    // ── Whiteboard: frame, white surface, markers, content ──
    private static func drawWhiteboard(_ ctx: GraphicsContext, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, dark: Bool) {
        // Shadow behind
        ctx.fill(Path(CGRect(x: x + 1, y: y + 1, width: w - 1, height: h - 1)),
                 with: .color(Color.black.opacity(dark ? 0.1 : 0.05)))

        // Frame (aluminum)
        let frameHex = dark ? "808898" : "A0A0B0"
        ctx.fill(Path(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerRadius: 0.5),
                 with: .color(Color(hex: frameHex)))

        // White board surface
        let boardHex = dark ? "D0D0D8" : "F0F0F4"
        ctx.fill(Path(CGRect(x: x + 1.5, y: y + 1.5, width: w - 3, height: h - 3)),
                 with: .color(Color(hex: boardHex)))

        // Content: lines and diagrams
        let lineColors = ["4060B0", "40A060", "C04040", "D09020"]
        let boardW = w - 6
        // Title line
        ctx.fill(Path(CGRect(x: x + 3, y: y + 3, width: min(boardW * 0.4, 14), height: 0.8)),
                 with: .color(Color(hex: lineColors[0]).opacity(0.7)))
        // Bullet points
        for i in 0..<3 {
            let ly = y + 5.5 + CGFloat(i) * 2.5
            if ly > y + h - 4 { break }
            // Bullet dot
            ctx.fill(Path(ellipseIn: CGRect(x: x + 3, y: ly, width: 1, height: 1)),
                     with: .color(Color(hex: lineColors[i % lineColors.count]).opacity(0.6)))
            // Text line
            let lineLen = CGFloat(8 + (i * 5) % Int(max(1, boardW - 8)))
            ctx.fill(Path(CGRect(x: x + 5, y: ly + 0.2, width: min(lineLen, boardW - 5), height: 0.6)),
                     with: .color(Color(hex: lineColors[i % lineColors.count]).opacity(0.5)))
        }

        // Small box diagram in corner
        if w > 30 {
            let diagX = x + w - 14
            let diagY = y + 4
            let diagHex = "C04040"
            ctx.stroke(Path(CGRect(x: diagX, y: diagY, width: 8, height: 5)),
                       with: .color(Color(hex: diagHex).opacity(0.5)), lineWidth: 0.5)
            ctx.stroke(Path(CGRect(x: diagX + 2, y: diagY + 6, width: 6, height: 3)),
                       with: .color(Color(hex: "40A060").opacity(0.5)), lineWidth: 0.5)
        }

        // Marker tray at bottom
        let trayHex = dark ? "707880" : "909098"
        ctx.fill(Path(CGRect(x: x + 2, y: y + h - 2.5, width: w - 4, height: 1.5)),
                 with: .color(Color(hex: trayHex)))
        // Markers on tray
        let markerColors = ["2040B0", "B02020", "20A040"]
        for (i, mc) in markerColors.enumerated() {
            ctx.fill(Path(CGRect(x: x + 4 + CGFloat(i) * 3, y: y + h - 2.8, width: 2, height: 1.2)),
                     with: .color(Color(hex: mc).opacity(0.8)))
        }
    }

    // ── Bookshelf: frame, shelves, individual books with colored spines ──
    private static func drawBookshelf(_ ctx: GraphicsContext, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, dark: Bool) {
        // Shadow
        ctx.fill(Path(CGRect(x: x + 1, y: y + h - 1, width: w - 1, height: 2)),
                 with: .color(Color.black.opacity(dark ? 0.12 : 0.06)))

        // Frame (dark wood)
        let frameHex = dark ? "4A3820" : "6A5030"
        let frameHi = dark ? "5A4830" : "7A6040"
        ctx.fill(Path(CGRect(x: x, y: y, width: w, height: h)),
                 with: .color(Color(hex: frameHex)))

        // Frame edges
        ctx.fill(Path(CGRect(x: x, y: y, width: w, height: 1)),
                 with: .color(Color(hex: frameHi).opacity(0.6)))
        ctx.fill(Path(CGRect(x: x, y: y, width: 1.2, height: h)),
                 with: .color(Color(hex: frameHi).opacity(0.3)))
        ctx.fill(Path(CGRect(x: x + w - 1.2, y: y, width: 1.2, height: h)),
                 with: .color(Color(hex: dark ? "3A2818" : "5A4028").opacity(0.4)))

        // Back panel (dark recess)
        let backHex = dark ? "2A1E14" : "5A4428"
        ctx.fill(Path(CGRect(x: x + 1.5, y: y + 1, width: w - 3, height: h - 2)),
                 with: .color(Color(hex: backHex)))

        // Shelves
        let shelfHex = dark ? "5A4830" : "7A6040"
        let shelfPositions = [y, y + h * 0.48, y + h - 1]
        for sy in shelfPositions {
            ctx.fill(Path(CGRect(x: x, y: sy, width: w, height: 1.2)),
                     with: .color(Color(hex: shelfHex)))
            // Shelf edge highlight
            ctx.fill(Path(CGRect(x: x + 1, y: sy, width: w - 2, height: 0.4)),
                     with: .color(Color(hex: frameHi).opacity(0.4)))
        }

        // Books on upper shelf
        let bookColors1 = ["C04040", "4060C0", "40A040", "C0A040", "8040C0", "C06040", "40A0C0"]
        let usableW = w - 4
        let bookW: CGFloat = max(1.8, usableW / 7)
        let shelfHeight1 = h * 0.48 - 2
        for i in 0..<min(7, Int(usableW / bookW)) {
            let bx = x + 2 + CGFloat(i) * bookW
            let bh = shelfHeight1 - CGFloat(i % 3)
            let by = y + 1.2 + (shelfHeight1 - bh)
            let bColor = bookColors1[i % bookColors1.count]
            ctx.fill(Path(CGRect(x: bx, y: by, width: bookW - 0.5, height: bh)),
                     with: .color(Color(hex: bColor)))
            // Spine line
            ctx.fill(Path(CGRect(x: bx + bookW * 0.4, y: by + 1, width: 0.3, height: bh - 2)),
                     with: .color(Color.white.opacity(0.15)))
            // Top edge highlight
            ctx.fill(Path(CGRect(x: bx, y: by, width: bookW - 0.5, height: 0.4)),
                     with: .color(Color.white.opacity(0.1)))
        }

        // Books on lower shelf
        let bookColors2 = ["40A0C0", "C040A0", "A0C040", "6060C0", "C08040"]
        let shelfTop2 = y + h * 0.48 + 1.5
        let shelfHeight2 = h - h * 0.48 - 3
        for i in 0..<min(5, Int(usableW / (bookW * 1.2))) {
            let bx = x + 2.5 + CGFloat(i) * bookW * 1.15
            let bh = shelfHeight2 - CGFloat((i + 2) % 3)
            let by = shelfTop2 + (shelfHeight2 - bh)
            let bColor = bookColors2[i % bookColors2.count]
            ctx.fill(Path(CGRect(x: bx, y: by, width: bookW * 1.1 - 0.5, height: bh)),
                     with: .color(Color(hex: bColor)))
            // Spine detail
            ctx.fill(Path(CGRect(x: bx + 0.5, y: by + bh * 0.3, width: bookW * 0.6, height: 0.3)),
                     with: .color(Color.white.opacity(0.12)))
        }
    }

    // ── Round Table ──
    private static func drawRoundTable(_ ctx: GraphicsContext, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, dark: Bool) {
        // Shadow
        ctx.fill(Path(ellipseIn: CGRect(x: x + 1, y: y + h - 3, width: w - 2, height: 4)),
                 with: .color(Color.black.opacity(dark ? 0.12 : 0.06)))

        // Leg
        let legHex = dark ? "2A2010" : "8A7050"
        ctx.fill(Path(CGRect(x: x + w / 2 - 1, y: y + h * 0.6, width: 2, height: h * 0.35)),
                 with: .color(Color(hex: legHex)))

        // Table top (ellipse with bevel)
        let topHex = dark ? "3A3020" : "C0A878"
        let topHi = dark ? "4A4030" : "D0B888"
        let topLo = dark ? "2A2010" : "A08860"
        ctx.fill(Path(ellipseIn: CGRect(x: x + 1.5, y: y + 1.5, width: w - 3, height: h * 0.55)),
                 with: .color(Color(hex: topHex)))
        // Top highlight
        ctx.fill(Path(ellipseIn: CGRect(x: x + 3, y: y + 2, width: w - 6, height: h * 0.3)),
                 with: .color(Color(hex: topHi).opacity(0.4)))
        // Edge shadow
        ctx.stroke(Path(ellipseIn: CGRect(x: x + 1.5, y: y + 1.5, width: w - 3, height: h * 0.55)),
                   with: .color(Color(hex: topLo).opacity(0.5)), lineWidth: 0.6)
    }

    // ── Water Cooler ──
    private static func drawWaterCooler(_ ctx: GraphicsContext, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, dark: Bool, frame: Int) {
        // Shadow
        ctx.fill(Path(ellipseIn: CGRect(x: x + 3, y: y + h - 2, width: w - 6, height: 2.5)),
                 with: .color(Color.black.opacity(dark ? 0.12 : 0.06)))

        // Base stand
        let standHex = dark ? "4A5060" : "8A9098"
        ctx.fill(Path(CGRect(x: x + 3, y: y + h * 0.4, width: w - 6, height: h * 0.55)),
                 with: .color(Color(hex: standHex)))

        // Body
        let bodyHex = dark ? "5A6470" : "C0C8D0"
        ctx.fill(Path(roundedRect: CGRect(x: x + 3.5, y: y + h * 0.2, width: w - 7, height: h * 0.55), cornerRadius: 1),
                 with: .color(Color(hex: bodyHex)))

        // Water bottle (top)
        let waterHex = "80C0E0"
        ctx.fill(Path(roundedRect: CGRect(x: x + 4, y: y, width: w - 8, height: h * 0.25), cornerRadius: 1),
                 with: .color(Color(hex: waterHex).opacity(0.6)))
        // Water shimmer
        let shimmer = 0.2 + sin(Double(frame) * 0.08) * 0.1
        ctx.fill(Path(CGRect(x: x + 5, y: y + 1, width: 2, height: h * 0.1)),
                 with: .color(Color.white.opacity(shimmer)))

        // Spout buttons
        let btnRed = "D04040"
        let btnBlue = "4060C0"
        ctx.fill(Path(ellipseIn: CGRect(x: x + 4.5, y: y + h * 0.45, width: 2, height: 2)),
                 with: .color(Color(hex: btnRed).opacity(0.8)))
        ctx.fill(Path(ellipseIn: CGRect(x: x + w - 6.5, y: y + h * 0.45, width: 2, height: 2)),
                 with: .color(Color(hex: btnBlue).opacity(0.8)))

        // Drip tray
        let trayHex = dark ? "3A4048" : "707880"
        ctx.fill(Path(CGRect(x: x + 3, y: y + h * 0.78, width: w - 6, height: 1.5)),
                 with: .color(Color(hex: trayHex)))
    }

    // ── Printer ──
    private static func drawPrinter(_ ctx: GraphicsContext, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, dark: Bool) {
        // Shadow
        ctx.fill(Path(CGRect(x: x + 1, y: y + h - 1.5, width: w - 2, height: 2)),
                 with: .color(Color.black.opacity(dark ? 0.10 : 0.05)))

        // Body
        let bodyHex = dark ? "3A3E4A" : "C0C4CC"
        let bodyHi = dark ? "4A4E5A" : "D0D4DC"
        ctx.fill(Path(roundedRect: CGRect(x: x + 1, y: y + 2, width: w - 2, height: h - 4), cornerRadius: 1),
                 with: .color(Color(hex: bodyHex)))
        // Top highlight
        ctx.fill(Path(CGRect(x: x + 1, y: y + 2, width: w - 2, height: 1.5)),
                 with: .color(Color(hex: bodyHi).opacity(0.5)))

        // Paper feed slot
        let slotHex = dark ? "1A1E28" : "E0E4EC"
        ctx.fill(Path(CGRect(x: x + 3, y: y + 3.5, width: w - 6, height: 3)),
                 with: .color(Color(hex: slotHex)))
        // Paper sticking out
        ctx.fill(Path(CGRect(x: x + 4, y: y + 1, width: w - 8, height: 3)),
                 with: .color(Color.white.opacity(dark ? 0.6 : 0.8)))
        // Text on paper
        ctx.fill(Path(CGRect(x: x + 5, y: y + 1.5, width: 4, height: 0.4)),
                 with: .color(Color(hex: "3A3A3A").opacity(0.3)))
        ctx.fill(Path(CGRect(x: x + 5, y: y + 2.3, width: 3, height: 0.4)),
                 with: .color(Color(hex: "3A3A3A").opacity(0.2)))

        // Status LEDs
        ctx.fill(Path(ellipseIn: CGRect(x: x + w - 5, y: y + h - 4, width: 1.2, height: 1.2)),
                 with: .color(Color(hex: "40C040")))
        ctx.fill(Path(ellipseIn: CGRect(x: x + w - 3.5, y: y + h - 4, width: 1.2, height: 1.2)),
                 with: .color(Color(hex: dark ? "303840" : "808890")))

        // Output tray
        let trayHex = dark ? "2A2E38" : "B0B4BC"
        ctx.fill(Path(CGRect(x: x + 2, y: y + h - 3, width: w - 4, height: 1.5)),
                 with: .color(Color(hex: trayHex)))
    }

    // ── Trash Bin ──
    private static func drawTrashBin(_ ctx: GraphicsContext, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, dark: Bool) {
        // Shadow
        ctx.fill(Path(ellipseIn: CGRect(x: x + 3, y: y + h - 2, width: w - 6, height: 2.5)),
                 with: .color(Color.black.opacity(dark ? 0.12 : 0.06)))

        // Bin body (slightly tapered)
        let binHex = dark ? "4A4E5A" : "90949C"
        let binHi = dark ? "5A5E6A" : "A0A4AC"
        ctx.fill(Path(CGRect(x: x + 4, y: y + 3, width: w - 8, height: h - 5)),
                 with: .color(Color(hex: binHex)))
        // Highlight stripe
        ctx.fill(Path(CGRect(x: x + 4.5, y: y + 4, width: 1, height: h - 7)),
                 with: .color(Color(hex: binHi).opacity(0.3)))

        // Rim
        ctx.fill(Path(CGRect(x: x + 3, y: y + 2, width: w - 6, height: 2)),
                 with: .color(Color(hex: binHi)))
        ctx.fill(Path(CGRect(x: x + 3, y: y + 2, width: w - 6, height: 0.6)),
                 with: .color(Color.white.opacity(0.1)))

        // Trash sticking out
        let trashColors = ["D0C0A0", "A0C0D0", "C0A0A0"]
        for (i, tc) in trashColors.enumerated() {
            let tx = x + 5 + CGFloat(i) * 2
            if tx < x + w - 5 {
                ctx.fill(Path(CGRect(x: tx, y: y + 1, width: 1.5, height: 2)),
                         with: .color(Color(hex: tc).opacity(0.5)))
            }
        }
    }

    // ── Lamp ──
    private static func drawLamp(_ ctx: GraphicsContext, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, dark: Bool, frame: Int) {
        let cx = x + w / 2

        // Glow halo
        let glow = 0.06 + sin(Double(frame) * 0.05) * 0.03
        ctx.fill(Path(ellipseIn: CGRect(x: cx - 12, y: y - 4, width: 24, height: 24)),
                 with: .color(Color(hex: "F0E0A0").opacity(glow)))

        // Base
        let baseHex = dark ? "5A5040" : "A09070"
        ctx.fill(Path(ellipseIn: CGRect(x: cx - 3, y: y + h - 3, width: 6, height: 3)),
                 with: .color(Color(hex: baseHex)))

        // Pole
        let poleHex = dark ? "6A6050" : "B0A080"
        ctx.fill(Path(CGRect(x: cx - 0.6, y: y + 5, width: 1.2, height: h - 8)),
                 with: .color(Color(hex: poleHex)))

        // Shade
        let shadeHex = dark ? "E0C880" : "F0E0A0"
        ctx.fill(Path(ellipseIn: CGRect(x: cx - 5, y: y + 1, width: 10, height: 6)),
                 with: .color(Color(hex: shadeHex)))
        // Shade highlight
        ctx.fill(Path(ellipseIn: CGRect(x: cx - 3, y: y + 1.5, width: 6, height: 3)),
                 with: .color(Color.white.opacity(0.15)))

        // Bulb hint
        ctx.fill(Path(ellipseIn: CGRect(x: cx - 1.5, y: y + 4, width: 3, height: 2)),
                 with: .color(Color(hex: "FFFDE0").opacity(0.5)))
    }

    // ── Rug ──
    private static func drawRug(_ ctx: GraphicsContext, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, dark: Bool) {
        let rugHex = dark ? "6E8362" : "9DB889"
        let borderHex = dark ? "50614A" : "6F845E"
        // Rug body
        ctx.fill(Path(roundedRect: CGRect(x: x + 1, y: y + 1, width: w - 2, height: h - 2), cornerRadius: 1.5),
                 with: .color(Color(hex: rugHex).opacity(0.72)))
        // Border pattern
        ctx.stroke(Path(roundedRect: CGRect(x: x + 2, y: y + 2, width: w - 4, height: h - 4), cornerRadius: 1),
                   with: .color(Color(hex: borderHex).opacity(0.65)), lineWidth: 0.6)
        // Inner pattern
        ctx.stroke(Path(roundedRect: CGRect(x: x + 4, y: y + 4, width: w - 8, height: h - 8), cornerRadius: 0.5),
                   with: .color(Color(hex: dark ? "C4D8A8" : "E7F1D0").opacity(0.35)), lineWidth: 0.4)
        if w > 16 && h > 12 {
            ctx.fill(Path(ellipseIn: CGRect(x: x + w / 2 - 4, y: y + h / 2 - 2.5, width: 8, height: 5)),
                     with: .color(Color(hex: dark ? "99AF7A" : "E7F1D0").opacity(0.32)))
        }
    }

    // ── Picture Frame ──
    private static func drawPictureFrame(_ ctx: GraphicsContext, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, dark: Bool) {
        // Frame (gold/wood)
        let frameHex = dark ? "5A4030" : "A08060"
        let frameHi = dark ? "6A5040" : "B09070"
        ctx.fill(Path(CGRect(x: x, y: y, width: w, height: h)),
                 with: .color(Color(hex: frameHex)))
        // Frame highlight
        ctx.fill(Path(CGRect(x: x, y: y, width: w, height: 0.8)),
                 with: .color(Color(hex: frameHi).opacity(0.5)))
        ctx.fill(Path(CGRect(x: x, y: y, width: 0.8, height: h)),
                 with: .color(Color(hex: frameHi).opacity(0.3)))

        // Picture area
        let picHex = dark ? "203040" : "D5E5F0"
        ctx.fill(Path(CGRect(x: x + 2, y: y + 2, width: w - 4, height: h - 4)),
                 with: .color(Color(hex: picHex)))
        // Simple landscape in picture
        let skyHex = dark ? "243B54" : "8CC7EE"
        let hillHex = dark ? "365339" : "6FA86F"
        ctx.fill(Path(CGRect(x: x + 2, y: y + 2, width: w - 4, height: (h - 4) * 0.6)),
                 with: .color(Color(hex: skyHex).opacity(0.5)))
        ctx.fill(Path(CGRect(x: x + 2, y: y + 2 + (h - 4) * 0.5, width: w - 4, height: (h - 4) * 0.5)),
                 with: .color(Color(hex: hillHex).opacity(0.4)))
        ctx.fill(Path(ellipseIn: CGRect(x: x + 4, y: y + 3, width: 2.5, height: 2.5)),
                 with: .color(Color(hex: "F7E39C").opacity(0.8)))
    }

    // ── Clock ──
    private static func drawClock(_ ctx: GraphicsContext, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, dark: Bool, frame: Int) {
        let rim = dark ? "D6D8DC" : "F5F6F8"
        let shadow = dark ? "4A505A" : "93A0AE"
        let face = dark ? "F0EFE8" : "FFFDF8"
        let hand = dark ? "243040" : "3B4652"

        ctx.fill(Path(ellipseIn: CGRect(x: x + 2, y: y + 2.2, width: w - 4, height: h - 4)),
                 with: .color(Color(hex: shadow).opacity(0.45)))
        ctx.fill(Path(ellipseIn: CGRect(x: x + 1.5, y: y + 1.5, width: w - 3, height: h - 3)),
                 with: .color(Color(hex: rim)))
        ctx.fill(Path(ellipseIn: CGRect(x: x + 3, y: y + 3, width: w - 6, height: h - 6)),
                 with: .color(Color(hex: face)))

        let cx = x + w / 2
        let cy = y + h / 2
        let minuteAngle = Double(frame % 120) / 120.0 * .pi * 2 - .pi / 2
        let minuteEnd = CGPoint(x: cx + cos(minuteAngle) * 3.6, y: cy + sin(minuteAngle) * 3.6)

        var hour = Path()
        hour.move(to: CGPoint(x: cx, y: cy))
        hour.addLine(to: CGPoint(x: cx + 1.4, y: cy - 2.2))
        ctx.stroke(hour, with: .color(Color(hex: hand)), lineWidth: 0.8)

        var minute = Path()
        minute.move(to: CGPoint(x: cx, y: cy))
        minute.addLine(to: minuteEnd)
        ctx.stroke(minute, with: .color(Color(hex: hand).opacity(0.8)), lineWidth: 0.6)

        ctx.fill(Path(ellipseIn: CGRect(x: cx - 0.7, y: cy - 0.7, width: 1.4, height: 1.4)),
                 with: .color(Color(hex: hand)))
    }

    // ═══════════════════════════════════════════════════
    // MARK: - Character Sprite Rendering
    // ═══════════════════════════════════════════════════

    private static func snappedPixel(_ value: CGFloat) -> CGFloat {
        value.rounded(.toNearestOrAwayFromZero)
    }

    private static func drawCharacterSprite(_ ctx: GraphicsContext, char: OfficeCharacter, workerColor: Color,
                                             hashVal: Int, dir: Direction, state: OfficeCharacterState,
                                             frame: Int, dark: Bool, rosterCharacter: WorkerCharacter?) {
        let shirtHex = rosterCharacter.map { normalizedHex($0.shirtColor) } ?? colorToHex(workerColor)
        let hairColors = ["4A3728", "8B4513", "2C1810", "C4A474", "1A1A2A", "6A3020"]
        let hairHex = rosterCharacter.map { normalizedHex($0.hairColor) } ?? hairColors[abs(hashVal) % hairColors.count]
        let skinHex = rosterCharacter.map { normalizedHex($0.skinTone) } ?? "FFD5B8"
        let pantsHex = rosterCharacter.map { normalizedHex($0.pantsColor) } ?? (abs(hashVal) % 2 == 0 ? "3A4050" : "4A3558")

        let cacheKey = "\(skinHex)|\(hairHex)|\(shirtHex)|\(pantsHex)"
        let sprites: CharacterSpriteSet
        if let cached = Self.spriteCache[cacheKey] {
            sprites = cached
        } else {
            // 캐시 크기 제한 (최대 50개 — 초과 시 전체 클리어)
            if Self.spriteCache.count > 50 { Self.spriteCache.removeAll() }
            let built = SpriteCatalog.buildCharacterSprites(skin: skinHex, hair: hairHex, shirt: shirtHex, pants: pantsHex)
            Self.spriteCache[cacheKey] = built
            sprites = built
        }

        let sprite: SpriteData
        switch state {
        case .typing, .reading, .searching:
            let frames = sprites.typing[dir] ?? sprites.typing[.down] ?? sprites.typing.values.first ?? []
            sprite = frames.isEmpty ? [] : frames[(frame / 4) % frames.count]
        case .walkingTo, .wandering:
            let frames = sprites.walk[dir] ?? sprites.walk[.down] ?? sprites.walk.values.first ?? []
            sprite = frames.isEmpty ? [] : frames[frame % frames.count]
        default:
            sprite = sprites.idle[dir] ?? sprites.idle[.down] ?? sprites.idle.values.first ?? []
        }

        let spriteH = CGFloat(sprite.count)
        let spriteW = sprite.isEmpty ? 16 : CGFloat(sprite[0].count)
        let isWalking: Bool = {
            switch state {
            case .walkingTo, .wandering: return true
            default: return false
            }
        }()

        let sittingOffset: CGFloat = {
            guard char.usesSeatPose else { return 0 }
            switch state {
            case .typing, .sittingIdle, .seatRest, .celebrating:
                return OfficeConstants.charSittingOffset
            default:
                return 0
            }
        }()

        let walkFrame = isWalking ? frame % 4 : 0
        let stepLift: CGFloat = (walkFrame == 1 || walkFrame == 3) ? -1 : 0
        let upperShiftX: CGFloat
        let midShiftX: CGFloat
        let upperShiftY: CGFloat
        let midShiftY: CGFloat
        let lowerShiftY: CGFloat
        let baseBobY: CGFloat
        let shadowWidth: CGFloat
        let shadowHeight: CGFloat
        let shadowY: CGFloat

        switch dir {
        case .left, .right:
            upperShiftX = 0
            midShiftX = 0
            upperShiftY = stepLift
            midShiftY = 0
            lowerShiftY = 0
            baseBobY = 0
            shadowWidth = 9.8
            shadowHeight = 3.7
            shadowY = char.pixelY - 0.9
        case .up, .down:
            upperShiftX = 0
            midShiftX = 0
            upperShiftY = stepLift
            midShiftY = stepLift
            lowerShiftY = 0
            baseBobY = 0
            shadowWidth = 9.6
            shadowHeight = 3.6
            shadowY = char.pixelY - 0.9
        }

        let drawX = snappedPixel(char.pixelX - spriteW / 2)
        let drawY = snappedPixel(char.pixelY + sittingOffset - spriteH + baseBobY)
        let shadowX = snappedPixel(char.pixelX - shadowWidth / 2)
        let shadowDrawY = snappedPixel(shadowY)

        // Shadow
        ctx.fill(
            Path(ellipseIn: CGRect(x: shadowX, y: shadowDrawY, width: shadowWidth, height: shadowHeight)),
            with: .color(Color.black.opacity(dark ? 0.18 : 0.10))
        )

        // Pixel render
        for y in 0..<sprite.count {
            let rowShiftX: CGFloat
            let rowShiftY: CGFloat
            if isWalking {
                switch y {
                case ..<10:
                    rowShiftX = upperShiftX
                    rowShiftY = upperShiftY
                case 10..<16:
                    rowShiftX = midShiftX
                    rowShiftY = midShiftY
                default:
                    rowShiftX = 0
                    rowShiftY = lowerShiftY
                }
            } else {
                rowShiftX = 0
                rowShiftY = 0
            }

            for x in 0..<sprite[y].count {
                let hex = sprite[y][x]
                guard !hex.isEmpty else { continue }
                ctx.fill(Path(CGRect(
                    x: snappedPixel(drawX + CGFloat(x) + rowShiftX),
                    y: snappedPixel(drawY + CGFloat(y) + rowShiftY),
                    width: 1.15,
                    height: 1.15
                )),
                         with: .color(Color(hex: hex)))
            }
        }

        if let rosterCharacter {
            drawCharacterDetails(
                ctx,
                character: rosterCharacter,
                dir: dir,
                drawX: drawX + upperShiftX,
                drawY: drawY + upperShiftY,
                hairHex: hairHex,
                skinHex: skinHex,
                shirtHex: shirtHex,
                pantsHex: pantsHex
            )
        }
    }

    private static func colorToHex(_ color: Color) -> String {
        guard let c = NSColor(color).usingColorSpace(.sRGB) else { return "5B9CF6" }
        return String(format: "%02X%02X%02X", Int(c.redComponent * 255), Int(c.greenComponent * 255), Int(c.blueComponent * 255))
    }

    private static func normalizedHex(_ hex: String) -> String {
        hex.replacingOccurrences(of: "#", with: "").uppercased()
    }

    private static func shadeHex(_ hex: String, by delta: CGFloat) -> String {
        let normalized = normalizedHex(hex)
        guard let color = NSColor(Color(hex: normalized)).usingColorSpace(.sRGB) else { return normalized }

        func clamp(_ value: CGFloat) -> CGFloat {
            min(max(value, 0), 1)
        }

        let r = clamp(color.redComponent + delta)
        let g = clamp(color.greenComponent + delta)
        let b = clamp(color.blueComponent + delta)
        return String(format: "%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }

    private static func blendHex(_ hexA: String, _ hexB: String, ratio: CGFloat) -> String {
        let a = normalizedHex(hexA)
        let b = normalizedHex(hexB)
        guard
            let colorA = NSColor(Color(hex: a)).usingColorSpace(.sRGB),
            let colorB = NSColor(Color(hex: b)).usingColorSpace(.sRGB)
        else { return a }

        let mix = min(max(ratio, 0), 1)
        let inv = 1 - mix
        let r = colorA.redComponent * inv + colorB.redComponent * mix
        let g = colorA.greenComponent * inv + colorB.greenComponent * mix
        let blue = colorA.blueComponent * inv + colorB.blueComponent * mix
        return String(format: "%02X%02X%02X", Int(r * 255), Int(g * 255), Int(blue * 255))
    }

    private static func drawCharacterDetails(
        _ ctx: GraphicsContext,
        character: WorkerCharacter,
        dir: Direction,
        drawX: CGFloat,
        drawY: CGFloat,
        hairHex: String,
        skinHex: String,
        shirtHex: String,
        pantsHex: String
    ) {
        let earPink = "F2B6B6"
        let metal = "B7C6D8"
        let darkLine = "1F2430"
        let gold = "E2C66C"
        let green = "6CC16A"
        let speciesColor = normalizedHex(character.hairColor)
        let hairShadow = shadeHex(hairHex, by: -0.18)
        let hairLight = shadeHex(hairHex, by: 0.12)
        let skinShadow = shadeHex(skinHex, by: -0.10)
        let shirtShadow = shadeHex(shirtHex, by: -0.16)
        let shirtLight = shadeHex(shirtHex, by: 0.14)
        let pantsShadow = shadeHex(pantsHex, by: -0.18)
        let pantsLight = shadeHex(pantsHex, by: 0.12)
        let blush = blendHex(skinHex, "F09CAB", ratio: 0.34)
        let furLight = blendHex(speciesColor, "FFF4E6", ratio: 0.18)
        let frontFacing = dir == .down
        let backFacing = dir == .up
        let sideFacing = dir == .left || dir == .right

        func pixel(_ px: CGFloat, _ py: CGFloat, _ hex: String, _ w: CGFloat = 1.2, _ h: CGFloat = 1.2, _ opacity: Double = 1) {
            ctx.fill(Path(CGRect(x: drawX + px, y: drawY + py, width: w, height: h)),
                     with: .color(Color(hex: hex).opacity(opacity)))
        }

        if backFacing {
            pixel(4.6, 2.2, hairShadow, 7.2, 2.3, 0.42)
            pixel(5.2, 3.1, hairLight, 6, 1.1, 0.22)
        } else {
            pixel(4.6, 2.2, hairShadow, 7.2, 1.8, 0.35)
            pixel(5.3, 2.4, hairLight, 5.8, 1, 0.28)
            pixel(dir == .left ? 4.1 : 10.9, 4.6, hairShadow, 1.5, 2.7, 0.22)
        }

        pixel(6.1, 9.6, skinShadow, 3.8, 0.8, backFacing ? 0.16 : 0.34)
        pixel(4.7, 10.3, shirtLight, 6.6, 1.1, backFacing ? 0.14 : 0.30)
        pixel(7.45, 10.6, shirtShadow, 1.15, 5, 0.30)
        pixel(5.1, 12, shirtShadow, 1, 3.3, 0.16)
        pixel(10.3, 12, shirtShadow, 1, 3.3, 0.16)
        pixel(6.1, 16.2, pantsLight, 1, 3.2, 0.30)
        pixel(9.0, 16.2, pantsShadow, 1, 3.2, 0.35)
        pixel(4.9, 19.4, pantsShadow, 2.4, 1, 0.34)
        pixel(8.9, 19.4, pantsShadow, 2.4, 1, 0.34)

        if frontFacing {
            pixel(5.2, 7.7, blush, 1.3, 0.9, 0.26)
            pixel(10.1, 7.7, blush, 1.3, 0.9, 0.26)
            pixel(7.4, 8.9, darkLine, 1.5, 0.55, 0.28)
        } else if sideFacing {
            let eyeX: CGFloat = dir == .left ? 5.4 : 10.0
            let noseX: CGFloat = dir == .left ? 6.5 : 8.0
            pixel(eyeX, 6.8, darkLine, 0.9, 1.2, 0.34)
            pixel(noseX, 8.2, skinShadow, 0.9, 0.8, 0.25)
        }

        switch character.species {
        case .cat, .fox:
            pixel(4, 1, speciesColor, 2, 2)
            pixel(10, 1, speciesColor, 2, 2)
            pixel(5, 2, earPink, 1, 1, 0.7)
            pixel(11, 2, earPink, 1, 1, 0.7)
            pixel(6.1, 7.8, furLight, 4.1, 1.6, 0.45)
            pixel(7.1, 8.6, "7A4A4A", 2, 0.8, 0.38)
            pixel(character.species == .fox ? 12.4 : 12.0, 13.1, character.species == .fox ? "FFF2E1" : speciesColor, 2.3, 3.4, 0.55)
            pixel(13.2, 15.6, character.species == .fox ? "FFF2E1" : furLight, 1.3, 1.2, 0.55)
        case .rabbit:
            pixel(5, -2, speciesColor, 2, 4)
            pixel(9, -2, speciesColor, 2, 4)
            pixel(5.7, -1, earPink, 0.8, 3, 0.65)
            pixel(9.7, -1, earPink, 0.8, 3, 0.65)
            pixel(6.4, 7.6, "F7F1EB", 3.2, 1.5, 0.42)
            pixel(7.4, 8.8, "D67E8A", 1.3, 0.8, 0.55)
        case .bear, .panda:
            pixel(4, 2, speciesColor, 2, 2)
            pixel(10, 2, speciesColor, 2, 2)
            pixel(5.4, 12.3, character.species == .panda ? "ECE7DD" : blendHex(speciesColor, "E6C39B", ratio: 0.45), 5.4, 2.2, 0.45)
            pixel(7.1, 7.8, blendHex(speciesColor, "F0D4B6", ratio: 0.5), 2.2, 1.5, 0.42)
        case .penguin:
            pixel(6.8, 8, "E4B54E", 2.4, 1.5)
            pixel(5.5, 11, "F4F0E8", 5.2, 3.2, 0.5)
            pixel(4.5, 11.2, "243447", 1.2, 3.6, 0.38)
            pixel(10.7, 11.2, "243447", 1.2, 3.6, 0.38)
            pixel(6.1, 13.6, "FFF8F0", 4, 2, 0.35)
        case .robot:
            pixel(7.2, -1, metal, 1, 2.4)
            pixel(6.2, 6, "69F0C8", 4.4, 1.3)
            pixel(7.1, -2, "F85B5B", 1.4, 1.4)
            pixel(5.3, 10.7, "D8E3EA", 5.6, 3.6, 0.32)
            pixel(7.6, 11.2, "69F0C8", 1, 2.6, 0.72)
            pixel(5.3, 12.6, darkLine, 5.6, 0.7, 0.26)
        case .alien:
            pixel(5, -1, green, 1.5, 3.2)
            pixel(10, -1, green, 1.5, 3.2)
            pixel(4.8, -2, "C5FFB7", 1.7, 1.7, 0.7)
            pixel(9.8, -2, "C5FFB7", 1.7, 1.7, 0.7)
            pixel(5.2, 7.2, "C5FFB7", 1.4, 1.1, 0.25)
            pixel(10.2, 7.2, "C5FFB7", 1.4, 1.1, 0.25)
            pixel(6.3, 12.4, blendHex(shirtHex, "A7FFD8", ratio: 0.35), 3.8, 2.3, 0.34)
        case .ghost:
            pixel(4.5, 19.5, skinHex, 2, 2, 0.55)
            pixel(7.5, 20.2, skinHex, 2, 1.8, 0.45)
            pixel(10.5, 19.6, skinHex, 1.6, 2, 0.4)
            pixel(4.2, 6.4, "F6FAFF", 7.4, 7, 0.12)
            pixel(5.5, 13.8, "DCEEFF", 4.8, 2.1, 0.15)
        case .dragon:
            pixel(4, 1, speciesColor, 2, 2)
            pixel(10, 1, speciesColor, 2, 2)
            pixel(7.3, -1, gold, 1.4, 2.2)
            pixel(6.1, 11.2, shirtLight, 4.2, 1.5, 0.22)
            pixel(4.2, 5.4, speciesColor, 1.2, 6.6, 0.35)
            pixel(11.6, 5.4, speciesColor, 1.2, 6.6, 0.35)
            pixel(7.4, 2.4, gold, 1, 6.3, 0.45)
        case .chicken:
            pixel(7, 1, "D84A4A", 2.2, 1.5)
            pixel(6.9, 8, "E6B850", 2.3, 1.4)
            pixel(6.2, 12.4, "FFF4E5", 4, 1.8, 0.42)
            pixel(4.2, 12, shirtLight, 1.4, 2.8, 0.24)
            pixel(10.4, 12, shirtLight, 1.4, 2.8, 0.24)
        case .owl:
            pixel(4.5, 1, speciesColor, 1.5, 2.4)
            pixel(10.2, 1, speciesColor, 1.5, 2.4)
            pixel(5.1, 6.4, blendHex(speciesColor, "EADCC7", ratio: 0.42), 5.6, 2.2, 0.40)
            pixel(6.1, 12.1, "F4E8D0", 3.9, 2.5, 0.24)
        case .frog:
            pixel(4.6, 4.5, speciesColor, 2.2, 2.2)
            pixel(9.2, 4.5, speciesColor, 2.2, 2.2)
            pixel(5.2, 5.1, "FFFFFF", 0.8, 0.8, 0.7)
            pixel(9.8, 5.1, "FFFFFF", 0.8, 0.8, 0.7)
            pixel(6.2, 12.5, "CFE8A4", 3.8, 2.2, 0.36)
            pixel(6.6, 8.4, "2F6130", 2.6, 0.6, 0.28)
        case .unicorn:
            pixel(7.3, -2, gold, 1.3, 3.4)
            pixel(6.2, 1, speciesColor, 4, 1.2)
            pixel(4.1, 3.5, "FF8CAD", 1.8, 4.4, 0.42)
            pixel(5.7, 4.1, "FFC966", 1.2, 3.5, 0.35)
            pixel(9.6, 12.1, "72D5C2", 1.5, 4.4, 0.36)
        case .skeleton:
            pixel(5.4, 8, darkLine, 1.2, 1.2)
            pixel(9.4, 8, darkLine, 1.2, 1.2)
            pixel(7.1, 10, darkLine, 2.4, 0.8)
            pixel(6.4, 12.1, "EEE9D9", 3.2, 2.6, 0.40)
            pixel(7.5, 15.3, "EEE9D9", 1, 4, 0.42)
        case .human, .claude:
            pixel(5.2, 3.5, hairLight, 2.2, 1.2, 0.24)
            pixel(9.0, 3.5, hairLight, 1.7, 1.2, 0.22)
            pixel(6.2, 10.1, blendHex(shirtHex, skinHex, ratio: 0.18), 3.6, 0.7, 0.24)
        default:
            break
        }

        switch character.hatType {
        case .beanie:
            pixel(4, 1, shirtHex, 8, 2)
            pixel(5.5, 0, shirtLight, 5, 1.2)
            pixel(4.2, 2.2, shirtShadow, 7.6, 0.8, 0.32)
        case .cap:
            pixel(4.2, 1, shirtHex, 7.6, 2)
            pixel(5.1, 1.2, shirtLight, 5.3, 0.9, 0.30)
            if dir != .up { pixel(9.5, 3, shirtHex, 3.2, 1.1) }
        case .hardhat:
            pixel(4, 1, "E4C14A", 8, 2.2)
            pixel(5.5, 0, "F6DA72", 5, 1.1)
            pixel(4.5, 2.3, "B28F1E", 7, 0.8, 0.30)
        case .wizard:
            pixel(6.7, -3, pantsHex, 1.6, 4.2)
            pixel(5.3, 0, pantsHex, 4.4, 1.3)
            pixel(6.9, -2.2, shirtLight, 1.1, 1.4, 0.24)
        case .crown:
            pixel(4.8, 1, gold, 7, 1.2)
            pixel(5.2, 0, gold, 1.2, 1.3)
            pixel(7.7, -0.6, gold, 1.2, 1.8)
            pixel(10.2, 0, gold, 1.2, 1.3)
        case .headphones:
            pixel(3.6, 5.8, darkLine, 1.4, 3.4)
            pixel(11.2, 5.8, darkLine, 1.4, 3.4)
            pixel(4.6, 4.8, darkLine, 7, 1.1)
            pixel(3.8, 6.6, "69F0C8", 1, 1.4, 0.62)
            pixel(11.4, 6.6, "69F0C8", 1, 1.4, 0.62)
        case .beret:
            pixel(4.2, 1.2, shirtHex, 7, 2.4)
            pixel(3.4, 2.2, shirtHex, 4.2, 1.3)
            pixel(5.1, 1.4, shirtLight, 4.5, 0.9, 0.28)
        case .none:
            break
        }

        switch character.accessory {
        case .glasses:
            pixel(5.2, 6.8, darkLine, 2, 1.2)
            pixel(9.1, 6.8, darkLine, 2, 1.2)
            pixel(7.2, 7.2, darkLine, 1.8, 0.6)
            pixel(5.5, 6.8, "FFFFFF", 0.6, 0.5, 0.35)
            pixel(9.5, 6.8, "FFFFFF", 0.6, 0.5, 0.35)
        case .sunglasses:
            pixel(4.8, 6.6, darkLine, 2.6, 1.5)
            pixel(8.8, 6.6, darkLine, 2.6, 1.5)
            pixel(7.3, 7.2, darkLine, 1.4, 0.7)
            pixel(5.4, 6.8, "7AA7C7", 1.2, 0.6, 0.16)
            pixel(9.4, 6.8, "7AA7C7", 1.2, 0.6, 0.16)
        case .scarf:
            pixel(4.6, 10.5, shirtHex, 7, 1.6)
            pixel(5.1, 12, shirtHex, 1.2, 2)
            pixel(8.2, 10.7, shirtLight, 2.2, 0.8, 0.26)
        case .mask:
            pixel(5.2, 8.2, "D8E3EA", 5.4, 1.8)
            pixel(5.5, 8.5, "FFFFFF", 4.8, 0.5, 0.18)
        case .earring:
            pixel(dir == .left ? 4.4 : 11.4, 8.4, gold, 1, 1.2)
        case .none:
            break
        }
    }

    // ═══════════════════════════════════════════════════
    // MARK: - Overlays (Speech Bubbles, Labels)
    // ═══════════════════════════════════════════════════

    private func drawParallelTaskBubble(
        _ ctx: GraphicsContext,
        tab: TerminalTab,
        anchorX: CGFloat,
        anchorY: CGFloat
    ) {
        let tasks = tab.officeParallelTasks
        guard !tasks.isEmpty else { return }
        let hasRunning = tasks.contains { $0.state == .running }
        let hasFailure = tasks.contains { $0.state == .failed }

        let visibleTasks = Array(tasks.prefix(3))
        let chipWidth: CGFloat = 18
        let gap: CGFloat = 4
        let extraCount = max(0, tasks.count - visibleTasks.count)
        let countWidth = extraCount > 0 ? 18 : 0
        let chipCount = CGFloat(visibleTasks.count)
        let gapCount = CGFloat(max(0, visibleTasks.count - 1))
        let chipsWidth = chipCount * chipWidth
        let gapsWidth = gapCount * gap
        let bubbleWidth = chipsWidth + gapsWidth + CGFloat(countWidth) + 18
        let bubbleHeight: CGFloat = 28
        let rect = CGRect(x: anchorX - bubbleWidth / 2, y: anchorY, width: bubbleWidth, height: bubbleHeight)
        let bubbleBG = dark ? Color(hex: "101624") : Color.white

        var tail = Path()
        tail.move(to: CGPoint(x: anchorX - 3, y: rect.maxY))
        tail.addLine(to: CGPoint(x: anchorX, y: rect.maxY + 4))
        tail.addLine(to: CGPoint(x: anchorX + 3, y: rect.maxY))
        ctx.fill(tail, with: .color(bubbleBG.opacity(0.96)))

        let bubblePath = Path(roundedRect: rect, cornerRadius: 5)
        ctx.fill(bubblePath, with: .color(bubbleBG.opacity(0.96)))
        ctx.stroke(bubblePath, with: .color(Theme.purple.opacity(0.4)), lineWidth: 0.7)

        ctx.draw(
            Text("PAR")
                .font(.system(size: 4.8, weight: .heavy, design: .monospaced))
                .foregroundColor(Theme.purple.opacity(0.95)),
            at: CGPoint(x: rect.minX + 10, y: rect.minY + 6.5)
        )

        if hasRunning {
            let pulseCenter = CGPoint(x: rect.maxX - 11, y: rect.minY + 6.5)
            let pulseRadius = CGFloat(1.8 + CGFloat((frame / 3) % 3))
            ctx.stroke(
                Path(ellipseIn: CGRect(
                    x: pulseCenter.x - pulseRadius,
                    y: pulseCenter.y - pulseRadius,
                    width: pulseRadius * 2,
                    height: pulseRadius * 2
                )),
                with: .color(Theme.cyan.opacity(0.7)),
                lineWidth: 0.5
            )
            ctx.fill(
                Path(ellipseIn: CGRect(x: pulseCenter.x - 1, y: pulseCenter.y - 1, width: 2, height: 2)),
                with: .color(Theme.cyan.opacity(0.95))
            )
        } else if hasFailure {
            ctx.draw(
                Text("!")
                    .font(.system(size: 5.2, weight: .heavy, design: .monospaced))
                    .foregroundColor(Theme.red.opacity(0.95)),
                at: CGPoint(x: rect.maxX - 11, y: rect.minY + 6.5)
            )
        } else {
            ctx.draw(
                Text("OK")
                    .font(.system(size: 4.8, weight: .heavy, design: .monospaced))
                    .foregroundColor(Theme.green.opacity(0.95)),
                at: CGPoint(x: rect.maxX - 12, y: rect.minY + 6.5)
            )
        }

        for (index, task) in visibleTasks.enumerated() {
            let chipX = rect.minX + 8 + CGFloat(index) * (chipWidth + gap)
            let chipRect = CGRect(x: chipX, y: rect.minY + 11, width: chipWidth, height: 13)
            drawParallelTaskChip(ctx, task: task, rect: chipRect)
        }

        if extraCount > 0 {
            let countX = rect.maxX - 11
            ctx.draw(
                Text("+\(extraCount)")
                    .font(.system(size: 4.8, weight: .heavy, design: .monospaced))
                    .foregroundColor(Theme.textDim),
                at: CGPoint(x: countX, y: rect.midY + 2)
            )
        }
    }

    private func drawParallelTaskChip(
        _ ctx: GraphicsContext,
        task: ParallelTaskRecord,
        rect: CGRect
    ) {
        let border = task.state.tint.opacity(0.55)
        let background = (dark ? Color(hex: "171E2D") : Color(hex: "F8F9FD")).opacity(0.95)
        let chipPath = Path(roundedRect: rect, cornerRadius: 3)
        ctx.fill(chipPath, with: .color(background))
        ctx.stroke(chipPath, with: .color(border), lineWidth: 0.6)

        let rosterCharacter = CharacterRegistry.shared.character(with: task.assigneeCharacterId)
        let workerColor = rosterCharacter.map { Color(hex: Self.normalizedHex($0.shirtColor)) } ?? task.state.tint
        let roleLabel = rosterCharacter?.jobRole.shortLabel ?? String(task.label.prefix(2)).uppercased()
        let avatarRect = CGRect(x: rect.minX + 2.2, y: rect.minY + 2.4, width: rect.width - 6, height: 7.2)
        let avatarPath = Path(roundedRect: avatarRect, cornerRadius: 2)
        ctx.fill(avatarPath, with: .color(workerColor.opacity(dark ? 0.24 : 0.18)))
        ctx.stroke(avatarPath, with: .color(workerColor.opacity(0.5)), lineWidth: 0.5)
        ctx.draw(
            Text(roleLabel)
                .font(.system(size: 4.4, weight: .heavy, design: .monospaced))
                .foregroundColor(workerColor.opacity(0.96)),
            at: CGPoint(x: avatarRect.midX, y: avatarRect.midY)
        )

        let statusRect = CGRect(x: rect.minX + 2, y: rect.maxY - 2.3, width: rect.width - 4, height: 1.5)
        ctx.fill(Path(roundedRect: statusRect, cornerRadius: 1),
                 with: .color(task.state.tint.opacity(task.state == .running ? 0.88 : 0.74)))

        let iconOrigin = CGPoint(x: rect.maxX - 4, y: rect.minY + 3)
        switch task.state {
        case .completed:
            var check = Path()
            check.move(to: CGPoint(x: iconOrigin.x - 2.5, y: iconOrigin.y + 0.8))
            check.addLine(to: CGPoint(x: iconOrigin.x - 1.2, y: iconOrigin.y + 2.2))
            check.addLine(to: CGPoint(x: iconOrigin.x + 1.6, y: iconOrigin.y - 0.9))
            ctx.stroke(check, with: .color(Theme.green.opacity(0.92)), lineWidth: 0.7)
        case .failed:
            var crossA = Path()
            crossA.move(to: CGPoint(x: iconOrigin.x - 2, y: iconOrigin.y - 1.5))
            crossA.addLine(to: CGPoint(x: iconOrigin.x + 1.6, y: iconOrigin.y + 1.6))
            var crossB = Path()
            crossB.move(to: CGPoint(x: iconOrigin.x + 1.6, y: iconOrigin.y - 1.5))
            crossB.addLine(to: CGPoint(x: iconOrigin.x - 2, y: iconOrigin.y + 1.6))
            ctx.stroke(crossA, with: .color(Theme.red.opacity(0.92)), lineWidth: 0.65)
            ctx.stroke(crossB, with: .color(Theme.red.opacity(0.92)), lineWidth: 0.65)
        case .running:
            let dotBaseX = rect.maxX - 5.8
            let dotY = rect.minY + 2.2
            for index in 0..<3 {
                let activeIndex = (frame / 4) % 3
                let opacity = activeIndex == index ? 0.95 : 0.35
                ctx.fill(
                    Path(ellipseIn: CGRect(x: dotBaseX + CGFloat(index) * 1.6, y: dotY, width: 0.9, height: 0.9)),
                    with: .color(Theme.cyan.opacity(opacity))
                )
            }
        }
    }

    private func drawOverlays(_ ctx: GraphicsContext, viewScale: CGFloat = 1.0) {
        // 축소 시 라벨 간소화: scale 기준으로 단계적 숨김
        let showNameLabels = viewScale >= 2.2
        let showFileLabels = viewScale >= 2.2
        let showToolBadges = viewScale >= 1.6
        func hasPrimaryBubble(for state: OfficeCharacterState) -> Bool {
            switch state {
            case .thinking, .typing, .reading, .searching, .celebrating, .error, .onBreak:
                return true
            default:
                return false
            }
        }

        func socialBubble(for char: OfficeCharacter) -> (text: String, color: Color)? {
            guard let mode = char.socialMode, char.socialTimer > 0 else { return nil }
            let phase = (frame / 10) % 4  // 4 phases for more variety
            let role = char.socialRole

            let texts: [String]
            let color: Color

            switch mode {
            case .greeting:
                color = Color(hex: "5AF078")
                texts = role == 0 ? Self.greetTexts0 : Self.greetTexts1
            case .chatting:
                color = Color(hex: "78C8F0")
                texts = role == 0 ? Self.chatTexts0 : Self.chatTexts1
            case .brainstorming:
                color = Color(hex: "C88AF0")
                texts = role == 0 ? Self.brainTexts0 : Self.brainTexts1
            case .coffee:
                color = Color(hex: "E8A850")
                texts = role == 0 ? Self.coffeeTexts0 : Self.coffeeTexts1
            case .highFive:
                color = Color(hex: "F0D850")
                texts = role == 0 ? Self.highFiveTexts0 : Self.highFiveTexts1
            }

            let text = texts[phase % texts.count]
            return (text, color)
        }

        func activityReaction(for char: OfficeCharacter) -> (text: String, color: Color)? {
            // Only show occasionally (every ~3 seconds, visible for 1.5 seconds)
            let cycle = frame % Int(OfficeConstants.fps * 6)
            guard cycle < Int(OfficeConstants.fps * 1.5) else { return nil }

            // Don't show during social interactions
            guard char.socialMode == nil else { return nil }

            switch char.state {
            case .typing:
                return (Self.typingReactions[frame / 18 % Self.typingReactions.count], Color(hex: "5AF078"))
            case .reading:
                return (Self.readingReactions[frame / 18 % Self.readingReactions.count], Color(hex: "78C8F0"))
            case .searching:
                return (Self.searchingReactions[frame / 18 % Self.searchingReactions.count], Color(hex: "C88AF0"))
            case .error:
                return (Self.errorReactions[frame / 12 % Self.errorReactions.count], Color(hex: "F06868"))
            case .thinking:
                return (Self.thinkingReactions[frame / 24 % Self.thinkingReactions.count], Color(hex: "E8A850"))
            case .celebrating:
                return (Self.celebratingReactions[frame / 12 % Self.celebratingReactions.count], Color(hex: "F0D850"))
            case .sittingIdle:
                // Only idle characters sometimes show reactions (rarely)
                guard (frame / 36 + char.tileCol * 7) % 20 == 0 else { return nil }
                return (Self.idleReactions[(frame / 36 + char.tileCol) % Self.idleReactions.count], Color(hex: "8690a4"))
            default:
                return nil
            }
        }

        func drawHighFiveSparkIfNeeded(for char: OfficeCharacter) {
            guard char.socialMode == .highFive,
                  char.socialRole == 0,
                  char.socialTimer > 0,
                  let partnerKey = char.socialPartnerKey,
                  let partner = characters[partnerKey],
                  partner.socialMode == .highFive,
                  partner.socialTimer > 0 else { return }

            let sparkCenter = CGPoint(
                x: (char.pixelX + partner.pixelX) / 2,
                y: min(char.pixelY, partner.pixelY) - 18
            )
            let bgRect = CGRect(x: sparkCenter.x - 5.5, y: sparkCenter.y - 5.5, width: 11, height: 11)
            ctx.fill(
                Path(ellipseIn: bgRect),
                with: .color(Theme.yellow.opacity(dark ? 0.22 : 0.15))
            )
            ctx.draw(
                Text("*")
                    .font(.system(size: 7, weight: .black))
                    .foregroundColor(Theme.yellow.opacity(0.98)),
                at: sparkCenter
            )
        }

        func overlayBaseY(for char: OfficeCharacter) -> CGFloat {
            max(8, char.pixelY - 40)
        }

        func projectBadgeY(for char: OfficeCharacter, tab: TerminalTab, hasBubbleText: Bool) -> CGFloat {
            let baseY = overlayBaseY(for: char)
            if !tab.officeParallelTasks.isEmpty {
                return max(4, parallelBubbleAnchorY(for: char, hasBubbleText: hasBubbleText) - 12)
            }
            if hasBubbleText {
                return max(4, baseY - 14)
            }
            return max(4, baseY - 6)
        }

        func parallelBubbleAnchorY(for char: OfficeCharacter, hasBubbleText: Bool) -> CGFloat {
            let baseY = overlayBaseY(for: char)
            return max(4, hasBubbleText ? baseY - 46 : baseY - 32)
        }

        let projectLeads = characters.values
            .filter { $0.usesSeatPose }
            .sorted { $0.pixelY < $1.pixelY }

        for char in projectLeads {
            guard let tabId = char.tabId,
                  let tab = tabs.first(where: { $0.id == tabId }) else { continue }
            guard tab.automationSourceTabId == nil else { continue }
            let hasBubbleText = socialBubble(for: char) != nil || hasPrimaryBubble(for: char.state)
            let label = String(tab.projectName.prefix(10))
            let badgeWidth = max(26, CGFloat(label.count) * 4.5 + 10)
            let badgeRect = CGRect(
                x: char.pixelX - badgeWidth / 2,
                y: projectBadgeY(for: char, tab: tab, hasBubbleText: hasBubbleText),
                width: badgeWidth,
                height: 8.5
            )
            let tint = projectTint(for: tab)
            ctx.fill(
                Path(roundedRect: badgeRect, cornerRadius: 2.5),
                with: .color((dark ? Color(hex: "0F1421") : Color.white).opacity(0.82))
            )
            ctx.stroke(
                Path(roundedRect: badgeRect, cornerRadius: 2.5),
                with: .color(tint.opacity(0.34)),
                lineWidth: 0.55
            )
            ctx.draw(
                Text(label)
                    .font(.system(size: 4.8, weight: .bold, design: .monospaced))
                    .foregroundColor(tint.opacity(0.95)),
                at: CGPoint(x: badgeRect.midX, y: badgeRect.midY)
            )
        }

        if let selectedFurnitureId,
           let furniture = map.furniture.first(where: { $0.id == selectedFurnitureId }) {
            let rect = CGRect(
                x: CGFloat(furniture.position.col) * 16 - 1,
                y: CGFloat(furniture.position.row) * 16 - 1,
                width: CGFloat(furniture.size.w) * 16 + 2,
                height: CGFloat(furniture.size.h) * 16 + 2
            )
            ctx.stroke(
                Path(roundedRect: rect, cornerRadius: 2),
                with: .color(Theme.yellow.opacity(0.9)),
                style: StrokeStyle(lineWidth: 1.2, dash: [2, 2])
            )
            ctx.fill(
                Path(roundedRect: rect.insetBy(dx: 1, dy: 1), cornerRadius: 2),
                with: .color(Theme.yellow.opacity(0.06))
            )
        }

        for (_, char) in characters {
            guard let tabId = char.tabId,
                  let tab = tabs.first(where: { $0.id == tabId }) else {
                if !char.displayName.isEmpty {
                    let idleColor = Color(hex: Self.normalizedHex(char.accentColorHex))
                    ctx.draw(
                        Text(char.displayName)
                            .font(.system(size: 5, weight: .semibold, design: .monospaced))
                            .foregroundColor(idleColor.opacity(0.72)),
                        at: CGPoint(x: char.pixelX, y: char.pixelY + 6)
                    )
                    let roleLabel = char.jobRole.shortLabel
                    let roleWidth = max(16, CGFloat(roleLabel.count) * 4.2 + 6)
                    let roleRect = CGRect(x: char.pixelX - roleWidth / 2, y: max(4, overlayBaseY(for: char) - 3), width: roleWidth, height: 8)
                    ctx.fill(
                        Path(roundedRect: roleRect, cornerRadius: 2),
                        with: .color((dark ? Color(hex: "111625") : Color.white).opacity(0.82))
                    )
                    ctx.stroke(
                        Path(roundedRect: roleRect, cornerRadius: 2),
                        with: .color(idleColor.opacity(0.22)),
                        lineWidth: 0.45
                    )
                    ctx.draw(
                        Text(roleLabel)
                            .font(.system(size: 4.6, weight: .bold, design: .monospaced))
                            .foregroundColor(idleColor.opacity(0.82)),
                        at: CGPoint(x: roleRect.midX, y: roleRect.midY)
                    )
                }
                continue
            }
            let bx = char.pixelX
            let by = overlayBaseY(for: char)

            let bubbleText: String?
            let iconColor: Color
            let isSelected = selectedTabId == char.tabId
            let socialOverlay = socialBubble(for: char) ?? activityReaction(for: char)

            if let socialOverlay {
                bubbleText = socialOverlay.text
                iconColor = socialOverlay.color
            } else {
                switch char.state {
                case .thinking: bubbleText = String(repeating: ".", count: (frame/8%3)+1); iconColor = Theme.purple
                case .typing: bubbleText = ">"; iconColor = Theme.green
                case .reading: bubbleText = "R"; iconColor = Theme.accent
                case .searching: bubbleText = "?"; iconColor = Theme.cyan
                case .celebrating: bubbleText = "ok"; iconColor = Theme.green
                case .error: bubbleText = "!"; iconColor = Theme.red
                case .onBreak:
                    let z = String(repeating: "z", count: (frame/12%3)+1)
                    ctx.draw(Text(z).font(.system(size: 5, weight: .bold)).foregroundColor(Theme.textDim.opacity(0.4)),
                             at: CGPoint(x: bx + 8, y: by + sin(Double(frame)*0.1)*2))
                    bubbleText = nil; iconColor = .clear
                default: bubbleText = nil; iconColor = .clear
                }
            }

            if isSelected {
                ctx.fill(
                    Path(ellipseIn: CGRect(x: bx - 8, y: char.pixelY - 3.5, width: 16, height: 6)),
                    with: .color(tab.workerColor.opacity(dark ? 0.24 : 0.18))
                )
                ctx.stroke(
                    Path(ellipseIn: CGRect(x: bx - 9, y: char.pixelY - 4, width: 18, height: 7)),
                    with: .color(tab.workerColor.opacity(0.85)),
                    lineWidth: 1
                )
            }

            if let text = bubbleText {
                let bg = dark ? Color(hex: "1A2030") : Color.white
                let bw: CGFloat = max(20, CGFloat(text.count)*6+10)
                let bbx = bx - bw/2
                var tail = Path()
                tail.move(to: CGPoint(x: bx-2, y: by+13)); tail.addLine(to: CGPoint(x: bx, y: by+16)); tail.addLine(to: CGPoint(x: bx+2, y: by+13))
                ctx.fill(tail, with: .color(bg))
                ctx.fill(Path(roundedRect: CGRect(x: bbx, y: by, width: bw, height: 13), cornerRadius: 3), with: .color(bg))
                ctx.stroke(Path(roundedRect: CGRect(x: bbx, y: by, width: bw, height: 13), cornerRadius: 3), with: .color(iconColor.opacity(0.3)), lineWidth: 0.5)
                ctx.draw(Text(text).font(.system(size: 6, weight: .bold, design: .monospaced)).foregroundColor(iconColor),
                         at: CGPoint(x: bx, y: by+6.5))
            }

            drawHighFiveSparkIfNeeded(for: char)

            if !tab.officeParallelTasks.isEmpty {
                drawParallelTaskBubble(
                    ctx,
                    tab: tab,
                    anchorX: bx,
                    anchorY: parallelBubbleAnchorY(for: char, hasBubbleText: bubbleText != nil)
                )
            }

            if showToolBadges, let badge = tab.officeLatestToolBadge,
               !(badge.label == "DONE" && !tab.officeParallelTasks.isEmpty) {
                let badgeWidth = max(18, CGFloat(badge.label.count) * 4.4 + 8)
                let hasTopProjectBadge = tab.automationSourceTabId == nil && char.usesSeatPose
                let badgeY: CGFloat = (bubbleText != nil || hasTopProjectBadge || !tab.officeParallelTasks.isEmpty) ? by + 15 : by + 2
                let badgeX: CGFloat = (bubbleText != nil || hasTopProjectBadge || !tab.officeParallelTasks.isEmpty) ? bx - badgeWidth / 2 : bx + 9
                let badgeRect = CGRect(x: badgeX, y: badgeY, width: badgeWidth, height: 9)
                ctx.fill(Path(roundedRect: badgeRect, cornerRadius: 2.5),
                         with: .color((dark ? Color(hex: "111625") : Color.white).opacity(0.96)))
                ctx.stroke(Path(roundedRect: badgeRect, cornerRadius: 2.5),
                           with: .color(badge.tint.opacity(0.6)),
                           lineWidth: 0.6)
                ctx.draw(
                    Text(badge.label)
                        .font(.system(size: 5.4, weight: .heavy, design: .monospaced))
                        .foregroundColor(badge.tint),
                    at: CGPoint(x: badgeRect.midX, y: badgeRect.midY)
                )
            }

            if showFileLabels, let fileName = tab.officeLatestFileName,
               (isSelected || tab.claudeActivity == .writing) {
                let fileLabel = fileName.prefix(10)
                let fileWidth = max(24, CGFloat(fileLabel.count) * 4.1 + 8)
                let fileRect = CGRect(x: bx - fileWidth / 2, y: char.pixelY + 8, width: fileWidth, height: 8.5)
                ctx.fill(Path(roundedRect: fileRect, cornerRadius: 2),
                         with: .color((dark ? Color(hex: "0F1421") : Color.white).opacity(0.86)))
                ctx.stroke(Path(roundedRect: fileRect, cornerRadius: 2),
                           with: .color(Theme.green.opacity(0.26)),
                           lineWidth: 0.45)
                ctx.draw(
                    Text(String(fileLabel))
                        .font(.system(size: 4.8, weight: .bold, design: .monospaced))
                        .foregroundColor(Theme.green.opacity(0.92)),
                    at: CGPoint(x: fileRect.midX, y: fileRect.midY)
                )
            }

            if showNameLabels, tab.claudeActivity != .idle || tab.isProcessing || char.state == .onBreak || char.socialTimer > 0 || isSelected {
                ctx.draw(Text(tab.workerName).font(.system(size: 5, weight: .semibold, design: .monospaced))
                    .foregroundColor(tab.workerColor.opacity(isSelected ? 1 : 0.8)), at: CGPoint(x: bx, y: char.pixelY+6))
            }
        }

        // Zone labels removed for cleaner look
    }

    private func projectTint(for tab: TerminalTab) -> Color {
        let colors: [Color] = [Theme.accent, Theme.cyan, Theme.green, Theme.orange, Theme.purple, Theme.pink]
        let index = Int(UInt(bitPattern: tab.projectPath.hashValue) % UInt(max(colors.count, 1)))
        return colors[index]
    }
}
