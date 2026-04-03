import SwiftUI
import DesignSystem
import OrderedCollections

// ═══════════════════════════════════════════════════
// MARK: - Z-Sorted Scene & Furniture Drawing
// ═══════════════════════════════════════════════════

extension OfficeSpriteRenderer {

    func drawCachedStaticFurniture(_ ctx: GraphicsContext) {
        for furniture in map.furniture where Self.usesStaticBackgroundCache(for: furniture.type) {
            let fx = CGFloat(furniture.position.col) * 16
            let fy = CGFloat(furniture.position.row) * 16
            let fw = CGFloat(furniture.size.w) * 16
            let fh = CGFloat(furniture.size.h) * 16
            Self.drawDetailedFurniture(ctx, type: furniture.type, x: fx, y: fy, w: fw, h: fh, dark: dark, frame: frame)
        }
    }

    func drawZSortedScene(_ ctx: GraphicsContext) {
        Self.zBuffer.removeAll(keepingCapacity: true)

        // Build seat lookup once per frame instead of per-monitor O(n) search
        let seatLookup: [String: Seat]
        if map.furniture.contains(where: { $0.type == .monitor }) {
            seatLookup = Dictionary(uniqueKeysWithValues: map.seats.map { ($0.id, $0) })
        } else {
            seatLookup = [:]
        }

        // Furniture
        for f in map.furniture {
            guard !Self.usesStaticBackgroundCache(for: f.type) else { continue }
            let fx = CGFloat(f.position.col) * 16
            let fy = CGFloat(f.position.row) * 16
            let fw = CGFloat(f.size.w) * 16
            let fh = CGFloat(f.size.h) * 16

            // 모니터의 경우 연결된 탭의 크롬 스크린샷 확인
            var chromeImg: CGImage? = nil
            if f.type == .monitor {
                let seatId = f.id.replacingOccurrences(of: "mon_", with: "seat_")
                if let seat = seatLookup[seatId],
                   let tabId = seat.assignedTabId {
                    chromeImg = chromeScreenshots[tabId]
                }
            }

            Self.zBuffer.append(ZDrawable(
                zY: f.zY,
                kind: .furniture(ZFurnitureInfo(
                    type: f.type, x: fx, y: fy, w: fw, h: fh,
                    dark: dark, frame: frame, chromeImage: chromeImg
                ))
            ))
        }

        // Characters
        for (_, char) in characters {
            let tab = char.tabId.flatMap { tabLookup[$0] }
            let rosterCharacter = CharacterRegistry.shared.character(with: char.rosterCharacterId)
            let workerColor = tab?.workerColor ?? Color(hex: Self.normalizedHex(char.accentColorHex))
            let hashSeed = tab?.id ?? char.rosterCharacterId ?? char.displayName
            let hashVal = hashSeed.hashValue

            Self.zBuffer.append(ZDrawable(
                zY: char.zY,
                kind: .character(ZCharacterInfo(
                    char: char, workerColor: workerColor, hashVal: hashVal,
                    dir: char.dir, state: char.state, frame: char.frame,
                    dark: dark, rosterCharacter: rosterCharacter
                ))
            ))
        }

        Self.zBuffer.sort { $0.zY < $1.zY }

        for drawable in Self.zBuffer {
            switch drawable.kind {
            case .furniture(let info):
                Self.drawDetailedFurniture(ctx, type: info.type, x: info.x, y: info.y,
                                           w: info.w, h: info.h, dark: info.dark, frame: info.frame)
                if info.type == .monitor, let img = info.chromeImage {
                    let screenX = info.x + 2.5
                    let screenY = info.y + 1.5
                    let screenW = info.w - 5
                    let screenH = info.h - 7
                    ctx.draw(Image(decorative: img, scale: 1),
                             in: CGRect(x: screenX, y: screenY, width: screenW, height: screenH))
                }
            case .character(let info):
                Self.drawCharacterSprite(ctx, char: info.char, workerColor: info.workerColor,
                                         hashVal: info.hashVal, dir: info.dir, state: info.state,
                                         frame: info.frame, dark: info.dark, rosterCharacter: info.rosterCharacter)
            }
        }
    }

    // ═══════════════════════════════════════════════════
    // MARK: - Detailed Furniture Drawing
    // ═══════════════════════════════════════════════════

