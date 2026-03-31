import SwiftUI
import Combine
import DesignSystem

// ═══════════════════════════════════════════════════════
// MARK: - Terminal Area
// ═══════════════════════════════════════════════════════

public struct TerminalAreaView: View {
    @EnvironmentObject var manager: SessionManager
    @StateObject private var settings = AppSettings.shared
    @State private var viewMode: ViewMode = .grid
    public enum ViewMode { case grid, single, git, history, browser }

    public init() {}

    /// Pre-computed counts of tabs sharing the same projectPath (avoids O(n²) filter inside ForEach)
    private var projectPathCounts: [String: Int] {
        Dictionary(grouping: manager.userVisibleTabs, by: \.projectPath).mapValues(\.count)
    }

    public var body: some View {
        VStack(spacing: 0) {
            topBar
            switch viewMode {
            case .grid: GridPanelView()
            case .single:
                if let tab = manager.activeTab { EventStreamView(tab: tab, compact: false) }
                else { EmptySessionView() }
            case .git: GitPanelView()
            case .history: HistoryPanelView()
            case .browser: BrowserPanelView()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .dofficeToggleBrowser)) { _ in
            withAnimation(.easeInOut(duration: 0.15)) { viewMode = .browser }
        }
    }

    private var topBar: some View {
        HStack(spacing: 0) {
            HStack(spacing: 2) {
                modeBtn("square.grid.2x2", .grid); modeBtn("rectangle", .single)
                Rectangle().fill(Theme.border).frame(width: 1, height: 14)
                modeBtn("arrow.triangle.branch", .git)
                modeBtn("clock.arrow.circlepath", .history)
                modeBtn("globe", .browser)
            }.padding(.horizontal, 8)
            Rectangle().fill(Theme.border).frame(width: 1, height: 18)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 3) {
                    if viewMode == .grid {
                        // Grid mode: show tabs for shift-click multi-select
                        ForEach(manager.userVisibleTabs) { t in gridTabBtn(t) }
                        if !manager.pinnedTabIds.isEmpty {
                            Rectangle().fill(Theme.border).frame(width: 1, height: 14)
                            Button(action: { manager.clearPinnedTabs() }) {
                                HStack(spacing: 3) {
                                    Image(systemName: "xmark.circle.fill").font(.system(size: 8))
                                    Text(NSLocalizedString("terminal.deselect", comment: "")).font(Theme.chrome(8))
                                }
                                .foregroundColor(Theme.textDim)
                                .padding(.horizontal, 6).padding(.vertical, 3)
                            }.buttonStyle(.plain)
                        }
                    }
                    if viewMode == .single || viewMode == .git || viewMode == .history { ForEach(manager.userVisibleTabs) { t in singleTabBtn(t) } }
                }.padding(.horizontal, 6)
            }
            Spacer(minLength: 0)
            Button(action: { manager.showNewTabSheet = true }) {
                Image(systemName: "plus").font(Theme.scaled(10, weight: .medium)).foregroundColor(Theme.textDim).frame(width: 28, height: 28)
            }.buttonStyle(.plain).padding(.trailing, 6)
        }
        .frame(height: 34).background(Theme.bgCard)
        .overlay(Rectangle().fill(Theme.border).frame(height: 1), alignment: .bottom)
    }

    private func modeBtn(_ icon: String, _ mode: ViewMode) -> some View {
        let label: String = {
            switch mode {
            case .grid: return "Grid"
            case .single: return "Single"
            case .git: return "Git"
            case .history: return NSLocalizedString("terminal.mode.history", comment: "")
            case .browser: return "Browser"
            }
        }()
        let selected = viewMode == mode
        return Button(action: { withAnimation(.easeInOut(duration: 0.2)) { viewMode = mode } }) {
            HStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: Theme.iconSize(9)))
                Text(label).font(Theme.chrome(8, weight: selected ? .bold : .regular))
            }
            .foregroundColor(selected ? Theme.accent : Theme.textDim).padding(.horizontal, Theme.sp2 - 2).padding(.vertical, Theme.sp1)
            .background(RoundedRectangle(cornerRadius: Theme.cornerSmall).fill(selected ? Theme.accent.opacity(0.12) : .clear))
        }.buttonStyle(.plain)
    }
    private func singleTabBtn(_ t: TerminalTab) -> some View {
        let a = manager.activeTabId == t.id
        let status = t.statusPresentation
        let needsInput = t.pendingApproval != nil
        let dotColor: Color = {
            if needsInput { return Color.blue }
            switch status.category {
            case .processing: return status.tint
            case .attention: return Theme.red
            case .completed: return Theme.green
            case .active, .idle: return t.workerColor
            }
        }()
        return Button(action: { manager.selectTab(t.id) }) {
            HStack(spacing: 4) {
                ZStack {
                    Circle().fill(dotColor).frame(width: 5, height: 5)
                    if needsInput {
                        AgentRingView(color: .blue, size: 12)
                    }
                }
                .frame(width: 12, height: 12)
                Text(t.projectName).font(Theme.chrome(10)).foregroundColor(a ? Theme.textPrimary : Theme.textSecondary).lineLimit(1)
                if (projectPathCounts[t.projectPath] ?? 0) > 1 {
                    Text(t.workerName).font(Theme.chrome(9)).foregroundColor(t.workerColor)
                }
                if needsInput {
                    Text(NSLocalizedString("terminal.waiting", comment: ""))
                        .font(Theme.mono(7, weight: .bold))
                        .foregroundColor(.blue)
                        .padding(.horizontal, 4).padding(.vertical, 1)
                        .background(Capsule().fill(Color.blue.opacity(0.15)))
                }
            }.padding(.horizontal, Theme.sp2).padding(.vertical, Theme.sp1)
            .background(
                RoundedRectangle(cornerRadius: Theme.cornerSmall)
                    .fill(needsInput ? Color.blue.opacity(0.08) : (a ? Theme.bgSelected : .clear))
            )
            .overlay(
                needsInput ?
                    RoundedRectangle(cornerRadius: Theme.cornerSmall)
                        .stroke(Color.blue.opacity(0.4), lineWidth: 1.5)
                : nil
            )
        }.buttonStyle(.plain)
    }

    private func gridTabBtn(_ t: TerminalTab) -> some View {
        let isPinned = manager.pinnedTabIds.contains(t.id)
        return Button(action: {
            // Shift+클릭은 onTapGesture로 감지할 수 없으므로
            // 그리드 모드에서는 항상 토글 동작
            withAnimation(.easeInOut(duration: 0.15)) {
                manager.togglePinTab(t.id)
            }
        }) {
            HStack(spacing: 4) {
                if isPinned {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(Theme.accentBackground)
                } else {
                    Circle().fill(t.workerColor.opacity(0.5)).frame(width: 5, height: 5)
                }
                Text(t.projectName).font(Theme.chrome(10)).foregroundColor(isPinned ? Theme.textPrimary : Theme.textSecondary).lineLimit(1)
                if (projectPathCounts[t.projectPath] ?? 0) > 1 {
                    Text(t.workerName).font(Theme.chrome(9)).foregroundColor(t.workerColor)
                }
            }
            .padding(.horizontal, Theme.sp2).padding(.vertical, Theme.sp1)
            .background(RoundedRectangle(cornerRadius: Theme.cornerSmall).fill(isPinned ? Theme.accent.opacity(0.12) : .clear)
                .overlay(RoundedRectangle(cornerRadius: Theme.cornerSmall).stroke(isPinned ? Theme.accent.opacity(0.3) : .clear, lineWidth: 1)))
        }.buttonStyle(.plain)
        .help(NSLocalizedString("terminal.help.grid.toggle", comment: ""))
    }
}


// ═══════════════════════════════════════════════════════
// MARK: - Agent Notification Ring
// ═══════════════════════════════════════════════════════

/// Pulsing ring that indicates an AI agent is waiting for user input.
/// Inspired by cmux's blue ring notification system.
public struct AgentRingView: View {
    public let color: Color
    public let size: CGFloat
    @State private var isPulsing = false

    public var body: some View {
        ZStack {
            // Outer pulse ring
            Circle()
                .stroke(color.opacity(isPulsing ? 0.0 : 0.6), lineWidth: 1.5)
                .frame(width: size * (isPulsing ? 1.8 : 1.0), height: size * (isPulsing ? 1.8 : 1.0))
                .scaleEffect(isPulsing ? 1.3 : 1.0)
                .opacity(isPulsing ? 0 : 0.8)

            // Inner steady ring
            Circle()
                .stroke(color.opacity(0.8), lineWidth: 1.5)
                .frame(width: size, height: size)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: false)) {
                isPulsing = true
            }
        }
    }
}

/// Blue glow border overlay for terminal panes when agent needs input
public struct AgentWaitingOverlay: View {
    public let isWaiting: Bool
    @State private var glowPhase: CGFloat = 0

    public var body: some View {
        if isWaiting {
            RoundedRectangle(cornerRadius: 6)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            Color.blue.opacity(0.8),
                            Color.blue.opacity(0.2),
                            Color.cyan.opacity(0.6),
                            Color.blue.opacity(0.2),
                            Color.blue.opacity(0.8)
                        ]),
                        center: .center,
                        startAngle: .degrees(glowPhase),
                        endAngle: .degrees(glowPhase + 360)
                    ),
                    lineWidth: 2.5
                )
                .shadow(color: Color.blue.opacity(0.4), radius: 6)
                .onAppear {
                    withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                        glowPhase = 360
                    }
                }
        }
    }
}

/// Notification badge with unread count
public struct NotificationBadge: View {
    public let count: Int

    public var body: some View {
        if count > 0 {
            Text(count > 99 ? "99+" : "\(count)")
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .padding(.horizontal, count > 9 ? 4 : 3)
                .padding(.vertical, 1)
                .background(Capsule().fill(Color.blue))
                .fixedSize()
        }
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - History Panel View (프롬프트 히스토리)
// ═══════════════════════════════════════════════════════

public struct HistoryPanelView: View {
    @EnvironmentObject var manager: SessionManager

    private var activeTab: TerminalTab? { manager.activeTab }

    public init() {}

    public var body: some View {
        if let tab = activeTab {
            HistoryListView(tab: tab)
        } else {
            EmptySessionView()
        }
    }
}

struct HistoryListView: View {
    @ObservedObject var tab: TerminalTab
    @State private var expandedEntryId: UUID?
    @State private var loadedDiffs: [UUID: String] = [:]
    @State private var revertTargetId: UUID?
    @State private var showRevertAlert = false
    @State private var historyCount: Int = 0
    private let refreshTimer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            HStack(spacing: 8) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: Theme.iconSize(12), weight: .bold))
                    .foregroundColor(Theme.accent)
                Text(NSLocalizedString("terminal.mode.history", comment: ""))
                    .font(Theme.mono(12, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                Text("\(tab.promptHistory.count)")
                    .font(Theme.mono(10, weight: .bold))
                    .foregroundColor(Theme.accent)
                    .padding(.horizontal, 5).padding(.vertical, 1)
                    .background(Theme.accent.opacity(0.12))
                    .cornerRadius(3)
                Spacer()
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(Theme.bgCard)
            .overlay(Rectangle().fill(Theme.border).frame(height: 1), alignment: .bottom)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    if tab.promptHistory.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 32))
                                .foregroundColor(Theme.textDim.opacity(0.4))
                            Text(NSLocalizedString("history.empty", comment: ""))
                                .font(Theme.mono(11))
                                .foregroundColor(Theme.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                    } else {
                        let reversed = Array(tab.promptHistory.reversed())
                        ForEach(Array(reversed.enumerated()), id: \.element.id) { displayIndex, entry in
                            historyEntryRow(entry: entry, isLast: displayIndex == reversed.count - 1)
                        }
                    }
                }
                .padding(12)
            }
            .background(Theme.bg)
        }
        .alert(NSLocalizedString("history.revert.confirm.title", comment: ""), isPresented: $showRevertAlert) {
            Button(NSLocalizedString("cancel", comment: ""), role: .cancel) {}
            Button(NSLocalizedString("history.revert.action", comment: ""), role: .destructive) {
                if let targetId = revertTargetId,
                   let entry = tab.promptHistory.first(where: { $0.id == targetId }) {
                    tab.revertToBeforePrompt(entry)
                }
            }
        } message: {
            Text(NSLocalizedString("history.revert.confirm.message", comment: ""))
        }
        .onReceive(refreshTimer) { _ in
            // promptHistory는 @Published가 아니므로 수동으로 갱신 감지
            if tab.promptHistory.count != historyCount {
                historyCount = tab.promptHistory.count
            }
        }
        .onAppear { historyCount = tab.promptHistory.count }
    }

    private func historyEntryRow(entry: PromptHistoryEntry, isLast: Bool) -> some View {
        let isExpanded = expandedEntryId == entry.id
        let fileCount = entry.fileChanges.filter { $0.action == "Write" || $0.action == "Edit" }.count

        return VStack(alignment: .leading, spacing: 0) {
            // 메인 행
            HStack(spacing: 8) {
                // 타임라인 인디케이터
                VStack(spacing: 0) {
                    Circle()
                        .fill(entry.isCompleted ? Theme.green : Theme.yellow)
                        .frame(width: 8, height: 8)
                    if !isLast {
                        Rectangle()
                            .fill(Theme.border)
                            .frame(width: 1)
                            .frame(maxHeight: .infinity)
                    }
                }
                .frame(width: 12)

                VStack(alignment: .leading, spacing: 4) {
                    // 시간 + 파일 수
                    HStack(spacing: 6) {
                        Text(relativeTime(entry.timestamp))
                            .font(Theme.chrome(8))
                            .foregroundColor(Theme.textDim)
                        if fileCount > 0 {
                            HStack(spacing: 2) {
                                Image(systemName: "doc.fill")
                                    .font(.system(size: 7))
                                Text(String(format: NSLocalizedString("history.files.changed", comment: ""), fileCount))
                                    .font(Theme.chrome(8, weight: .medium))
                            }
                            .foregroundColor(Theme.cyan)
                        }
                        if let hash = entry.gitCommitHashBefore {
                            Text(String(hash.prefix(7)))
                                .font(Theme.mono(8))
                                .foregroundColor(Theme.textDim)
                        }
                        Spacer()
                    }

                    // 프롬프트 텍스트
                    Text(entry.promptText)
                        .font(Theme.mono(10))
                        .foregroundColor(Theme.textPrimary)
                        .lineLimit(isExpanded ? nil : 2)
                }

                Spacer()

                // 액션 버튼
                HStack(spacing: 4) {
                    if fileCount > 0 {
                        Button(action: { toggleExpand(entry) }) {
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(Theme.textDim)
                                .frame(width: 24, height: 24)
                                .background(RoundedRectangle(cornerRadius: 4).fill(Theme.bgSurface))
                        }
                        .buttonStyle(.plain)
                        .help(isExpanded ? NSLocalizedString("history.collapse", comment: "") : NSLocalizedString("history.expand", comment: ""))
                    }

                    if entry.gitCommitHashBefore != nil && fileCount > 0 {
                        Button(action: {
                            revertTargetId = entry.id
                            showRevertAlert = true
                        }) {
                            Image(systemName: "arrow.uturn.backward")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(Theme.orange)
                                .frame(width: 24, height: 24)
                                .background(RoundedRectangle(cornerRadius: 4).fill(Theme.orange.opacity(0.1)))
                        }
                        .buttonStyle(.plain)
                        .help(NSLocalizedString("history.revert.confirm.title", comment: ""))
                    }
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 8)

            // 확장된 diff 뷰
            if isExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(entry.fileChanges.filter { $0.action == "Write" || $0.action == "Edit" }, id: \.id) { file in
                        HStack(spacing: 4) {
                            Image(systemName: file.action == "Write" ? "plus.circle.fill" : "pencil.circle.fill")
                                .font(.system(size: 9))
                                .foregroundColor(file.action == "Write" ? Theme.green : Theme.yellow)
                            Text(file.fileName)
                                .font(Theme.mono(9))
                                .foregroundColor(Theme.textSecondary)
                            Spacer()
                            Text(file.action)
                                .font(Theme.chrome(7, weight: .medium))
                                .foregroundColor(Theme.textDim)
                        }
                    }

                    if let diff = loadedDiffs[entry.id] {
                        ScrollView(.horizontal, showsIndicators: true) {
                            Text(diff)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(Theme.textSecondary)
                                .textSelection(.enabled)
                        }
                        .frame(maxHeight: 300)
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Theme.bgTerminal))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.border, lineWidth: 1))
                    } else {
                        HStack(spacing: 6) {
                            ProgressView().scaleEffect(0.5)
                            Text(NSLocalizedString("history.expand", comment: ""))
                                .font(Theme.chrome(9))
                                .foregroundColor(Theme.textDim)
                        }
                    }
                }
                .padding(.horizontal, 30).padding(.bottom, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(RoundedRectangle(cornerRadius: 8).fill(Theme.bgCard))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border, lineWidth: 1))
    }

    private func toggleExpand(_ entry: PromptHistoryEntry) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if expandedEntryId == entry.id {
                expandedEntryId = nil
            } else {
                expandedEntryId = entry.id
                if loadedDiffs[entry.id] == nil {
                    DispatchQueue.global(qos: .userInitiated).async {
                        let diff = tab.loadDiffForHistoryEntry(entry)
                        DispatchQueue.main.async {
                            loadedDiffs[entry.id] = diff
                        }
                    }
                }
            }
        }
    }

    private func relativeTime(_ date: Date) -> String {
        let interval = Int(Date().timeIntervalSince(date))
        if interval < 60 { return NSLocalizedString("history.just.now", comment: "") }
        if interval < 3600 { return "\(interval / 60)m ago" }
        if interval < 86400 { return "\(interval / 3600)h ago" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter.string(from: date)
    }
}


// ═══════════════════════════════════════════════════════
// MARK: - Event Stream View
// ═══════════════════════════════════════════════════════

public struct EventStreamView: View {
    @EnvironmentObject var manager: SessionManager
    @ObservedObject var tab: TerminalTab
    @StateObject private var settings = AppSettings.shared
    public let compact: Bool
    @State private var inputText = ""
    @State private var pastedChunks: [(id: Int, text: String)] = []
    @State private var pasteCounter: Int = 0
    @FocusState private var isFocused: Bool
    @State private var autoScroll = true
    @State private var lastBlockCount = 0
    @State private var blockFilter = BlockFilter()
    @State private var showFilterBar = false
    @State private var showFilePanel = false
    @State private var elapsedSeconds: Int = 0
    @State private var selectedCommandIndex: Int = 0
    @State private var planSelectionDraft: [String: String] = [:]
    @State private var planSelectionSignature: String = ""
    @State private var sentPlanSignatures: Set<String> = []
    @State private var scrollWorkItem: DispatchWorkItem?
    @State private var showSleepWorkSetup = false
    @State private var unavailableProviderAlert: AgentProvider?
    public let elapsedTimer = Timer.publish(every: 3, on: .main, in: .common).autoconnect()

    // ═══════════════════════════════════════════
    // MARK: - Slash Commands
    // ═══════════════════════════════════════════

    private struct SlashCommand {
        let name: String
        let description: String
        let usage: String
        let category: String
        let action: (TerminalTab, SessionManager, [String]) -> Void

        public init(_ name: String, _ desc: String, usage: String = "", category: String = NSLocalizedString("slash.category.general", comment: ""), action: @escaping (TerminalTab, SessionManager, [String]) -> Void) {
            self.name = name; self.description = desc; self.usage = usage; self.category = category; self.action = action
        }
    }

