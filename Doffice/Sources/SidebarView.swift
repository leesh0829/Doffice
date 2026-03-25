import SwiftUI
import AppKit

private struct CollapsibleSidebarPanel<Content: View>: View {
    let title: String
    let icon: String
    let tint: Color
    let storageKey: String
    @ViewBuilder let content: Content
    @AppStorage private var isCollapsed: Bool

    init(title: String, icon: String, tint: Color, storageKey: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.tint = tint
        self.storageKey = storageKey
        self.content = content()
        self._isCollapsed = AppStorage(wrappedValue: false, storageKey)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: isCollapsed ? 0 : 10) {
            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { isCollapsed.toggle() } }) {
                HStack(spacing: 6) {
                    Image(systemName: icon).font(Theme.chrome(9)).foregroundColor(tint)
                    Text(title.uppercased()).font(Theme.pixel).foregroundColor(Theme.textDim).tracking(2)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(Theme.textDim.opacity(0.5))
                        .rotationEffect(.degrees(isCollapsed ? 0 : 90))
                }
            }.buttonStyle(.plain)

            if !isCollapsed {
                content
            }
        }
        .appPanelStyle(padding: Theme.sp3, radius: Theme.cornerLarge, fill: Theme.bgCard, strokeOpacity: Theme.borderDefault, shadow: false)
    }
}

private enum SessionStatusFilter: String, CaseIterable, Identifiable {
    case all
    case active
    case processing
    case completed
    case attention

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: return NSLocalizedString("status.all", comment: "")
        case .active: return NSLocalizedString("status.active", comment: "")
        case .processing: return NSLocalizedString("status.processing", comment: "")
        case .completed: return NSLocalizedString("status.completed", comment: "")
        case .attention: return NSLocalizedString("status.attention", comment: "")
        }
    }

    var symbol: String {
        switch self {
        case .all: return "square.grid.2x2.fill"
        case .active: return "bolt.fill"
        case .processing: return "gearshape.2.fill"
        case .completed: return "checkmark.circle.fill"
        case .attention: return "exclamationmark.triangle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .all: return Theme.textSecondary
        case .active: return Theme.green
        case .processing: return Theme.accent
        case .completed: return Theme.green
        case .attention: return Theme.red
        }
    }
}

private enum SidebarSortOption: String, CaseIterable, Identifiable {
    case recent
    case name
    case tokens
    case status

    var id: String { rawValue }

    var label: String {
        switch self {
        case .recent: return NSLocalizedString("sidebar.sort.recent", comment: "")
        case .name: return NSLocalizedString("sidebar.sort.name", comment: "")
        case .tokens: return NSLocalizedString("sidebar.sort.tokens", comment: "")
        case .status: return NSLocalizedString("sidebar.sort.status", comment: "")
        }
    }
}

struct SidebarView: View {
    @EnvironmentObject var manager: SessionManager
    @ObservedObject private var settings = AppSettings.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let forceCompact: Bool
    @AppStorage("viewMode") private var appViewModeRaw: Int = 1
    @State private var draggingTabId: String?
    @State private var showHistory: Bool = false
    @State private var searchQuery: String = ""
    @State private var isMultiSelectMode = false
    @State private var selectedTabIds: Set<String> = []
    @AppStorage("workman.sidebarStatusFilter") private var statusFilterRaw: String = SessionStatusFilter.all.rawValue
    @AppStorage("workman.sidebarSortOption") private var sortOptionRaw: String = SidebarSortOption.recent.rawValue

    private var statusFilter: SessionStatusFilter {
        get { SessionStatusFilter(rawValue: statusFilterRaw) ?? .all }
        nonmutating set { statusFilterRaw = newValue.rawValue }
    }
    private var sortOption: SidebarSortOption {
        get { SidebarSortOption(rawValue: sortOptionRaw) ?? .recent }
        nonmutating set { sortOptionRaw = newValue.rawValue }
    }
    private var sortOptionBinding: Binding<SidebarSortOption> {
        Binding(
            get: { SidebarSortOption(rawValue: sortOptionRaw) ?? .recent },
            set: { sortOptionRaw = $0.rawValue }
        )
    }

    private var isTerminalOnlyMode: Bool {
        appViewModeRaw == 2
    }

    init(forceCompact: Bool = false) {
        self.forceCompact = forceCompact
    }

    private var isCompactChrome: Bool {
        forceCompact || (isTerminalOnlyMode && settings.terminalSidebarLightweight)
    }

    private var filteredProjectGroups: [SessionManager.ProjectGroup] {
        let loweredQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        let groups = manager.projectGroups.compactMap { group -> SessionManager.ProjectGroup? in
            let matchingTabs = group.tabs
                .filter { tab in
                    matchesQuery(tab, loweredQuery: loweredQuery) && matchesFilter(tab)
                }
                .sorted(by: tabSortComparator(lhs:rhs:))

            guard !matchingTabs.isEmpty else { return nil }
            return SessionManager.ProjectGroup(
                id: group.id,
                projectName: group.projectName,
                tabs: matchingTabs,
                hasActiveTab: matchingTabs.contains(where: { $0.id == manager.activeTabId })
            )
        }

        return groups.sorted { lhs, rhs in
            compareGroups(lhs, rhs)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "circle.grid.2x2.fill").font(Theme.chrome(9)).foregroundColor(Theme.textDim)
                Text(NSLocalizedString("sessions", comment: "").uppercased()).font(Theme.pixel).foregroundColor(Theme.textDim).tracking(2)
                Spacer()
                Button(action: { showHistory.toggle() }) {
                    Image(systemName: "clock.arrow.circlepath").font(Theme.chrome(9))
                        .foregroundColor(showHistory ? Theme.accent : Theme.textDim)
                }.buttonStyle(.plain).help(NSLocalizedString("sidebar.help.history", comment: ""))
                Button(action: { isMultiSelectMode.toggle(); if !isMultiSelectMode { selectedTabIds.removeAll() } }) {
                    Image(systemName: isMultiSelectMode ? "checkmark.circle.fill" : "checkmark.circle")
                        .font(.system(size: Theme.chromeIconSize(11)))
                        .foregroundColor(isMultiSelectMode ? Theme.accent : Theme.textDim)
                }
                .buttonStyle(.plain)
                .help(NSLocalizedString("sidebar.help.multiselect", comment: ""))
                Text("\(manager.userVisibleTabCount)")
                    .font(Theme.chrome(9, weight: .medium)).foregroundColor(Theme.textDim)
                    .padding(.horizontal, Theme.sp1 + 2).padding(.vertical, 1)
                    .background(RoundedRectangle(cornerRadius: Theme.cornerSmall).fill(Theme.bgSurface))
            }
            .padding(.horizontal, Theme.sp3).padding(.vertical, Theme.sp2)

            if showHistory { SessionHistoryView() }

            newSessionQuickAction
                .padding(.horizontal, Theme.sp2)
                .padding(.bottom, Theme.sp2)

            sessionExplorerPanel
                .padding(.horizontal, Theme.sp2)
                .padding(.bottom, Theme.sp2)

