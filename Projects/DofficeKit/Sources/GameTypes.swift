import SwiftUI
import DesignSystem

// ═══════════════════════════════════════════════════════
// MARK: - Level System
// ═══════════════════════════════════════════════════════

public struct WorkerLevel {
    public let level: Int
    public let title: String
    public let xpRequired: Int
    public let badge: String

    public init(level: Int, title: String, xpRequired: Int, badge: String) {
        self.level = level; self.title = title; self.xpRequired = xpRequired; self.badge = badge
    }

    // ── 칭호 테이블 (레벨 범위 → 칭호 + 배지) ──
    // 레벨이 올라갈수록 필요 XP가 지수적으로 증가
    // 레벨 상한 없음 — 무한히 오를 수 있음

    private struct TitleTier {
        let minLevel: Int
        let title: String
        let badge: String
    }

    private static let titleTiers: [TitleTier] = [
        TitleTier(minLevel: 1, title: NSLocalizedString("level.intern", comment: ""), badge: "🌱"),
        TitleTier(minLevel: 2, title: NSLocalizedString("level.junior", comment: ""), badge: "🔰"),
        TitleTier(minLevel: 3, title: NSLocalizedString("level.middle", comment: ""), badge: "⚙️"),
        TitleTier(minLevel: 5, title: NSLocalizedString("level.senior", comment: ""), badge: "🔧"),
        TitleTier(minLevel: 7, title: NSLocalizedString("level.lead", comment: ""), badge: "⭐"),
        TitleTier(minLevel: 10, title: NSLocalizedString("level.architect", comment: ""), badge: "🏗"),
        TitleTier(minLevel: 13, title: NSLocalizedString("level.cto", comment: ""), badge: "🎯"),
        TitleTier(minLevel: 16, title: NSLocalizedString("level.legend", comment: ""), badge: "🏆"),
        TitleTier(minLevel: 20, title: NSLocalizedString("level.god", comment: ""), badge: "👑"),
        TitleTier(minLevel: 25, title: NSLocalizedString("level.cosmos", comment: ""), badge: "🌌"),
        TitleTier(minLevel: 30, title: NSLocalizedString("level.saint", comment: ""), badge: "🌠"),
        TitleTier(minLevel: 35, title: NSLocalizedString("level.galaxy", comment: ""), badge: "🌌"),
        TitleTier(minLevel: 40, title: NSLocalizedString("level.supernova", comment: ""), badge: "☄️"),
        TitleTier(minLevel: 50, title: NSLocalizedString("level.dimension", comment: ""), badge: "🌀"),
        TitleTier(minLevel: 60, title: NSLocalizedString("level.singularity", comment: ""), badge: "♾️"),
        TitleTier(minLevel: 75, title: NSLocalizedString("level.transcendence", comment: ""), badge: "🔱"),
        TitleTier(minLevel: 90, title: NSLocalizedString("level.immortal", comment: ""), badge: "💎"),
        TitleTier(minLevel: 100, title: NSLocalizedString("level.absolute", comment: ""), badge: "🪐"),
        TitleTier(minLevel: 120, title: NSLocalizedString("level.myth", comment: ""), badge: "🔥"),
        TitleTier(minLevel: 150, title: NSLocalizedString("level.genesis", comment: ""), badge: "☀️"),
        TitleTier(minLevel: 200, title: NSLocalizedString("level.origin", comment: ""), badge: "🌅"),
        TitleTier(minLevel: 250, title: NSLocalizedString("level.infinity", comment: ""), badge: "∞"),
        TitleTier(minLevel: 300, title: NSLocalizedString("level.eternity", comment: ""), badge: "🕳️"),
        TitleTier(minLevel: 400, title: NSLocalizedString("level.time.lord", comment: ""), badge: "⏳"),
        TitleTier(minLevel: 500, title: NSLocalizedString("level.dimension.lord", comment: ""), badge: "🌐"),
        TitleTier(minLevel: 750, title: NSLocalizedString("level.multiverse.observer", comment: ""), badge: "👁️"),
        TitleTier(minLevel: 1000, title: NSLocalizedString("level.end.pioneer", comment: ""), badge: "🕊️"),
        TitleTier(minLevel: 1500, title: NSLocalizedString("level.source.of.being", comment: ""), badge: "🔮"),
        TitleTier(minLevel: 2000, title: NSLocalizedString("level.first.and.last", comment: ""), badge: "⚛️"),
        TitleTier(minLevel: 5000, title: NSLocalizedString("level.nameless", comment: ""), badge: "🌑"),
        TitleTier(minLevel: 10000, title: NSLocalizedString("level.concept.itself", comment: ""), badge: "💠"),
    ]