    private static let allSlashCommands: [SlashCommand] = [
        // ── 일반 ──
        SlashCommand("help", NSLocalizedString("slash.cmd.help", comment: ""), category: NSLocalizedString("slash.category.general", comment: "")) { tab, _, args in
            let cmds = EventStreamView.allSlashCommands
            if let query = args.first?.lowercased() {
                let filtered = cmds.filter { $0.name.contains(query) || $0.description.contains(query) }
                if filtered.isEmpty { tab.appendBlock(.status(message: String(format: NSLocalizedString("terminal.cmd.not.found", comment: ""), query))); return }
                let lines = filtered.map { "/\($0.name)\($0.usage.isEmpty ? "" : " \($0.usage)") — \($0.description)" }
                tab.appendBlock(.status(message: NSLocalizedString("terminal.search.result", comment: "") + lines.joined(separator: "\n")))
            } else {
                var grouped: [String: [SlashCommand]] = [:]
                for c in cmds { grouped[c.category, default: []].append(c) }
                let order = [NSLocalizedString("slash.category.general", comment: ""), NSLocalizedString("slash.category.model", comment: ""), NSLocalizedString("slash.category.session", comment: ""), NSLocalizedString("slash.category.display", comment: ""), "Git", NSLocalizedString("slash.category.tools", comment: "")]
                var text = "📜 " + NSLocalizedString("help.command.list", comment: "") + "\n"
                for cat in order {
                    guard let list = grouped[cat] else { continue }
                    text += "\n[\(cat)]\n"
                    for c in list { text += "  /\(c.name)\(c.usage.isEmpty ? "" : " \(c.usage)") — \(c.description)\n" }
                }
                tab.appendBlock(.status(message: text))
            }
        },
        SlashCommand("clear", NSLocalizedString("slash.cmd.clear", comment: ""), category: NSLocalizedString("slash.category.general", comment: "")) { tab, _, _ in
            tab.clearBlocks()
            tab.appendBlock(.status(message: NSLocalizedString("terminal.log.cleared", comment: "")))
        },
        SlashCommand("cancel", NSLocalizedString("slash.cmd.cancel", comment: ""), category: NSLocalizedString("slash.category.general", comment: "")) { tab, _, _ in
            if tab.isProcessing { tab.cancelProcessing() }
            else { tab.appendBlock(.status(message: NSLocalizedString("terminal.no.running.task", comment: ""))) }
        },
        SlashCommand("stop", NSLocalizedString("slash.cmd.stop", comment: ""), category: NSLocalizedString("slash.category.general", comment: "")) { tab, _, _ in
            if tab.isProcessing || tab.isRunning { tab.forceStop() }
            else { tab.appendBlock(.status(message: NSLocalizedString("terminal.no.running.task", comment: ""))) }
        },
        SlashCommand("copy", NSLocalizedString("slash.cmd.copy", comment: ""), category: NSLocalizedString("slash.category.general", comment: "")) { tab, _, _ in
            if let last = tab.blocks.last(where: { if case .thought = $0.blockType { return true }; if case .completion = $0.blockType { return true }; return false }) {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(last.content, forType: .string)
                tab.appendBlock(.status(message: String(format: NSLocalizedString("terminal.copied.to.clipboard", comment: ""), last.content.count)))
            } else { tab.appendBlock(.status(message: NSLocalizedString("terminal.no.response.to.copy", comment: ""))) }
        },
        SlashCommand("export", NSLocalizedString("slash.cmd.export", comment: ""), category: NSLocalizedString("slash.category.general", comment: "")) { tab, _, _ in
            let text = tab.blocks.map { block -> String in
                let prefix: String
                switch block.blockType {
                case .userPrompt: prefix = "> "
                case .thought: prefix = "💭 "
                case .toolUse(let name, _): prefix = "⏺ [\(name)] "
                case .toolOutput: prefix = "  ⎿ "
                case .toolError: prefix = "  ✗ "
                case .status(let msg): return "ℹ️ \(msg)"
                case .completion: prefix = "✅ "
                case .error(let msg): return "🚨 \(msg)"
                default: prefix = ""
                }
                return prefix + block.content
            }.joined(separator: "\n")
            let dateStr = { let f = DateFormatter(); f.dateFormat = "yyyyMMdd_HHmmss"; return f.string(from: Date()) }()
            let path = "\(tab.projectPath)/doffice_log_\(dateStr).txt"
            do { try text.write(toFile: path, atomically: true, encoding: .utf8)
                tab.appendBlock(.status(message: String(format: NSLocalizedString("terminal.log.saved", comment: ""), path)))
            } catch { tab.appendBlock(.status(message: String(format: NSLocalizedString("terminal.log.save.failed", comment: ""), error.localizedDescription))) }
        },

        // ── 모델/설정 ──
        SlashCommand("model", NSLocalizedString("slash.cmd.model", comment: ""), usage: "<model>", category: NSLocalizedString("slash.category.model", comment: "")) { tab, _, args in
            guard let arg = args.first?.lowercased(),
                  let model = ClaudeModel.allCases.first(where: { $0.rawValue.lowercased().contains(arg) }) else {
                let current = tab.selectedModel
                tab.appendBlock(.status(message: String(format: NSLocalizedString("terminal.model.current", comment: ""), current.icon, current.rawValue)))
                return
            }
            tab.selectedModel = model
            tab.appendBlock(.status(message: String(format: NSLocalizedString("terminal.model.changed", comment: ""), model.icon, model.rawValue)))
        },
        SlashCommand("effort", NSLocalizedString("slash.cmd.effort", comment: ""), usage: "<low|medium|high|max>", category: NSLocalizedString("slash.category.model", comment: "")) { tab, _, args in
            guard let arg = args.first?.lowercased(),
                  let effort = EffortLevel.allCases.first(where: { $0.rawValue.lowercased() == arg }) else {
                let current = tab.effortLevel
                tab.appendBlock(.status(message: String(format: NSLocalizedString("terminal.effort.current", comment: ""), current.icon, current.rawValue)))
                return
            }
            tab.effortLevel = effort
            tab.appendBlock(.status(message: String(format: NSLocalizedString("slash.status.effort.changed", comment: ""), effort.icon, effort.rawValue)))
        },
        SlashCommand("output", NSLocalizedString("slash.cmd.output", comment: ""), usage: "<full|realtime|result>", category: NSLocalizedString("slash.category.model", comment: "")) { tab, _, args in
            guard let arg = args.first?.lowercased() else {
                tab.appendBlock(.status(message: String(format: NSLocalizedString("slash.status.output.current", comment: ""), tab.outputMode.icon, tab.outputMode.displayName)))
                return
            }
            let modeMap: [String: OutputMode] = ["full": .full, "전체": .full, "realtime": .realtime, "실시간": .realtime, "result": .resultOnly, "결과만": .resultOnly, "결과": .resultOnly]
            guard let mode = modeMap[arg] else { tab.appendBlock(.status(message: String(format: NSLocalizedString("slash.status.output.unknown", comment: ""), arg))); return }
            tab.outputMode = mode
            tab.appendBlock(.status(message: String(format: NSLocalizedString("slash.status.output.changed", comment: ""), mode.icon, mode.rawValue)))
        },
        SlashCommand("permission", NSLocalizedString("slash.cmd.permission", comment: ""), usage: "<bypass|auto|default|plan|edits>", category: NSLocalizedString("slash.category.model", comment: "")) { tab, _, args in
            guard let arg = args.first?.lowercased() else {
                let c = tab.permissionMode
                tab.appendBlock(.status(message: String(format: NSLocalizedString("slash.status.permission.current", comment: ""), c.icon, c.displayName, c.desc)))
                return
            }
            let map: [String: PermissionMode] = ["bypass": .bypassPermissions, "auto": .auto, "default": .defaultMode, "plan": .plan, "edits": .acceptEdits, "edit": .acceptEdits]
            guard let mode = map[arg] else { tab.appendBlock(.status(message: String(format: NSLocalizedString("slash.status.permission.unknown", comment: ""), arg))); return }
            tab.permissionMode = mode
            tab.appendBlock(.status(message: String(format: NSLocalizedString("slash.status.permission.changed", comment: ""), mode.icon, mode.displayName, mode.desc)))
        },
        SlashCommand("budget", NSLocalizedString("slash.cmd.budget", comment: ""), usage: "<금액|off>", category: NSLocalizedString("slash.category.model", comment: "")) { tab, _, args in
            guard let arg = args.first else {
                let b = tab.maxBudgetUSD
                tab.appendBlock(.status(message: String(format: NSLocalizedString("slash.status.budget.current", comment: ""), b > 0 ? "$\(String(format: "%.2f", b))" : NSLocalizedString("slash.status.budget.unlimited", comment: ""))))
                return
            }
            if arg == "off" || arg == "0" { tab.maxBudgetUSD = 0; tab.appendBlock(.status(message: NSLocalizedString("slash.status.budget.removed", comment: ""))); return }
            guard let v = Double(arg), v > 0 else { tab.appendBlock(.status(message: NSLocalizedString("slash.status.budget.invalid", comment: ""))); return }
            tab.maxBudgetUSD = v
            tab.appendBlock(.status(message: String(format: NSLocalizedString("slash.status.budget.set", comment: ""), String(format: "%.2f", v))))
        },
        SlashCommand("system", NSLocalizedString("slash.cmd.system", comment: ""), usage: "<프롬프트|clear>", category: NSLocalizedString("slash.category.model", comment: "")) { tab, _, args in
            let text = args.joined(separator: " ")
            if text.isEmpty || text == "show" {
                let s = tab.systemPrompt.isEmpty ? NSLocalizedString("slash.status.system.none", comment: "") : tab.systemPrompt
                tab.appendBlock(.status(message: String(format: NSLocalizedString("slash.status.system.current", comment: ""), s)))
            } else if text == "clear" {
                tab.systemPrompt = ""
                tab.appendBlock(.status(message: NSLocalizedString("slash.status.system.cleared", comment: "")))
            } else {
                tab.systemPrompt = text
                tab.appendBlock(.status(message: String(format: NSLocalizedString("slash.status.system.set", comment: ""), text)))
            }
        },
        SlashCommand("worktree", NSLocalizedString("slash.cmd.worktree", comment: ""), category: NSLocalizedString("slash.category.model", comment: "")) { tab, _, _ in
            tab.useWorktree.toggle()
            tab.appendBlock(.status(message: String(format: NSLocalizedString("slash.status.worktree.toggle", comment: ""), tab.useWorktree ? NSLocalizedString("slash.toggle.on", comment: "") : NSLocalizedString("slash.toggle.off", comment: ""))))
        },
        SlashCommand("chrome", NSLocalizedString("slash.cmd.chrome", comment: ""), category: NSLocalizedString("slash.category.model", comment: "")) { tab, _, _ in
            tab.enableChrome.toggle()
            tab.appendBlock(.status(message: String(format: NSLocalizedString("slash.status.chrome.toggle", comment: ""), tab.enableChrome ? NSLocalizedString("slash.toggle.on", comment: "") : NSLocalizedString("slash.toggle.off", comment: ""))))
        },
        SlashCommand("brief", NSLocalizedString("slash.cmd.brief", comment: ""), category: NSLocalizedString("slash.category.model", comment: "")) { tab, _, _ in
            tab.enableBrief.toggle()
            tab.appendBlock(.status(message: String(format: NSLocalizedString("slash.status.brief.toggle", comment: ""), tab.enableBrief ? NSLocalizedString("slash.toggle.on", comment: "") : NSLocalizedString("slash.toggle.off", comment: ""))))
        },

        // ── 세션 ──
        SlashCommand("stats", NSLocalizedString("slash.cmd.stats", comment: ""), category: NSLocalizedString("slash.category.session", comment: "")) { tab, _, _ in
            let elapsed = Int(Date().timeIntervalSince(tab.startTime))
            let mins = elapsed / 60; let secs = elapsed % 60
            let stats = [
                NSLocalizedString("slash.status.stats.title", comment: ""),
                String(format: NSLocalizedString("slash.status.stats.worker", comment: ""), tab.workerName, tab.projectName),
                String(format: NSLocalizedString("slash.status.stats.model", comment: ""), tab.selectedModel.icon, tab.selectedModel.rawValue, tab.effortLevel.icon, tab.effortLevel.rawValue),
                String(format: NSLocalizedString("slash.status.stats.elapsed", comment: ""), mins, secs),
                String(format: NSLocalizedString("slash.status.stats.tokens", comment: ""), "\(tab.tokensUsed)", "\(tab.inputTokensUsed)", "\(tab.outputTokensUsed)"),
                String(format: NSLocalizedString("slash.status.stats.cost", comment: ""), String(format: "%.4f", tab.totalCost)),
                String(format: NSLocalizedString("slash.status.stats.prompts", comment: ""), tab.completedPromptCount),
                String(format: NSLocalizedString("slash.status.stats.commands", comment: ""), tab.commandCount, tab.errorCount),
                String(format: NSLocalizedString("slash.status.stats.blocks", comment: ""), tab.blocks.count),
                String(format: NSLocalizedString("slash.status.stats.files", comment: ""), tab.fileChanges.count),
            ].joined(separator: "\n")
            tab.appendBlock(.status(message: stats))
        },
        SlashCommand("restart", NSLocalizedString("slash.cmd.restart", comment: ""), category: NSLocalizedString("slash.category.session", comment: "")) { tab, _, _ in
            if tab.isProcessing { tab.cancelProcessing() }
            tab.clearBlocks()
            tab.claudeActivity = .idle
            tab.start()
        },
        SlashCommand("continue", NSLocalizedString("slash.cmd.continue", comment: ""), category: NSLocalizedString("slash.category.session", comment: "")) { tab, _, _ in
            tab.continueSession = true
            tab.appendBlock(.status(message: NSLocalizedString("slash.status.continue", comment: "")))
        },
        SlashCommand("resume", NSLocalizedString("slash.cmd.resume", comment: ""), category: NSLocalizedString("slash.category.session", comment: "")) { tab, _, _ in
            tab.continueSession = true
            tab.appendBlock(.status(message: NSLocalizedString("slash.status.resume", comment: "")))
        },
        SlashCommand("fork", NSLocalizedString("slash.cmd.fork", comment: ""), category: NSLocalizedString("slash.category.session", comment: "")) { tab, _, _ in
            tab.forkSession = true
            tab.appendBlock(.status(message: NSLocalizedString("slash.status.fork", comment: "")))
        },

        // ── 화면 ──
        SlashCommand("scroll", NSLocalizedString("slash.cmd.scroll", comment: ""), category: NSLocalizedString("slash.category.display", comment: "")) { tab, _, _ in
            tab.appendBlock(.status(message: NSLocalizedString("slash.status.scroll.tip", comment: "")))
        },
        SlashCommand("errors", NSLocalizedString("slash.cmd.errors", comment: ""), category: NSLocalizedString("slash.category.display", comment: "")) { tab, _, _ in
            let errors = tab.blocks.filter { block in
                if block.isError { return true }
                switch block.blockType {
                case .error: return true
                case .toolError: return true
                default: return false
                }
            }
            if errors.isEmpty { tab.appendBlock(.status(message: NSLocalizedString("slash.status.no.errors", comment: ""))); return }
            let text = errors.enumerated().map { (i, e) in "  \(i+1). \(e.content.prefix(200))" }.joined(separator: "\n")
            tab.appendBlock(.status(message: String(format: NSLocalizedString("slash.status.error.list", comment: ""), errors.count) + "\n\(text)"))
        },
        SlashCommand("files", NSLocalizedString("slash.cmd.files", comment: ""), category: NSLocalizedString("slash.category.display", comment: "")) { tab, _, _ in
            if tab.fileChanges.isEmpty { tab.appendBlock(.status(message: NSLocalizedString("slash.status.no.file.changes", comment: ""))); return }
            let text = tab.fileChanges.map { "  \($0.action == "Write" ? "📝" : "✏️") \($0.path)" }.joined(separator: "\n")
            tab.appendBlock(.status(message: String(format: NSLocalizedString("slash.status.file.list", comment: ""), tab.fileChanges.count) + "\n\(text)"))
        },
        SlashCommand("tokens", NSLocalizedString("slash.cmd.tokens", comment: ""), category: NSLocalizedString("slash.category.display", comment: "")) { tab, _, _ in
            let tracker = TokenTracker.shared
            let text = [
                NSLocalizedString("slash.status.tokens.title", comment: ""),
                String(format: NSLocalizedString("slash.status.tokens.session", comment: ""), tracker.formatTokens(tab.tokensUsed), tracker.formatTokens(tab.inputTokensUsed), tracker.formatTokens(tab.outputTokensUsed)),
                String(format: NSLocalizedString("slash.status.tokens.today", comment: ""), tracker.formatTokens(tracker.todayTokens)),
                String(format: NSLocalizedString("slash.status.tokens.week", comment: ""), tracker.formatTokens(tracker.weekTokens)),
                String(format: NSLocalizedString("slash.status.tokens.cost.session", comment: ""), String(format: "%.4f", tab.totalCost)),
                String(format: NSLocalizedString("slash.status.tokens.cost.today", comment: ""), String(format: "%.4f", tracker.todayCost)),
                String(format: NSLocalizedString("slash.status.tokens.cost.week", comment: ""), String(format: "%.4f", tracker.weekCost)),
            ].joined(separator: "\n")
            tab.appendBlock(.status(message: text))
        },
        SlashCommand("usage", NSLocalizedString("slash.cmd.usage", comment: ""), category: NSLocalizedString("slash.category.display", comment: "")) { tab, _, _ in
            tab.appendBlock(.status(message: NSLocalizedString("slash.status.usage.checking", comment: "")))
            DispatchQueue.global(qos: .userInitiated).async { [weak tab] in
                let result = ClaudeUsageFetcher.fetch()
                DispatchQueue.main.async {
                    guard let tab = tab else { return }
                    // 마지막 "조회 중" 블록 제거
                    if let lastIdx = tab.blocks.indices.last,
                       tab.blocks[lastIdx].content.contains(NSLocalizedString("slash.checking", comment: "")) {
                        tab.blocks.remove(at: lastIdx)
                    }
                    tab.appendBlock(.status(message: result))
                }
            }
        },
        SlashCommand("config", NSLocalizedString("slash.cmd.config", comment: ""), category: NSLocalizedString("slash.category.display", comment: "")) { tab, _, _ in
            var lines = [
                NSLocalizedString("slash.status.config.title", comment: ""),
                String(format: NSLocalizedString("slash.status.config.model", comment: ""), tab.selectedModel.icon, tab.selectedModel.rawValue),
                String(format: NSLocalizedString("slash.status.config.effort", comment: ""), tab.effortLevel.icon, tab.effortLevel.rawValue),
                String(format: NSLocalizedString("slash.status.config.output", comment: ""), tab.outputMode.icon, tab.outputMode.displayName),
                String(format: NSLocalizedString("slash.status.config.permission", comment: ""), tab.permissionMode.icon, tab.permissionMode.displayName),
                String(format: NSLocalizedString("slash.status.config.budget", comment: ""), tab.maxBudgetUSD > 0 ? "$\(String(format: "%.2f", tab.maxBudgetUSD))" : NSLocalizedString("slash.status.budget.unlimited", comment: "")),
                String(format: NSLocalizedString("slash.status.config.worktree", comment: ""), tab.useWorktree ? "✅" : "❌"),
                String(format: NSLocalizedString("slash.status.config.chrome", comment: ""), tab.enableChrome ? "✅" : "❌"),
                String(format: NSLocalizedString("slash.status.config.brief", comment: ""), tab.enableBrief ? "✅" : "❌"),
            ]
            if !tab.systemPrompt.isEmpty { lines.append(String(format: NSLocalizedString("slash.status.config.system", comment: ""), String(tab.systemPrompt.prefix(50)))) }
            if !tab.allowedTools.isEmpty { lines.append(String(format: NSLocalizedString("slash.status.config.allow", comment: ""), tab.allowedTools)) }
            if !tab.disallowedTools.isEmpty { lines.append(String(format: NSLocalizedString("slash.status.config.deny", comment: ""), tab.disallowedTools)) }
            lines.append(String(format: NSLocalizedString("slash.status.config.project", comment: ""), tab.projectPath))
            tab.appendBlock(.status(message: lines.joined(separator: "\n")))
        },

        // ── Git ──
        SlashCommand("git", NSLocalizedString("slash.status.git.desc", comment: ""), category: "Git") { tab, _, _ in
            tab.refreshGitInfo()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let g = tab.gitInfo
                if !g.isGitRepo { tab.appendBlock(.status(message: NSLocalizedString("slash.status.git.not.repo", comment: ""))); return }
                let text = [
                    NSLocalizedString("slash.status.git.title", comment: ""),
                    String(format: NSLocalizedString("slash.status.git.branch", comment: ""), g.branch),
                    String(format: NSLocalizedString("slash.status.git.changed.files", comment: ""), g.changedFiles),
                    String(format: NSLocalizedString("slash.status.git.last.commit", comment: ""), g.lastCommit),
                    String(format: NSLocalizedString("slash.status.git.commit.age", comment: ""), g.lastCommitAge),
                ].joined(separator: "\n")
                tab.appendBlock(.status(message: text))
            }
        },
        SlashCommand("branch", NSLocalizedString("slash.cmd.branch", comment: ""), category: "Git") { tab, _, _ in
            tab.refreshGitInfo()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                tab.appendBlock(.status(message: String(format: NSLocalizedString("slash.status.branch.current", comment: ""), tab.gitInfo.branch.isEmpty ? NSLocalizedString("slash.status.deny.none", comment: "") : tab.gitInfo.branch)))
            }
        },

        // ── 도구 ──
        SlashCommand("allow", NSLocalizedString("slash.cmd.allow", comment: ""), usage: "<tool1,tool2,...|clear>", category: NSLocalizedString("slash.category.tools", comment: "")) { tab, _, args in
            let text = args.joined(separator: " ")
            if text.isEmpty || text == "show" {
                tab.appendBlock(.status(message: String(format: NSLocalizedString("slash.status.allow.current", comment: ""), tab.allowedTools.isEmpty ? NSLocalizedString("slash.status.allow.all", comment: "") : tab.allowedTools)))
            } else if text == "clear" {
                tab.allowedTools = ""
                tab.appendBlock(.status(message: NSLocalizedString("slash.status.allow.cleared", comment: "")))
            } else {
                tab.allowedTools = text
                tab.appendBlock(.status(message: String(format: NSLocalizedString("slash.status.allow.set", comment: ""), text)))
            }
        },
        SlashCommand("deny", NSLocalizedString("slash.cmd.deny", comment: ""), usage: "<tool1,tool2,...|clear>", category: NSLocalizedString("slash.category.tools", comment: "")) { tab, _, args in
            let text = args.joined(separator: " ")
            if text.isEmpty || text == "show" {
                tab.appendBlock(.status(message: String(format: NSLocalizedString("slash.status.deny.current", comment: ""), tab.disallowedTools.isEmpty ? NSLocalizedString("slash.status.deny.none", comment: "") : tab.disallowedTools)))
            } else if text == "clear" {
                tab.disallowedTools = ""
                tab.appendBlock(.status(message: NSLocalizedString("slash.status.deny.cleared", comment: "")))
            } else {
                tab.disallowedTools = text
                tab.appendBlock(.status(message: String(format: NSLocalizedString("slash.status.deny.set", comment: ""), text)))
            }
        },
        SlashCommand("pr", NSLocalizedString("slash.cmd.pr", comment: ""), usage: "<PR번호>", category: NSLocalizedString("slash.category.tools", comment: "")) { tab, _, args in
            guard let num = args.first else {
                tab.appendBlock(.status(message: NSLocalizedString("slash.status.pr.usage", comment: "")))
                return
            }
            tab.fromPR = num
            tab.appendBlock(.status(message: String(format: NSLocalizedString("slash.status.pr.context", comment: ""), num)))
        },
        SlashCommand("name", NSLocalizedString("slash.cmd.name", comment: ""), usage: "<이름>", category: NSLocalizedString("slash.category.session", comment: "")) { tab, _, args in
            let n = args.joined(separator: " ")
            if n.isEmpty { tab.appendBlock(.status(message: String(format: NSLocalizedString("slash.status.name.current", comment: ""), tab.sessionName.isEmpty ? NSLocalizedString("slash.status.deny.none", comment: "") : tab.sessionName))); return }
            tab.sessionName = n
            tab.appendBlock(.status(message: String(format: NSLocalizedString("slash.status.name.set", comment: ""), n)))
        },
        SlashCommand("compare", NSLocalizedString("slash.cmd.compare", comment: ""), usage: "<세션1이름> <세션2이름>", category: NSLocalizedString("slash.category.session", comment: "")) { tab, manager, args in
            let allTabs = manager.userVisibleTabs

            if allTabs.count < 2 {
                tab.appendBlock(.status(message: NSLocalizedString("slash.compare.need.two", comment: "")))
                return
            }

            let tab1: TerminalTab
            let tab2: TerminalTab

            if args.count >= 2 {
                let name1 = args[0].lowercased()
                let name2 = args[1].lowercased()
                guard let t1 = allTabs.first(where: { $0.workerName.lowercased().contains(name1) }),
                      let t2 = allTabs.first(where: { $0.workerName.lowercased().contains(name2) && $0.id != t1.id }) else {
                    tab.appendBlock(.status(message: NSLocalizedString("slash.compare.not.found", comment: "") + allTabs.map(\.workerName).joined(separator: ", ")))
                    return
                }
                tab1 = t1; tab2 = t2
            } else {
                // 인자 없으면 처음 2개 비교
                guard allTabs.count >= 2 else {
                    tab.appendBlock(.status(message: NSLocalizedString("slash.compare.need.two", comment: "")))
                    return
                }
                tab1 = allTabs[0]; tab2 = allTabs[1]
            }

            let dur1 = Int(Date().timeIntervalSince(tab1.startTime))
            let dur2 = Int(Date().timeIntervalSince(tab2.startTime))

            func fmtDur(_ s: Int) -> String {
                if s < 60 { return String(format: NSLocalizedString("slash.status.duration.seconds", comment: ""), s) }
                if s < 3600 { return String(format: NSLocalizedString("slash.status.duration.minutes", comment: ""), s/60, s%60) }
                return String(format: NSLocalizedString("slash.status.duration.hours", comment: ""), s/3600, s%3600/60)
            }

            func fmtTokens(_ n: Int) -> String {
                if n >= 1000 { return String(format: "%.1fK", Double(n)/1000) }
                return "\(n)"
            }

            let cmpProcessing = NSLocalizedString("slash.status.compare.status.processing", comment: "")
            let cmpComplete = NSLocalizedString("slash.status.compare.status.complete", comment: "")
            let cmpWaiting = NSLocalizedString("slash.status.compare.status.waiting", comment: "")
            let lines = [
                NSLocalizedString("slash.status.compare.title", comment: ""),
                "══════════════════════════════════════════════════",
                "",
                String(format: "%-20s │ %-20s │ %-20s", NSLocalizedString("slash.status.compare.header.item", comment: ""), tab1.workerName, tab2.workerName),
                "─────────────────────┼──────────────────────┼──────────────────────",
                String(format: "%-20s │ %-20s │ %-20s", NSLocalizedString("slash.status.compare.header.project", comment: ""), String(tab1.projectName.prefix(18)), String(tab2.projectName.prefix(18))),
                String(format: "%-20s │ %-20s │ %-20s", NSLocalizedString("slash.status.compare.header.status", comment: ""), tab1.isProcessing ? cmpProcessing : (tab1.isCompleted ? cmpComplete : cmpWaiting), tab2.isProcessing ? cmpProcessing : (tab2.isCompleted ? cmpComplete : cmpWaiting)),
                String(format: "%-20s │ %-20s │ %-20s", NSLocalizedString("slash.status.compare.header.model", comment: ""), tab1.selectedModel.rawValue, tab2.selectedModel.rawValue),
                String(format: "%-20s │ %-20s │ %-20s", NSLocalizedString("slash.status.compare.header.tokens.in", comment: ""), fmtTokens(tab1.inputTokensUsed), fmtTokens(tab2.inputTokensUsed)),
                String(format: "%-20s │ %-20s │ %-20s", NSLocalizedString("slash.status.compare.header.tokens.out", comment: ""), fmtTokens(tab1.outputTokensUsed), fmtTokens(tab2.outputTokensUsed)),
                String(format: "%-20s │ %-20s │ %-20s", NSLocalizedString("slash.status.compare.header.tokens.total", comment: ""), fmtTokens(tab1.tokensUsed), fmtTokens(tab2.tokensUsed)),
                String(format: "%-20s │ %-20s │ %-20s", NSLocalizedString("slash.status.compare.header.cost", comment: ""), String(format: "$%.4f", tab1.totalCost), String(format: "$%.4f", tab2.totalCost)),
                String(format: "%-20s │ %-20s │ %-20s", NSLocalizedString("slash.status.compare.header.commands", comment: ""), "\(tab1.commandCount)", "\(tab2.commandCount)"),
                String(format: "%-20s │ %-20s │ %-20s", NSLocalizedString("slash.status.compare.header.file.changes", comment: ""), String(format: NSLocalizedString("slash.status.file.count", comment: ""), tab1.fileChanges.count), String(format: NSLocalizedString("slash.status.file.count", comment: ""), tab2.fileChanges.count)),
                String(format: "%-20s │ %-20s │ %-20s", NSLocalizedString("slash.status.compare.header.errors", comment: ""), "\(tab1.errorCount)", "\(tab2.errorCount)"),
                String(format: "%-20s │ %-20s │ %-20s", NSLocalizedString("slash.status.compare.header.elapsed", comment: ""), fmtDur(dur1), fmtDur(dur2)),
                "",
                "══════════════════════════════════════════════════",
            ]

            tab.appendBlock(.status(message: lines.joined(separator: "\n")))
        },
        SlashCommand("timeline", NSLocalizedString("slash.cmd.timeline", comment: ""), category: NSLocalizedString("slash.category.session", comment: "")) { tab, _, _ in
            if tab.timeline.isEmpty {
                tab.appendBlock(.status(message: NSLocalizedString("slash.timeline.empty", comment: "")))
                return
            }
            let df = DateFormatter()
            df.dateFormat = "HH:mm:ss"
            var lines = [NSLocalizedString("slash.status.timeline.title", comment: ""), "═══════════════════════════════"]
            for event in tab.timeline.suffix(30) {
                let time = df.string(from: event.timestamp)
                let icon: String
                switch event.type {
                case .started: icon = "🟢"
                case .prompt: icon = "💬"
                case .toolUse: icon = "🔧"
                case .fileChange: icon = "📝"
                case .error: icon = "❌"
                case .completed: icon = "✅"
                }
                lines.append("\(time) \(icon) \(event.type.displayName): \(event.detail)")
            }
            tab.appendBlock(.status(message: lines.joined(separator: "\n")))
        },
        SlashCommand("sleepwork", NSLocalizedString("slash.cmd.sleepwork", comment: ""), usage: "<작업내용> [토큰예산]", category: NSLocalizedString("slash.category.session", comment: "")) { tab, _, args in
            if args.isEmpty {
                tab.appendBlock(.status(message: NSLocalizedString("slash.sleepwork.usage", comment: "")))
                return
            }
            let taskText = args.dropLast().joined(separator: " ")
            let budgetText = args.last ?? ""
            var budget: Int? = nil
            let bt = budgetText.lowercased()
            if bt.hasSuffix("k"), let n = Double(bt.dropLast()) { budget = Int(n * 1000) }
            else if bt.hasSuffix("m"), let n = Double(bt.dropLast()) { budget = Int(n * 1_000_000) }
            else if let n = Int(bt) { budget = n }

            let task = taskText.isEmpty ? budgetText : taskText  // if only 1 arg, treat as task
            if task.isEmpty {
                tab.appendBlock(.status(message: NSLocalizedString("slash.sleepwork.enter.task", comment: "")))
                return
            }
            tab.startSleepWork(task: task, tokenBudget: budget)
        },
        SlashCommand("search", NSLocalizedString("slash.cmd.search", comment: ""), usage: "<검색어>", category: NSLocalizedString("slash.category.display", comment: "")) { tab, manager, args in
            let query = args.joined(separator: " ").trimmingCharacters(in: .whitespaces)
            guard !query.isEmpty else {
                tab.appendBlock(.status(message: NSLocalizedString("slash.search.usage", comment: "")))
                return
            }
            let allTabs = manager.userVisibleTabs
            var results: [(tabName: String, blockContent: String, lineNum: Int)] = []

            for t in allTabs {
                for (idx, block) in t.blocks.enumerated() {
                    if block.content.localizedCaseInsensitiveContains(query) {
                        let snippet = block.content.components(separatedBy: "\n")
                            .first(where: { $0.localizedCaseInsensitiveContains(query) }) ?? String(block.content.prefix(80))
                        results.append((t.workerName, String(snippet.prefix(80)), idx))
                    }
                }
            }

            if results.isEmpty {
                tab.appendBlock(.status(message: String(format: NSLocalizedString("slash.status.search.no.results", comment: ""), query)))
                return
            }

            var lines = [String(format: NSLocalizedString("slash.status.search.results", comment: ""), query, results.count), "═══════════════════════════════"]
            for r in results.prefix(20) {
                lines.append("[\(r.tabName)] \(r.blockContent)")
            }
            if results.count > 20 {
                lines.append(String(format: NSLocalizedString("slash.status.search.more", comment: ""), results.count - 20))
            }
            tab.appendBlock(.status(message: lines.joined(separator: "\n")))
        },
    ]

    /// /cmd 형태만 명령 모드 (경로 /path/to 제외)
    private var isCommandMode: Bool {
        guard inputText.hasPrefix("/") else { return false }
        let after = String(inputText.dropFirst())
        return !after.hasPrefix("/") && !after.contains("/")
    }

    private var hasTypedArgs: Bool {
        guard isCommandMode else { return false }
        let afterSlash = String(inputText.dropFirst())
        return afterSlash.contains(" ") && afterSlash.split(separator: " ").count > 1
    }

    private var matchingCommands: [SlashCommand] {
        guard isCommandMode, !hasTypedArgs else { return [] }
        let typed = String(inputText.dropFirst()).lowercased().trimmingCharacters(in: .whitespaces)
        if typed.isEmpty { return Self.allSlashCommands }
        return Self.allSlashCommands.filter { $0.name.hasPrefix(typed) }
    }

    public var body: some View {
        Group {
            if settings.rawTerminalMode {
                rawTerminalBody
                    .id("raw-\(tab.id)")  // 모드 전환 시 뷰 완전 재생성
                    .overlay(AgentWaitingOverlay(isWaiting: tab.pendingApproval != nil))
            } else {
                normalBody
                    .id("normal-\(tab.id)")
                    .overlay(AgentWaitingOverlay(isWaiting: tab.pendingApproval != nil))
            }
        }
        .alert(item: $unavailableProviderAlert) { provider in
            Alert(
                title: Text(provider.selectionUnavailableTitle),
                message: Text(provider.selectionUnavailableDetail),
                dismissButton: .default(Text("확인"))
            )
        }
    }

    private func selectProvider(_ provider: AgentProvider) {
        guard tab.provider != provider else { return }
        guard provider.refreshAvailability(force: false) else {
            unavailableProviderAlert = provider
            return
        }
        // Reset session state when switching providers
        tab.isProcessing = false
        tab.claudeActivity = .idle
        tab.selectedModel = provider.defaultModel
        tab.isClaude = provider == .claude
    }

    // MARK: - Raw Terminal Body (NSView 기반 진짜 CLI)

    private var rawTerminalBody: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Button(action: { tab.forceStop() }) {
                    Circle().fill(Color.red.opacity(0.85)).frame(width: 10, height: 10)
                }.buttonStyle(.plain).help(NSLocalizedString("terminal.help.close.session", comment: ""))
                Text("\(tab.provider.shellLabel) — \(tab.projectName)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(Theme.textDim)
                Spacer()
            }
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(Theme.bgSurface)

            CLITerminalView(tab: tab, fontSize: 13 * settings.fontSizeScale)
        }
        .background(Theme.bgTerminal)
    }

    // MARK: - Normal Body (Doffice UI)

    private var normalBody: some View {
        VStack(spacing: 0) {
            // [Feature 2] 작업 상태 바
            if !compact { statusBar }

            // [Feature 6] 필터 바
            if showFilterBar && !compact { filterBar }

            // Main content
            HStack(spacing: 0) {
                // Event stream
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(filteredBlocks) { block in
                                EventBlockView(block: block, compact: compact)
                                    .id(block.id)
                                    .textSelection(.enabled)
                            }

                            if tab.isProcessing {
                                ProcessingIndicator(activity: tab.claudeActivity, workerColor: tab.workerColor, workerName: tab.workerName)
                                    .id("processing")
                            }

                            Color.clear.frame(height: 1).id("streamEnd")
                        }
                        .padding(.horizontal, compact ? 8 : 14)
                        .padding(.vertical, 8)
                    }
                    .background(Theme.bgTerminal)
                    .compositingGroup()
                    .onChange(of: tab.blocks.count) { _, newCount in
                        if autoScroll && newCount != lastBlockCount {
                            lastBlockCount = newCount
                            debouncedScroll(proxy, delay: 0.1)
                        }
                    }
                    .onChange(of: tab.isProcessing) { _, processing in
                        // 처리 완료 시 최종 결과로 스크롤
                        if !processing && autoScroll {
                            debouncedScroll(proxy, delay: 0.15)
                        }
                    }
                    .onChange(of: tab.claudeActivity) { _, _ in
                        // 활동 상태 변경될 때마다 스크롤 (tool 전환 등)
                        if autoScroll {
                            debouncedScroll(proxy, delay: 0.2)
                        }
                    }
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { scrollToEnd(proxy) }
                    }
                }

                // [Feature 4] 파일 변경 패널
                if showFilePanel && !compact {
                    Rectangle().fill(Theme.border).frame(width: 1)
                    fileChangePanel
                }
            }

            // Slash command suggestions
            if isCommandMode && !matchingCommands.isEmpty {
                commandSuggestionsView
            }

            if let request = activePlanSelectionRequest {
                planSelectionPanel(request)
            }

            if !compact { fullInputBar } else { compactInputBar }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { isFocused = true }
            syncPlanSelectionState(with: activePlanSelectionRequest)
        }
        .onChange(of: activePlanSelectionRequest?.signature ?? "") { _, _ in
            syncPlanSelectionState(with: activePlanSelectionRequest)
        }
        .onReceive(elapsedTimer) { _ in
            if tab.isProcessing || tab.claudeActivity != .idle {
                elapsedSeconds = Int(Date().timeIntervalSince(tab.startTime))
            }
        }
        // 승인 모달 + 슬립워크 (단일 overlay로 합쳐 투명 렌더링 버그 방지)
        .overlay {
            ZStack {
                if tab.pendingApproval != nil || showSleepWorkSetup {
                    Color.black.opacity(0.4).ignoresSafeArea()
                        .compositingGroup()
                        .onTapGesture {
                            if showSleepWorkSetup { showSleepWorkSetup = false }
                        }
                }
                if let approval = tab.pendingApproval {
                    ApprovalSheet(approval: approval)
                }
                if showSleepWorkSetup {
                    SleepWorkSetupSheet(tab: tab, onDismiss: { showSleepWorkSetup = false })
                }
            }
        }
        // 보안 경고 오버레이
        .overlay(alignment: .top) {
            VStack(spacing: 6) {
                if let warning = tab.dangerousCommandWarning {
                    securityBanner(warning, color: Theme.red, icon: "exclamationmark.octagon.fill") {
                        tab.dangerousCommandWarning = nil
                    }
                }
                if let warning = tab.sensitiveFileWarning {
                    securityBanner(warning, color: Theme.orange, icon: "lock.shield.fill") {
                        tab.sensitiveFileWarning = nil
                    }
                }
            }
            .padding(.horizontal, 16).padding(.top, 8)
            .animation(.easeInOut(duration: 0.2), value: tab.dangerousCommandWarning)
            .animation(.easeInOut(duration: 0.2), value: tab.sensitiveFileWarning)
        }
    }

    private func securityBanner(_ message: String, color: Color, icon: String, onDismiss: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: Theme.iconSize(12), weight: .bold))
                .foregroundColor(color)
            Text(message)
                .font(Theme.mono(9, weight: .medium))
                .foregroundColor(color)
                .lineLimit(3)
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: Theme.iconSize(10)))
                    .foregroundColor(color.opacity(0.5))
            }.buttonStyle(.plain)
        }
        .padding(Theme.sp3)
        .background(
            RoundedRectangle(cornerRadius: Theme.cornerLarge)
                .fill(color.opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: Theme.cornerLarge).stroke(color.opacity(0.3), lineWidth: 1))
        )
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // ═══════════════════════════════════════════
    // MARK: - [Feature 2] Status Bar
    // ═══════════════════════════════════════════

    private var statusBar: some View {
        HStack(spacing: 8) {
            // Worker + Activity
            HStack(spacing: 4) {
                Circle().fill(tab.workerColor).frame(width: 6, height: 6)
                Text(tab.workerName).font(Theme.chrome(9, weight: .semibold)).foregroundColor(tab.workerColor)
                Text(activityLabel).font(Theme.chrome(9)).foregroundColor(activityLabelColor)
            }

            Rectangle().fill(Theme.border).frame(width: 1, height: 12)

            // Elapsed time
            HStack(spacing: 0) {
                Text(formatElapsed(elapsedSeconds)).font(Theme.chrome(9)).foregroundColor(Theme.textSecondary)
            }

            // File count
            if !tab.fileChanges.isEmpty {
                Rectangle().fill(Theme.border).frame(width: 1, height: 12)
                HStack(spacing: 3) {
                    Image(systemName: "doc.fill").font(Theme.chrome(8)).foregroundColor(Theme.green)
                    Text("\(Set(tab.fileChanges.map(\.fileName)).count) files").font(Theme.chrome(9, weight: .bold)).foregroundColor(Theme.green)
                }
            }

            // Error count
            if tab.errorCount > 0 {
                HStack(spacing: 3) {
                    Image(systemName: "exclamationmark.triangle.fill").font(Theme.chrome(7)).foregroundColor(Theme.red)
                    Text("\(tab.errorCount) errors").font(Theme.chrome(9, weight: .bold)).foregroundColor(Theme.red)
                }
            }

            // Commands
            if tab.commandCount > 0 {
                HStack(spacing: 3) {
                    Image(systemName: "terminal").font(Theme.chrome(7)).foregroundColor(Theme.textDim)
                    Text("\(tab.commandCount) cmds").font(Theme.chrome(9)).foregroundColor(Theme.textSecondary)
                }
            }

            Spacer()

            // Toggle buttons
            Button(action: { withAnimation(.easeInOut(duration: 0.15)) { showFilterBar.toggle() } }) {
                HStack(spacing: 3) {
                    Image(systemName: "line.3.horizontal.decrease.circle\(showFilterBar ? ".fill" : "")")
                        .font(Theme.chrome(8))
                    Text(NSLocalizedString("terminal.filter", comment: "")).font(Theme.chrome(8, weight: showFilterBar ? .bold : .regular))
                }
                .foregroundColor(showFilterBar || blockFilter.isActive ? Theme.accent : Theme.textDim)
                .padding(.horizontal, 5).padding(.vertical, 2)
                .background(showFilterBar ? Theme.accent.opacity(0.08) : .clear).cornerRadius(Theme.cornerSmall)
            }.buttonStyle(.plain).help(NSLocalizedString("terminal.help.log.filter", comment: ""))

            Button(action: { withAnimation(.easeInOut(duration: 0.15)) { showFilePanel.toggle() } }) {
                HStack(spacing: 3) {
                    Image(systemName: "doc.text.magnifyingglass").font(Theme.chrome(8))
                    Text(NSLocalizedString("terminal.file", comment: "")).font(Theme.chrome(8, weight: showFilePanel ? .bold : .regular))
                }
                .foregroundColor(showFilePanel ? Theme.accent : Theme.textDim)
                .padding(.horizontal, 5).padding(.vertical, 2)
                .background(showFilePanel ? Theme.accent.opacity(0.08) : .clear).cornerRadius(Theme.cornerSmall)
            }.buttonStyle(.plain).help(NSLocalizedString("terminal.help.file.changes", comment: ""))
        }
        .padding(.horizontal, Theme.sp3).padding(.vertical, 5)
        .background(Theme.bgSurface.opacity(0.5))
        .overlay(Rectangle().fill(Theme.border).frame(height: 1), alignment: .bottom)
    }

    private var activityLabel: String {
        switch tab.claudeActivity {
        case .idle: return NSLocalizedString("terminal.status.idle", comment: ""); case .thinking: return NSLocalizedString("terminal.status.thinking", comment: ""); case .reading: return NSLocalizedString("terminal.status.reading", comment: "")
        case .writing: return NSLocalizedString("terminal.status.writing", comment: ""); case .searching: return NSLocalizedString("terminal.status.searching", comment: ""); case .running: return NSLocalizedString("terminal.status.running", comment: "")
        case .done: return NSLocalizedString("terminal.status.done", comment: ""); case .error: return NSLocalizedString("terminal.status.error", comment: "")
        }
    }

    private var activityLabelColor: Color {
        switch tab.claudeActivity {
        case .thinking: return Theme.purple; case .reading: return Theme.accent; case .writing: return Theme.green
        case .searching: return Theme.cyan; case .running: return Theme.yellow; case .done: return Theme.green
        case .error: return Theme.red; case .idle: return Theme.textDim
        }
    }

    private func formatElapsed(_ secs: Int) -> String {
        if secs < 60 { return "\(secs)s" }
        if secs < 3600 { return "\(secs / 60)m \(secs % 60)s" }
        return "\(secs / 3600)h \((secs % 3600) / 60)m"
    }

    // ═══════════════════════════════════════════
    // MARK: - [Feature 6] Filter Bar
    // ═══════════════════════════════════════════

    private var filterBar: some View {
        HStack(spacing: 4) {
            Text("Filter").font(Theme.chrome(8, weight: .bold)).foregroundColor(Theme.textDim)
            ForEach(["Bash", "Read", "Write", "Edit", "Grep", "Glob"], id: \.self) { tool in
                filterChip(tool, color: toolColor(tool))
            }
            Rectangle().fill(Theme.border).frame(width: 1, height: 12)
            Button(action: { blockFilter.onlyErrors.toggle() }) {
                Text("Errors").font(Theme.chrome(8, weight: blockFilter.onlyErrors ? .bold : .regular))
                    .foregroundColor(blockFilter.onlyErrors ? Theme.red : Theme.textDim)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(blockFilter.onlyErrors ? Theme.red.opacity(0.1) : .clear).cornerRadius(3)
            }.buttonStyle(.plain)
            Spacer()
            if blockFilter.isActive {
                Button(action: { blockFilter = BlockFilter() }) {
                    Text("Clear").font(Theme.chrome(8)).foregroundStyle(Theme.accentBackground)
                }.buttonStyle(.plain)
            }
            // Search
            HStack(spacing: 3) {
                Image(systemName: "magnifyingglass").font(Theme.chrome(8)).foregroundColor(Theme.textDim)
                TextField(NSLocalizedString("terminal.search.placeholder", comment: ""), text: $blockFilter.searchText)
                    .textFieldStyle(.plain).font(Theme.chrome(9)).frame(width: 80)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 4)
        .background(Theme.bgSurface.opacity(0.3))
        .overlay(Rectangle().fill(Theme.border).frame(height: 1), alignment: .bottom)
    }

    private func filterChip(_ tool: String, color: Color) -> some View {
        let active = blockFilter.toolTypes.contains(tool)
        return Button(action: {
            if active { blockFilter.toolTypes.remove(tool) }
            else { blockFilter.toolTypes.insert(tool) }
        }) {
            Text(tool).font(Theme.chrome(8, weight: active ? .bold : .regular))
                .foregroundColor(active ? color : Theme.textDim)
                .padding(.horizontal, 5).padding(.vertical, 2)
                .background(active ? color.opacity(0.1) : .clear).cornerRadius(3)
        }.buttonStyle(.plain)
        .accessibilityLabel(String(format: NSLocalizedString("terminal.filter.a11y", comment: ""), tool))
    }

    private func toolColor(_ name: String) -> Color {
        switch name {
        case "Bash": return Theme.yellow; case "Read": return Theme.accent
        case "Write", "Edit": return Theme.green; case "Grep", "Glob": return Theme.cyan
        default: return Theme.textSecondary
        }
    }

    // ═══════════════════════════════════════════
    // MARK: - [Feature 4] File Change Panel
    // ═══════════════════════════════════════════

    private var fileChangePanel: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "doc.text").font(Theme.chrome(9)).foregroundStyle(Theme.accentBackground)
                Text("FILES").font(Theme.pixel).foregroundColor(Theme.textDim).tracking(1.5)
                Spacer()
                Text("\(Set(tab.fileChanges.map(\.fileName)).count)")
                    .font(Theme.chrome(9, weight: .bold)).foregroundStyle(Theme.accentBackground)
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Theme.bgSurface.opacity(0.5))

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    // Group by unique file
                    let grouped = Dictionary(grouping: tab.fileChanges, by: \.path)
                    ForEach(Array(grouped.keys.sorted()), id: \.self) { path in
                        if let records = grouped[path], let latest = records.last {
                        HStack(spacing: 6) {
                            Image(systemName: latest.action == "Write" ? "doc.badge.plus" : "pencil.line")
                                .font(Theme.chrome(8)).foregroundColor(Theme.green)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(latest.fileName).font(Theme.chrome(9, weight: .medium)).foregroundColor(Theme.textPrimary).lineLimit(1)
                                Text("\(latest.action) x\(records.count)")
                                    .font(Theme.chrome(7)).foregroundColor(Theme.textDim)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        } // if let records
                    }

                    if tab.fileChanges.isEmpty {
                        Text(NSLocalizedString("terminal.no.file.changes", comment: "")).font(Theme.chrome(10)).foregroundColor(Theme.textDim)
                            .frame(maxWidth: .infinity).padding(.vertical, 20)
                    }
                }
            }
        }
        .frame(width: 180)
        .background(Theme.bgCard)
    }

    // ═══════════════════════════════════════════
    // MARK: - Filtered Blocks (기존 확장)
    // ═══════════════════════════════════════════

    private func scrollToEnd(_ proxy: ScrollViewProxy) {
        proxy.scrollTo("streamEnd", anchor: .bottom)
    }

    private func debouncedScroll(_ proxy: ScrollViewProxy, delay: Double) {
        scrollWorkItem?.cancel()
        let item = DispatchWorkItem { scrollToEnd(proxy) }
        scrollWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    private var filteredBlocks: [StreamBlock] {
        // Fast path: no filtering needed
        if tab.outputMode == .full && !blockFilter.isActive {
            return tab.blocks
        }
        var blocks: [StreamBlock]
        switch tab.outputMode {
        case .full: blocks = tab.blocks
        case .realtime: blocks = tab.blocks.filter { if case .sessionStart = $0.blockType { return false }; return true }
        case .resultOnly:
            blocks = tab.blocks.filter {
                switch $0.blockType {
                case .userPrompt, .thought, .completion, .error: return true
                default: return false
                }
            }
        }
        // 추가 필터 적용
        if blockFilter.isActive {
            blocks = blocks.filter { blockFilter.matches($0) }
        }
        return blocks
    }

    // MARK: - Input Bars

    private var fullInputBar: some View {
        VStack(spacing: 0) {
            // Settings
            HStack(spacing: 0) {
                settingGroup("Agent") {
                    ForEach(AgentProvider.allCases) { provider in
                        settingChip(provider.displayName, isSelected: tab.provider == provider, color: providerColor(provider)) {
                            selectProvider(provider)
                        }
                    }
                }

                settingSep

                settingGroup("Model") {
                    if tab.provider == .claude {
                        ForEach(tab.provider.models) { model in
                            settingChip(model.displayName, isSelected: tab.selectedModel == model, color: modelColor(model)) {
                                tab.selectedModel = model
                            }
                        }
                    } else {
                        settingMenuChip(tab.selectedModel.displayName, color: modelColor(tab.selectedModel)) {
                            ForEach(tab.provider.models) { model in
                                Button(model.displayName) {
                                    tab.selectedModel = model
                                }
                            }
                        }
                    }
                }

                settingSep

                if tab.provider == .claude {
                    settingGroup("Effort") {
                        ForEach(EffortLevel.allCases) { l in
                            let name = l.rawValue.prefix(1).uppercased() + l.rawValue.dropFirst()
                            settingChip(name, isSelected: tab.effortLevel == l, color: Theme.accent) { tab.effortLevel = l }
                        }
                    }

                    settingSep

                    settingGroup("Output") {
                        ForEach(OutputMode.allCases) { m in
                            settingChip(m.rawValue, isSelected: tab.outputMode == m, color: Theme.cyan) { tab.outputMode = m }
                        }
                    }

                    settingSep

                    settingGroup(NSLocalizedString("terminal.permission.section", comment: "")) {
                        ForEach(PermissionMode.allCases) { m in
                            settingChip(m.displayName, isSelected: tab.permissionMode == m, color: permissionColor(m)) { tab.permissionMode = m }
                                .help(m.desc)
                        }
                    }
                } else if tab.provider == .gemini {
                    settingGroup("Output") {
                        ForEach(OutputMode.allCases) { m in
                            settingChip(m.rawValue, isSelected: tab.outputMode == m, color: Theme.cyan) { tab.outputMode = m }
                        }
                    }
                } else {
                    settingGroup("Sandbox") {
                        ForEach(CodexSandboxMode.allCases) { mode in
                            settingChip(mode.displayName, isSelected: tab.codexSandboxMode == mode, color: codexSandboxColor(mode)) {
                                tab.codexSandboxMode = mode
                            }
                        }
                    }

                    settingSep

                    settingGroup("Approval") {
                        ForEach(CodexApprovalPolicy.allCases) { mode in
                            settingChip(mode.displayName, isSelected: tab.codexApprovalPolicy == mode, color: codexApprovalColor(mode)) {
                                tab.codexApprovalPolicy = mode
                            }
                        }
                    }

                    settingSep

                    settingGroup("Output") {
                        ForEach(OutputMode.allCases) { m in
                            settingChip(m.rawValue, isSelected: tab.outputMode == m, color: Theme.cyan) { tab.outputMode = m }
                        }
                    }
                }

                Spacer(minLength: 4)

                if tab.totalCost > 0 {
                    Text(String(format: "$%.4f", tab.totalCost))
                        .font(Theme.chrome(9, weight: .semibold)).foregroundColor(Theme.yellow)
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(Theme.yellow.opacity(0.06)).cornerRadius(4)
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 3)
            .background(Theme.bgSurface.opacity(0.6))

            // 설정 ↔ 입력 구분선
            Rectangle().fill(Theme.border).frame(height: 1)

            if let workflowTab = workflowDisplayTab, !workflowTab.workflowTimelineStages.isEmpty {
                workflowProgressBar(workflowTab)
                Rectangle().fill(Theme.border).frame(height: 1)
            }

            // 슬립워크 상태 바
            if tab.sleepWorkTask != nil {
                sleepWorkStatusBar
            }

            // 첨부 이미지 미리보기
            if !tab.attachedImages.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(tab.attachedImages, id: \.absoluteString) { url in
                            ZStack(alignment: .topTrailing) {
                                if let nsImage = NSImage(contentsOf: url) {
                                    Image(nsImage: nsImage)
                                        .resizable().scaledToFill()
                                        .frame(width: 48, height: 48)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.border, lineWidth: 1))
                                } else {
                                    RoundedRectangle(cornerRadius: 6).fill(Theme.bgSurface)
                                        .frame(width: 48, height: 48)
                                        .overlay(Image(systemName: "photo").foregroundColor(Theme.textDim))
                                }
                                Button(action: { tab.attachedImages.removeAll { $0 == url } }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 14)).foregroundColor(Theme.red)
                                        .background(Circle().fill(Theme.bgCard).frame(width: 12, height: 12))
                                }.buttonStyle(.plain).offset(x: 4, y: -4)
                            }
                        }
                    }.padding(.horizontal, 14).padding(.vertical, 4)
                }
                .background(Theme.bgSurface.opacity(0.5))
            }

            // Input (auto-growing)
            HStack(alignment: .bottom, spacing: 8) {
                HStack(spacing: 3) {
                    RoundedRectangle(cornerRadius: 1).fill(tab.workerColor).frame(width: 3, height: 16)
                    Text(tab.projectName).font(Theme.chrome(10)).foregroundColor(Theme.textDim)
                    Text(">").font(Theme.chrome(12, weight: .semibold)).foregroundStyle(Theme.accentBackground)
                }.padding(.bottom, 4)

                // Auto-growing TextEditor
                ZStack(alignment: .topLeading) {
                    // Hidden text for height calculation
                    Text(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? " " : inputText)
                        .font(Theme.monoNormal).foregroundColor(.clear)
                        .padding(.horizontal, 4).padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .allowsHitTesting(false)
                    // Actual editor
                    TextEditor(text: $inputText)
                        .font(Theme.monoNormal).foregroundColor(Theme.textPrimary)
                        .focused($isFocused)
                        .disabled(tab.isProcessing)
                        .scrollContentBackground(.hidden)
                        .padding(.horizontal, 0).padding(.vertical, 4)
                        .accessibilityLabel(NSLocalizedString("terminal.input.a11y", comment: ""))
                    // Placeholder (on top visually but doesn't intercept clicks)
                    if inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(tab.isProcessing ? NSLocalizedString("terminal.input.placeholder.running", comment: "") : NSLocalizedString("terminal.input.placeholder", comment: ""))
                            .font(Theme.monoNormal).foregroundColor(Theme.textDim.opacity(0.5))
                            .padding(.horizontal, 4).padding(.vertical, 8)
                            .allowsHitTesting(false)
                    }
                }
                .frame(minHeight: 32, maxHeight: 120)
                .onKeyPress(.return, phases: .down) { event in
                    if event.modifiers.contains(.shift) {
                        return .ignored // Shift+Enter → 줄바꿈 (기본 동작)
                    }
                    submit()
                    return .handled // Enter → 전송
                }
                .onKeyPress(phases: .down) { event in
                    guard isCommandMode else { return .ignored }
                    return handleCommandKeyNavigation(event)
                }
                .onChange(of: inputText) { old, new in
                    selectedCommandIndex = 0
                    // Detect paste: if many new lines appeared at once
                    let addedLen = new.count - old.count
                    if addedLen > 0 {
                        let added = String(new.suffix(addedLen))
                        let newLines = added.components(separatedBy: .newlines).count - 1
                        if newLines >= 4 {
                            // Collapse pasted text into a placeholder
                            pasteCounter += 1
                            let chunkId = pasteCounter
                            let lineCount = added.components(separatedBy: .newlines).count
                            pastedChunks.append((id: chunkId, text: added))
                            let placeholder = "[Pasted text #\(chunkId) +\(lineCount) lines]"
                            // Replace the pasted portion with placeholder
                            let prefix = String(new.prefix(new.count - addedLen))
                            inputText = prefix + placeholder
                        }
                    }
                }

                // 이미지 첨부
                Button(action: { pickImage() }) {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: Theme.iconSize(11)))
                        .foregroundColor(tab.attachedImages.isEmpty ? Theme.textDim : Theme.cyan)
                }
                .buttonStyle(.plain)
                .help(NSLocalizedString("terminal.help.attach.image", comment: ""))
                .padding(.bottom, 4)

                Button(action: { showSleepWorkSetup = true }) {
                    Image(systemName: "moon.zzz.fill")
                        .font(.system(size: Theme.iconSize(11)))
                        .foregroundColor(Theme.purple)
                }
                .buttonStyle(.plain)
                .help(NSLocalizedString("terminal.help.sleepwork", comment: ""))
                .padding(.bottom, 4)

                if tab.isProcessing {
                    Button(action: { tab.cancelProcessing() }) {
                        Label("Stop", systemImage: "stop.fill").font(Theme.chrome(9, weight: .medium))
                            .foregroundColor(Theme.red).padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Theme.red.opacity(0.1)).cornerRadius(5)
                    }.buttonStyle(.plain).padding(.bottom, 4)
                } else {
                    Button(action: { submit() }) {
                        Image(systemName: "arrow.up.circle.fill").font(.system(size: Theme.iconSize(20)))
                            .foregroundColor(inputText.isEmpty ? Theme.textDim : Theme.accent)
                    }.buttonStyle(.plain).disabled(inputText.isEmpty).padding(.bottom, 4)
                }
            }.padding(.horizontal, 14).padding(.vertical, 4)
        }
        .background(Theme.bgInput)
        .overlay(
            VStack(spacing: 0) {
                Rectangle().fill(Theme.textDim.opacity(0.3)).frame(height: 1)
                Spacer()
                Rectangle().fill(Theme.textDim.opacity(0.3)).frame(height: 1)
            }
        )
        .onDrop(of: [.fileURL, .image], isTargeted: nil) { providers in
            for provider in providers {
                provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { data, _ in
                    guard let data = data as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                    let ext = url.pathExtension.lowercased()
                    if ["png", "jpg", "jpeg", "gif", "webp", "bmp", "tiff", "heic"].contains(ext) {
                        DispatchQueue.main.async { tab.attachedImages.append(url) }
                    }
                }
            }
            return true
        }
    }

    private var compactInputBar: some View {
        HStack(alignment: .bottom, spacing: 4) {
            ZStack(alignment: .topLeading) {
                Text(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? " " : inputText)
                    .font(Theme.monoSmall).foregroundColor(.clear)
                    .padding(.horizontal, 4).padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .allowsHitTesting(false)
                TextEditor(text: $inputText)
                    .font(Theme.monoSmall).foregroundColor(Theme.textPrimary)
                    .focused($isFocused).disabled(tab.isProcessing)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 0).padding(.vertical, 2)
                if inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(NSLocalizedString("terminal.input.hint", comment: "")).font(Theme.monoSmall).foregroundColor(Theme.textDim.opacity(0.5))
                        .padding(.horizontal, 4).padding(.vertical, 6)
                        .allowsHitTesting(false)
                }
            }
            .frame(minHeight: 28, maxHeight: 100)
            .onKeyPress(.return, phases: .down) { event in
                if event.modifiers.contains(.shift) { return .ignored }
                submit(); return .handled
            }
            .onKeyPress(phases: .down) { event in
                guard isCommandMode else { return .ignored }
                return handleCommandKeyNavigation(event)
            }

            if tab.isProcessing {
                Button(action: { tab.cancelProcessing() }) {
                    Image(systemName: "stop.fill").font(.system(size: Theme.iconSize(7))).foregroundColor(Theme.red)
                }.buttonStyle(.plain).padding(.bottom, 4)
            } else {
                Button(action: { submit() }) {
                    Image(systemName: "arrow.up.circle.fill").font(.system(size: Theme.iconSize(14)))
                        .foregroundColor(inputText.isEmpty ? Theme.textDim : Theme.accent)
                }.buttonStyle(.plain).disabled(inputText.isEmpty).padding(.bottom, 4)
            }
        }.padding(.horizontal, 8).padding(.vertical, 3).background(Theme.bgInput)
    }

    private var sleepWorkStatusBar: some View {
        let budget = tab.sleepWorkTokenBudget ?? 0
        let used = tab.tokensUsed - tab.sleepWorkStartTokens
        let ratio = budget > 0 ? Double(used) / Double(budget) : 0
        let color: Color = ratio < 1.0 ? Theme.purple : (ratio < 2.0 ? Theme.yellow : Theme.red)

        return HStack(spacing: 8) {
            Image(systemName: "moon.zzz.fill").font(.system(size: Theme.iconSize(10))).foregroundColor(Theme.purple)
            Text(NSLocalizedString("terminal.sleepwork.running", comment: "")).font(Theme.chrome(9, weight: .bold)).foregroundColor(Theme.purple)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2).fill(Theme.border.opacity(0.15)).frame(height: 4)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color)
                        .frame(width: min(geo.size.width, geo.size.width * CGFloat(min(ratio, 2.0) / 2.0)), height: 4)
                }
            }.frame(height: 4).frame(maxWidth: 120)

            if budget > 0 {
                Text("\(formatK(used)) / \(formatK(budget))")
                    .font(Theme.chrome(9, weight: .bold)).foregroundColor(color)
            }

            Spacer()

            Button(action: {
                tab.sleepWorkTask = nil
                tab.cancelProcessing()
            }) {
                Text(NSLocalizedString("terminal.sleepwork.stop", comment: "")).font(Theme.chrome(9, weight: .bold)).foregroundColor(Theme.red)
            }.buttonStyle(.plain)
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(Theme.purple.opacity(0.06))
    }

    private func formatK(_ n: Int) -> String {
        if n >= 1000000 { return String(format: "%.1fM", Double(n) / 1000000) }
        if n >= 1000 { return String(format: "%.1fK", Double(n) / 1000) }
        return "\(n)"
    }

    private func pickImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image, .png, .jpeg]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.title = NSLocalizedString("terminal.image.attach.title", comment: "")
        panel.message = NSLocalizedString("terminal.image.pick.message", comment: "")
        if panel.runModal() == .OK {
            tab.attachedImages.append(contentsOf: panel.urls)
        }
    }

    private func expandPastedChunks(_ text: String) -> String {
        var result = text
        for chunk in pastedChunks {
            let placeholder = "[Pasted text #\(chunk.id) +\(chunk.text.components(separatedBy: .newlines).count) lines]"
            result = result.replacingOccurrences(of: placeholder, with: chunk.text)
        }
        return result
    }

    private func submit() {
        let raw = expandPastedChunks(inputText)
        let p = raw.trimmingCharacters(in: .whitespaces); guard !p.isEmpty else { return }
        guard !tab.isProcessing else { return }

        // Slash command handling — /cmd 형태만 (경로 /path/to/file 제외)
        let afterSlash = String(p.dropFirst())
        let looksLikeCommand = p.hasPrefix("/") && !afterSlash.hasPrefix("/") && !afterSlash.contains("/")
        if looksLikeCommand {
            let parts = afterSlash.split(separator: " ", maxSplits: 1).map(String.init)
            let cmdName = parts.first?.lowercased() ?? ""
            let args = parts.count > 1 ? parts[1].split(separator: " ").map(String.init) : []

            // 정확히 매칭되는 명령어만 실행
            if let cmd = Self.allSlashCommands.first(where: { $0.name == cmdName }) {
                inputText = ""; pastedChunks.removeAll(); selectedCommandIndex = 0
                tab.appendBlock(.userPrompt, content: "/\(cmd.name)" + (args.isEmpty ? "" : " " + args.joined(separator: " ")))
                cmd.action(tab, manager, args)
                return
            }
        }

        inputText = ""; pastedChunks.removeAll()
        tab.sendPrompt(p)
        AchievementManager.shared.addXP(5); AchievementManager.shared.incrementCommand()
    }

    // ═══════════════════════════════════════════
    // MARK: - Command Suggestions View
    // ═══════════════════════════════════════════

    private var commandSuggestionsView: some View {
        let commands = matchingCommands
        let clampedIndex = min(selectedCommandIndex, max(0, commands.count - 1))
        return VStack(alignment: .leading, spacing: 0) {
            Rectangle().fill(Theme.border).frame(height: 1)
            HStack(spacing: 4) {
                Image(systemName: "command").font(Theme.chrome(8)).foregroundStyle(Theme.accentBackground)
                Text(NSLocalizedString("terminal.command.label", comment: "")).font(Theme.chrome(8, weight: .bold)).foregroundStyle(Theme.accentBackground)
                if commands.count < Self.allSlashCommands.count {
                    Text(String(format: NSLocalizedString("terminal.cmd.match.count", comment: ""), commands.count)).font(Theme.chrome(7)).foregroundColor(Theme.textDim)
                }
                Spacer()
                Text(NSLocalizedString("terminal.cmd.suggestion.hint", comment: "")).font(Theme.chrome(7)).foregroundColor(Theme.textDim)
            }
            .padding(.horizontal, 12).padding(.vertical, 4)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(commands.enumerated()), id: \.offset) { idx, cmd in
                            let isSelected = idx == clampedIndex
                            HStack(spacing: 6) {
                                Text("/\(cmd.name)")
                                    .font(Theme.mono(11, weight: isSelected ? .bold : .medium))
                                    .foregroundColor(isSelected ? Theme.accent : Theme.textPrimary)
                                if !cmd.usage.isEmpty {
                                    Text(cmd.usage).font(Theme.mono(9)).foregroundColor(Theme.textDim)
                                }
                                Spacer()
                                Text(cmd.description).font(Theme.mono(9)).foregroundColor(isSelected ? Theme.textSecondary : Theme.textDim)
                            }
                            .padding(.horizontal, 12).padding(.vertical, 5)
                            .background(isSelected ? Theme.accent.opacity(0.12) : .clear)
                            .contentShape(Rectangle())
                            .id(idx)
                            .onTapGesture {
                                inputText = "/\(cmd.name) "
                                selectedCommandIndex = idx
                            }
                        }
                    }
                }
                .frame(maxHeight: 240)
                .onChange(of: selectedCommandIndex) { _, newIdx in
                    withAnimation(.easeOut(duration: 0.1)) { proxy.scrollTo(min(newIdx, commands.count - 1), anchor: .center) }
                }
            }
        }
        .background(Theme.bgSurface)
    }

    private func handleCommandKeyNavigation(_ key: KeyPress) -> KeyPress.Result {
        let commands = matchingCommands

        // Escape → 명령어 모드 종료
        if key.key == .escape {
            inputText = ""
            selectedCommandIndex = 0
            return .handled
        }

        guard !commands.isEmpty else { return .ignored }

        if key.key == .upArrow {
            selectedCommandIndex = max(0, selectedCommandIndex - 1)
            return .handled
        } else if key.key == .downArrow {
            selectedCommandIndex = min(commands.count - 1, selectedCommandIndex + 1)
            return .handled
        } else if key.key == .tab {
            let idx = min(selectedCommandIndex, commands.count - 1)
            inputText = "/\(commands[idx].name) "
            return .handled
        }
        return .ignored
    }

    private var workflowDisplayTab: TerminalTab? {
        if let sourceId = tab.automationSourceTabId,
           let sourceTab = manager.tabs.first(where: { $0.id == sourceId }) {
            return sourceTab
        }
        return tab.workflowTimelineStages.isEmpty ? nil : tab
    }

    private var activePlanSelectionRequest: PlanSelectionRequest? {
        guard tab.permissionMode == .plan, !tab.isProcessing else { return nil }

        let lastUserPromptIndex = tab.blocks.lastIndex { block in
            if case .userPrompt = block.blockType { return true }
            return false
        }

        guard let lastUserPromptIndex else { return nil }
        let nextIdx = tab.blocks.index(after: lastUserPromptIndex)
        let responseBlocks = nextIdx < tab.blocks.endIndex ? tab.blocks.suffix(from: nextIdx) : ArraySlice<StreamBlock>()
        let responseText = responseBlocks.compactMap { block -> String? in
            if case .thought = block.blockType {
                return block.content
            }
            return nil
        }
        .joined(separator: "\n")
        .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !responseText.isEmpty else { return nil }
        guard let request = PlanSelectionRequest.parse(from: responseText) else { return nil }
        guard !sentPlanSignatures.contains(request.signature) else { return nil }
        return request
    }

    private func syncPlanSelectionState(with request: PlanSelectionRequest?) {
        guard let request else {
            planSelectionSignature = ""
            planSelectionDraft = [:]
            return
        }

        guard planSelectionSignature != request.signature else { return }
        planSelectionSignature = request.signature
        planSelectionDraft = [:]
    }

    private func planSelectionPanel(_ request: PlanSelectionRequest) -> some View {
        let selectedCount = request.groups.reduce(into: 0) { count, group in
            if planSelectionDraft[group.id] != nil { count += 1 }
        }
        let isComplete = selectedCount == request.groups.count

        return VStack(alignment: .leading, spacing: compact ? 8 : 10) {
            HStack(spacing: 6) {
                Image(systemName: "list.bullet.clipboard")
                    .font(.system(size: Theme.iconSize(compact ? 8 : 10)))
                    .foregroundColor(Theme.purple)
                Text(NSLocalizedString("terminal.plan.select", comment: ""))
                    .font(Theme.mono(compact ? 9 : 10, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                Text("\(selectedCount)/\(request.groups.count)")
                    .font(Theme.mono(compact ? 8 : 9, weight: .semibold))
                    .foregroundColor(isComplete ? Theme.green : Theme.textDim)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background((isComplete ? Theme.green : Theme.bgSelected).opacity(0.12))
                    .cornerRadius(4)
                Spacer()
                if !planSelectionDraft.isEmpty {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.12)) {
                            planSelectionDraft = [:]
                        }
                    }) {
                        Text(NSLocalizedString("terminal.plan.reset", comment: ""))
                            .font(Theme.mono(compact ? 8 : 9))
                            .foregroundColor(Theme.textDim)
                    }
                    .buttonStyle(.plain)
                }
            }

            if let promptLine = request.promptLine {
                Text(promptLine)
                    .font(Theme.mono(compact ? 9 : 10))
                    .foregroundColor(Theme.textSecondary)
                    .lineLimit(2)
            }

            ForEach(request.groups) { group in
                VStack(alignment: .leading, spacing: 6) {
                    Text(group.title)
                        .font(Theme.mono(compact ? 9 : 10, weight: .semibold))
                        .foregroundColor(Theme.textPrimary)

                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(group.options) { option in
                            let isSelected = planSelectionDraft[group.id] == option.key
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.12)) {
                                    planSelectionDraft[group.id] = option.key
                                }
                            }) {
                                HStack(alignment: .top, spacing: 8) {
                                    Text(option.key)
                                        .font(Theme.mono(compact ? 8 : 9, weight: .bold))
                                        .foregroundColor(isSelected ? Theme.bg : Theme.purple)
                                        .frame(width: compact ? 18 : 20, height: compact ? 18 : 20)
                                        .background(
                                            RoundedRectangle(cornerRadius: 5)
                                                .fill(isSelected ? Theme.purple : Theme.purple.opacity(0.12))
                                        )
                                    Text(option.label)
                                        .font(Theme.mono(compact ? 9 : 10))
                                        .foregroundColor(isSelected ? Theme.textPrimary : Theme.textSecondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .multilineTextAlignment(.leading)
                                    if isSelected {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: Theme.iconSize(compact ? 8 : 9)))
                                            .foregroundColor(Theme.green)
                                    }
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 7)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(isSelected ? Theme.purple.opacity(0.1) : Theme.bgSurface.opacity(0.65))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(isSelected ? Theme.purple.opacity(0.35) : Theme.border.opacity(0.35), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            HStack(spacing: 8) {
                Button(action: {
                    inputText = request.responseText(from: planSelectionDraft)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { isFocused = true }
                }) {
                    Text(NSLocalizedString("terminal.insert.input", comment: ""))
                        .font(Theme.mono(compact ? 8 : 9, weight: .medium))
                        .foregroundColor(isComplete ? Theme.textPrimary : Theme.textDim)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 7).fill(Theme.bgSurface))
                        .overlay(
                            RoundedRectangle(cornerRadius: 7)
                                .stroke(isComplete ? Theme.border.opacity(0.5) : Theme.border.opacity(0.25), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .disabled(!isComplete)

                Button(action: {
                    let response = request.responseText(from: planSelectionDraft)
                    guard !response.isEmpty else { return }
                    inputText = ""
                    sentPlanSignatures.insert(request.signature)
                    tab.sendPrompt(response)
                    AchievementManager.shared.addXP(5)
                    AchievementManager.shared.incrementCommand()
                }) {
                    Text(NSLocalizedString("terminal.send.selection", comment: ""))
                        .font(Theme.mono(compact ? 8 : 9, weight: .bold))
                        .foregroundColor(isComplete ? Theme.bg : Theme.textDim)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 7)
                                .fill(isComplete ? Theme.purple : Theme.bgSelected.opacity(0.35))
                        )
                }
                .buttonStyle(.plain)
                .disabled(!isComplete)

                Spacer()
            }
        }
        .padding(.horizontal, compact ? 10 : 14)
        .padding(.vertical, compact ? 8 : 10)
        .background(Theme.bgSurface.opacity(0.72))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Theme.purple.opacity(0.18), lineWidth: 1)
        )
        .padding(.horizontal, compact ? 8 : 12)
        .padding(.top, 8)
        .padding(.bottom, compact ? 2 : 4)
    }

    private func workflowProgressBar(_ workflowTab: TerminalTab) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "point.topleft.down.curvedto.point.bottomright.up")
                    .font(Theme.mono(8))
                    .foregroundStyle(Theme.accentBackground)
                Text(NSLocalizedString("terminal.argument.flow", comment: ""))
                    .font(Theme.mono(8, weight: .bold))
                    .foregroundColor(Theme.textDim)
                if let summary = workflowTab.workflowProgressSummary {
                    Text(summary)
                        .font(Theme.mono(8, weight: .semibold))
                        .foregroundColor(Theme.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(workflowTab.workflowTimelineStages) { stage in
                        workflowStageChip(stage)
                    }
                }
                .padding(.vertical, 1)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Theme.bgSurface.opacity(0.45))
    }

    private func workflowStageChip(_ stage: WorkflowStageRecord) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Text(stage.role.displayName)
                    .font(Theme.mono(8, weight: .bold))
                    .foregroundColor(stage.state.tint)
                Text(stage.state.label)
                    .font(Theme.mono(7, weight: .semibold))
                    .foregroundColor(stage.state.tint)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(stage.state.tint.opacity(0.12))
                    .cornerRadius(4)
            }

            Text(stage.workerName)
                .font(Theme.mono(9, weight: .semibold))
                .foregroundColor(Theme.textPrimary)
                .lineLimit(1)

            Text(stage.handoffLabel)
                .font(Theme.mono(7))
                .foregroundColor(Theme.textSecondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Theme.bgCard.opacity(0.9))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(stage.state.tint.opacity(0.22), lineWidth: 1)
        )
    }

    // MARK: - Setting Helpers

    private func settingGroup<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(Theme.chrome(8, weight: .medium))
                .foregroundColor(Theme.textDim)
                .fixedSize()
            HStack(spacing: 2) {
                content()
            }
        }
        .padding(.horizontal, 6)
    }

    private var settingSep: some View {
        Rectangle().fill(Theme.textDim.opacity(0.25)).frame(width: 1, height: 18).padding(.horizontal, 4)
    }

    private func settingChip(_ label: String, isSelected: Bool, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: { withAnimation(.easeInOut(duration: 0.12)) { action() } }) {
            Text(label)
                .font(Theme.chrome(9, weight: isSelected ? .bold : .regular))
                .foregroundColor(isSelected ? color : Theme.textDim)
                .fixedSize()
                .padding(.horizontal, 7).padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isSelected ? color.opacity(0.14) : .clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isSelected ? color.opacity(0.3) : .clear, lineWidth: 1)
                )
        }.buttonStyle(.plain)
    }

    private func settingMenuChip<Content: View>(_ label: String, color: Color, @ViewBuilder content: () -> Content) -> some View {
        Menu {
            content()
        } label: {
            HStack(spacing: 4) {
                Text(label)
                    .font(Theme.chrome(9, weight: .bold))
                    .foregroundColor(color)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(color.opacity(0.85))
            }
            .fixedSize()
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(color.opacity(0.14))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
        }
        .menuStyle(.borderlessButton)
    }

    private func modelColor(_ m: ClaudeModel) -> Color {
        switch m {
        case .opus: return Theme.purple
        case .sonnet: return Theme.accent
        case .haiku: return Theme.green
        case .gpt54: return Theme.accent
        case .gpt54Mini: return Theme.cyan
        case .gpt53Codex: return Theme.orange
        case .gpt52Codex: return Theme.orange
        case .gpt52: return Theme.green
        case .gpt51CodexMax: return Theme.red
        case .gpt51CodexMini: return Theme.yellow
        case .gemini25Pro: return Theme.cyan
        case .gemini25Flash: return Theme.green
        }
    }

    private func providerColor(_ provider: AgentProvider) -> Color {
        switch provider {
        case .claude: return Theme.accent
        case .codex: return Theme.orange
        case .gemini: return Theme.cyan
        }
    }

    private func approvalColor(_ m: ApprovalMode) -> Color {
        switch m {
        case .auto: return Theme.yellow
        case .ask: return Theme.orange
        case .safe: return Theme.green
        }
    }

    private func permissionColor(_ m: PermissionMode) -> Color {
        switch m {
        case .acceptEdits: return Theme.green
        case .bypassPermissions: return Theme.yellow
        case .auto: return Theme.cyan
        case .defaultMode: return Theme.orange
        case .plan: return Theme.purple
        }
    }

    private func codexSandboxColor(_ mode: CodexSandboxMode) -> Color {
        switch mode {
        case .readOnly: return Theme.green
        case .workspaceWrite: return Theme.cyan
        case .dangerFullAccess: return Theme.red
        }
    }

    private func codexApprovalColor(_ mode: CodexApprovalPolicy) -> Color {
        switch mode {
        case .untrusted: return Theme.green
        case .onRequest: return Theme.orange
        case .never: return Theme.yellow
        }
    }
}