            // "전체" 버튼
            if manager.selectedGroupPath != nil {
                Button(action: { manager.selectedGroupPath = nil; manager.focusSingleTab = false }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left").font(Theme.chrome(8, weight: .bold))
                        Text(NSLocalizedString("sidebar.view.all", comment: "")).font(Theme.chrome(9, weight: .medium))
                        Spacer()
                    }
                    .foregroundColor(Theme.accent)
                    .padding(.horizontal, 14).padding(.vertical, 6)
                }.buttonStyle(.plain)
            }

            ScrollView {
                let groups = filteredProjectGroups
                VStack(spacing: 4) {
                    if groups.isEmpty {
                        AppEmptyStateView(
                            title: NSLocalizedString("session.no.match", comment: ""),
                            message: searchQuery.isEmpty ? NSLocalizedString("session.no.match.hint", comment: "") : NSLocalizedString("sidebar.search.adjust", comment: ""),
                            symbol: searchQuery.isEmpty ? "rectangle.stack.badge.plus" : "magnifyingglass",
                            tint: searchQuery.isEmpty ? Theme.accent : Theme.textDim
                        )
                    } else {
                        ForEach(groups) { group in
                            if group.tabs.count == 1 {
                                let tab = group.tabs[0]
                                SessionCard(tab: tab)
                                    .overlay(alignment: .leading) {
                                        if isMultiSelectMode {
                                            Image(systemName: selectedTabIds.contains(tab.id) ? "checkmark.circle.fill" : "circle")
                                                .font(.system(size: 14))
                                                .foregroundColor(selectedTabIds.contains(tab.id) ? Theme.accent : Theme.textDim)
                                                .padding(.leading, 6)
                                        }
                                    }
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        if isMultiSelectMode {
                                            if selectedTabIds.contains(tab.id) {
                                                selectedTabIds.remove(tab.id)
                                            } else {
                                                selectedTabIds.insert(tab.id)
                                            }
                                        }
                                    }
                                    .allowsHitTesting(isMultiSelectMode ? true : false)
                            } else {
                                SessionGroupCard(group: group)
                                    .overlay(alignment: .leading) {
                                        if isMultiSelectMode {
                                            VStack(spacing: 4) {
                                                ForEach(group.tabs) { tab in
                                                    Image(systemName: selectedTabIds.contains(tab.id) ? "checkmark.circle.fill" : "circle")
                                                        .font(.system(size: 14))
                                                        .foregroundColor(selectedTabIds.contains(tab.id) ? Theme.accent : Theme.textDim)
                                                        .onTapGesture {
                                                            if selectedTabIds.contains(tab.id) {
                                                                selectedTabIds.remove(tab.id)
                                                            } else {
                                                                selectedTabIds.insert(tab.id)
                                                            }
                                                        }
                                                }
                                            }
                                            .padding(.leading, 6)
                                        }
                                    }
                            }
                        }
                    }
                }.padding(.horizontal, 8).padding(.vertical, 4)
            }

            if isMultiSelectMode && !selectedTabIds.isEmpty {
                HStack(spacing: 8) {
                    Text(String(format: NSLocalizedString("sidebar.selected.count", comment: ""), selectedTabIds.count)).font(Theme.chrome(9, weight: .bold)).foregroundColor(Theme.accent)
                    Spacer()
                    Button(action: { batchRestart() }) {
                        Image(systemName: "arrow.clockwise").font(.system(size: 10))
                    }.buttonStyle(.plain).help(NSLocalizedString("sidebar.help.restart", comment: ""))
                    Button(action: { batchStop() }) {
                        Image(systemName: "stop.fill").font(.system(size: 10)).foregroundColor(Theme.red)
                    }.buttonStyle(.plain).help(NSLocalizedString("sidebar.help.stop", comment: ""))
                    Button(action: { batchClose() }) {
                        Image(systemName: "xmark").font(.system(size: 10)).foregroundColor(Theme.red)
                    }.buttonStyle(.plain).help(NSLocalizedString("close", comment: ""))
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Theme.bgCard)
                .overlay(Rectangle().fill(Theme.border).frame(height: 1), alignment: .top)
            }

            Spacer(minLength: 0)
            if !isCompactChrome {
                gamePanel
            }
            tokenUsagePanel
            if manager.totalTokensUsed > 0 { tokenPanel }
            if isCompactChrome {
                lightweightManagementButtons
            } else {
                managementButtons
            }
        }
        .background(Theme.bgCard)
    }

    @ObservedObject private var tracker = TokenTracker.shared

    private var tokenUsagePanel: some View {
        sidebarPanel(title: "Usage", icon: "chart.bar.fill", tint: Theme.cyan) {
            VStack(spacing: 10) {
                VStack(spacing: 4) {
                    HStack {
                        Text(NSLocalizedString("misc.today", comment: "")).font(Theme.chrome(9, weight: .medium)).foregroundColor(Theme.textSecondary)
                        Spacer()
                        Text(tracker.formatTokens(tracker.todayTokens))
                            .font(Theme.chrome(10, weight: .bold)).foregroundColor(Theme.textPrimary)
                        Text("/").font(Theme.chrome(8)).foregroundColor(Theme.textDim)
                        Text(tracker.formatTokens(tracker.dailyTokenLimit))
                            .font(Theme.chrome(9)).foregroundColor(Theme.textDim)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2).fill(Theme.bg).frame(height: 4)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(dailyBarColor)
                                .frame(width: max(0, geo.size.width * min(1, tracker.dailyUsagePercent)), height: 4)
                        }
                    }.frame(height: 4)
                    HStack {
                        Text(NSLocalizedString("misc.remaining", comment: "")).font(Theme.chrome(7)).foregroundColor(Theme.textDim)
                        Spacer()
                        Text(tracker.formatTokens(tracker.dailyRemaining))
                            .font(Theme.chrome(8, weight: .semibold))
                            .foregroundColor(tracker.dailyUsagePercent > 0.8 ? Theme.red : Theme.green)
                    }
                    if tracker.todayCost > 0 {
                        HStack {
                            Text(NSLocalizedString("misc.cost", comment: "")).font(Theme.chrome(7)).foregroundColor(Theme.textDim)
                            Spacer()
                            Text(String(format: "$%.4f", tracker.todayCost))
                                .font(Theme.chrome(8)).foregroundColor(Theme.yellow)
                        }
                    }
                }

                Divider().overlay(Theme.border.opacity(0.6))

                VStack(spacing: 4) {
                    HStack {
                        Text(NSLocalizedString("misc.thisweek", comment: "")).font(Theme.chrome(9, weight: .medium)).foregroundColor(Theme.textSecondary)
                        Spacer()
                        Text(tracker.formatTokens(tracker.weekTokens))
                            .font(Theme.chrome(10, weight: .bold)).foregroundColor(Theme.textPrimary)
                        Text("/").font(Theme.chrome(8)).foregroundColor(Theme.textDim)
                        Text(tracker.formatTokens(tracker.weeklyTokenLimit))
                            .font(Theme.chrome(9)).foregroundColor(Theme.textDim)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2).fill(Theme.bg).frame(height: 4)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(weeklyBarColor)
                                .frame(width: max(0, geo.size.width * min(1, tracker.weeklyUsagePercent)), height: 4)
                        }
                    }.frame(height: 4)
                    HStack {
                        Text(NSLocalizedString("misc.remaining", comment: "")).font(Theme.chrome(7)).foregroundColor(Theme.textDim)
                        Spacer()
                        Text(tracker.formatTokens(tracker.weeklyRemaining))
                            .font(Theme.chrome(8, weight: .semibold))
                            .foregroundColor(tracker.weeklyUsagePercent > 0.8 ? Theme.red : Theme.green)
                    }
                    if tracker.weekCost > 0 {
                        HStack {
                            Text(NSLocalizedString("misc.cost", comment: "")).font(Theme.chrome(7)).foregroundColor(Theme.textDim)
                            Spacer()
                            Text(String(format: "$%.4f", tracker.weekCost))
                                .font(Theme.chrome(8)).foregroundColor(Theme.yellow)
                        }
                    }
                }

                // 결제 기간
                if AppSettings.shared.billingDay > 0 {
                    Divider().overlay(Theme.border.opacity(0.6))
                    VStack(spacing: 4) {
                        HStack {
                            Text(NSLocalizedString("sidebar.billing.period", comment: "")).font(Theme.chrome(9, weight: .medium)).foregroundColor(Theme.textSecondary)
                            Spacer()
                            Text(tracker.billingPeriodLabel).font(Theme.chrome(8)).foregroundColor(Theme.textDim)
                        }
                        HStack {
                            Text(NSLocalizedString("sidebar.tokens", comment: "")).font(Theme.chrome(7)).foregroundColor(Theme.textDim)
                            Spacer()
                            Text(tracker.formatTokens(tracker.billingPeriodTokens))
                                .font(Theme.chrome(10, weight: .bold)).foregroundColor(Theme.orange)
                        }
                        HStack {
                            Text(NSLocalizedString("misc.cost", comment: "")).font(Theme.chrome(7)).foregroundColor(Theme.textDim)
                            Spacer()
                            Text(String(format: "$%.4f", tracker.billingPeriodCost))
                                .font(Theme.chrome(8)).foregroundColor(Theme.yellow)
                        }
                    }
                }

                if manager.totalTokensUsed > 0 {
                    Divider().overlay(Theme.border.opacity(0.6))
                    HStack {
                        Text(NSLocalizedString("sidebar.current.session", comment: "")).font(Theme.chrome(8, weight: .medium)).foregroundColor(Theme.textDim)
                        Spacer()
                        let (totalIn, totalOut) = manager.userVisibleTabs.reduce((0, 0)) { ($0.0 + $1.inputTokensUsed, $0.1 + $1.outputTokensUsed) }
                        if totalIn > 0 || totalOut > 0 {
                            HStack(spacing: 4) {
                                Text("In").font(Theme.chrome(7)).foregroundColor(Theme.textDim)
                                Text(formatTokens(totalIn)).font(Theme.chrome(8, weight: .semibold)).foregroundColor(Theme.accent)
                                Text("Out").font(Theme.chrome(7)).foregroundColor(Theme.textDim)
                                Text(formatTokens(totalOut)).font(Theme.chrome(8, weight: .semibold)).foregroundColor(Theme.green)
                            }
                        } else {
                            Text(formatTokens(manager.totalTokensUsed)).font(Theme.chrome(8, weight: .semibold)).foregroundColor(Theme.textPrimary)
                        }
                    }
                }
            }
        }
    }

    private var dailyBarColor: Color {
        if tracker.dailyUsagePercent > 0.9 { return Theme.red }
        if tracker.dailyUsagePercent > 0.7 { return Theme.yellow }
        return Theme.green
    }

    private var weeklyBarColor: Color {
        if tracker.weeklyUsagePercent > 0.9 { return Theme.red }
        if tracker.weeklyUsagePercent > 0.7 { return Theme.yellow }
        return Theme.cyan
    }

    private var tokenPanel: some View {
        sidebarPanel(title: "Tokens", icon: "bolt.fill", tint: Theme.yellow) {
            VStack(spacing: 8) {
                HStack {
                    Text(NSLocalizedString("sidebar.total.usage", comment: ""))
                        .font(Theme.chrome(8, weight: .medium))
                        .foregroundColor(Theme.textDim)
                    Spacer()
                    Text(formatTokens(manager.totalTokensUsed))
                        .font(Theme.chrome(12, weight: .semibold)).foregroundColor(Theme.textPrimary)
                }
                ForEach(manager.userVisibleTabs.sorted(by: { $0.tokensUsed > $1.tokensUsed })) { tab in
                    if tab.tokensUsed > 0 {
                        HStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 1).fill(tab.workerColor).frame(width: 3, height: 12)
                            Text(tab.workerName).font(Theme.chrome(9)).foregroundColor(Theme.textSecondary)
                            Spacer()
                            Text(formatTokens(tab.tokensUsed)).font(Theme.chrome(9)).foregroundColor(Theme.textDim)
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 2).fill(Theme.bg)
                                    RoundedRectangle(cornerRadius: 2).fill(tab.workerColor.opacity(0.5))
                                        .frame(width: max(2, geo.size.width * CGFloat(tab.tokensUsed) / CGFloat(max(1, tab.tokenLimit))))
                                }
                            }.frame(width: 36, height: 3)
                        }
                    }
                }
            }
        }
    }

    private var gamePanel: some View {
        sidebarPanel(title: "Level", icon: "sparkles", tint: Theme.yellow) {
            VStack(spacing: 8) {
                XPBarView(xp: AchievementManager.shared.totalXP)
                AchievementsView()
            }
        }
    }

    private var newSessionQuickAction: some View {
        Button(action: { manager.showNewTabSheet = true }) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill").font(Theme.chrome(14))
                    Text(NSLocalizedString("session.new", comment: "")).font(Theme.chrome(11, weight: .semibold))
                    Spacer()
                    Text("Cmd+T").font(Theme.chrome(8, weight: .medium)).foregroundColor(Theme.textDim)
                }
                Text(NSLocalizedString("session.project", comment: ""))
                    .font(Theme.chrome(8))
                    .foregroundColor(Theme.textDim)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .appButtonSurface(tone: .accent)
        }
        .buttonStyle(.plain)
    }

    private var sessionExplorerPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 검색 + 정렬을 한 줄로
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: Theme.chromeIconSize(9), weight: .semibold))
                    .foregroundColor(Theme.textDim)
                TextField(NSLocalizedString("search", comment: ""), text: $searchQuery)
                    .textFieldStyle(.plain)
                    .font(Theme.chrome(10))
                    .foregroundColor(Theme.textPrimary)

                if !searchQuery.isEmpty {
                    Button(action: { searchQuery = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: Theme.chromeIconSize(9)))
                            .foregroundColor(Theme.textDim)
                    }.buttonStyle(.plain)
                }

                Rectangle().fill(Theme.border).frame(width: 1, height: 12)

                Menu {
                    Picker(NSLocalizedString("sidebar.sort.label", comment: ""), selection: sortOptionBinding) {
                        ForEach(SidebarSortOption.allCases) { option in
                            Text(option.label).tag(option)
                        }
                    }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: Theme.chromeIconSize(8), weight: .semibold))
                        Text(sortOption.label)
                            .font(Theme.chrome(8, weight: .bold))
                    }.foregroundColor(Theme.textDim)
                }.menuStyle(.borderlessButton).fixedSize()
            }
            .appFieldStyle()

            // 필터 — 컴팩트 칩, 0개인 것은 비활성 처리
            HStack(spacing: 4) {
                ForEach(SessionStatusFilter.allCases) { filter in
                    let count = countForFilter(filter)
                    Button(action: {
                        withAnimation(sidebarAnimation) { statusFilter = filter }
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: filter.symbol)
                                .font(.system(size: Theme.chromeIconSize(7), weight: .semibold))
                            if statusFilter == filter || count > 0 {
                                Text("\(count)")
                                    .font(Theme.chrome(8, weight: .bold))
                            }
                        }
                        .foregroundColor(statusFilter == filter ? filter.tint : Theme.textDim)
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.cornerMedium).fill(statusFilter == filter ? filter.tint.opacity(0.12) : .clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.cornerMedium).stroke(statusFilter == filter ? filter.tint.opacity(0.3) : Theme.border.opacity(0.2), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .opacity(count > 0 || statusFilter == filter ? 1 : 0.4)
                }
                Spacer()
                Text("\(filteredProjectGroups.reduce(0) { $0 + $1.tabs.count })")
                    .font(Theme.chrome(8, weight: .medium))
                    .foregroundColor(Theme.textDim)
            }
        }
        .appPanelStyle(padding: 10, radius: 12, fill: Theme.bgCard.opacity(0.98), strokeOpacity: 0.2, shadow: false)
    }

    @State private var showCharacterSheet = false
    @State private var showAchievementSheet = false
    @State private var showAccessorySheet = false
    @State private var showReportSheet = false

    private func batchRestart() {
        for id in selectedTabIds {
            if let tab = manager.tabs.first(where: { $0.id == id }) {
                tab.stop()
                tab.start()
            }
        }
        selectedTabIds.removeAll()
        isMultiSelectMode = false
    }

    private func batchStop() {
        for id in selectedTabIds {
            if let tab = manager.tabs.first(where: { $0.id == id }) {
                tab.forceStop()
            }
        }
        selectedTabIds.removeAll()
        isMultiSelectMode = false
    }

    private func batchClose() {
        for id in selectedTabIds {
            manager.removeTab(id)
        }
        selectedTabIds.removeAll()
        isMultiSelectMode = false
    }

    private var managementButtons: some View {
        VStack(spacing: 6) {
            utilityButton(title: NSLocalizedString("sidebar.characters", comment: ""), icon: "person.2.fill", countText: "\(CharacterRegistry.shared.hiredCharacters.count)/\(CharacterRegistry.shared.allCharacters.count)", tone: .accent) { showCharacterSheet = true }
            utilityButton(title: NSLocalizedString("sidebar.accessories", comment: ""), icon: "sofa.fill", countText: "\(breakRoomFurnitureOnCount)/20", tone: .purple) { showAccessorySheet = true }
            utilityButton(title: NSLocalizedString("sidebar.reports", comment: ""), icon: "doc.text.fill", countText: "\(manager.availableReportCount)", tone: .cyan) { showReportSheet = true }
            utilityButton(title: NSLocalizedString("sidebar.achievements", comment: ""), icon: "trophy.fill", countText: "\(AchievementManager.shared.unlockedCount)/\(AchievementManager.shared.achievements.count)", tone: .yellow) { showAchievementSheet = true }
        }
        .padding(.horizontal, 10).padding(.bottom, 6)
        .sheet(isPresented: $showCharacterSheet) {
            CharacterCollectionView()
                .frame(minWidth: 940, idealWidth: 1040, minHeight: 760, idealHeight: 840)
        }
        .sheet(isPresented: $showAccessorySheet) { AccessoryView().frame(minWidth: 480, minHeight: 560) }
        .sheet(isPresented: $showReportSheet) { ReportCenterView().frame(minWidth: 760, minHeight: 620) }
        .sheet(isPresented: $showAchievementSheet) { AchievementCollectionView().frame(minWidth: 880, idealWidth: 960, minHeight: 680, idealHeight: 740) }
    }

    private var lightweightManagementButtons: some View {
        VStack(spacing: 6) {
            lightweightButton(title: NSLocalizedString("sidebar.characters", comment: ""), icon: "person.2.fill") { showCharacterSheet = true }
            lightweightButton(title: NSLocalizedString("sidebar.accessories", comment: ""), icon: "sofa.fill") { showAccessorySheet = true }
            lightweightButton(title: NSLocalizedString("sidebar.reports", comment: ""), icon: "doc.text.fill") { showReportSheet = true }
            lightweightButton(title: NSLocalizedString("sidebar.achievements", comment: ""), icon: "trophy.fill") { showAchievementSheet = true }
        }
        .padding(.horizontal, 10).padding(.bottom, 6)
        .sheet(isPresented: $showCharacterSheet) {
            CharacterCollectionView()
                .frame(minWidth: 940, idealWidth: 1040, minHeight: 760, idealHeight: 840)
        }
        .sheet(isPresented: $showAccessorySheet) { AccessoryView().frame(minWidth: 480, minHeight: 560) }
        .sheet(isPresented: $showReportSheet) { ReportCenterView().frame(minWidth: 760, minHeight: 620) }
        .sheet(isPresented: $showAchievementSheet) { AchievementCollectionView().frame(minWidth: 880, idealWidth: 960, minHeight: 680, idealHeight: 740) }
    }

    private func lightweightButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: Theme.chromeIconSize(12), weight: .semibold))
                    .foregroundColor(Theme.textSecondary)
                Text(title).font(Theme.chrome(11, weight: .medium))
                Spacer()
                Text(NSLocalizedString("action.open", comment: ""))
                    .font(Theme.chrome(8, weight: .bold))
                    .foregroundColor(Theme.textDim)
            }
            .foregroundColor(Theme.textSecondary)
            .padding(.vertical, 9).padding(.horizontal, 12)
            .background(RoundedRectangle(cornerRadius: 8).fill(Theme.bgSurface.opacity(0.5))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border, lineWidth: 1)))
        }
        .buttonStyle(.plain)
    }

    private var breakRoomFurnitureOnCount: Int {
        let s = AppSettings.shared
        return [s.breakRoomShowSofa, s.breakRoomShowCoffeeMachine, s.breakRoomShowPlant, s.breakRoomShowSideTable,
                s.breakRoomShowPicture, s.breakRoomShowNeonSign, s.breakRoomShowRug,
                s.breakRoomShowBookshelf, s.breakRoomShowAquarium, s.breakRoomShowArcade, s.breakRoomShowWhiteboard,
                s.breakRoomShowLamp, s.breakRoomShowCat, s.breakRoomShowTV, s.breakRoomShowFan,
                s.breakRoomShowCalendar, s.breakRoomShowPoster, s.breakRoomShowTrashcan, s.breakRoomShowCushion].filter { $0 }.count
    }

    private func formatTokens(_ count: Int) -> String {
        if count >= 1000 { return String(format: "%.1fk", Double(count) / 1000.0) }
        return "\(count)"
    }

    private var sidebarAnimation: Animation {
        reduceMotion ? .linear(duration: 0.01) : .easeInOut(duration: 0.16)
    }

    private func matchesQuery(_ tab: TerminalTab, loweredQuery: String) -> Bool {
        guard !loweredQuery.isEmpty else { return true }
        return tab.sidebarSearchTokens.contains(loweredQuery)
    }

    private func matchesFilter(_ tab: TerminalTab) -> Bool {
        switch statusFilter {
        case .all:
            return true
        case .active:
            return tab.statusPresentation.category == .active || tab.statusPresentation.category == .processing
        case .processing:
            return tab.statusPresentation.category == .processing
        case .completed:
            return tab.statusPresentation.category == .completed
        case .attention:
            return tab.statusPresentation.category == .attention
        }
    }

    private func countForFilter(_ filter: SessionStatusFilter) -> Int {
        manager.userVisibleTabs.filter { tab in
            switch filter {
            case .all:
                return true
            case .active:
                return tab.statusPresentation.category == .active || tab.statusPresentation.category == .processing
            case .processing:
                return tab.statusPresentation.category == .processing
            case .completed:
                return tab.statusPresentation.category == .completed
            case .attention:
                return tab.statusPresentation.category == .attention
            }
        }.count
    }

    private func tabSortComparator(lhs: TerminalTab, rhs: TerminalTab) -> Bool {
        switch sortOption {
        case .recent:
            if lhs.lastActivityTime != rhs.lastActivityTime { return lhs.lastActivityTime > rhs.lastActivityTime }
        case .name:
            let nameComparison = lhs.projectName.localizedCaseInsensitiveCompare(rhs.projectName)
            if nameComparison != .orderedSame { return nameComparison == .orderedAscending }
        case .tokens:
            if lhs.tokensUsed != rhs.tokensUsed { return lhs.tokensUsed > rhs.tokensUsed }
        case .status:
            if lhs.statusPresentation.sortPriority != rhs.statusPresentation.sortPriority {
                return lhs.statusPresentation.sortPriority < rhs.statusPresentation.sortPriority
            }
        }

        if lhs.projectName != rhs.projectName {
            return lhs.projectName.localizedCaseInsensitiveCompare(rhs.projectName) == .orderedAscending
        }
        return lhs.workerName.localizedCaseInsensitiveCompare(rhs.workerName) == .orderedAscending
    }

    private func compareGroups(_ lhs: SessionManager.ProjectGroup, _ rhs: SessionManager.ProjectGroup) -> Bool {
        switch sortOption {
        case .recent:
            let lhsDate = lhs.tabs.map(\.lastActivityTime).max() ?? .distantPast
            let rhsDate = rhs.tabs.map(\.lastActivityTime).max() ?? .distantPast
            if lhsDate != rhsDate { return lhsDate > rhsDate }
        case .name:
            let comparison = lhs.projectName.localizedCaseInsensitiveCompare(rhs.projectName)
            if comparison != .orderedSame { return comparison == .orderedAscending }
        case .tokens:
            let lhsTokens = lhs.tabs.reduce(0) { $0 + $1.tokensUsed }
            let rhsTokens = rhs.tabs.reduce(0) { $0 + $1.tokensUsed }
            if lhsTokens != rhsTokens { return lhsTokens > rhsTokens }
        case .status:
            let lhsPriority = lhs.tabs.map(\.statusPresentation.sortPriority).min() ?? .max
            let rhsPriority = rhs.tabs.map(\.statusPresentation.sortPriority).min() ?? .max
            if lhsPriority != rhsPriority { return lhsPriority < rhsPriority }
        }

        return lhs.projectName.localizedCaseInsensitiveCompare(rhs.projectName) == .orderedAscending
    }

    private func sidebarPanel<Content: View>(
        title: String,
        icon: String,
        tint: Color,
        storageKey: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        CollapsibleSidebarPanel(title: title, icon: icon, tint: tint, storageKey: storageKey ?? "sidebar.\(title)", content: content)
            .padding(.horizontal, 10)
        .padding(.bottom, 8)
    }

    private func utilityButton(
        title: String,
        icon: String,
        countText: String,
        tone: AppChromeTone,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: Theme.chromeIconSize(12), weight: .semibold))
                    .foregroundColor(tone.color)
                    .frame(width: 18)
                Text(title).font(Theme.chrome(11, weight: .medium))
                Spacer()
                Text(countText)
                    .font(Theme.chrome(9, weight: .bold))
                    .foregroundColor(tone.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(RoundedRectangle(cornerRadius: Theme.cornerSmall).fill(tone.color.opacity(0.10)))
            }
            .foregroundColor(Theme.textSecondary)
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: Theme.cornerLarge)
                    .fill(Theme.bgSurface.opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerLarge)
                    .stroke(Theme.border.opacity(0.22), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct ReportCenterView: View {
    @EnvironmentObject var manager: SessionManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedReportPath: String?
    @State private var reportText: String = ""
    @State private var reportToDelete: SessionManager.ReportReference?
    @State private var showDeleteConfirm = false
    @State private var hoveredReportId: String?

    private var reports: [SessionManager.ReportReference] { manager.availableReports() }
    private var selectedReport: SessionManager.ReportReference? {
        guard let p = selectedReportPath else { return nil }
        return reports.first { $0.path == p }
    }

    var body: some View {
        VStack(spacing: 0) {
            DSModalHeader(
                icon: "doc.richtext.fill",
                iconColor: Theme.cyan,
                title: NSLocalizedString("sidebar.reports", comment: ""),
                subtitle: NSLocalizedString("sidebar.report.subtitle", comment: ""),
                trailing: AnyView(
                    Text("\(reports.count)")
                        .font(Theme.mono(10, weight: .bold))
                        .foregroundColor(Theme.cyan)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: Theme.cornerSmall).fill(Theme.accentBg(Theme.cyan)))
                        .overlay(RoundedRectangle(cornerRadius: Theme.cornerSmall).stroke(Theme.accentBorder(Theme.cyan), lineWidth: 1))
                ),
                onClose: { dismiss() }
            )

            // ── Content ──
            HStack(spacing: 0) {
                // Left: report list
                reportListPanel
                    .frame(width: 280)

                Rectangle().fill(Theme.border).frame(width: 1)

                // Right: preview
                reportPreviewPanel
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Theme.bg)
        .onAppear {
            if selectedReportPath == nil, let first = reports.first { loadReport(first.path) }
        }
        .onChange(of: reports.map(\.path)) { _, paths in
            if let sp = selectedReportPath, paths.contains(sp) { loadReport(sp) }
            else if let first = reports.first { loadReport(first.path) }
            else { selectedReportPath = nil; reportText = "" }
        }
        .alert(NSLocalizedString("report.delete", comment: ""), isPresented: $showDeleteConfirm) {
            Button(NSLocalizedString("delete", comment: ""), role: .destructive) {
                if let r = reportToDelete { deleteReport(r); reportToDelete = nil }
            }
            Button(NSLocalizedString("cancel", comment: ""), role: .cancel) { reportToDelete = nil }
        } message: {
            if let r = reportToDelete {
                Text(String(format: NSLocalizedString("sidebar.report.delete.confirm", comment: ""), r.projectName))
            }
        }
    }

    // ── Left Panel ──

    private var reportListPanel: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "list.bullet").font(.system(size: 9, weight: .medium)).foregroundColor(Theme.textDim)
                Text(NSLocalizedString("sidebar.report.list", comment: "")).font(Theme.mono(9, weight: .bold)).foregroundColor(Theme.textDim)
                Spacer()
            }
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(Theme.bgSurface.opacity(0.3))

            Rectangle().fill(Theme.border.opacity(0.5)).frame(height: 1)

            ScrollView {
                LazyVStack(spacing: 4) {
                    if reports.isEmpty {
                        emptyReportList
                    } else {
                        ForEach(reports) { report in reportRow(report) }
                    }
                }
                .padding(8)
            }
        }
        .background(Theme.bgCard)
    }

    private var emptyReportList: some View {
        VStack(spacing: 10) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 28))
                .foregroundColor(Theme.textDim.opacity(0.2))
            Text(NSLocalizedString("sidebar.report.none", comment: ""))
                .font(Theme.mono(10, weight: .bold))
                .foregroundColor(Theme.textDim.opacity(0.5))
            Text(NSLocalizedString("sidebar.report.none.hint", comment: ""))
                .font(Theme.mono(8))
                .foregroundColor(Theme.textDim.opacity(0.35))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private func reportRow(_ report: SessionManager.ReportReference) -> some View {
        let isSelected = selectedReportPath == report.path
        let isHovered = hoveredReportId == report.id
        let fileName = (report.path as NSString).lastPathComponent

        return Button(action: { withAnimation(.easeInOut(duration: 0.1)) { loadReport(report.path) } }) {
            HStack(spacing: 10) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected ? Theme.cyan.opacity(0.15) : Theme.bgSurface)
                        .frame(width: 32, height: 32)
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 12))
                        .foregroundColor(isSelected ? Theme.cyan : Theme.textDim.opacity(0.5))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(report.projectName)
                        .font(Theme.mono(10, weight: .bold))
                        .foregroundColor(isSelected ? Theme.textPrimary : Theme.textSecondary)
                        .lineLimit(1)
                    Text(fileName)
                        .font(Theme.mono(7))
                        .foregroundColor(Theme.textDim)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(reportDateShort(report.updatedAt))
                        .font(Theme.mono(7, weight: .medium))
                        .foregroundColor(isSelected ? Theme.cyan : Theme.textDim)
                    Text(reportTimeShort(report.updatedAt))
                        .font(Theme.mono(7))
                        .foregroundColor(Theme.textDim.opacity(0.6))
                }

                // Delete button (only on hover)
                if isHovered || isSelected {
                    Button(action: { reportToDelete = report; showDeleteConfirm = true }) {
                        Image(systemName: "trash")
                            .font(.system(size: 9))
                            .foregroundColor(Theme.red.opacity(0.5))
                            .frame(width: 20, height: 20)
                    }
                    .buttonStyle(.plain)
                    .help(NSLocalizedString("report.delete", comment: ""))
                    .transition(.opacity)
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Theme.cyan.opacity(0.08) : (isHovered ? Theme.bgSurface.opacity(0.6) : .clear))
            )
            .overlay(alignment: .leading) {
                if isSelected {
                    RoundedRectangle(cornerRadius: 2).fill(Theme.cyan).frame(width: 3).padding(.vertical, 4)
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { h in withAnimation(.easeInOut(duration: 0.1)) { hoveredReportId = h ? report.id : nil } }
        .contextMenu {
            Button { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: report.path)]) }
                label: { Label(NSLocalizedString("action.finder", comment: ""), systemImage: "folder") }
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(report.path, forType: .string)
            } label: { Label(NSLocalizedString("action.copy.path", comment: ""), systemImage: "doc.on.doc") }
            Divider()
            Button(role: .destructive) { reportToDelete = report; showDeleteConfirm = true }
                label: { Label(NSLocalizedString("delete", comment: ""), systemImage: "trash") }
        }
    }

    // ── Right Panel (Preview) ──

    private var reportPreviewPanel: some View {
        VStack(spacing: 0) {
            // Preview header
            HStack(spacing: 8) {
                if let r = selectedReport {
                    Image(systemName: "doc.text.fill").font(.system(size: 10)).foregroundColor(Theme.cyan)
                    Text(r.projectName).font(Theme.mono(10, weight: .bold)).foregroundColor(Theme.textPrimary).lineLimit(1)
                    Text("·").foregroundColor(Theme.textDim)
                    Text((r.path as NSString).lastPathComponent).font(Theme.mono(8)).foregroundColor(Theme.textDim).lineLimit(1)
                } else {
                    Text(NSLocalizedString("sidebar.report.preview", comment: "")).font(Theme.mono(10, weight: .bold)).foregroundColor(Theme.textDim)
                }
                Spacer()
                if let p = selectedReportPath {
                    Button(action: { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: p)]) }) {
                        HStack(spacing: 3) {
                            Image(systemName: "folder").font(.system(size: 8))
                            Text("Finder").font(Theme.mono(8, weight: .bold))
                        }.foregroundColor(Theme.cyan)
                    }.buttonStyle(.plain)

                    Button(action: {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(reportText, forType: .string)
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "doc.on.doc").font(.system(size: 8))
                            Text(NSLocalizedString("sidebar.report.copy", comment: "")).font(Theme.mono(8, weight: .bold))
                        }.foregroundColor(Theme.textSecondary)
                    }.buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(Theme.bgCard)

            Rectangle().fill(Theme.border.opacity(0.5)).frame(height: 1)

            // Content
            if reportText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                emptyPreview
            } else {
                ScrollView {
                    MarkdownTextView(text: reportText, compact: false)
                        .padding(20)
                }
            }
        }
        .background(Theme.bg)
    }

    private var emptyPreview: some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.left.circle")
                .font(.system(size: 28))
                .foregroundColor(Theme.textDim.opacity(0.15))
            Text(NSLocalizedString("sidebar.report.select", comment: ""))
                .font(Theme.mono(11, weight: .medium))
                .foregroundColor(Theme.textDim.opacity(0.4))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // ── Helpers ──

    private func loadReport(_ path: String) {
        selectedReportPath = path
        reportText = (try? String(contentsOfFile: path, encoding: .utf8)) ?? NSLocalizedString("sidebar.report.load.fail", comment: "")
    }

    private func deleteReport(_ report: SessionManager.ReportReference) {
        try? FileManager.default.removeItem(atPath: report.path)
        if selectedReportPath == report.path { selectedReportPath = nil; reportText = "" }
        manager.invalidateReportCache()
    }

    private func reportDateShort(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "M/d"; return f.string(from: date)
    }
    private func reportTimeShort(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; return f.string(from: date)
    }
}

