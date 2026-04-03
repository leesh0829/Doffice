import SwiftUI
import DesignSystem
import DofficeKit

struct MainView: View {
    @EnvironmentObject var manager: SessionManager
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @StateObject var settings = AppSettings.shared
    @StateObject var achievementManager = AchievementManager.shared
    @State var sidebarWidth: CGFloat = 216
    @State var showSettings = false
    @State var showClaudeNotInstalledAlert = false
    @State var showRoleNoticeAlert = false
    @State var roleNoticeTitle = ""
    @State var roleNoticeMessage = ""
    @State var showBugReport = false
    @State var showUpdateSheet = false
    @State var showActionCenter = false
    @State var showCommandPalette = false
    @State var showDailyReward = false
    @State var dailyRewardData: AchievementManager.DailyRewardResult?
    @State var showBillingAlert = false
    @State var billingAlertMessage = ""
    @StateObject var updater = UpdateChecker.shared
    @StateObject var pluginHost = PluginHost.shared
    @StateObject var effectEngine = PluginEffectEngine.shared
    @State var activePluginPanelId: String?
    @StateObject var sessionNotifications = SessionNotificationManager.shared
    @Environment(\.openWindow) var openWindow
    @AppStorage("officeExpanded") var officeExpanded = true
    @AppStorage("viewMode") var viewModeRaw: Int = 1
    @AppStorage("sidebarCollapsed") var sidebarCollapsed = false

    enum ViewMode: Int { case split = 0, office = 1, terminal = 2, strip = 3 }
    var viewMode: ViewMode { ViewMode(rawValue: viewModeRaw) ?? .split }
    var officeHeight: CGFloat { officeExpanded ? 380 : 240 }
    let minimumSidebarWidth: CGFloat = 196
    let preferredSidebarWidth: CGFloat = 216
    let minimumPrimaryContentWidth: CGFloat = 880

    var chromeAnimation: Animation {
        reduceMotion ? .linear(duration: 0.01) : .easeInOut(duration: 0.2)
    }