private struct PlanSelectionRequest {
    public struct Group: Identifiable {
        public let id: String
        public let title: String
        public let options: [Option]
    }

    public struct Option: Identifiable {
        public let id: String
        public let key: String
        public let label: String
    }

    public let signature: String
    public let promptLine: String?
    public let groups: [Group]

    public static func parse(from text: String) -> PlanSelectionRequest? {
        let normalizedText = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedText.isEmpty else { return nil }

        let lowered = normalizedText.lowercased()
        let requestMarkers = ["선호", "선택", "알려주세요", "골라", "정해주세요", "말씀해주세요", "어떤 것", "어떤 방식", "결정", "어떻게 할", "무엇을", "choose", "pick", "prefer", "which one", "which option", "select", "what would you", "would you like", "option"]
        guard requestMarkers.contains(where: { lowered.contains($0) }) else { return nil }

        let lines = normalizedText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var groups: [Group] = []
        var currentTitle: String?
        var currentOptions: [Option] = []

        let flushCurrentGroup: () -> Void = {
            guard let title = currentTitle, currentOptions.count >= 2 else {
                currentTitle = nil
                currentOptions = []
                return
            }
            let index = groups.count + 1
            groups.append(
                Group(
                    id: "plan-group-\(index)",
                    title: title,
                    options: currentOptions
                )
            )
            currentTitle = nil
            currentOptions = []
        }

        for line in lines {
            if let title = parseGroupTitle(from: line) {
                flushCurrentGroup()
                currentTitle = title
                continue
            }

            if let option = parseOption(from: line) {
                if currentTitle == nil {
                    currentTitle = NSLocalizedString("terminal.choice.select", comment: "")
                }
                currentOptions.append(option)
                continue
            }

            if !currentOptions.isEmpty {
                let lastIndex = currentOptions.count - 1
                let last = currentOptions[lastIndex]
                currentOptions[lastIndex] = Option(
                    id: last.id,
                    key: last.key,
                    label: "\(last.label) \(line)"
                )
            }
        }

        flushCurrentGroup()

        guard !groups.isEmpty else { return nil }
        let promptLine = lines.last(where: { line in
            requestMarkers.contains(where: { marker in line.lowercased().contains(marker) })
        })

        return PlanSelectionRequest(
            signature: normalizedText,
            promptLine: promptLine,
            groups: groups
        )
    }

