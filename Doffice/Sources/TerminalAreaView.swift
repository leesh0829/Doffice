import SwiftUI
import Combine

// ═══════════════════════════════════════════════════════
// MARK: - Terminal Area
// ═══════════════════════════════════════════════════════

struct TerminalAreaView: View {
    @EnvironmentObject var manager: SessionManager
    @State private var viewMode: ViewMode = .grid
    enum ViewMode { case grid, single, git }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            switch viewMode {
            case .grid: GridPanelView()
            case .single:
                if let tab = manager.activeTab { EventStreamView(tab: tab, compact: false) }
                else { EmptySessionView() }
            case .git: GitPanelView()
            }
        }
        .sheet(isPresented: $manager.showNewTabSheet) {
            NewTabSheet()
        }
    }

    private var topBar: some View {
        HStack(spacing: 0) {
            HStack(spacing: 2) {
                modeBtn("square.grid.2x2", .grid); modeBtn("rectangle", .single)
                Rectangle().fill(Theme.border).frame(width: 1, height: 14)
                modeBtn("arrow.triangle.branch", .git)
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
                                    Text("선택 해제").font(Theme.chrome(8))
                                }
                                .foregroundColor(Theme.textDim)
                                .padding(.horizontal, 6).padding(.vertical, 3)
                            }.buttonStyle(.plain)
                        }
                    }
                    if viewMode == .single || viewMode == .git { ForEach(manager.userVisibleTabs) { t in singleTabBtn(t) } }
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
        let label: String = { switch mode { case .grid: return "Grid"; case .single: return "Single"; case .git: return "Git" } }()
        let selected = viewMode == mode
        return Button(action: { withAnimation(.easeInOut(duration: 0.2)) { viewMode = mode } }) {
            HStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: Theme.iconSize(9)))
                Text(label).font(Theme.chrome(8, weight: selected ? .bold : .regular))
            }
            .foregroundColor(selected ? Theme.accent : Theme.textDim).padding(.horizontal, 6).padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 4).fill(selected ? Theme.accent.opacity(0.12) : .clear))
        }.buttonStyle(.plain)
    }
    private func singleTabBtn(_ t: TerminalTab) -> some View {
        let a = manager.activeTabId == t.id
        let status = t.statusPresentation
        let dotColor: Color = {
            switch status.category {
            case .processing: return status.tint
            case .attention: return Theme.red
            case .completed: return Theme.green
            case .active, .idle: return t.workerColor
            }
        }()
        return Button(action: { manager.selectTab(t.id) }) {
            HStack(spacing: 4) {
                Circle().fill(dotColor).frame(width: 5, height: 5)
                Text(t.projectName).font(Theme.chrome(10)).foregroundColor(a ? Theme.textPrimary : Theme.textSecondary).lineLimit(1)
                if manager.userVisibleTabs.filter({ $0.projectPath == t.projectPath }).count > 1 {
                    Text(t.workerName).font(Theme.chrome(9)).foregroundColor(t.workerColor)
                }
            }.padding(.horizontal, 8).padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 5).fill(a ? Theme.bgSelected : .clear))
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
                        .foregroundColor(Theme.accent)
                } else {
                    Circle().fill(t.workerColor.opacity(0.5)).frame(width: 5, height: 5)
                }
                Text(t.projectName).font(Theme.chrome(10)).foregroundColor(isPinned ? Theme.textPrimary : Theme.textSecondary).lineLimit(1)
                if manager.userVisibleTabs.filter({ $0.projectPath == t.projectPath }).count > 1 {
                    Text(t.workerName).font(Theme.chrome(9)).foregroundColor(t.workerColor)
                }
            }
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 5).fill(isPinned ? Theme.accent.opacity(0.12) : .clear)
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(isPinned ? Theme.accent.opacity(0.3) : .clear, lineWidth: 1)))
        }.buttonStyle(.plain)
        .help("클릭하여 그리드에 표시/숨기기")
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - Event Stream View
// ═══════════════════════════════════════════════════════

struct EventStreamView: View {
    @EnvironmentObject var manager: SessionManager
    @ObservedObject var tab: TerminalTab
    @ObservedObject private var settings = AppSettings.shared
    let compact: Bool
    @State private var inputText = ""
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
    let elapsedTimer = Timer.publish(every: 3, on: .main, in: .common).autoconnect()

    // ═══════════════════════════════════════════
    // MARK: - Slash Commands
    // ═══════════════════════════════════════════

    private struct SlashCommand {
        let name: String
        let description: String
        let usage: String
        let category: String
        let action: (TerminalTab, SessionManager, [String]) -> Void

        init(_ name: String, _ desc: String, usage: String = "", category: String = "일반", action: @escaping (TerminalTab, SessionManager, [String]) -> Void) {
            self.name = name; self.description = desc; self.usage = usage; self.category = category; self.action = action
        }
    }