    @ViewBuilder
    private var mainLayout: some View {
        VStack(spacing: 0) {
            titleBar

            GeometryReader { geometry in
                let effectiveSidebarWidth = protectedSidebarWidth(totalWidth: geometry.size.width)
                let forceCompactSidebar = shouldForceCompactSidebar(
                    totalWidth: geometry.size.width,
                    sidebarWidth: effectiveSidebarWidth
                )

                HStack(spacing: 0) {
                    if !sidebarCollapsed {
                        SidebarView(forceCompact: forceCompactSidebar)
                            .frame(width: effectiveSidebarWidth)
                            .clipped()
                            .transition(.move(edge: .leading))

                        Rectangle().fill(Theme.border).frame(width: 1)
                    }

                    ZStack {
                        if let panelId = activePluginPanelId,
                           let panel = pluginHost.panels.first(where: { $0.id == panelId }) {
                            // 플러그인 패널 표시
                            VStack(spacing: 0) {
                                pluginPanelHeader(panel)
                                PluginPanelView(htmlURL: panel.htmlURL, pluginName: panel.pluginName)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                        } else {
                            switch viewMode {
                            case .split:
                                splitView
                            case .office:
                                officeFullView
                            case .terminal:
                                TerminalAreaView()
                            case .strip:
                                stripView
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            statusBar
        }
        .background(Theme.bg)
        .compositingGroup()
        .ignoresSafeArea(.all, edges: .top)
        .background(WindowConfigurator())
    }

    private var bodyWithOverlays: some View {
        mainLayout
        .offset(effectEngine.shakeOffset)
        .overlay { PluginEffectOverlay().zIndex(9) }
        .overlay(alignment: .topTrailing) {
            VStack(alignment: .trailing, spacing: 8) {
                if let ach = achievementManager.recentUnlock {
                    AchievementToastView(achievement: ach) {
                        achievementManager.dismissRecentUnlock()
                    }
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .scale(scale: 0.96).combined(with: .opacity)
                        )
                    )
                    .animation(.easeOut(duration: 0.2), value: ach.id)
                }
                // 세션 알림 배너
                SessionNotificationBannerStack { tabId in
                    manager.selectTab(tabId)
                }
            }
            .padding(.top, 44)
            .padding(.trailing, 18)
            .zIndex(10)
        }
        .overlay {
            ZStack {
                if settings.isLocked {
                    SessionLockOverlay()
                }
                if showCommandPalette {
                    CommandPaletteView(
                        isPresented: $showCommandPalette,
                        onNewSession: { manager.showNewTabSheet = true },
                        onSettings: { showSettings = true },
                        onBugReport: { showBugReport = true },
                        onExportLog: { exportActiveLog() },
                        onSetViewMode: { viewModeRaw = $0 }
                    )
                    .transition(.opacity)
                    .animation(.easeOut(duration: 0.15), value: showCommandPalette)
                    .zIndex(20)
                }
            }
        }
        .overlay(alignment: .bottom) {
            if settings.pendingRefresh {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.clockwise.circle.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.accentBackground)
                    Text(NSLocalizedString("main.settings.changed", comment: ""))
                        .font(Theme.mono(11, weight: .medium))
                        .foregroundColor(Theme.textPrimary)
                    Spacer()
                    Button(NSLocalizedString("main.refresh", comment: "")) {
                        settings.pendingRefresh = false
                        manager.refresh()
                    }
                    .font(Theme.mono(10, weight: .bold))
                    .foregroundColor(Theme.textOnAccent)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Theme.accentBackground))
                    .buttonStyle(.plain)
                    Button(action: { settings.pendingRefresh = false }) {
                        Image(systemName: "xmark").font(.system(size: 10, weight: .bold))
                            .foregroundColor(Theme.textDim)
                    }.buttonStyle(.plain)
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Theme.bgCard)
                )
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border.opacity(0.3), lineWidth: 1))
                .padding(.horizontal, 20).padding(.bottom, 40)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.spring(response: 0.3), value: settings.pendingRefresh)
                .zIndex(15)
            }
        }
    }

    private var bodyWithSheets: some View {
        bodyWithOverlays
        .sheet(isPresented: Binding(
            get: { !settings.hasCompletedOnboarding },
            set: { if !$0 { settings.hasCompletedOnboarding = true } }
        )) { OnboardingView().dofficeSheetPresentation() }
        .sheet(isPresented: $showSettings) { SettingsView().dofficeSheetPresentation() }
        .sheet(isPresented: $showBugReport) { BugReportView().dofficeSheetPresentation() }
        .sheet(isPresented: $showUpdateSheet) { UpdateSheet().dofficeSheetPresentation() }
        .sheet(isPresented: $manager.showNewTabSheet) { NewTabSheet().dofficeSheetPresentation() }
        .sheet(isPresented: $showActionCenter) {
            ActionCenterView()
                .frame(minWidth: 500, minHeight: 400)
                .dofficeSheetPresentation()
        }
    }

    private var bodyWithAlerts: some View {
        bodyWithSheets
        .alert(NSLocalizedString("claude.not.installed", comment: ""), isPresented: $showClaudeNotInstalledAlert) {
            Button(NSLocalizedString("main.install.guide", comment: "")) {
                if let url = URL(string: "https://docs.anthropic.com/en/docs/claude-code/overview") {
                    NSWorkspace.shared.open(url)
                }
            }
            Button(NSLocalizedString("retry", comment: "")) {
                DispatchQueue.global(qos: .userInitiated).async {
                    ClaudeInstallChecker.shared.check()
                    CodexInstallChecker.shared.check()
                    DispatchQueue.main.async {
                        if !ClaudeInstallChecker.shared.isInstalled && !CodexInstallChecker.shared.isInstalled {
                            showClaudeNotInstalledAlert = true
                        }
                    }
                }
            }
            Button(NSLocalizedString("confirm", comment: ""), role: .cancel) {}
        } message: {
            Text(NSLocalizedString("claude.install.message", comment: ""))
        }
        .alert(roleNoticeTitle, isPresented: $showRoleNoticeAlert) {
            Button(NSLocalizedString("confirm", comment: ""), role: .cancel) {}
        } message: {
            Text(roleNoticeMessage)
        }
        .overlay {
            if showDailyReward, let reward = dailyRewardData {
                DailyRewardOverlay(reward: reward) {
                    withAnimation(.easeOut(duration: 0.25)) { showDailyReward = false }
                }
                .transition(.scale(scale: 0.8).combined(with: .opacity))
                .zIndex(100)
            }
        }
        .overlay {
            if showBillingAlert {
                BillingAlertOverlay(message: billingAlertMessage) {
                    withAnimation(.easeOut(duration: 0.25)) { showBillingAlert = false }
                }
                .transition(.scale(scale: 0.8).combined(with: .opacity))
                .zIndex(101)
            }
        }
    }

    var body: some View {
        bodyWithLifecycle
            .withNotificationHandlers(manager: manager, chromeAnimation: chromeAnimation,
                                       viewModeRaw: $viewModeRaw,
                                       showClaudeNotInstalledAlert: $showClaudeNotInstalledAlert,
                                       showRoleNoticeAlert: $showRoleNoticeAlert,
                                       roleNoticeTitle: $roleNoticeTitle,
                                       roleNoticeMessage: $roleNoticeMessage,
                                       showCommandPalette: $showCommandPalette,
                                       showActionCenter: $showActionCenter,
                                       exportActiveLog: exportActiveLog)
    }

    private var bodyWithLifecycle: some View {
        bodyWithAlerts
        .onChange(of: manager.showNewTabSheet) { _, isPresented in
            guard isPresented else { return }
            showSettings = false
            showBugReport = false
            showUpdateSheet = false
            showActionCenter = false
        }
        .onChange(of: showSettings) { _, isPresented in
            guard isPresented, manager.showNewTabSheet else { return }
            showSettings = false
        }
        .onChange(of: showBugReport) { _, isPresented in
            guard isPresented, manager.showNewTabSheet else { return }
            showBugReport = false
        }
        .onChange(of: showUpdateSheet) { _, isPresented in
            guard isPresented, manager.showNewTabSheet else { return }
            showUpdateSheet = false
        }
        .onChange(of: showActionCenter) { _, isPresented in
            guard isPresented, manager.showNewTabSheet else { return }
            showActionCenter = false
        }
        .onAppear {
            if SmokeTestHarness.isEnabled {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    SmokeTestHarness.completeMainViewSmoke(manager: manager, settings: settings)
                }
                return
            }
            settings.ensureCoffeeSupportPreset()
            if manager.userVisibleTabs.isEmpty {
                // Let the first frame render before session restoration work kicks in.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    manager.restoreSessions()
                }
                // Runtime session scanning can still start automatically, but keep it
                // behind restoration so launch feels responsive even with shell probes.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                    manager.autoDetectAndConnect()
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                ClaudeInstallChecker.shared.check()
                CodexInstallChecker.shared.check()
                if !ClaudeInstallChecker.shared.isInstalled && !CodexInstallChecker.shared.isInstalled {
                    showClaudeNotInstalledAlert = true
                }
            }
            // 플러그인 확장 포인트 로드
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.6) {
                PluginHost.shared.reload()
            }
            // Daily login reward
            if let reward = AchievementManager.shared.claimDailyReward() {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    dailyRewardData = reward
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                        showDailyReward = true
                    }
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                updater.checkForUpdates()
            }
            // 결제일 알림 체크
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                checkBillingDay()
            }
        }
        .onDisappear { manager.stopScanning() }
    }

    // MARK: - Split View (기본 모드: 오피스 + 터미널)

    private var splitView: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottomTrailing) {
                OfficeSceneView()

                // 오피스 시점 + 확장/축소 버튼
                HStack(spacing: 3) {
                    // 전체 맵 ↔ 포커스 시점 토글
                    Button(action: {
                        withAnimation(chromeAnimation) {
                            settings.officeViewMode = settings.officeViewMode == "grid" ? "side" : "grid"
                        }
                    }) {
                        Image(systemName: settings.officeViewMode == "grid" ? "scope" : "rectangle.expand.vertical")
                            .font(.system(size: Theme.iconSize(10), weight: .bold))
                            .foregroundColor(Theme.textDim.opacity(0.6))
                            .frame(width: 26, height: 20)
                            .background(RoundedRectangle(cornerRadius: 5).fill(Theme.bgCard.opacity(0.7)))
                            .overlay(RoundedRectangle(cornerRadius: 5).stroke(Theme.border.opacity(0.3), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .help(settings.officeViewMode == "grid" ? NSLocalizedString("main.office.focus.toggle", comment: "") : NSLocalizedString("main.office.grid.toggle", comment: ""))

                    // 확장/축소
                    Button(action: {
                        withAnimation(chromeAnimation) {
                            officeExpanded.toggle()
                        }
                    }) {
                        Image(systemName: officeExpanded ? "chevron.up.2" : "chevron.down.2")
                            .font(.system(size: Theme.iconSize(10), weight: .bold))
                            .foregroundColor(Theme.textDim.opacity(0.5))
                            .frame(width: 26, height: 20)
                            .background(RoundedRectangle(cornerRadius: 5).fill(Theme.bgCard.opacity(0.7)))
                            .overlay(RoundedRectangle(cornerRadius: 5).stroke(Theme.border.opacity(0.3), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .help(officeExpanded ? NSLocalizedString("main.office.shrink", comment: "") : NSLocalizedString("main.office.expand", comment: ""))
                }
                .padding(4)
            }
            .frame(height: officeHeight)
            .clipped()

            Rectangle().fill(Theme.border).frame(height: 1)
            TerminalAreaView()
        }
    }

    // MARK: - Strip View (v1.2 스타일: 픽셀 스트립 + 터미널)

    private var stripView: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottom) {
                PixelStripView()
                    .frame(height: 140)

                if !manager.projectGroups.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(manager.projectGroups.prefix(8)) { group in
                            Button(action: {
                                if let tab = group.tabs.first { manager.selectTab(tab.id) }
                            }) {
                                HStack(spacing: 3) {
                                    Circle()
                                        .fill(group.tabs.contains(where: \.isRunning) ? Theme.green : Theme.textDim.opacity(0.3))
                                        .frame(width: 5, height: 5)
                                    Text(group.projectName)
                                        .font(Theme.mono(8, weight: group.hasActiveTab ? .bold : .medium))
                                        .foregroundColor(group.hasActiveTab ? Theme.accent : Theme.textSecondary)
                                        .lineLimit(1)
                                }
                                .padding(.horizontal, 6).padding(.vertical, 3)
                                .background(RoundedRectangle(cornerRadius: 5).fill(Theme.bgCard.opacity(0.75)))
                            }
                            .buttonStyle(.plain)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 10).padding(.bottom, 3)
                }
            }
            Rectangle().fill(Theme.border).frame(height: 1)
            TerminalAreaView()
        }
    }

    // MARK: - Office Full View (오피스 전체 화면)

    private var officeFullView: some View {
        OfficeSceneView()
    }

    func openOfficeWindow() {
        openWindow(id: "office-window")
        // 메인 창을 터미널 모드로 전환
        withAnimation(chromeAnimation) {
            viewModeRaw = ViewMode.terminal.rawValue
        }
    }

    private func checkBillingDay() {
        let day = settings.billingDay
        guard day > 0 else { return }

        let cal = Calendar.current
        let now = Date()
        let todayDay = cal.component(.day, from: now)
        let monthKey = "\(cal.component(.year, from: now))-\(cal.component(.month, from: now))"

        // 이미 이번 달에 알림을 보냈으면 스킵
        guard settings.billingLastNotifiedMonth != monthKey else { return }

        // 결제일 당일 또는 결제일이 지났는데 아직 알림 안 보낸 경우
        guard todayDay >= day else { return }

        settings.billingLastNotifiedMonth = monthKey

        let tracker = TokenTracker.shared
        let costStr = String(format: "$%.2f", tracker.todayCost)
        let tokens = tracker.todayTokens

        billingAlertMessage = String(format: NSLocalizedString("main.billing.alert", comment: ""), tokens > 1000 ? String(format: "%.1fK", Double(tokens)/1000) : "\(tokens)", costStr)

        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            showBillingAlert = true
        }
    }

    private func exportActiveLog() {
        guard let tab = manager.activeTab, let url = tab.exportLog() else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = url.lastPathComponent
        panel.allowedContentTypes = [.plainText]
        if panel.runModal() == .OK, let dest = panel.url {
            do {
                try FileManager.default.copyItem(at: url, to: dest)
            } catch {
                let alert = NSAlert()
                alert.messageText = NSLocalizedString("main.log.export.fail", comment: "")
                alert.informativeText = error.localizedDescription
                alert.alertStyle = .warning
                alert.runModal()
            }
        }
    }

}