    public func responseText(from selections: [String: String]) -> String {
        let lines = groups.enumerated().compactMap { index, group -> String? in
            guard let selectedKey = selections[group.id],
                  let option = group.options.first(where: { $0.key == selectedKey }) else { return nil }
            return "\(index + 1). \(group.title): \(option.key) - \(option.label)"
        }

        guard lines.count == groups.count else { return "" }
        return """
        플랜 모드 선택:
        \(lines.joined(separator: "\n"))

        이 선택 기준으로 이어서 진행해주세요.
        """
    }

    private static func parseGroupTitle(from line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        guard parts.count == 2 else { return nil }

        let marker = String(parts[0])
        guard marker.count >= 2,
              let last = marker.last,
              last == "." || last == ")" else { return nil }

        let digits = marker.dropLast()
        guard !digits.isEmpty, digits.allSatisfy(\.isNumber) else { return nil }

        let title = String(parts[1])
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: "：", with: "")
        return title.isEmpty ? nil : title
    }

    private static func parseOption(from line: String) -> Option? {
        let trimmed = line
            .replacingOccurrences(of: "•", with: "")
            .replacingOccurrences(of: "-", with: "", options: [], range: line.startIndex..<line.index(line.startIndex, offsetBy: min(1, line.count)))
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmed.count >= 2 else { return nil }

        // Circled numbers: ①, ②, ③ ...
        let circledNumbers: [Character: String] = ["①": "1", "②": "2", "③": "3", "④": "4", "⑤": "5", "⑥": "6", "⑦": "7", "⑧": "8", "⑨": "9"]
        if let first = trimmed.first, let num = circledNumbers[first] {
            let label = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !label.isEmpty else { return nil }
            return Option(id: "plan-option-\(num)-\(label)", key: num, label: label)
        }

        // Parenthesized: (1), (2), (A), (B)
        if trimmed.hasPrefix("("), let closeIdx = trimmed.firstIndex(of: ")") {
            let afterStart = trimmed.index(after: trimmed.startIndex)
            guard afterStart < trimmed.endIndex, afterStart <= closeIdx else { return nil }
            let inner = trimmed[afterStart..<closeIdx]
            guard inner.count >= 1, inner.count <= 2 else { return nil }
            let key = String(inner).uppercased()
            let afterClose = trimmed.index(after: closeIdx)
            guard afterClose <= trimmed.endIndex else { return nil }
            let label = String(trimmed[afterClose...]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !label.isEmpty else { return nil }
            return Option(id: "plan-option-\(key)-\(label)", key: key, label: label)
        }

        guard trimmed.count >= 3 else { return nil }
        let characters = Array(trimmed)
        let marker = characters[0]
        let separator = characters[1]

        // Single letter (A, B...), digit (1, 2...), or Korean marker (가, 나, 다...)
        let koreanOrderMarkers: Set<Character> = ["가", "나", "다", "라", "마"]
        let isValidMarker = marker.isLetter || marker.isNumber || koreanOrderMarkers.contains(marker)
        guard isValidMarker, separator == ")" || separator == "." || separator == ":" else { return nil }

        let key: String
        if marker.isNumber || koreanOrderMarkers.contains(marker) {
            key = String(marker)
        } else {
            key = String(marker).uppercased()
        }
        let label = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !label.isEmpty else { return nil }

        return Option(
            id: "plan-option-\(key)-\(label)",
            key: key,
            label: label
        )
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - Event Block View
// ═══════════════════════════════════════════════════════

public struct EventBlockView: View {
    var block: StreamBlock
    @StateObject private var settings = AppSettings.shared
    public let compact: Bool

    public var body: some View {
        switch block.blockType {
        case .sessionStart:
            sessionStartBlock
        case .userPrompt:
            userPromptBlock
        case .thought:
            thoughtBlock
        case .toolUse(let name, _):
            toolUseBlock(name: name)
        case .toolOutput:
            toolOutputBlock
        case .toolError:
            toolErrorBlock
        case .toolEnd(let success):
            toolEndBlock(success: success)
        case .fileChange(_, let action):
            fileChangeBlock(action: action)
        case .status(let msg):
            statusBlock(msg)
        case .completion(let cost, let duration):
            completionBlock(cost: cost, duration: duration)
        case .error(let msg):
            errorBlock(msg)
        case .text:
            textBlock
        }
    }

    // MARK: - Block Styles

    private var sessionStartBlock: some View {
        HStack(spacing: 6) {
            Image(systemName: "play.circle.fill").font(.system(size: Theme.iconSize(10))).foregroundColor(Theme.green)
            Text(block.content).font(Theme.monoSmall).foregroundColor(Theme.textSecondary)
        }
        .padding(.vertical, 4)
    }

    private var userPromptBlock: some View {
        HStack(alignment: .top, spacing: 6) {
            Text(">").font(Theme.mono(13, weight: .bold)).foregroundStyle(Theme.accentBackground)
            Text(block.content).font(Theme.mono(compact ? 11 : 13)).foregroundStyle(Theme.accentBackground)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 6).padding(.horizontal, 8)
        .background(RoundedRectangle(cornerRadius: 6).fill(Theme.accent.opacity(0.06)))
    }

    private var thoughtBlock: some View {
        HStack(alignment: .top, spacing: 6) {
            Circle().fill(Theme.textDim).frame(width: 4, height: 4).padding(.top, 6)
            MarkdownTextView(text: block.content, compact: compact)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }.padding(.vertical, 2)
    }

    private func toolUseBlock(name: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(toolColor(name)).frame(width: 6, height: 6)
            Text("\(name)").font(Theme.mono(compact ? 10 : 11, weight: .bold)).foregroundColor(toolColor(name))
            Text("(\(block.content))").font(Theme.mono(compact ? 10 : 11)).foregroundColor(Theme.textSecondary).lineLimit(1)
            if !block.isComplete { ProgressView().scaleEffect(0.4).frame(width: 10, height: 10) }
        }
        .padding(.vertical, 4).padding(.horizontal, 6)
        .background(RoundedRectangle(cornerRadius: 6).fill(toolColor(name).opacity(0.06)))
    }

    private var toolOutputBlock: some View {
        ToolOutputBlockView(block: block, compact: compact)
    }

    private var toolErrorBlock: some View {
        HStack(alignment: .top, spacing: 0) {
            Text("  x ").font(Theme.mono(11)).foregroundColor(Theme.red)
            Text(block.content)
                .font(Theme.mono(compact ? 10 : 11))
                .foregroundColor(Theme.red)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.leading, 8)
        .background(Theme.red.opacity(0.04))
    }

    private func toolEndBlock(success: Bool) -> some View {
        HStack(spacing: 4) {
            Image(systemName: success ? "checkmark" : "xmark")
                .font(Theme.mono(8, weight: .bold))
                .foregroundColor(success ? Theme.green : Theme.red)
        }
        .padding(.leading, 16).padding(.vertical, 1)
    }

    private func fileChangeBlock(action: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: action == "Write" ? "doc.badge.plus" : "pencil.line")
                .font(.system(size: Theme.iconSize(9))).foregroundColor(Theme.green)
            Text(action).font(Theme.mono(10, weight: .semibold)).foregroundColor(Theme.green)
            Text(block.content).font(Theme.mono(compact ? 10 : 11)).foregroundColor(Theme.textPrimary)
        }
        .padding(.vertical, 3).padding(.horizontal, 6)
        .background(RoundedRectangle(cornerRadius: 6).fill(Theme.green.opacity(0.06)))
    }

    private func statusBlock(_ msg: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "info.circle").font(.system(size: Theme.iconSize(7))).foregroundColor(Theme.textDim)
            Text(msg).font(Theme.monoTiny).foregroundColor(Theme.textDim).italic()
        }.padding(.vertical, 1)
    }

    private func completionBlock(cost: Double?, duration: Int?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill").font(.system(size: Theme.iconSize(10))).foregroundColor(Theme.green)
                Text(NSLocalizedString("terminal.complete", comment: "")).font(Theme.mono(10, weight: .bold)).foregroundColor(Theme.green)
                if let d = duration {
                    Text("\(d/1000).\(d%1000/100)s").font(Theme.mono(8)).foregroundColor(Theme.textDim)
                }
                if let c = cost, c > 0 {
                    Text(String(format: "$%.4f", c)).font(Theme.mono(8, weight: .semibold)).foregroundColor(Theme.yellow)
                }
            }

            if !block.content.isEmpty && block.content != NSLocalizedString("slash.status.completed", comment: "") {
                MarkdownTextView(text: block.content, compact: compact)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
        }
        .padding(.vertical, 5).padding(.horizontal, 8)
    }

    private func errorBlock(_ msg: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill").font(.system(size: Theme.iconSize(10))).foregroundColor(Theme.red)
            Text(msg).font(Theme.mono(11)).foregroundColor(Theme.red)
            if !block.content.isEmpty { Text(block.content).font(Theme.monoSmall).foregroundColor(Theme.red.opacity(0.7)) }
        }
        .padding(.vertical, 4).padding(.horizontal, 6)
        .background(RoundedRectangle(cornerRadius: 6).fill(Theme.red.opacity(0.05)))
    }

    private var textBlock: some View {
        Text(block.content).font(Theme.mono(compact ? 11 : 12)).foregroundColor(Theme.textTerminal)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func toolColor(_ name: String) -> Color {
        switch name {
        case "Bash": return Theme.yellow
        case "Read": return Theme.accent
        case "Write", "Edit": return Theme.green
        case "Grep", "Glob": return Theme.cyan
        case "Agent": return Theme.purple
        default: return Theme.textSecondary
        }
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - Tool Output Block View (truncated)
// ═══════════════════════════════════════════════════════

public struct ToolOutputBlockView: View {
    var block: StreamBlock
    public let compact: Bool
    private let maxCollapsedLines = 12

    @State private var isExpanded = false

    private var lines: [String] {
        block.content.components(separatedBy: "\n")
    }

    private var isTruncatable: Bool {
        lines.count > maxCollapsedLines
    }

    private var displayText: String {
        if isExpanded || !isTruncatable {
            return block.content
        }
        if lines.count > 100 {
            let head = lines.prefix(3)
            let tail = lines.suffix(3)
            let hidden = lines.count - 6
            return (head + [String(format: NSLocalizedString("terminal.lines.omitted", comment: ""), hidden)] + tail).joined(separator: "\n")
        }
        let head = lines.prefix(6)
        let tail = lines.suffix(4)
        let hidden = lines.count - 10
        return (head + [String(format: NSLocalizedString("terminal.lines.omitted", comment: ""), hidden)] + tail).joined(separator: "\n")
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                Text("  | ").font(Theme.mono(11)).foregroundColor(Theme.textDim)
                Text(displayText)
                    .font(Theme.mono(compact ? 10 : 11))
                    .foregroundColor(Theme.textTerminal)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }.padding(.leading, 8)

            if isTruncatable {
                Button(action: { isExpanded.toggle() }) {
                    HStack(spacing: 4) {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: Theme.iconSize(7)))
                        Text(isExpanded ? NSLocalizedString("terminal.collapse", comment: "") : String(format: NSLocalizedString("terminal.expand.all", comment: ""), lines.count))
                            .font(Theme.mono(9))
                    }
                    .foregroundColor(Theme.textDim)
                    .padding(.leading, 28)
                    .padding(.vertical, 2)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - Markdown Text View
// ═══════════════════════════════════════════════════════

public struct MarkdownTextView: View {
    public let text: String
    public let compact: Bool

    public init(text: String, compact: Bool = false) {
        self.text = text
        self.compact = compact
    }

    // Pre-compiled regex patterns (avoid recompilation on every inlineMarkdown call)
    private static let boldRegex = try? NSRegularExpression(pattern: "\\*\\*(.+?)\\*\\*")
    private static let codeRegex = try? NSRegularExpression(pattern: "`([^`]+)`")

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(parseBlocks().enumerated()), id: \.offset) { _, mdBlock in
                switch mdBlock {
                case .heading(let level, let content):
                    Text(content)
                        .font(Theme.mono(headingSize(level), weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                        .padding(.top, level <= 2 ? 6 : 3)
                case .codeBlock(let code):
                    Text(code)
                        .font(Theme.mono(compact ? 10 : 11))
                        .foregroundColor(Theme.cyan)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Theme.bg))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.border, lineWidth: 1))
                        .textSelection(.enabled)
                case .bullet(let content):
                    HStack(alignment: .top, spacing: 6) {
                        Text("•").font(Theme.mono(compact ? 10 : 11)).foregroundStyle(Theme.accentBackground)
                            .frame(width: 10)
                        inlineMarkdown(content)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                case .separator:
                    Rectangle().fill(Theme.border).frame(height: 1).padding(.vertical, 4)
                case .table(let rows):
                    tableView(rows)
                case .paragraph(let content):
                    inlineMarkdown(content)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    // MARK: - Inline markdown (bold, code, italic)

    private func inlineMarkdown(_ text: String) -> Text {
        var result = Text("")
        let nsText = text as NSString
        var pos = 0

        while pos < nsText.length {
            let searchRange = NSRange(location: pos, length: nsText.length - pos)

            // Find earliest match of either pattern
            let boldMatch = Self.boldRegex?.firstMatch(in: text, range: searchRange)
            let codeMatch = Self.codeRegex?.firstMatch(in: text, range: searchRange)

            // Pick whichever comes first
            let match: NSTextCheckingResult?
            let isBold: Bool
            if let b = boldMatch, let c = codeMatch {
                if b.range.location <= c.range.location {
                    match = b; isBold = true
                } else {
                    match = c; isBold = false
                }
            } else if let b = boldMatch {
                match = b; isBold = true
            } else if let c = codeMatch {
                match = c; isBold = false
            } else {
                match = nil; isBold = false
            }

            guard let m = match else {
                // No more matches — emit rest as plain text
                let rest = nsText.substring(from: pos)
                result = result + Text(rest).font(Theme.mono(compact ? 11 : 12)).foregroundColor(Theme.textSecondary)
                break
            }

            // Emit text before the match
            if m.range.location > pos {
                let before = nsText.substring(with: NSRange(location: pos, length: m.range.location - pos))
                result = result + Text(before).font(Theme.mono(compact ? 11 : 12)).foregroundColor(Theme.textSecondary)
            }

            // Emit the matched content (capture group 1)
            let inner = nsText.substring(with: m.range(at: 1))
            if isBold {
                result = result + Text(inner).font(Theme.mono(compact ? 11 : 12, weight: .bold)).foregroundColor(Theme.textPrimary)
            } else {
                result = result + Text(inner).font(Theme.mono(compact ? 10 : 11)).foregroundColor(Theme.cyan)
            }

            pos = m.range.location + m.range.length
        }
        return result
    }

    // MARK: - Table

    private func tableView(_ rows: [[String]]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { rowIdx, row in
                HStack(spacing: 0) {
                    ForEach(Array(row.enumerated()), id: \.offset) { colIdx, cell in
                        Text(cell.trimmingCharacters(in: .whitespaces))
                            .font(Theme.mono(compact ? 9 : 10, weight: rowIdx == 0 ? .bold : .regular))
                            .foregroundColor(rowIdx == 0 ? Theme.textPrimary : Theme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 6).padding(.vertical, 3)
                        if colIdx < row.count - 1 {
                            Rectangle().fill(Theme.border.opacity(0.3)).frame(width: 1)
                        }
                    }
                }
                if rowIdx == 0 {
                    Rectangle().fill(Theme.border).frame(height: 1)
                } else if rowIdx < rows.count - 1 {
                    Rectangle().fill(Theme.border.opacity(0.3)).frame(height: 1)
                }
            }
        }
        .background(RoundedRectangle(cornerRadius: 6).fill(Theme.bgSurface.opacity(0.5)))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.border, lineWidth: 1))
    }

    // MARK: - Block Parser

    private enum MdBlock {
        case heading(Int, String)
        case codeBlock(String)
        case bullet(String)
        case separator
        case table([[String]])
        case paragraph(String)
    }

    private func headingSize(_ level: Int) -> CGFloat {
        switch level {
        case 1: return compact ? 14 : 16
        case 2: return compact ? 13 : 14
        case 3: return compact ? 12 : 13
        default: return compact ? 11 : 12
        }
    }

    private func parseBlocks() -> [MdBlock] {
        let lines = text.components(separatedBy: "\n")
        var blocks: [MdBlock] = []
        var i = 0

        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Code block
            if trimmed.hasPrefix("```") {
                var code: [String] = []
                i += 1
                while i < lines.count && !lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                    code.append(lines[i])
                    i += 1
                }
                blocks.append(.codeBlock(code.joined(separator: "\n")))
                i += 1
                continue
            }

            // Heading
            if trimmed.hasPrefix("###") {
                blocks.append(.heading(3, String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)))
                i += 1; continue
            }
            if trimmed.hasPrefix("##") {
                blocks.append(.heading(2, String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)))
                i += 1; continue
            }
            if trimmed.hasPrefix("#") {
                blocks.append(.heading(1, String(trimmed.dropFirst(1)).trimmingCharacters(in: .whitespaces)))
                i += 1; continue
            }

            // Separator
            if trimmed.hasPrefix("---") || trimmed.hasPrefix("***") {
                blocks.append(.separator)
                i += 1; continue
            }

            // Table (detect | at start)
            if trimmed.hasPrefix("|") && trimmed.contains("|") {
                var tableRows: [[String]] = []
                while i < lines.count {
                    let tl = lines[i].trimmingCharacters(in: .whitespaces)
                    guard tl.hasPrefix("|") else { break }
                    // skip separator rows like |---|---|
                    if tl.contains("---") { i += 1; continue }
                    let cells = tl.components(separatedBy: "|").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                    if !cells.isEmpty { tableRows.append(cells) }
                    i += 1
                }
                if !tableRows.isEmpty { blocks.append(.table(tableRows)) }
                continue
            }

            // Bullet
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                let content = String(trimmed.dropFirst(2))
                blocks.append(.bullet(content))
                i += 1; continue
            }

            // Empty line
            if trimmed.isEmpty {
                i += 1; continue
            }

            // Paragraph (collect consecutive non-empty lines)
            var para: [String] = [line]
            i += 1
            while i < lines.count {
                let next = lines[i].trimmingCharacters(in: .whitespaces)
                if next.isEmpty || next.hasPrefix("#") || next.hasPrefix("```") || next.hasPrefix("|") || next.hasPrefix("- ") || next.hasPrefix("* ") || next.hasPrefix("---") { break }
                para.append(lines[i])
                i += 1
            }
            blocks.append(.paragraph(para.joined(separator: "\n")))
        }
        return blocks
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - Processing Indicator
// ═══════════════════════════════════════════════════════