    private static let allSlashCommands: [SlashCommand] = [
        // ── 일반 ──
        SlashCommand("help", "사용 가능한 명령어 목록", category: "일반") { tab, _, args in
            let cmds = EventStreamView.allSlashCommands
            if let query = args.first?.lowercased() {
                let filtered = cmds.filter { $0.name.contains(query) || $0.description.contains(query) }
                if filtered.isEmpty { tab.appendBlock(.status(message: "⚠️ '\(query)' 관련 명령어를 찾을 수 없습니다")); return }
                let lines = filtered.map { "/\($0.name)\($0.usage.isEmpty ? "" : " \($0.usage)") — \($0.description)" }
                tab.appendBlock(.status(message: "🔍 검색 결과\n" + lines.joined(separator: "\n")))
            } else {
                var grouped: [String: [SlashCommand]] = [:]
                for c in cmds { grouped[c.category, default: []].append(c) }
                let order = ["일반", "모델/설정", "세션", "화면", "Git", "도구"]
                var text = "📜 명령어 목록 (/help <키워드>로 검색)\n"
                for cat in order {
                    guard let list = grouped[cat] else { continue }
                    text += "\n[\(cat)]\n"
                    for c in list { text += "  /\(c.name)\(c.usage.isEmpty ? "" : " \(c.usage)") — \(c.description)\n" }
                }
                tab.appendBlock(.status(message: text))
            }
        },
        SlashCommand("clear", "이벤트 스트림 초기화", category: "일반") { tab, _, _ in
            tab.clearBlocks()
            tab.appendBlock(.status(message: "🗑️ 로그가 초기화되었습니다"))
        },
        SlashCommand("cancel", "현재 작업 취소", category: "일반") { tab, _, _ in
            if tab.isProcessing { tab.cancelProcessing() }
            else { tab.appendBlock(.status(message: "ℹ️ 실행 중인 작업이 없습니다")) }
        },
        SlashCommand("stop", "진행 중인 명령어 강제 중지 (SIGKILL)", category: "일반") { tab, _, _ in
            if tab.isProcessing || tab.isRunning { tab.forceStop() }
            else { tab.appendBlock(.status(message: "ℹ️ 실행 중인 작업이 없습니다")) }
        },
        SlashCommand("copy", "마지막 응답을 클립보드에 복사", category: "일반") { tab, _, _ in
            if let last = tab.blocks.last(where: { if case .thought = $0.blockType { return true }; if case .completion = $0.blockType { return true }; return false }) {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(last.content, forType: .string)
                tab.appendBlock(.status(message: "📋 클립보드에 복사되었습니다 (\(last.content.count)자)"))
            } else { tab.appendBlock(.status(message: "⚠️ 복사할 응답이 없습니다")) }
        },
        SlashCommand("export", "대화 로그를 파일로 저장", category: "일반") { tab, _, _ in
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
            let path = "\(tab.projectPath)/workman_log_\(dateStr).txt"
            do { try text.write(toFile: path, atomically: true, encoding: .utf8)
                tab.appendBlock(.status(message: "📁 로그 저장: \(path)"))
            } catch { tab.appendBlock(.status(message: "⚠️ 저장 실패: \(error.localizedDescription)")) }
        },

        // ── 모델/설정 ──
        SlashCommand("model", "모델 변경", usage: "<opus|sonnet|haiku>", category: "모델/설정") { tab, _, args in
            guard let arg = args.first?.lowercased(),
                  let model = ClaudeModel.allCases.first(where: { $0.rawValue.lowercased().contains(arg) }) else {
                let current = tab.selectedModel
                tab.appendBlock(.status(message: "🤖 현재 모델: \(current.icon) \(current.rawValue)\n사용법: /model <opus|sonnet|haiku>"))
                return
            }
            tab.selectedModel = model
            tab.appendBlock(.status(message: "🤖 모델 변경: \(model.icon) \(model.rawValue)"))
        },
        SlashCommand("effort", "노력 수준 변경", usage: "<low|medium|high|max>", category: "모델/설정") { tab, _, args in
            guard let arg = args.first?.lowercased(),
                  let effort = EffortLevel.allCases.first(where: { $0.rawValue.lowercased() == arg }) else {
                let current = tab.effortLevel
                tab.appendBlock(.status(message: "💪 현재 노력 수준: \(current.icon) \(current.rawValue)\n사용법: /effort <low|medium|high|max>"))
                return
            }
            tab.effortLevel = effort
            tab.appendBlock(.status(message: "💪 노력 수준 변경: \(effort.icon) \(effort.rawValue)"))
        },
        SlashCommand("output", "출력 모드 변경", usage: "<full|realtime|result>", category: "모델/설정") { tab, _, args in
            guard let arg = args.first?.lowercased() else {
                tab.appendBlock(.status(message: "📺 현재 출력 모드: \(tab.outputMode.icon) \(tab.outputMode.rawValue)\n사용법: /output <full|realtime|result>"))
                return
            }
            let modeMap: [String: OutputMode] = ["full": .full, "전체": .full, "realtime": .realtime, "실시간": .realtime, "result": .resultOnly, "결과만": .resultOnly, "결과": .resultOnly]
            guard let mode = modeMap[arg] else { tab.appendBlock(.status(message: "⚠️ 알 수 없는 모드: \(arg)")); return }
            tab.outputMode = mode
            tab.appendBlock(.status(message: "📺 출력 모드 변경: \(mode.icon) \(mode.rawValue)"))
        },
        SlashCommand("permission", "권한 모드 변경", usage: "<bypass|auto|default|plan|edits>", category: "모델/설정") { tab, _, args in
            guard let arg = args.first?.lowercased() else {
                let c = tab.permissionMode
                tab.appendBlock(.status(message: "🛡️ 현재 권한: \(c.icon) \(c.displayName) — \(c.desc)\n사용법: /permission <bypass|auto|default|plan|edits>"))
                return
            }
            let map: [String: PermissionMode] = ["bypass": .bypassPermissions, "auto": .auto, "default": .defaultMode, "plan": .plan, "edits": .acceptEdits, "edit": .acceptEdits]
            guard let mode = map[arg] else { tab.appendBlock(.status(message: "⚠️ 알 수 없는 모드: \(arg)")); return }
            tab.permissionMode = mode
            tab.appendBlock(.status(message: "🛡️ 권한 변경: \(mode.icon) \(mode.displayName) — \(mode.desc)"))
        },
        SlashCommand("budget", "최대 예산 설정 (USD)", usage: "<금액|off>", category: "모델/설정") { tab, _, args in
            guard let arg = args.first else {
                let b = tab.maxBudgetUSD
                tab.appendBlock(.status(message: "💰 현재 예산: \(b > 0 ? "$\(String(format: "%.2f", b))" : "무제한")\n사용법: /budget <금액|off>"))
                return
            }
            if arg == "off" || arg == "0" { tab.maxBudgetUSD = 0; tab.appendBlock(.status(message: "💰 예산 제한 해제")); return }
            guard let v = Double(arg), v > 0 else { tab.appendBlock(.status(message: "⚠️ 올바른 금액을 입력하세요")); return }
            tab.maxBudgetUSD = v
            tab.appendBlock(.status(message: "💰 최대 예산 설정: $\(String(format: "%.2f", v))"))
        },
        SlashCommand("system", "시스템 프롬프트 설정", usage: "<프롬프트|clear>", category: "모델/설정") { tab, _, args in
            let text = args.joined(separator: " ")
            if text.isEmpty || text == "show" {
                let s = tab.systemPrompt.isEmpty ? "(없음)" : tab.systemPrompt
                tab.appendBlock(.status(message: "📝 시스템 프롬프트:\n\(s)"))
            } else if text == "clear" {
                tab.systemPrompt = ""
                tab.appendBlock(.status(message: "📝 시스템 프롬프트 초기화"))
            } else {
                tab.systemPrompt = text
                tab.appendBlock(.status(message: "📝 시스템 프롬프트 설정:\n\(text)"))
            }
        },
        SlashCommand("worktree", "워크트리 모드 토글", category: "모델/설정") { tab, _, _ in
            tab.useWorktree.toggle()
            tab.appendBlock(.status(message: "🌳 워크트리 모드: \(tab.useWorktree ? "켜짐" : "꺼짐")"))
        },
        SlashCommand("chrome", "크롬 연동 토글", category: "모델/설정") { tab, _, _ in
            tab.enableChrome.toggle()
            tab.appendBlock(.status(message: "🌐 크롬 연동: \(tab.enableChrome ? "켜짐" : "꺼짐")"))
        },
        SlashCommand("brief", "간결 모드 토글", category: "모델/설정") { tab, _, _ in
            tab.enableBrief.toggle()
            tab.appendBlock(.status(message: "✂️ 간결 모드: \(tab.enableBrief ? "켜짐" : "꺼짐")"))
        },

        // ── 세션 ──
        SlashCommand("stats", "현재 세션 통계", category: "세션") { tab, _, _ in
            let elapsed = Int(Date().timeIntervalSince(tab.startTime))
            let mins = elapsed / 60; let secs = elapsed % 60
            let stats = """
            📊 세션 통계
            ├ 작업자: \(tab.workerName) (\(tab.projectName))
            ├ 모델: \(tab.selectedModel.icon) \(tab.selectedModel.rawValue) · \(tab.effortLevel.icon) \(tab.effortLevel.rawValue)
            ├ 경과: \(mins)m \(secs)s
            ├ 토큰: \(tab.tokensUsed) (입력 \(tab.inputTokensUsed) / 출력 \(tab.outputTokensUsed))
            ├ 비용: $\(String(format: "%.4f", tab.totalCost))
            ├ 프롬프트: \(tab.completedPromptCount)회
            ├ 명령: \(tab.commandCount)개 · 에러: \(tab.errorCount)개
            ├ 블록: \(tab.blocks.count)개
            └ 파일 변경: \(tab.fileChanges.count)개
            """
            tab.appendBlock(.status(message: stats))
        },
        SlashCommand("restart", "세션 재시작", category: "세션") { tab, _, _ in
            if tab.isProcessing { tab.cancelProcessing() }
            tab.clearBlocks()
            tab.claudeActivity = .idle
            tab.start()
        },
        SlashCommand("continue", "이전 대화 이어서 진행", category: "세션") { tab, _, _ in
            tab.continueSession = true
            tab.appendBlock(.status(message: "🔗 다음 프롬프트는 이전 대화를 이어서 진행합니다"))
        },
        SlashCommand("resume", "이전 세션 이어서 진행", category: "세션") { tab, _, _ in
            tab.continueSession = true
            tab.appendBlock(.status(message: "🔗 resume 모드 활성화 — 다음 프롬프트가 이전 세션을 이어갑니다"))
        },
        SlashCommand("fork", "현재 대화를 분기하여 새 세션 시작", category: "세션") { tab, _, _ in
            tab.forkSession = true
            tab.appendBlock(.status(message: "🍴 fork 모드 활성화 — 다음 프롬프트가 대화를 분기합니다"))
        },

        // ── 화면 ──
        SlashCommand("scroll", "자동 스크롤 현재 상태 안내", category: "화면") { tab, _, _ in
            tab.appendBlock(.status(message: "📜 스크롤 팁: 스크롤을 위로 올리면 자동 스크롤이 멈추고, 맨 아래로 내리면 다시 켜집니다"))
        },
        SlashCommand("errors", "에러만 필터링하여 표시", category: "화면") { tab, _, _ in
            let errors = tab.blocks.filter { block in
                if block.isError { return true }
                switch block.blockType {
                case .error: return true
                case .toolError: return true
                default: return false
                }
            }
            if errors.isEmpty { tab.appendBlock(.status(message: "✅ 에러 없음!")); return }
            let text = errors.enumerated().map { (i, e) in "  \(i+1). \(e.content.prefix(200))" }.joined(separator: "\n")
            tab.appendBlock(.status(message: "🚨 에러 목록 (\(errors.count)개)\n\(text)"))
        },
        SlashCommand("files", "변경된 파일 목록", category: "화면") { tab, _, _ in
            if tab.fileChanges.isEmpty { tab.appendBlock(.status(message: "📁 변경된 파일 없음")); return }
            let text = tab.fileChanges.map { "  \($0.action == "Write" ? "📝" : "✏️") \($0.path)" }.joined(separator: "\n")
            tab.appendBlock(.status(message: "📁 변경된 파일 (\(tab.fileChanges.count)개)\n\(text)"))
        },
        SlashCommand("tokens", "토큰 사용량 상세", category: "화면") { tab, _, _ in
            let tracker = TokenTracker.shared
            let text = """
            🔢 토큰 사용량
            ├ 이 세션: \(tracker.formatTokens(tab.tokensUsed)) (입력 \(tracker.formatTokens(tab.inputTokensUsed)) / 출력 \(tracker.formatTokens(tab.outputTokensUsed)))
            ├ 오늘 전체: \(tracker.formatTokens(tracker.todayTokens))
            ├ 이번 주: \(tracker.formatTokens(tracker.weekTokens))
            ├ 비용 (세션): $\(String(format: "%.4f", tab.totalCost))
            ├ 비용 (오늘): $\(String(format: "%.4f", tracker.todayCost))
            └ 비용 (이번 주): $\(String(format: "%.4f", tracker.weekCost))
            """
            tab.appendBlock(.status(message: text))
        },
        SlashCommand("usage", "Claude 플랜 사용량 표시 (API에서 직접 조회)", category: "화면") { tab, _, _ in
            tab.appendBlock(.status(message: "⏳ Claude 사용량 조회 중..."))
            DispatchQueue.global(qos: .userInitiated).async { [weak tab] in
                let result = ClaudeUsageFetcher.fetch()
                DispatchQueue.main.async {
                    guard let tab = tab else { return }
                    // 마지막 "조회 중" 블록 제거
                    if let lastIdx = tab.blocks.indices.last,
                       tab.blocks[lastIdx].content.contains("조회 중") {
                        tab.blocks.remove(at: lastIdx)
                    }
                    tab.appendBlock(.status(message: result))
                }
            }
        },
        SlashCommand("config", "현재 설정 요약", category: "화면") { tab, _, _ in
            var lines = [
                "⚙️ 설정 요약",
                "├ 모델: \(tab.selectedModel.icon) \(tab.selectedModel.rawValue)",
                "├ 노력: \(tab.effortLevel.icon) \(tab.effortLevel.rawValue)",
                "├ 출력: \(tab.outputMode.icon) \(tab.outputMode.rawValue)",
                "├ 권한: \(tab.permissionMode.icon) \(tab.permissionMode.displayName)",
                "├ 예산: \(tab.maxBudgetUSD > 0 ? "$\(String(format: "%.2f", tab.maxBudgetUSD))" : "무제한")",
                "├ 워크트리: \(tab.useWorktree ? "✅" : "❌")",
                "├ 크롬: \(tab.enableChrome ? "✅" : "❌")",
                "├ 간결: \(tab.enableBrief ? "✅" : "❌")",
            ]
            if !tab.systemPrompt.isEmpty { lines.append("├ 시스템: \(tab.systemPrompt.prefix(50))...") }
            if !tab.allowedTools.isEmpty { lines.append("├ 허용 도구: \(tab.allowedTools)") }
            if !tab.disallowedTools.isEmpty { lines.append("├ 차단 도구: \(tab.disallowedTools)") }
            lines.append("└ 프로젝트: \(tab.projectPath)")
            tab.appendBlock(.status(message: lines.joined(separator: "\n")))
        },

        // ── Git ──
        SlashCommand("git", "Git 상태 확인", category: "Git") { tab, _, _ in
            tab.refreshGitInfo()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let g = tab.gitInfo
                if !g.isGitRepo { tab.appendBlock(.status(message: "⚠️ Git 저장소가 아닙니다")); return }
                let text = """
                🔀 Git 상태
                ├ 브랜치: \(g.branch)
                ├ 변경 파일: \(g.changedFiles)개
                ├ 마지막 커밋: \(g.lastCommit)
                └ 커밋 시간: \(g.lastCommitAge)
                """
                tab.appendBlock(.status(message: text))
            }
        },
        SlashCommand("branch", "현재 브랜치 표시", category: "Git") { tab, _, _ in
            tab.refreshGitInfo()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                tab.appendBlock(.status(message: "🌿 브랜치: \(tab.gitInfo.branch.isEmpty ? "(없음)" : tab.gitInfo.branch)"))
            }
        },

        // ── 도구 ──
        SlashCommand("allow", "허용 도구 설정", usage: "<tool1,tool2,...|clear>", category: "도구") { tab, _, args in
            let text = args.joined(separator: " ")
            if text.isEmpty || text == "show" {
                tab.appendBlock(.status(message: "✅ 허용 도구: \(tab.allowedTools.isEmpty ? "(전체)" : tab.allowedTools)"))
            } else if text == "clear" {
                tab.allowedTools = ""
                tab.appendBlock(.status(message: "✅ 도구 제한 해제 (전체 허용)"))
            } else {
                tab.allowedTools = text
                tab.appendBlock(.status(message: "✅ 허용 도구 설정: \(text)"))
            }
        },
        SlashCommand("deny", "차단 도구 설정", usage: "<tool1,tool2,...|clear>", category: "도구") { tab, _, args in
            let text = args.joined(separator: " ")
            if text.isEmpty || text == "show" {
                tab.appendBlock(.status(message: "🚫 차단 도구: \(tab.disallowedTools.isEmpty ? "(없음)" : tab.disallowedTools)"))
            } else if text == "clear" {
                tab.disallowedTools = ""
                tab.appendBlock(.status(message: "🚫 도구 차단 해제"))
            } else {
                tab.disallowedTools = text
                tab.appendBlock(.status(message: "🚫 도구 차단 설정: \(text)"))
            }
        },
        SlashCommand("pr", "PR 번호로 리뷰 시작", usage: "<PR번호>", category: "도구") { tab, _, args in
            guard let num = args.first else {
                tab.appendBlock(.status(message: "⚠️ 사용법: /pr <PR번호>"))
                return
            }
            tab.fromPR = num
            tab.appendBlock(.status(message: "🔍 PR #\(num) — 다음 프롬프트에서 이 PR을 컨텍스트로 사용합니다"))
        },
        SlashCommand("name", "세션 이름 설정", usage: "<이름>", category: "세션") { tab, _, args in
            let n = args.joined(separator: " ")
            if n.isEmpty { tab.appendBlock(.status(message: "📛 현재 이름: \(tab.sessionName.isEmpty ? "(없음)" : tab.sessionName)")); return }
            tab.sessionName = n
            tab.appendBlock(.status(message: "📛 세션 이름: \(n)"))
        },
        SlashCommand("compare", "두 세션 비교", usage: "<세션1이름> <세션2이름>", category: "세션") { tab, manager, args in
            let allTabs = manager.userVisibleTabs

            if allTabs.count < 2 {
                tab.appendBlock(.status(message: "비교하려면 최소 2개 세션이 필요합니다."))
                return
            }

            let tab1: TerminalTab
            let tab2: TerminalTab

            if args.count >= 2 {
                let name1 = args[0].lowercased()
                let name2 = args[1].lowercased()
                guard let t1 = allTabs.first(where: { $0.workerName.lowercased().contains(name1) }),
                      let t2 = allTabs.first(where: { $0.workerName.lowercased().contains(name2) && $0.id != t1.id }) else {
                    tab.appendBlock(.status(message: "세션을 찾을 수 없습니다. 이름을 확인하세요.\n사용 가능: " + allTabs.map(\.workerName).joined(separator: ", ")))
                    return
                }
                tab1 = t1; tab2 = t2
            } else {
                // 인자 없으면 처음 2개 비교
                tab1 = allTabs[0]; tab2 = allTabs[1]
            }

            let dur1 = Int(Date().timeIntervalSince(tab1.startTime))
            let dur2 = Int(Date().timeIntervalSince(tab2.startTime))

            func fmtDur(_ s: Int) -> String {
                if s < 60 { return "\(s)초" }
                if s < 3600 { return "\(s/60)분 \(s%60)초" }
                return "\(s/3600)시간 \(s%3600/60)분"
            }

            func fmtTokens(_ n: Int) -> String {
                if n >= 1000 { return String(format: "%.1fK", Double(n)/1000) }
                return "\(n)"
            }

            let lines = [
                "⚖️ 세션 비교",
                "══════════════════════════════════════════════════",
                "",
                String(format: "%-20s │ %-20s │ %-20s", "항목", tab1.workerName, tab2.workerName),
                "─────────────────────┼──────────────────────┼──────────────────────",
                String(format: "%-20s │ %-20s │ %-20s", "프로젝트", String(tab1.projectName.prefix(18)), String(tab2.projectName.prefix(18))),
                String(format: "%-20s │ %-20s │ %-20s", "상태", tab1.isProcessing ? "진행 중" : (tab1.isCompleted ? "완료" : "대기"), tab2.isProcessing ? "진행 중" : (tab2.isCompleted ? "완료" : "대기")),
                String(format: "%-20s │ %-20s │ %-20s", "모델", tab1.selectedModel.rawValue, tab2.selectedModel.rawValue),
                String(format: "%-20s │ %-20s │ %-20s", "토큰 (입력)", fmtTokens(tab1.inputTokensUsed), fmtTokens(tab2.inputTokensUsed)),
                String(format: "%-20s │ %-20s │ %-20s", "토큰 (출력)", fmtTokens(tab1.outputTokensUsed), fmtTokens(tab2.outputTokensUsed)),
                String(format: "%-20s │ %-20s │ %-20s", "토큰 (총)", fmtTokens(tab1.tokensUsed), fmtTokens(tab2.tokensUsed)),
                String(format: "%-20s │ %-20s │ %-20s", "비용", String(format: "$%.4f", tab1.totalCost), String(format: "$%.4f", tab2.totalCost)),
                String(format: "%-20s │ %-20s │ %-20s", "명령 수", "\(tab1.commandCount)", "\(tab2.commandCount)"),
                String(format: "%-20s │ %-20s │ %-20s", "파일 변경", "\(tab1.fileChanges.count)개", "\(tab2.fileChanges.count)개"),
                String(format: "%-20s │ %-20s │ %-20s", "에러", "\(tab1.errorCount)", "\(tab2.errorCount)"),
                String(format: "%-20s │ %-20s │ %-20s", "경과 시간", fmtDur(dur1), fmtDur(dur2)),
                "",
                "══════════════════════════════════════════════════",
            ]

            tab.appendBlock(.status(message: lines.joined(separator: "\n")))
        },
        SlashCommand("timeline", "세션 타임라인 보기", category: "세션") { tab, _, _ in
            if tab.timeline.isEmpty {
                tab.appendBlock(.status(message: "타임라인이 비어있습니다."))
                return
            }
            let df = DateFormatter()
            df.dateFormat = "HH:mm:ss"
            var lines = ["📋 세션 타임라인", "═══════════════════════════════"]
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
                lines.append("\(time) \(icon) \(event.type.rawValue): \(event.detail)")
            }
            tab.appendBlock(.status(message: lines.joined(separator: "\n")))
        },
        SlashCommand("sleepwork", "슬립워크 모드 시작", usage: "<작업내용> [토큰예산]", category: "세션") { tab, _, args in
            if args.isEmpty {
                tab.appendBlock(.status(message: "사용법: /sleepwork <작업내용> [토큰예산]\n예: /sleepwork \"버그 수정해줘\" 10k\n\n또는 🌙 버튼을 눌러 설정 화면을 사용하세요."))
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
                tab.appendBlock(.status(message: "작업 내용을 입력하세요."))
                return
            }
            tab.startSleepWork(task: task, tokenBudget: budget)
        },
        SlashCommand("search", "전체 세션에서 검색", usage: "<검색어>", category: "화면") { tab, manager, args in
            let query = args.joined(separator: " ").trimmingCharacters(in: .whitespaces)
            guard !query.isEmpty else {
                tab.appendBlock(.status(message: "사용법: /search <검색어>"))
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
                tab.appendBlock(.status(message: "🔍 '\(query)' 검색 결과 없음"))
                return
            }

            var lines = ["🔍 '\(query)' 검색 결과 (\(results.count)건)", "═══════════════════════════════"]
            for r in results.prefix(20) {
                lines.append("[\(r.tabName)] \(r.blockContent)")
            }
            if results.count > 20 {
                lines.append("... 외 \(results.count - 20)건")
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

    var body: some View {
        if settings.rawTerminalMode {
            rawTerminalBody
        } else {
            normalBody
        }
    }

    // MARK: - Raw Terminal Body (NSView 기반 진짜 CLI)

    private var rawTerminalBody: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Button(action: { tab.forceStop() }) {
                    Circle().fill(Color.red.opacity(0.85)).frame(width: 10, height: 10)
                }.buttonStyle(.plain).help("세션 종료")
                Text("claude — \(tab.projectName)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(Color(red: 0.45, green: 0.45, blue: 0.5))
                Spacer()
            }
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(Color(red: 0.15, green: 0.15, blue: 0.15))

            CLITerminalView(tab: tab, fontSize: 13 * settings.fontSizeScale)
        }
        .background(Color(red: 0.1, green: 0.1, blue: 0.1))
    }

    // MARK: - Normal Body (WorkMan UI)

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
                    .onChange(of: tab.blocks.count) { _, newCount in
                        if autoScroll && newCount != lastBlockCount {
                            lastBlockCount = newCount
                            scrollWorkItem?.cancel()
                            let item = DispatchWorkItem { scrollToEnd(proxy) }
                            scrollWorkItem = item
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: item)
                        }
                    }
                    .onChange(of: tab.isProcessing) { _, processing in
                        // 처리 완료 시 최종 결과로 스크롤
                        if !processing && autoScroll {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { scrollToEnd(proxy) }
                        }
                    }
                    .onChange(of: tab.claudeActivity) { _, _ in
                        // 활동 상태 변경될 때마다 스크롤 (tool 전환 등)
                        if autoScroll {
                            scrollWorkItem?.cancel()
                            let item = DispatchWorkItem { scrollToEnd(proxy) }
                            scrollWorkItem = item
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: item)
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
        .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { isFocused = true } }
        .onAppear { syncPlanSelectionState(with: activePlanSelectionRequest) }
        .onChange(of: activePlanSelectionRequest?.signature ?? "") { _, _ in
            syncPlanSelectionState(with: activePlanSelectionRequest)
        }
        .onReceive(elapsedTimer) { _ in
            if tab.isProcessing || tab.claudeActivity != .idle {
                elapsedSeconds = Int(Date().timeIntervalSince(tab.startTime))
            }
        }
        // 승인 모달 + 슬립워크 (overlay로 처리하여 부모 sheet과 충돌 방지)
        .overlay {
            if let approval = tab.pendingApproval {
                Color.black.opacity(0.4).ignoresSafeArea()
                ApprovalSheet(approval: approval)
                    .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
            }
        }
        .overlay {
            if showSleepWorkSetup {
                Color.black.opacity(0.4).ignoresSafeArea()
                    .onTapGesture { showSleepWorkSetup = false }
                SleepWorkSetupSheet(tab: tab, onDismiss: { showSleepWorkSetup = false })
                    .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
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
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(color.opacity(0.3), lineWidth: 1))
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
                    Text("필터").font(Theme.chrome(8, weight: showFilterBar ? .bold : .regular))
                }
                .foregroundColor(showFilterBar || blockFilter.isActive ? Theme.accent : Theme.textDim)
                .padding(.horizontal, 5).padding(.vertical, 2)
                .background(showFilterBar ? Theme.accent.opacity(0.08) : .clear).cornerRadius(4)
            }.buttonStyle(.plain).help("로그 필터")

            Button(action: { withAnimation(.easeInOut(duration: 0.15)) { showFilePanel.toggle() } }) {
                HStack(spacing: 3) {
                    Image(systemName: "doc.text.magnifyingglass").font(Theme.chrome(8))
                    Text("파일").font(Theme.chrome(8, weight: showFilePanel ? .bold : .regular))
                }
                .foregroundColor(showFilePanel ? Theme.accent : Theme.textDim)
                .padding(.horizontal, 5).padding(.vertical, 2)
                .background(showFilePanel ? Theme.accent.opacity(0.08) : .clear).cornerRadius(4)
            }.buttonStyle(.plain).help("파일 변경")
        }
        .padding(.horizontal, 12).padding(.vertical, 5)
        .background(Theme.bgSurface.opacity(0.5))
        .overlay(Rectangle().fill(Theme.border).frame(height: 1), alignment: .bottom)
    }

    private var activityLabel: String {
        switch tab.claudeActivity {
        case .idle: return "대기"; case .thinking: return "생각 중"; case .reading: return "읽는 중"
        case .writing: return "작성 중"; case .searching: return "검색 중"; case .running: return "실행 중"
        case .done: return "완료"; case .error: return "에러"
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
                    Text("Clear").font(Theme.chrome(8)).foregroundColor(Theme.accent)
                }.buttonStyle(.plain)
            }
            // Search
            HStack(spacing: 3) {
                Image(systemName: "magnifyingglass").font(Theme.chrome(8)).foregroundColor(Theme.textDim)
                TextField("검색...", text: $blockFilter.searchText)
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
        .accessibilityLabel("\(tool) 필터")
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
                Image(systemName: "doc.text").font(Theme.chrome(9)).foregroundColor(Theme.accent)
                Text("FILES").font(Theme.pixel).foregroundColor(Theme.textDim).tracking(1.5)
                Spacer()
                Text("\(Set(tab.fileChanges.map(\.fileName)).count)")
                    .font(Theme.chrome(9, weight: .bold)).foregroundColor(Theme.accent)
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
                        Text("변경된 파일 없음").font(Theme.chrome(10)).foregroundColor(Theme.textDim)
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

    private var filteredBlocks: [StreamBlock] {
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
                // Model
                settingGroup("Model") {
                    ForEach(ClaudeModel.allCases) { m in
                        settingChip(m.displayName, isSelected: tab.selectedModel == m, color: modelColor(m)) { tab.selectedModel = m }
                    }
                }

                settingSep

                // Effort
                settingGroup("Effort") {
                    ForEach(EffortLevel.allCases) { l in
                        let name = l.rawValue.prefix(1).uppercased() + l.rawValue.dropFirst()
                        settingChip(name, isSelected: tab.effortLevel == l, color: Theme.accent) { tab.effortLevel = l }
                    }
                }

                settingSep

                // Output
                settingGroup("Output") {
                    ForEach(OutputMode.allCases) { m in
                        settingChip(m.rawValue, isSelected: tab.outputMode == m, color: Theme.cyan) { tab.outputMode = m }
                    }
                }

                settingSep

                // Permission
                settingGroup("권한") {
                    ForEach(PermissionMode.allCases) { m in
                        settingChip(m.displayName, isSelected: tab.permissionMode == m, color: permissionColor(m)) { tab.permissionMode = m }
                            .help(m.desc)
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
                                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.border, lineWidth: 0.5))
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
                    Text(">").font(Theme.chrome(12, weight: .semibold)).foregroundColor(Theme.accent)
                }.padding(.bottom, 4)

                // Auto-growing TextEditor
                ZStack(alignment: .topLeading) {
                    // Placeholder
                    if inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(tab.isProcessing ? "실행 중..." : "명령을 입력하세요")
                            .font(Theme.monoNormal).foregroundColor(Theme.textDim.opacity(0.5))
                            .padding(.horizontal, 4).padding(.vertical, 8)
                            .allowsHitTesting(false)
                    }
                    // Hidden text for height calculation
                    Text(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? " " : inputText)
                        .font(Theme.monoNormal).foregroundColor(.clear)
                        .padding(.horizontal, 4).padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    // Actual editor
                    TextEditor(text: $inputText)
                        .font(Theme.monoNormal).foregroundColor(Theme.textPrimary)
                        .focused($isFocused)
                        .disabled(tab.isProcessing)
                        .scrollContentBackground(.hidden)
                        .padding(.horizontal, 0).padding(.vertical, 4)
                        .accessibilityLabel("명령 입력")
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
                .onChange(of: inputText) { _, _ in selectedCommandIndex = 0 }

                // 이미지 첨부
                Button(action: { pickImage() }) {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: Theme.iconSize(11)))
                        .foregroundColor(tab.attachedImages.isEmpty ? Theme.textDim : Theme.cyan)
                }
                .buttonStyle(.plain)
                .help("이미지 첨부 (Cmd+Shift+I)")
                .padding(.bottom, 4)

                Button(action: { showSleepWorkSetup = true }) {
                    Image(systemName: "moon.zzz.fill")
                        .font(.system(size: Theme.iconSize(11)))
                        .foregroundColor(Theme.purple)
                }
                .buttonStyle(.plain)
                .help("슬립워크")
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
                if inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("입력...").font(Theme.monoSmall).foregroundColor(Theme.textDim.opacity(0.5))
                        .padding(.horizontal, 4).padding(.vertical, 6)
                        .allowsHitTesting(false)
                }
                Text(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? " " : inputText)
                    .font(Theme.monoSmall).foregroundColor(.clear)
                    .padding(.horizontal, 4).padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                TextEditor(text: $inputText)
                    .font(Theme.monoSmall).foregroundColor(Theme.textPrimary)
                    .focused($isFocused).disabled(tab.isProcessing)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 0).padding(.vertical, 2)
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
            Text("슬립워크 진행 중").font(Theme.chrome(9, weight: .bold)).foregroundColor(Theme.purple)

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
                Text("중단").font(Theme.chrome(9, weight: .bold)).foregroundColor(Theme.red)
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
        panel.title = "이미지 첨부"
        panel.message = "Claude에 보낼 이미지를 선택하세요"
        if panel.runModal() == .OK {
            tab.attachedImages.append(contentsOf: panel.urls)
        }
    }

    private func submit() {
        let p = inputText.trimmingCharacters(in: .whitespaces); guard !p.isEmpty else { return }
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
                inputText = ""; selectedCommandIndex = 0
                tab.appendBlock(.userPrompt, content: "/\(cmd.name)" + (args.isEmpty ? "" : " " + args.joined(separator: " ")))
                cmd.action(tab, manager, args)
                return
            }
        }

        inputText = ""; tab.sendPrompt(p)
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
                Image(systemName: "command").font(Theme.chrome(8)).foregroundColor(Theme.accent)
                Text("명령어").font(Theme.chrome(8, weight: .bold)).foregroundColor(Theme.accent)
                if commands.count < Self.allSlashCommands.count {
                    Text("\(commands.count)개 일치").font(Theme.chrome(7)).foregroundColor(Theme.textDim)
                }
                Spacer()
                Text("↑↓ 선택  Tab 완성  Enter 실행  Esc 닫기").font(Theme.chrome(7)).foregroundColor(Theme.textDim)
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
        let responseBlocks = tab.blocks.suffix(from: tab.blocks.index(after: lastUserPromptIndex))
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
                Text("플랜 선택")
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
                        Text("초기화")
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
                    Text("입력창에 넣기")
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
                    Text("선택 보내기")
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
                    .foregroundColor(Theme.accent)
                Text("인수 흐름")
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
                        .stroke(isSelected ? color.opacity(0.3) : .clear, lineWidth: 0.5)
                )
        }.buttonStyle(.plain)
    }

    private func modelColor(_ m: ClaudeModel) -> Color {
        switch m {
        case .opus: return Theme.purple
        case .sonnet: return Theme.accent
        case .haiku: return Theme.green
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
}

private struct PlanSelectionRequest {
    struct Group: Identifiable {
        let id: String
        let title: String
        let options: [Option]
    }

    struct Option: Identifiable {
        let id: String
        let key: String
        let label: String
    }

    let signature: String
    let promptLine: String?
    let groups: [Group]

    static func parse(from text: String) -> PlanSelectionRequest? {
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
                    currentTitle = "선택"
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

    func responseText(from selections: [String: String]) -> String {
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
            let inner = trimmed[trimmed.index(after: trimmed.startIndex)..<closeIdx]
            guard inner.count >= 1, inner.count <= 2 else { return nil }
            let key = String(inner).uppercased()
            let label = String(trimmed[trimmed.index(after: closeIdx)...]).trimmingCharacters(in: .whitespacesAndNewlines)
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

struct EventBlockView: View {
    @ObservedObject var block: StreamBlock
    @ObservedObject private var settings = AppSettings.shared
    let compact: Bool

    var body: some View {
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
            Text(">").font(Theme.mono(13, weight: .bold)).foregroundColor(Theme.accent)
            Text(block.content).font(Theme.mono(compact ? 11 : 13)).foregroundColor(Theme.accent)
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
                Text("완료").font(Theme.mono(10, weight: .bold)).foregroundColor(Theme.green)
                if let d = duration {
                    Text("\(d/1000).\(d%1000/100)s").font(Theme.mono(8)).foregroundColor(Theme.textDim)
                }
                if let c = cost, c > 0 {
                    Text(String(format: "$%.4f", c)).font(Theme.mono(8, weight: .semibold)).foregroundColor(Theme.yellow)
                }
            }

            if !block.content.isEmpty && block.content != "완료" {
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

struct ToolOutputBlockView: View {
    @ObservedObject var block: StreamBlock
    let compact: Bool
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
            return (head + ["    ... \(hidden)줄 생략 ..."] + tail).joined(separator: "\n")
        }
        let head = lines.prefix(6)
        let tail = lines.suffix(4)
        let hidden = lines.count - 10
        return (head + ["    ... \(hidden)줄 생략 ..."] + tail).joined(separator: "\n")
    }

    var body: some View {
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
                        Text(isExpanded ? "접기" : "전체 보기 (\(lines.count)줄)")
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

struct MarkdownTextView: View {
    let text: String
    let compact: Bool

    // Pre-compiled regex patterns (avoid recompilation on every inlineMarkdown call)
    private static let boldRegex = try! NSRegularExpression(pattern: "\\*\\*(.+?)\\*\\*")
    private static let codeRegex = try! NSRegularExpression(pattern: "`([^`]+)`")

    var body: some View {
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
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.border.opacity(0.5), lineWidth: 0.5))
                        .textSelection(.enabled)
                case .bullet(let content):
                    HStack(alignment: .top, spacing: 6) {
                        Text("•").font(Theme.mono(compact ? 10 : 11)).foregroundColor(Theme.accent)
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
            let boldMatch = Self.boldRegex.firstMatch(in: text, range: searchRange)
            let codeMatch = Self.codeRegex.firstMatch(in: text, range: searchRange)

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
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.border.opacity(0.5), lineWidth: 0.5))
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

struct ProcessingIndicator: View {
    let activity: ClaudeActivity
    let workerColor: Color
    let workerName: String
    @ObservedObject private var settings = AppSettings.shared
    @State private var dotPhase = 0
    let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()

    var body: some View {
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
        case .thinking: return "생각 중"
        case .reading: return "읽는 중"
        case .writing: return "작성 중"
        case .searching: return "검색 중"
        case .running: return "실행 중"
        default: return "처리 중"
        }
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - Grid Panel View
// ═══════════════════════════════════════════════════════

struct GridPanelView: View {
    @EnvironmentObject var manager: SessionManager

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

    var body: some View {
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
struct GridSinglePanel: View {
    @ObservedObject var tab: TerminalTab
    @ObservedObject private var settings = AppSettings.shared
    let isSelected: Bool

    var body: some View {
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
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(isSelected ? Theme.accent.opacity(0.5) : Theme.border, lineWidth: isSelected ? 1.5 : 0.5))
    }
}

struct GridGroupPanel: View {
    let group: SessionManager.ProjectGroup
    @EnvironmentObject var manager: SessionManager
    @ObservedObject private var settings = AppSettings.shared
    @State private var selectedWorkerIndex = 0

    private var activeTab: TerminalTab? {
        guard !group.tabs.isEmpty else { return nil }
        let idx = min(max(0, selectedWorkerIndex), group.tabs.count - 1)
        return group.tabs[idx]
    }

    var body: some View {
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
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(group.hasActiveTab ? Theme.accent.opacity(0.5) : Theme.border, lineWidth: group.hasActiveTab ? 1.5 : 0.5))
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

struct ApprovalSheet: View {
    let approval: TerminalTab.PendingApproval
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.shield.fill").font(.system(size: Theme.iconSize(20))).foregroundColor(Theme.yellow)
                Text("승인 필요").font(Theme.mono(14, weight: .bold)).foregroundColor(Theme.textPrimary)
            }
            Text(approval.reason).font(Theme.monoSmall).foregroundColor(Theme.textSecondary)
            Text(approval.command).font(Theme.mono(11)).foregroundColor(Theme.red)
                .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 6).fill(Theme.red.opacity(0.05)))
                .textSelection(.enabled)
            HStack {
                Button(action: { approval.onDeny?(); dismiss() }) {
                    Text("거부").font(Theme.mono(11, weight: .medium)).foregroundColor(Theme.red)
                        .padding(.horizontal, 20).padding(.vertical, 8)
                        .background(Theme.red.opacity(0.1)).cornerRadius(6)
                }.buttonStyle(.plain).keyboardShortcut(.escape)
                Spacer()
                Button(action: { approval.onApprove?(); dismiss() }) {
                    Text("승인").font(Theme.mono(11, weight: .medium)).foregroundColor(Theme.textOnAccent)
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

struct EmptySessionView: View {
    var body: some View {
        VStack {
            Spacer()
            AppEmptyStateView(
                title: "세션이 아직 없습니다",
                message: "Cmd+T 또는 새 세션 시작 버튼으로 바로 작업을 시작할 수 있습니다.",
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

struct NewSessionProjectRecord: Codable, Identifiable, Hashable {
    let path: String
    var name: String
    var lastUsedAt: Date
    var isFavorite: Bool

    var id: String { path }
}

struct NewSessionDraftSnapshot: Codable {
    var selectedModel: String
    var effortLevel: String
    var permissionMode: String
    var terminalCount: Int
    var systemPrompt: String
    var maxBudget: String
    var allowedTools: String
    var disallowedTools: String
    var additionalDirs: [String]
    var continueSession: Bool
    var useWorktree: Bool
}

private enum NewSessionPreset: String, CaseIterable, Identifiable {
    case balanced
    case planFirst
    case safeReview
    case parallelBuild

    var id: String { rawValue }

    var title: String {
        switch self {
        case .balanced: return "기본 작업"
        case .planFirst: return "플랜 우선"
        case .safeReview: return "안전 검토"
        case .parallelBuild: return "병렬 구현"
        }
    }

    var subtitle: String {
        switch self {
        case .balanced: return "일반 개발 시작"
        case .planFirst: return "계획만 먼저 정리"
        case .safeReview: return "보수적 권한으로 검토"
        case .parallelBuild: return "여러 터미널로 분배"
        }
    }

    var tint: Color {
        switch self {
        case .balanced: return Theme.accent
        case .planFirst: return Theme.purple
        case .safeReview: return Theme.orange
        case .parallelBuild: return Theme.cyan
        }
    }

    var symbol: String {
        switch self {
        case .balanced: return "hammer.fill"
        case .planFirst: return "list.bullet.clipboard.fill"
        case .safeReview: return "shield.fill"
        case .parallelBuild: return "square.grid.3x1.folder.badge.plus"
        }
    }
}

final class NewSessionPreferencesStore: ObservableObject {
    static let shared = NewSessionPreferencesStore()

    @Published private(set) var favoriteProjects: [NewSessionProjectRecord] = []
    @Published private(set) var recentProjects: [NewSessionProjectRecord] = []
    @Published private(set) var lastDraft: NewSessionDraftSnapshot?

    private let favoritesKey = "workman.new-session.favorite-projects"
    private let recentsKey = "workman.new-session.recent-projects"
    private let lastDraftKey = "workman.new-session.last-draft"

    private init() {
        load()
    }

    func isFavorite(path: String) -> Bool {
        favoriteProjects.contains(where: { $0.path == path })
    }

    func toggleFavorite(projectName: String, projectPath: String) {
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

    func suggestedProjects(currentTabs: [TerminalTab], savedSessions: [SavedSession]) -> [NewSessionProjectRecord] {
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

    func rememberLaunch(projectName: String, projectPath: String, draft: NewSessionDraftSnapshot) {
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
}

private extension Array {
    func prefixArray(_ maxCount: Int) -> [Element] {
        Array(prefix(maxCount))
    }
}

struct NewTabSheet: View {
    @EnvironmentObject var manager: SessionManager; @Environment(\.dismiss) var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var preferences = NewSessionPreferencesStore.shared
    @State private var projectName = ""
    @State private var projectPath = ""
    @State private var terminalCount = 1
    @State private var tasks: [String] = [""]

    // 폴더 신뢰 확인
    @State private var trustConfirmed = false
    @State private var showTrustPrompt = false
    @State private var didBootstrap = false
    @State private var pathError: String?

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
    @State private var selectedModel: ClaudeModel = .sonnet
    @State private var effortLevel: EffortLevel = .medium

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

    var body: some View {
        Group {
            if showTrustPrompt {
                trustPromptView
            } else {
                sessionConfigView
            }
        }
        .onAppear {
            bootstrapFromLastDraftIfNeeded()
        }
    }

    // MARK: - 폴더 신뢰 확인 화면

    private var trustPromptView: some View {
        VStack(spacing: 0) {
            // 터미널 스타일 헤더
            VStack(spacing: 12) {
                Image(systemName: "shield.checkered")
                    .font(.system(size: Theme.iconSize(28))).foregroundColor(Theme.yellow)

                Text("폴더 신뢰 확인")
                    .font(Theme.mono(14, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
            }.padding(.top, 20).padding(.bottom, 12)

            // 경로 표시
            HStack(spacing: 6) {
                Image(systemName: "folder.fill").font(.system(size: Theme.iconSize(10))).foregroundColor(Theme.accent)
                Text(projectPath)
                    .font(Theme.mono(10))
                    .foregroundColor(Theme.accent).lineLimit(1).truncationMode(.middle)
            }
            .padding(.horizontal, 16).padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 8).fill(Theme.accent.opacity(0.06)))
            .padding(.horizontal, 24)

            // 안내 텍스트
            VStack(alignment: .leading, spacing: 8) {
                Text("이 프로젝트를 직접 만들었거나 신뢰할 수 있나요?")
                    .font(Theme.mono(11, weight: .medium))
                    .foregroundColor(Theme.textPrimary)

                Text("(직접 작성한 코드, 잘 알려진 오픈소스, 또는 팀 프로젝트 등)")
                    .font(Theme.mono(9))
                    .foregroundColor(Theme.textDim)

                Rectangle().fill(Theme.border).frame(height: 1).padding(.vertical, 4)

                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill").font(.system(size: Theme.iconSize(9))).foregroundColor(Theme.yellow)
                    Text("Claude Code가 이 폴더의 파일을 읽고, 수정하고, 실행할 수 있습니다.")
                        .font(Theme.mono(9)).foregroundColor(Theme.yellow)
                }
            }
            .padding(16).padding(.horizontal, 8)

            Spacer(minLength: 8)

            // 선택 버튼
            VStack(spacing: 6) {
                Button(action: {
                    withAnimation(sheetAnimation) {
                        trustConfirmed = true
                        showTrustPrompt = false
                    }
                    createSessions()
                    dismiss()
                }) {
                    HStack(spacing: 8) {
                        Text("❯").font(Theme.mono(12, weight: .bold)).foregroundColor(Theme.green)
                        Text("네, 이 폴더를 신뢰합니다")
                            .font(Theme.mono(11, weight: .semibold)).foregroundColor(Theme.textPrimary)
                        Spacer()
                        Image(systemName: "checkmark.shield.fill").font(.system(size: Theme.iconSize(12))).foregroundColor(Theme.green)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Theme.green.opacity(0.08))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.green.opacity(0.3), lineWidth: 1)))
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.return)
                .accessibilityLabel("이 폴더를 신뢰하고 세션 시작")
                .accessibilityHint("프로젝트 폴더를 신뢰 목록으로 보고 새 세션을 생성합니다")

                Button(action: {
                    withAnimation(sheetAnimation) {
                        showTrustPrompt = false
                    }
                }) {
                    HStack(spacing: 8) {
                        Text(" ").font(Theme.mono(12, weight: .bold))
                        Text("아니오, 돌아가기")
                            .font(Theme.mono(11)).foregroundColor(Theme.textSecondary)
                        Spacer()
                        Image(systemName: "xmark.circle").font(.system(size: Theme.iconSize(12))).foregroundColor(Theme.textDim)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Theme.bgSurface)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border.opacity(0.3), lineWidth: 1)))
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape)
                .accessibilityLabel("폴더 신뢰 확인 닫기")
            }.padding(.horizontal, 24).padding(.bottom, 20)
        }
        .frame(width: max(440, 440 * AppSettings.shared.fontSizeScale), height: max(340, 340 * AppSettings.shared.fontSizeScale))
        .background(Theme.bgCard)
    }

    // MARK: - 세션 설정 화면

    private var sessionConfigView: some View {
        VStack(spacing: 0) {
            DSModalHeader(
                icon: "plus.circle.fill",
                iconColor: Theme.accent,
                title: "새 세션",
                subtitle: "프로젝트 경로를 선택하고 실행 규칙만 정하면 바로 시작할 수 있습니다."
            )

            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: Theme.sp4) {

                    configSection(title: "빠른 시작", subtitle: "최근 프로젝트와 마지막 설정을 바로 불러올 수 있습니다.") {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(spacing: 8) {
                                Button(action: { applyLastDraftIfAvailable() }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "clock.arrow.circlepath")
                                        Text("마지막 설정 불러오기")
                                    }
                                    .font(Theme.mono(9, weight: .bold))
                                    .appButtonSurface(tone: .neutral, compact: true)
                                }
                                .buttonStyle(.plain)
                                .disabled(preferences.lastDraft == nil)
                                .accessibilityLabel("마지막 세션 설정 불러오기")

                                if !projectPath.isEmpty {
                                    Button(action: {
                                        preferences.toggleFavorite(projectName: resolvedProjectName, projectPath: projectPath)
                                    }) {
                                        HStack(spacing: 6) {
                                            Image(systemName: isCurrentProjectFavorite ? "star.fill" : "star")
                                            Text(isCurrentProjectFavorite ? "즐겨찾기됨" : "즐겨찾기")
                                        }
                                        .font(Theme.mono(9, weight: .bold))
                                        .appButtonSurface(tone: .yellow, compact: true)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel(isCurrentProjectFavorite ? "현재 프로젝트 즐겨찾기 해제" : "현재 프로젝트 즐겨찾기")
                                }
                            }

                            optionGroup(title: "추천 프리셋") {
                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
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
                                optionGroup(title: "내 프리셋") {
                                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                                        ForEach(CustomPresetStore.shared.presets) { preset in
                                            selectionChip(
                                                title: preset.name,
                                                subtitle: "터미널 \(preset.draft.terminalCount) · \(preset.draft.selectedModel)",
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
                                                    Label("삭제", systemImage: "trash")
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            if !favoriteProjects.isEmpty {
                                optionGroup(title: "즐겨찾기 프로젝트") {
                                    projectSuggestionScroller(projects: favoriteProjects)
                                }
                            }

                            if !recentProjects.isEmpty {
                                optionGroup(title: "최근 프로젝트") {
                                    projectSuggestionScroller(projects: recentProjects)
                                }
                            }
                        }
                    }

                    configSection(title: "프로젝트", subtitle: "경로만 입력해도 세션을 만들 수 있습니다.") {
                        VStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 6) {
                                sectionLabel("프로젝트 경로")
                                HStack(spacing: 8) {
                                    TextField("/path/to/project", text: $projectPath)
                                        .textFieldStyle(.plain)
                                        .font(Theme.monoSmall)
                                        .appFieldStyle(emphasized: true)
                                        .accessibilityLabel("프로젝트 경로")
                                        .accessibilityHint("작업할 폴더 경로를 입력합니다")

                                    Button("Browse") {
                                        let p = NSOpenPanel(); p.canChooseFiles = false; p.canChooseDirectories = true
                                        if p.runModal() == .OK, let u = p.url {
                                            projectPath = u.path
                                            if projectName.isEmpty { projectName = u.lastPathComponent }
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    .font(Theme.mono(9, weight: .bold))
                                    .appButtonSurface(tone: .neutral, compact: true)
                                    .accessibilityLabel("프로젝트 폴더 찾기")
                                }
                                .onChange(of: projectPath) { _ in
                                    pathError = nil
                                }
                                if let error = pathError {
                                    Text(error)
                                        .font(Theme.mono(8))
                                        .foregroundColor(Theme.red)
                                }
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                sectionLabel("프로젝트 이름")
                                TextField("e.g. my-project", text: $projectName)
                                    .textFieldStyle(.plain)
                                    .font(Theme.monoSmall)
                                    .appFieldStyle()
                                    .accessibilityLabel("프로젝트 이름")
                            }
                        }
                    }

                    configSection(title: "실행 설정", subtitle: "모델, 추론 강도, 권한 모드를 같은 규칙으로 정리했습니다.") {
                        VStack(alignment: .leading, spacing: 14) {
                            optionGroup(title: "모델") {
                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                                    ForEach(ClaudeModel.allCases) { model in
                                        selectionChip(
                                            title: model.displayName,
                                            subtitle: model == .sonnet ? "기본 추천" : nil,
                                            symbol: "circle.fill",
                                            tint: modelTint(model),
                                            selected: selectedModel == model
                                        ) {
                                            selectedModel = model
                                        }
                                    }
                                }
                            }

                            optionGroup(title: "Effort") {
                                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
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

                            optionGroup(title: "권한") {
                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
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
                        }
                    }

                    configSection(title: "터미널", subtitle: "작업을 나눌 때만 여러 개를 선택하면 됩니다.") {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                sectionLabel("터미널 수")
                                Spacer()
                                Text("\(terminalCount)개")
                                    .font(Theme.mono(9, weight: .bold))
                                    .foregroundColor(Theme.accent)
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
                                    .accessibilityLabel("터미널 \(n)개")
                                    .accessibilityValue(terminalCount == n ? "선택됨" : "선택 안 됨")
                                }
                            }

                            if terminalCount > 1 {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("각 터미널에 보낼 작업")
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
                                            TextField("작업 내용 (비워두면 빈 터미널)", text: $tasks[i])
                                                .textFieldStyle(.plain)
                                                .font(Theme.mono(10))
                                                .appFieldStyle()
                                        }
                                    }
                                }
                            }
                        }
                    }

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
                                Text("고급 옵션")
                                    .font(Theme.mono(10, weight: .bold))
                                    .foregroundColor(Theme.textPrimary)
                                Text("예산, 워크트리, 도구 제한 같은 세부 옵션")
                                    .font(Theme.mono(8))
                                    .foregroundColor(Theme.textDim)
                            }
                            Spacer()
                            if hasAdvancedOptions {
                                Text("설정됨")
                                    .font(Theme.mono(8, weight: .bold))
                                    .foregroundColor(Theme.green)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Capsule().fill(Theme.green.opacity(0.10)))
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .appPanelStyle(padding: 14, radius: 14, fill: Theme.bgCard.opacity(0.96), strokeOpacity: 0.18, shadow: false)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(showAdvanced ? "고급 옵션 접기" : "고급 옵션 펼치기")

                    if showAdvanced {
                        advancedOptionsView
                    }
                }
                .padding(20)
            }

            HStack {
                Button(action: { dismiss() }) {
                    Text("Cancel")
                        .font(Theme.mono(10, weight: .bold))
                        .appButtonSurface(tone: .neutral)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape)
                .accessibilityLabel("새 세션 생성 취소")

                Button(action: { showSavePreset = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.down").font(.system(size: Theme.iconSize(9)))
                        Text("프리셋 저장")
                            .font(Theme.mono(9, weight: .bold))
                    }
                    .appButtonSurface(tone: .neutral, compact: true)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("현재 설정을 프리셋으로 저장")

                Spacer()
                Button(action: {
                    if !projectPath.isEmpty {
                        var isDir: ObjCBool = false
                        if !FileManager.default.fileExists(atPath: projectPath, isDirectory: &isDir) || !isDir.boolValue {
                            pathError = "경로가 존재하지 않거나 디렉토리가 아닙니다"
                            return
                        }
                        pathError = nil
                    }
                    if !projectPath.isEmpty && !trustConfirmed {
                        withAnimation(sheetAnimation) {
                            showTrustPrompt = true
                        }
                    } else {
                        createSessions(); dismiss()
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "play.fill").font(.system(size: Theme.iconSize(9), weight: .bold))
                        Text(terminalCount > 1 ? "Create \(terminalCount)개" : "Create")
                            .font(Theme.mono(10, weight: .bold))
                    }
                    .appButtonSurface(tone: .accent, prominent: true)
                }
                .buttonStyle(.plain).keyboardShortcut(.return)
                .disabled(projectPath.isEmpty && projectName.isEmpty)
                .accessibilityLabel(terminalCount > 1 ? "세션 \(terminalCount)개 생성" : "세션 생성")
            }.padding(.horizontal, 24).padding(.vertical, 12)
            .background(Theme.bg)
            .overlay(Rectangle().fill(Theme.border).frame(height: 1), alignment: .top)
        }
        .frame(width: max(560, 560 * AppSettings.shared.fontSizeScale), height: max(660, 660 * AppSettings.shared.fontSizeScale))
        .background(Theme.bg)
        .sheet(isPresented: $showSavePreset) {
            SavePresetSheet(draft: currentDraftSnapshot())
        }
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
                    Text("시스템 프롬프트").font(Theme.mono(9, weight: .medium)).foregroundColor(Theme.textSecondary)
                }
                TextField("추가 지시사항 (--append-system-prompt)", text: $systemPrompt, axis: .vertical)
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
                        Text("예산 한도 (USD)").font(Theme.mono(9, weight: .medium)).foregroundColor(Theme.textSecondary)
                    }
                    TextField("0 = 무제한", text: $maxBudget)
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
                            Text("이전 대화 이어하기").font(Theme.mono(9, weight: .medium)).foregroundColor(Theme.textSecondary)
                        }
                    }.toggleStyle(.switch).controlSize(.small)
                }
            }

            // 워크트리
            Toggle(isOn: $useWorktree) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.branch").font(.system(size: Theme.iconSize(9))).foregroundColor(Theme.green)
                    Text("Git 워크트리 생성").font(Theme.mono(9, weight: .medium)).foregroundColor(Theme.textSecondary)
                    Text("--worktree").font(Theme.mono(8)).foregroundColor(Theme.textDim)
                }
            }.toggleStyle(.switch).controlSize(.small)

            // 도구 제한
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "wrench.and.screwdriver.fill").font(.system(size: Theme.iconSize(9))).foregroundColor(Theme.orange)
                    Text("허용 도구").font(Theme.mono(9, weight: .medium)).foregroundColor(Theme.textSecondary)
                    Text("(쉼표 구분)").font(Theme.mono(8)).foregroundColor(Theme.textDim)
                }
                TextField("예: Bash,Read,Edit,Write", text: $allowedTools)
                    .textFieldStyle(.plain)
                    .font(Theme.mono(10))
                    .appFieldStyle()
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "xmark.shield.fill").font(.system(size: Theme.iconSize(9))).foregroundColor(Theme.red)
                    Text("차단 도구").font(Theme.mono(9, weight: .medium)).foregroundColor(Theme.textSecondary)
                    Text("(쉼표 구분)").font(Theme.mono(8)).foregroundColor(Theme.textDim)
                }
                TextField("예: Bash(rm:*)", text: $disallowedTools)
                    .textFieldStyle(.plain)
                    .font(Theme.mono(10))
                    .appFieldStyle()
            }

            // 추가 디렉토리
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "folder.badge.plus").font(.system(size: Theme.iconSize(9))).foregroundColor(Theme.accent)
                    Text("추가 디렉토리 접근").font(Theme.mono(9, weight: .medium)).foregroundColor(Theme.textSecondary)
                }
                HStack(spacing: 4) {
                    TextField("경로 추가", text: $additionalDir)
                        .textFieldStyle(.plain)
                        .font(Theme.mono(10))
                        .appFieldStyle()
                    Button(action: {
                        let p = NSOpenPanel(); p.canChooseFiles = false; p.canChooseDirectories = true
                        if p.runModal() == .OK, let u = p.url { additionalDir = u.path }
                    }) {
                        Image(systemName: "folder").font(.system(size: Theme.iconSize(10))).foregroundColor(Theme.accent)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("추가 디렉토리 선택")
                    Button(action: {
                        if !additionalDir.isEmpty {
                            additionalDirs.append(additionalDir); additionalDir = ""
                        }
                    }) {
                        Image(systemName: "plus.circle.fill").font(.system(size: Theme.iconSize(12))).foregroundColor(Theme.green)
                    }
                    .buttonStyle(.plain)
                    .disabled(additionalDir.isEmpty)
                    .accessibilityLabel("추가 디렉토리 목록에 추가")
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
        .accessibilityValue(selected ? "선택됨" : "선택 안 됨")
        .accessibilityHint("이 설정을 선택합니다")
    }

    private func modelTint(_ model: ClaudeModel) -> Color {
        switch model {
        case .opus: return Theme.purple
        case .sonnet: return Theme.accent
        case .haiku: return Theme.green
        }
    }

    private func effortTitle(_ level: EffortLevel) -> String {
        switch level {
        case .low: return "낮음"
        case .medium: return "보통"
        case .high: return "높음"
        case .max: return "최대"
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
                    .accessibilityLabel("\(project.name) 프로젝트")
                    .accessibilityValue(project.isFavorite ? "즐겨찾기" : "최근 사용")
                    .accessibilityHint("이 프로젝트 정보를 입력 칸에 채웁니다")
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

    private func createSessions() {
        let name = projectName.isEmpty ? (projectPath as NSString).lastPathComponent : projectName
        let path = projectPath.isEmpty ? NSHomeDirectory() : projectPath
        let capacity = manager.manualLaunchCapacity
        if capacity <= 0 {
            manager.notifyManualLaunchCapacity(requested: terminalCount)
            return
        }

        let launchCount = min(terminalCount, capacity)
        if launchCount < terminalCount {
            manager.notifyManualLaunchCapacity(requested: terminalCount)
        }

        preferences.rememberLaunch(
            projectName: name,
            projectPath: path,
            draft: currentDraftSnapshot()
        )

        for i in 0..<launchCount {
            let prompt = i < tasks.count ? tasks[i].trimmingCharacters(in: .whitespaces) : ""
            let tab = manager.addTab(
                projectName: name,
                projectPath: path,
                initialPrompt: prompt.isEmpty ? nil : prompt,
                manualLaunch: true,
                autoStart: false
            )
            tab.selectedModel = selectedModel
            tab.effortLevel = effortLevel
            tab.permissionMode = permissionMode
            tab.systemPrompt = systemPrompt
            tab.maxBudgetUSD = Double(maxBudget) ?? 0
            tab.allowedTools = allowedTools
            tab.disallowedTools = disallowedTools
            tab.additionalDirs = additionalDirs
            tab.continueSession = continueSession
            tab.useWorktree = useWorktree
            tab.start()
        }
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - CLITerminalView (SwiftTerm — 별도 파일 SwiftTermBridge.swift)
// ═══════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════
// MARK: - Sleep Work Setup Sheet
// ═══════════════════════════════════════════════════════

struct SleepWorkSetupSheet: View {
    @ObservedObject var tab: TerminalTab
    @Environment(\.dismiss) var envDismiss
    var onDismiss: (() -> Void)?
    @State private var task = ""
    @State private var budgetText = ""

    private func close() {
        if let onDismiss { onDismiss() } else { envDismiss() }
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "moon.zzz.fill").font(.system(size: 20)).foregroundColor(Theme.purple)
                Text("슬립워크").font(Theme.mono(14, weight: .bold)).foregroundColor(Theme.textPrimary)
                Spacer()
                Button(action: { close() }) {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 16)).foregroundColor(Theme.textDim)
                }.buttonStyle(.plain)
            }

            Text("작업을 맡기고 자리를 비워보세요. 설정한 토큰 예산 내에서 자동으로 진행합니다.")
                .font(Theme.mono(10))
                .foregroundColor(Theme.textSecondary)

            VStack(alignment: .leading, spacing: 6) {
                Text("작업 내용").font(Theme.mono(9, weight: .bold)).foregroundColor(Theme.textDim)
                TextEditor(text: $task)
                    .font(Theme.monoNormal)
                    .frame(minHeight: 80)
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Theme.bgSurface))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border, lineWidth: 1))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("토큰 예산 (예: 10k, 50k, 100k)").font(Theme.mono(9, weight: .bold)).foregroundColor(Theme.textDim)
                TextField("10k", text: $budgetText)
                    .font(Theme.monoNormal)
                    .textFieldStyle(.plain)
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Theme.bgSurface))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border, lineWidth: 1))
                Text("비워두면 무제한. 예산의 2배 초과 시 자동 중단됩니다.")
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
                        Text("슬립워크 시작").font(Theme.mono(11, weight: .bold))
                    }
                    .foregroundColor(.white)
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