    internal static func drawDetailedFurniture(_ ctx: GraphicsContext, type: FurnitureType,
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

    internal static func drawFurnitureAmbientShadow(
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
    internal static func drawDesk(_ ctx: GraphicsContext, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, dark: Bool) {
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
    internal static func drawMonitor(_ ctx: GraphicsContext, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, dark: Bool, frame: Int) {
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
    internal static func drawChair(_ ctx: GraphicsContext, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, dark: Bool) {
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
    internal static func drawPlant(_ ctx: GraphicsContext, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, dark: Bool, frame: Int) {
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
    internal static func drawCoffeeMachine(_ ctx: GraphicsContext, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, dark: Bool, frame: Int) {
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
    internal static func drawSofa(_ ctx: GraphicsContext, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, dark: Bool) {
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
    internal static func drawWhiteboard(_ ctx: GraphicsContext, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, dark: Bool) {
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
    internal static func drawBookshelf(_ ctx: GraphicsContext, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, dark: Bool) {
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
    internal static func drawRoundTable(_ ctx: GraphicsContext, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, dark: Bool) {
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
    internal static func drawWaterCooler(_ ctx: GraphicsContext, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, dark: Bool, frame: Int) {
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
    internal static func drawPrinter(_ ctx: GraphicsContext, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, dark: Bool) {
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
    internal static func drawTrashBin(_ ctx: GraphicsContext, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, dark: Bool) {
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
    internal static func drawLamp(_ ctx: GraphicsContext, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, dark: Bool, frame: Int) {
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
    internal static func drawRug(_ ctx: GraphicsContext, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, dark: Bool) {
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
    internal static func drawPictureFrame(_ ctx: GraphicsContext, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, dark: Bool) {
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
    internal static func drawClock(_ ctx: GraphicsContext, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, dark: Bool, frame: Int) {
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

    internal static func snappedPixel(_ value: CGFloat) -> CGFloat {
        value.rounded(.toNearestOrAwayFromZero)
    }

    internal static func drawCharacterSprite(_ ctx: GraphicsContext, char: OfficeCharacter, workerColor: Color,
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
            // Move to end (most recently used) for LRU ordering
            Self.spriteCache.removeValue(forKey: cacheKey)
            Self.spriteCache[cacheKey] = cached
            sprites = cached
        } else {
            // LRU eviction — remove oldest entries (front of OrderedDictionary)
            if Self.spriteCache.count > 50 {
                let removeCount = Self.spriteCache.count / 2
                Self.spriteCache.removeFirst(removeCount)
            }
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

        // Pixel render — batch contiguous same-color pixels into single rects per row
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

            let row = sprite[y]
            let rowY = snappedPixel(drawY + CGFloat(y) + rowShiftY)
            var runStart = -1
            var runHex = ""

            for x in 0..<row.count {
                let hex = row[x]
                if hex == runHex && !hex.isEmpty {
                    continue  // extend current run
                }
                // Flush previous run
                if !runHex.isEmpty && runStart >= 0 {
                    let runLen = CGFloat(x - runStart)
                    ctx.fill(Path(CGRect(
                        x: snappedPixel(drawX + CGFloat(runStart) + rowShiftX),
                        y: rowY, width: runLen * 1.15, height: 1.15
                    )), with: .color(Color(hex: runHex)))
                }
                runStart = x
                runHex = hex
            }
            // Flush last run
            if !runHex.isEmpty && runStart >= 0 {
                let runLen = CGFloat(row.count - runStart)
                ctx.fill(Path(CGRect(
                    x: snappedPixel(drawX + CGFloat(runStart) + rowShiftX),
                    y: rowY, width: runLen * 1.15, height: 1.15
                )), with: .color(Color(hex: runHex)))
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

    internal static func colorToHex(_ color: Color) -> String {
        guard let c = NSColor(color).usingColorSpace(.sRGB) else { return "5B9CF6" }
        return String(format: "%02X%02X%02X", Int(c.redComponent * 255), Int(c.greenComponent * 255), Int(c.blueComponent * 255))
    }

    internal static func normalizedHex(_ hex: String) -> String {
        hex.replacingOccurrences(of: "#", with: "").uppercased()
    }

    internal static func shadeHex(_ hex: String, by delta: CGFloat) -> String {
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

    internal static func blendHex(_ hexA: String, _ hexB: String, ratio: CGFloat) -> String {
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

    internal static func drawCharacterDetails(
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
}
