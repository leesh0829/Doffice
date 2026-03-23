import SwiftUI
import Darwin
import UserNotifications

// ═══════════════════════════════════════════════════════
// MARK: - Stream Event Architecture
// ═══════════════════════════════════════════════════════

/// 실시간 이벤트 블록 - 각 블록은 UI에서 독립적으로 렌더링됨
class StreamBlock: ObservableObject, Identifiable {
    let id = UUID()
    let timestamp = Date()
    let blockType: BlockType
    @Published var content: String = ""
    @Published var isComplete: Bool = false
    @Published var isError: Bool = false
    @Published var exitCode: Int?

    enum BlockType: Equatable {
        case sessionStart(model: String, sessionId: String)
        case thought                    // 💭 AI 사고 텍스트
        case toolUse(name: String, input: String) // ⏺ 도구 실행 (Bash, Read, Edit 등)
        case toolOutput                 // ⎿ 도구 결과 (stdout)
        case toolError                  // ✗ 도구 에러 (stderr)
        case toolEnd(success: Bool)     // 도구 완료
        case text                       // 일반 텍스트 응답
        case fileChange(path: String, action: String) // 파일 변경
        case status(message: String)    // 상태 메시지
        case completion(cost: Double?, duration: Int?) // 완료
        case error(message: String)     // 에러
        case userPrompt                 // 사용자 입력
    }

    init(type: BlockType, content: String = "") {
        self.blockType = type
        self.content = content
    }

    func append(_ text: String) {
        content += text
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - Enums
// ═══════════════════════════════════════════════════════

enum ClaudeActivity: String {
    case idle = "idle"
    case thinking = "thinking"
    case reading = "reading"
    case writing = "writing"
    case searching = "searching"
    case running = "running bash"
    case done = "done"
    case error = "error"
}

enum ClaudeModel: String, CaseIterable, Identifiable {
    case opus = "opus", sonnet = "sonnet", haiku = "haiku"
    var id: String { rawValue }
    var icon: String { switch self { case .opus: return "🟣"; case .sonnet: return "🔵"; case .haiku: return "🟢" } }
    var displayName: String { rawValue.capitalized }
}

enum EffortLevel: String, CaseIterable, Identifiable {
    case low, medium, high, max
    var id: String { rawValue }
    var icon: String { switch self { case .low: return "🐢"; case .medium: return "🚶"; case .high: return "🏃"; case .max: return "🚀" } }
}

enum OutputMode: String, CaseIterable, Identifiable {
    case full = "전체", realtime = "실시간", resultOnly = "결과만"
    var id: String { rawValue }
    var icon: String { switch self { case .full: return "📋"; case .realtime: return "⚡"; case .resultOnly: return "📌" } }
}

enum WorkerState: String {
    case idle, walking, coding, pairing, success, error
    case thinking, reading, writing, searching, running
}

// 권한 모드 (--permission-mode)
enum PermissionMode: String, CaseIterable, Identifiable {
    case bypassPermissions = "bypassPermissions"
    case auto = "auto"
    case defaultMode = "default"
    case plan = "plan"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .bypassPermissions: return "⚡"
        case .auto: return "🤖"
        case .defaultMode: return "🛡️"
        case .plan: return "📋"
        }
    }
    var displayName: String {
        switch self {
        case .bypassPermissions: return "전체 허용"
        case .auto: return "자동"
        case .defaultMode: return "기본"
        case .plan: return "계획만"
        }
    }
    var desc: String {
        switch self {
        case .bypassPermissions: return "모든 권한 자동 승인"
        case .auto: return "상황에 따라 자동 판단"
        case .defaultMode: return "위험 명령 승인 필요"
        case .plan: return "계획만 세우고 실행 안함"
        }
    }
}

// 승인 모드 (UI용 - legacy)
enum ApprovalMode: String, CaseIterable, Identifiable {
    case auto = "Auto"
    case ask = "Ask"
    case safe = "Safe"
    var id: String { rawValue }
    var icon: String { switch self { case .auto: return "⚡"; case .ask: return "🛡️"; case .safe: return "🔒" } }
    var desc: String { switch self { case .auto: return "모든 명령 자동 실행"; case .ask: return "위험 명령 승인 필요"; case .safe: return "읽기 전용" } }
}