// ═══════════════════════════════════════════════════════
// MARK: - Session Lock Overlay
// ═══════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════
// MARK: - Daily Reward Overlay
// ═══════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════
// MARK: - Billing Alert Overlay
// ═══════════════════════════════════════════════════════

struct BillingAlertOverlay: View {
    let message: String
    let onDismiss: () -> Void
    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.black.opacity(appeared ? 0.45 : 0)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(spacing: 16) {
                // 아이콘
                ZStack {
                    Circle()
                        .fill(RadialGradient(
                            colors: [Theme.orange.opacity(0.2), Theme.orange.opacity(0.05), .clear],
                            center: .center, startRadius: 0, endRadius: 50
                        ))
                        .frame(width: 80, height: 80)
                    Text("💳").font(.system(size: 36))
                }

                Text(NSLocalizedString("main.billing.alert.title", comment: ""))
                    .font(Theme.mono(15, weight: .black))
                    .foregroundColor(Theme.textPrimary)

                // 사용량 요약
                VStack(spacing: 8) {
                    ForEach(message.components(separatedBy: "\n").filter { !$0.isEmpty }, id: \.self) { line in
                        Text(line)
                            .font(Theme.mono(10, weight: line.contains(NSLocalizedString("main.billing.page", comment: "")) ? .bold : .regular))
                            .foregroundColor(line.contains(NSLocalizedString("main.billing.page", comment: "")) ? Theme.orange : Theme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Theme.orange.opacity(0.05))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.orange.opacity(0.15), lineWidth: 1))
                )

