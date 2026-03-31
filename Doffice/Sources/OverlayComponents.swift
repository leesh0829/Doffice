import SwiftUI
import Combine

// ═══════════════════════════════════════════════════════
// MARK: - 1. 확인 필요 센터 (Action Center)
// ═══════════════════════════════════════════════════════

struct ActionCenterView: View {
    @EnvironmentObject var manager: SessionManager
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var settings = AppSettings.shared

    private var attentionTabs: [TerminalTab] {
        manager.userVisibleTabs.filter { $0.statusPresentation.category == .attention }
    }
    private var processingTabs: [TerminalTab] {
        manager.userVisibleTabs.filter { $0.statusPresentation.category == .processing }
    }
    private var completedTabs: [TerminalTab] {
        manager.userVisibleTabs.filter { $0.statusPresentation.category == .completed }
    }
    private var pendingApprovalTabs: [TerminalTab] {
        manager.userVisibleTabs.filter { $0.pendingApproval != nil }
    }

    var body: some View {
        VStack(spacing: 0) {
            DSModalHeader(
                icon: "bell.badge.fill",
                iconColor: Theme.orange,
                title: NSLocalizedString("overlay.action.center", comment: ""),
                subtitle: NSLocalizedString("overlay.action.center.subtitle", comment: ""),
                onClose: { dismiss() }
            )

            ScrollView {
                VStack(spacing: 16) {
                    // 승인 대기
                    if !pendingApprovalTabs.isEmpty {
                        actionSection(
                            title: NSLocalizedString("overlay.pending.approval", comment: ""),
                            symbol: "hand.raised.fill",
                            tint: Theme.orange,
                            tabs: pendingApprovalTabs
                        ) { tab in
                            HStack(spacing: 6) {
                                Text(tab.pendingApproval?.command ?? NSLocalizedString("overlay.tool.approval", comment: ""))
                                    .font(Theme.mono(8))
                                    .foregroundColor(Theme.textDim)
                                    .lineLimit(1)
                                Spacer()
                                Button(NSLocalizedString("overlay.go", comment: "")) {
                                    manager.selectTab(tab.id)
                                    dismiss()
                                }
                                .font(Theme.mono(8, weight: .bold))
                                .foregroundStyle(Theme.accentBackground)
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // 오류
                    if !attentionTabs.isEmpty {
                        actionSection(
                            title: NSLocalizedString("overlay.needs.attention", comment: ""),
                            symbol: "exclamationmark.triangle.fill",
                            tint: Theme.red,
                            tabs: attentionTabs
                        ) { tab in
                            HStack(spacing: 6) {
                                Text(tab.startError ?? NSLocalizedString("overlay.error.occurred", comment: ""))
                                    .font(Theme.mono(8))
                                    .foregroundColor(Theme.textDim)
                                    .lineLimit(1)
                                Spacer()
                                Button(NSLocalizedString("overlay.go", comment: "")) {
                                    manager.selectTab(tab.id)
                                    dismiss()
                                }
                                .font(Theme.mono(8, weight: .bold))
                                .foregroundStyle(Theme.accentBackground)
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // 작업 중
                    if !processingTabs.isEmpty {
                        actionSection(
                            title: NSLocalizedString("overlay.in.progress", comment: ""),
                            symbol: "gearshape.2.fill",
                            tint: Theme.accent,
                            tabs: processingTabs
                        ) { tab in
                            HStack(spacing: 6) {
                                Text(tab.statusPresentation.label)
                                    .font(Theme.mono(8))
                                    .foregroundColor(Theme.textDim)
                                Spacer()
                                Button(NSLocalizedString("overlay.go", comment: "")) {
                                    manager.selectTab(tab.id)
                                    dismiss()
                                }
                                .font(Theme.mono(8, weight: .bold))
                                .foregroundStyle(Theme.accentBackground)
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // 완료
                    if !completedTabs.isEmpty {
                        actionSection(
                            title: NSLocalizedString("overlay.completed", comment: ""),
                            symbol: "checkmark.circle.fill",
                            tint: Theme.green,
                            tabs: completedTabs
                        ) { tab in
                            HStack(spacing: 6) {
                                if tab.tokensUsed > 0 {
                                    Text("\(tab.tokensUsed) tokens")
                                        .font(Theme.mono(8))
                                        .foregroundColor(Theme.textDim)
                                }
                                Spacer()
                                Button(NSLocalizedString("overlay.go", comment: "")) {
                                    manager.selectTab(tab.id)
                                    dismiss()
                                }
                                .font(Theme.mono(8, weight: .bold))
                                .foregroundStyle(Theme.accentBackground)
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if pendingApprovalTabs.isEmpty && attentionTabs.isEmpty && processingTabs.isEmpty && completedTabs.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 32))
                                .foregroundColor(Theme.green.opacity(0.6))
                            Text(NSLocalizedString("overlay.all.normal", comment: ""))
                                .font(Theme.mono(11, weight: .medium))
                                .foregroundColor(Theme.textDim)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                    }
                }
                .padding(18)
            }
        }
        .background(Theme.bgCard)
        .frame(minWidth: 500, minHeight: 400)
    }

    private func actionSection<Detail: View>(
        title: String,
        symbol: String,
        tint: Color,
        tabs: [TerminalTab],
        @ViewBuilder detail: @escaping (TerminalTab) -> Detail
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: Theme.iconSize(10)))
                    .foregroundColor(tint)
                Text(title)
                    .font(Theme.mono(10, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                Text("\(tabs.count)")
                    .font(Theme.mono(9, weight: .bold))
                    .foregroundColor(tint)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(tint.opacity(0.15))
                    .cornerRadius(3)
            }

            VStack(spacing: 4) {
                ForEach(tabs) { tab in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(tab.statusPresentation.tint)
                                .frame(width: 6, height: 6)
                            Text(tab.workerName.isEmpty ? tab.projectName : tab.workerName)
                                .font(Theme.mono(10, weight: .medium))
                                .foregroundColor(Theme.textPrimary)
                                .lineLimit(1)
                            Text(tab.projectName)
                                .font(Theme.mono(8))
                                .foregroundColor(Theme.textDim)
                                .lineLimit(1)
                            Spacer()
                        }
                        detail(tab)
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Theme.bgSurface.opacity(0.6)))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(tint.opacity(0.15), lineWidth: 1))
                }
            }
        }
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - 2. 커맨드 팔레트 (Command Palette)
// ═══════════════════════════════════════════════════════

struct CommandPaletteAction: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let symbol: String
    let tint: Color
    let action: () -> Void
}

struct CommandPaletteView: View {
    @EnvironmentObject var manager: SessionManager
    @ObservedObject private var settings = AppSettings.shared
    @Binding var isPresented: Bool
    @State private var query = ""
    @FocusState private var isFocused: Bool
    @State private var selectedIndex = 0

    var onNewSession: () -> Void
    var onSettings: () -> Void
    var onBugReport: () -> Void
    var onExportLog: () -> Void
    var onSetViewMode: (Int) -> Void

    private var allActions: [CommandPaletteAction] {
        var actions: [CommandPaletteAction] = [
            CommandPaletteAction(title: NSLocalizedString("overlay.new.session", comment: ""), subtitle: "Cmd+T", symbol: "plus.circle.fill", tint: Theme.green) {
                isPresented = false; onNewSession()
            },
            CommandPaletteAction(title: NSLocalizedString("overlay.refresh.session", comment: ""), subtitle: "Cmd+R", symbol: "arrow.clockwise", tint: Theme.accent) {
                isPresented = false; manager.refresh()
            },
            CommandPaletteAction(title: NSLocalizedString("overlay.settings", comment: ""), subtitle: "", symbol: "gearshape.fill", tint: Theme.textSecondary) {
                isPresented = false; onSettings()
            },
            CommandPaletteAction(title: NSLocalizedString("overlay.bug.report", comment: ""), subtitle: "", symbol: "ladybug.fill", tint: Theme.red) {
                isPresented = false; onBugReport()
            },
            CommandPaletteAction(title: NSLocalizedString("overlay.export.log", comment: ""), subtitle: "Cmd+Shift+E", symbol: "square.and.arrow.up", tint: Theme.cyan) {
                isPresented = false; onExportLog()
            },
            CommandPaletteAction(title: NSLocalizedString("overlay.split.view", comment: ""), subtitle: "", symbol: "rectangle.split.1x2", tint: Theme.accent) {
                isPresented = false; onSetViewMode(0)
            },
            CommandPaletteAction(title: NSLocalizedString("overlay.office.view", comment: ""), subtitle: "", symbol: "building.2", tint: Theme.purple) {
                isPresented = false; onSetViewMode(1)
            },
            CommandPaletteAction(title: NSLocalizedString("overlay.strip.view", comment: ""), subtitle: "", symbol: "person.2.fill", tint: Theme.orange) {
                isPresented = false; onSetViewMode(3)
            },
            CommandPaletteAction(title: NSLocalizedString("overlay.terminal.view", comment: ""), subtitle: "", symbol: "terminal", tint: Theme.green) {
                isPresented = false; onSetViewMode(2)
            },
        ]

        // 플러그인 명령어 추가
        for cmd in PluginHost.shared.commands {
            actions.append(CommandPaletteAction(title: cmd.title, subtitle: "[\(cmd.pluginName)]", symbol: cmd.icon, tint: Theme.purple) {
                isPresented = false
                PluginHost.shared.executeCommand(cmd, projectPath: manager.activeTab?.projectPath)
            })
        }

        // 현재 세션들을 검색 대상에 추가
        for tab in manager.userVisibleTabs {
            let name = tab.workerName.isEmpty ? tab.projectName : "\(tab.workerName) · \(tab.projectName)"
            actions.append(CommandPaletteAction(title: name, subtitle: NSLocalizedString("overlay.go.to.session", comment: ""), symbol: "arrow.right.circle", tint: tab.statusPresentation.tint) {
                isPresented = false; manager.selectTab(tab.id)
            })
        }

        return actions
    }

    private var filteredActions: [CommandPaletteAction] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return allActions }
        return allActions.filter {
            $0.title.lowercased().contains(q) || $0.subtitle.lowercased().contains(q)
        }
    }

    var body: some View {
        ZStack {
            // Backdrop
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { isPresented = false }

            VStack(spacing: 0) {
                // Search field
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: Theme.iconSize(14)))
                        .foregroundColor(Theme.textDim)
                    TextField(NSLocalizedString("overlay.search.commands", comment: ""), text: $query)
                        .font(Theme.mono(13))
                        .textFieldStyle(.plain)
                        .foregroundColor(Theme.textPrimary)
                        .focused($isFocused)
                        .onSubmit { executeSelected() }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

                Rectangle().fill(Theme.border.opacity(0.5)).frame(height: 1)

                // Results
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 2) {
                            ForEach(Array(filteredActions.enumerated()), id: \.element.id) { index, action in
                                commandRow(action: action, isSelected: index == selectedIndex)
                                    .id(index)
                                    .onTapGesture { action.action() }
                            }
                        }
                        .padding(8)
                    }
                    .onChange(of: selectedIndex) { _, newVal in
                        withAnimation(.easeOut(duration: 0.1)) { proxy.scrollTo(newVal, anchor: .center) }
                    }
                }
                .frame(maxHeight: 340)