    // ── 레벨별 필요 XP 계산 (지수적 증가) ──
    // base=120, growth=1.14 → 저렙도 느리고, 고렙은 매우매우 느림
    // Lv5: ~700, Lv10: ~2,700, Lv20: ~18,000, Lv50: ~1.5M

    public static func xpForLevel(_ level: Int) -> Int {
        guard level > 1 else { return 0 }
        let base: Double = 120
        let growth: Double = 1.14
        var total: Double = 0
        for lv in 2...level {
            total += base * pow(growth, Double(lv - 2))
            if total > 1_000_000_000 { return Int(min(total, 1_000_000_000)) }
        }
        return Int(total)
    }

    public static func titleAndBadge(for level: Int) -> (title: String, badge: String) {
        let tier = titleTiers.last(where: { $0.minLevel <= level }) ?? titleTiers.first ?? TitleTier(minLevel: 1, title: "인턴", badge: "🐣")
        return (tier.title, tier.badge)
    }

    public static func forXP(_ xp: Int) -> WorkerLevel {
        // 이진 탐색으로 현재 레벨 찾기 (최대 200 레벨로 제한 — overflow 방지)
        var lo = 1, hi = 200
        while lo < hi {
            let mid = (lo + hi + 1) / 2
            let required = xpForLevel(mid)
            if required <= xp && required >= 0 {
                lo = mid
            } else {
                hi = mid - 1
            }
        }
        let level = lo
        let (title, badge) = titleAndBadge(for: level)
        return WorkerLevel(level: level, title: title, xpRequired: xpForLevel(level), badge: badge)
    }

    public static func progress(_ xp: Int) -> Double {
        let cur = forXP(xp)
        let curXP = xpForLevel(cur.level)
        let nextXP = xpForLevel(cur.level + 1)
        if nextXP <= curXP { return 1.0 }
        return Double(xp - curXP) / Double(nextXP - curXP)
    }

    public static func nextLevel(_ xp: Int) -> WorkerLevel? {
        let cur = forXP(xp)
        let nextLv = cur.level + 1
        let nextXP = xpForLevel(nextLv)
        let (title, badge) = titleAndBadge(for: nextLv)
        return WorkerLevel(level: nextLv, title: title, xpRequired: nextXP, badge: badge)
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - Achievement
// ═══════════════════════════════════════════════════════

public enum AchievementRarity: String, Codable {
    case common = "일반"
    case rare = "희귀"
    case epic = "영웅"
    case legendary = "전설"
    case mythic = "신화"

    public var displayName: String {
        switch self {
        case .common: return NSLocalizedString("rarity.common", comment: "")
        case .rare: return NSLocalizedString("rarity.rare", comment: "")
        case .epic: return NSLocalizedString("rarity.epic", comment: "")
        case .legendary: return NSLocalizedString("rarity.legendary", comment: "")
        case .mythic: return NSLocalizedString("rarity.mythic", comment: "")
        }
    }

    public var color: Color {
        switch self {
        case .common: return Theme.textSecondary
        case .rare: return Theme.accent
        case .epic: return Theme.purple
        case .legendary: return Theme.yellow
        case .mythic: return Theme.red
        }
    }

    public var bgGlow: Color {
        switch self {
        case .common: return .clear
        case .rare: return Theme.accent.opacity(0.1)
        case .epic: return Theme.purple.opacity(0.15)
        case .legendary: return Theme.yellow.opacity(0.2)
        case .mythic: return Theme.red.opacity(0.25)
        }
    }
}

public struct Achievement: Identifiable, Codable {
    public let id: String
    public let icon: String
    public let name: String
    public let description: String
    public let xpReward: Int
    public let rarity: AchievementRarity
    public var unlocked: Bool = false
    public var unlockedAt: Date?

    public init(id: String, icon: String, name: String, description: String, xpReward: Int, rarity: AchievementRarity, unlocked: Bool = false, unlockedAt: Date? = nil) {
        self.id = id; self.icon = icon; self.name = name; self.description = description
        self.xpReward = xpReward; self.rarity = rarity; self.unlocked = unlocked; self.unlockedAt = unlockedAt
    }

    public var localizedName: String {
        let key = "achievement.\(id).name"
        let localized = NSLocalizedString(key, comment: "")
        return localized == key ? name : localized
    }

    public var localizedDescription: String {
        let key = "achievement.\(id).desc"
        let localized = NSLocalizedString(key, comment: "")
        return localized == key ? description : localized
    }
}