                HStack(spacing: 10) {
                    Button(action: onDismiss) {
                        Text(NSLocalizedString("main.billing.confirm", comment: ""))
                            .font(Theme.mono(11, weight: .bold))
                            .foregroundColor(Theme.textOnAccent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Theme.orange))
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        if let url = URL(string: "https://console.anthropic.com/settings/billing") {
                            NSWorkspace.shared.open(url)
                        }
                        onDismiss()
                    }) {
                        Text(NSLocalizedString("main.billing.page", comment: ""))
                            .font(Theme.mono(11, weight: .bold))
                            .foregroundColor(Theme.orange)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Theme.orange.opacity(0.08))
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.orange.opacity(0.3), lineWidth: 1))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(24)
            .frame(width: 320)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Theme.bgCard)
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.orange.opacity(0.2), lineWidth: 1))
            )
            .scaleEffect(appeared ? 1.0 : 0.85)
            .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                appeared = true
            }
        }
    }
}

struct DailyRewardOverlay: View {
    let reward: AchievementManager.DailyRewardResult
    let onDismiss: () -> Void
    @State private var appeared = false
    @State private var sparkles: [(x: CGFloat, y: CGFloat, delay: Double)] = (0..<12).map { _ in
        (CGFloat.random(in: -120...120), CGFloat.random(in: -80...80), Double.random(in: 0...0.5))
    }

