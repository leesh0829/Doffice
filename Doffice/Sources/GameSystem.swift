import SwiftUI

// ═══════════════════════════════════════════════════════
// MARK: - Level System
// ═══════════════════════════════════════════════════════

struct WorkerLevel {
    let level: Int
    let title: String
    let xpRequired: Int
    let badge: String

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

    static func xpForLevel(_ level: Int) -> Int {
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

    static func titleAndBadge(for level: Int) -> (title: String, badge: String) {
        let tier = titleTiers.last(where: { $0.minLevel <= level }) ?? titleTiers.first ?? TitleTier(minLevel: 1, title: "인턴", badge: "🐣")
        return (tier.title, tier.badge)
    }

    static func forXP(_ xp: Int) -> WorkerLevel {
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

    static func progress(_ xp: Int) -> Double {
        let cur = forXP(xp)
        let curXP = xpForLevel(cur.level)
        let nextXP = xpForLevel(cur.level + 1)
        if nextXP <= curXP { return 1.0 }
        return Double(xp - curXP) / Double(nextXP - curXP)
    }

    static func nextLevel(_ xp: Int) -> WorkerLevel? {
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

enum AchievementRarity: String, Codable {
    case common = "일반"
    case rare = "희귀"
    case epic = "영웅"
    case legendary = "전설"
    case mythic = "신화"

    var displayName: String {
        switch self {
        case .common: return NSLocalizedString("rarity.common", comment: "")
        case .rare: return NSLocalizedString("rarity.rare", comment: "")
        case .epic: return NSLocalizedString("rarity.epic", comment: "")
        case .legendary: return NSLocalizedString("rarity.legendary", comment: "")
        case .mythic: return NSLocalizedString("rarity.mythic", comment: "")
        }
    }

    var color: Color {
        switch self {
        case .common: return Theme.textSecondary
        case .rare: return Theme.accent
        case .epic: return Theme.purple
        case .legendary: return Theme.yellow
        case .mythic: return Theme.red
        }
    }

    var bgGlow: Color {
        switch self {
        case .common: return .clear
        case .rare: return Theme.accent.opacity(0.1)
        case .epic: return Theme.purple.opacity(0.15)
        case .legendary: return Theme.yellow.opacity(0.2)
        case .mythic: return Theme.red.opacity(0.25)
        }
    }
}

struct Achievement: Identifiable, Codable {
    let id: String
    let icon: String
    let name: String
    let description: String
    let xpReward: Int
    let rarity: AchievementRarity
    var unlocked: Bool = false
    var unlockedAt: Date?

    var localizedName: String {
        let key = "achievement.\(id).name"
        let localized = NSLocalizedString(key, comment: "")
        return localized == key ? name : localized
    }

    var localizedDescription: String {
        let key = "achievement.\(id).desc"
        let localized = NSLocalizedString(key, comment: "")
        return localized == key ? description : localized
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - Achievement Manager
// ═══════════════════════════════════════════════════════

class AchievementManager: ObservableObject {
    static let shared = AchievementManager()

    @Published var achievements: [Achievement] = [
        // ─────────────────────────────────────────────
        // Common (일반) — 쉽게 달성 가능
        // ─────────────────────────────────────────────
        Achievement(id: "first_session", icon: "🎬", name: "첫 걸음", description: "첫 번째 세션을 시작했다", xpReward: 30, rarity: .common),
        Achievement(id: "first_complete", icon: "✅", name: "완료!", description: "첫 번째 작업을 완료했다", xpReward: 30, rarity: .common),
        Achievement(id: "first_bash", icon: "💻", name: "첫 명령어", description: "첫 Bash 명령을 실행했다", xpReward: 20, rarity: .common),
        Achievement(id: "first_edit", icon: "✏️", name: "첫 수정", description: "첫 번째 파일을 수정했다", xpReward: 20, rarity: .common),
        Achievement(id: "command_10", icon: "🔟", name: "열 번의 손짓", description: "명령을 10번 실행했다", xpReward: 25, rarity: .common),
        Achievement(id: "complete_5", icon: "🖐", name: "다섯 번째 성공", description: "작업을 5번 완료했다", xpReward: 30, rarity: .common),
        Achievement(id: "complete_10", icon: "🔄", name: "열 번째 성공", description: "작업을 10번 완료했다", xpReward: 35, rarity: .common),
        Achievement(id: "session_10", icon: "📋", name: "열 번째 출근", description: "세션을 10번 시작했다", xpReward: 30, rarity: .common),
        Achievement(id: "token_first_1k", icon: "🪙", name: "첫 천 토큰", description: "누적 1,000 토큰을 사용했다", xpReward: 25, rarity: .common),
        Achievement(id: "weekend_warrior", icon: "🎮", name: "주말 전사", description: "주말에 작업했다", xpReward: 30, rarity: .common),
        Achievement(id: "read_10", icon: "📖", name: "독서가", description: "한 세션에서 파일을 10번 읽었다", xpReward: 25, rarity: .common),
        Achievement(id: "cost_first", icon: "💵", name: "첫 지출", description: "API 비용이 발생했다", xpReward: 20, rarity: .common),
        Achievement(id: "five_sessions", icon: "🖐🏻", name: "다섯 손가락", description: "5개 세션을 동시에 실행했다", xpReward: 40, rarity: .common),
        Achievement(id: "file_edit_5", icon: "📝", name: "다섯 줄 수정", description: "파일을 5번 수정했다", xpReward: 25, rarity: .common),
        Achievement(id: "monday_blues", icon: "😩", name: "월요병", description: "월요일에 작업했다", xpReward: 25, rarity: .common),
        Achievement(id: "friday_coder", icon: "🎉", name: "불금 코더", description: "금요일에 작업했다", xpReward: 25, rarity: .common),

        // ─────────────────────────────────────────────
        // Rare (희귀) — 중간 난이도
        // ─────────────────────────────────────────────
        Achievement(id: "night_owl", icon: "🦉", name: "야행성", description: "자정~새벽 5시 사이에 작업했다", xpReward: 50, rarity: .rare),
        Achievement(id: "early_bird", icon: "🐦", name: "얼리버드", description: "새벽 4~6시 사이에 작업했다", xpReward: 50, rarity: .rare),
        Achievement(id: "speed_demon", icon: "⚡", name: "스피드 데몬", description: "5분 안에 작업을 완료했다", xpReward: 50, rarity: .rare),
        Achievement(id: "multi_tasker", icon: "🤹", name: "멀티태스커", description: "3개 이상 동시에 작업했다", xpReward: 50, rarity: .rare),
        Achievement(id: "pair_programmer", icon: "👯", name: "페어 프로그래머", description: "같은 프로젝트에 2명을 배정했다", xpReward: 50, rarity: .rare),
        Achievement(id: "bug_squasher", icon: "🪲", name: "벌레 사냥꾼", description: "에러 상태에서 복구했다", xpReward: 50, rarity: .rare),
        Achievement(id: "token_saver", icon: "💰", name: "절약왕", description: "1k 토큰 이하로 작업을 완료했다", xpReward: 50, rarity: .rare),
        Achievement(id: "command_50", icon: "5️⃣", name: "반백", description: "명령을 50번 실행했다", xpReward: 45, rarity: .rare),
        Achievement(id: "complete_25", icon: "🎖", name: "숙련공", description: "작업을 25번 완료했다", xpReward: 50, rarity: .rare),
        Achievement(id: "session_25", icon: "📊", name: "출근왕", description: "세션을 25번 시작했다", xpReward: 45, rarity: .rare),
        Achievement(id: "lunch_coder", icon: "🍱", name: "점심시간 코더", description: "점심시간(12~13시)에 작업했다", xpReward: 40, rarity: .rare),
        Achievement(id: "file_surgeon", icon: "🔪", name: "외과의사", description: "한 세션에서 5개 이상 파일을 수정했다", xpReward: 50, rarity: .rare),
        Achievement(id: "cost_1", icon: "💲", name: "첫 달러", description: "누적 비용 $1을 넘었다", xpReward: 50, rarity: .rare),
        Achievement(id: "focus_30", icon: "🧘", name: "집중력", description: "30분 이상 연속 작업했다", xpReward: 45, rarity: .rare),
        Achievement(id: "error_5", icon: "💪", name: "불굴의 의지", description: "에러에서 5번 복구했다", xpReward: 55, rarity: .rare),
        Achievement(id: "opus_user", icon: "🟣", name: "오퍼스 유저", description: "Opus 모델을 사용했다", xpReward: 40, rarity: .rare),
        Achievement(id: "haiku_user", icon: "🟢", name: "하이쿠 유저", description: "Haiku 모델을 사용했다", xpReward: 40, rarity: .rare),
        Achievement(id: "token_10k_total", icon: "📈", name: "만 토큰 클럽", description: "누적 10,000 토큰을 사용했다", xpReward: 50, rarity: .rare),
        Achievement(id: "git_first_branch", icon: "🌱", name: "가지치기", description: "Git 브랜치에서 작업했다", xpReward: 35, rarity: .rare),
        Achievement(id: "session_streak_3", icon: "🔥", name: "3일 연속", description: "3일 연속으로 작업했다", xpReward: 55, rarity: .rare),
        Achievement(id: "night_complete", icon: "🌙", name: "달빛 코더", description: "밤 10시 이후에 작업을 완료했다", xpReward: 40, rarity: .rare),
        Achievement(id: "morning_complete", icon: "🌅", name: "아침형 인간", description: "오전 9시 전에 작업을 완료했다", xpReward: 40, rarity: .rare),
        Achievement(id: "file_edit_25", icon: "🗂", name: "정리의 달인", description: "파일을 25번 수정했다", xpReward: 45, rarity: .rare),
        Achievement(id: "file_edit_50", icon: "📚", name: "리팩토링 장인", description: "파일을 50번 수정했다", xpReward: 55, rarity: .rare),
        Achievement(id: "cost_5", icon: "💳", name: "구독자", description: "누적 비용 $5를 넘었다", xpReward: 45, rarity: .rare),
        Achievement(id: "read_50", icon: "🔍", name: "탐정", description: "파일을 50번 읽었다", xpReward: 45, rarity: .rare),
        Achievement(id: "dawn_warrior", icon: "🌄", name: "새벽 전사", description: "새벽 3시에 작업 중이었다", xpReward: 55, rarity: .rare),
        Achievement(id: "token_5k_session", icon: "📊", name: "알찬 세션", description: "한 세션에서 5k 이상 토큰을 사용했다", xpReward: 45, rarity: .rare),

        // ─────────────────────────────────────────────
        // Epic (영웅) — 높은 난이도
        // ─────────────────────────────────────────────
        Achievement(id: "marathon", icon: "🏃", name: "마라톤", description: "1시간 이상 연속으로 작업했다", xpReward: 80, rarity: .epic),
        Achievement(id: "git_master", icon: "🌿", name: "Git 마스터", description: "한 세션에서 10개 이상 파일을 변경했다", xpReward: 80, rarity: .epic),
        Achievement(id: "centurion", icon: "💯", name: "백전노장", description: "명령을 100번 실행했다", xpReward: 80, rarity: .epic),
        Achievement(id: "token_whale", icon: "🐋", name: "토큰 고래", description: "한 세션에서 10k 이상 토큰을 사용했다", xpReward: 80, rarity: .epic),
        Achievement(id: "complete_50", icon: "🏅", name: "베테랑", description: "작업을 50번 완료했다", xpReward: 80, rarity: .epic),
        Achievement(id: "complete_100", icon: "🎯", name: "백전백승", description: "작업을 100번 완료했다", xpReward: 100, rarity: .epic),
        Achievement(id: "command_500", icon: "⚔️", name: "오백장군", description: "명령을 500번 실행했다", xpReward: 90, rarity: .epic),
        Achievement(id: "session_50", icon: "🏢", name: "근속상", description: "세션을 50번 시작했다", xpReward: 80, rarity: .epic),
        Achievement(id: "ultra_marathon", icon: "🏔", name: "울트라 마라톤", description: "3시간 이상 연속으로 작업했다", xpReward: 100, rarity: .epic),
        Achievement(id: "cost_10", icon: "💎", name: "큰손", description: "누적 비용 $10을 넘었다", xpReward: 90, rarity: .epic),
        Achievement(id: "token_100k_total", icon: "🏦", name: "토큰 부자", description: "누적 100,000 토큰을 사용했다", xpReward: 90, rarity: .epic),
        Achievement(id: "git_master_25", icon: "🌳", name: "Git 장인", description: "한 세션에서 25개 이상 파일을 변경했다", xpReward: 90, rarity: .epic),
        Achievement(id: "multi_5", icon: "🎪", name: "오케스트라 지휘자", description: "5개 이상 동시에 작업했다", xpReward: 85, rarity: .epic),
        Achievement(id: "error_10", icon: "🔥", name: "불사조", description: "에러에서 10번 복구했다", xpReward: 85, rarity: .epic),
        Achievement(id: "speed_2min", icon: "🚀", name: "번개", description: "2분 안에 작업을 완료했다", xpReward: 85, rarity: .epic),
        Achievement(id: "night_marathon", icon: "🌃", name: "야간 마라톤", description: "자정~5시에 1시간 이상 작업했다", xpReward: 95, rarity: .epic),
        Achievement(id: "three_models", icon: "🎨", name: "삼총사", description: "세 가지 모델을 모두 사용했다", xpReward: 80, rarity: .epic),
        Achievement(id: "session_streak_7", icon: "📆", name: "7일 연속", description: "7일 연속으로 작업했다", xpReward: 100, rarity: .epic),
        Achievement(id: "token_50k_session", icon: "🐳", name: "메가 세션", description: "한 세션에서 50k 이상 토큰을 사용했다", xpReward: 90, rarity: .epic),
        Achievement(id: "git_branch_5", icon: "🌲", name: "브랜치 달인", description: "5개 이상 다른 브랜치에서 작업했다", xpReward: 80, rarity: .epic),
        Achievement(id: "file_surgeon_10", icon: "⚕️", name: "집도의", description: "한 세션에서 10개 이상 파일을 수정했다", xpReward: 85, rarity: .epic),
        Achievement(id: "complete_200", icon: "🎗", name: "프로", description: "작업을 200번 완료했다", xpReward: 90, rarity: .epic),
        Achievement(id: "file_edit_100", icon: "🏗", name: "건축가", description: "파일을 100번 수정했다", xpReward: 85, rarity: .epic),
        Achievement(id: "read_200", icon: "📚", name: "학자", description: "파일을 200번 읽었다", xpReward: 80, rarity: .epic),
        Achievement(id: "error_25", icon: "🛡", name: "방패", description: "에러에서 25번 복구했다", xpReward: 95, rarity: .epic),
        Achievement(id: "cost_50", icon: "💰", name: "투자자", description: "누적 비용 $50을 넘었다", xpReward: 95, rarity: .epic),
        Achievement(id: "session_streak_14", icon: "🗓", name: "2주 연속", description: "14일 연속으로 작업했다", xpReward: 100, rarity: .epic),
        Achievement(id: "git_branch_10", icon: "🌴", name: "숲의 관리자", description: "10개 이상 다른 브랜치에서 작업했다", xpReward: 90, rarity: .epic),
        Achievement(id: "token_500k_total", icon: "🏧", name: "토큰 재벌", description: "누적 500,000 토큰을 사용했다", xpReward: 95, rarity: .epic),
        Achievement(id: "speed_1min", icon: "💨", name: "섬광", description: "1분 안에 작업을 완료했다", xpReward: 100, rarity: .epic),
        Achievement(id: "marathon_6h", icon: "🏕", name: "캠프파이어", description: "6시간 이상 연속으로 작업했다", xpReward: 110, rarity: .epic),
        Achievement(id: "token_100k_session", icon: "🦈", name: "메갈로돈", description: "한 세션에서 100k 이상 토큰을 사용했다", xpReward: 100, rarity: .epic),
        Achievement(id: "git_master_50", icon: "🏔", name: "산을 옮기다", description: "한 세션에서 50개 이상 파일을 변경했다", xpReward: 100, rarity: .epic),
        Achievement(id: "session_75", icon: "🎓", name: "졸업", description: "세션을 75번 시작했다", xpReward: 90, rarity: .epic),
        Achievement(id: "read_500", icon: "🧠", name: "브레인", description: "파일을 500번 읽었다", xpReward: 90, rarity: .epic),
        Achievement(id: "file_edit_200", icon: "⚒", name: "대장장이", description: "파일을 200번 수정했다", xpReward: 90, rarity: .epic),
        Achievement(id: "complete_300", icon: "🗻", name: "등산가", description: "작업을 300번 완료했다", xpReward: 95, rarity: .epic),
        Achievement(id: "night_owl_10", icon: "🦇", name: "박쥐", description: "심야 작업을 10일 이상 했다", xpReward: 95, rarity: .epic),

        // ─────────────────────────────────────────────
        // Legendary (전설) — 매우 높은 난이도
        // ─────────────────────────────────────────────
        Achievement(id: "level_5", icon: "⭐", name: "스타 개발자", description: "레벨 5에 도달했다", xpReward: 150, rarity: .legendary),
        Achievement(id: "level_8", icon: "🏆", name: "전설의 시작", description: "레벨 8에 도달했다", xpReward: 200, rarity: .legendary),
        Achievement(id: "level_10", icon: "🌌", name: "우주의 끝", description: "레벨 10에 도달했다", xpReward: 300, rarity: .legendary),
        Achievement(id: "complete_500", icon: "👑", name: "천하무적", description: "작업을 500번 완료했다", xpReward: 250, rarity: .legendary),
        Achievement(id: "command_1000", icon: "🗡", name: "천 번의 손짓", description: "명령을 1,000번 실행했다", xpReward: 200, rarity: .legendary),
        Achievement(id: "command_5000", icon: "⚜️", name: "만능 해커", description: "명령을 5,000번 실행했다", xpReward: 300, rarity: .legendary),
        Achievement(id: "session_100", icon: "🏛", name: "출퇴근 달인", description: "세션을 100번 시작했다", xpReward: 200, rarity: .legendary),
        Achievement(id: "token_million", icon: "💫", name: "백만장자", description: "누적 1,000,000 토큰을 사용했다", xpReward: 250, rarity: .legendary),
        Achievement(id: "cost_100", icon: "🤑", name: "큰 후원자", description: "누적 비용 $100을 넘었다", xpReward: 200, rarity: .legendary),
        Achievement(id: "session_streak_30", icon: "🔱", name: "30일 연속", description: "30일 연속으로 작업했다", xpReward: 300, rarity: .legendary),
        Achievement(id: "perfectionist", icon: "🎆", name: "완벽주의자", description: "전설 등급 외 모든 업적을 달성했다", xpReward: 500, rarity: .legendary),
        Achievement(id: "complete_1000", icon: "🐉", name: "용", description: "작업을 1,000번 완료했다", xpReward: 400, rarity: .legendary),
        Achievement(id: "command_10000", icon: "🌠", name: "별을 헤아리며", description: "명령을 10,000번 실행했다", xpReward: 350, rarity: .legendary),
        Achievement(id: "file_edit_500", icon: "🗿", name: "불멸의 조각가", description: "파일을 500번 수정했다", xpReward: 300, rarity: .legendary),
        Achievement(id: "error_50", icon: "🔮", name: "예언자", description: "에러에서 50번 복구했다", xpReward: 250, rarity: .legendary),
        Achievement(id: "session_streak_100", icon: "💎", name: "다이아몬드", description: "100일 연속으로 작업했다", xpReward: 500, rarity: .legendary),
        Achievement(id: "session_500", icon: "🏰", name: "성을 쌓다", description: "세션을 500번 시작했다", xpReward: 350, rarity: .legendary),
        Achievement(id: "cost_500", icon: "🏦", name: "은행장", description: "누적 비용 $500을 넘었다", xpReward: 350, rarity: .legendary),
        Achievement(id: "token_5million", icon: "🪐", name: "행성", description: "누적 5,000,000 토큰을 사용했다", xpReward: 400, rarity: .legendary),
        Achievement(id: "complete_2000", icon: "☀️", name: "태양", description: "작업을 2,000번 완료했다", xpReward: 500, rarity: .legendary),
        Achievement(id: "session_streak_365", icon: "♾️", name: "무한", description: "365일 연속으로 작업했다", xpReward: 1000, rarity: .legendary),
        Achievement(id: "command_50000", icon: "🔨", name: "광부", description: "명령을 50,000번 실행했다", xpReward: 500, rarity: .legendary),
        Achievement(id: "level_15", icon: "🌟", name: "별 중의 별", description: "레벨 15에 도달했다", xpReward: 400, rarity: .legendary),
        Achievement(id: "level_20", icon: "💠", name: "다이아몬드 코어", description: "레벨 20에 도달했다", xpReward: 500, rarity: .legendary),
        Achievement(id: "complete_3000", icon: "🏹", name: "만발의 궁수", description: "작업을 3,000번 완료했다", xpReward: 500, rarity: .legendary),
        Achievement(id: "command_20000", icon: "⛏️", name: "채굴왕", description: "명령을 20,000번 실행했다", xpReward: 400, rarity: .legendary),
        Achievement(id: "session_2000", icon: "🏙", name: "도시를 세우다", description: "세션을 2,000번 시작했다", xpReward: 450, rarity: .legendary),
        Achievement(id: "token_10million", icon: "🌍", name: "지구", description: "누적 10,000,000 토큰을 사용했다", xpReward: 500, rarity: .legendary),
        Achievement(id: "cost_1000", icon: "🏦", name: "재벌", description: "누적 비용 $1,000을 넘었다", xpReward: 500, rarity: .legendary),
        Achievement(id: "file_edit_1000", icon: "🏗️", name: "마천루", description: "파일을 1,000번 수정했다", xpReward: 400, rarity: .legendary),
        Achievement(id: "read_1000", icon: "🔬", name: "연구원", description: "파일을 1,000번 읽었다", xpReward: 350, rarity: .legendary),
        Achievement(id: "read_2000", icon: "🧬", name: "게놈 해독자", description: "파일을 2,000번 읽었다", xpReward: 400, rarity: .legendary),
        Achievement(id: "error_100", icon: "🧱", name: "만리장성", description: "에러에서 100번 복구했다", xpReward: 400, rarity: .legendary),
        Achievement(id: "git_branch_30", icon: "🌲", name: "고목나무", description: "30개 이상 다른 브랜치에서 작업했다", xpReward: 350, rarity: .legendary),
        Achievement(id: "git_branch_50", icon: "🏞", name: "밀림 탐험가", description: "50개 이상 다른 브랜치에서 작업했다", xpReward: 400, rarity: .legendary),
        Achievement(id: "night_owl_50", icon: "🌑", name: "암흑의 제왕", description: "심야 작업을 50일 이상 했다", xpReward: 400, rarity: .legendary),
        Achievement(id: "session_streak_60", icon: "📿", name: "60일 연속", description: "60일 연속으로 작업했다", xpReward: 450, rarity: .legendary),
        Achievement(id: "session_streak_180", icon: "🧭", name: "반년의 여정", description: "180일 연속으로 작업했다", xpReward: 600, rarity: .legendary),
        Achievement(id: "marathon_12h", icon: "🏜", name: "사막 횡단", description: "12시간 이상 연속으로 작업했다", xpReward: 500, rarity: .legendary),
        Achievement(id: "weekend_50", icon: "🎪", name: "주말의 지배자", description: "주말에 50일 이상 작업했다", xpReward: 400, rarity: .legendary),
        Achievement(id: "multi_7", icon: "🎰", name: "럭키 세븐", description: "7개 이상 동시에 작업했다", xpReward: 400, rarity: .legendary),
        Achievement(id: "git_master_100", icon: "🌋", name: "화산 폭발", description: "한 세션에서 100개 이상 파일을 변경했다", xpReward: 450, rarity: .legendary),
        Achievement(id: "token_200k_session", icon: "🐘", name: "매머드", description: "한 세션에서 200k 이상 토큰을 사용했다", xpReward: 450, rarity: .legendary),
        Achievement(id: "file_surgeon_25", icon: "🏥", name: "종합병원", description: "한 세션에서 25개 이상 파일을 수정했다", xpReward: 400, rarity: .legendary),

        // ─────────────────────────────────────────────
        // Mythic (신화) — 극한 난이도, 오랜 사용만이 가능
        // ─────────────────────────────────────────────
        Achievement(id: "complete_5000", icon: "🐲", name: "용왕", description: "작업을 5,000번 완료했다", xpReward: 800, rarity: .mythic),
        Achievement(id: "complete_10000", icon: "🕳️", name: "블랙홀", description: "작업을 10,000번 완료했다", xpReward: 1500, rarity: .mythic),
        Achievement(id: "command_100000", icon: "🌌", name: "은하수", description: "명령을 100,000번 실행했다", xpReward: 1000, rarity: .mythic),
        Achievement(id: "command_500000", icon: "🔭", name: "관측 가능한 우주", description: "명령을 500,000번 실행했다", xpReward: 2000, rarity: .mythic),
        Achievement(id: "session_5000", icon: "🌐", name: "글로벌 네트워크", description: "세션을 5,000번 시작했다", xpReward: 800, rarity: .mythic),
        Achievement(id: "session_10000", icon: "🪐", name: "항성계", description: "세션을 10,000번 시작했다", xpReward: 1500, rarity: .mythic),
        Achievement(id: "token_50million", icon: "🌞", name: "항성", description: "누적 50,000,000 토큰을 사용했다", xpReward: 1000, rarity: .mythic),
        Achievement(id: "token_100million", icon: "💥", name: "빅뱅", description: "누적 100,000,000 토큰을 사용했다", xpReward: 1500, rarity: .mythic),
        Achievement(id: "token_1billion", icon: "🔮", name: "오메가 포인트", description: "누적 1,000,000,000 토큰을 사용했다", xpReward: 3000, rarity: .mythic),
        Achievement(id: "token_500k_session", icon: "🦕", name: "브론토사우루스", description: "한 세션에서 500k 이상 토큰을 사용했다", xpReward: 800, rarity: .mythic),
        Achievement(id: "token_1m_session", icon: "☄️", name: "혜성 충돌", description: "한 세션에서 1M 이상 토큰을 사용했다", xpReward: 1200, rarity: .mythic),
        Achievement(id: "cost_5000", icon: "👸", name: "여왕", description: "누적 비용 $5,000을 넘었다", xpReward: 1000, rarity: .mythic),
        Achievement(id: "cost_10000", icon: "🤴", name: "황제", description: "누적 비용 $10,000을 넘었다", xpReward: 1500, rarity: .mythic),
        Achievement(id: "cost_50000", icon: "🏛️", name: "연방 예산", description: "누적 비용 $50,000을 넘었다", xpReward: 3000, rarity: .mythic),
        Achievement(id: "file_edit_2000", icon: "⚙️", name: "기계 심장", description: "파일을 2,000번 수정했다", xpReward: 700, rarity: .mythic),
        Achievement(id: "file_edit_5000", icon: "🧬", name: "진화", description: "파일을 5,000번 수정했다", xpReward: 1000, rarity: .mythic),
        Achievement(id: "file_edit_10000", icon: "🌊", name: "쓰나미", description: "파일을 10,000번 수정했다", xpReward: 1500, rarity: .mythic),
        Achievement(id: "file_edit_50000", icon: "🏔️", name: "에베레스트", description: "파일을 50,000번 수정했다", xpReward: 3000, rarity: .mythic),
        Achievement(id: "read_5000", icon: "📡", name: "위성 수신", description: "파일을 5,000번 읽었다", xpReward: 800, rarity: .mythic),
        Achievement(id: "read_10000", icon: "🛸", name: "외계 통신", description: "파일을 10,000번 읽었다", xpReward: 1200, rarity: .mythic),
        Achievement(id: "read_50000", icon: "🧠", name: "초지능", description: "파일을 50,000번 읽었다", xpReward: 2000, rarity: .mythic),
        Achievement(id: "error_200", icon: "🦾", name: "사이보그", description: "에러에서 200번 복구했다", xpReward: 800, rarity: .mythic),
        Achievement(id: "error_500", icon: "🤖", name: "터미네이터", description: "에러에서 500번 복구했다", xpReward: 1500, rarity: .mythic),
        Achievement(id: "error_1000", icon: "🛡️", name: "절대 방패", description: "에러에서 1,000번 복구했다", xpReward: 2500, rarity: .mythic),
        Achievement(id: "git_branch_100", icon: "🌳", name: "세계수", description: "100개 이상 다른 브랜치에서 작업했다", xpReward: 800, rarity: .mythic),
        Achievement(id: "git_branch_500", icon: "🍃", name: "잎새의 바다", description: "500개 이상 다른 브랜치에서 작업했다", xpReward: 1500, rarity: .mythic),
        Achievement(id: "git_master_200", icon: "💣", name: "핵폭발", description: "한 세션에서 200개 이상 파일을 변경했다", xpReward: 800, rarity: .mythic),
        Achievement(id: "git_master_500", icon: "🌪️", name: "카테고리 5", description: "한 세션에서 500개 이상 파일을 변경했다", xpReward: 1500, rarity: .mythic),
        Achievement(id: "file_surgeon_50", icon: "🧑‍⚕️", name: "신의 손", description: "한 세션에서 50개 이상 파일을 수정했다", xpReward: 700, rarity: .mythic),
        Achievement(id: "file_surgeon_100", icon: "🧪", name: "연금술사", description: "한 세션에서 100개 이상 파일을 수정했다", xpReward: 1200, rarity: .mythic),
        Achievement(id: "night_owl_100", icon: "👻", name: "유령", description: "심야 작업을 100일 이상 했다", xpReward: 800, rarity: .mythic),
        Achievement(id: "night_owl_365", icon: "🧛", name: "뱀파이어", description: "심야 작업을 365일 이상 했다", xpReward: 2000, rarity: .mythic),
        Achievement(id: "session_streak_365_x2", icon: "⏳", name: "시간의 군주", description: "730일(2년) 연속으로 작업했다", xpReward: 3000, rarity: .mythic),
        Achievement(id: "session_streak_1000", icon: "🏺", name: "영원", description: "1,000일 연속으로 작업했다", xpReward: 5000, rarity: .mythic),
        Achievement(id: "marathon_24h", icon: "🌅", name: "해가 뜨고 지고", description: "24시간 이상 연속으로 작업했다", xpReward: 1000, rarity: .mythic),
        Achievement(id: "marathon_48h", icon: "😵", name: "불면의 경지", description: "48시간 이상 연속으로 작업했다", xpReward: 2000, rarity: .mythic),
        Achievement(id: "weekend_100", icon: "🎡", name: "영원한 주말", description: "주말에 100일 이상 작업했다", xpReward: 800, rarity: .mythic),
        Achievement(id: "weekend_365", icon: "🏖️", name: "워커홀릭", description: "주말에 365일 이상 작업했다", xpReward: 2000, rarity: .mythic),
        Achievement(id: "multi_10", icon: "🎼", name: "오케스트라", description: "10개 이상 동시에 작업했다", xpReward: 800, rarity: .mythic),
        Achievement(id: "multi_15", icon: "🎆", name: "불꽃놀이", description: "15개 이상 동시에 작업했다", xpReward: 1500, rarity: .mythic),
        Achievement(id: "level_25", icon: "🔱", name: "포세이돈", description: "레벨 25에 도달했다", xpReward: 1000, rarity: .mythic),
        Achievement(id: "level_30", icon: "⚡", name: "제우스", description: "레벨 30에 도달했다", xpReward: 2000, rarity: .mythic),
        Achievement(id: "level_50", icon: "🕊️", name: "신", description: "레벨 50에 도달했다", xpReward: 5000, rarity: .mythic),
        Achievement(id: "active_days_365", icon: "📅", name: "개근상", description: "누적 365일 작업했다", xpReward: 1000, rarity: .mythic),
        Achievement(id: "active_days_1000", icon: "🗓️", name: "천일의 약속", description: "누적 1,000일 작업했다", xpReward: 2500, rarity: .mythic),

        // ─────────────────────────────────────────────
        // 추가 Common (일반) — 다양한 조건
        // ─────────────────────────────────────────────
        Achievement(id: "tuesday_coder", icon: "📌", name: "화요일 전사", description: "화요일에 작업했다", xpReward: 25, rarity: .common),
        Achievement(id: "wednesday_coder", icon: "🐫", name: "수요일 낙타", description: "수요일에 작업했다", xpReward: 25, rarity: .common),
        Achievement(id: "thursday_coder", icon: "⚡", name: "목요일 번개", description: "목요일에 작업했다", xpReward: 25, rarity: .common),
        Achievement(id: "first_grep", icon: "🔎", name: "첫 검색", description: "첫 Grep 검색을 실행했다", xpReward: 20, rarity: .common),
        Achievement(id: "first_glob", icon: "📂", name: "파일 탐색가", description: "첫 Glob 패턴 검색을 실행했다", xpReward: 20, rarity: .common),
        Achievement(id: "command_25", icon: "🎯", name: "스물다섯 발", description: "명령을 25번 실행했다", xpReward: 25, rarity: .common),
        Achievement(id: "complete_3", icon: "🥉", name: "동메달", description: "작업을 3번 완료했다", xpReward: 25, rarity: .common),
        Achievement(id: "session_3", icon: "🔰", name: "세 번째 출근", description: "세션을 3번 시작했다", xpReward: 20, rarity: .common),
        Achievement(id: "session_5", icon: "✋", name: "다섯 번째 출근", description: "세션을 5번 시작했다", xpReward: 25, rarity: .common),
        Achievement(id: "read_5", icon: "📄", name: "열람자", description: "한 세션에서 파일을 5번 읽었다", xpReward: 20, rarity: .common),

        // ─────────────────────────────────────────────
        // 추가 Rare (희귀)
        // ─────────────────────────────────────────────
        Achievement(id: "afternoon_coder", icon: "☕", name: "오후의 커피", description: "오후 2~4시에 작업했다", xpReward: 40, rarity: .rare),
        Achievement(id: "evening_coder", icon: "🌆", name: "석양의 코더", description: "저녁 6~8시에 작업했다", xpReward: 40, rarity: .rare),
        Achievement(id: "dinner_coder", icon: "🍽️", name: "저녁밥 거른 코더", description: "저녁 7시에 작업 중이었다", xpReward: 45, rarity: .rare),
        Achievement(id: "command_75", icon: "7️⃣", name: "일흔다섯", description: "명령을 75번 실행했다", xpReward: 45, rarity: .rare),
        Achievement(id: "command_200", icon: "🔢", name: "이백장군", description: "명령을 200번 실행했다", xpReward: 50, rarity: .rare),
        Achievement(id: "complete_15", icon: "🏐", name: "열다섯 번째", description: "작업을 15번 완료했다", xpReward: 45, rarity: .rare),
        Achievement(id: "complete_20", icon: "🎱", name: "스무 번째", description: "작업을 20번 완료했다", xpReward: 45, rarity: .rare),
        Achievement(id: "token_2k_total", icon: "🪙", name: "이천 토큰", description: "누적 2,000 토큰을 사용했다", xpReward: 35, rarity: .rare),
        Achievement(id: "token_5k_total", icon: "🏷️", name: "오천 토큰", description: "누적 5,000 토큰을 사용했다", xpReward: 40, rarity: .rare),
        Achievement(id: "token_2k_session", icon: "📋", name: "보통 세션", description: "한 세션에서 2k 이상 토큰을 사용했다", xpReward: 35, rarity: .rare),
        Achievement(id: "cost_2", icon: "💲", name: "두 번째 달러", description: "누적 비용 $2를 넘었다", xpReward: 40, rarity: .rare),
        Achievement(id: "cost_3", icon: "💲", name: "세 번째 달러", description: "누적 비용 $3을 넘었다", xpReward: 40, rarity: .rare),
        Achievement(id: "focus_15", icon: "⏱️", name: "집중 15분", description: "15분 이상 연속 작업했다", xpReward: 35, rarity: .rare),
        Achievement(id: "focus_45", icon: "⏰", name: "집중 45분", description: "45분 이상 연속 작업했다", xpReward: 50, rarity: .rare),
        Achievement(id: "file_edit_10", icon: "📑", name: "열 번 수정", description: "파일을 10번 수정했다", xpReward: 35, rarity: .rare),
        Achievement(id: "file_edit_15", icon: "📋", name: "열다섯 번 수정", description: "파일을 15번 수정했다", xpReward: 40, rarity: .rare),
        Achievement(id: "read_25", icon: "📖", name: "다독가", description: "파일을 25번 읽었다", xpReward: 40, rarity: .rare),
        Achievement(id: "read_100", icon: "🔬", name: "연구자", description: "파일을 100번 읽었다", xpReward: 50, rarity: .rare),
        Achievement(id: "git_branch_3", icon: "🌿", name: "세 갈래", description: "3개 이상 다른 브랜치에서 작업했다", xpReward: 40, rarity: .rare),
        Achievement(id: "error_3", icon: "🤕", name: "세 번의 시련", description: "에러에서 3번 복구했다", xpReward: 40, rarity: .rare),
        Achievement(id: "session_15", icon: "📝", name: "열다섯 번째 출근", description: "세션을 15번 시작했다", xpReward: 40, rarity: .rare),
        Achievement(id: "session_20", icon: "📊", name: "스무 번째 출근", description: "세션을 20번 시작했다", xpReward: 40, rarity: .rare),
        Achievement(id: "night_owl_3", icon: "🌒", name: "초승달", description: "심야 작업을 3일 이상 했다", xpReward: 45, rarity: .rare),
        Achievement(id: "night_owl_5", icon: "🌓", name: "반달", description: "심야 작업을 5일 이상 했다", xpReward: 50, rarity: .rare),
        Achievement(id: "weekend_5", icon: "🏠", name: "주말 상근자", description: "주말에 5일 이상 작업했다", xpReward: 45, rarity: .rare),
        Achievement(id: "weekend_10", icon: "🏡", name: "주말 단골", description: "주말에 10일 이상 작업했다", xpReward: 50, rarity: .rare),

        // ─────────────────────────────────────────────
        // 추가 Epic (영웅)
        // ─────────────────────────────────────────────
        Achievement(id: "complete_75", icon: "🎖️", name: "상사", description: "작업을 75번 완료했다", xpReward: 85, rarity: .epic),
        Achievement(id: "complete_150", icon: "🥇", name: "금메달", description: "작업을 150번 완료했다", xpReward: 90, rarity: .epic),
        Achievement(id: "complete_250", icon: "🏆", name: "트로피", description: "작업을 250번 완료했다", xpReward: 90, rarity: .epic),
        Achievement(id: "command_750", icon: "🗡️", name: "칠백오십", description: "명령을 750번 실행했다", xpReward: 85, rarity: .epic),
        Achievement(id: "command_1500", icon: "🔱", name: "천오백", description: "명령을 1,500번 실행했다", xpReward: 90, rarity: .epic),
        Achievement(id: "command_3000", icon: "⚔️", name: "삼천검", description: "명령을 3,000번 실행했다", xpReward: 95, rarity: .epic),
        Achievement(id: "command_7500", icon: "🪓", name: "벌목꾼", description: "명령을 7,500번 실행했다", xpReward: 100, rarity: .epic),
        Achievement(id: "session_30", icon: "📅", name: "한 달 근무", description: "세션을 30번 시작했다", xpReward: 80, rarity: .epic),
        Achievement(id: "session_40", icon: "📆", name: "사십 번 출근", description: "세션을 40번 시작했다", xpReward: 80, rarity: .epic),
        Achievement(id: "token_20k_session", icon: "🐬", name: "돌고래", description: "한 세션에서 20k 이상 토큰을 사용했다", xpReward: 85, rarity: .epic),
        Achievement(id: "token_30k_session", icon: "🦭", name: "바다표범", description: "한 세션에서 30k 이상 토큰을 사용했다", xpReward: 85, rarity: .epic),
        Achievement(id: "token_200k_total", icon: "🏪", name: "토큰 상점", description: "누적 200,000 토큰을 사용했다", xpReward: 90, rarity: .epic),
        Achievement(id: "token_300k_total", icon: "🏬", name: "토큰 백화점", description: "누적 300,000 토큰을 사용했다", xpReward: 90, rarity: .epic),
        Achievement(id: "cost_20", icon: "💳", name: "VIP", description: "누적 비용 $20을 넘었다", xpReward: 85, rarity: .epic),
        Achievement(id: "cost_30", icon: "💎", name: "다이아 회원", description: "누적 비용 $30을 넘었다", xpReward: 90, rarity: .epic),
        Achievement(id: "cost_75", icon: "🏅", name: "골드 후원자", description: "누적 비용 $75를 넘었다", xpReward: 95, rarity: .epic),
        Achievement(id: "file_edit_75", icon: "📐", name: "설계사", description: "파일을 75번 수정했다", xpReward: 80, rarity: .epic),
        Achievement(id: "file_edit_150", icon: "🔧", name: "기술자", description: "파일을 150번 수정했다", xpReward: 85, rarity: .epic),
        Achievement(id: "read_150", icon: "📜", name: "고문서 해독가", description: "파일을 150번 읽었다", xpReward: 80, rarity: .epic),
        Achievement(id: "read_300", icon: "🏛️", name: "도서관장", description: "파일을 300번 읽었다", xpReward: 85, rarity: .epic),
        Achievement(id: "error_15", icon: "🩹", name: "응급처치", description: "에러에서 15번 복구했다", xpReward: 85, rarity: .epic),
        Achievement(id: "error_20", icon: "🧯", name: "소방관", description: "에러에서 20번 복구했다", xpReward: 90, rarity: .epic),
        Achievement(id: "error_35", icon: "🧱", name: "성벽", description: "에러에서 35번 복구했다", xpReward: 95, rarity: .epic),
        Achievement(id: "git_branch_7", icon: "🌵", name: "선인장", description: "7개 이상 다른 브랜치에서 작업했다", xpReward: 80, rarity: .epic),
        Achievement(id: "git_branch_15", icon: "🏝️", name: "군도", description: "15개 이상 다른 브랜치에서 작업했다", xpReward: 90, rarity: .epic),
        Achievement(id: "git_branch_20", icon: "🗺️", name: "지도 제작자", description: "20개 이상 다른 브랜치에서 작업했다", xpReward: 90, rarity: .epic),
        Achievement(id: "session_streak_5", icon: "🔥", name: "5일 연속", description: "5일 연속으로 작업했다", xpReward: 85, rarity: .epic),
        Achievement(id: "session_streak_10", icon: "🔥", name: "10일 연속", description: "10일 연속으로 작업했다", xpReward: 90, rarity: .epic),
        Achievement(id: "session_streak_21", icon: "📿", name: "3주 연속", description: "21일 연속으로 작업했다", xpReward: 100, rarity: .epic),
        Achievement(id: "night_owl_15", icon: "🦇", name: "15일의 밤", description: "심야 작업을 15일 이상 했다", xpReward: 90, rarity: .epic),
        Achievement(id: "night_owl_20", icon: "🌑", name: "그믐달", description: "심야 작업을 20일 이상 했다", xpReward: 95, rarity: .epic),
        Achievement(id: "night_owl_30", icon: "🌘", name: "한 달의 밤", description: "심야 작업을 30일 이상 했다", xpReward: 100, rarity: .epic),
        Achievement(id: "weekend_20", icon: "🎢", name: "주말 마니아", description: "주말에 20일 이상 작업했다", xpReward: 85, rarity: .epic),
        Achievement(id: "weekend_30", icon: "🎠", name: "주말의 왕", description: "주말에 30일 이상 작업했다", xpReward: 90, rarity: .epic),
        Achievement(id: "active_days_30", icon: "📅", name: "한 달 개근", description: "누적 30일 작업했다", xpReward: 80, rarity: .epic),
        Achievement(id: "active_days_60", icon: "📆", name: "두 달 개근", description: "누적 60일 작업했다", xpReward: 85, rarity: .epic),
        Achievement(id: "active_days_90", icon: "🗓️", name: "분기 개근", description: "누적 90일 작업했다", xpReward: 90, rarity: .epic),
        Achievement(id: "active_days_180", icon: "📊", name: "반년 개근", description: "누적 180일 작업했다", xpReward: 95, rarity: .epic),
        Achievement(id: "marathon_2h", icon: "🏃‍♂️", name: "하프 마라톤", description: "2시간 이상 연속으로 작업했다", xpReward: 90, rarity: .epic),
        Achievement(id: "marathon_4h", icon: "🏃‍♀️", name: "풀 마라톤", description: "4시간 이상 연속으로 작업했다", xpReward: 100, rarity: .epic),
        Achievement(id: "marathon_8h", icon: "🏋️", name: "철인", description: "8시간 이상 연속으로 작업했다", xpReward: 110, rarity: .epic),

        // ─────────────────────────────────────────────
        // 추가 Legendary (전설)
        // ─────────────────────────────────────────────
        Achievement(id: "complete_400", icon: "🎪", name: "서커스 단장", description: "작업을 400번 완료했다", xpReward: 200, rarity: .legendary),
        Achievement(id: "complete_750", icon: "🏰", name: "성주", description: "작업을 750번 완료했다", xpReward: 250, rarity: .legendary),
        Achievement(id: "command_15000", icon: "🗼", name: "탑 빌더", description: "명령을 15,000번 실행했다", xpReward: 350, rarity: .legendary),
        Achievement(id: "command_25000", icon: "🏗️", name: "크레인", description: "명령을 25,000번 실행했다", xpReward: 400, rarity: .legendary),
        Achievement(id: "session_150", icon: "🏭", name: "공장장", description: "세션을 150번 시작했다", xpReward: 200, rarity: .legendary),
        Achievement(id: "session_200", icon: "🏛️", name: "의회", description: "세션을 200번 시작했다", xpReward: 250, rarity: .legendary),
        Achievement(id: "session_300", icon: "🌆", name: "메트로폴리스", description: "세션을 300번 시작했다", xpReward: 300, rarity: .legendary),
        Achievement(id: "session_1000", icon: "🌃", name: "네온시티", description: "세션을 1,000번 시작했다", xpReward: 400, rarity: .legendary),
        Achievement(id: "token_2million", icon: "🌏", name: "대륙", description: "누적 2,000,000 토큰을 사용했다", xpReward: 300, rarity: .legendary),
        Achievement(id: "token_3million", icon: "🌎", name: "서반구", description: "누적 3,000,000 토큰을 사용했다", xpReward: 350, rarity: .legendary),
        Achievement(id: "cost_200", icon: "💰", name: "금고", description: "누적 비용 $200을 넘었다", xpReward: 250, rarity: .legendary),
        Achievement(id: "cost_300", icon: "🏧", name: "ATM", description: "누적 비용 $300을 넘었다", xpReward: 300, rarity: .legendary),
        Achievement(id: "file_edit_750", icon: "⛏️", name: "광산 노동자", description: "파일을 750번 수정했다", xpReward: 250, rarity: .legendary),
        Achievement(id: "read_750", icon: "🔭", name: "천문학자", description: "파일을 750번 읽었다", xpReward: 250, rarity: .legendary),
        Achievement(id: "error_75", icon: "🛡️", name: "강철 방패", description: "에러에서 75번 복구했다", xpReward: 200, rarity: .legendary),
        Achievement(id: "weekend_75", icon: "🎡", name: "놀이공원 사장", description: "주말에 75일 이상 작업했다", xpReward: 350, rarity: .legendary),
        Achievement(id: "active_days_270", icon: "🗺️", name: "세계 일주", description: "누적 270일 작업했다", xpReward: 300, rarity: .legendary),
        Achievement(id: "session_streak_45", icon: "🧲", name: "45일 연속", description: "45일 연속으로 작업했다", xpReward: 350, rarity: .legendary),
        Achievement(id: "session_streak_90", icon: "💫", name: "분기 연속", description: "90일 연속으로 작업했다", xpReward: 400, rarity: .legendary),
        Achievement(id: "marathon_10h", icon: "🏜️", name: "사하라 횡단", description: "10시간 이상 연속으로 작업했다", xpReward: 400, rarity: .legendary),
        Achievement(id: "level_12", icon: "🌟", name: "빛나는 별", description: "레벨 12에 도달했다", xpReward: 300, rarity: .legendary),

        // ─────────────────────────────────────────────
        // 추가 Mythic (신화)
        // ─────────────────────────────────────────────
        Achievement(id: "complete_7500", icon: "🐉", name: "용의 둥지", description: "작업을 7,500번 완료했다", xpReward: 1200, rarity: .mythic),
        Achievement(id: "complete_15000", icon: "🕳️", name: "차원의 문", description: "작업을 15,000번 완료했다", xpReward: 2000, rarity: .mythic),
        Achievement(id: "complete_25000", icon: "🌌", name: "다중 우주", description: "작업을 25,000번 완료했다", xpReward: 3000, rarity: .mythic),
        Achievement(id: "command_200000", icon: "🌀", name: "소용돌이", description: "명령을 200,000번 실행했다", xpReward: 1500, rarity: .mythic),
        Achievement(id: "command_1000000", icon: "♾️", name: "백만장자 명령", description: "명령을 1,000,000번 실행했다", xpReward: 3000, rarity: .mythic),
        Achievement(id: "session_20000", icon: "🌠", name: "유성우", description: "세션을 20,000번 시작했다", xpReward: 2000, rarity: .mythic),
        Achievement(id: "token_500million", icon: "🌟", name: "퀘이사", description: "누적 500,000,000 토큰을 사용했다", xpReward: 2000, rarity: .mythic),
        Achievement(id: "token_2m_session", icon: "🌊", name: "해일", description: "한 세션에서 2M 이상 토큰을 사용했다", xpReward: 1500, rarity: .mythic),
        Achievement(id: "token_5m_session", icon: "🌋", name: "슈퍼볼케이노", description: "한 세션에서 5M 이상 토큰을 사용했다", xpReward: 2500, rarity: .mythic),
        Achievement(id: "cost_25000", icon: "🏰", name: "왕궁", description: "누적 비용 $25,000을 넘었다", xpReward: 2000, rarity: .mythic),
        Achievement(id: "cost_100000", icon: "🌍", name: "국가 예산", description: "누적 비용 $100,000을 넘었다", xpReward: 5000, rarity: .mythic),
        Achievement(id: "file_edit_20000", icon: "🌪️", name: "허리케인", description: "파일을 20,000번 수정했다", xpReward: 2000, rarity: .mythic),
        Achievement(id: "file_edit_100000", icon: "🌊", name: "대양", description: "파일을 100,000번 수정했다", xpReward: 3000, rarity: .mythic),
        Achievement(id: "read_20000", icon: "🧿", name: "만물의 눈", description: "파일을 20,000번 읽었다", xpReward: 1500, rarity: .mythic),
        Achievement(id: "read_100000", icon: "📡", name: "딥 스페이스", description: "파일을 100,000번 읽었다", xpReward: 2500, rarity: .mythic),
        Achievement(id: "error_2000", icon: "⚛️", name: "핵융합", description: "에러에서 2,000번 복구했다", xpReward: 3000, rarity: .mythic),
        Achievement(id: "git_branch_200", icon: "🌳", name: "아마존", description: "200개 이상 다른 브랜치에서 작업했다", xpReward: 1200, rarity: .mythic),
        Achievement(id: "git_branch_1000", icon: "🌲", name: "타이가", description: "1,000개 이상 다른 브랜치에서 작업했다", xpReward: 2500, rarity: .mythic),
        Achievement(id: "git_master_1000", icon: "💫", name: "초신성", description: "한 세션에서 1,000개 이상 파일을 변경했다", xpReward: 2000, rarity: .mythic),
        Achievement(id: "file_surgeon_200", icon: "🧬", name: "유전자 편집", description: "한 세션에서 200개 이상 파일을 수정했다", xpReward: 1500, rarity: .mythic),
        Achievement(id: "weekend_500", icon: "🏗️", name: "영원한 건설", description: "주말에 500일 이상 작업했다", xpReward: 2500, rarity: .mythic),
        Achievement(id: "active_days_2000", icon: "🗿", name: "모아이", description: "누적 2,000일 작업했다", xpReward: 3000, rarity: .mythic),
        Achievement(id: "active_days_3650", icon: "🏺", name: "십년의 유산", description: "누적 3,650일(10년) 작업했다", xpReward: 5000, rarity: .mythic),
        Achievement(id: "session_streak_500", icon: "🧊", name: "빙하기", description: "500일 연속으로 작업했다", xpReward: 3000, rarity: .mythic),
        Achievement(id: "session_streak_1500", icon: "🏛️", name: "문명", description: "1,500일 연속으로 작업했다", xpReward: 5000, rarity: .mythic),
        Achievement(id: "marathon_72h", icon: "💀", name: "불멸", description: "72시간 이상 연속으로 작업했다", xpReward: 3000, rarity: .mythic),
        Achievement(id: "level_40", icon: "🔮", name: "대마법사", description: "레벨 40에 도달했다", xpReward: 3000, rarity: .mythic),
        Achievement(id: "level_75", icon: "👁️", name: "전지전능", description: "레벨 75에 도달했다", xpReward: 5000, rarity: .mythic),
        Achievement(id: "level_100", icon: "🕊️", name: "아센션", description: "레벨 100에 도달했다", xpReward: 10000, rarity: .mythic),

        Achievement(id: "mythic_perfectionist", icon: "🌈", name: "전설을 넘어서", description: "전설 등급 이하 모든 업적을 달성했다", xpReward: 3000, rarity: .mythic),
        Achievement(id: "true_god", icon: "∞", name: "초월", description: "신화 등급 외 모든 업적을 달성했다", xpReward: 10000, rarity: .mythic),
    ]

    @Published var totalXP: Int = 0
    @Published var commandCount: Int = 0
    @Published var recentUnlock: Achievement?

    // 확장 추적 변수
    @Published var totalSessions: Int = 0
    @Published var totalCompletions: Int = 0
    @Published var totalTokensUsed: Int = 0
    @Published var totalCost: Double = 0
    @Published var errorRecoveryCount: Int = 0
    @Published var totalFileEdits: Int = 0
    @Published var totalFileReads: Int = 0
    @Published var usedModels: Set<String> = []
    @Published var uniqueBranches: Set<String> = []
    @Published var activeDays: Set<String> = []  // "yyyy-MM-dd" 형식
    @Published var nightDays: Set<String> = []   // 심야 작업한 날
    @Published var weekendDays: Set<String> = [] // 주말 작업한 날
    @Published var lastLoginRewardDate: String = ""  // "yyyy-MM-dd"
    @Published var loginStreak: Int = 0
    @Published var todayRewardClaimed: Bool = false

    private let saveKey = "DofficeAchievements"
    private var saveDebounceWork: DispatchWorkItem?
    private var toastQueue: [Achievement] = []
    private var toastDismissWork: DispatchWorkItem?
    private let dayFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f
    }()

    @Published var unlockedCount: Int = 0
    var currentLevel: WorkerLevel { WorkerLevel.forXP(totalXP) }

    init() {
        loadState()
        // Check daily login reward
        let today = dayFormatter.string(from: Date())
        todayRewardClaimed = (lastLoginRewardDate == today)
    }

    func unlock(_ id: String) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in self?.unlock(id) }
            return
        }
        guard let idx = achievements.firstIndex(where: { $0.id == id && !$0.unlocked }) else { return }
        guard idx >= 0 && idx < achievements.count else { return }
        achievements[idx].unlocked = true
        achievements[idx].unlockedAt = Date()
        unlockedCount += 1
        let unlockedAchievement = achievements[idx]
        enqueueRecentUnlock(unlockedAchievement)
        addXP(unlockedAchievement.xpReward)
        NSSound(named: "Hero")?.play()
        PluginHost.shared.fireEvent(.onAchievementUnlock)
        saveState()

        // 완벽주의자 체크
        let nonLegendary = achievements.filter { $0.rarity != .legendary && $0.rarity != .mythic }
        if nonLegendary.allSatisfy({ $0.unlocked }) { unlock("perfectionist") }
        let nonMythic = achievements.filter { $0.rarity != .mythic }
        if nonMythic.allSatisfy({ $0.unlocked }) { unlock("mythic_perfectionist") }
        let nonTrueGod = achievements.filter { $0.id != "true_god" }
        if nonTrueGod.allSatisfy({ $0.unlocked }) { unlock("true_god") }
    }

    func dismissRecentUnlock() {
        toastDismissWork?.cancel()
        toastDismissWork = nil
        recentUnlock = nil
        showNextRecentUnlockIfNeeded()
    }

    struct DailyRewardResult {
        let xp: Int
        let bonusXP: Int
        let streak: Int
        let isMilestone: Bool
        let milestoneEmoji: String
        let milestoneLabel: String
    }

    func claimDailyReward() -> DailyRewardResult? {
        let today = dayFormatter.string(from: Date())
        guard today != lastLoginRewardDate else { return nil }

        guard let yesterdayDate = Calendar.current.date(byAdding: .day, value: -1, to: Date()) else { return nil }
        let yesterday = dayFormatter.string(from: yesterdayDate)
        if lastLoginRewardDate == yesterday {
            loginStreak += 1
        } else {
            loginStreak = 1
        }
        lastLoginRewardDate = today
        todayRewardClaimed = true

        let baseXP = 15
        let streakBonus = min(loginStreak * 5, 100)
        let totalXP = baseXP + streakBonus
        addXP(totalXP)

        var bonusXP = 0
        var isMilestone = false
        var milestoneEmoji = "🔥"
        var milestoneLabel = ""

        switch loginStreak {
        case 7:   bonusXP = 50;   isMilestone = true; milestoneEmoji = "🎉"; milestoneLabel = NSLocalizedString("game.milestone.week", comment: "")
        case 14:  bonusXP = 100;  isMilestone = true; milestoneEmoji = "🔥"; milestoneLabel = NSLocalizedString("game.milestone.2weeks", comment: "")
        case 30:  bonusXP = 200;  isMilestone = true; milestoneEmoji = "👑"; milestoneLabel = NSLocalizedString("game.milestone.month", comment: "")
        case 60:  bonusXP = 300;  isMilestone = true; milestoneEmoji = "💎"; milestoneLabel = NSLocalizedString("game.milestone.2months", comment: "")
        case 100: bonusXP = 500;  isMilestone = true; milestoneEmoji = "🏆"; milestoneLabel = NSLocalizedString("game.milestone.100days", comment: "")
        case 365: bonusXP = 1000; isMilestone = true; milestoneEmoji = "🌟"; milestoneLabel = NSLocalizedString("game.milestone.year", comment: "")
        default: break
        }
        if bonusXP > 0 { addXP(bonusXP) }

        saveState()
        return DailyRewardResult(
            xp: totalXP, bonusXP: bonusXP, streak: loginStreak,
            isMilestone: isMilestone, milestoneEmoji: milestoneEmoji, milestoneLabel: milestoneLabel
        )
    }

    func addXP(_ amount: Int) {
        let prevLevel = WorkerLevel.forXP(totalXP).level
        totalXP += amount
        let newLevel = WorkerLevel.forXP(totalXP).level

        // Level up celebration!
        if newLevel > prevLevel {
            OfficeSceneStore.shared.controller.triggerCelebration()
            PluginHost.shared.fireEvent(.onLevelUp)
        }

        if totalXP >= 1000 { unlock("level_5") }
        if totalXP >= 4000 { unlock("level_8") }
        if totalXP >= 10000 { unlock("level_10") }
        if totalXP >= 15000 { unlock("level_12") }
        if totalXP >= 25000 { unlock("level_15") }
        if totalXP >= 50000 { unlock("level_20") }
        if totalXP >= 100000 { unlock("level_25") }
        if totalXP >= 200000 { unlock("level_30") }
        if totalXP >= 500000 { unlock("level_40") }
        if totalXP >= 1000000 { unlock("level_50") }
        if totalXP >= 2000000 { unlock("level_75") }
        if totalXP >= 5000000 { unlock("level_100") }
        saveState()
    }

    func incrementCommand() {
        commandCount += 1
        if commandCount >= 10 { unlock("command_10") }
        if commandCount >= 25 { unlock("command_25") }
        if commandCount >= 50 { unlock("command_50") }
        if commandCount >= 75 { unlock("command_75") }
        if commandCount >= 100 { unlock("centurion") }
        if commandCount >= 200 { unlock("command_200") }
        if commandCount >= 500 { unlock("command_500") }
        if commandCount >= 750 { unlock("command_750") }
        if commandCount >= 1000 { unlock("command_1000") }
        if commandCount >= 1500 { unlock("command_1500") }
        if commandCount >= 3000 { unlock("command_3000") }
        if commandCount >= 5000 { unlock("command_5000") }
        if commandCount >= 7500 { unlock("command_7500") }
        if commandCount >= 10000 { unlock("command_10000") }
        if commandCount >= 15000 { unlock("command_15000") }
        if commandCount >= 20000 { unlock("command_20000") }
        if commandCount >= 25000 { unlock("command_25000") }
        if commandCount >= 50000 { unlock("command_50000") }
        if commandCount >= 100000 { unlock("command_100000") }
        if commandCount >= 200000 { unlock("command_200000") }
        if commandCount >= 500000 { unlock("command_500000") }
        if commandCount >= 1000000 { unlock("command_1000000") }
        if commandCount == 1 { unlock("first_bash") }
        saveState()
    }

    func recordFileEdit() {
        totalFileEdits += 1
        if totalFileEdits == 1 { unlock("first_edit") }
        if totalFileEdits >= 5 { unlock("file_edit_5") }
        if totalFileEdits >= 10 { unlock("file_edit_10") }
        if totalFileEdits >= 15 { unlock("file_edit_15") }
        if totalFileEdits >= 25 { unlock("file_edit_25") }
        if totalFileEdits >= 50 { unlock("file_edit_50") }
        if totalFileEdits >= 75 { unlock("file_edit_75") }
        if totalFileEdits >= 100 { unlock("file_edit_100") }
        if totalFileEdits >= 150 { unlock("file_edit_150") }
        if totalFileEdits >= 200 { unlock("file_edit_200") }
        if totalFileEdits >= 500 { unlock("file_edit_500") }
        if totalFileEdits >= 750 { unlock("file_edit_750") }
        if totalFileEdits >= 1000 { unlock("file_edit_1000") }
        if totalFileEdits >= 2000 { unlock("file_edit_2000") }
        if totalFileEdits >= 5000 { unlock("file_edit_5000") }
        if totalFileEdits >= 10000 { unlock("file_edit_10000") }
        if totalFileEdits >= 20000 { unlock("file_edit_20000") }
        if totalFileEdits >= 50000 { unlock("file_edit_50000") }
        if totalFileEdits >= 100000 { unlock("file_edit_100000") }
        saveState()
    }

    func recordFileRead(sessionReadCount: Int) {
        totalFileReads += 1
        if sessionReadCount >= 5 { unlock("read_5") }
        if sessionReadCount >= 10 { unlock("read_10") }
        if totalFileReads >= 25 { unlock("read_25") }
        if totalFileReads >= 50 { unlock("read_50") }
        if totalFileReads >= 100 { unlock("read_100") }
        if totalFileReads >= 150 { unlock("read_150") }
        if totalFileReads >= 200 { unlock("read_200") }
        if totalFileReads >= 300 { unlock("read_300") }
        if totalFileReads >= 500 { unlock("read_500") }
        if totalFileReads >= 750 { unlock("read_750") }
        if totalFileReads >= 1000 { unlock("read_1000") }
        if totalFileReads >= 2000 { unlock("read_2000") }
        if totalFileReads >= 5000 { unlock("read_5000") }
        if totalFileReads >= 10000 { unlock("read_10000") }
        if totalFileReads >= 20000 { unlock("read_20000") }
        if totalFileReads >= 50000 { unlock("read_50000") }
        if totalFileReads >= 100000 { unlock("read_100000") }
        saveState()
    }

    func recordModel(_ model: String) {
        usedModels.insert(model.lowercased())
        if usedModels.contains("opus") { unlock("opus_user") }
        if usedModels.contains("haiku") { unlock("haiku_user") }
        if usedModels.contains("opus") && usedModels.contains("sonnet") && usedModels.contains("haiku") {
            unlock("three_models")
        }
        saveState()
    }

    func recordBranch(_ branch: String) {
        guard !branch.isEmpty else { return }
        uniqueBranches.insert(branch)
        unlock("git_first_branch")
        if uniqueBranches.count >= 3 { unlock("git_branch_3") }
        if uniqueBranches.count >= 5 { unlock("git_branch_5") }
        if uniqueBranches.count >= 7 { unlock("git_branch_7") }
        if uniqueBranches.count >= 10 { unlock("git_branch_10") }
        if uniqueBranches.count >= 15 { unlock("git_branch_15") }
        if uniqueBranches.count >= 20 { unlock("git_branch_20") }
        if uniqueBranches.count >= 30 { unlock("git_branch_30") }
        if uniqueBranches.count >= 50 { unlock("git_branch_50") }
        if uniqueBranches.count >= 100 { unlock("git_branch_100") }
        if uniqueBranches.count >= 200 { unlock("git_branch_200") }
        if uniqueBranches.count >= 500 { unlock("git_branch_500") }
        if uniqueBranches.count >= 1000 { unlock("git_branch_1000") }
        saveState()
    }

    func recordCost(_ cost: Double) {
        totalCost += cost
        if totalCost > 0 { unlock("cost_first") }
        if totalCost >= 1.0 { unlock("cost_1") }
        if totalCost >= 2.0 { unlock("cost_2") }
        if totalCost >= 3.0 { unlock("cost_3") }
        if totalCost >= 5.0 { unlock("cost_5") }
        if totalCost >= 10.0 { unlock("cost_10") }
        if totalCost >= 20.0 { unlock("cost_20") }
        if totalCost >= 30.0 { unlock("cost_30") }
        if totalCost >= 50.0 { unlock("cost_50") }
        if totalCost >= 75.0 { unlock("cost_75") }
        if totalCost >= 100.0 { unlock("cost_100") }
        if totalCost >= 200.0 { unlock("cost_200") }
        if totalCost >= 300.0 { unlock("cost_300") }
        if totalCost >= 500.0 { unlock("cost_500") }
        if totalCost >= 1000.0 { unlock("cost_1000") }
        if totalCost >= 5000.0 { unlock("cost_5000") }
        if totalCost >= 10000.0 { unlock("cost_10000") }
        if totalCost >= 25000.0 { unlock("cost_25000") }
        if totalCost >= 50000.0 { unlock("cost_50000") }
        if totalCost >= 100000.0 { unlock("cost_100000") }
        saveState()
    }

    private func recordActiveDay() {
        let today = dayFormatter.string(from: Date())
        activeDays.insert(today)
        // 메모리 절약: 400일 초과 시 오래된 날짜 제거 (365일 업적 체크 + 여유)
        if activeDays.count > 400 {
            let sorted = activeDays.sorted()
            let toRemove = sorted.prefix(activeDays.count - 400)
            for d in toRemove { activeDays.remove(d) }
        }
        if activeDays.count >= 30 { unlock("active_days_30") }
        if activeDays.count >= 60 { unlock("active_days_60") }
        if activeDays.count >= 90 { unlock("active_days_90") }
        if activeDays.count >= 180 { unlock("active_days_180") }
        if activeDays.count >= 270 { unlock("active_days_270") }
        if activeDays.count >= 365 { unlock("active_days_365") }
        if activeDays.count >= 1000 { unlock("active_days_1000") }
        if activeDays.count >= 2000 { unlock("active_days_2000") }
        if activeDays.count >= 3650 { unlock("active_days_3650") }
        checkStreakAchievements()
        saveState()
    }

    private func checkStreakAchievements() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var streak = 1
        var day = today
        while true {
            guard let prev = cal.date(byAdding: .day, value: -1, to: day) else { break }
            let prevStr = dayFormatter.string(from: prev)
            if activeDays.contains(prevStr) { streak += 1; day = prev }
            else { break }
        }
        if streak >= 3 { unlock("session_streak_3") }
        if streak >= 5 { unlock("session_streak_5") }
        if streak >= 7 { unlock("session_streak_7") }
        if streak >= 10 { unlock("session_streak_10") }
        if streak >= 14 { unlock("session_streak_14") }
        if streak >= 21 { unlock("session_streak_21") }
        if streak >= 30 { unlock("session_streak_30") }
        if streak >= 45 { unlock("session_streak_45") }
        if streak >= 60 { unlock("session_streak_60") }
        if streak >= 90 { unlock("session_streak_90") }
        if streak >= 100 { unlock("session_streak_100") }
        if streak >= 180 { unlock("session_streak_180") }
        if streak >= 365 { unlock("session_streak_365") }
        if streak >= 500 { unlock("session_streak_500") }
        if streak >= 730 { unlock("session_streak_365_x2") }
        if streak >= 1000 { unlock("session_streak_1000") }
        if streak >= 1500 { unlock("session_streak_1500") }
    }

    func checkSessionAchievements(tabs: [TerminalTab]) {
        if tabs.count >= 1 { unlock("first_session") }
        if tabs.count >= 5 { unlock("five_sessions") }

        let runningCount = tabs.filter({ $0.isRunning && !$0.isCompleted }).count
        if runningCount >= 3 { unlock("multi_tasker") }
        if runningCount >= 5 { unlock("multi_5") }
        if runningCount >= 7 { unlock("multi_7") }
        if runningCount >= 10 { unlock("multi_10") }
        if runningCount >= 15 { unlock("multi_15") }

        if tabs.contains(where: { $0.sessionCount >= 2 }) { unlock("pair_programmer") }

        for tab in tabs {
            if tab.gitInfo.changedFiles >= 10 { unlock("git_master") }
            if tab.gitInfo.changedFiles >= 25 { unlock("git_master_25") }
            if tab.gitInfo.changedFiles >= 50 { unlock("git_master_50") }
            if tab.gitInfo.changedFiles >= 100 { unlock("git_master_100") }
            if tab.gitInfo.changedFiles >= 200 { unlock("git_master_200") }
            if tab.gitInfo.changedFiles >= 500 { unlock("git_master_500") }
            if tab.gitInfo.changedFiles >= 1000 { unlock("git_master_1000") }
            if tab.fileChanges.count >= 5 { unlock("file_surgeon") }
            if tab.fileChanges.count >= 10 { unlock("file_surgeon_10") }
            if tab.fileChanges.count >= 25 { unlock("file_surgeon_25") }
            if tab.fileChanges.count >= 50 { unlock("file_surgeon_50") }
            if tab.fileChanges.count >= 100 { unlock("file_surgeon_100") }
            if tab.fileChanges.count >= 200 { unlock("file_surgeon_200") }
        }

        let now = Date()
        let hour = Calendar.current.component(.hour, from: now)
        let weekday = Calendar.current.component(.weekday, from: now)

        if hour >= 0 && hour < 5 {
            unlock("night_owl")
            let today = dayFormatter.string(from: now)
            if !nightDays.contains(today) {
                nightDays.insert(today)
                if nightDays.count >= 3 { unlock("night_owl_3") }
                if nightDays.count >= 5 { unlock("night_owl_5") }
                if nightDays.count >= 10 { unlock("night_owl_10") }
                if nightDays.count >= 15 { unlock("night_owl_15") }
                if nightDays.count >= 20 { unlock("night_owl_20") }
                if nightDays.count >= 30 { unlock("night_owl_30") }
                if nightDays.count >= 50 { unlock("night_owl_50") }
                if nightDays.count >= 100 { unlock("night_owl_100") }
                if nightDays.count >= 365 { unlock("night_owl_365") }
                saveState()
            }
        }
        if hour >= 4 && hour < 6 { unlock("early_bird") }
        if hour >= 12 && hour < 13 { unlock("lunch_coder") }
        if hour >= 14 && hour < 16 { unlock("afternoon_coder") }
        if hour >= 18 && hour < 20 { unlock("evening_coder") }
        if hour == 19 { unlock("dinner_coder") }
        if weekday == 3 { unlock("tuesday_coder") }
        if weekday == 4 { unlock("wednesday_coder") }
        if weekday == 5 { unlock("thursday_coder") }
        if weekday == 1 || weekday == 7 {
            unlock("weekend_warrior")
            let today = dayFormatter.string(from: now)
            if !weekendDays.contains(today) {
                weekendDays.insert(today)
                if weekendDays.count >= 5 { unlock("weekend_5") }
                if weekendDays.count >= 10 { unlock("weekend_10") }
                if weekendDays.count >= 20 { unlock("weekend_20") }
                if weekendDays.count >= 30 { unlock("weekend_30") }
                if weekendDays.count >= 50 { unlock("weekend_50") }
                if weekendDays.count >= 75 { unlock("weekend_75") }
                if weekendDays.count >= 100 { unlock("weekend_100") }
                if weekendDays.count >= 365 { unlock("weekend_365") }
                if weekendDays.count >= 500 { unlock("weekend_500") }
                saveState()
            }
        }
        if weekday == 2 { unlock("monday_blues") }
        if weekday == 6 { unlock("friday_coder") }
        if hour == 3 { unlock("dawn_warrior") }

        // 야간 마라톤: 자정~5시에 1시간 이상 작업 중인 세션
        if hour >= 0 && hour < 5 {
            for tab in tabs where !tab.isCompleted {
                let dur = now.timeIntervalSince(tab.startTime)
                if dur > 3600 { unlock("night_marathon") }
            }
        }

        // 활동일 기록
        recordActiveDay()
    }

    func checkCompletionAchievements(tab: TerminalTab) {
        totalCompletions += 1
        totalSessions += 1
        totalTokensUsed += tab.tokensUsed

        unlock("first_complete")
        if totalCompletions >= 3 { unlock("complete_3") }
        if totalCompletions >= 5 { unlock("complete_5") }
        if totalCompletions >= 10 { unlock("complete_10") }
        if totalCompletions >= 15 { unlock("complete_15") }
        if totalCompletions >= 20 { unlock("complete_20") }
        if totalCompletions >= 25 { unlock("complete_25") }
        if totalCompletions >= 50 { unlock("complete_50") }
        if totalCompletions >= 75 { unlock("complete_75") }
        if totalCompletions >= 100 { unlock("complete_100") }
        if totalCompletions >= 150 { unlock("complete_150") }
        if totalCompletions >= 200 { unlock("complete_200") }
        if totalCompletions >= 250 { unlock("complete_250") }
        if totalCompletions >= 300 { unlock("complete_300") }
        if totalCompletions >= 400 { unlock("complete_400") }
        if totalCompletions >= 500 { unlock("complete_500") }
        if totalCompletions >= 750 { unlock("complete_750") }
        if totalCompletions >= 1000 { unlock("complete_1000") }
        if totalCompletions >= 2000 { unlock("complete_2000") }
        if totalCompletions >= 3000 { unlock("complete_3000") }
        if totalCompletions >= 5000 { unlock("complete_5000") }
        if totalCompletions >= 7500 { unlock("complete_7500") }
        if totalCompletions >= 10000 { unlock("complete_10000") }
        if totalCompletions >= 15000 { unlock("complete_15000") }
        if totalCompletions >= 25000 { unlock("complete_25000") }

        if totalSessions >= 3 { unlock("session_3") }
        if totalSessions >= 5 { unlock("session_5") }
        if totalSessions >= 10 { unlock("session_10") }
        if totalSessions >= 15 { unlock("session_15") }
        if totalSessions >= 20 { unlock("session_20") }
        if totalSessions >= 25 { unlock("session_25") }
        if totalSessions >= 30 { unlock("session_30") }
        if totalSessions >= 40 { unlock("session_40") }
        if totalSessions >= 50 { unlock("session_50") }
        if totalSessions >= 75 { unlock("session_75") }
        if totalSessions >= 100 { unlock("session_100") }
        if totalSessions >= 150 { unlock("session_150") }
        if totalSessions >= 200 { unlock("session_200") }
        if totalSessions >= 300 { unlock("session_300") }
        if totalSessions >= 500 { unlock("session_500") }
        if totalSessions >= 1000 { unlock("session_1000") }
        if totalSessions >= 2000 { unlock("session_2000") }
        if totalSessions >= 5000 { unlock("session_5000") }
        if totalSessions >= 10000 { unlock("session_10000") }
        if totalSessions >= 20000 { unlock("session_20000") }

        let dur = Date().timeIntervalSince(tab.startTime)
        if dur < 60 { unlock("speed_1min") }
        if dur < 120 { unlock("speed_2min") }
        if dur < 300 { unlock("speed_demon") }
        if dur > 900 { unlock("focus_15") }
        if dur > 1800 { unlock("focus_30") }
        if dur > 3600 { unlock("marathon") }
        if dur > 7200 { unlock("marathon_2h") }
        if dur > 10800 { unlock("ultra_marathon") }
        if dur > 14400 { unlock("marathon_4h") }
        if dur > 21600 { unlock("marathon_6h") }
        if dur > 28800 { unlock("marathon_8h") }
        if dur > 36000 { unlock("marathon_10h") }
        if dur > 43200 { unlock("marathon_12h") }
        if dur > 86400 { unlock("marathon_24h") }
        if dur > 172800 { unlock("marathon_48h") }
        if dur > 259200 { unlock("marathon_72h") }

        if tab.tokensUsed < 1000 && tab.tokensUsed > 0 { unlock("token_saver") }
        if tab.tokensUsed >= 2000 { unlock("token_2k_session") }
        if tab.tokensUsed >= 5000 { unlock("token_5k_session") }
        if tab.tokensUsed >= 10000 { unlock("token_whale") }
        if tab.tokensUsed >= 20000 { unlock("token_20k_session") }
        if tab.tokensUsed >= 30000 { unlock("token_30k_session") }
        if tab.tokensUsed >= 50000 { unlock("token_50k_session") }
        if tab.tokensUsed >= 100000 { unlock("token_100k_session") }
        if tab.tokensUsed >= 200000 { unlock("token_200k_session") }
        if tab.tokensUsed >= 500000 { unlock("token_500k_session") }
        if tab.tokensUsed >= 1000000 { unlock("token_1m_session") }
        if tab.tokensUsed >= 2000000 { unlock("token_2m_session") }
        if tab.tokensUsed >= 5000000 { unlock("token_5m_session") }

        // 누적 토큰 체크
        if totalTokensUsed >= 1000 { unlock("token_first_1k") }
        if totalTokensUsed >= 2000 { unlock("token_2k_total") }
        if totalTokensUsed >= 5000 { unlock("token_5k_total") }
        if totalTokensUsed >= 10000 { unlock("token_10k_total") }
        if totalTokensUsed >= 100000 { unlock("token_100k_total") }
        if totalTokensUsed >= 200000 { unlock("token_200k_total") }
        if totalTokensUsed >= 300000 { unlock("token_300k_total") }
        if totalTokensUsed >= 500000 { unlock("token_500k_total") }
        if totalTokensUsed >= 1000000 { unlock("token_million") }
        if totalTokensUsed >= 2000000 { unlock("token_2million") }
        if totalTokensUsed >= 3000000 { unlock("token_3million") }
        if totalTokensUsed >= 5000000 { unlock("token_5million") }
        if totalTokensUsed >= 10000000 { unlock("token_10million") }
        if totalTokensUsed >= 50000000 { unlock("token_50million") }
        if totalTokensUsed >= 100000000 { unlock("token_100million") }
        if totalTokensUsed >= 500000000 { unlock("token_500million") }
        if totalTokensUsed >= 1000000000 { unlock("token_1billion") }

        // 비용 기록
        recordCost(tab.totalCost)

        // 모델 기록
        recordModel(tab.selectedModel.rawValue)

        // 브랜치 기록
        if let branch = tab.branch { recordBranch(branch) }

        // 시간대 체크
        let hour = Calendar.current.component(.hour, from: Date())
        if hour >= 22 || hour < 5 { unlock("night_complete") }
        if hour >= 5 && hour < 9 { unlock("morning_complete") }

        addXP(30)
        saveState()
    }

    func checkErrorRecovery() {
        errorRecoveryCount += 1
        unlock("bug_squasher")
        if errorRecoveryCount >= 3 { unlock("error_3") }
        if errorRecoveryCount >= 5 { unlock("error_5") }
        if errorRecoveryCount >= 10 { unlock("error_10") }
        if errorRecoveryCount >= 15 { unlock("error_15") }
        if errorRecoveryCount >= 20 { unlock("error_20") }
        if errorRecoveryCount >= 25 { unlock("error_25") }
        if errorRecoveryCount >= 35 { unlock("error_35") }
        if errorRecoveryCount >= 50 { unlock("error_50") }
        if errorRecoveryCount >= 75 { unlock("error_75") }
        if errorRecoveryCount >= 100 { unlock("error_100") }
        if errorRecoveryCount >= 200 { unlock("error_200") }
        if errorRecoveryCount >= 500 { unlock("error_500") }
        if errorRecoveryCount >= 1000 { unlock("error_1000") }
        if errorRecoveryCount >= 2000 { unlock("error_2000") }
        saveState()
    }

    private func saveState() {
        // 디바운스: 연속 호출 시 마지막 호출만 실행 (2초 후)
        saveDebounceWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.saveStateNow()
        }
        saveDebounceWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: work)
    }

    private func saveStateNow() {
        let data: [String: Any] = [
            "totalXP": totalXP,
            "commandCount": commandCount,
            "unlocked": achievements.filter { $0.unlocked }.map { $0.id },
            "totalSessions": totalSessions,
            "totalCompletions": totalCompletions,
            "totalTokensUsed": totalTokensUsed,
            "totalCost": totalCost,
            "errorRecoveryCount": errorRecoveryCount,
            "totalFileEdits": totalFileEdits,
            "totalFileReads": totalFileReads,
            "usedModels": Array(usedModels),
            "uniqueBranches": Array(uniqueBranches),
            "activeDays": Array(activeDays),
            "nightDays": Array(nightDays),
            "weekendDays": Array(weekendDays),
            "lastLoginRewardDate": lastLoginRewardDate,
            "loginStreak": loginStreak,
        ]
        UserDefaults.standard.set(data, forKey: saveKey)
    }

    private func loadState() {
        guard let data = UserDefaults.standard.dictionary(forKey: saveKey) else { return }
        totalXP = data["totalXP"] as? Int ?? 0
        commandCount = data["commandCount"] as? Int ?? 0
        totalSessions = data["totalSessions"] as? Int ?? 0
        totalCompletions = data["totalCompletions"] as? Int ?? 0
        totalTokensUsed = data["totalTokensUsed"] as? Int ?? 0
        totalCost = data["totalCost"] as? Double ?? 0
        errorRecoveryCount = data["errorRecoveryCount"] as? Int ?? 0
        totalFileEdits = data["totalFileEdits"] as? Int ?? 0
        totalFileReads = data["totalFileReads"] as? Int ?? 0
        if let models = data["usedModels"] as? [String] { usedModels = Set(models) }
        if let branches = data["uniqueBranches"] as? [String] { uniqueBranches = Set(branches) }
        if let days = data["activeDays"] as? [String] { activeDays = Set(days) }
        if let nights = data["nightDays"] as? [String] { nightDays = Set(nights) }
        if let weekends = data["weekendDays"] as? [String] { weekendDays = Set(weekends) }
        lastLoginRewardDate = data["lastLoginRewardDate"] as? String ?? ""
        loginStreak = data["loginStreak"] as? Int ?? 0
        if let unlocked = data["unlocked"] as? [String] {
            for id in unlocked {
                if let idx = achievements.firstIndex(where: { $0.id == id }) {
                    achievements[idx].unlocked = true
                }
            }
        }
        unlockedCount = achievements.filter { $0.unlocked }.count
    }

    private func enqueueRecentUnlock(_ achievement: Achievement) {
        toastQueue.append(achievement)
        showNextRecentUnlockIfNeeded()
    }

    private func showNextRecentUnlockIfNeeded() {
        guard recentUnlock == nil, !toastQueue.isEmpty else { return }
        let nextAchievement = toastQueue.removeFirst()
        recentUnlock = nextAchievement
        scheduleRecentUnlockDismiss(for: nextAchievement.id)
    }

    private func scheduleRecentUnlockDismiss(for id: String) {
        toastDismissWork?.cancel()

        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            guard self.recentUnlock?.id == id else { return }
            self.recentUnlock = nil
            self.toastDismissWork = nil
            self.showNextRecentUnlockIfNeeded()
        }

        toastDismissWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 4, execute: work)
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - Achievement Toast (팝업 알림)
// ═══════════════════════════════════════════════════════