// MARK: - Session Group Card

struct SessionGroupCard: View {
    let group: SessionManager.ProjectGroup
    @EnvironmentObject var manager: SessionManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var settings = AppSettings.shared
    @State private var isExpanded = false
    private var isGroupActive: Bool { group.hasActiveTab }

    private var isGroupSelected: Bool { manager.selectedGroupPath == group.id }
    private var groupAnimation: Animation {
        reduceMotion ? .linear(duration: 0.01) : .easeInOut(duration: 0.15)
    }

    private var groupStatus: TabStatusPresentation {
        if group.tabs.contains(where: { $0.statusPresentation.category == .attention }) {
            return TabStatusPresentation(category: .attention, label: NSLocalizedString("status.attention", comment: ""), symbol: "exclamationmark.triangle.fill", tint: Theme.red, sortPriority: 0)
        }
        if group.tabs.allSatisfy(\.isCompleted) {
            return TabStatusPresentation(category: .completed, label: NSLocalizedString("status.completed", comment: ""), symbol: "checkmark.circle.fill", tint: Theme.green, sortPriority: 3)
        }
        if group.tabs.contains(where: { $0.statusPresentation.category == .processing }) {
            return TabStatusPresentation(category: .processing, label: NSLocalizedString("status.processing", comment: ""), symbol: "gearshape.2.fill", tint: Theme.accent, sortPriority: 1)
        }
        if group.tabs.contains(where: { $0.statusPresentation.category == .active }) {
            return TabStatusPresentation(category: .active, label: NSLocalizedString("status.active", comment: ""), symbol: "bolt.circle.fill", tint: Theme.green.opacity(0.85), sortPriority: 2)
        }
        return TabStatusPresentation(category: .idle, label: NSLocalizedString("status.idle", comment: ""), symbol: "moon.zzz.fill", tint: Theme.textDim, sortPriority: 4)
    }

