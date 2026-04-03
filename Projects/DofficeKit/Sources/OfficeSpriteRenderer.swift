import SwiftUI
import DesignSystem
import OrderedCollections

// ═══════════════════════════════════════════════════════
// MARK: - Office Sprite Renderer (Z-sorted Canvas)
// ═══════════════════════════════════════════════════════

public struct OfficeSpriteRenderer {
    public let map: OfficeMap
    public let characters: [String: OfficeCharacter]
    public let tabs: [TerminalTab]
    public let frame: Int
    public let dark: Bool
    public let theme: BackgroundTheme
    public let selectedTabId: String?
    public let selectedFurnitureId: String?
    public var chromeScreenshots: [String: CGImage] = [:]  // tabId → chrome screenshot
    /// Pre-built tab lookup table — avoids O(n) tabs.first(where:) per character
    internal let tabLookup: [String: TerminalTab]

    public init(map: OfficeMap, characters: [String: OfficeCharacter], tabs: [TerminalTab],
         frame: Int, dark: Bool, theme: BackgroundTheme,
         selectedTabId: String?, selectedFurnitureId: String?) {
        self.init(map: map, characters: characters, tabs: tabs,
                  frame: frame, dark: dark, theme: theme,
                  selectedTabId: selectedTabId, selectedFurnitureId: selectedFurnitureId,
                  cachedPalette: OfficeScenePalette(theme: theme, dark: dark))
    }

    /// Init with a pre-built palette to avoid recomputing it every frame.
    public init(map: OfficeMap, characters: [String: OfficeCharacter], tabs: [TerminalTab],
         frame: Int, dark: Bool, theme: BackgroundTheme,
         selectedTabId: String?, selectedFurnitureId: String?,
         cachedPalette: OfficeScenePalette) {
        self.map = map
        self.characters = characters
        self.tabs = tabs
        self.frame = frame
        self.dark = dark
        self.theme = theme
        self.selectedTabId = selectedTabId
        self.selectedFurnitureId = selectedFurnitureId
        self.palette = cachedPalette
        // Build O(1) tab lookup once instead of O(n) per character
        var lookup: [String: TerminalTab] = [:]
        lookup.reserveCapacity(tabs.count)
        for tab in tabs { lookup[tab.id] = tab }
        self.tabLookup = lookup
    }

    // Sprite cache: OrderedDictionary for LRU eviction (oldest = first entries)
    internal static var spriteCache: OrderedDictionary<String, CharacterSpriteSet> = [:]

    // Reusable Z-sort buffer — avoids per-frame heap allocation
    internal static var zBuffer: [ZDrawable] = []

    // Pre-allocated bubble text arrays to avoid per-frame allocation
    internal static let greetTexts0 = ["(ᵔᴥᵔ)", "ヾ(＾∇＾)", "(◕‿◕)", "\\(^o^)/"]
    internal static let greetTexts1 = ["(＾▽＾)", "(｡◕‿◕｡)", "٩(◕‿◕)۶", "(づ｡◕‿‿◕｡)づ"]
    internal static let chatTexts0 = ["(¬‿¬)", "ᕕ(ᐛ)ᕗ", "(•̀ᴗ•́)و", "( ˘▽˘)っ♨"]
    internal static let chatTexts1 = ["(≧◡≦)", "ʕ•ᴥ•ʔ", "(ノ◕ヮ◕)ノ*:・゚✧", "٩(♡ε♡)۶"]
    internal static let brainTexts0 = ["(°ロ°)☝", "φ(._.)メモメモ", "(⌐■_■)", "ᕦ(ò_óˇ)ᕤ"]
    internal static let brainTexts1 = ["(☞ﾟ∀ﾟ)☞", "( •_•)>⌐■-■", "ψ(._. )>", "(╯°□°)╯︵ ┻━┻"]
    internal static let coffeeTexts0 = ["☕(◕‿◕)", "(っ˘ω˘c)♨", "( ˘⌣˘)❤☕", "✧(˘⌣˘)☕"]
    internal static let coffeeTexts1 = ["(⊃˘▽˘)⊃☕", "☕(⌐■_■)", "(´∀`)♨", "☕✧(◕‿◕✿)"]
    internal static let highFiveTexts0 = ["(つ≧▽≦)つ", "ε=ε=(ノ≧∇≦)ノ", "(ﾉ◕ヮ◕)ﾉ*:・゚✧", "( •̀ω•́ )σ"]
    internal static let highFiveTexts1 = ["⊂(◉‿◉)つ", "(ノ´ヮ`)ノ*: ・゚✧", "\\(★ω★)/", "(*≧▽≦)ノシ"]

    // Pre-allocated activity reaction arrays to avoid per-frame allocation
    internal static let typingReactions = ["⌨️ ᵗᵃᵏ", "✎ ᵗᵃᵏ", "⌨ᵈᵃᵈᵃ", "⚡⌨⚡"]
    internal static let readingReactions = ["📖...", "🔍hmm", "👀...", "📄✓"]
    internal static let searchingReactions = ["🔎...", "🧐?", "🗂️...", "📂✓"]
    internal static let errorReactions = ["(╥_╥)", "╥﹏╥", "(ᗒᗣᗕ)՞", "( ꈨ◞ )"]
    internal static let thinkingReactions = ["(·_·)", "🤔...", "φ(._.)", "(ᵕ≀ᵕ)"]
    internal static let celebratingReactions = ["🎉✧", "\\(ᵔᵕᵔ)/", "٩(◕‿◕)۶", "★彡"]
    internal static let idleReactions = ["(¬_¬)", "(-_-) zzZ", "(˘ω˘)", "( ˙꒳˙ )"]
    internal static let windowColumns: Set<Int> = [3, 4, 5, 9, 10, 11, 15, 16, 17, 21, 22, 23, 31, 32, 33, 37, 38, 39]
    /// Computed once per renderer creation, not per property access
    public let palette: OfficeScenePalette

    // Static background cache: avoids redrawing ~8000 floor/wall draw calls every frame
    private static var cachedBackgroundImage: CGImage?
    private static var cachedBackgroundKey: String = ""
    private static let staticCachedTypes: Set<FurnitureType> = [.rug, .bookshelf, .whiteboard, .pictureFrame, .clock]
    public static func usesStaticBackgroundCache(for type: FurnitureType) -> Bool {
        staticCachedTypes.contains(type)
    }

    // MARK: - Main Render

    public func render(context: GraphicsContext, scale: CGFloat, offsetX: CGFloat, offsetY: CGFloat) {
        renderStaticBackground(context: context, scale: scale, offsetX: offsetX, offsetY: offsetY)
        renderDynamicLayers(context: context, scale: scale, offsetX: offsetX, offsetY: offsetY)
    }

    public func renderStaticBackground(context: GraphicsContext, scale: CGFloat, offsetX: CGFloat, offsetY: CGFloat) {
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
    public static func invalidateBackgroundCache() {
        cachedBackgroundImage = nil
        cachedBackgroundKey = ""
    }

    public func renderDynamicLayers(context: GraphicsContext, scale: CGFloat, offsetX: CGFloat, offsetY: CGFloat) {
        var ctx = context
        ctx.translateBy(x: offsetX, y: offsetY)
        ctx.scaleBy(x: scale, y: scale)
        drawZSortedScene(ctx)
        drawOverlays(ctx, viewScale: scale)
    }
}