struct AchievementToastView: View {
    let achievement: Achievement
    let onDismiss: () -> Void
    @State private var isVisible = false

    var body: some View {
        Button(action: onDismiss) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(achievement.rarity.color.opacity(0.16))
                    Text(achievement.icon)
                        .font(Theme.scaled(15))
                }
                .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(achievement.localizedName)
                        .font(Theme.mono(10, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                        .lineLimit(1)
                    Text(NSLocalizedString("game.achievement.unlocked", comment: ""))
                        .font(Theme.mono(8, weight: .medium))
                        .foregroundColor(achievement.rarity.color)
                }

                Spacer(minLength: 8)

                Image(systemName: "xmark")
                    .font(.system(size: Theme.iconSize(8), weight: .bold))
                    .foregroundColor(Theme.textDim.opacity(0.8))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(minWidth: 180, maxWidth: 240, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 13)
                    .fill(Theme.bgCard.opacity(0.98))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 13)
                    .stroke(achievement.rarity.color.opacity(0.28), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .help(NSLocalizedString("game.toast.dismiss", comment: ""))
        .scaleEffect(isVisible ? 1 : 0.97)
        .opacity(isVisible ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.24, dampingFraction: 0.9)) {
                isVisible = true
            }
        }
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - XP Bar (사이드바용 — 컴팩트)
// ═══════════════════════════════════════════════════════