    var body: some View {
        VStack(spacing: 0) {
            // 그룹 헤더: 클릭 → 오른쪽 패널에 이 그룹만 표시 + 펼침
            Button(action: {
                withAnimation(groupAnimation) {
                    // 이미 선택된 그룹이면 펼침 토글, 아니면 선택 + 펼침
                    if isGroupSelected && !manager.focusSingleTab {
                        isExpanded.toggle()
                    } else {
                        manager.selectedGroupPath = group.id
                        manager.focusSingleTab = false  // 그룹 전체 보기
                        isExpanded = true
                        if let first = group.tabs.first { manager.selectTab(first.id) }
                    }
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(Theme.chrome(7, weight: .bold)).foregroundColor(Theme.textDim).frame(width: 10)
                    Circle().fill(groupStatus.tint).frame(width: 7, height: 7)
                    Text(group.projectName).font(Theme.chrome(11, weight: isGroupSelected ? .bold : .semibold))
                        .foregroundColor(isGroupSelected ? Theme.textPrimary : Theme.textSecondary).lineLimit(1)
                    Spacer()
                    AppStatusBadge(
                        title: groupStatus.label,
                        symbol: groupStatus.symbol,
                        tint: groupStatus.tint
                    )
                    Text("\(group.tabs.count)").font(Theme.chrome(9, weight: .bold)).foregroundColor(Theme.accent)
                        .padding(.horizontal, 5).padding(.vertical, 1).background(Theme.accent.opacity(0.1)).cornerRadius(3)
                }
                .padding(.horizontal, 10).padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 8)
                    .fill(isGroupSelected ? Theme.bgSelected : Theme.bgSurface.opacity(0.5))
                    .overlay(RoundedRectangle(cornerRadius: 8)
                        .stroke(isGroupSelected ? Theme.accent.opacity(0.4) : .clear, lineWidth: isGroupSelected ? 1.5 : 0)))
            }.buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 2) { ForEach(group.tabs) { tab in WorkerMiniCard(tab: tab) } }
                    .padding(.leading, 16).padding(.trailing, 4).padding(.vertical, 4)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(group.projectName) 그룹")
        .accessibilityValue("\(group.tabs.count)개 세션, \(groupStatus.label)")
        .contextMenu {
            Button {
                NSWorkspace.shared.open(URL(fileURLWithPath: group.tabs.first?.projectPath ?? ""))
            } label: { Label(NSLocalizedString("action.finder", comment: ""), systemImage: "folder") }

            Button {
                if let p = group.tabs.first?.projectPath {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(p, forType: .string)
                }
            } label: { Label(NSLocalizedString("action.copy.path", comment: ""), systemImage: "doc.on.doc") }

            Divider()

            Button {
                if let p = group.tabs.first?.projectPath {
                    let url = URL(fileURLWithPath: p)
                    NSWorkspace.shared.open(url, configuration: .init(), completionHandler: nil)
                    // Terminal에서 열기
                    let script = "tell application \"Terminal\" to do script \"cd \\\"\(p)\\\"\""
                    if let appleScript = NSAppleScript(source: script) { appleScript.executeAndReturnError(nil) }
                }
            } label: { Label(NSLocalizedString("sidebar.open.terminal", comment: ""), systemImage: "terminal") }
        }
    }
}