// 로그 필터
struct BlockFilter {
    var toolTypes: Set<String> = []   // 비어있으면 전부 표시
    var onlyErrors: Bool = false
    var searchText: String = ""

    var isActive: Bool { !toolTypes.isEmpty || onlyErrors || !searchText.isEmpty }

    func matches(_ block: StreamBlock) -> Bool {
        // 에러 필터
        if onlyErrors {
            switch block.blockType {
            case .toolError, .error: break
            case .toolEnd(let success): if success { return false }
            default: return false
            }
        }
        // 도구 필터
        if !toolTypes.isEmpty {
            switch block.blockType {
            case .toolUse(let name, _): if !toolTypes.contains(name) { return false }
            case .toolOutput, .toolError, .toolEnd: break // 도구 결과는 항상 표시
            case .userPrompt, .thought, .completion, .error, .status, .sessionStart: break
            case .fileChange(_, let action):
                if !toolTypes.contains(action) && !toolTypes.contains("Write") && !toolTypes.contains("Edit") { return false }
            case .text: break
            }
        }
        // 검색 필터
        if !searchText.isEmpty {
            if !block.content.localizedCaseInsensitiveContains(searchText) { return false }
        }
        return true
    }
}

// 파일 변경 추적
struct FileChangeRecord: Identifiable {
    let id = UUID()
    let path: String
    let fileName: String
    let action: String // Write, Edit, Read
    let timestamp: Date
    var success: Bool = true
}

struct GitInfo { var branch = "", changedFiles = 0, lastCommit = "", lastCommitAge = "", isGitRepo = false }
struct SessionSummary { var filesModified: [String] = [], duration: TimeInterval = 0, tokenCount = 0, cost: Double = 0, lastLines: [String] = [], commandCount: Int = 0, errorCount: Int = 0, timestamp = Date() }

class SessionGroup: ObservableObject, Identifiable {
    let id: String; @Published var name: String; @Published var color: Color; @Published var tabIds: [String]
    init(id: String = UUID().uuidString, name: String, color: Color, tabIds: [String] = []) {
        self.id = id; self.name = name; self.color = color; self.tabIds = tabIds
    }
}