public struct ProcessingIndicator: View {
    public let activity: ClaudeActivity
    public let workerColor: Color
    public let workerName: String
    @StateObject private var settings = AppSettings.shared
    @State private var dotPhase = 0
    public let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()

    public var body: some View {
        HStack(spacing: 6) {
            Circle().fill(workerColor).frame(width: 8, height: 8)
            Text(workerName).font(Theme.chrome(10, weight: .semibold)).foregroundColor(workerColor)
            Text(statusText).font(Theme.chrome(10)).foregroundColor(Theme.textDim)
            HStack(spacing: 2) {
                ForEach(0..<3, id: \.self) { i in
                    Circle().fill(Theme.textDim)
                        .frame(width: 3, height: 3)
                        .opacity(i <= dotPhase ? 0.8 : 0.2)
                }
            }
        }
        .padding(.vertical, 4)
        .onReceive(timer) { _ in dotPhase = (dotPhase + 1) % 3 }
    }

    private var statusText: String {
        switch activity {
        case .thinking: return NSLocalizedString("terminal.status.thinking", comment: "")
        case .reading: return NSLocalizedString("terminal.status.reading", comment: "")
        case .writing: return NSLocalizedString("terminal.status.writing", comment: "")
        case .searching: return NSLocalizedString("terminal.status.searching", comment: "")
        case .running: return NSLocalizedString("terminal.status.running", comment: "")
        default: return NSLocalizedString("misc.processing", comment: "")
        }
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - Grid Panel View
// ═══════════════════════════════════════════════════════

public struct GridPanelView: View {
    @EnvironmentObject var manager: SessionManager
    @StateObject private var settings = AppSettings.shared

    private var hasPinnedTabs: Bool { !manager.pinnedTabIds.isEmpty }

    private var pinnedTabs: [TerminalTab] {
        manager.userVisibleTabs.filter { manager.pinnedTabIds.contains($0.id) }
    }

    private var visibleGroups: [SessionManager.ProjectGroup] {
        if let selectedPath = manager.selectedGroupPath {
            let tabs = manager.visibleTabs
            guard let first = tabs.first else { return [] }
            return [SessionManager.ProjectGroup(id: selectedPath, projectName: first.projectName, tabs: tabs, hasActiveTab: tabs.contains(where: { $0.id == manager.activeTabId }))]
        }
        return manager.projectGroups
    }

    private var isFiltered: Bool { manager.selectedGroupPath != nil }

    public var body: some View {
        if manager.visibleTabs.isEmpty {
            EmptySessionView()
        } else if hasPinnedTabs {
            // ── Pinned multi-select grid (최우선) ──
            pinnedGridView
        } else if manager.focusSingleTab, let tab = manager.activeTab {
            EventStreamView(tab: tab, compact: false)
        } else {
            defaultGridView
        }
    }

    // Pinned tabs grid: show only selected tabs
    private var pinnedGridView: some View {
        let tabs = pinnedTabs
        let cols = tabs.count <= 1 ? 1 : tabs.count <= 4 ? 2 : 3
        return GeometryReader { geo in
            let totalH = geo.size.height
            let rows = max(1, Int(ceil(Double(tabs.count) / Double(cols))))
            let cellH = max(120, (totalH - CGFloat(rows + 1) * 6) / CGFloat(rows))
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: cols), spacing: 6) {
                    ForEach(tabs) { tab in
                        GridSinglePanel(tab: tab, isSelected: manager.activeTabId == tab.id)
                            .frame(height: cellH)
                            .onTapGesture { manager.focusSingleTab = true; manager.selectTab(tab.id) }
                    }
                }.padding(6)
            }.background(Theme.bg)
        }
    }

    // Default grid: show groups
    private var defaultGridView: some View {
        let groups = visibleGroups
        let tabCount = groups.reduce(0) { $0 + $1.tabs.count }
        let cols = tabCount <= 1 ? 1 : tabCount <= 4 ? 2 : 3
        return GeometryReader { geo in
            let totalH = geo.size.height
            let rows = max(1, Int(ceil(Double(tabCount) / Double(cols))))
            let cellH = max(120, (totalH - CGFloat(rows + 1) * 6) / CGFloat(rows))
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: cols), spacing: 6) {
                    ForEach(groups) { group in
                        if isFiltered && group.tabs.count > 1 {
                            ForEach(group.tabs) { tab in
                                GridSinglePanel(tab: tab, isSelected: manager.activeTabId == tab.id)
                                    .frame(height: cellH)
                                    .onTapGesture { manager.focusSingleTab = true; manager.selectTab(tab.id) }
                            }
                        } else {
                            GridGroupPanel(group: group)
                                .frame(height: cellH)
                        }
                    }
                }.padding(6)
            }.background(Theme.bg)
        }
    }
}