struct WorkerMiniCard: View {
    @ObservedObject var tab: TerminalTab
    @EnvironmentObject var manager: SessionManager
    private var isSelected: Bool { manager.activeTabId == tab.id }
    var body: some View {
        Button(action: { manager.focusSingleTab = true; manager.selectTab(tab.id) }) {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 1).fill(tab.workerColor).frame(width: 3, height: 14)
                Text(tab.workerName).font(Theme.chrome(10, weight: .medium)).foregroundColor(tab.workerColor)
                AppStatusBadge(
                    title: tab.statusPresentation.label,
                    symbol: tab.statusPresentation.symbol,
                    tint: tab.statusPresentation.tint
                )
                Spacer()
                if tab.tokensUsed > 0 { Text(tab.tokensUsed >= 1000 ? String(format: "%.1fk", Double(tab.tokensUsed)/1000) : "\(tab.tokensUsed)")
                    .font(Theme.chrome(9)).foregroundColor(Theme.textDim) }
                if isSelected { Button(action: { manager.removeTab(tab.id) }) {
                    Image(systemName: "xmark").font(Theme.chrome(7, weight: .bold)).foregroundColor(Theme.textDim).padding(2) }.buttonStyle(.plain) }
            }
            .padding(.horizontal, Theme.sp2).padding(.vertical, Theme.sp1 + 1)
            .background(RoundedRectangle(cornerRadius: Theme.cornerMedium).fill(isSelected ? Theme.bgSelected : .clear))
            .overlay(RoundedRectangle(cornerRadius: Theme.cornerMedium).stroke(isSelected ? Theme.border : .clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(tab.projectName) \(tab.workerName)")
        .accessibilityValue(tab.statusPresentation.label)
        .accessibilityHint(NSLocalizedString("sidebar.a11y.open.single", comment: ""))
        .contextMenu {
            Button { NSWorkspace.shared.open(URL(fileURLWithPath: tab.projectPath)) }
                label: { Label(NSLocalizedString("action.finder", comment: ""), systemImage: "folder") }
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(tab.projectPath, forType: .string)
            } label: { Label(NSLocalizedString("action.copy.path", comment: ""), systemImage: "doc.on.doc") }
            Divider()
            Button(role: .destructive) { manager.removeTab(tab.id) }
                label: { Label(NSLocalizedString("action.close.session", comment: ""), systemImage: "xmark") }
        }
    }
}