    private var streakColor: Color {
        if reward.streak >= 100 { return Theme.yellow }
        if reward.streak >= 30 { return Theme.orange }
        if reward.streak >= 7 { return Theme.green }
        return Theme.accent
    }

    var body: some View {
        ZStack {
            Color.black.opacity(appeared ? 0.5 : 0)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(spacing: 0) {
                // 상단 이모지 + 파티클
                ZStack {
                    // 반짝이는 파티클
                    ForEach(0..<sparkles.count, id: \.self) { i in
                        Text(["✦", "✧", "·", "★", "◆"][i % 5])
                            .font(.system(size: CGFloat.random(in: 6...12)))
                            .foregroundColor(streakColor.opacity(appeared ? 0.8 : 0))
                            .offset(
                                x: appeared ? sparkles[i].x : 0,
                                y: appeared ? sparkles[i].y : 0
                            )
                            .animation(
                                .easeOut(duration: 0.8).delay(sparkles[i].delay),
                                value: appeared
                            )
                    }

                    Text(reward.isMilestone ? reward.milestoneEmoji : "📅")
                        .font(.system(size: appeared ? 48 : 20))
                        .animation(.spring(response: 0.5, dampingFraction: 0.6), value: appeared)
                }
                .frame(height: 100)

                // 제목
                Text(reward.isMilestone ? reward.milestoneLabel : NSLocalizedString("main.attendance.check", comment: ""))
                    .font(Theme.mono(16, weight: .black))
                    .foregroundColor(Theme.textPrimary)
                    .padding(.bottom, 4)

                Text(String(format: NSLocalizedString("main.attendance.streak", comment: ""), reward.streak))
                    .font(Theme.mono(11, weight: .bold))
                    .foregroundColor(streakColor)
                    .padding(.bottom, 16)

                // XP 보상 카드
                HStack(spacing: 20) {
                    rewardBadge(label: NSLocalizedString("main.attendance.basic", comment: ""), value: "+\(reward.xp)", color: Theme.accent)
                    if reward.bonusXP > 0 {
                        rewardBadge(label: NSLocalizedString("main.attendance.bonus", comment: ""), value: "+\(reward.bonusXP)", color: Theme.yellow)
                    }
                }
                .padding(.bottom, 16)

                // 연속 출석 진행 바 (7일 기준)
                VStack(spacing: 6) {
                    HStack(spacing: 4) {
                        ForEach(0..<7, id: \.self) { day in
                            let filled = (reward.streak % 7 == 0) ? 7 : reward.streak % 7
                            ZStack {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(day < filled ? streakColor.opacity(0.2) : Theme.bgSurface)
                                    .frame(width: 28, height: 28)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4)
                                            .stroke(day < filled ? streakColor.opacity(0.4) : Theme.border.opacity(0.2), lineWidth: 1)
                                    )
                                if day < filled {
                                    Text("✓")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(streakColor)
                                } else {
                                    Text("\(day + 1)")
                                        .font(Theme.mono(8))
                                        .foregroundColor(Theme.textDim)
                                }
                            }
                        }
                    }
                    Text(NSLocalizedString("main.attendance.weekly", comment: ""))
                        .font(Theme.mono(8))
                        .foregroundColor(Theme.textDim)
                }
                .padding(.bottom, 20)

                // 확인 버튼
                Button(action: onDismiss) {
                    Text(NSLocalizedString("confirm", comment: ""))
                        .font(Theme.mono(12, weight: .bold))
                        .foregroundColor(Theme.textOnAccent)
                        .frame(width: 120)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(LinearGradient(colors: [streakColor, streakColor.opacity(0.7)], startPoint: .top, endPoint: .bottom))
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(28)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Theme.bgCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(streakColor.opacity(0.2), lineWidth: 1)
                    )
            )
            .frame(width: 300)
            .scaleEffect(appeared ? 1.0 : 0.85)
            .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                appeared = true
            }
        }
    }

    private func rewardBadge(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(Theme.mono(18, weight: .black))
                .foregroundColor(color)
            Text("XP")
                .font(Theme.mono(8, weight: .bold))
                .foregroundColor(color.opacity(0.6))
            Text(label)
                .font(Theme.mono(8))
                .foregroundColor(Theme.textDim)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(color.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(color.opacity(0.15), lineWidth: 1)
                )
        )
    }
}