// 선택된 그룹 내 개별 탭 패널
public struct GridSinglePanel: View {
    @ObservedObject var tab: TerminalTab
    @StateObject private var settings = AppSettings.shared
    public let isSelected: Bool

    public var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 1).fill(tab.workerColor).frame(width: 3, height: 12)
                Text(tab.workerName).font(Theme.chrome(9, weight: .bold)).foregroundColor(tab.workerColor)
                Text(tab.projectName).font(Theme.chrome(9)).foregroundColor(Theme.textSecondary).lineLimit(1)
                Spacer()
                if tab.isProcessing { ProgressView().scaleEffect(0.35).frame(width: 8, height: 8) }
                Text(tab.selectedModel.icon).font(Theme.chrome(9))
            }
            .padding(.horizontal, 6).padding(.vertical, 4)
            .background(isSelected ? Theme.bgSelected : Theme.bgCard)

            EventStreamView(tab: tab, compact: true)
        }
        .background(RoundedRectangle(cornerRadius: 8).fill(Theme.bgCard))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(isSelected ? Theme.accent.opacity(0.5) : Theme.border, lineWidth: 1))
    }
}

public struct GridGroupPanel: View {
    public let group: SessionManager.ProjectGroup
    @EnvironmentObject var manager: SessionManager
    @StateObject private var settings = AppSettings.shared
    @State private var selectedWorkerIndex = 0

    private var activeTab: TerminalTab? {
        guard !group.tabs.isEmpty else { return nil }
        let idx = min(max(0, selectedWorkerIndex), group.tabs.count - 1)
        return group.tabs[idx]
    }

    public var body: some View {
        Group {
            if let activeTab = activeTab {
                VStack(spacing: 0) {
                    // Header: project name + worker tabs
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 1).fill(activeTab.workerColor).frame(width: 3, height: 12)
                        Text(group.projectName).font(Theme.chrome(10, weight: .semibold)).foregroundColor(Theme.textPrimary).lineLimit(1)
                        Spacer()

                        if group.tabs.count > 1 {
                            HStack(spacing: 2) {
                                ForEach(Array(group.tabs.enumerated()), id: \.element.id) { i, tab in
                                    Button(action: { selectedWorkerIndex = i; manager.selectTab(tab.id) }) {
                                        Text(tab.workerName).font(Theme.chrome(7, weight: selectedWorkerIndex == i ? .bold : .regular))
                                            .foregroundColor(selectedWorkerIndex == i ? tab.workerColor : Theme.textDim)
                                            .padding(.horizontal, 4).padding(.vertical, 2)
                                            .background(selectedWorkerIndex == i ? tab.workerColor.opacity(0.1) : .clear)
                                            .cornerRadius(3)
                                    }.buttonStyle(.plain)
                                }
                            }
                        }

                        if activeTab.isProcessing { ProgressView().scaleEffect(0.35).frame(width: 8, height: 8) }
                        Text(activeTab.selectedModel.icon).font(Theme.chrome(9))
                    }

                    .padding(.horizontal, 6).padding(.vertical, 4)
                    .background(group.hasActiveTab ? Theme.bgSelected : Theme.bgCard)

                    EventStreamView(tab: activeTab, compact: true)
                }
                .background(RoundedRectangle(cornerRadius: 8).fill(Theme.bgCard))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(group.hasActiveTab ? Theme.accent.opacity(0.5) : Theme.border, lineWidth: 1))
                .onTapGesture { manager.selectTab(activeTab.id) }
            } else {
                EmptyView()
            }
        }
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - [Feature 5] Approval Sheet
// ═══════════════════════════════════════════════════════

public struct ApprovalSheet: View {
    public let approval: TerminalTab.PendingApproval
    @Environment(\.dismiss) var dismiss

    public var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.shield.fill").font(.system(size: Theme.iconSize(20))).foregroundColor(Theme.yellow)
                Text(NSLocalizedString("terminal.approval.needed", comment: "")).font(Theme.mono(14, weight: .bold)).foregroundColor(Theme.textPrimary)
            }
            Text(approval.reason).font(Theme.monoSmall).foregroundColor(Theme.textSecondary)
            Text(approval.command).font(Theme.mono(11)).foregroundColor(Theme.red)
                .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 6).fill(Theme.red.opacity(0.05)))
                .textSelection(.enabled)
            HStack {
                Button(action: { approval.onDeny?(); dismiss() }) {
                    Text(NSLocalizedString("terminal.deny", comment: "")).font(Theme.mono(11, weight: .medium)).foregroundColor(Theme.red)
                        .padding(.horizontal, 20).padding(.vertical, 8)
                        .background(Theme.red.opacity(0.1)).cornerRadius(6)
                }.buttonStyle(.plain).keyboardShortcut(.escape)
                Spacer()
                Button(action: { approval.onApprove?(); dismiss() }) {
                    Text(NSLocalizedString("terminal.approve", comment: "")).font(Theme.mono(11, weight: .medium)).foregroundColor(Theme.textOnAccent)
                        .padding(.horizontal, 20).padding(.vertical, 8)
                        .background(Theme.accent).cornerRadius(6)
                }.buttonStyle(.plain).keyboardShortcut(.return)
            }
        }.padding(24).frame(width: 420).background(Theme.bgCard)
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - Supporting Views
// ═══════════════════════════════════════════════════════

public struct EmptySessionView: View {
    @StateObject private var settings = AppSettings.shared
    public var body: some View {
        VStack {
            Spacer()
            AppEmptyStateView(
                title: NSLocalizedString("terminal.no.session.title", comment: ""),
                message: NSLocalizedString("terminal.no.session.message", comment: ""),
                symbol: "plus.circle.fill",
                tint: Theme.accent
            )
            .padding(.horizontal, 24)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Theme.bgTerminal)
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - New Tab Sheet (멀티 터미널 지원)
// ═══════════════════════════════════════════════════════

public struct NewSessionProjectRecord: Codable, Identifiable, Hashable {
    public let path: String
    public var name: String
    public var lastUsedAt: Date
    public var isFavorite: Bool

    public var id: String { path }
}

public struct NewSessionDraftSnapshot: Codable {
    public var selectedModel: String
    public var effortLevel: String
    public var permissionMode: String
    public var codexSandboxMode: String
    public var codexApprovalPolicy: String
    public var terminalCount: Int
    public var systemPrompt: String
    public var maxBudget: String
    public var allowedTools: String
    public var disallowedTools: String
    public var additionalDirs: [String]
    public var continueSession: Bool
    public var useWorktree: Bool

    public init(
        selectedModel: String,
        effortLevel: String,
        permissionMode: String,
        codexSandboxMode: String = CodexSandboxMode.workspaceWrite.rawValue,
        codexApprovalPolicy: String = CodexApprovalPolicy.onRequest.rawValue,
        terminalCount: Int,
        systemPrompt: String,
        maxBudget: String,
        allowedTools: String,
        disallowedTools: String,
        additionalDirs: [String],
        continueSession: Bool,
        useWorktree: Bool
    ) {
        self.selectedModel = selectedModel
        self.effortLevel = effortLevel
        self.permissionMode = permissionMode
        self.codexSandboxMode = codexSandboxMode
        self.codexApprovalPolicy = codexApprovalPolicy
        self.terminalCount = terminalCount
        self.systemPrompt = systemPrompt
        self.maxBudget = maxBudget
        self.allowedTools = allowedTools
        self.disallowedTools = disallowedTools
        self.additionalDirs = additionalDirs
        self.continueSession = continueSession
        self.useWorktree = useWorktree
    }

    private enum CodingKeys: String, CodingKey {
        case selectedModel
        case effortLevel
        case permissionMode
        case codexSandboxMode
        case codexApprovalPolicy
        case terminalCount
        case systemPrompt
        case maxBudget
        case allowedTools
        case disallowedTools
        case additionalDirs
        case continueSession
        case useWorktree
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        selectedModel = try container.decode(String.self, forKey: .selectedModel)
        effortLevel = try container.decode(String.self, forKey: .effortLevel)
        permissionMode = try container.decode(String.self, forKey: .permissionMode)
        codexSandboxMode = try container.decodeIfPresent(String.self, forKey: .codexSandboxMode) ?? CodexSandboxMode.workspaceWrite.rawValue
        codexApprovalPolicy = try container.decodeIfPresent(String.self, forKey: .codexApprovalPolicy) ?? CodexApprovalPolicy.onRequest.rawValue
        terminalCount = try container.decode(Int.self, forKey: .terminalCount)
        systemPrompt = try container.decode(String.self, forKey: .systemPrompt)
        maxBudget = try container.decode(String.self, forKey: .maxBudget)
        allowedTools = try container.decode(String.self, forKey: .allowedTools)
        disallowedTools = try container.decode(String.self, forKey: .disallowedTools)
        additionalDirs = try container.decode([String].self, forKey: .additionalDirs)
        continueSession = try container.decode(Bool.self, forKey: .continueSession)
        useWorktree = try container.decode(Bool.self, forKey: .useWorktree)
    }
}

private enum NewSessionPreset: String, CaseIterable, Identifiable {
    case balanced
    case planFirst
    case safeReview
    case parallelBuild

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .balanced: return NSLocalizedString("terminal.preset.balanced", comment: "")
        case .planFirst: return NSLocalizedString("terminal.preset.planfirst", comment: "")
        case .safeReview: return NSLocalizedString("terminal.preset.safereview", comment: "")
        case .parallelBuild: return NSLocalizedString("terminal.preset.parallelbuild", comment: "")
        }
    }

    public var subtitle: String {
        switch self {
        case .balanced: return NSLocalizedString("terminal.preset.balanced.desc", comment: "")
        case .planFirst: return NSLocalizedString("terminal.preset.planfirst.desc", comment: "")
        case .safeReview: return NSLocalizedString("terminal.preset.safereview.desc", comment: "")
        case .parallelBuild: return NSLocalizedString("terminal.preset.parallelbuild.desc", comment: "")
        }
    }

    public var tint: Color {
        switch self {
        case .balanced: return Theme.accent
        case .planFirst: return Theme.purple
        case .safeReview: return Theme.orange
        case .parallelBuild: return Theme.cyan
        }
    }

    public var symbol: String {
        switch self {
        case .balanced: return "hammer.fill"
        case .planFirst: return "list.bullet.clipboard.fill"
        case .safeReview: return "shield.fill"
        case .parallelBuild: return "square.grid.3x1.folder.badge.plus"
        }
    }
}

public final class NewSessionPreferencesStore: ObservableObject {
    public static let shared = NewSessionPreferencesStore()

    @Published public private(set) var favoriteProjects: [NewSessionProjectRecord] = []
    @Published public private(set) var recentProjects: [NewSessionProjectRecord] = []
    @Published public private(set) var lastDraft: NewSessionDraftSnapshot?
    @Published public private(set) var trustedProjectPaths: [String] = []

    private let favoritesKey = "doffice.new-session.favorite-projects"
    private let recentsKey = "doffice.new-session.recent-projects"
    private let lastDraftKey = "doffice.new-session.last-draft"
    private let trustedProjectPathsKey = "doffice.new-session.trusted-project-paths"

    private init() {
        load()
    }

    public func isFavorite(path: String) -> Bool {
        favoriteProjects.contains(where: { $0.path == path })
    }

    public func toggleFavorite(projectName: String, projectPath: String) {
        guard !projectPath.isEmpty else { return }

        if let index = favoriteProjects.firstIndex(where: { $0.path == projectPath }) {
            favoriteProjects.remove(at: index)
        } else {
            favoriteProjects.insert(
                NewSessionProjectRecord(path: projectPath, name: projectName.isEmpty ? (projectPath as NSString).lastPathComponent : projectName, lastUsedAt: Date(), isFavorite: true),
                at: 0
            )
        }
        favoriteProjects = dedupeProjects(favoriteProjects).prefixArray(8)
        saveFavorites()
    }