// MARK: - Session Card

struct SessionCard: View {
    @ObservedObject var tab: TerminalTab
    @EnvironmentObject var manager: SessionManager
    @ObservedObject private var settings = AppSettings.shared
    @State private var isEditingName = false
    @State private var editName = ""

    private var isSelected: Bool { manager.activeTabId == tab.id }

    var body: some View {
        Button(action: { manager.selectedGroupPath = nil; manager.focusSingleTab = true; manager.selectTab(tab.id) }) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Circle().fill(tab.statusPresentation.tint).frame(width: 7, height: 7)
                    Text(tab.projectName)
                        .font(Theme.chrome(11, weight: isSelected ? .semibold : .regular))
                        .foregroundColor(isSelected ? Theme.textPrimary : Theme.textSecondary).lineLimit(1)
                    Spacer()
                    if let idx = manager.userVisibleTabs.firstIndex(where: { $0.id == tab.id }), idx < 9 {
                        Text("Cmd+\(idx + 1)").font(Theme.chrome(7, weight: .medium))
                            .foregroundColor(Theme.textDim).opacity(isSelected ? 0.7 : 0.3)
                    }
                    if isSelected {
                        Button(action: { manager.removeTab(tab.id) }) {
                            Image(systemName: "xmark").font(Theme.chrome(7, weight: .bold))
                                .foregroundColor(Theme.textDim).padding(2)
                        }.buttonStyle(.plain)
                    }
                }