struct XPBarView: View {
    let xp: Int
    var body: some View {
        let level = WorkerLevel.forXP(xp)
        let progress = WorkerLevel.progress(xp)
        HStack(spacing: 6) {
            Text(level.badge).font(Theme.scaled(12))
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("Lv.\(level.level) \(level.title)")
                        .font(Theme.mono(8, weight: .bold)).foregroundColor(Theme.yellow)
                    Spacer()
                    Text("\(xp) XP").font(Theme.mono(7)).foregroundColor(Theme.textDim)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2).fill(Theme.bg).frame(height: 3)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(LinearGradient(colors: [Theme.yellow, Theme.orange], startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(2, geo.size.width * CGFloat(progress)), height: 3)
                    }
                }.frame(height: 3)
            }
        }
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - 도전과제 관리 시트 (풀 화면 패널)
// ═══════════════════════════════════════════════════════

struct AchievementCollectionView: View {
    @ObservedObject var mgr = AchievementManager.shared
    @Environment(\.dismiss) var dismiss
    @State private var selectedRarity: AchievementRarity? = nil
    @State private var showUnlockedOnly = false
    @State private var inspectedAchievement: Achievement? = nil

    private let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 14), count: 4)

    private var completionPercent: Int {
        Int(Double(mgr.unlockedCount) / Double(max(1, mgr.achievements.count)) * 100)
    }

    private func itemsFor(_ rarity: AchievementRarity) -> [Achievement] {
        mgr.achievements.filter { $0.rarity == rarity && (!showUnlockedOnly || $0.unlocked) }
    }

    var body: some View {
        VStack(spacing: 0) {
            DSModalHeader(
                icon: "trophy.fill",
                iconColor: Theme.yellow,
                title: NSLocalizedString("sidebar.achievements", comment: ""),
                subtitle: "\(mgr.unlockedCount)/\(mgr.achievements.count) · \(completionPercent)%",
                trailing: AnyView(
                    DSProgressBar(value: Double(mgr.unlockedCount) / Double(max(1, mgr.achievements.count)), tint: Theme.yellow)
                        .frame(width: 80)
                ),
                onClose: { dismiss() }
            )

            // 필터 바
            filterBar
                .padding(.horizontal, Theme.sp5).padding(.vertical, Theme.sp2)
                .background(Theme.bgCard)

            Rectangle().fill(Theme.border).frame(height: 1)

            // ═══════════ 본문: 카드 그리드 ═══════════
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 24) {
                    if selectedRarity == nil {
                        raritySection(.mythic)
                        raritySection(.legendary)
                        raritySection(.epic)
                        raritySection(.rare)
                        raritySection(.common)
                    } else {
                        let items = mgr.achievements
                            .filter { $0.rarity == selectedRarity && (!showUnlockedOnly || $0.unlocked) }
                            .sorted { ($0.unlocked ? 0 : 1) < ($1.unlocked ? 0 : 1) }
                        LazyVGrid(columns: gridColumns, spacing: 14) {
                            ForEach(items) { ach in
                                AchievementCard(achievement: ach)
                                    .onTapGesture { if ach.unlocked { withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { inspectedAchievement = ach } } }
                            }
                        }
                        .id("\(selectedRarity?.rawValue ?? "all")-\(showUnlockedOnly)")
                    }
                }
                .padding(.horizontal, 24).padding(.vertical, 16)
            }
        }
        .background(Theme.bg)
        .overlay(detailOverlay)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Line 1: Title + counter + close button
            HStack {
                Text("🏆").font(Theme.scaled(16))
                Text("ACHIEVEMENTS")
                    .font(Theme.mono(14, weight: .heavy))
                    .foregroundColor(Theme.textPrimary).tracking(2)
                Text("\(mgr.unlockedCount) / \(mgr.achievements.count)")
                    .font(Theme.mono(12, weight: .bold))
                    .foregroundColor(Theme.textSecondary)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: Theme.iconSize(18)))
                        .foregroundColor(Theme.textDim.opacity(0.5))
                }
                .buttonStyle(.plain)
                .help(NSLocalizedString("game.close.hint", comment: ""))
            }

            // Line 2: Wide progress bar
            GeometryReader { geo in
                let fraction = Double(mgr.unlockedCount) / Double(max(1, mgr.achievements.count))
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(Theme.border.opacity(0.15)).frame(height: 8)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(LinearGradient(colors: [Theme.yellow, Theme.orange], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(4, geo.size.width * CGFloat(fraction)), height: 8)
                }
            }.frame(height: 8)

            // Line 3: Compact stats inline
            HStack(spacing: 16) {
                let level = mgr.currentLevel
                HStack(spacing: 4) {
                    Text(level.badge).font(Theme.scaled(12))
                    Text("Lv.\(level.level) \(level.title)")
                        .font(Theme.mono(10, weight: .bold))
                        .foregroundColor(Theme.yellow)
                }
                Text("·").foregroundColor(Theme.textDim)
                inlineStat(label: "XP", value: "\(mgr.totalXP)", color: Theme.yellow)
                Text("·").foregroundColor(Theme.textDim)
                inlineStat(label: NSLocalizedString("game.stat.commands", comment: ""), value: "\(mgr.commandCount)", color: Theme.accent)
                Text("·").foregroundColor(Theme.textDim)
                inlineStat(label: NSLocalizedString("game.stat.tokens", comment: ""), value: formatTokens(mgr.totalTokensUsed), color: Theme.cyan)
                Text("·").foregroundColor(Theme.textDim)
                inlineStat(label: NSLocalizedString("game.stat.activity", comment: ""), value: "\(mgr.activeDays.count)\(NSLocalizedString("game.stat.days.suffix", comment: ""))", color: Theme.orange)
                Spacer()
                Text(String(format: NSLocalizedString("game.completion.percent", comment: ""), completionPercent))
                    .font(Theme.mono(11, weight: .black))
                    .foregroundColor(Theme.yellow)
            }
        }
    }

    private func inlineStat(label: String, value: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Text(value).font(Theme.mono(10, weight: .bold)).foregroundColor(color)
            Text(label).font(Theme.mono(8)).foregroundColor(Theme.textDim)
        }
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        HStack(spacing: 6) {
            filterTab(label: NSLocalizedString("status.all", comment: ""), rarity: nil, count: mgr.achievements.count, unlocked: mgr.unlockedCount)
            ForEach([AchievementRarity.mythic, .legendary, .epic, .rare, .common], id: \.rawValue) { r in
                filterTab(label: r.displayName, rarity: r,
                          count: mgr.achievements.filter { $0.rarity == r }.count,
                          unlocked: mgr.achievements.filter { $0.rarity == r && $0.unlocked }.count)
            }

            Spacer()

            Button(action: { withAnimation(.easeInOut(duration: 0.15)) { showUnlockedOnly.toggle() } }) {
                HStack(spacing: 5) {
                    Image(systemName: showUnlockedOnly ? "eye.fill" : "eye").font(.system(size: Theme.iconSize(11)))
                    Text(showUnlockedOnly ? NSLocalizedString("game.filter.unlocked", comment: "") : NSLocalizedString("game.filter.all", comment: ""))
                        .font(Theme.mono(11, weight: .medium))
                }
                .foregroundColor(showUnlockedOnly ? Theme.accent : Theme.textDim)
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: Theme.cornerMedium).fill(showUnlockedOnly ? Theme.accent.opacity(0.12) : Theme.bgSurface)
                        .overlay(RoundedRectangle(cornerRadius: Theme.cornerMedium).stroke(showUnlockedOnly ? Theme.accent.opacity(0.3) : Theme.border.opacity(0.2), lineWidth: 1))
                )
            }.buttonStyle(.plain)
        }
    }

    private func filterTab(label: String, rarity: AchievementRarity?, count: Int, unlocked: Int) -> some View {
        let isSelected = (selectedRarity == nil && rarity == nil) || selectedRarity == rarity
        let color = rarity?.color ?? Theme.yellow

        return Button(action: { withAnimation(.easeInOut(duration: 0.15)) { selectedRarity = rarity } }) {
            HStack(spacing: 6) {
                if let r = rarity { Circle().fill(r.color).frame(width: 7, height: 7) }
                Text(label).font(Theme.mono(11, weight: isSelected ? .bold : .medium))
                Text("\(unlocked)")
                    .font(Theme.mono(10, weight: .bold))
                    .foregroundColor(isSelected ? color : Theme.textDim)
            }
            .foregroundColor(isSelected ? color : Theme.textSecondary)
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: Theme.cornerMedium)
                    .fill(isSelected ? color.opacity(0.12) : .clear)
                    .overlay(RoundedRectangle(cornerRadius: Theme.cornerMedium).stroke(isSelected ? color.opacity(0.4) : Theme.border.opacity(0.15), lineWidth: isSelected ? 1 : 0.5))
            )
        }.buttonStyle(.plain)
    }

    private func formatTokens(_ count: Int) -> String {
        if count >= 1000000 { return String(format: "%.1fM", Double(count) / 1000000) }
        if count >= 1000 { return String(format: "%.1fK", Double(count) / 1000) }
        return "\(count)"
    }

    // MARK: - Rarity Section

    private func raritySection(_ rarity: AchievementRarity) -> some View {
        let items = itemsFor(rarity).sorted { ($0.unlocked ? 0 : 1) < ($1.unlocked ? 0 : 1) }
        let unlocked = items.filter { $0.unlocked }.count
        let total = mgr.achievements.filter { $0.rarity == rarity }.count
        let progress = Double(unlocked) / Double(max(1, total))

        return Group {
            if !items.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    // 섹션 헤더
                    sectionHeader(rarity: rarity, unlocked: unlocked, total: total, progress: progress)

                    LazyVGrid(columns: gridColumns, spacing: 14) {
                        ForEach(items) { ach in
                            AchievementCard(achievement: ach)
                                .onTapGesture { if ach.unlocked { withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { inspectedAchievement = ach } } }
                        }
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(sectionBg(rarity))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(rarity.color.opacity(0.08), lineWidth: 1))
                )
            }
        }
    }

    private func sectionHeader(rarity: AchievementRarity, unlocked: Int, total: Int, progress: Double) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2).fill(rarity.color).frame(width: 3, height: 14)
            Text(rarity.displayName.uppercased())
                .font(Theme.mono(10, weight: .heavy))
                .foregroundColor(rarity.color).tracking(2)

            Text("\(unlocked)/\(total)")
                .font(Theme.mono(8, weight: .bold))
                .foregroundColor(rarity.color)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(Capsule().fill(rarity.color.opacity(0.1)).overlay(Capsule().stroke(rarity.color.opacity(0.2), lineWidth: 1)))

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2).fill(rarity.color.opacity(0.06)).frame(height: 5)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(rarity.color.opacity(0.4))
                        .frame(width: max(2, geo.size.width * CGFloat(progress)), height: 5)
                }
            }.frame(height: 5)

            if unlocked == total && total > 0 {
                HStack(spacing: 3) {
                    Image(systemName: "checkmark.seal.fill").font(.system(size: Theme.iconSize(9))).foregroundColor(Theme.green)
                    Text(NSLocalizedString("game.section.complete", comment: "")).font(Theme.mono(7, weight: .heavy)).foregroundColor(Theme.green).tracking(1)
                }
            }
        }
    }

    private func sectionBg(_ rarity: AchievementRarity) -> Color {
        if AppSettings.shared.isDarkMode {
            switch rarity {
            case .mythic: return Color(hex: "160a0a")
            case .legendary: return Color(hex: "12110d")
            case .epic: return Color(hex: "110f16")
            case .rare: return Color(hex: "0e1018")
            case .common: return Color(hex: "0e1014")
            }
        } else {
            switch rarity {
            case .mythic: return Color(hex: "fdf2f2")
            case .legendary: return Color(hex: "faf6ed")
            case .epic: return Color(hex: "f4f0f8")
            case .rare: return Color(hex: "eef2f9")
            case .common: return Color(hex: "f2f2f5")
            }
        }
    }
    // MARK: - Detail Overlay (카드형 상세 뷰)

    @ViewBuilder
    private var detailOverlay: some View {
        if let ach = inspectedAchievement {
            ZStack {
                // 딤 배경
                Color.black.opacity(0.6)
                    .ignoresSafeArea()
                    .onTapGesture { withAnimation(.easeOut(duration: 0.2)) { inspectedAchievement = nil } }

                AchievementDetailCard(achievement: ach) {
                    withAnimation(.easeOut(duration: 0.2)) { inspectedAchievement = nil }
                }
                .transition(.scale(scale: 0.85).combined(with: .opacity))
            }
        }
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - Achievement Detail Card (수집형 카드)
// ═══════════════════════════════════════════════════════

struct AchievementDetailCard: View {
    let achievement: Achievement
    let onClose: () -> Void
    @State private var appeared = false

    private var rarityGradient: [Color] {
        switch achievement.rarity {
        case .mythic: return [Color(hex: "2a1010"), Color(hex: "1a0808"), Color(hex: "120606")]
        case .legendary: return [Color(hex: "2a2410"), Color(hex: "1a1608"), Color(hex: "12100a")]
        case .epic: return [Color(hex: "1e1628"), Color(hex: "15101e"), Color(hex: "100c18")]
        case .rare: return [Color(hex: "101828"), Color(hex: "0c1220"), Color(hex: "0a0e18")]
        case .common: return [Color(hex: "161a22"), Color(hex: "12151c"), Color(hex: "0e1016")]
        }
    }

    private var rarityGradientLight: [Color] {
        switch achievement.rarity {
        case .mythic: return [Color(hex: "fef2f2"), Color(hex: "fdeaea"), Color(hex: "fce2e2")]
        case .legendary: return [Color(hex: "fef9ec"), Color(hex: "fdf5e0"), Color(hex: "faf0d4")]
        case .epic: return [Color(hex: "f8f2fc"), Color(hex: "f3ecf9"), Color(hex: "eee6f6")]
        case .rare: return [Color(hex: "eef4fc"), Color(hex: "e8eef8"), Color(hex: "e2e8f4")]
        case .common: return [Color(hex: "f6f6f9"), Color(hex: "f0f0f4"), Color(hex: "eaeaef")]
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── 카드 상단: 레어리티 배너 ──
            HStack {
                HStack(spacing: 5) {
                    Circle().fill(achievement.rarity.color).frame(width: 7, height: 7)
                    Text(achievement.rarity.displayName.uppercased())
                        .font(Theme.mono(9, weight: .heavy))
                        .foregroundColor(achievement.rarity.color).tracking(2)
                }
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: Theme.iconSize(10), weight: .bold))
                        .foregroundColor(Theme.textDim.opacity(0.6))
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(Theme.bgSurface.opacity(0.5)))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 8)

            // ── 아이콘 영역 ──
            ZStack {
                // 다중 글로우 링
                Circle()
                    .fill(RadialGradient(
                        colors: [achievement.rarity.color.opacity(0.2), achievement.rarity.color.opacity(0.05), .clear],
                        center: .center, startRadius: 0, endRadius: 60
                    ))
                    .frame(width: 120, height: 120)
                Circle()
                    .stroke(achievement.rarity.color.opacity(0.15), lineWidth: 1)
                    .frame(width: 80, height: 80)
                Circle()
                    .stroke(achievement.rarity.color.opacity(0.08), lineWidth: 1)
                    .frame(width: 100, height: 100)
                Text(achievement.icon)
                    .font(Theme.scaled(52))
                    .scaleEffect(appeared ? 1.0 : 0.5)
                    .opacity(appeared ? 1 : 0)
            }
            .padding(.vertical, 10)

            // ── 이름 ──
            Text(achievement.localizedName)
                .font(Theme.mono(18, weight: .bold))
                .foregroundColor(Theme.textPrimary)
                .padding(.top, 4)

            // ── 설명 ──
            Text(achievement.localizedDescription)
                .font(Theme.mono(12))
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24).padding(.top, 6)

            Spacer().frame(height: 20)

            // ── 하단 정보 패널 ──
            VStack(spacing: 10) {
                Rectangle().fill(achievement.rarity.color.opacity(0.15)).frame(height: 1)
                    .padding(.horizontal, 16)

                HStack(spacing: 0) {
                    detailItem(label: NSLocalizedString("game.reward", comment: ""), value: "+\(achievement.xpReward) XP", color: Theme.yellow)
                    detailDivider
                    detailItem(label: NSLocalizedString("game.grade", comment: ""), value: achievement.rarity.displayName, color: achievement.rarity.color)
                    detailDivider
                    if let date = achievement.unlockedAt {
                        detailItem(label: NSLocalizedString("game.unlock.date", comment: ""), value: fmtDateFull(date), color: Theme.green)
                    }
                }
                .padding(.horizontal, 12)
            }
            .padding(.bottom, 20)
        }
        .frame(width: 280, height: 380)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(LinearGradient(
                        colors: AppSettings.shared.isDarkMode ? rarityGradient : rarityGradientLight,
                        startPoint: .top, endPoint: .bottom
                    ))
                // 외곽 글로우 보더
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [achievement.rarity.color.opacity(0.5), achievement.rarity.color.opacity(0.15), achievement.rarity.color.opacity(0.5)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ), lineWidth: 1
                    )
            }
        )
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.65).delay(0.1)) { appeared = true }
        }
    }

    private func detailItem(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(label)
                .font(Theme.mono(7, weight: .medium))
                .foregroundColor(Theme.textDim).tracking(0.5)
            Text(value)
                .font(Theme.mono(11, weight: .bold))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
    }

    private var detailDivider: some View {
        Rectangle().fill(Theme.border.opacity(0.15)).frame(width: 1, height: 28)
    }

    private func fmtDateFull(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "yy.M.d"; return f.string(from: date)
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - Achievement Card
// ═══════════════════════════════════════════════════════

struct AchievementCard: View {
    let achievement: Achievement
    @State private var isHovered = false

    private var cardBg: Color {
        // 앱 톤 유지: bgCard 위에 rarity 색상을 미세하게 올림
        Theme.bgCard
    }

    var body: some View {
        VStack(spacing: 4) {
            if achievement.unlocked {
                unlockedContent
            } else {
                lockedContent
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: achievement.unlocked ? 110 : 70)
        .background(cardBackground)
        .scaleEffect(isHovered ? 1.03 : 1.0)
        .animation(.easeOut(duration: 0.15), value: isHovered)
        .onHover { h in withAnimation(.easeInOut(duration: 0.12)) { isHovered = h } }
    }

    // MARK: - Unlocked

    private var unlockedContent: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [achievement.rarity.color.opacity(0.25), .clear], center: .center, startRadius: 0, endRadius: 22))
                    .frame(width: 40, height: 40)
                Text(achievement.icon).font(Theme.scaled(22))
            }
            Text(achievement.localizedName)
                .font(Theme.mono(10, weight: .bold))
                .foregroundColor(Theme.textPrimary)
                .lineLimit(1)
            Text(achievement.localizedDescription)
                .font(Theme.mono(8))
                .foregroundColor(Theme.textSecondary)
                .lineLimit(2).multilineTextAlignment(.center)
                .frame(minHeight: 20)
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill").font(.system(size: Theme.iconSize(7))).foregroundColor(Theme.green)
                if let date = achievement.unlockedAt {
                    Text(fmtDate(date)).font(Theme.mono(7)).foregroundColor(Theme.textDim)
                }
                Spacer()
                Text("+\(achievement.xpReward) XP")
                    .font(Theme.mono(8, weight: .bold))
                    .foregroundColor(achievement.rarity.color)
            }
        }
    }

    // MARK: - Locked

    private var lockedContent: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle().fill(Theme.bgSurface.opacity(0.2)).frame(width: 28, height: 28)
                Circle().stroke(Theme.border.opacity(0.1), style: StrokeStyle(lineWidth: 1, dash: [3, 3])).frame(width: 28, height: 28)
                Image(systemName: "lock.fill").font(.system(size: Theme.iconSize(8))).foregroundColor(Theme.textDim.opacity(0.15))
            }
            Text("???")
                .font(Theme.mono(8, weight: .medium))
                .foregroundColor(Theme.textDim.opacity(0.2))
            if isHovered {
                Text(achievement.localizedDescription)
                    .font(Theme.mono(7))
                    .foregroundColor(Theme.textDim.opacity(0.4))
                    .lineLimit(2).multilineTextAlignment(.center)
                    .transition(.opacity)
            }
            Spacer(minLength: 0)
            HStack(spacing: 2) {
                Image(systemName: "star.fill").font(.system(size: Theme.iconSize(5))).foregroundColor(Theme.yellow.opacity(0.1))
                Text("+\(achievement.xpReward)").font(Theme.mono(7)).foregroundColor(Theme.yellow.opacity(0.1))
                Spacer()
            }
        }
    }

    // MARK: - Background

    private var cardBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Theme.cornerLarge)
                .fill(achievement.unlocked ? cardBg : Theme.bgSurface.opacity(0.04))

            if achievement.unlocked {
                // Left rarity stripe
                HStack {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(achievement.rarity.color.opacity(0.5))
                        .frame(width: 2)
                        .padding(.vertical, 8)
                    Spacer()
                }
            }

            RoundedRectangle(cornerRadius: Theme.cornerLarge)
                .stroke(
                    achievement.unlocked
                        ? Theme.accentBorder(achievement.rarity.color)
                        : Theme.border.opacity(isHovered ? 0.3 : 0.1),
                    lineWidth: 1
                )
        }
    }

    private func fmtDate(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "M/d"; return f.string(from: date)
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - 사이드바용 업적 없음 (레벨만 유지)
// ═══════════════════════════════════════════════════════

struct AchievementsView: View {
    var body: some View { EmptyView() }
}