    public func suggestedProjects(currentTabs: [TerminalTab], savedSessions: [SavedSession]) -> [NewSessionProjectRecord] {
        var merged: [String: NewSessionProjectRecord] = [:]

        for favorite in favoriteProjects {
            merged[favorite.path] = favorite
        }

        for recent in recentProjects {
            mergeProject(into: &merged, project: recent)
        }

        for tab in currentTabs {
            let record = NewSessionProjectRecord(
                path: tab.projectPath,
                name: tab.projectName,
                lastUsedAt: tab.lastActivityTime,
                isFavorite: isFavorite(path: tab.projectPath)
            )
            mergeProject(into: &merged, project: record)
        }

        for session in savedSessions {
            let record = NewSessionProjectRecord(
                path: session.projectPath,
                name: session.projectName,
                lastUsedAt: session.lastActivityTime ?? session.startTime,
                isFavorite: isFavorite(path: session.projectPath)
            )
            mergeProject(into: &merged, project: record)
        }

        return merged.values.sorted { lhs, rhs in
            if lhs.isFavorite != rhs.isFavorite { return lhs.isFavorite && !rhs.isFavorite }
            if lhs.lastUsedAt != rhs.lastUsedAt { return lhs.lastUsedAt > rhs.lastUsedAt }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    public func rememberLaunch(projectName: String, projectPath: String, draft: NewSessionDraftSnapshot) {
        guard !projectPath.isEmpty else { return }

        let record = NewSessionProjectRecord(
            path: projectPath,
            name: projectName,
            lastUsedAt: Date(),
            isFavorite: isFavorite(path: projectPath)
        )
        recentProjects.removeAll(where: { $0.path == projectPath })
        recentProjects.insert(record, at: 0)
        recentProjects = dedupeProjects(recentProjects).prefixArray(10)
        lastDraft = draft
        saveRecents()
        saveLastDraft()
    }

    public func isTrusted(projectPath: String) -> Bool {
        let normalized = normalizeProjectPath(projectPath)
        guard !normalized.isEmpty else { return true }
        return trustedProjectPaths.contains(where: {
            normalized == $0 || normalized.hasPrefix($0 + "/")
        })
    }

    public func trust(projectPath: String) {
        let normalized = normalizeProjectPath(projectPath)
        guard !normalized.isEmpty else { return }

        if trustedProjectPaths.contains(where: { normalized == $0 || normalized.hasPrefix($0 + "/") }) {
            return
        }

        trustedProjectPaths.removeAll { $0.hasPrefix(normalized + "/") }
        trustedProjectPaths.insert(normalized, at: 0)
        trustedProjectPaths = Array(trustedProjectPaths.prefix(64))
        saveTrustedProjectPaths()
    }

    private func mergeProject(into merged: inout [String: NewSessionProjectRecord], project: NewSessionProjectRecord) {
        if let existing = merged[project.path] {
            let preferredName = existing.name.count >= project.name.count ? existing.name : project.name
            merged[project.path] = NewSessionProjectRecord(
                path: project.path,
                name: preferredName,
                lastUsedAt: max(existing.lastUsedAt, project.lastUsedAt),
                isFavorite: existing.isFavorite || project.isFavorite
            )
        } else {
            merged[project.path] = project
        }
    }

    private func dedupeProjects(_ projects: [NewSessionProjectRecord]) -> [NewSessionProjectRecord] {
        var seen = Set<String>()
        return projects.filter { project in
            seen.insert(project.path).inserted
        }
    }

    private func normalizeProjectPath(_ rawPath: String) -> String {
        let trimmed = rawPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        let expanded = NSString(string: trimmed).expandingTildeInPath
        let baseURL = URL(fileURLWithPath: expanded, isDirectory: true)
        let standardized = baseURL.standardizedFileURL.path
        // resolvingSymlinksInPath can crash on non-existent paths
        guard FileManager.default.fileExists(atPath: standardized) else { return standardized }
        return baseURL.standardizedFileURL.resolvingSymlinksInPath().path
    }

    private func load() {
        let decoder = JSONDecoder()
        if let data = UserDefaults.standard.data(forKey: favoritesKey),
           let decoded = try? decoder.decode([NewSessionProjectRecord].self, from: data) {
            favoriteProjects = decoded
        }
        if let data = UserDefaults.standard.data(forKey: recentsKey),
           let decoded = try? decoder.decode([NewSessionProjectRecord].self, from: data) {
            recentProjects = decoded
        }
        if let data = UserDefaults.standard.data(forKey: lastDraftKey),
           let decoded = try? decoder.decode(NewSessionDraftSnapshot.self, from: data) {
            lastDraft = decoded
        }
        if let storedPaths = UserDefaults.standard.array(forKey: trustedProjectPathsKey) as? [String] {
            trustedProjectPaths = storedPaths
                .map(normalizeProjectPath)
                .filter { !$0.isEmpty }
        }
    }

    private func saveFavorites() {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(favoriteProjects) {
            UserDefaults.standard.set(data, forKey: favoritesKey)
        }
    }

    private func saveRecents() {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(recentProjects) {
            UserDefaults.standard.set(data, forKey: recentsKey)
        }
    }

    private func saveLastDraft() {
        let encoder = JSONEncoder()
        if let draft = lastDraft, let data = try? encoder.encode(draft) {
            UserDefaults.standard.set(data, forKey: lastDraftKey)
        }
    }

    private func saveTrustedProjectPaths() {
        UserDefaults.standard.set(trustedProjectPaths, forKey: trustedProjectPathsKey)
    }
}

private extension Array {
    func prefixArray(_ maxCount: Int) -> [Element] {
        Array(prefix(maxCount))
    }
}

public struct NewTabSheet: View {
    public init() {}
    @EnvironmentObject var manager: SessionManager; @Environment(\.dismiss) var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var settings = AppSettings.shared
    @StateObject private var preferences = NewSessionPreferencesStore.shared
    @State private var projectName = ""
    @State private var projectPath = ""
    @State private var terminalCount = 1
    @State private var tasks: [String] = [""]

    @State private var showTrustPrompt = false
    @State private var didBootstrap = false
    @State private var pathError: String?
    @State private var isCreatingSessions = false

    // 고급 옵션
    @State private var showAdvanced = false
    @State private var permissionMode: PermissionMode = .bypassPermissions
    @State private var systemPrompt = ""
    @State private var maxBudget: String = ""
    @State private var allowedTools = ""
    @State private var disallowedTools = ""
    @State private var additionalDir = ""
    @State private var additionalDirs: [String] = []
    @State private var continueSession = false
    @State private var useWorktree = false
    @State private var showSavePreset = false
    @State private var activePresetId: String?
    @State private var unavailableProviderAlert: AgentProvider?
    @State private var selectedModel: ClaudeModel = .sonnet
    @State private var effortLevel: EffortLevel = .medium
    @State private var codexSandboxMode: CodexSandboxMode = .workspaceWrite
    @State private var codexApprovalPolicy: CodexApprovalPolicy = .onRequest

    private var suggestedProjects: [NewSessionProjectRecord] {
        preferences.suggestedProjects(currentTabs: manager.userVisibleTabs, savedSessions: SessionStore.shared.load())
    }

    private var favoriteProjects: [NewSessionProjectRecord] {
        suggestedProjects.filter(\.isFavorite).prefixArray(4)
    }

    private var recentProjects: [NewSessionProjectRecord] {
        suggestedProjects.filter { !$0.isFavorite }.prefixArray(6)
    }

    private var isCurrentProjectFavorite: Bool {
        preferences.isFavorite(path: projectPath)
    }

    private var sheetAnimation: Animation {
        reduceMotion ? .linear(duration: 0.01) : .easeInOut(duration: 0.18)
    }

    private var selectedProvider: AgentProvider {
        selectedModel.provider
    }

    private var sheetVisibleFrame: CGRect {
        NSScreen.main?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
    }

    private var preferredSheetWidth: CGFloat {
        let baseWidth = 640 * min(max(settings.fontSizeScale, 1.0), 1.08)
        return min(max(560, baseWidth), max(560, sheetVisibleFrame.width - 80))
    }

    private var preferredSheetHeight: CGFloat {
        let baseHeight = 720 * min(max(settings.fontSizeScale, 1.0), 1.05)
        return min(max(620, baseHeight), max(560, sheetVisibleFrame.height - 90))
    }

    private var trustWarningText: String {
        switch selectedProvider {
        case .claude:
            return NSLocalizedString("terminal.trust.warning", comment: "")
        case .codex:
            return "Codex가 이 폴더의 파일을 읽고, 수정하고, 실행할 수 있습니다."
        case .gemini:
            return "Gemini가 이 폴더의 파일을 읽고, 수정하고, 실행할 수 있습니다."
        }
    }

    private func providerSubtitle(_ provider: AgentProvider) -> String {
        switch provider {
        case .claude: return "Claude Code CLI"
        case .codex: return "Codex CLI"
        case .gemini: return "Gemini CLI"
        }
    }

    private func providerSymbol(_ provider: AgentProvider) -> String {
        switch provider {
        case .claude: return "bubble.left.and.bubble.right.fill"
        case .codex: return "terminal.fill"
        case .gemini: return "diamond.fill"
        }
    }

    private func providerChipTint(_ provider: AgentProvider) -> Color {
        switch provider {
        case .claude: return Theme.accent
        case .codex: return Theme.orange
        case .gemini: return Theme.cyan
        }
    }

    private func selectProvider(_ provider: AgentProvider) {
        guard selectedProvider != provider else { return }
        guard ensureProviderAvailable(provider) else { return }
        selectedModel = provider.defaultModel
    }

    private func ensureProviderAvailable(_ provider: AgentProvider) -> Bool {
        guard provider.refreshAvailability(force: false) else {
            unavailableProviderAlert = provider
            return false
        }
        return true
    }

    public var body: some View {
        ZStack {
            sessionConfigView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(!showTrustPrompt)

            if showTrustPrompt {
                Color.black.opacity(0.38)
                    .overlay {
                        trustPromptView
                            .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    }
                    .zIndex(1)
            }
        }
        .frame(width: preferredSheetWidth, height: preferredSheetHeight)
        .background(Theme.bg)
        .onAppear {
            isCreatingSessions = false
            bootstrapFromLastDraftIfNeeded()
        }
        .alert(item: $unavailableProviderAlert) { provider in
            Alert(
                title: Text(provider.selectionUnavailableTitle),
                message: Text(provider.selectionUnavailableDetail),
                dismissButton: .default(Text("확인"))
            )
        }
    }

    // MARK: - 폴더 신뢰 확인 화면

    private var trustPromptView: some View {
        VStack(spacing: 0) {
            // 터미널 스타일 헤더
            VStack(spacing: 12) {
                Image(systemName: "shield.checkered")
                    .font(.system(size: Theme.iconSize(28))).foregroundColor(Theme.yellow)

                Text(NSLocalizedString("terminal.trust.title", comment: ""))
                    .font(Theme.mono(14, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
            }.padding(.top, 20).padding(.bottom, 12)

            // 경로 표시
            HStack(spacing: 6) {
                Image(systemName: "folder.fill").font(.system(size: Theme.iconSize(10))).foregroundStyle(Theme.accentBackground)
                Text(projectPath)
                    .font(Theme.mono(10))
                    .foregroundStyle(Theme.accentBackground).lineLimit(1).truncationMode(.middle)
            }
            .padding(.horizontal, 16).padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 8).fill(Theme.accent.opacity(0.06)))
            .padding(.horizontal, 24)

            // 안내 텍스트
            VStack(alignment: .leading, spacing: 8) {
                Text(NSLocalizedString("terminal.trust.question", comment: ""))
                    .font(Theme.mono(11, weight: .medium))
                    .foregroundColor(Theme.textPrimary)

                Text(NSLocalizedString("terminal.trust.hint", comment: ""))
                    .font(Theme.mono(9))
                    .foregroundColor(Theme.textDim)

                Rectangle().fill(Theme.border).frame(height: 1).padding(.vertical, 4)

                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill").font(.system(size: Theme.iconSize(9))).foregroundColor(Theme.yellow)
                    Text(trustWarningText)
                        .font(Theme.mono(9)).foregroundColor(Theme.yellow)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16).padding(.horizontal, 8)

            Spacer(minLength: 8)

            // 선택 버튼
            VStack(spacing: 6) {
                Button(action: {
                    approveFolderTrustAndLaunch()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.right")
                            .font(.system(size: Theme.iconSize(10), weight: .bold))
                            .foregroundColor(Theme.green)
                        Text(NSLocalizedString("terminal.trust.yes", comment: ""))
                            .font(Theme.mono(11, weight: .semibold))
                            .foregroundColor(Theme.textPrimary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: Theme.iconSize(12)))
                            .foregroundColor(Theme.green)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Theme.green.opacity(0.08))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.green.opacity(0.3), lineWidth: 1)))
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .keyboardShortcut(.return)
                .disabled(isCreatingSessions)
                .accessibilityLabel(NSLocalizedString("terminal.trust.yes.a11y", comment: ""))
                .accessibilityHint(NSLocalizedString("terminal.trust.yes.a11y.hint", comment: ""))

                Button(action: {
                    withAnimation(sheetAnimation) {
                        showTrustPrompt = false
                    }
                }) {
                    HStack(spacing: 8) {
                        Color.clear.frame(width: 12, height: 12)
                        Text(NSLocalizedString("terminal.trust.no", comment: ""))
                            .font(Theme.mono(11))
                            .foregroundColor(Theme.textSecondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: "xmark.circle")
                            .font(.system(size: Theme.iconSize(12)))
                            .foregroundColor(Theme.textDim)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Theme.bgSurface)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border.opacity(0.3), lineWidth: 1)))
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .keyboardShortcut(.escape)
                .disabled(isCreatingSessions)
                .accessibilityLabel(NSLocalizedString("terminal.trust.no.a11y", comment: ""))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
        .frame(width: min(520, preferredSheetWidth - 72))
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Theme.bgCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Theme.border.opacity(0.45), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.28), radius: 24, y: 10)
    }

    // MARK: - 세션 설정 화면

    private var sessionConfigView: some View {
        VStack(spacing: 0) {
            DSModalHeader(
                icon: "plus.circle.fill",
                iconColor: Theme.accent,
                title: NSLocalizedString("session.new", comment: ""),
                subtitle: NSLocalizedString("terminal.new.subtitle", comment: "")
            )

            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: Theme.sp4) {
                    sessionConfigQuickStartSection
                    sessionConfigProjectSection
                    sessionConfigExecutionSection
                    sessionConfigTerminalSection
                    sessionConfigAdvancedToggle
                }
                .padding(20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            sessionConfigBottomBar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showSavePreset) {
            SavePresetSheet(draft: currentDraftSnapshot())
                .dofficeSheetPresentation()
        }
    }

    @ViewBuilder
    private var sessionConfigQuickStartSection: some View {
        configSection(title: NSLocalizedString("terminal.quickstart", comment: ""), subtitle: NSLocalizedString("terminal.quickstart.subtitle", comment: "")) {
            VStack(alignment: .leading, spacing: 14) {
                ViewThatFits(in: .horizontal) {
                    quickStartActionsRow
                    quickStartActionsColumn
                }

                optionGroup(title: NSLocalizedString("terminal.recommended.presets", comment: "")) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 8)], spacing: 8) {
                        ForEach(NewSessionPreset.allCases) { preset in
                            selectionChip(
                                title: preset.title,
                                subtitle: preset.subtitle,
                                symbol: preset.symbol,
                                tint: preset.tint,
                                selected: activePresetId == preset.id
                            ) {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    activePresetId = preset.id
                                }
                                applyPreset(preset)
                            }
                        }
                    }
                }

                // 사용자 저장 프리셋
                if !CustomPresetStore.shared.presets.isEmpty {
                    optionGroup(title: NSLocalizedString("terminal.my.presets", comment: "")) {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 8)], spacing: 8) {
                            ForEach(CustomPresetStore.shared.presets) { preset in
                                selectionChip(
                                    title: preset.name,
                                    subtitle: String(format: NSLocalizedString("terminal.preset.custom.subtitle", comment: ""), preset.draft.terminalCount, preset.draft.selectedModel),
                                    symbol: preset.icon,
                                    tint: preset.tintColor,
                                    selected: activePresetId == "custom-\(preset.id)"
                                ) {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        activePresetId = "custom-\(preset.id)"
                                    }
                                    applyDraft(preset.draft)
                                }
                                .contextMenu {
                                    Button(role: .destructive) {
                                        CustomPresetStore.shared.delete(preset)
                                    } label: {
                                        Label(NSLocalizedString("terminal.preset.delete", comment: ""), systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                }

                if !favoriteProjects.isEmpty {
                    optionGroup(title: NSLocalizedString("terminal.favorite.projects", comment: "")) {
                        projectSuggestionScroller(projects: favoriteProjects)
                    }
                }

                if !recentProjects.isEmpty {
                    optionGroup(title: NSLocalizedString("terminal.recent.projects", comment: "")) {
                        projectSuggestionScroller(projects: recentProjects)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var sessionConfigProjectSection: some View {
        configSection(title: NSLocalizedString("terminal.config.project", comment: ""), subtitle: NSLocalizedString("terminal.config.project.subtitle", comment: "")) {
            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    sectionLabel(NSLocalizedString("terminal.project.path", comment: ""))
                    HStack(spacing: 8) {
                        TextField("/path/to/project", text: $projectPath)
                            .textFieldStyle(.plain)
                            .font(Theme.monoSmall)
                            .appFieldStyle(emphasized: true)
                            .accessibilityLabel(NSLocalizedString("terminal.project.path.a11y", comment: ""))
                            .accessibilityHint(NSLocalizedString("terminal.project.path.a11y.hint", comment: ""))

                        Button("Browse") {
                            let p = NSOpenPanel(); p.canChooseFiles = false; p.canChooseDirectories = true
                            if p.runModal() == .OK, let u = p.url {
                                projectPath = normalizedProjectPath(u.path)
                                if projectName.isEmpty { projectName = u.lastPathComponent }
                            }
                        }
                        .buttonStyle(.plain)
                        .font(Theme.mono(9, weight: .bold))
                        .appButtonSurface(tone: .neutral, compact: true)
                        .accessibilityLabel(NSLocalizedString("terminal.project.folder.find.a11y", comment: ""))
                    }
                    .onChange(of: projectPath) { _, _ in
                        pathError = nil
                    }
                    if let error = pathError {
                        Text(error)
                            .font(Theme.mono(8))
                            .foregroundColor(Theme.red)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    sectionLabel(NSLocalizedString("terminal.project.name", comment: ""))
                    TextField("e.g. my-project", text: $projectName)
                        .textFieldStyle(.plain)
                        .font(Theme.monoSmall)
                        .appFieldStyle()
                        .accessibilityLabel(NSLocalizedString("terminal.project.name.a11y", comment: ""))
                }
            }
        }
    }

    @ViewBuilder
    private var sessionConfigExecutionSection: some View {
        configSection(title: NSLocalizedString("terminal.config.execution", comment: ""), subtitle: NSLocalizedString("terminal.config.execution.subtitle", comment: "")) {
            VStack(alignment: .leading, spacing: 14) {
                optionGroup(title: "Agent") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 8)], spacing: 8) {
                        ForEach(AgentProvider.allCases) { provider in
                            selectionChip(
                                title: provider.displayName,
                                subtitle: providerSubtitle(provider),
                                symbol: providerSymbol(provider),
                                tint: providerChipTint(provider),
                                selected: selectedProvider == provider
                            ) {
                                selectProvider(provider)
                            }
                        }
                    }
                }

                optionGroup(title: NSLocalizedString("terminal.config.model", comment: "")) {
                    if selectedProvider == .claude {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 8)], spacing: 8) {
                            ForEach(selectedProvider.models) { model in
                                selectionChip(
                                    title: model.displayName,
                                    subtitle: model.isRecommended ? NSLocalizedString("terminal.config.model.recommended", comment: "") : nil,
                                    symbol: "circle.fill",
                                    tint: modelTint(model),
                                    selected: selectedModel == model
                                ) {
                                    selectedModel = model
                                }
                            }
                        }
                    } else {
                        Menu {
                            ForEach(selectedProvider.models) { model in
                                Button(model.displayName) {
                                    selectedModel = model
                                }
                            }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: Theme.iconSize(10), weight: .semibold))
                                    .foregroundColor(modelTint(selectedModel))
                                    .frame(width: 18)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(selectedModel.displayName)
                                        .font(Theme.mono(9, weight: .bold))
                                        .foregroundColor(Theme.textPrimary)
                                    Text("Codex 모델 선택")
                                        .font(Theme.mono(7))
                                        .foregroundColor(Theme.textDim)
                                }

                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(modelTint(selectedModel).opacity(0.10))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(modelTint(selectedModel).opacity(0.24), lineWidth: 1)
                            )
                        }
                        .menuStyle(.borderlessButton)
                    }
                }

                if selectedProvider == .claude {
                    optionGroup(title: "Effort") {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 8)], spacing: 8) {
                            ForEach(EffortLevel.allCases) { level in
                                selectionChip(
                                    title: effortTitle(level),
                                    subtitle: nil,
                                    symbol: effortSymbol(level),
                                    tint: effortTint(level),
                                    selected: effortLevel == level
                                ) {
                                    effortLevel = level
                                }
                            }
                        }
                    }

                    optionGroup(title: NSLocalizedString("terminal.config.permission", comment: "")) {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 8)], spacing: 8) {
                            ForEach(PermissionMode.allCases) { mode in
                                selectionChip(
                                    title: mode.displayName,
                                    subtitle: mode.desc,
                                    symbol: permissionSymbol(mode),
                                    tint: permissionTint(mode),
                                    selected: permissionMode == mode
                                ) {
                                    permissionMode = mode
                                }
                            }
                        }
                    }
                } else {
                    optionGroup(title: "Sandbox") {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 8)], spacing: 8) {
                            ForEach(CodexSandboxMode.allCases) { mode in
                                selectionChip(
                                    title: mode.displayName,
                                    subtitle: mode.shortLabel,
                                    symbol: "square.3.layers.3d.down.right",
                                    tint: codexSandboxColor(mode),
                                    selected: codexSandboxMode == mode
                                ) {
                                    codexSandboxMode = mode
                                }
                            }
                        }
                    }

                    optionGroup(title: "Approval") {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 8)], spacing: 8) {
                            ForEach(CodexApprovalPolicy.allCases) { mode in
                                selectionChip(
                                    title: mode.displayName,
                                    subtitle: mode.shortLabel,
                                    symbol: "hand.raised.fill",
                                    tint: codexApprovalColor(mode),
                                    selected: codexApprovalPolicy == mode
                                ) {
                                    codexApprovalPolicy = mode
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var quickStartActionsRow: some View {
        HStack(spacing: 8) {
            lastDraftButton
            if !projectPath.isEmpty {
                favoriteProjectButton
            }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var quickStartActionsColumn: some View {
        VStack(alignment: .leading, spacing: 8) {
            lastDraftButton
            if !projectPath.isEmpty {
                favoriteProjectButton
            }
        }
    }

    private var lastDraftButton: some View {
        Button(action: { applyLastDraftIfAvailable() }) {
            HStack(spacing: 6) {
                Image(systemName: "clock.arrow.circlepath")
                Text(NSLocalizedString("terminal.load.last.settings", comment: ""))
            }
            .font(Theme.mono(9, weight: .bold))
            .appButtonSurface(tone: .neutral, compact: true)
        }
        .buttonStyle(.plain)
        .disabled(preferences.lastDraft == nil)
        .accessibilityLabel(NSLocalizedString("terminal.load.last.a11y", comment: ""))
    }

    private var favoriteProjectButton: some View {
        Button(action: {
            preferences.toggleFavorite(projectName: resolvedProjectName, projectPath: projectPath)
        }) {
            HStack(spacing: 6) {
                Image(systemName: isCurrentProjectFavorite ? "star.fill" : "star")
                Text(isCurrentProjectFavorite ? NSLocalizedString("terminal.favorite.on", comment: "") : NSLocalizedString("terminal.favorite.off", comment: ""))
            }
            .font(Theme.mono(9, weight: .bold))
            .appButtonSurface(tone: .yellow, compact: true)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isCurrentProjectFavorite ? NSLocalizedString("terminal.favorite.a11y.on", comment: "") : NSLocalizedString("terminal.favorite.a11y.off", comment: ""))
    }

    @ViewBuilder
    private var sessionConfigTerminalSection: some View {
        configSection(title: NSLocalizedString("terminal.config.terminal", comment: ""), subtitle: NSLocalizedString("terminal.config.terminal.subtitle", comment: "")) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    sectionLabel(NSLocalizedString("terminal.config.terminal.count", comment: ""))
                    Spacer()
                    Text(String(format: NSLocalizedString("terminal.count.items", comment: ""), terminalCount))
                        .font(Theme.mono(9, weight: .bold))
                        .foregroundStyle(Theme.accentBackground)
                }

                HStack(spacing: 8) {
                    ForEach([1, 2, 3, 4, 5], id: \.self) { n in
                        Button(action: {
                            withAnimation(sheetAnimation) {
                                setTerminalCount(n)
                            }
                        }) {
                            VStack(spacing: 4) {
                                HStack(spacing: 2) {
                                    ForEach(0..<n, id: \.self) { i in
                                        let colorIdx = (manager.userVisibleTabCount + i) % Theme.workerColors.count
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(Theme.workerColors[colorIdx])
                                            .frame(width: n <= 3 ? 10 : 7, height: 12)
                                    }
                                }
                                Text("\(n)")
                                    .font(Theme.mono(9, weight: terminalCount == n ? .bold : .medium))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(terminalCount == n ? Theme.accent.opacity(0.08) : Theme.bgSurface)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(terminalCount == n ? Theme.accent.opacity(0.24) : Theme.border.opacity(0.22), lineWidth: 1)
                            )
                            .foregroundColor(terminalCount == n ? Theme.accent : Theme.textSecondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(String(format: NSLocalizedString("terminal.config.terminal.n.a11y", comment: ""), n))
                        .accessibilityValue(terminalCount == n ? NSLocalizedString("terminal.config.terminal.selected", comment: "") : NSLocalizedString("terminal.config.terminal.unselected", comment: ""))
                    }
                }

                if terminalCount > 1 {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(NSLocalizedString("terminal.config.task.per.terminal", comment: ""))
                            .font(Theme.mono(9, weight: .medium))
                            .foregroundColor(Theme.textDim)
                        ForEach(tasks.indices, id: \.self) { i in
                            HStack(spacing: 8) {
                                let colorIdx = (manager.userVisibleTabCount + i) % Theme.workerColors.count
                                Circle().fill(Theme.workerColors[colorIdx]).frame(width: 8, height: 8)
                                Text("#\(i + 1)")
                                    .font(Theme.mono(8, weight: .bold))
                                    .foregroundColor(Theme.textDim)
                                    .frame(width: 18)
                                TextField(NSLocalizedString("terminal.config.task.placeholder", comment: ""), text: $tasks[i])
                                    .textFieldStyle(.plain)
                                    .font(Theme.mono(10))
                                    .appFieldStyle()
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var sessionConfigAdvancedToggle: some View {
        Button(action: {
            withAnimation(sheetAnimation) {
                showAdvanced.toggle()
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: showAdvanced ? "chevron.down" : "chevron.right")
                    .font(.system(size: Theme.iconSize(9), weight: .bold))
                    .foregroundColor(Theme.textDim)
                VStack(alignment: .leading, spacing: 2) {
                    Text(NSLocalizedString("terminal.config.advanced", comment: ""))
                        .font(Theme.mono(10, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                    Text(NSLocalizedString("terminal.config.advanced.desc", comment: ""))
                        .font(Theme.mono(8))
                        .foregroundColor(Theme.textDim)
                }
                Spacer()
                if hasAdvancedOptions {
                    Text(NSLocalizedString("terminal.config.advanced.set", comment: ""))
                        .font(Theme.mono(8, weight: .bold))
                        .foregroundColor(Theme.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: Theme.cornerSmall).fill(Theme.green.opacity(0.10)))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .appPanelStyle(padding: 14, radius: 14, fill: Theme.bgCard.opacity(0.96), strokeOpacity: 0.18, shadow: false)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(showAdvanced ? NSLocalizedString("terminal.config.advanced.collapse.a11y", comment: "") : NSLocalizedString("terminal.config.advanced.expand.a11y", comment: ""))

        if showAdvanced {
            advancedOptionsView
        }
    }

    @ViewBuilder
    private var sessionConfigBottomBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Text("Cancel")
                    .font(Theme.mono(10, weight: .bold))
                    .appButtonSurface(tone: .neutral)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.escape)
            .accessibilityLabel(NSLocalizedString("terminal.cancel.new.a11y", comment: ""))

            Button(action: { showSavePreset = true }) {
                HStack(spacing: 4) {
                    Image(systemName: "square.and.arrow.down").font(.system(size: Theme.iconSize(9)))
                    Text(NSLocalizedString("terminal.save.preset", comment: ""))
                        .font(Theme.mono(9, weight: .bold))
                }
                .appButtonSurface(tone: .neutral, compact: true)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(NSLocalizedString("terminal.save.preset.a11y", comment: ""))

            Spacer()
            Button(action: { handleCreateButtonTapped() }) {
                HStack(spacing: 4) {
                    Image(systemName: "play.fill").font(.system(size: Theme.iconSize(9), weight: .bold))
                    Text(isCreatingSessions
                         ? NSLocalizedString("status.running", comment: "")
                         : (terminalCount > 1 ? String(format: NSLocalizedString("terminal.create.count", comment: ""), terminalCount) : "Create"))
                        .font(Theme.mono(10, weight: .bold))
                }
                .appButtonSurface(tone: .accent, prominent: true)
            }
            .buttonStyle(.plain).keyboardShortcut(.return)
            .disabled((projectPath.isEmpty && projectName.isEmpty) || isCreatingSessions)
            .accessibilityLabel(terminalCount > 1 ? String(format: NSLocalizedString("terminal.create.sessions.a11y", comment: ""), terminalCount) : NSLocalizedString("terminal.create.session.a11y", comment: ""))
        }.padding(.horizontal, 24).padding(.vertical, 12)
        .background(Theme.bg)
        .overlay(Rectangle().fill(Theme.border).frame(height: 1), alignment: .top)
    }

    // MARK: - 고급 옵션

    private var hasAdvancedOptions: Bool {
        !systemPrompt.isEmpty || maxBudget != "" || !allowedTools.isEmpty ||
        !disallowedTools.isEmpty || !additionalDirs.isEmpty || continueSession || useWorktree
    }

    private var advancedOptionsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 시스템 프롬프트
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "text.bubble.fill").font(.system(size: Theme.iconSize(9))).foregroundColor(Theme.purple)
                    Text(NSLocalizedString("terminal.system.prompt", comment: "")).font(Theme.mono(9, weight: .medium)).foregroundColor(Theme.textSecondary)
                }
                TextField(NSLocalizedString("terminal.system.prompt.placeholder", comment: ""), text: $systemPrompt, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(Theme.mono(10))
                    .lineLimit(2...4)
                    .appFieldStyle()
            }

            // 예산 제한
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "dollarsign.circle.fill").font(.system(size: Theme.iconSize(9))).foregroundColor(Theme.yellow)
                        Text(NSLocalizedString("terminal.budget.limit", comment: "")).font(Theme.mono(9, weight: .medium)).foregroundColor(Theme.textSecondary)
                    }
                    TextField(NSLocalizedString("terminal.budget.unlimited", comment: ""), text: $maxBudget)
                        .textFieldStyle(.plain)
                        .font(Theme.mono(10))
                        .frame(width: 100)
                        .appFieldStyle()
                }
                Spacer()

                // 세션 이어하기
                VStack(alignment: .leading, spacing: 4) {
                    Toggle(isOn: $continueSession) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.turn.up.right").font(.system(size: Theme.iconSize(9))).foregroundColor(Theme.cyan)
                            Text(NSLocalizedString("terminal.resume.conversation", comment: "")).font(Theme.mono(9, weight: .medium)).foregroundColor(Theme.textSecondary)
                        }
                    }.toggleStyle(.switch).controlSize(.small)
                }
            }

            // 워크트리
            Toggle(isOn: $useWorktree) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.branch").font(.system(size: Theme.iconSize(9))).foregroundColor(Theme.green)
                    Text(NSLocalizedString("terminal.git.worktree", comment: "")).font(Theme.mono(9, weight: .medium)).foregroundColor(Theme.textSecondary)
                    Text("--worktree").font(Theme.mono(8)).foregroundColor(Theme.textDim)
                }
            }.toggleStyle(.switch).controlSize(.small)

            // 도구 제한
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "wrench.and.screwdriver.fill").font(.system(size: Theme.iconSize(9))).foregroundColor(Theme.orange)
                    Text(NSLocalizedString("terminal.allowed.tools", comment: "")).font(Theme.mono(9, weight: .medium)).foregroundColor(Theme.textSecondary)
                    Text(NSLocalizedString("terminal.tools.comma.sep", comment: "")).font(Theme.mono(8)).foregroundColor(Theme.textDim)
                }
                TextField(NSLocalizedString("terminal.allowed.tools.placeholder", comment: ""), text: $allowedTools)
                    .textFieldStyle(.plain)
                    .font(Theme.mono(10))
                    .appFieldStyle()
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "xmark.shield.fill").font(.system(size: Theme.iconSize(9))).foregroundColor(Theme.red)
                    Text(NSLocalizedString("terminal.blocked.tools", comment: "")).font(Theme.mono(9, weight: .medium)).foregroundColor(Theme.textSecondary)
                    Text(NSLocalizedString("terminal.tools.comma.sep", comment: "")).font(Theme.mono(8)).foregroundColor(Theme.textDim)
                }
                TextField(NSLocalizedString("terminal.blocked.tools.placeholder", comment: ""), text: $disallowedTools)
                    .textFieldStyle(.plain)
                    .font(Theme.mono(10))
                    .appFieldStyle()
            }

            // 추가 디렉토리
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "folder.badge.plus").font(.system(size: Theme.iconSize(9))).foregroundStyle(Theme.accentBackground)
                    Text(NSLocalizedString("terminal.additional.dirs", comment: "")).font(Theme.mono(9, weight: .medium)).foregroundColor(Theme.textSecondary)
                }
                HStack(spacing: 4) {
                    TextField(NSLocalizedString("terminal.additional.dir.placeholder", comment: ""), text: $additionalDir)
                        .textFieldStyle(.plain)
                        .font(Theme.mono(10))
                        .appFieldStyle()
                    Button(action: {
                        let p = NSOpenPanel(); p.canChooseFiles = false; p.canChooseDirectories = true
                        if p.runModal() == .OK, let u = p.url { additionalDir = u.path }
                    }) {
                        Image(systemName: "folder").font(.system(size: Theme.iconSize(10))).foregroundStyle(Theme.accentBackground)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(NSLocalizedString("terminal.additional.dir.select.a11y", comment: ""))
                    Button(action: {
                        if !additionalDir.isEmpty {
                            additionalDirs.append(additionalDir); additionalDir = ""
                        }
                    }) {
                        Image(systemName: "plus.circle.fill").font(.system(size: Theme.iconSize(12))).foregroundColor(Theme.green)
                    }
                    .buttonStyle(.plain)
                    .disabled(additionalDir.isEmpty)
                    .accessibilityLabel(NSLocalizedString("terminal.additional.dir.add.a11y", comment: ""))
                }
                if !additionalDirs.isEmpty {
                    ForEach(additionalDirs.indices, id: \.self) { i in
                        HStack(spacing: 4) {
                            Image(systemName: "folder.fill").font(.system(size: Theme.iconSize(8))).foregroundColor(Theme.accent.opacity(0.6))
                            Text(additionalDirs[i]).font(Theme.mono(9)).foregroundColor(Theme.textSecondary).lineLimit(1)
                            Spacer()
                            Button(action: { additionalDirs.remove(at: i) }) {
                                Image(systemName: "xmark").font(Theme.scaled(7, weight: .bold)).foregroundColor(Theme.red)
                            }.buttonStyle(.plain)
                        }.padding(.leading, 8)
                    }
                }
            }
        }
        .appPanelStyle(padding: 16, radius: 14, fill: Theme.bgCard.opacity(0.96), strokeOpacity: 0.18, shadow: false)
    }

    private func configSection<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(Theme.mono(11, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                Text(subtitle)
                    .font(Theme.mono(8))
                    .foregroundColor(Theme.textDim)
            }

            content()
        }
        .appPanelStyle(fill: Theme.bgCard.opacity(0.98), strokeOpacity: Theme.borderDefault)
    }

    private func optionGroup<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel(title)
            content()
        }
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(Theme.mono(9, weight: .bold))
            .foregroundColor(Theme.textDim)
    }

    private func selectionChip(
        title: String,
        subtitle: String?,
        symbol: String,
        tint: Color,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: Theme.iconSize(10), weight: .semibold))
                    .foregroundColor(tint)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Theme.mono(9, weight: .bold))
                        .foregroundColor(selected ? Theme.textPrimary : Theme.textSecondary)
                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(Theme.mono(7))
                            .foregroundColor(Theme.textDim)
                            .lineLimit(2)
                    }
                }

                Spacer(minLength: 0)

                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: Theme.iconSize(10), weight: .bold))
                        .foregroundColor(tint)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(selected ? tint.opacity(0.10) : Theme.bgSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(selected ? tint.opacity(0.24) : Theme.border.opacity(0.22), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(subtitle.map { "\(title), \($0)" } ?? title)
        .accessibilityValue(selected ? NSLocalizedString("terminal.option.selected.a11y", comment: "") : NSLocalizedString("terminal.option.unselected.a11y", comment: ""))
        .accessibilityHint(NSLocalizedString("terminal.option.select.a11y.hint", comment: ""))
    }

    private func modelTint(_ model: ClaudeModel) -> Color {
        switch model {
        case .opus: return Theme.purple
        case .sonnet: return Theme.accent
        case .haiku: return Theme.green
        case .gpt54: return Theme.accent
        case .gpt54Mini: return Theme.cyan
        case .gpt53Codex: return Theme.orange
        case .gpt52Codex: return Theme.orange
        case .gpt52: return Theme.green
        case .gpt51CodexMax: return Theme.red
        case .gpt51CodexMini: return Theme.yellow
        case .gemini25Pro: return Theme.cyan
        case .gemini25Flash: return Theme.green
        }
    }

    private func effortTitle(_ level: EffortLevel) -> String {
        switch level {
        case .low: return NSLocalizedString("terminal.effort.low", comment: "")
        case .medium: return NSLocalizedString("terminal.effort.medium", comment: "")
        case .high: return NSLocalizedString("terminal.effort.high", comment: "")
        case .max: return NSLocalizedString("terminal.effort.max", comment: "")
        }
    }

    private func effortSymbol(_ level: EffortLevel) -> String {
        switch level {
        case .low: return "tortoise.fill"
        case .medium: return "figure.walk"
        case .high: return "figure.run"
        case .max: return "flame.fill"
        }
    }

    private func effortTint(_ level: EffortLevel) -> Color {
        switch level {
        case .low: return Theme.green
        case .medium: return Theme.accent
        case .high: return Theme.orange
        case .max: return Theme.red
        }
    }

    private func permissionSymbol(_ mode: PermissionMode) -> String {
        switch mode {
        case .acceptEdits: return "square.and.pencil"
        case .bypassPermissions: return "bolt.fill"
        case .auto: return "gearshape.2.fill"
        case .defaultMode: return "shield.fill"
        case .plan: return "list.bullet.clipboard.fill"
        }
    }

    private func permissionTint(_ mode: PermissionMode) -> Color {
        switch mode {
        case .acceptEdits: return Theme.orange
        case .bypassPermissions: return Theme.yellow
        case .auto: return Theme.cyan
        case .defaultMode: return Theme.textSecondary
        case .plan: return Theme.purple
        }
    }

    private func codexSandboxColor(_ mode: CodexSandboxMode) -> Color {
        switch mode {
        case .readOnly: return Theme.green
        case .workspaceWrite: return Theme.cyan
        case .dangerFullAccess: return Theme.red
        }
    }

    private func codexApprovalColor(_ mode: CodexApprovalPolicy) -> Color {
        switch mode {
        case .untrusted: return Theme.green
        case .onRequest: return Theme.orange
        case .never: return Theme.yellow
        }
    }

    private var resolvedProjectName: String {
        let trimmed = projectName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        if !projectPath.isEmpty { return (projectPath as NSString).lastPathComponent }
        return ""
    }

    private func projectSuggestionScroller(projects: [NewSessionProjectRecord]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(projects) { project in
                    Button(action: { applyProjectSuggestion(project) }) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Image(systemName: project.isFavorite ? "star.fill" : "folder.fill")
                                    .font(.system(size: Theme.iconSize(9), weight: .semibold))
                                    .foregroundColor(project.isFavorite ? Theme.yellow : Theme.accent)
                                Text(project.name)
                                    .font(Theme.mono(9, weight: .bold))
                                    .foregroundColor(Theme.textPrimary)
                                    .lineLimit(1)
                            }
                            Text(project.path)
                                .font(Theme.mono(7))
                                .foregroundColor(Theme.textDim)
                                .lineLimit(1)
                            Text(project.lastUsedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(Theme.mono(7, weight: .medium))
                                .foregroundColor(Theme.textDim)
                        }
                        .frame(width: 180, alignment: .leading)
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Theme.bgSurface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Theme.border.opacity(0.22), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(String(format: NSLocalizedString("terminal.project.a11y.label", comment: ""), project.name))
                    .accessibilityValue(project.isFavorite ? NSLocalizedString("terminal.project.a11y.favorite", comment: "") : NSLocalizedString("terminal.project.a11y.recent", comment: ""))
                    .accessibilityHint(NSLocalizedString("terminal.project.a11y.hint", comment: ""))
                }
            }
            .padding(.vertical, 1)
        }
    }

    private func applyProjectSuggestion(_ project: NewSessionProjectRecord) {
        projectName = project.name
        projectPath = project.path
    }

    private func applyPreset(_ preset: NewSessionPreset) {
        switch preset {
        case .balanced:
            selectedModel = .sonnet
            effortLevel = .medium
            permissionMode = .bypassPermissions
            setTerminalCount(1)
            continueSession = false
            useWorktree = false
        case .planFirst:
            selectedModel = .sonnet
            effortLevel = .medium
            permissionMode = .plan
            setTerminalCount(1)
            continueSession = false
            useWorktree = false
        case .safeReview:
            selectedModel = .sonnet
            effortLevel = .high
            permissionMode = .defaultMode
            setTerminalCount(1)
            continueSession = true
            useWorktree = false
        case .parallelBuild:
            selectedModel = .sonnet
            effortLevel = .high
            permissionMode = .bypassPermissions
            setTerminalCount(3)
            continueSession = false
            useWorktree = true
        }
    }

    private func applyCustomPreset(_ preset: CustomSessionPreset) {
        applyDraft(preset.draft)
    }

    private func currentDraftSnapshot() -> NewSessionDraftSnapshot {
        NewSessionDraftSnapshot(
            selectedModel: selectedModel.rawValue,
            effortLevel: effortLevel.rawValue,
            permissionMode: permissionMode.rawValue,
            codexSandboxMode: codexSandboxMode.rawValue,
            codexApprovalPolicy: codexApprovalPolicy.rawValue,
            terminalCount: terminalCount,
            systemPrompt: systemPrompt,
            maxBudget: maxBudget,
            allowedTools: allowedTools,
            disallowedTools: disallowedTools,
            additionalDirs: additionalDirs,
            continueSession: continueSession,
            useWorktree: useWorktree
        )
    }

    private func applyDraft(_ draft: NewSessionDraftSnapshot) {
        if let model = ClaudeModel(rawValue: draft.selectedModel) {
            selectedModel = model
        }
        if let level = EffortLevel(rawValue: draft.effortLevel) {
            effortLevel = level
        }
        if let mode = PermissionMode(rawValue: draft.permissionMode) {
            permissionMode = mode
        }
        if let mode = CodexSandboxMode(rawValue: draft.codexSandboxMode) {
            codexSandboxMode = mode
        }
        if let mode = CodexApprovalPolicy(rawValue: draft.codexApprovalPolicy) {
            codexApprovalPolicy = mode
        }
        setTerminalCount(max(1, min(5, draft.terminalCount)))
        systemPrompt = draft.systemPrompt
        maxBudget = draft.maxBudget
        allowedTools = draft.allowedTools
        disallowedTools = draft.disallowedTools
        additionalDirs = draft.additionalDirs
        continueSession = draft.continueSession
        useWorktree = draft.useWorktree
    }

    private func applyLastDraftIfAvailable() {
        guard let draft = preferences.lastDraft else { return }
        applyDraft(draft)
    }

    private func bootstrapFromLastDraftIfNeeded() {
        guard !didBootstrap else { return }
        didBootstrap = true
        if let draft = preferences.lastDraft {
            applyDraft(draft)
        }
    }

    private func setTerminalCount(_ n: Int) {
        terminalCount = n
        while tasks.count < n { tasks.append("") }
        while tasks.count > n { tasks.removeLast() }
    }

    private func normalizedProjectPath(_ rawPath: String) -> String {
        let trimmed = rawPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        let expanded = NSString(string: trimmed).expandingTildeInPath
        let baseURL = URL(fileURLWithPath: expanded, isDirectory: true)
        let standardized = baseURL.standardizedFileURL.path
        guard FileManager.default.fileExists(atPath: standardized) else { return standardized }
        return baseURL.standardizedFileURL.resolvingSymlinksInPath().path
    }

    private var isCurrentProjectTrusted: Bool {
        let normalized = normalizedProjectPath(projectPath)
        guard !normalized.isEmpty else { return true }
        return preferences.isTrusted(projectPath: normalized)
    }

    private func validateSelectedProjectPath() -> Bool {
        let normalized = normalizedProjectPath(projectPath)
        if !normalized.isEmpty {
            var isDir: ObjCBool = false
            if !FileManager.default.fileExists(atPath: normalized, isDirectory: &isDir) || !isDir.boolValue {
                pathError = NSLocalizedString("terminal.path.error", comment: "")
                return false
            }
        }
        pathError = nil
        return true
    }

    private func handleCreateButtonTapped() {
        guard !isCreatingSessions else { return }
        guard validateSelectedProjectPath() else { return }
        guard ensureProviderAvailable(selectedProvider) else { return }

        if !projectPath.isEmpty && !isCurrentProjectTrusted {
            withAnimation(sheetAnimation) {
                showTrustPrompt = true
            }
            return
        }

        launchSessionsAfterConfirmation()
    }

    private func approveFolderTrustAndLaunch() {
        guard !isCreatingSessions else { return }

        preferences.trust(projectPath: projectPath)
        withAnimation(sheetAnimation) {
            showTrustPrompt = false
        }

        launchSessionsAfterConfirmation()
    }

    private func launchSessionsAfterConfirmation() {
        guard !isCreatingSessions else { return }
        guard ensureProviderAvailable(selectedProvider) else { return }

        let normalizedPath = normalizedProjectPath(projectPath)
        let path = normalizedPath.isEmpty ? NSHomeDirectory() : normalizedPath
        let name = projectName.isEmpty ? (path as NSString).lastPathComponent : projectName

        // Capture references before dismiss — @EnvironmentObject becomes
        // invalid once the sheet is removed from the view hierarchy.
        let mgr = manager
        let prefs = preferences

        let capacity = mgr.manualLaunchCapacity
        if capacity <= 0 {
            mgr.notifyManualLaunchCapacity(requested: terminalCount)
            return
        }

        let launchCount = min(terminalCount, capacity)
        if launchCount < terminalCount {
            mgr.notifyManualLaunchCapacity(requested: terminalCount)
        }

        let prompts = Array(tasks.prefix(launchCount)).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        let draft = currentDraftSnapshot()
        let chosenProvider = self.selectedProvider
        let selectedModel = self.selectedModel
        let effortLevel = self.effortLevel
        let permissionMode = self.permissionMode
        let codexSandboxMode = self.codexSandboxMode
        let codexApprovalPolicy = self.codexApprovalPolicy
        let systemPrompt = self.systemPrompt
        let maxBudget = self.maxBudget
        let allowedTools = self.allowedTools
        let disallowedTools = self.disallowedTools
        let additionalDirs = self.additionalDirs
        let continueSession = self.continueSession
        let useWorktree = self.useWorktree

        // Remember launch and create tabs BEFORE dismiss so all view
        // properties are still valid.
        prefs.rememberLaunch(
            projectName: name,
            projectPath: path,
            draft: draft
        )

        var tabsToStart: [TerminalTab] = []
        tabsToStart.reserveCapacity(launchCount)

        for i in 0..<launchCount {
            let prompt = i < prompts.count ? prompts[i] : ""
            let tab = mgr.addTab(
                projectName: name,
                projectPath: path,
                provider: chosenProvider,
                initialPrompt: prompt.isEmpty ? nil : prompt,
                manualLaunch: true,
                autoStart: false
            )
            tab.selectedModel = selectedModel
            tab.isClaude = selectedModel.provider == .claude
            tab.effortLevel = effortLevel
            tab.permissionMode = permissionMode
            tab.codexSandboxMode = codexSandboxMode
            tab.codexApprovalPolicy = codexApprovalPolicy
            tab.systemPrompt = systemPrompt
            tab.maxBudgetUSD = Double(maxBudget) ?? 0
            tab.allowedTools = allowedTools
            tab.disallowedTools = disallowedTools
            tab.additionalDirs = additionalDirs
            tab.continueSession = continueSession
            tab.useWorktree = useWorktree
            tabsToStart.append(tab)
        }

        isCreatingSessions = true
        dismiss()

        // Start tabs asynchronously — tab objects are already created and
        // retained by the manager, so they are safe to access after dismiss.
        for (index, tab) in tabsToStart.enumerated() {
            let delay = min(Double(index) * 0.18, 0.72)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                autoreleasepool {
                    tab.start()
                }
            }
        }
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - CLITerminalView (SwiftTerm — 별도 파일 SwiftTermBridge.swift)
// ═══════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════
// MARK: - Sleep Work Setup Sheet
// ═══════════════════════════════════════════════════════