                HStack(alignment: .center, spacing: 6) {
                    HStack(spacing: 3) {
                        RoundedRectangle(cornerRadius: 1).fill(tab.workerColor).frame(width: 3, height: 10)
                        if isEditingName {
                            TextField(NSLocalizedString("sidebar.field.name", comment: ""), text: $editName).textFieldStyle(.plain)
                                .font(Theme.chrome(10, weight: .bold)).foregroundColor(tab.workerColor).frame(width: 60)
                                .onSubmit {
                                    if !editName.trimmingCharacters(in: .whitespaces).isEmpty {
                                        tab.workerName = editName.trimmingCharacters(in: .whitespaces)
                                    }
                                    isEditingName = false
                                }
                        } else {
                            Text(tab.workerName).font(Theme.chrome(10)).foregroundColor(tab.workerColor)
                                .onTapGesture(count: 2) { editName = tab.workerName; isEditingName = true }
                        }
                    }
                    AppStatusBadge(
                        title: tab.statusPresentation.label,
                        symbol: tab.statusPresentation.symbol,
                        tint: tab.statusPresentation.tint
                    )
                    if tab.sessionCount > 1 {
                        Text("x\(tab.sessionCount)").font(Theme.chrome(9, weight: .bold)).foregroundColor(Theme.cyan)
                    }
                    Spacer()
                    if tab.tokensUsed > 0 {
                        Text(formatTokens(tab.tokensUsed)).font(Theme.chrome(9)).foregroundColor(Theme.textDim)
                    }
                }