struct SessionLockOverlay: View {
    @StateObject private var settings = AppSettings.shared
    @State private var pinInput = ""
    @State private var wrongPin = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 40))
                    .foregroundColor(Theme.yellow)

                Text(NSLocalizedString("main.session.locked", comment: ""))
                    .font(Theme.mono(16, weight: .bold))
                    .foregroundColor(Theme.textPrimary)

                Text(NSLocalizedString("main.session.still.running", comment: ""))
                    .font(Theme.mono(10))
                    .foregroundColor(Theme.textDim)

                if !settings.lockPIN.isEmpty {
                    SecureField(NSLocalizedString("main.pin.input", comment: ""), text: $pinInput)
                        .font(Theme.monoNormal)
                        .textFieldStyle(.plain)
                        .frame(width: 160)
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Theme.bgSurface))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(wrongPin ? Theme.red : Theme.border, lineWidth: 1))
                        .multilineTextAlignment(.center)
                        .onSubmit {
                            if pinInput == settings.lockPIN {
                                settings.isLocked = false
                                pinInput = ""
                                wrongPin = false
                            } else {
                                wrongPin = true
                                pinInput = ""
                            }
                        }

                    if wrongPin {
                        Text(NSLocalizedString("main.pin.wrong", comment: ""))
                            .font(Theme.mono(9, weight: .bold))
                            .foregroundColor(Theme.red)
                    }
                } else {
                    Button(NSLocalizedString("main.unlock", comment: "")) {
                        settings.isLocked = false
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20).padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Theme.accentBackground))
                    .foregroundColor(Theme.textOnAccent)
                    .font(Theme.mono(11, weight: .bold))
                }
            }
            .padding(40)
        }
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - Bug Report View
// ═══════════════════════════════════════════════════════

struct BugReportView: View {
    @Environment(\.dismiss) var dismiss
    @State private var title = ""
    @State private var description = ""
    @State private var screenshotImage: NSImage?
    @State private var isSending = false
    @State private var sent = false