                Rectangle().fill(Theme.border.opacity(0.3)).frame(height: 1)

                // Footer
                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 8))
                        Text(NSLocalizedString("overlay.navigate", comment: ""))
                            .font(Theme.mono(8))
                    }
                    .foregroundColor(Theme.textDim)
                    HStack(spacing: 4) {
                        Image(systemName: "return")
                            .font(.system(size: 8))
                        Text(NSLocalizedString("overlay.execute", comment: ""))
                            .font(Theme.mono(8))
                    }
                    .foregroundColor(Theme.textDim)
                    HStack(spacing: 4) {
                        Text("esc")
                            .font(Theme.mono(8))
                        Text(NSLocalizedString("overlay.close", comment: ""))
                            .font(Theme.mono(8))
                    }
                    .foregroundColor(Theme.textDim)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .background(Theme.bgCard)
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border.opacity(0.4), lineWidth: 1))
            .frame(width: 520)
            .padding(.top, 80)
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .onAppear {
            isFocused = true
            selectedIndex = 0
        }
        .onChange(of: query) { _, _ in selectedIndex = 0 }
        .onKeyPress(.upArrow) { moveSelection(-1); return .handled }
        .onKeyPress(.downArrow) { moveSelection(1); return .handled }
        .onKeyPress(.escape) { isPresented = false; return .handled }
        .onKeyPress(.return) { executeSelected(); return .handled }
    }

    private func commandRow(action: CommandPaletteAction, isSelected: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: action.symbol)
                .font(.system(size: Theme.iconSize(12)))
                .foregroundColor(action.tint)
                .frame(width: 22)
            Text(action.title)
                .font(Theme.mono(11, weight: .medium))
                .foregroundColor(Theme.textPrimary)
            if !action.subtitle.isEmpty {
                Text(action.subtitle)
                    .font(Theme.mono(9))
                    .foregroundColor(Theme.textDim)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 8).fill(isSelected ? Theme.accent.opacity(0.12) : .clear))
        .contentShape(Rectangle())
    }

    private func moveSelection(_ delta: Int) {
        let count = filteredActions.count
        guard count > 0 else { return }
        selectedIndex = (selectedIndex + delta + count) % count
    }

    private func executeSelected() {
        let actions = filteredActions
        guard selectedIndex >= 0, selectedIndex < actions.count else { return }
        actions[selectedIndex].action()
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - 3. 작업 프리셋 저장 (Custom Session Presets)
// ═══════════════════════════════════════════════════════

struct CustomSessionPreset: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
    var name: String
    var icon: String  // SF Symbol name
    var tint: String  // "accent", "purple", "orange", "cyan", "green", "red"
    var draft: NewSessionDraftSnapshot

    static func == (lhs: CustomSessionPreset, rhs: CustomSessionPreset) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

final class CustomPresetStore: ObservableObject {
    static let shared = CustomPresetStore()
    @Published private(set) var presets: [CustomSessionPreset] = []
    private let key = "doffice.custom-session-presets"

    private init() { load() }

    func save(_ preset: CustomSessionPreset) {
        if let idx = presets.firstIndex(where: { $0.id == preset.id }) {
            presets[idx] = preset
        } else {
            presets.insert(preset, at: 0)
        }
        persist()
    }

    func delete(_ preset: CustomSessionPreset) {
        presets.removeAll { $0.id == preset.id }
        persist()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([CustomSessionPreset].self, from: data) else { return }
        presets = decoded
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(presets) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

struct SavePresetSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var store = CustomPresetStore.shared
    @State private var presetName = ""
    @State private var selectedIcon = "star.fill"
    @State private var selectedTint = "accent"
    let draft: NewSessionDraftSnapshot

    private let icons = ["star.fill", "hammer.fill", "shield.fill", "bolt.fill", "leaf.fill", "flame.fill", "wand.and.stars", "cpu"]
    private let tints: [(String, Color)] = [
        ("accent", Theme.accent), ("purple", Theme.purple), ("orange", Theme.orange),
        ("cyan", Theme.cyan), ("green", Theme.green), ("red", Theme.red)
    ]

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text(NSLocalizedString("overlay.save.preset", comment: ""))
                    .font(Theme.mono(14, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Theme.textDim)
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(NSLocalizedString("overlay.label.name", comment: "")).font(Theme.mono(9, weight: .bold)).foregroundColor(Theme.textSecondary)
                TextField(NSLocalizedString("overlay.preset.placeholder", comment: ""), text: $presetName)
                    .textFieldStyle(.plain)
                    .font(Theme.mono(11))
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Theme.bgSurface))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border.opacity(0.3), lineWidth: 1))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(NSLocalizedString("overlay.label.icon", comment: "")).font(Theme.mono(9, weight: .bold)).foregroundColor(Theme.textSecondary)
                HStack(spacing: 8) {
                    ForEach(icons, id: \.self) { icon in
                        Button(action: { selectedIcon = icon }) {
                            Image(systemName: icon)
                                .font(.system(size: Theme.iconSize(14)))
                                .foregroundColor(selectedIcon == icon ? Theme.accent : Theme.textDim)
                                .frame(width: 32, height: 32)
                                .background(RoundedRectangle(cornerRadius: 6).fill(selectedIcon == icon ? Theme.accent.opacity(0.12) : Theme.bgSurface))
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(selectedIcon == icon ? Theme.accent.opacity(0.4) : Theme.border.opacity(0.2), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(NSLocalizedString("overlay.label.color", comment: "")).font(Theme.mono(9, weight: .bold)).foregroundColor(Theme.textSecondary)
                HStack(spacing: 8) {
                    ForEach(tints, id: \.0) { name, color in
                        Button(action: { selectedTint = name }) {
                            Circle()
                                .fill(color)
                                .frame(width: 24, height: 24)
                                .overlay(Circle().stroke(.white.opacity(selectedTint == name ? 0.8 : 0), lineWidth: 2))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // 설정 요약
            VStack(alignment: .leading, spacing: 4) {
                Text(NSLocalizedString("overlay.included.settings", comment: "")).font(Theme.mono(9, weight: .bold)).foregroundColor(Theme.textSecondary)
                HStack(spacing: 8) {
                    presetTag(String(format: NSLocalizedString("overlay.model.prefix", comment: ""), "\(draft.selectedModel)"))
                    presetTag(String(format: NSLocalizedString("overlay.effort.prefix", comment: ""), "\(draft.effortLevel)"))
                    presetTag(String(format: NSLocalizedString("overlay.terminal.prefix", comment: ""), "\(draft.terminalCount)"))
                    if !draft.systemPrompt.isEmpty { presetTag(NSLocalizedString("overlay.system.prompt", comment: "")) }
                }
            }

            HStack {
                Button(NSLocalizedString("overlay.cancel", comment: "")) { dismiss() }
                    .buttonStyle(.plain)
                    .font(Theme.mono(10, weight: .bold))
                    .foregroundColor(Theme.textDim)
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Theme.bgSurface))
                    .keyboardShortcut(.escape)
                Spacer()
                Button(NSLocalizedString("overlay.save", comment: "")) {
                    let preset = CustomSessionPreset(
                        name: presetName.trimmingCharacters(in: .whitespacesAndNewlines),
                        icon: selectedIcon,
                        tint: selectedTint,
                        draft: draft
                    )
                    store.save(preset)
                    dismiss()
                }
                .buttonStyle(.plain)
                .font(Theme.mono(10, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 20).padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 8).fill(Theme.accentBackground))
                .keyboardShortcut(.return)
                .disabled(presetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 420)
        .background(Theme.bg)
    }

    private func presetTag(_ text: String) -> some View {
        Text(text)
            .font(Theme.mono(8))
            .foregroundColor(Theme.textDim)
            .padding(.horizontal, 6).padding(.vertical, 3)
            .background(Theme.bgSurface)
            .cornerRadius(4)
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - 4. 세션 알림 시스템 (Session Notification Banners)
// ═══════════════════════════════════════════════════════

struct SessionNotification: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let detail: String
    let symbol: String
    let tint: Color
    let tabId: String?
    let timestamp = Date()

    static func == (lhs: SessionNotification, rhs: SessionNotification) -> Bool { lhs.id == rhs.id }
}

final class SessionNotificationManager: ObservableObject {
    static let shared = SessionNotificationManager()
    @Published var notifications: [SessionNotification] = []
    @Published var unreadCount: Int = 0
    @Published var history: [SessionNotification] = []
    private var cancellables = Set<AnyCancellable>()
    private var knownCompletedIds = Set<String>()
    private var knownErrorIds = Set<String>()

    /// Number of tabs currently waiting for user input
    var pendingApprovalCount: Int {
        SessionManager.shared.userVisibleTabs.filter { $0.pendingApproval != nil }.count
    }

    /// Total badge count: unread notifications + pending approvals
    var badgeCount: Int {
        unreadCount + pendingApprovalCount
    }

    func markAllRead() {
        unreadCount = 0
    }

    /// Navigate to the most recent unread notification's tab
    func jumpToLatestUnread() -> String? {
        if let latest = notifications.last(where: { $0.tabId != nil }) {
            dismiss(latest)
            return latest.tabId
        }
        // Fallback: find first tab with pending approval
        return SessionManager.shared.userVisibleTabs.first(where: { $0.pendingApproval != nil })?.id
    }

    private init() {
        // 세션 완료 감지
        NotificationCenter.default.publisher(for: .dofficeTabCycleCompleted)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notif in
                let tabId = notif.userInfo?["tabId"] as? String
                    ?? (notif.object as? TerminalTab)?.id
                guard let tabId else { return }
                self?.handleCompletion(tabId: tabId)
            }
            .store(in: &cancellables)
    }

    func post(_ notification: SessionNotification) {
        notifications.append(notification)
        history.append(notification)
        unreadCount += 1
        // Keep history manageable
        if history.count > 100 { history.removeFirst(history.count - 100) }
        // 5초 후 자동 제거
        let id = notification.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.notifications.removeAll { $0.id == id }
        }
    }

    func dismiss(_ notification: SessionNotification) {
        notifications.removeAll { $0.id == notification.id }
    }

    func postCompletion(tabName: String, tabId: String) {
        guard !knownCompletedIds.contains(tabId) else { return }
        knownCompletedIds.insert(tabId)
        pruneKnownIdsIfNeeded()
        post(SessionNotification(
            title: String(format: NSLocalizedString("overlay.notif.completed", comment: ""), tabName),
            detail: NSLocalizedString("overlay.notif.task.done", comment: ""),
            symbol: "checkmark.circle.fill",
            tint: Theme.green,
            tabId: tabId
        ))
    }

    func postError(tabName: String, tabId: String, message: String) {
        guard !knownErrorIds.contains(tabId) else { return }
        knownErrorIds.insert(tabId)
        pruneKnownIdsIfNeeded()
        post(SessionNotification(
            title: String(format: NSLocalizedString("overlay.notif.error", comment: ""), tabName),
            detail: message,
            symbol: "exclamationmark.triangle.fill",
            tint: Theme.red,
            tabId: tabId
        ))
    }

    func postApprovalNeeded(tabName: String, tabId: String, toolName: String) {
        post(SessionNotification(
            title: String(format: NSLocalizedString("overlay.notif.approval.needed", comment: ""), tabName),
            detail: String(format: NSLocalizedString("overlay.notif.approval.waiting", comment: ""), toolName),
            symbol: "hand.raised.fill",
            tint: Theme.orange,
            tabId: tabId
        ))
    }

    /// 메모리 누수 방지: 알림 ID 셋이 과도하게 커지면 정리
    private func pruneKnownIdsIfNeeded() {
        let maxSize = 500
        if knownCompletedIds.count > maxSize {
            // 현재 존재하는 탭 ID만 유지
            let activeIds = Set(SessionManager.shared.tabs.map(\.id))
            knownCompletedIds = knownCompletedIds.intersection(activeIds)
        }
        if knownErrorIds.count > maxSize {
            let activeIds = Set(SessionManager.shared.tabs.map(\.id))
            knownErrorIds = knownErrorIds.intersection(activeIds)
        }
    }

    private func handleCompletion(tabId: String) {
        let tab = SessionManager.shared.tabs.first { $0.id == tabId }
        guard let tab else { return }
        // 자동화 탭은 알림 제외 (사용자 직접 세션만)
        guard tab.automationSourceTabId == nil else { return }
        let name = tab.workerName.isEmpty ? tab.projectName : tab.workerName
        postCompletion(tabName: name, tabId: tabId)
    }
}

struct SessionNotificationBannerStack: View {
    @ObservedObject var notificationManager = SessionNotificationManager.shared
    @ObservedObject private var settings = AppSettings.shared
    var onTapNotification: ((String) -> Void)?

    var body: some View {
        VStack(spacing: 6) {
            ForEach(notificationManager.notifications.suffix(3)) { notif in
                notificationBanner(notif)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .opacity
                    ))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: notificationManager.notifications.map(\.id))
    }

    private func notificationBanner(_ notif: SessionNotification) -> some View {
        HStack(spacing: 10) {
            Image(systemName: notif.symbol)
                .font(.system(size: Theme.iconSize(14)))
                .foregroundColor(notif.tint)

            VStack(alignment: .leading, spacing: 2) {
                Text(notif.title)
                    .font(Theme.mono(10, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(1)
                Text(notif.detail)
                    .font(Theme.mono(8))
                    .foregroundColor(Theme.textDim)
                    .lineLimit(1)
            }

            Spacer()

            Button(action: { notificationManager.dismiss(notif) }) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(Theme.textDim)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Theme.bgCard.opacity(0.95))
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(notif.tint.opacity(0.3), lineWidth: 1))
        .onTapGesture {
            if let tabId = notif.tabId {
                onTapNotification?(tabId)
            }
            notificationManager.dismiss(notif)
        }
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - Preset Color Helper
// ═══════════════════════════════════════════════════════

extension CustomSessionPreset {
    var tintColor: Color {
        switch tint {
        case "purple": return Theme.purple
        case "orange": return Theme.orange
        case "cyan": return Theme.cyan
        case "green": return Theme.green
        case "red": return Theme.red
        default: return Theme.accent
        }
    }
}