                if tab.gitInfo.isGitRepo {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.branch").font(Theme.chrome(8)).foregroundColor(Theme.cyan.opacity(0.6))
                        Text(tab.gitInfo.branch).font(Theme.chrome(9)).foregroundColor(Theme.cyan.opacity(0.7)).lineLimit(1)
                        if tab.gitInfo.changedFiles > 0 {
                            Text("+\(tab.gitInfo.changedFiles)").font(Theme.chrome(8, weight: .bold)).foregroundColor(Theme.yellow.opacity(0.8))
                        }
                    }
                }

                if let startError = tab.startError, !startError.isEmpty {
                    Text(startError)
                        .font(Theme.chrome(8))
                        .foregroundColor(Theme.red)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, Theme.sp3).padding(.vertical, Theme.sp2)
            .background(
                RoundedRectangle(cornerRadius: Theme.cornerLarge)
                    .fill(isSelected ? Theme.bgSelected : .clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerLarge)
                    .stroke(isSelected ? Theme.border : .clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(tab.projectName) 세션")
        .accessibilityValue("\(tab.workerName), \(tab.statusPresentation.label)")
        .accessibilityHint(NSLocalizedString("sidebar.a11y.select.session", comment: ""))
        .contextMenu {
            Button { NSWorkspace.shared.open(URL(fileURLWithPath: tab.projectPath)) }
                label: { Label(NSLocalizedString("action.finder", comment: ""), systemImage: "folder") }
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(tab.projectPath, forType: .string)
            } label: { Label(NSLocalizedString("action.copy.path", comment: ""), systemImage: "doc.on.doc") }
            if tab.gitInfo.isGitRepo {
                Divider()
                Button {
                    let gitDir = (tab.projectPath as NSString).appendingPathComponent(".git")
                    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: gitDir)])
                } label: { Label("Git 폴더 보기", systemImage: "arrow.triangle.branch") }
            }
            Divider()
            Button(role: .destructive) { manager.removeTab(tab.id) }
                label: { Label(NSLocalizedString("action.close.session", comment: ""), systemImage: "xmark") }
        }
    }

    private func formatTokens(_ count: Int) -> String {
        if count >= 1000 { return String(format: "%.1fk", Double(count) / 1000.0) }
        return "\(count)"
    }

}

// MARK: - Drag & Drop

struct TabDropDelegate: DropDelegate {
    let tabId: String
    let manager: SessionManager
    @Binding var draggingTabId: String?

    func performDrop(info: DropInfo) -> Bool { draggingTabId = nil; return true }
    func dropEntered(info: DropInfo) {
        guard let dragging = draggingTabId, dragging != tabId,
              let fromIndex = manager.tabs.firstIndex(where: { $0.id == dragging }),
              let toIndex = manager.tabs.firstIndex(where: { $0.id == tabId }) else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            manager.tabs.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
        }
    }
    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }
}

// MARK: - Session History

struct SessionHistoryView: View {
    @State private var history: [SavedSession] = []
    @State private var lastSaved: Date?
    @EnvironmentObject var manager: SessionManager

    var body: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Theme.border).frame(height: 1)
            VStack(spacing: 6) {
                HStack {
                    HStack(spacing: 4) {
                        Text("HISTORY").font(Theme.pixel).foregroundColor(Theme.textDim).tracking(2)
                    }
                    Spacer()
                    if let saved = lastSaved {
                        Text(timeAgo(saved)).font(Theme.chrome(9)).foregroundColor(Theme.textDim)
                    }
                }
                if history.isEmpty {
                    AppEmptyStateView(
                        title: NSLocalizedString("sidebar.history.empty.title", comment: ""),
                        message: NSLocalizedString("sidebar.history.empty.message", comment: ""),
                        symbol: "clock.arrow.circlepath",
                        tint: Theme.textDim
                    )
                } else {
                    ForEach(history.prefix(5), id: \.projectPath) { session in
                        HStack(spacing: 6) {
                            Circle().fill(session.isCompleted ? Theme.green : Theme.textDim).frame(width: 5, height: 5)
                            Text(session.projectName).font(Theme.chrome(10)).foregroundColor(Theme.textSecondary).lineLimit(1)
                            Spacer()
                            if session.tokensUsed > 0 {
                                Text(formatTokens(session.tokensUsed)).font(Theme.chrome(9)).foregroundColor(Theme.textDim)
                            }
                            if !manager.userVisibleTabs.contains(where: { $0.projectPath == session.projectPath }) {
                                Button(action: {
                                    if manager.manualLaunchCapacity > 0 {
                                        manager.addTab(projectName: session.projectName, projectPath: session.projectPath, branch: session.branch, manualLaunch: true)
                                    } else {
                                        manager.notifyManualLaunchCapacity()
                                    }
                                }) {
                                    Image(systemName: "arrow.counterclockwise").font(Theme.chrome(9)).foregroundColor(Theme.accent)
                                }.buttonStyle(.plain).help(NSLocalizedString("sidebar.help.session.restart", comment: ""))
                            }
                        }
                    }
                }
            }.padding(.horizontal, 14).padding(.vertical, 8)
            Rectangle().fill(Theme.border).frame(height: 1)
        }
        .onAppear(perform: reloadHistory)
        .onReceive(NotificationCenter.default.publisher(for: .workmanSessionStoreDidChange)) { _ in
            reloadHistory()
        }
    }

    private func formatTokens(_ count: Int) -> String {
        if count >= 1000 { return String(format: "%.1fk", Double(count) / 1000.0) }
        return "\(count)"
    }
    private func timeAgo(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return NSLocalizedString("sidebar.time.just.now", comment: "") }
        if interval < 3600 { return String(format: NSLocalizedString("sidebar.time.minutes.ago", comment: ""), Int(interval / 60)) }
        if interval < 86400 { return String(format: NSLocalizedString("sidebar.time.hours.ago", comment: ""), Int(interval / 3600)) }
        return String(format: NSLocalizedString("sidebar.time.days.ago", comment: ""), Int(interval / 86400))
    }

    private func reloadHistory() {
        history = SessionStore.shared.load()
        lastSaved = SessionStore.shared.loadLastSaved()
    }
}