class ClaudeInstallChecker {
    static let shared = ClaudeInstallChecker()
    var isInstalled = false, version = "", path = ""
    func check() {
        if let p = TerminalTab.shellSync("which claude 2>/dev/null")?.trimmingCharacters(in: .whitespacesAndNewlines), !p.isEmpty {
            isInstalled = true; path = p
            version = TerminalTab.shellSync("claude --version 2>/dev/null")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        }
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - Token Tracker (일간/주간 토큰 추적)
// ═══════════════════════════════════════════════════════

class TokenTracker: ObservableObject {
    static let shared = TokenTracker()
    private let saveKey = "WorkManTokenHistory"

    struct DayRecord: Codable {
        var date: String // "yyyy-MM-dd"
        var inputTokens: Int
        var outputTokens: Int
        var cost: Double
        var totalTokens: Int { inputTokens + outputTokens }
    }

    @Published var history: [DayRecord] = []

    // 사용자 설정 한도
    @AppStorage("dailyTokenLimit") var dailyTokenLimit: Int = 500_000
    @AppStorage("weeklyTokenLimit") var weeklyTokenLimit: Int = 2_500_000

    private var dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    init() { load() }

    private var todayKey: String { dateFormatter.string(from: Date()) }

    // MARK: - Record

    func recordTokens(input: Int, output: Int) {
        let key = todayKey
        if let idx = history.firstIndex(where: { $0.date == key }) {
            history[idx].inputTokens += input
            history[idx].outputTokens += output
        } else {
            history.append(DayRecord(date: key, inputTokens: input, outputTokens: output, cost: 0))
        }
        save()
    }

    func recordCost(_ cost: Double) {
        let key = todayKey
        if let idx = history.firstIndex(where: { $0.date == key }) {
            history[idx].cost += cost
        } else {
            history.append(DayRecord(date: key, inputTokens: 0, outputTokens: 0, cost: cost))
        }
        save()
    }

    // MARK: - Queries

    var todayRecord: DayRecord {
        history.first(where: { $0.date == todayKey }) ?? DayRecord(date: todayKey, inputTokens: 0, outputTokens: 0, cost: 0)
    }

    var todayTokens: Int { todayRecord.totalTokens }
    var todayCost: Double { todayRecord.cost }

    var weekTokens: Int {
        let cal = Calendar.current
        let now = Date()
        let weekAgo = cal.date(byAdding: .day, value: -7, to: now)!
        return history.filter { dateFormatter.date(from: $0.date).map { $0 >= weekAgo } ?? false }.reduce(0) { $0 + $1.totalTokens }
    }

    var weekCost: Double {
        let cal = Calendar.current
        let now = Date()
        let weekAgo = cal.date(byAdding: .day, value: -7, to: now)!
        return history.filter { dateFormatter.date(from: $0.date).map { $0 >= weekAgo } ?? false }.reduce(0) { $0 + $1.cost }
    }

    var dailyRemaining: Int { max(0, dailyTokenLimit - todayTokens) }
    var weeklyRemaining: Int { max(0, weeklyTokenLimit - weekTokens) }

    var dailyUsagePercent: Double { Double(todayTokens) / Double(max(1, dailyTokenLimit)) }
    var weeklyUsagePercent: Double { Double(weekTokens) / Double(max(1, weeklyTokenLimit)) }

    // MARK: - Persistence

    private func save() {
        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: saveKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: saveKey),
              let loaded = try? JSONDecoder().decode([DayRecord].self, from: data) else { return }
        // 최근 30일만 유지
        let cal = Calendar.current
        let cutoff = cal.date(byAdding: .day, value: -30, to: Date())!
        history = loaded.filter { dateFormatter.date(from: $0.date).map { $0 >= cutoff } ?? false }
    }

    func formatTokens(_ c: Int) -> String {
        if c >= 1_000_000 { return String(format: "%.1fM", Double(c) / 1_000_000) }
        if c >= 1000 { return String(format: "%.1fk", Double(c) / 1000) }
        return "\(c)"
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - Terminal Tab (이벤트 스트림 기반)
// ═══════════════════════════════════════════════════════

class TerminalTab: ObservableObject, Identifiable {
    let id: String
    @Published var projectName: String
    @Published var projectPath: String
    @Published var workerName: String
    @Published var workerColor: Color

    // 이벤트 스트림 (핵심!)
    @Published var blocks: [StreamBlock] = []
    @Published var isProcessing: Bool = false
    @Published var isRunning: Bool = true

    // Claude 설정
    @Published var selectedModel: ClaudeModel = .sonnet
    @Published var effortLevel: EffortLevel = .medium
    @Published var outputMode: OutputMode = .full

    // 상태
    @Published var claudeActivity: ClaudeActivity = .idle
    @Published var tokensUsed: Int = 0
    @Published var inputTokensUsed: Int = 0
    @Published var outputTokensUsed: Int = 0
    @Published var totalCost: Double = 0
    @Published var tokenLimit: Int = 45000
    @Published var isClaude: Bool = true
    @Published var isCompleted: Bool = false
    @Published var gitInfo = GitInfo()
    @Published var summary: SessionSummary?
    @Published var startError: String?
    @Published var approvalMode: ApprovalMode = .auto
    @Published var fileChanges: [FileChangeRecord] = []
    @Published var commandCount: Int = 0
    @Published var errorCount: Int = 0
    @Published var pendingApproval: PendingApproval?

    struct PendingApproval: Identifiable {
        let id = UUID()
        let command: String
        let reason: String
        var onApprove: (() -> Void)?
        var onDeny: (() -> Void)?
    }

    var detectedPid: Int?
    @Published var branch: String?
    @Published var sessionCount: Int = 1
    @Published var groupId: String?
    var startTime = Date()
    @Published var lastActivityTime = Date()

    // 3분 미활동 → 휴게실
    var isOnBreak: Bool { !isProcessing && Date().timeIntervalSince(lastActivityTime) > 180 }

    // Conversation continuity
    private var sessionId: String?
    private var currentProcess: Process?
    private var activeToolBlockIndex: Int?
    private var seenToolUseIds: Set<String> = []  // 중복 방지
    @Published var scrollTrigger: Int = 0          // 스크롤 트리거

    // Legacy compat
    var outputText: String { blocks.map { $0.content }.joined(separator: "\n") }
    var masterFD: Int32 = -1

    var initialPrompt: String?
    var characterId: String?  // CharacterRegistry 연동

    // ── 고급 CLI 옵션 ──
    @Published var permissionMode: PermissionMode = .bypassPermissions
    @Published var systemPrompt: String = ""
    @Published var maxBudgetUSD: Double = 0       // 0 = 무제한
    @Published var allowedTools: String = ""       // 쉼표 구분
    @Published var disallowedTools: String = ""    // 쉼표 구분
    @Published var additionalDirs: [String] = []
    @Published var continueSession: Bool = false   // --continue
    @Published var useWorktree: Bool = false        // --worktree

    init(id: String, projectName: String, projectPath: String, workerName: String, workerColor: Color) {
        self.id = id; self.projectName = projectName; self.projectPath = projectPath
        self.workerName = workerName; self.workerColor = workerColor
    }

    var workerState: WorkerState {
        if isCompleted { return .success }
        if isProcessing {
            switch claudeActivity {
            case .thinking: return .thinking
            case .reading: return .reading
            case .writing: return .writing
            case .searching: return .searching
            case .running: return .running
            case .done: return .success
            case .error: return .error
            case .idle: return .coding
            }
        }
        return sessionCount > 1 ? .pairing : .idle
    }

    // MARK: - Start

    func start() {
        isRunning = true; isClaude = true; startTime = Date()
        let checker = ClaudeInstallChecker.shared; checker.check()
        if !checker.isInstalled {
            appendBlock(.error(message: "Claude Code 미설치"), content: "npm install -g @anthropic-ai/claude-code")
            startError = "Claude Code not installed"
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .workmanClaudeNotInstalled, object: nil)
            }
            return
        }
        appendBlock(.sessionStart(model: selectedModel.displayName, sessionId: ""),
                     content: "\(selectedModel.icon) \(selectedModel.displayName) · \(effortLevel.icon) \(effortLevel.rawValue) · v\(checker.version)")
        refreshGitInfo()

        // 초기 프롬프트가 있으면 자동 실행
        if let prompt = initialPrompt, !prompt.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.sendPrompt(prompt)
            }
        }
    }

    // MARK: - Send Prompt (stream-json 이벤트 스트림)

    func sendPrompt(_ prompt: String) {
        guard !prompt.isEmpty, !isProcessing else { return }

        appendBlock(.userPrompt, content: prompt)
        isProcessing = true
        claudeActivity = .thinking
        lastActivityTime = Date()  // 휴게실에서 복귀

        let path = FileManager.default.fileExists(atPath: projectPath) ? projectPath : NSHomeDirectory()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            var cmd = "cd \(self.shellEscape(path)) && claude -p --output-format stream-json --verbose"
            // 권한 모드
            cmd += " --permission-mode \(self.permissionMode.rawValue)"
            cmd += " --model \(self.selectedModel.rawValue)"
            cmd += " --effort \(self.effortLevel.rawValue)"
            // 세션 이어하기
            if self.continueSession && self.sessionId == nil {
                cmd += " --continue"
            } else if let sid = self.sessionId {
                cmd += " --resume \(self.shellEscape(sid))"
            }
            // 시스템 프롬프트
            if !self.systemPrompt.isEmpty {
                cmd += " --append-system-prompt \(self.shellEscape(self.systemPrompt))"
            }
            // 예산 제한
            if self.maxBudgetUSD > 0 {
                cmd += " --max-budget-usd \(String(format: "%.2f", self.maxBudgetUSD))"
            }
            // 도구 제한
            if !self.allowedTools.trimmingCharacters(in: .whitespaces).isEmpty {
                cmd += " --allowed-tools \(self.shellEscape(self.allowedTools.trimmingCharacters(in: .whitespaces)))"
            }
            if !self.disallowedTools.trimmingCharacters(in: .whitespaces).isEmpty {
                cmd += " --disallowed-tools \(self.shellEscape(self.disallowedTools.trimmingCharacters(in: .whitespaces)))"
            }
            // 추가 디렉토리
            for dir in self.additionalDirs where !dir.isEmpty {
                cmd += " --add-dir \(self.shellEscape(dir))"
            }
            // 워크트리
            if self.useWorktree { cmd += " --worktree" }
            cmd += " \(self.shellEscape(prompt))"

            let proc = Process()
            let outPipe = Pipe()
            let errPipe = Pipe()
            proc.executableURL = URL(fileURLWithPath: "/bin/zsh")
            // -l (login shell) 로 실행해야 ~/.zprofile, ~/.zshrc 의 PATH 설정이 로드됨
            proc.arguments = ["-l", "-c", cmd]
            proc.currentDirectoryURL = URL(fileURLWithPath: path)
            var env = ProcessInfo.processInfo.environment
            // GUI 앱에서 homebrew PATH가 누락될 수 있으므로 보장
            let existingPath = env["PATH"] ?? "/usr/bin:/bin"
            let extraPaths = ["/opt/homebrew/bin", "/usr/local/bin", "/opt/homebrew/sbin",
                              NSHomeDirectory() + "/.nvm/versions/node/*/bin",
                              NSHomeDirectory() + "/.local/bin",
                              "/usr/local/opt/node/bin"]
            env["PATH"] = (extraPaths + [existingPath]).joined(separator: ":")
            env["TERM"] = "dumb"; env["NO_COLOR"] = "1"
            proc.environment = env
            proc.standardOutput = outPipe
            proc.standardError = errPipe
            self.currentProcess = proc

            // stderr 캡처 (에러 진단용)
            errPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                let data = handle.availableData
                guard !data.isEmpty, let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !text.isEmpty else { return }
                DispatchQueue.main.async {
                    // JSON 스트림이 아닌 진짜 에러만 표시
                    if !text.hasPrefix("{") && !text.contains("node:") {
                        self?.appendBlock(.error(message: "stderr"), content: text)
                    }
                }
            }

            var jsonBuffer = ""

            outPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                let data = handle.availableData
                guard !data.isEmpty, let chunk = String(data: data, encoding: .utf8) else { return }
                jsonBuffer += chunk

                // 줄 단위로 JSON 파싱 → 즉시 UI 반영
                while let nl = jsonBuffer.range(of: "\n") {
                    let line = String(jsonBuffer[jsonBuffer.startIndex..<nl.lowerBound])
                    jsonBuffer = String(jsonBuffer[nl.upperBound...])
                    guard !line.trimmingCharacters(in: .whitespaces).isEmpty,
                          let ld = line.data(using: .utf8),
                          let json = try? JSONSerialization.jsonObject(with: ld) as? [String: Any] else { continue }

                    DispatchQueue.main.async { [weak self] in
                        self?.handleStreamEvent(json)
                    }
                }
            }

            do {
                try proc.run()
                proc.waitUntilExit()
            } catch {
                DispatchQueue.main.async {
                    self.appendBlock(.error(message: error.localizedDescription))
                }
            }

            outPipe.fileHandleForReading.readabilityHandler = nil
            errPipe.fileHandleForReading.readabilityHandler = nil

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.currentProcess = nil
                // result 이벤트에서 이미 isProcessing=false 했지만,
                // 프로세스가 비정상 종료한 경우만 여기서 처리
                if self.isProcessing {
                    self.isProcessing = false
                    self.claudeActivity = self.claudeActivity == .error ? .error : .done
                }
            }
        }
    }

    // MARK: - Stream Event Handler (핵심 파서)

    private func handleStreamEvent(_ json: [String: Any]) {
        let type = json["type"] as? String ?? ""

        switch type {
        case "system":
            if let sid = json["session_id"] as? String { sessionId = sid }
            if let model = json["model"] as? String {
                // 세션 시작 블록 업데이트
                if let first = blocks.first, case .sessionStart = first.blockType {
                    first.content += " · \(model)"
                }
            }

        case "assistant":
            guard let msg = json["message"] as? [String: Any],
                  let content = msg["content"] as? [[String: Any]] else { return }

            // usage가 message 안에 있을 수도, 최상위에 있을 수도 있음
            let usageObj = msg["usage"] as? [String: Any] ?? json["usage"] as? [String: Any]
            if let usage = usageObj {
                let input = usage["input_tokens"] as? Int ?? 0
                let output = usage["output_tokens"] as? Int ?? 0
                inputTokensUsed += input
                outputTokensUsed += output
                tokensUsed = inputTokensUsed + outputTokensUsed
                TokenTracker.shared.recordTokens(input: input, output: output)
            }

            for block in content {
                let blockType = block["type"] as? String ?? ""

                if blockType == "text" {
                    let text = block["text"] as? String ?? ""
                    if !text.isEmpty {
                        claudeActivity = .thinking
                        appendBlock(.thought, content: text)
                    }
                }
                else if blockType == "tool_use" {
                    // 중복 방지: tool_use ID로 이미 처리된 것은 스킵
                    let toolUseId = block["id"] as? String ?? UUID().uuidString
                    guard !seenToolUseIds.contains(toolUseId) else { continue }
                    seenToolUseIds.insert(toolUseId)

                    let toolName = block["name"] as? String ?? ""
                    let toolInput = block["input"] as? [String: Any] ?? [:]

                    switch toolName {
                    case "Bash":
                        claudeActivity = .running
                        commandCount += 1
                        let cmd = toolInput["command"] as? String ?? ""
                        let desc = toolInput["description"] as? String
                        let header = desc != nil ? "\(cmd)  // \(desc!)" : cmd
                        appendBlock(.toolUse(name: "Bash", input: cmd), content: header)
                    case "Read":
                        claudeActivity = .reading
                        let file = toolInput["file_path"] as? String ?? ""
                        appendBlock(.toolUse(name: "Read", input: file), content: (file as NSString).lastPathComponent)
                        let readCount = blocks.filter { if case .toolUse(let n, _) = $0.blockType, n == "Read" { return true }; return false }.count
                        AchievementManager.shared.recordFileRead(sessionReadCount: readCount)
                    case "Write":
                        claudeActivity = .writing
                        let file = toolInput["file_path"] as? String ?? ""
                        fileChanges.append(FileChangeRecord(path: file, fileName: (file as NSString).lastPathComponent, action: "Write", timestamp: Date()))
                        appendBlock(.fileChange(path: file, action: "Write"), content: (file as NSString).lastPathComponent)
                        AchievementManager.shared.recordFileEdit()
                    case "Edit":
                        claudeActivity = .writing
                        let file = toolInput["file_path"] as? String ?? ""
                        fileChanges.append(FileChangeRecord(path: file, fileName: (file as NSString).lastPathComponent, action: "Edit", timestamp: Date()))
                        appendBlock(.fileChange(path: file, action: "Edit"), content: (file as NSString).lastPathComponent)
                        AchievementManager.shared.recordFileEdit()
                    case "Grep":
                        claudeActivity = .searching
                        let pattern = toolInput["pattern"] as? String ?? ""
                        appendBlock(.toolUse(name: "Grep", input: pattern), content: pattern)
                    case "Glob":
                        claudeActivity = .searching
                        let pattern = toolInput["pattern"] as? String ?? ""
                        appendBlock(.toolUse(name: "Glob", input: pattern), content: pattern)
                    default:
                        appendBlock(.toolUse(name: toolName, input: ""), content: toolName)
                    }

                    activeToolBlockIndex = blocks.count - 1
                }
            }

        case "user":
            // tool_result → 도구 실행 결과
            if let result = json["tool_use_result"] as? [String: Any] {
                let stdout = result["stdout"] as? String ?? ""
                let stderr = result["stderr"] as? String ?? ""
                let interrupted = result["interrupted"] as? Bool ?? false

                if !stdout.isEmpty {
                    appendBlock(.toolOutput, content: stdout)
                }
                if !stderr.isEmpty {
                    errorCount += 1
                    appendBlock(.toolError, content: stderr)
                }
                if interrupted {
                    appendBlock(.toolEnd(success: false), content: "중단됨")
                } else {
                    let success = !(result["is_error"] as? Bool ?? false)
                    appendBlock(.toolEnd(success: success))
                }

                activeToolBlockIndex = nil
            }

        case "result":
            let cost = json["total_cost_usd"] as? Double ?? 0
            let duration = json["duration_ms"] as? Int ?? 0
            let resultText = json["result"] as? String ?? ""
            totalCost += cost
            TokenTracker.shared.recordCost(cost)

            // result 이벤트에서도 usage 파싱
            if let usage = json["usage"] as? [String: Any] {
                let input = usage["input_tokens"] as? Int ?? 0
                let output = usage["output_tokens"] as? Int ?? 0
                if input > 0 || output > 0 {
                    inputTokensUsed += input
                    outputTokensUsed += output
                    tokensUsed = inputTokensUsed + outputTokensUsed
                    TokenTracker.shared.recordTokens(input: input, output: output)
                }
            }
            // total_input_tokens / total_output_tokens (일부 Claude Code 버전)
            if let totalInput = json["total_input_tokens"] as? Int, let totalOutput = json["total_output_tokens"] as? Int {
                // 전체 값이 현재 누적보다 크면 갱신
                if totalInput > inputTokensUsed || totalOutput > outputTokensUsed {
                    let diffIn = max(0, totalInput - inputTokensUsed)
                    let diffOut = max(0, totalOutput - outputTokensUsed)
                    if diffIn > 0 || diffOut > 0 {
                        TokenTracker.shared.recordTokens(input: diffIn, output: diffOut)
                    }
                    inputTokensUsed = totalInput
                    outputTokensUsed = totalOutput
                    tokensUsed = totalInput + totalOutput
                }
            }

            if let sid = json["session_id"] as? String { sessionId = sid }

            appendBlock(.completion(cost: cost, duration: duration),
                        content: resultText.isEmpty ? "완료" : String(resultText.prefix(200)))

            // 즉시 완료 상태로 전환 (프로세스 종료 기다리지 않음)
            isProcessing = false
            claudeActivity = .done
            seenToolUseIds.removeAll()
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                if self?.claudeActivity == .done { self?.claudeActivity = .idle }
            }

            sendCompletionNotification()

        default:
            break
        }
    }

    // MARK: - Block Management

    @discardableResult
    func appendBlock(_ type: StreamBlock.BlockType, content: String = "") -> StreamBlock {
        let block = StreamBlock(type: type, content: content)
        blocks.append(block)
        scrollTrigger += 1  // 스크롤 트리거
        return block
    }

    func cancelProcessing() {
        currentProcess?.terminate(); currentProcess = nil
        isProcessing = false; claudeActivity = .idle
        appendBlock(.status(message: "취소됨"))
    }

    func clearBlocks() { blocks.removeAll() }

    // Legacy compat
    func send(_ text: String) { sendPrompt(text) }
    func sendCommand(_ command: String) { sendPrompt(command) }
    func sendKey(_ key: UInt8) { if key == 3 { cancelProcessing() } }
    func stop() { cancelProcessing(); isRunning = false }

    // MARK: - Notifications

    private func sendCompletionNotification() {
        let content = UNMutableNotificationContent()
        content.title = "✅ \(workerName) — \(projectName) 완료"

        let elapsed = Int(Date().timeIntervalSince(startTime))
        let timeStr: String
        if elapsed < 60 { timeStr = "\(elapsed)초" }
        else if elapsed < 3600 { timeStr = "\(elapsed / 60)분 \(elapsed % 60)초" }
        else { timeStr = "\(elapsed / 3600)시간 \((elapsed % 3600) / 60)분" }

        let fileCount = Set(fileChanges.map(\.fileName)).count
        var details: [String] = []
        details.append("⏱ \(timeStr)")
        if totalCost > 0 { details.append("💰 $\(String(format: "%.4f", totalCost))") }
        if tokensUsed > 0 { details.append("🔤 \(tokensUsed >= 1000 ? String(format: "%.1fk", Double(tokensUsed)/1000) : "\(tokensUsed)") tokens") }
        if fileCount > 0 { details.append("📄 \(fileCount)개 파일 수정") }
        if commandCount > 0 { details.append("⚙ \(commandCount)개 명령") }
        if errorCount > 0 { details.append("⚠ \(errorCount)개 에러") }

        content.body = details.joined(separator: " · ")
        content.sound = .default
        content.categoryIdentifier = "SESSION_COMPLETE"

        if gitInfo.isGitRepo && !gitInfo.branch.isEmpty {
            content.subtitle = "🌿 \(gitInfo.branch)"
        }

        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
        NSSound(named: "Glass")?.play()
    }

    // MARK: - Git Info

    func refreshGitInfo() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            let p = self.projectPath
            let br = Self.shellSync("git -C \"\(p)\" branch --show-current 2>/dev/null")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let ch = Self.shellSync("git -C \"\(p)\" status --porcelain 2>/dev/null")?.components(separatedBy: "\n").filter { !$0.isEmpty }.count ?? 0
            let log = Self.shellSync("git -C \"\(p)\" log -1 --format='%s|||%cr' 2>/dev/null")?.trimmingCharacters(in: .whitespacesAndNewlines)
            var msg = ""; var age = ""
            if let l = log { let pp = l.components(separatedBy: "|||"); if pp.count >= 2 { msg = pp[0]; age = pp[1] } }
            DispatchQueue.main.async {
                self.gitInfo = GitInfo(branch: br, changedFiles: ch, lastCommit: String(msg.prefix(40)), lastCommitAge: age, isGitRepo: !br.isEmpty)
                self.branch = br
            }
        }
    }

    func generateSummary() {
        let files = blocks.compactMap { b -> String? in
            if case .fileChange(let path, _) = b.blockType { return (path as NSString).lastPathComponent }
            return nil
        }
        summary = SessionSummary(filesModified: Array(Set(files)), duration: Date().timeIntervalSince(startTime),
                                 tokenCount: tokensUsed, cost: totalCost, commandCount: commandCount, errorCount: errorCount, timestamp: Date())
    }

    func exportLog() -> URL? {
        let name = "\(projectName)_\(DateFormatter.localizedString(from: startTime, dateStyle: .short, timeStyle: .short)).md"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        var s = "# \(projectName) Session\n\n"
        for b in blocks {
            switch b.blockType {
            case .userPrompt: s += "\n## ❯ \(b.content)\n\n"
            case .thought: s += "\(b.content)\n\n"
            case .toolUse(let name, _): s += "⏺ **\(name)**(`\(b.content)`)\n"
            case .toolOutput: s += "```\n\(b.content)\n```\n"
            case .toolError: s += "⚠️ ```\n\(b.content)\n```\n"
            case .completion: s += "\n---\n✅ \(b.content)\n"
            default: s += "\(b.content)\n"
            }
        }
        try? s.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func shellEscape(_ str: String) -> String { "'" + str.replacingOccurrences(of: "'", with: "'\\''") + "'" }

    static func shellSync(_ command: String) -> String? {
        let p = Process(); let pipe = Pipe()
        p.standardOutput = pipe; p.standardError = FileHandle.nullDevice
        p.executableURL = URL(fileURLWithPath: "/bin/zsh"); p.arguments = ["-c", command]
        do { try p.run(); p.waitUntilExit()
            let d = pipe.fileHandleForReading.readDataToEndOfFile()
            let o = String(data: d, encoding: .utf8); return o?.isEmpty == true ? nil : o
        } catch { return nil }
    }
}