    var body: some View {
        VStack(spacing: 18) {
            DSModalHeader(
                icon: "ladybug.fill",
                iconColor: Theme.red,
                title: NSLocalizedString("main.bug.title", comment: ""),
                subtitle: NSLocalizedString("main.bug.subtitle", comment: ""),
                onClose: { dismiss() }
            )

            if sent {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: Theme.iconSize(34)))
                        .foregroundColor(Theme.green)
                    Text(NSLocalizedString("main.bug.sent.title", comment: ""))
                        .font(Theme.mono(12, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                    Text(NSLocalizedString("main.bug.sent.message", comment: ""))
                        .font(Theme.mono(8))
                        .foregroundColor(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .appPanelStyle(fill: Theme.bgCard.opacity(0.98), strokeOpacity: 0.22, shadow: false)
            } else {
                reportSection(
                    title: NSLocalizedString("main.bug.summary.title", comment: ""),
                    subtitle: NSLocalizedString("main.bug.summary.subtitle", comment: "")
                ) {
                    TextField(NSLocalizedString("main.bug.summary.placeholder", comment: ""), text: $title)
                        .textFieldStyle(.plain)
                        .font(Theme.monoSmall)
                        .appFieldStyle(emphasized: true)
                        .accessibilityLabel(NSLocalizedString("main.bug.summary.title", comment: ""))
                        .accessibilityHint(NSLocalizedString("main.bug.summary.subtitle", comment: ""))
                }

                reportSection(
                    title: NSLocalizedString("main.bug.detail.title", comment: ""),
                    subtitle: NSLocalizedString("main.bug.detail.subtitle", comment: "")
                ) {
                    TextEditor(text: $description)
                        .font(Theme.monoSmall)
                        .foregroundColor(Theme.textPrimary)
                        .frame(height: 130)
                        .scrollContentBackground(.hidden)
                        .appFieldStyle()
                        .accessibilityLabel(NSLocalizedString("main.bug.detail.title", comment: ""))
                }

                reportSection(
                    title: NSLocalizedString("main.bug.screenshot.title", comment: ""),
                    subtitle: NSLocalizedString("main.bug.screenshot.subtitle", comment: "")
                ) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Button(action: captureScreenshot) {
                                HStack(spacing: 6) {
                                    Image(systemName: "camera.fill")
                                    Text(NSLocalizedString("main.bug.capture", comment: ""))
                                }
                                .font(Theme.mono(9, weight: .bold))
                                .appButtonSurface(tone: .accent, compact: true)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(NSLocalizedString("main.bug.capture", comment: ""))

                            Button(action: pickImage) {
                                HStack(spacing: 6) {
                                    Image(systemName: "photo")
                                    Text(NSLocalizedString("main.bug.choose.file", comment: ""))
                                }
                                .font(Theme.mono(9, weight: .bold))
                                .appButtonSurface(tone: .neutral, compact: true)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(NSLocalizedString("main.bug.choose.file", comment: ""))

                            Spacer()

                            if screenshotImage != nil {
                                HStack(spacing: 6) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(Theme.green)
                                    Text(NSLocalizedString("main.bug.attached", comment: ""))
                                        .font(Theme.mono(8, weight: .bold))
                                        .foregroundColor(Theme.green)
                                    Button(action: { screenshotImage = nil }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(Theme.textDim)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel(NSLocalizedString("delete", comment: ""))
                                }
                            }
                        }

                        if let img = screenshotImage {
                            Image(nsImage: img)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: .infinity, maxHeight: 160)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Theme.border.opacity(0.28), lineWidth: 1)
                                )
                        }
                    }
                }
            }

            HStack {
                Button(action: { dismiss() }) {
                    Text(sent ? NSLocalizedString("close", comment: "") : NSLocalizedString("cancel", comment: ""))
                        .font(Theme.mono(10, weight: .bold))
                        .appButtonSurface(tone: .neutral)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape)

                Spacer()

                if !sent {
                    Button(action: sendReport) {
                        HStack(spacing: 6) {
                            if isSending {
                                ProgressView().scaleEffect(0.7)
                            } else {
                                Image(systemName: "paperplane.fill")
                            }
                            Text(NSLocalizedString("main.bug.send", comment: ""))
                                .font(Theme.mono(10, weight: .bold))
                        }
                        .appButtonSurface(tone: .accent, prominent: true)
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.return)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
                    .accessibilityLabel(NSLocalizedString("main.bug.send", comment: ""))
                }
            }
        }
        .padding(24)
        .frame(width: 540)
        .background(Theme.bg)
    }

    private func reportSection<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(Theme.mono(10, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                Text(subtitle)
                    .font(Theme.mono(8))
                    .foregroundColor(Theme.textDim)
            }

            content()
        }
        .appPanelStyle(fill: Theme.bgCard.opacity(0.98), strokeOpacity: 0.22, shadow: false)
    }

    private func captureScreenshot() {
        guard let window = NSApp.mainWindow,
              let contentView = window.contentView else { return }

        let bounds = contentView.bounds
        guard let bitmap = contentView.bitmapImageRepForCachingDisplay(in: bounds) else { return }
        contentView.cacheDisplay(in: bounds, to: bitmap)

        let image = NSImage(size: bounds.size)
        image.addRepresentation(bitmap)
        screenshotImage = image
    }

    private func pickImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .tiff]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url, let img = NSImage(contentsOf: url) {
            screenshotImage = img
        }
    }

    private func sendReport() {
        guard !isSending else { return }
        isSending = true

        // 스크린샷을 임시 파일로 저장
        var attachmentPath: String?
        if let img = screenshotImage, let tiff = img.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiff),
           let png = bitmap.representation(using: .png, properties: [:]) {
            let tmpURL = FileManager.default.temporaryDirectory.appendingPathComponent("doffice_bug_\(Int(Date().timeIntervalSince1970)).png")
            try? png.write(to: tmpURL)
            attachmentPath = tmpURL.path
        }

        // 시스템 정보 수집
        let sysInfo = """
        App: 도피스
        macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)
        Claude: \(ClaudeInstallChecker.shared.version)
        Codex: \(CodexInstallChecker.shared.version)
        Sessions: \(SessionManager.shared.userVisibleTabCount)
        Theme: \(AppSettings.shared.isDarkMode ? "Dark" : "Light")
        Font Scale: \(AppSettings.shared.fontSizeScale)
        """

        let body = """
        [버그 제목] \(title)

        [상세 설명]
        \(description)

        [시스템 정보]
        \(sysInfo)
        """

        // mailto URL (이미지는 첨부 안내)
        let mailBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let mailSubject = String(format: NSLocalizedString("bug.report.subject", comment: ""), title).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let mailURL = "mailto:goodjunha@gmail.com?subject=\(mailSubject)&body=\(mailBody)"

        if let url = URL(string: mailURL) {
            NSWorkspace.shared.open(url)
        }

        // 스크린샷이 있으면 Finder에서 열어서 수동 첨부 안내
        if let path = attachmentPath {
            NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isSending = false
            sent = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { dismiss() }
        }
    }
}

// MARK: - Notification Handlers (split from body to help type-checker)

private struct NotificationHandlersModifier: ViewModifier {
    @ObservedObject var manager: SessionManager
    let chromeAnimation: Animation
    @Binding var viewModeRaw: Int
    @Binding var showClaudeNotInstalledAlert: Bool
    @Binding var showRoleNoticeAlert: Bool
    @Binding var roleNoticeTitle: String
    @Binding var roleNoticeMessage: String
    @Binding var showCommandPalette: Bool
    @Binding var showActionCenter: Bool
    let exportActiveLog: () -> Void

    func body(content: Content) -> some View {
        applyHandlers(content)
    }

