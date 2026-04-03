import SwiftUI
import DesignSystem

// ═══════════════════════════════════════════════════════
// MARK: - Achievement Toast (팝업 알림)
// ═══════════════════════════════════════════════════════

public struct AchievementToastView: View {
    let achievement: Achievement
    let onDismiss: () -> Void
    @State private var isVisible = false

    public init(achievement: Achievement, onDismiss: @escaping () -> Void) {
        self.achievement = achievement; self.onDismiss = onDismiss
    }

    public var body: some View {
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

public struct XPBarView: View {
    let xp: Int

    public init(xp: Int) { self.xp = xp }

    public var body: some View {
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

public struct AchievementCollectionView: View {
    @ObservedObject var mgr = AchievementManager.shared
    @Environment(\.dismiss) var dismiss
    @State private var selectedRarity: AchievementRarity? = nil
    @State private var showUnlockedOnly = false
    @State private var inspectedAchievement: Achievement? = nil

    public init() {}

    private let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 14), count: 4)

    private var completionPercent: Int {
        Int(Double(mgr.unlockedCount) / Double(max(1, mgr.achievements.count)) * 100)
    }

    private func itemsFor(_ rarity: AchievementRarity) -> [Achievement] {
        mgr.achievements.filter { $0.rarity == rarity && (!showUnlockedOnly || $0.unlocked) }
    }

    public var body: some View {
        VStack(spacing: 0) {
            DSModalHeader(
                icon: "trophy.fill",
                iconColor: Theme.yellow,
                title: NSLocalizedString("sidebar.achievements", comment: ""),
                subtitle: "\(mgr.unlockedCount)/\(mgr.achievements.count) · \(completionPercent)%",
                trailing: DSProgressBar(value: Double(mgr.unlockedCount) / Double(max(1, mgr.achievements.count)), tint: Theme.yellow)
                        .frame(width: 80),
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
                inlineStat(label: NSLocalizedString("game.stat.tokens", comment: ""), value: mgr.totalTokensUsed.tokenFormatted, color: Theme.cyan)
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

public struct AchievementDetailCard: View {
    let achievement: Achievement
    let onClose: () -> Void
    @State private var appeared = false

    public init(achievement: Achievement, onClose: @escaping () -> Void) {
        self.achievement = achievement; self.onClose = onClose
    }

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

    public var body: some View {
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

public struct AchievementCard: View {
    let achievement: Achievement
    @State private var isHovered = false

    public init(achievement: Achievement) { self.achievement = achievement }

    private var cardBg: Color {
        // 앱 톤 유지: bgCard 위에 rarity 색상을 미세하게 올림
        Theme.bgCard
    }

    public var body: some View {
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

public struct AchievementsView: View {
    public init() {}
    public var body: some View { EmptyView() }
}