public struct SleepWorkSetupSheet: View {
    @ObservedObject var tab: TerminalTab
    @Environment(\.dismiss) var envDismiss
    public var onDismiss: (() -> Void)?
    @State private var task = ""
    @State private var budgetText = ""

    private func close() {
        if let onDismiss { onDismiss() } else { envDismiss() }
    }

    public var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "moon.zzz.fill").font(.system(size: 20)).foregroundColor(Theme.purple)
                Text(NSLocalizedString("terminal.sleepwork.title", comment: "")).font(Theme.mono(14, weight: .bold)).foregroundColor(Theme.textPrimary)
                Spacer()
                Button(action: { close() }) {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 16)).foregroundColor(Theme.textDim)
                }.buttonStyle(.plain)
            }

            Text(NSLocalizedString("terminal.sleepwork.desc", comment: ""))
                .font(Theme.mono(10))
                .foregroundColor(Theme.textSecondary)

            VStack(alignment: .leading, spacing: 6) {
                Text(NSLocalizedString("terminal.sleepwork.task", comment: "")).font(Theme.mono(9, weight: .bold)).foregroundColor(Theme.textDim)
                TextEditor(text: $task)
                    .font(Theme.monoNormal)
                    .frame(minHeight: 80)
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Theme.bgSurface))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border, lineWidth: 1))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(NSLocalizedString("terminal.sleepwork.token.budget", comment: "")).font(Theme.mono(9, weight: .bold)).foregroundColor(Theme.textDim)
                TextField("10k", text: $budgetText)
                    .font(Theme.monoNormal)
                    .textFieldStyle(.plain)
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Theme.bgSurface))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border, lineWidth: 1))
                Text(NSLocalizedString("terminal.sleepwork.token.hint", comment: ""))
                    .font(Theme.mono(8)).foregroundColor(Theme.textDim)
            }

            HStack {
                Spacer()
                Button(action: {
                    let budget = parseBudget(budgetText)
                    tab.startSleepWork(task: task, tokenBudget: budget)
                    close()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "moon.zzz.fill").font(.system(size: 12))
                        Text(NSLocalizedString("terminal.sleepwork.start", comment: "")).font(Theme.mono(11, weight: .bold))
                    }
                    .foregroundColor(Theme.textOnAccent)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Theme.purple))
                }
                .buttonStyle(.plain)
                .disabled(task.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 420)
        .background(Theme.bgCard)
    }

    private func parseBudget(_ text: String) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return nil }
        if trimmed.hasSuffix("m") {
            if let n = Double(trimmed.dropLast()) { return Int(n * 1_000_000) }
        }
        if trimmed.hasSuffix("k") {
            if let n = Double(trimmed.dropLast()) { return Int(n * 1000) }
        }
        return Int(trimmed)
    }
}