    private func applyHandlers(_ content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .dofficeRefresh)) { _ in manager.refresh() }
            .onReceive(NotificationCenter.default.publisher(for: .dofficeNewTab)) { _ in manager.showNewTabSheet = true }
            .onReceive(NotificationCenter.default.publisher(for: .dofficeCloseTab)) { _ in
                if let id = manager.activeTabId { manager.removeTab(id) }
            }
            .onDeleteCommand {
                if let id = manager.activeTabId { manager.removeTab(id) }
            }
            .onReceive(NotificationCenter.default.publisher(for: .dofficeSelectTab)) { notif in
                let tabs = manager.userVisibleTabs
                if let i = notif.object as? Int, i >= 1, i <= tabs.count { manager.selectTab(tabs[i-1].id) }
            }
            .onReceive(NotificationCenter.default.publisher(for: .dofficeExportLog)) { _ in exportActiveLog() }
            .onReceive(NotificationCenter.default.publisher(for: .dofficeRestartSession)) { _ in
                if let tab = manager.activeTab { tab.stop(); tab.start() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .dofficeNextTab)) { _ in
                let tabs = manager.userVisibleTabs
                guard tabs.count > 1, let currentId = manager.activeTabId,
                      let idx = tabs.firstIndex(where: { $0.id == currentId }) else { return }
                manager.selectTab(tabs[(idx + 1) % tabs.count].id)
            }
            .onReceive(NotificationCenter.default.publisher(for: .dofficePreviousTab)) { _ in
                let tabs = manager.userVisibleTabs
                guard tabs.count > 1, let currentId = manager.activeTabId,
                      let idx = tabs.firstIndex(where: { $0.id == currentId }) else { return }
                manager.selectTab(tabs[(idx - 1 + tabs.count) % tabs.count].id)
            }
    }

    private func applyPartB(_ content: some View) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .dofficeCancelProcessing)) { _ in
                if let tab = manager.activeTab { tab.cancelProcessing() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .dofficeClearTerminal)) { _ in
                if let tab = manager.activeTab { tab.clearBlocks() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .dofficeToggleOffice)) { _ in
                withAnimation(chromeAnimation) { viewModeRaw = viewModeRaw == 1 ? 0 : 1 }
            }
            .onReceive(NotificationCenter.default.publisher(for: .dofficeToggleTerminal)) { _ in
                withAnimation(chromeAnimation) { viewModeRaw = viewModeRaw == 2 ? 0 : 2 }
            }
            .onReceive(NotificationCenter.default.publisher(for: .dofficeClaudeNotInstalled)) { _ in
                showClaudeNotInstalledAlert = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .dofficeRoleNotice)) { notif in
                roleNoticeTitle = notif.userInfo?["title"] as? String ?? NSLocalizedString("main.job.notice", comment: "")
                roleNoticeMessage = notif.userInfo?["message"] as? String ?? ""
                showRoleNoticeAlert = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .dofficeCommandPalette)) { _ in showCommandPalette.toggle() }
            .onReceive(NotificationCenter.default.publisher(for: .dofficeActionCenter)) { _ in showActionCenter = true }
            .onReceive(NotificationCenter.default.publisher(for: .dofficeOpenBrowser)) { notif in
                // IPC 서버에서 브라우저 열기 요청 → 터미널 모드(2)로 전환 후 브라우저 뷰 활성화
                withAnimation(chromeAnimation) { viewModeRaw = 2 }
                let url = notif.object as? String
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    NotificationCenter.default.post(name: .dofficeToggleBrowser, object: url)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .dofficeToggleBrowser)) { _ in
                if viewModeRaw != 2 { withAnimation(chromeAnimation) { viewModeRaw = 2 } }
            }
            .onChange(of: viewModeRaw) { _, newValue in
                if newValue == 2 { OfficeSceneStore.shared.suspend() }
            }
    }
}

extension View {
    func withNotificationHandlers(
        manager: SessionManager, chromeAnimation: Animation,
        viewModeRaw: Binding<Int>,
        showClaudeNotInstalledAlert: Binding<Bool>,
        showRoleNoticeAlert: Binding<Bool>,
        roleNoticeTitle: Binding<String>,
        roleNoticeMessage: Binding<String>,
        showCommandPalette: Binding<Bool>,
        showActionCenter: Binding<Bool>,
        exportActiveLog: @escaping () -> Void
    ) -> some View {
        modifier(NotificationHandlersModifier(
            manager: manager, chromeAnimation: chromeAnimation,
            viewModeRaw: viewModeRaw,
            showClaudeNotInstalledAlert: showClaudeNotInstalledAlert,
            showRoleNoticeAlert: showRoleNoticeAlert,
            roleNoticeTitle: roleNoticeTitle,
            roleNoticeMessage: roleNoticeMessage,
            showCommandPalette: showCommandPalette,
            showActionCenter: showActionCenter,
            exportActiveLog: exportActiveLog
        ))
    }
}

// MARK: - Window Configurator (타이틀 바 공백 제거)

private struct WindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                window.titlebarAppearsTransparent = true
                window.titleVisibility = .hidden
                window.isMovableByWindowBackground = true
                window.styleMask.insert(.fullSizeContentView)
            }
        }
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}
