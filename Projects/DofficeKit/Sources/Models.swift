import SwiftUI
import Darwin
import UserNotifications
import ScreenCaptureKit
import DesignSystem

// ═══════════════════════════════════════════════════════
// MARK: - Stream Event Architecture
// ═══════════════════════════════════════════════════════

/// 실시간 이벤트 블록 - 각 블록은 UI에서 독립적으로 렌더링됨
public struct StreamBlock: Identifiable {
    public let id = UUID()
    public let timestamp = Date()
    public let blockType: BlockType
    public var content: String = ""
    public var isComplete: Bool = false
    public var isError: Bool = false
    public var exitCode: Int?

    public enum BlockType: Equatable {
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

    public init(type: BlockType, content: String = "") {
        self.blockType = type
        self.content = content
    }

    public mutating func append(_ text: String) {
        content += text
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - Enums
// ═══════════════════════════════════════════════════════

public enum ClaudeActivity: String {
    case idle = "idle"
    case thinking = "thinking"
    case reading = "reading"
    case writing = "writing"
    case searching = "searching"
    case running = "running bash"
    case done = "done"
    case error = "error"
}

public enum AgentProvider: String, CaseIterable, Identifiable {
    case claude
    case codex
    case gemini

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .claude: return "Claude"
        case .codex: return "Codex"
        case .gemini: return "Gemini"
        }
    }

    public var executableName: String {
        switch self {
        case .claude: return "claude"
        case .codex: return "codex"
        case .gemini: return "gemini"
        }
    }

    public var defaultModel: AgentModel {
        switch self {
        case .claude: return .sonnet
        case .codex: return .gpt54
        case .gemini: return .gemini25Pro
        }
    }

    public var models: [AgentModel] {
        AgentModel.allCases.filter { $0.provider == self }
    }

    public var installChecker: CLIInstallChecker {
        switch self {
        case .claude: return ClaudeInstallChecker.shared
        case .codex: return CodexInstallChecker.shared
        case .gemini: return GeminiInstallChecker.shared
        }
    }

    public var installTitle: String {
        switch self {
        case .claude: return NSLocalizedString("tab.claude.not.installed", comment: "")
        case .codex: return "Codex CLI not found"
        case .gemini: return "Gemini CLI not found"
        }
    }

    public var installDetail: String {
        switch self {
        case .claude:
            return NSLocalizedString("tab.claude.not.installed.detail", comment: "")
        case .codex:
            return "Codex CLI를 찾을 수 없습니다.\n\n설치 후 `which codex`로 경로를 확인해주세요."
        case .gemini:
            return "Gemini CLI를 찾을 수 없습니다.\n\n설치: npm install -g @anthropic-ai/gemini-cli\n설치 후 `which gemini`로 경로를 확인해주세요."
        }
    }

    public var selectionUnavailableTitle: String {
        switch self {
        case .claude:
            return "Claude CLI를 확인해주세요"
        case .codex:
            return "Codex 모델을 확인해주세요"
        case .gemini:
            return "Gemini CLI를 확인해주세요"
        }
    }

    public var selectionUnavailableDetail: String {
        switch self {
        case .claude:
            return "Claude를 선택하려면 터미널에서 `which claude`로 설치 여부를 확인해주세요."
        case .codex:
            return "Codex를 선택하려면 터미널에서 `which codex`로 설치 여부를 확인하고, 사용할 수 있는 모델이 보이는지 확인해주세요."
        case .gemini:
            return "Gemini를 선택하려면 터미널에서 `which gemini`로 설치 여부를 확인해주세요."
        }
    }

    @discardableResult
    public func refreshAvailability(force: Bool = true) -> Bool {
        installChecker.check(force: force)
        return installChecker.isInstalled
    }

    public var shellLabel: String {
        switch self {
        case .claude: return "claude"
        case .codex: return "codex"
        case .gemini: return "gemini"
        }
    }
}

public enum AgentModel: String, CaseIterable, Identifiable {
    case opus = "opus"
    case sonnet = "sonnet"
    case haiku = "haiku"
    case gpt54 = "gpt-5.4"
    case gpt54Mini = "gpt-5.4-mini"
    case gpt53Codex = "gpt-5.3-codex"
    case gpt52Codex = "gpt-5.2-codex"
    case gpt52 = "gpt-5.2"
    case gpt51CodexMax = "gpt-5.1-codex-max"
    case gpt51CodexMini = "gpt-5.1-codex-mini"
    case gemini25Pro = "gemini-2.5-pro"
    case gemini25Flash = "gemini-2.5-flash"

    public var id: String { rawValue }

    public var provider: AgentProvider {
        switch self {
        case .opus, .sonnet, .haiku:
            return .claude
        case .gpt54, .gpt54Mini, .gpt53Codex, .gpt52Codex, .gpt52, .gpt51CodexMax, .gpt51CodexMini:
            return .codex
        case .gemini25Pro, .gemini25Flash:
            return .gemini
        }
    }

    public var icon: String {
        switch self {
        case .opus: return "🟣"
        case .sonnet: return "🔵"
        case .haiku: return "🟢"
        case .gpt54: return "◉"
        case .gpt54Mini: return "◌"
        case .gpt53Codex: return "⌘"
        case .gpt52Codex: return "⌘"
        case .gpt52: return "○"
        case .gpt51CodexMax: return "◆"
        case .gpt51CodexMini: return "◇"
        case .gemini25Pro: return "💎"
        case .gemini25Flash: return "⚡"
        }
    }

    public var displayName: String {
        switch self {
        case .opus: return "Opus"
        case .sonnet: return "Sonnet"
        case .haiku: return "Haiku"
        case .gpt54: return "GPT-5.4"
        case .gpt54Mini: return "GPT-5.4-Mini"
        case .gpt53Codex: return "GPT-5.3-Codex"
        case .gpt52Codex: return "GPT-5.2-Codex"
        case .gpt52: return "GPT-5.2"
        case .gpt51CodexMax: return "GPT-5.1-Codex-Max"
        case .gpt51CodexMini: return "GPT-5.1-Codex-Mini"
        case .gemini25Pro: return "Gemini 2.5 Pro"
        case .gemini25Flash: return "Gemini 2.5 Flash"
        }
    }

    public var isRecommended: Bool {
        switch self {
        case .sonnet, .gpt54, .gemini25Pro:
            return true
        default:
            return false
        }
    }

    public static func detect(from value: String) -> AgentModel? {
        let lowered = value.lowercased()
        return allCases.first { lowered.contains($0.rawValue) }
    }
}

public typealias ClaudeModel = AgentModel

public enum EffortLevel: String, CaseIterable, Identifiable {
    case low, medium, high, max
    public var id: String { rawValue }
    public var icon: String { switch self { case .low: return "🐢"; case .medium: return "🚶"; case .high: return "🏃"; case .max: return "🚀" } }
}

public enum OutputMode: String, CaseIterable, Identifiable {
    case full = "전체", realtime = "실시간", resultOnly = "결과만"
    public var id: String { rawValue }
    public var icon: String { switch self { case .full: return "📋"; case .realtime: return "⚡"; case .resultOnly: return "📌" } }
    public var displayName: String {
        switch self {
        case .full: return NSLocalizedString("output.mode.full", comment: "")
        case .realtime: return NSLocalizedString("output.mode.realtime", comment: "")
        case .resultOnly: return NSLocalizedString("output.mode.resultOnly", comment: "")
        }
    }
}

public enum CodexSandboxMode: String, CaseIterable, Identifiable {
    case readOnly = "read-only"
    case workspaceWrite = "workspace-write"
    case dangerFullAccess = "danger-full-access"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .readOnly: return "읽기 전용"
        case .workspaceWrite: return "작업 폴더"
        case .dangerFullAccess: return "전체 허용"
        }
    }

    public var icon: String {
        switch self {
        case .readOnly: return "👀"
        case .workspaceWrite: return "🛠"
        case .dangerFullAccess: return "⚠️"
        }
    }

    public var shortLabel: String {
        switch self {
        case .readOnly: return "읽기"
        case .workspaceWrite: return "작업"
        case .dangerFullAccess: return "전체"
        }
    }
}

public enum CodexApprovalPolicy: String, CaseIterable, Identifiable {
    case untrusted
    case onRequest = "on-request"
    case never

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .untrusted: return "안전만"
        case .onRequest: return "필요 시"
        case .never: return "묻지 않음"
        }
    }

    public var icon: String {
        switch self {
        case .untrusted: return "🛡️"
        case .onRequest: return "🤝"
        case .never: return "⚡"
        }
    }

    public var shortLabel: String {
        switch self {
        case .untrusted: return "안전"
        case .onRequest: return "요청"
        case .never: return "자동"
        }
    }
}

public enum WorkerState: String {
    case idle, walking, coding, pairing, success, error
    case thinking, reading, writing, searching, running
}

// 권한 모드 (--permission-mode)
public enum PermissionMode: String, CaseIterable, Identifiable {
    case acceptEdits = "acceptEdits"
    case bypassPermissions = "bypassPermissions"
    case auto = "auto"
    case defaultMode = "default"
    case plan = "plan"
    public var id: String { rawValue }
    public var icon: String {
        switch self {
        case .acceptEdits: return "✏️"
        case .bypassPermissions: return "⚡"
        case .auto: return "🤖"
        case .defaultMode: return "🛡️"
        case .plan: return "📋"
        }
    }
    public var displayName: String {
        switch self {
        case .acceptEdits: return NSLocalizedString("perm.acceptEdits", comment: "")
        case .bypassPermissions: return NSLocalizedString("perm.bypass", comment: "")
        case .auto: return NSLocalizedString("perm.auto", comment: "")
        case .defaultMode: return NSLocalizedString("perm.default", comment: "")
        case .plan: return NSLocalizedString("perm.plan", comment: "")
        }
    }
    public var desc: String {
        switch self {
        case .acceptEdits: return NSLocalizedString("perm.acceptEdits.desc", comment: "")
        case .bypassPermissions: return NSLocalizedString("perm.bypass.desc", comment: "")
        case .auto: return NSLocalizedString("perm.auto.desc", comment: "")
        case .defaultMode: return NSLocalizedString("perm.default.desc", comment: "")
        case .plan: return NSLocalizedString("perm.plan.desc", comment: "")
        }
    }
}

// 승인 모드 (UI용 - legacy)
public enum ApprovalMode: String, CaseIterable, Identifiable {
    case auto = "Auto"
    case ask = "Ask"
    case safe = "Safe"
    public var id: String { rawValue }
    public var icon: String { switch self { case .auto: return "⚡"; case .ask: return "🛡️"; case .safe: return "🔒" } }
    public var displayName: String { switch self { case .auto: return NSLocalizedString("output.auto", comment: ""); case .ask: return NSLocalizedString("output.ask", comment: ""); case .safe: return NSLocalizedString("output.safe", comment: "") } }
    public var desc: String { switch self { case .auto: return NSLocalizedString("output.auto.desc", comment: ""); case .ask: return NSLocalizedString("output.ask.desc", comment: ""); case .safe: return NSLocalizedString("output.safe.desc", comment: "") } }
}

// 로그 필터
public struct BlockFilter {
    public var toolTypes: Set<String> = []   // 비어있으면 전부 표시
    public var onlyErrors: Bool = false
    public var searchText: String = ""

    public init(toolTypes: Set<String> = [], onlyErrors: Bool = false, searchText: String = "") {
        self.toolTypes = toolTypes; self.onlyErrors = onlyErrors; self.searchText = searchText
    }

    public var isActive: Bool { !toolTypes.isEmpty || onlyErrors || !searchText.isEmpty }

    public func matches(_ block: StreamBlock) -> Bool {
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
public struct FileChangeRecord: Identifiable {
    public let id = UUID()
    public let path: String
    public let fileName: String
    public let action: String // Write, Edit, Read
    public let timestamp: Date
    public var success: Bool = true

    public init(path: String, fileName: String, action: String, timestamp: Date, success: Bool = true) {
        self.path = path; self.fileName = fileName; self.action = action; self.timestamp = timestamp; self.success = success
    }
}

// 프롬프트 히스토리 (되돌리기 기능)
public struct PromptHistoryEntry: Identifiable {
    public let id = UUID()
    public let timestamp: Date
    public let promptText: String
    public let gitCommitHashBefore: String?
    public var fileChanges: [FileChangeRecord]
    public var isCompleted: Bool = false

    public init(timestamp: Date, promptText: String, gitCommitHashBefore: String?, fileChanges: [FileChangeRecord] = []) {
        self.timestamp = timestamp
        self.promptText = promptText
        self.gitCommitHashBefore = gitCommitHashBefore
        self.fileChanges = fileChanges
    }
}

public enum ParallelTaskState: String {
    case running
    case completed
    case failed

    public var label: String {
        switch self {
        case .running: return NSLocalizedString("task.status.running", comment: "")
        case .completed: return NSLocalizedString("task.status.completed", comment: "")
        case .failed: return NSLocalizedString("task.status.failed", comment: "")
        }
    }

    public var tint: Color {
        switch self {
        case .running: return Theme.cyan
        case .completed: return Theme.green
        case .failed: return Theme.red
        }
    }
}

public struct ParallelTaskRecord: Identifiable, Equatable {
    public let id: String
    public let label: String
    public let assigneeCharacterId: String
    public var state: ParallelTaskState

    public init(id: String, label: String, assigneeCharacterId: String, state: ParallelTaskState) {
        self.id = id; self.label = label; self.assigneeCharacterId = assigneeCharacterId; self.state = state
    }
}

public enum TabStatusCategory: String, CaseIterable {
    case active
    case processing
    case completed
    case attention
    case idle
}

public struct TabStatusPresentation {
    public let category: TabStatusCategory
    public let label: String
    public let symbol: String
    public let tint: Color
    public let sortPriority: Int

    public init(category: TabStatusCategory, label: String, symbol: String, tint: Color, sortPriority: Int) {
        self.category = category; self.label = label; self.symbol = symbol; self.tint = tint; self.sortPriority = sortPriority
    }
}

public enum WorkflowStageState: String {
    case queued
    case running
    case completed
    case failed
    case skipped

    public var label: String {
        switch self {
        case .queued: return NSLocalizedString("workflow.stage.queued", comment: "")
        case .running: return NSLocalizedString("workflow.stage.running", comment: "")
        case .completed: return NSLocalizedString("workflow.stage.completed", comment: "")
        case .failed: return NSLocalizedString("workflow.stage.failed", comment: "")
        case .skipped: return NSLocalizedString("workflow.stage.skipped", comment: "")
        }
    }

    public var tint: Color {
        switch self {
        case .queued: return Theme.textDim
        case .running: return Theme.cyan
        case .completed: return Theme.green
        case .failed: return Theme.red
        case .skipped: return Theme.textSecondary
        }
    }
}

public struct WorkflowStageRecord: Identifiable, Equatable {
    public let id: String
    public let role: WorkerJob
    public var workerName: String
    public var assigneeCharacterId: String
    public var state: WorkflowStageState
    public var handoffLabel: String
    public var detail: String
    public var updatedAt: Date

    public init(id: String, role: WorkerJob, workerName: String, assigneeCharacterId: String, state: WorkflowStageState, handoffLabel: String, detail: String, updatedAt: Date) {
        self.id = id; self.role = role; self.workerName = workerName; self.assigneeCharacterId = assigneeCharacterId; self.state = state; self.handoffLabel = handoffLabel; self.detail = detail; self.updatedAt = updatedAt
    }
}

public struct GitInfo {
    public var branch = "", changedFiles = 0, lastCommit = "", lastCommitAge = "", isGitRepo = false
    public init(branch: String = "", changedFiles: Int = 0, lastCommit: String = "", lastCommitAge: String = "", isGitRepo: Bool = false) {
        self.branch = branch; self.changedFiles = changedFiles; self.lastCommit = lastCommit; self.lastCommitAge = lastCommitAge; self.isGitRepo = isGitRepo
    }
}
public struct SessionSummary {
    public var filesModified: [String] = [], duration: TimeInterval = 0, tokenCount: Int = 0, cost: Double = 0, lastLines: [String] = [], commandCount: Int = 0, errorCount: Int = 0, timestamp: Date = Date()
    public init(filesModified: [String] = [], duration: TimeInterval = 0, tokenCount: Int = 0, cost: Double = 0, lastLines: [String] = [], commandCount: Int = 0, errorCount: Int = 0, timestamp: Date = Date()) {
        self.filesModified = filesModified; self.duration = duration; self.tokenCount = tokenCount; self.cost = cost; self.lastLines = lastLines; self.commandCount = commandCount; self.errorCount = errorCount; self.timestamp = timestamp
    }
}

public class SessionGroup: ObservableObject, Identifiable {
    public let id: String; @Published public var name: String; @Published public var color: Color; @Published public var tabIds: [String]
    public init(id: String = UUID().uuidString, name: String, color: Color, tabIds: [String] = []) {
        self.id = id; self.name = name; self.color = color; self.tabIds = tabIds
    }
}

public final class CLIInstallChecker {
    private let executableName: String
    private let knownExecutablePaths: [String]
    private let installHint: String
    private let lock = NSLock()
    private var _isInstalled = false
    private var _version = ""
    private var _path = ""
    private var _errorInfo = ""
    private var lastCheckedAt: Date?
    private let cacheTTL: TimeInterval = 10

    public init(executableName: String, knownExecutablePaths: [String], installHint: String) {
        self.executableName = executableName
        self.knownExecutablePaths = knownExecutablePaths
        self.installHint = installHint
    }

    public var isInstalled: Bool { lock.lock(); defer { lock.unlock() }; return _isInstalled }
    public var version: String { lock.lock(); defer { lock.unlock() }; return _version }
    public var path: String { lock.lock(); defer { lock.unlock() }; return _path }
    public var errorInfo: String { lock.lock(); defer { lock.unlock() }; return _errorInfo }

    public func check(force: Bool = false) {
        lock.lock()
        defer { lock.unlock() }

        if !force,
           let lastCheckedAt,
           Date().timeIntervalSince(lastCheckedAt) < cacheTTL {
            return
        }

        lastCheckedAt = Date()

        // 1) Try `which <cli>` with our enriched PATH
        if let p = TerminalTab.shellSync("which \(executableName) 2>/dev/null")?.trimmingCharacters(in: .whitespacesAndNewlines), !p.isEmpty {
            _isInstalled = true; _path = p; _errorInfo = ""
            _version = TerminalTab.shellSync("\(executableName) --version 2>/dev/null")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return
        }

        // 2) Check well-known installation paths directly
        let allPATHDirs = TerminalTab.buildFullPATH().split(separator: ":").map(String.init)
        let allCandidates = knownExecutablePaths + allPATHDirs.map { $0 + "/\(executableName)" }

        for candidate in allCandidates {
            if FileManager.default.isExecutableFile(atPath: candidate) {
                _isInstalled = true; _path = candidate; _errorInfo = ""
                _version = TerminalTab.shellSync("\"\(candidate)\" --version 2>/dev/null")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return
            }
        }

        // 3) Fallback: try login shell with timeout (prevents hang)
        if let p = TerminalTab.shellSyncLoginWithTimeout("which \(executableName) 2>/dev/null", timeout: 3)?.trimmingCharacters(in: .whitespacesAndNewlines), !p.isEmpty {
            _isInstalled = true; _path = p; _errorInfo = ""
            _version = TerminalTab.shellSyncLoginWithTimeout("\"\(p)\" --version 2>/dev/null", timeout: 3)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return
        }

        // Not found
        _isInstalled = false
        _version = ""
        _path = ""
        _errorInfo = installHint
    }
}

public enum ClaudeInstallChecker {
    public static let shared = CLIInstallChecker(
        executableName: "claude",
        knownExecutablePaths: [
            "/usr/local/bin/claude",
            "/opt/homebrew/bin/claude",
            NSHomeDirectory() + "/.npm-global/bin/claude",
        ],
        installHint: "Claude CLI not found. Install with: npm install -g @anthropic-ai/claude-code"
    )
}

public enum CodexInstallChecker {
    public static let shared = CLIInstallChecker(
        executableName: "codex",
        knownExecutablePaths: [
            "/Applications/Codex.app/Contents/Resources/codex",
            "/usr/local/bin/codex",
            "/opt/homebrew/bin/codex",
            NSHomeDirectory() + "/.npm-global/bin/codex",
        ],
        installHint: "Codex CLI not found. Install Codex Desktop or add the codex binary to PATH."
    )
}

public enum GeminiInstallChecker {
    public static let shared = CLIInstallChecker(
        executableName: "gemini",
        knownExecutablePaths: [
            "/usr/local/bin/gemini",
            "/opt/homebrew/bin/gemini",
            NSHomeDirectory() + "/.npm-global/bin/gemini",
            NSHomeDirectory() + "/.local/bin/gemini",
        ],
        installHint: "Gemini CLI not found. Install with: npm install -g @anthropic-ai/gemini-cli"
    )
}

// ═══════════════════════════════════════════════════════
// MARK: - Token Tracker (일간/주간 토큰 추적)
// ═══════════════════════════════════════════════════════

public class TokenTracker: ObservableObject {
    public static let shared = TokenTracker()
    public static let recommendedDailyLimit = 500_000
    public static let recommendedWeeklyLimit = 2_500_000
    private let saveKey = "DofficeTokenHistory"
    private let automationDailyReserve = 100_000
    private let automationWeeklyReserve = 300_000
    private let globalDailyReserve = 12_000
    private let globalWeeklyReserve = 40_000
    private let emergencyDailyReserve = 6_000
    private let emergencyWeeklyReserve = 20_000
    private let persistenceQueue = DispatchQueue(label: "doffice.token-tracker", qos: .utility)
    private var saveWorkItem: DispatchWorkItem?

    public struct DayRecord: Codable {
        public var date: String // "yyyy-MM-dd"
        public var inputTokens: Int
        public var outputTokens: Int
        public var cost: Double
        public var totalTokens: Int { inputTokens + outputTokens }
    }

    @Published public var history: [DayRecord] = []

    private var cachedWeekTokens: Int = 0
    private var cachedWeekCost: Double = 0
    private var cachedBillingTokens: Int = 0
    private var cachedBillingCost: Double = 0
    private var cacheTimestamp: Date = .distantPast

    // 사용자 설정 한도
    @AppStorage("dailyTokenLimit") public var dailyTokenLimit: Int = TokenTracker.recommendedDailyLimit
    @AppStorage("weeklyTokenLimit") public var weeklyTokenLimit: Int = TokenTracker.recommendedWeeklyLimit

    private var dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    public init() { load() }

    private var todayKey: String { dateFormatter.string(from: Date()) }

    // MARK: - Record

    public func recordTokens(input: Int, output: Int) {
        guard input > 0 || output > 0 else { return }
        cacheTimestamp = .distantPast
        let key = todayKey
        if let idx = history.firstIndex(where: { $0.date == key }) {
            history[idx].inputTokens += input
            history[idx].outputTokens += output
        } else {
            history.append(DayRecord(date: key, inputTokens: input, outputTokens: output, cost: 0))
        }
        scheduleSave()
        #if DEBUG
        print("[TokenTracker] +\(input)in +\(output)out → today: \(todayTokens), week: \(weekTokens)")
        #endif
    }

    public func recordCost(_ cost: Double) {
        guard cost > 0 else { return }
        cacheTimestamp = .distantPast
        let key = todayKey
        if let idx = history.firstIndex(where: { $0.date == key }) {
            history[idx].cost += cost
        } else {
            history.append(DayRecord(date: key, inputTokens: 0, outputTokens: 0, cost: cost))
        }
        scheduleSave()
        #if DEBUG
        print("[TokenTracker] cost +$\(String(format: "%.4f", cost)) → today: $\(String(format: "%.4f", todayCost))")
        #endif
    }

    // MARK: - Queries

    public var todayRecord: DayRecord {
        history.first(where: { $0.date == todayKey }) ?? DayRecord(date: todayKey, inputTokens: 0, outputTokens: 0, cost: 0)
    }

    public var todayTokens: Int { todayRecord.totalTokens }
    public var todayCost: Double { todayRecord.cost }

    public var weekTokens: Int {
        refreshCacheIfNeeded()
        return cachedWeekTokens
    }

    public var weekCost: Double {
        refreshCacheIfNeeded()
        return cachedWeekCost
    }

    // ── 결제 기간 (Billing Period) 사용량 ──

    /// 결제일 기준 이번 달 시작일
    public var billingPeriodStart: Date {
        let billingDay = max(1, AppSettings.shared.billingDay)
        let cal = Calendar.current
        let now = Date()
        let todayDay = cal.component(.day, from: now)
        let year = cal.component(.year, from: now)
        let month = cal.component(.month, from: now)

        if billingDay <= 0 {
            // 미설정이면 이번 달 1일부터
            return cal.date(from: DateComponents(year: year, month: month, day: 1)) ?? now
        }
        if todayDay >= billingDay {
            // 이번 달 결제일 이후
            return cal.date(from: DateComponents(year: year, month: month, day: billingDay)) ?? now
        } else {
            // 아직 결제일 전 → 지난달 결제일부터
            guard let lastMonth = cal.date(byAdding: .month, value: -1, to: now) else { return now }
            let lmYear = cal.component(.year, from: lastMonth)
            let lmMonth = cal.component(.month, from: lastMonth)
            guard let dayRange = cal.range(of: .day, in: .month, for: lastMonth) else { return now }
            let maxDay = dayRange.upperBound - 1
            return cal.date(from: DateComponents(year: lmYear, month: lmMonth, day: min(billingDay, maxDay))) ?? now
        }
    }

    public var billingPeriodTokens: Int {
        refreshCacheIfNeeded()
        return cachedBillingTokens
    }

    public var billingPeriodCost: Double {
        refreshCacheIfNeeded()
        return cachedBillingCost
    }

    private func refreshCacheIfNeeded() {
        let now = Date()
        guard now.timeIntervalSince(cacheTimestamp) > 30 else { return }
        cacheTimestamp = now

        let cal = Calendar.current
        let weekAgo = cal.date(byAdding: .day, value: -7, to: now) ?? now
        let weekRecords = history.filter { dateFormatter.date(from: $0.date).map { $0 >= weekAgo } ?? false }
        cachedWeekTokens = weekRecords.reduce(0) { $0 + $1.totalTokens }
        cachedWeekCost = weekRecords.reduce(0) { $0 + $1.cost }

        let bStart = billingPeriodStart
        let billingRecords = history.filter { dateFormatter.date(from: $0.date).map { $0 >= bStart } ?? false }
        cachedBillingTokens = billingRecords.reduce(0) { $0 + $1.totalTokens }
        cachedBillingCost = billingRecords.reduce(0) { $0 + $1.cost }
    }

    public var billingPeriodDays: Int {
        let cal = Calendar.current
        return cal.dateComponents([.day], from: billingPeriodStart, to: Date()).day ?? 0
    }

    public var billingPeriodLabel: String {
        let df = DateFormatter()
        df.dateFormat = "M/d"
        let start = df.string(from: billingPeriodStart)
        let billingDay = max(1, AppSettings.shared.billingDay)
        let cal = Calendar.current
        let nextBilling = cal.date(byAdding: .month, value: 1, to: billingPeriodStart)
            ?? cal.date(byAdding: .day, value: 30, to: billingPeriodStart)
            ?? Date()
        let end = df.string(from: cal.date(byAdding: .day, value: -1, to: nextBilling) ?? nextBilling)
        return "\(start) ~ \(end)"
    }

    public var totalAllTimeTokens: Int {
        history.reduce(0) { $0 + $1.totalTokens }
    }

    public var totalAllTimeCost: Double {
        history.reduce(0) { $0 + $1.cost }
    }

    private var safeDailyLimit: Int { max(1, dailyTokenLimit) }
    private var safeWeeklyLimit: Int { max(1, weeklyTokenLimit) }

    private func cappedReserve(_ configured: Int, limit: Int, maxRatio: Double) -> Int {
        let ratioCap = max(1, Int(Double(max(1, limit)) * maxRatio))
        return min(configured, ratioCap)
    }

    private var effectiveGlobalDailyReserve: Int {
        cappedReserve(globalDailyReserve, limit: safeDailyLimit, maxRatio: 0.05)
    }

    private var effectiveGlobalWeeklyReserve: Int {
        cappedReserve(globalWeeklyReserve, limit: safeWeeklyLimit, maxRatio: 0.05)
    }

    private var effectiveAutomationDailyReserve: Int {
        cappedReserve(automationDailyReserve, limit: safeDailyLimit, maxRatio: 0.18)
    }

    private var effectiveAutomationWeeklyReserve: Int {
        cappedReserve(automationWeeklyReserve, limit: safeWeeklyLimit, maxRatio: 0.18)
    }

    private var effectiveEmergencyDailyReserve: Int {
        cappedReserve(emergencyDailyReserve, limit: safeDailyLimit, maxRatio: 0.03)
    }

    private var effectiveEmergencyWeeklyReserve: Int {
        cappedReserve(emergencyWeeklyReserve, limit: safeWeeklyLimit, maxRatio: 0.03)
    }

    public var dailyRemaining: Int { max(0, safeDailyLimit - todayTokens) }
    public var weeklyRemaining: Int { max(0, safeWeeklyLimit - weekTokens) }

    public var dailyUsagePercent: Double { Double(todayTokens) / Double(safeDailyLimit) }
    public var weeklyUsagePercent: Double { Double(weekTokens) / Double(safeWeeklyLimit) }

    private func protectionUsageSummary() -> String {
        String(format: NSLocalizedString("token.protection.summary", comment: ""), formatTokens(todayTokens), formatTokens(safeDailyLimit), formatTokens(weekTokens), formatTokens(safeWeeklyLimit))
    }

    public func startBlockReason(isAutomation: Bool) -> String? {
        if dailyRemaining <= effectiveGlobalDailyReserve ||
            weeklyRemaining <= effectiveGlobalWeeklyReserve ||
            dailyUsagePercent >= 0.985 ||
            weeklyUsagePercent >= 0.985 {
            return String(format: NSLocalizedString("token.protection.global.block", comment: ""), protectionUsageSummary())
        }

        if isAutomation &&
            (dailyRemaining <= effectiveAutomationDailyReserve ||
             weeklyRemaining <= effectiveAutomationWeeklyReserve ||
             dailyUsagePercent >= 0.82 ||
             weeklyUsagePercent >= 0.82) {
            return String(format: NSLocalizedString("token.protection.sub.block", comment: ""), protectionUsageSummary())
        }

        return nil
    }

    public func runningStopReason(isAutomation: Bool, currentTabTokens: Int, tokenLimit: Int) -> String? {
        if currentTabTokens >= tokenLimit {
            return NSLocalizedString("token.protection.session.limit", comment: "")
        }

        if dailyRemaining <= effectiveEmergencyDailyReserve ||
            weeklyRemaining <= effectiveEmergencyWeeklyReserve {
            return String(format: NSLocalizedString("token.protection.global.stop", comment: ""), protectionUsageSummary())
        }

        if isAutomation &&
            (dailyRemaining <= effectiveGlobalDailyReserve ||
             weeklyRemaining <= effectiveGlobalWeeklyReserve ||
             dailyUsagePercent >= 0.94 ||
             weeklyUsagePercent >= 0.94) {
            return String(format: NSLocalizedString("token.protection.sub.stop", comment: ""), protectionUsageSummary())
        }

        // 비용 제한 체크
        let settings = AppSettings.shared
        if settings.dailyCostLimit > 0 && todayCost >= settings.dailyCostLimit {
            return String(format: NSLocalizedString("token.protection.daily.cost", comment: ""), String(format: "%.2f", settings.dailyCostLimit), String(format: "%.2f", todayCost))
        }

        return nil
    }

    public func costWarningNeeded(tabCost: Double) -> String? {
        let settings = AppSettings.shared
        guard settings.costWarningAt80 else { return nil }
        if settings.perSessionCostLimit > 0 && tabCost >= settings.perSessionCostLimit * 0.8 {
            return String(format: NSLocalizedString("token.protection.session.cost.warn", comment: ""), String(format: "%.2f", tabCost), String(format: "%.2f", settings.perSessionCostLimit))
        }
        if settings.dailyCostLimit > 0 && todayCost >= settings.dailyCostLimit * 0.8 {
            return String(format: NSLocalizedString("token.protection.daily.cost.warn", comment: ""), String(format: "%.2f", todayCost), String(format: "%.2f", settings.dailyCostLimit))
        }
        return nil
    }

    // MARK: - Persistence

    /// 30일 이상 된 기록을 런타임에서도 주기적으로 제거
    private func pruneHistoryIfNeeded() {
        guard history.count > 35 else { return } // 30일 + 여유
        let cal = Calendar.current
        let cutoff = cal.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        history = history.filter { dateFormatter.date(from: $0.date).map { $0 >= cutoff } ?? false }
    }

    private func scheduleSave(delay: TimeInterval = 0.75) {
        pruneHistoryIfNeeded()
        saveWorkItem?.cancel()
        let snapshot = history
        let key = saveKey
        let workItem = DispatchWorkItem {
            if let data = try? JSONEncoder().encode(snapshot) {
                UserDefaults.standard.set(data, forKey: key)
            }
        }
        saveWorkItem = workItem
        persistenceQueue.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: saveKey),
              let loaded = try? JSONDecoder().decode([DayRecord].self, from: data) else { return }
        // 최근 30일만 유지
        let cal = Calendar.current
        let cutoff = cal.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        history = loaded.filter { dateFormatter.date(from: $0.date).map { $0 >= cutoff } ?? false }
    }

    public func clearOldEntries() {
        let key = todayKey
        history = history.filter { $0.date == key }
        scheduleSave(delay: 0)
    }

    public func clearAllEntries() {
        history.removeAll()
        saveWorkItem?.cancel()
        UserDefaults.standard.removeObject(forKey: saveKey)
    }

    public func applyRecommendedMinimumLimits() {
        if dailyTokenLimit < Self.recommendedDailyLimit {
            dailyTokenLimit = Self.recommendedDailyLimit
        }
        if weeklyTokenLimit < Self.recommendedWeeklyLimit {
            weeklyTokenLimit = Self.recommendedWeeklyLimit
        }
    }

    /// Returns records for the last 7 days (oldest first), filling missing days with zero records.
    public var last7DaysRecords: [DayRecord] {
        let cal = Calendar.current
        let now = Date()
        var result: [DayRecord] = []
        for offset in (0..<7).reversed() {
            guard let day = cal.date(byAdding: .day, value: -offset, to: now) else { continue }
            let key = dateFormatter.string(from: day)
            if let record = history.first(where: { $0.date == key }) {
                result.append(record)
            } else {
                result.append(DayRecord(date: key, inputTokens: 0, outputTokens: 0, cost: 0))
            }
        }
        return result
    }

    /// Short weekday label for a date string
    public func weekdayLabel(for dateString: String) -> String {
        guard let date = dateFormatter.date(from: dateString) else { return "?" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "E"
        return f.string(from: date)
    }

    /// Average daily tokens over last 7 days
    public var averageDailyTokens: Int {
        let records = last7DaysRecords
        let total = records.reduce(0) { $0 + $1.totalTokens }
        return total / max(1, records.count)
    }

    /// Average daily cost over last 7 days
    public var averageDailyCost: Double {
        let records = last7DaysRecords
        let total = records.reduce(0.0) { $0 + $1.cost }
        return total / Double(max(1, records.count))
    }

    public func formatTokens(_ c: Int) -> String {
        if c >= 1_000_000 { return String(format: "%.1fM", Double(c) / 1_000_000) }
        if c >= 1000 { return String(format: "%.1fk", Double(c) / 1000) }
        return "\(c)"
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - Terminal Tab (이벤트 스트림 기반)
// ═══════════════════════════════════════════════════════

public class TerminalTab: ObservableObject, Identifiable {
    private static let maxRetainedBlocks = 420
    private static let maxRetainedFileChanges = 240

    /// Decoupled character lookup (set by App layer to bridge CharacterRegistry)
    public static var characterLookup: ((String) -> WorkerCharacter?) = { _ in nil }
    /// Decoupled hired-characters provider (set by App layer to bridge CharacterRegistry)
    public static var hiredCharactersProvider: (() -> [WorkerCharacter]) = { [] }

    private struct ToolUseContext {
        let id: String
        let name: String
        let input: [String: Any]
        let preview: String
    }

    private struct PermissionDenialCandidate {
        let toolUseId: String?
        let toolName: String
        let toolInput: [String: Any]
        let message: String
    }

    public let id: String
    public var projectName: String
    public var projectPath: String
    @Published public var workerName: String
    @Published public var workerColor: Color

    // 이벤트 스트림 (핵심!)
    @Published public var blocks: [StreamBlock] = []
    @Published public var isProcessing: Bool = false
    @Published public var isRunning: Bool = true

    // 모델/CLI 설정
    public var selectedModel: ClaudeModel = .sonnet
    public var effortLevel: EffortLevel = .medium
    public var outputMode: OutputMode = .full
    public var codexSandboxMode: CodexSandboxMode = .workspaceWrite
    public var codexApprovalPolicy: CodexApprovalPolicy = .onRequest

    // 상태
    @Published public var claudeActivity: ClaudeActivity = .idle
    @Published public var tokensUsed: Int = 0
    public var inputTokensUsed: Int = 0
    public var outputTokensUsed: Int = 0
    public var totalCost: Double = 0
    @Published public var tokenLimit: Int = 45000
    @Published public var isClaude: Bool = true
    @Published public var isCompleted: Bool = false
    @Published public var gitInfo = GitInfo()
    @Published public var summary: SessionSummary?
    @Published public var startError: String?
    @Published public var approvalMode: ApprovalMode = .auto
    public var fileChanges: [FileChangeRecord] = []
    public var commandCount: Int = 0
    public var errorCount: Int = 0
    public var readCommandCount: Int = 0
    @Published public var pendingApproval: PendingApproval?
    @Published public var lastResultText: String = ""

    // 보안 경고
    @Published public var dangerousCommandWarning: String?
    @Published public var sensitiveFileWarning: String?

    // 슬립워크
    @Published public var sleepWorkTask: String?
    @Published public var sleepWorkTokenBudget: Int?
    @Published public var sleepWorkStartTokens: Int = 0
    @Published public var sleepWorkCompleted: Bool = false
    @Published public var sleepWorkExceeded: Bool = false  // 2x budget exceeded
    @Published public var lastPromptText: String = ""
    @Published public var attachedImages: [URL] = []  // 첨부된 이미지 경로들
    @Published public var completedPromptCount: Int = 0
    @Published public var parallelTasks: [ParallelTaskRecord] = []
    public var promptHistory: [PromptHistoryEntry] = []
    private var pendingHistoryPreHash: String?
    private var pendingHistoryFileChangeStartIndex: Int = 0

    // 세션 타임라인
    public struct TimelineEvent: Identifiable {
        public let id = UUID()
        public let timestamp: Date
        public let type: TimelineEventType
        public let detail: String
    }

    public enum TimelineEventType: String {
        case started, prompt, toolUse, fileChange, error, completed

        public var displayName: String {
            switch self {
            case .started: return NSLocalizedString("timeline.event.started", comment: "")
            case .prompt: return NSLocalizedString("timeline.event.prompt", comment: "")
            case .toolUse: return NSLocalizedString("timeline.event.toolUse", comment: "")
            case .fileChange: return NSLocalizedString("timeline.event.fileChange", comment: "")
            case .error: return NSLocalizedString("timeline.event.error", comment: "")
            case .completed: return NSLocalizedString("timeline.event.completed", comment: "")
            }
        }
    }

    public var timeline: [TimelineEvent] = []

    public struct PendingApproval: Identifiable {
        public let id = UUID()
        public let command: String
        public let reason: String
        public var onApprove: (() -> Void)?
        public var onDeny: (() -> Void)?
    }

    public var detectedPid: Int?
    @Published public var branch: String?
    @Published public var sessionCount: Int = 1
    @Published public var groupId: String?
    public var startTime = Date()
    @Published public var lastActivityTime = Date()

    // 3분 미활동 → 휴게실
    public var isOnBreak: Bool { !isProcessing && Date().timeIntervalSince(lastActivityTime) > 180 }

    // Conversation continuity
    private var sessionId: String?
    private var currentProcess: Process?
    private var currentOutPipe: Pipe?
    private var currentErrPipe: Pipe?
    private var cancelledProcessIds: Set<ObjectIdentifier> = []
    private var activeToolBlockIndex: Int?
    private var seenToolUseIds: Set<String> = []  // 중복 방지
    private var toolUseContexts: [String: ToolUseContext] = [:]
    private var pendingPermissionDenial: PermissionDenialCandidate?
    private var lastPermissionFingerprint: String?
    @Published public var scrollTrigger: Int = 0          // 스크롤 트리거
    private var budgetStopIssued = false

    // Legacy compat
    public var outputText: String { blocks.map { $0.content }.joined(separator: "\n") }
    public var masterFD: Int32 = -1

    // ── Raw Terminal Mode (PTY) ──
    @Published public var rawOutput: String = ""
    @Published public var rawScrollTrigger: Int = 0
    @Published public var isRawMode: Bool = false
    private var rawMasterFD: Int32 = -1
    public let vt100 = VT100Terminal(rows: 50, cols: 120)

    public var initialPrompt: String?
    public var characterId: String?  // CharacterRegistry 연동
    public var automationSourceTabId: String?
    public var automationReportPath: String?
    public var manualLaunch: Bool = false
    public var workflowSourceRequest: String = ""
    public var workflowPlanSummary: String = ""
    public var workflowDesignSummary: String = ""
    public var workflowReviewSummary: String = ""
    public var workflowQASummary: String = ""
    public var workflowSRESummary: String = ""
    public var officeSeatLockReason: String?
    public var workflowStages: [WorkflowStageRecord] = []
    public var reviewerAttemptCount: Int = 0
    public var qaAttemptCount: Int = 0
    public var automatedRevisionCount: Int = 0

    // ── 고급 CLI 옵션 ──
    public var permissionMode: PermissionMode = .bypassPermissions
    public var systemPrompt: String = ""
    public var maxBudgetUSD: Double = 0       // 0 = 무제한
    public var allowedTools: String = ""       // 쉼표 구분
    public var disallowedTools: String = ""    // 쉼표 구분
    public var additionalDirs: [String] = []
    public var continueSession: Bool = false   // --continue
    public var useWorktree: Bool = false        // --worktree

    // ── 추가 CLI 옵션 (v1.5) ──
    public var fallbackModel: String = ""          // --fallback-model
    public var sessionName: String = ""            // --name
    public var jsonSchema: String = ""             // --json-schema
    public var mcpConfigPaths: [String] = []       // --mcp-config
    public var customAgent: String = ""            // --agent
    public var customAgentsJSON: String = ""       // --agents (JSON)
    public var pluginDirs: [String] = []           // --plugin-dir
    public var customTools: String = ""            // --tools (빌트인 도구 제한)
    public var enableChrome: Bool = true           // --chrome
    public var forkSession: Bool = false           // --fork-session
    public var fromPR: String = ""                 // --from-pr
    public var enableBrief: Bool = false           // --brief
    public var tmuxMode: Bool = false              // --tmux
    public var strictMcpConfig: Bool = false       // --strict-mcp-config
    public var settingSources: String = ""         // --setting-sources
    public var settingsFileOrJSON: String = ""     // --settings
    public var betaHeaders: String = ""            // --betas

    // ── 세션 연속성 (--resume으로 멀티턴 유지) ──

    // ── 크롬 윈도우 캡처 ──
    public var chromeScreenshot: CGImage?

    public init(id: String = UUID().uuidString, projectName: String, projectPath: String, workerName: String, workerColor: Color) {
        self.id = id; self.projectName = projectName; self.projectPath = projectPath
        self.workerName = workerName; self.workerColor = workerColor
    }

    deinit {
        currentProcess?.terminate()
        currentProcess = nil
        chromeScreenshot = nil
        if rawMasterFD >= 0 {
            close(rawMasterFD)
            rawMasterFD = -1
        }
    }

    public var provider: AgentProvider { selectedModel.provider }

    private func sessionStartSummary(modelLabel: String? = nil) -> String {
        let resolvedModel = modelLabel.flatMap { ClaudeModel.detect(from: $0) } ?? selectedModel
        let resolvedLabel = modelLabel ?? resolvedModel.displayName
        let version = resolvedModel.provider.installChecker.version
        switch resolvedModel.provider {
        case .claude:
            return "\(resolvedModel.icon) \(resolvedLabel) · \(effortLevel.icon) \(effortLevel.rawValue) · v\(version)"
        case .codex:
            return "\(resolvedModel.icon) \(resolvedLabel) · \(codexSandboxMode.icon) \(codexSandboxMode.shortLabel) · \(codexApprovalPolicy.icon) \(codexApprovalPolicy.shortLabel) · v\(version)"
        case .gemini:
            return "\(resolvedModel.icon) \(resolvedLabel) · v\(version)"
        }
    }

    private func sanitizeTerminalText(_ text: String) -> String {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let ansiPattern = "\u{001B}\\[[0-9;?]*[ -/]*[@-~]"
        return normalized
            .replacingOccurrences(of: ansiPattern, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func updateReportedModel(_ reportedModel: String) {
        if let resolvedModel = ClaudeModel.detect(from: reportedModel) {
            selectedModel = resolvedModel
        }
        if !blocks.isEmpty, case .sessionStart = blocks[0].blockType {
            let displayLabel = ClaudeModel.detect(from: reportedModel)?.displayName ?? reportedModel
            blocks[0].content = sessionStartSummary(modelLabel: displayLabel)
        }
    }

    public var persistedSessionId: String? { sessionId }

    public func applySavedSessionConfiguration(_ saved: SavedSession) {
        if let raw = saved.selectedModel, let model = ClaudeModel(rawValue: raw) {
            selectedModel = model
        }
        if let raw = saved.effortLevel, let level = EffortLevel(rawValue: raw) {
            effortLevel = level
        }
        if let raw = saved.outputMode, let mode = OutputMode(rawValue: raw) {
            outputMode = mode
        }
        if let raw = saved.permissionMode, let mode = PermissionMode(rawValue: raw) {
            permissionMode = mode
        }
        if let raw = saved.codexSandboxMode, let mode = CodexSandboxMode(rawValue: raw) {
            codexSandboxMode = mode
        }
        if let raw = saved.codexApprovalPolicy, let mode = CodexApprovalPolicy(rawValue: raw) {
            codexApprovalPolicy = mode
        }

        tokenLimit = saved.tokenLimit ?? tokenLimit
        systemPrompt = saved.systemPrompt ?? ""
        maxBudgetUSD = saved.maxBudgetUSD ?? 0
        allowedTools = saved.allowedTools ?? ""
        disallowedTools = saved.disallowedTools ?? ""
        additionalDirs = saved.additionalDirs ?? []
        continueSession = saved.continueSession ?? false
        useWorktree = saved.useWorktree ?? false
        fallbackModel = saved.fallbackModel ?? ""
        sessionName = saved.sessionName ?? ""
        jsonSchema = saved.jsonSchema ?? ""
        mcpConfigPaths = saved.mcpConfigPaths ?? []
        customAgent = saved.customAgent ?? ""
        customAgentsJSON = saved.customAgentsJSON ?? ""
        pluginDirs = saved.pluginDirs ?? []
        customTools = saved.customTools ?? ""
        enableChrome = saved.enableChrome ?? true
        forkSession = saved.forkSession ?? false
        fromPR = saved.fromPR ?? ""
        enableBrief = saved.enableBrief ?? false
        tmuxMode = saved.tmuxMode ?? false
        strictMcpConfig = saved.strictMcpConfig ?? false
        settingSources = saved.settingSources ?? ""
        settingsFileOrJSON = saved.settingsFileOrJSON ?? ""
        betaHeaders = saved.betaHeaders ?? ""

        branch = saved.branch
        if let savedCharacterId = saved.characterId,
           let savedCharacter = Self.characterLookup(savedCharacterId),
           savedCharacter.isHired,
           !savedCharacter.isOnVacation {
            characterId = savedCharacterId
        }
        if let savedSessionId = saved.sessionId, !savedSessionId.isEmpty {
            sessionId = savedSessionId
        }
    }

    public func restoreSavedSessionSnapshot(_ saved: SavedSession) {
        tokensUsed = saved.tokensUsed
        inputTokensUsed = saved.inputTokensUsed ?? 0
        if let savedOutputTokens = saved.outputTokensUsed {
            outputTokensUsed = savedOutputTokens
        } else {
            outputTokensUsed = max(0, saved.tokensUsed - inputTokensUsed)
        }
        totalCost = saved.totalCost ?? 0
        commandCount = saved.commandCount ?? commandCount
        errorCount = saved.errorCount ?? errorCount
        completedPromptCount = saved.completedPromptCount ?? completedPromptCount
        lastResultText = saved.lastResultText ?? ""
        lastPromptText = saved.lastPrompt ?? ""
        fileChanges = saved.fileChanges?.map(\.fileChangeRecord) ?? []
        startTime = saved.startTime
        lastActivityTime = saved.lastActivityTime ?? saved.startTime
        initialPrompt = nil
        isCompleted = false
        isClaude = selectedModel.provider == .claude
        isRunning = true
        startError = nil

        if let summaryFiles = saved.summaryFiles {
            summary = SessionSummary(
                filesModified: summaryFiles,
                duration: saved.summaryDuration ?? 0,
                tokenCount: saved.summaryTokens ?? saved.tokensUsed,
                cost: saved.totalCost ?? 0,
                lastLines: [],
                commandCount: saved.commandCount ?? 0,
                errorCount: saved.errorCount ?? 0,
                timestamp: saved.lastActivityTime ?? saved.startTime
            )
        }

        // 대화 내역 복원 (최근 100개 블록)
        if let chatHistory = saved.chatHistory, !chatHistory.isEmpty {
            let restoredBlocks = chatHistory.map { $0.toBlock() }
            blocks.append(contentsOf: restoredBlocks)
        }
    }

    public func appendRestorationNotice(from saved: SavedSession, recoveryBundleURL: URL?) {
        var details: [String] = [NSLocalizedString("tab.restore.not.rerun", comment: "")]

        if let lastPrompt = saved.lastPrompt, !lastPrompt.isEmpty {
            details.append(String(format: NSLocalizedString("tab.restore.last.input", comment: ""), String(lastPrompt.prefix(180))))
        } else if let initialPrompt = saved.initialPrompt, !initialPrompt.isEmpty {
            details.append(String(format: NSLocalizedString("tab.restore.initial.input", comment: ""), String(initialPrompt.prefix(180))))
        }

        if let recoveryBundleURL {
            details.append(String(format: NSLocalizedString("tab.restore.recovery.folder", comment: ""), recoveryBundleURL.path))
        }

        if saved.sessionId != nil && (saved.continueSession ?? false) {
            details.append(NSLocalizedString("tab.restore.continue.hint", comment: ""))
        }

        let title = saved.wasProcessing == true ? NSLocalizedString("tab.restore.interrupted", comment: "") : NSLocalizedString("tab.restore.previous", comment: "")
        appendBlock(.status(message: title), content: details.joined(separator: "\n"))
    }

    public var workerState: WorkerState {
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

    public func start() {
        isRunning = true; startTime = Date()

        // Raw terminal mode: SwiftTerm이 자체 관리
        if AppSettings.shared.rawTerminalMode {
            if !isRawMode { // 이미 raw 모드면 재시작 안 함
                // 이전 Claude 프로세스가 남아있으면 정리
                currentProcess?.terminate()
                currentProcess = nil
                isProcessing = false
                claudeActivity = .idle
                isClaude = false
                startRawTerminal()
            }
            return
        }

        // raw → normal 전환 시 상태 정리
        if isRawMode {
            isRawMode = false
            isProcessing = false
            claudeActivity = .idle
        }
        isClaude = provider == .claude

        let checker = provider.installChecker
        checker.check()
        if !checker.isInstalled {
            appendBlock(.error(message: provider.installTitle), content: provider.installDetail)
            startError = "\(provider.displayName) CLI not installed"
            isRunning = false
            if provider == .claude {
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .dofficeClaudeNotInstalled, object: nil)
                }
            }
            return
        }

        appendBlock(.sessionStart(model: selectedModel.displayName, sessionId: ""),
                     content: sessionStartSummary())
        timeline.append(TimelineEvent(timestamp: Date(), type: .started, detail: projectName))
        refreshGitInfo()

        // 초기 프롬프트가 있으면 자동 실행
        if let prompt = initialPrompt, !prompt.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.sendPrompt(prompt)
            }
        }
    }

    // MARK: - Raw Terminal (PTY)

    /// Raw terminal mode: SwiftTerm이 PTY를 관리하므로 상태만 설정
    private func startRawTerminal() {
        isRawMode = true
        isProcessing = false
        claudeActivity = .idle
        // PTY 생성/프로세스 실행은 SwiftTermContainer에서 처리
    }

    public func writeRawInput(_ text: String) {}
    public func sendRawSignal(_ signal: UInt8) {}
    public func updatePTYWindowSize(cols: UInt16, rows: UInt16) {}

    // MARK: - Send Prompt (stream-json 이벤트 스트림)

    public func sendPrompt(_ prompt: String, permissionOverride: PermissionMode? = nil, bypassWorkflowRouting: Bool = false) {
        guard !prompt.isEmpty else { return }
        PluginHost.shared.fireEvent(.onPromptSubmit)

        // Raw terminal mode: PTY에 직접 전송
        if isRawMode {
            writeRawInput(prompt + "\n")
            return
        }

        if !bypassWorkflowRouting,
           permissionOverride == nil,
           SessionManager.shared.routePromptIfNeeded(for: self, prompt: prompt) {
            return
        }

        if !bypassWorkflowRouting, permissionOverride == nil {
            SessionManager.shared.prepareDirectDeveloperWorkflowIfNeeded(for: self, prompt: prompt)
        }

        guard !isProcessing else { return }

        // 이전 프로세스 및 취소 상태 정리
        cancelledProcessIds.removeAll()
        if let prev = currentProcess, prev.isRunning {
            currentOutPipe?.fileHandleForReading.readabilityHandler = nil
            currentErrPipe?.fileHandleForReading.readabilityHandler = nil
            currentOutPipe = nil
            currentErrPipe = nil
            prev.terminate()
            currentProcess = nil
        }

        if let reason = TokenTracker.shared.startBlockReason(isAutomation: isAutomationTab) {
            appendBlock(.status(message: NSLocalizedString("tab.token.protection", comment: "")), content: reason)
            claudeActivity = .idle
            return
        }

        pendingApproval = nil
        pendingPermissionDenial = nil
        lastPermissionFingerprint = nil
        toolUseContexts.removeAll()
        parallelTasks.removeAll()
        isCompleted = false
        budgetStopIssued = false

        appendBlock(.userPrompt, content: prompt)
        timeline.append(TimelineEvent(timestamp: Date(), type: .prompt, detail: String(prompt.prefix(50)) + (prompt.count > 50 ? "..." : "")))
        trimTimelineIfNeeded()
        initialPrompt = nil
        lastPromptText = prompt
        isProcessing = true
        claudeActivity = .thinking
        lastActivityTime = Date()

        // 히스토리 스냅샷: 프롬프트 전 git 상태 캡처
        pendingHistoryFileChangeStartIndex = fileChanges.count
        let projPath = projectPath
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let hash = Self.shellSync("git -C \"\(projPath)\" rev-parse HEAD 2>/dev/null")?.trimmingCharacters(in: .whitespacesAndNewlines)
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.pendingHistoryPreHash = (hash?.isEmpty ?? true) ? nil : hash
                let entry = PromptHistoryEntry(
                    timestamp: Date(),
                    promptText: prompt,
                    gitCommitHashBefore: self.pendingHistoryPreHash
                )
                self.promptHistory.append(entry)
                // promptHistory는 @Published가 아니므로 별도 알림 불필요
                // isProcessing/claudeActivity 변경 시 자연 갱신됨
            }
        }

        let path = FileManager.default.fileExists(atPath: projectPath) ? projectPath : NSHomeDirectory()
        let effectivePermissionMode = permissionOverride ?? permissionMode

        if provider == .codex {
            let images = attachedImages
            DispatchQueue.main.async { [weak self] in
                self?.attachedImages.removeAll()
            }
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.sendPromptWithCodex(prompt, path: path, images: images)
            }
            return
        }

        if provider == .gemini {
            let images = attachedImages
            DispatchQueue.main.async { [weak self] in
                self?.attachedImages.removeAll()
            }
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else { return }
                self.sendPromptWithGemini(prompt, path: path, images: images)
            }
            return
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            var cmd = "\(self.resolvedExecutableCommand(for: .claude)) -p --output-format stream-json --verbose"

            // 권한 모드
            cmd += " --permission-mode \(effectivePermissionMode.rawValue)"
            cmd += " --model \(self.selectedModel.rawValue)"
            cmd += " --effort \(self.effortLevel.rawValue)"

            // 세션 이어하기
            if self.continueSession && self.sessionId == nil {
                cmd += " --continue"
            } else if let sid = self.sessionId {
                cmd += " --resume \(self.shellEscape(sid))"
            }

            // 세션 이름
            if !self.sessionName.isEmpty {
                cmd += " --name \(self.shellEscape(self.sessionName))"
            }
            // 시스템 프롬프트
            if !self.systemPrompt.isEmpty {
                cmd += " --append-system-prompt \(self.shellEscape(self.systemPrompt))"
            }
            // 예산 제한
            if self.maxBudgetUSD > 0 {
                cmd += " --max-budget-usd \(String(format: "%.2f", self.maxBudgetUSD))"
            }
            // 대체 모델
            if !self.fallbackModel.isEmpty {
                cmd += " --fallback-model \(self.shellEscape(self.fallbackModel))"
            }
            // JSON 스키마
            if !self.jsonSchema.isEmpty {
                cmd += " --json-schema \(self.shellEscape(self.jsonSchema))"
            }
            // 도구 제한
            let effectiveAllowedTools = self.effectiveAllowedTools()
            if !effectiveAllowedTools.isEmpty {
                cmd += " --allowed-tools \(self.shellEscape(effectiveAllowedTools))"
            }
            let effectiveDisallowedTools = self.effectiveDisallowedTools()
            if !effectiveDisallowedTools.isEmpty {
                cmd += " --disallowed-tools \(self.shellEscape(effectiveDisallowedTools))"
            }
            // 빌트인 도구
            if !self.customTools.trimmingCharacters(in: .whitespaces).isEmpty {
                cmd += " --tools \(self.shellEscape(self.customTools.trimmingCharacters(in: .whitespaces)))"
            }
            // 추가 디렉토리
            for dir in self.additionalDirs where !dir.isEmpty {
                cmd += " --add-dir \(self.shellEscape(dir))"
            }
            // MCP 설정
            for mcpPath in self.mcpConfigPaths where !mcpPath.isEmpty {
                cmd += " --mcp-config \(self.shellEscape(mcpPath))"
            }
            if self.strictMcpConfig { cmd += " --strict-mcp-config" }
            // 에이전트
            if !self.customAgent.isEmpty {
                cmd += " --agent \(self.shellEscape(self.customAgent))"
            }
            if !self.customAgentsJSON.isEmpty {
                cmd += " --agents \(self.shellEscape(self.customAgentsJSON))"
            }
            // 플러그인 (수동 + PluginManager 자동 주입)
            var allPluginDirs = self.pluginDirs.filter { !$0.isEmpty }
            let managedPaths = PluginManager.shared.activePluginPaths
            for path in managedPaths where !allPluginDirs.contains(path) {
                allPluginDirs.append(path)
            }
            for pluginDir in allPluginDirs {
                cmd += " --plugin-dir \(self.shellEscape(pluginDir))"
            }
            // 크롬
            if self.enableChrome { cmd += " --chrome" }
            // 워크트리
            if self.useWorktree { cmd += " --worktree" }
            if self.tmuxMode { cmd += " --tmux" }
            // 포크
            if self.forkSession { cmd += " --fork-session" }
            // PR
            if !self.fromPR.isEmpty { cmd += " --from-pr \(self.shellEscape(self.fromPR))" }
            // Brief
            if self.enableBrief { cmd += " --brief" }
            // 베타
            if !self.betaHeaders.isEmpty { cmd += " --betas \(self.shellEscape(self.betaHeaders))" }
            // 설정 소스
            if !self.settingSources.isEmpty { cmd += " --setting-sources \(self.shellEscape(self.settingSources))" }
            if !self.settingsFileOrJSON.isEmpty { cmd += " --settings \(self.shellEscape(self.settingsFileOrJSON))" }

            // 첨부 이미지
            let images = self.attachedImages
            for imageURL in images {
                cmd += " --image \(self.shellEscape(imageURL.path))"
            }

            // 프롬프트
            cmd += " -- \(self.shellEscape(prompt))"

            // 이미지 첨부 초기화
            DispatchQueue.main.async { [weak self] in self?.attachedImages.removeAll() }

            // 프로젝트 경로 존재 여부 확인
            let projectDirURL = URL(fileURLWithPath: path)
            if !FileManager.default.fileExists(atPath: projectDirURL.path) {
                DispatchQueue.main.async {
                    self.appendBlock(.error(message: NSLocalizedString("tab.project.path.missing", comment: "")), content: String(format: NSLocalizedString("tab.project.path.missing.detail", comment: ""), path))
                    self.isProcessing = false
                    self.claudeActivity = .idle
                }
                return
            }

            let proc = Process()
            let outPipe = Pipe()
            let errPipe = Pipe()
            proc.executableURL = URL(fileURLWithPath: "/bin/zsh")
            proc.arguments = ["-f", "-c", cmd]
            proc.currentDirectoryURL = projectDirURL
            var env = ProcessInfo.processInfo.environment
            env["PATH"] = Self.buildFullPATH()
            env["TERM"] = "dumb"; env["NO_COLOR"] = "1"
            proc.environment = env
            proc.standardOutput = outPipe
            proc.standardError = errPipe

            // 프로세스 및 파이프 참조를 메인 스레드에서 안전하게 설정
            DispatchQueue.main.async { [weak self] in
                self?.currentProcess = proc
                self?.currentOutPipe = outPipe
                self?.currentErrPipe = errPipe
            }

            // 프로세스 ID를 캡처하여 이후 검증용으로 사용
            let procId = ObjectIdentifier(proc)

            // stderr 캡처 (에러 진단용)
            errPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                let data = handle.availableData
                guard !data.isEmpty,
                      let rawText = String(data: data, encoding: .utf8) else { return }
                DispatchQueue.main.async { [weak self] in
                    guard let self = self,
                          self.currentProcess.map({ ObjectIdentifier($0) == procId }) ?? false
                    else { return }
                    let text = self.sanitizeTerminalText(rawText)
                    if !text.isEmpty && !text.hasPrefix("{") && !text.contains("node:") {
                        self.appendBlock(.error(message: "stderr"), content: text)
                    }
                }
            }

            var jsonBuffer = ""
            let bufferQueue = DispatchQueue(label: "com.doffice.jsonBuffer")

            outPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                let data = handle.availableData
                guard !data.isEmpty, let chunk = String(data: data, encoding: .utf8) else { return }
                bufferQueue.sync {
                    jsonBuffer += chunk

                    // 버퍼가 1MB를 초과하면 개행 없는 비정상 스트림 — 버퍼 초기화
                    if jsonBuffer.utf8.count > 1_048_576 {
                        jsonBuffer = ""
                        return
                    }

                    while let nl = jsonBuffer.range(of: "\n") {
                        let line = String(jsonBuffer[jsonBuffer.startIndex..<nl.lowerBound])
                        jsonBuffer = String(jsonBuffer[nl.upperBound...])
                        guard !line.trimmingCharacters(in: .whitespaces).isEmpty,
                              let ld = line.data(using: .utf8),
                              let json = try? JSONSerialization.jsonObject(with: ld) as? [String: Any] else { continue }

                        DispatchQueue.main.async { [weak self] in
                            guard let self = self,
                                  self.currentProcess.map({ ObjectIdentifier($0) == procId }) ?? false
                            else { return }
                            self.handleStreamEvent(json)
                        }
                    }
                }
            }

            do {
                try proc.run()

                // Watchdog: 30분 타임아웃 — CLI가 무한 hang 방지
                let watchdog = DispatchWorkItem { [weak proc] in
                    guard let p = proc, p.isRunning else { return }
                    print("[Doffice] ⚠️ Process watchdog: 30분 타임아웃 도달, 강제 종료")
                    p.terminate()
                }
                DispatchQueue.global().asyncAfter(deadline: .now() + 1800, execute: watchdog)

                proc.waitUntilExit()
                watchdog.cancel()
            } catch {
                print("[도피스] 프로세스 실행 실패: \(error)")
                DispatchQueue.main.async { [weak self] in
                    self?.appendBlock(.error(message: NSLocalizedString("tab.process.launch.failed", comment: "")), content: String(format: NSLocalizedString("tab.process.launch.failed.detail", comment: ""), error.localizedDescription))
                    self?.isProcessing = false
                    self?.claudeActivity = .error
                    self?.currentProcess = nil
                }
                return
            }

            outPipe.fileHandleForReading.readabilityHandler = nil
            errPipe.fileHandleForReading.readabilityHandler = nil

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                // 취소된 프로세스면 무시
                if self.cancelledProcessIds.contains(procId) {
                    self.cancelledProcessIds.remove(procId)
                    return
                }
                // 이 프로세스가 현재 프로세스인지 확인 (다른 프로세스가 이미 대체했을 수 있음)
                let isStillCurrentProcess = self.currentProcess.map { ObjectIdentifier($0) == procId } ?? true
                guard isStillCurrentProcess else { return }

                self.currentProcess = nil
                self.currentOutPipe = nil
                self.currentErrPipe = nil
                // result 이벤트에서 이미 isProcessing=false 했지만,
                // 프로세스가 비정상 종료한 경우만 여기서 처리
                if self.isProcessing {
                    self.isProcessing = false
                    self.claudeActivity = self.claudeActivity == .error ? .error : .done
                    self.finalizeParallelTasks(as: self.claudeActivity == .error ? .failed : .completed)
                }
                if let denial = self.pendingPermissionDenial, self.pendingApproval == nil {
                    self.presentPermissionApprovalIfNeeded(denial)
                }
            }
        }
    }

    private func codexConfigOverride(_ key: String, value: String) -> String {
        "-c \(shellEscape("\(key)=\"\(value)\""))"
    }

    static func isCodexMissingRolloutResumeError(_ text: String) -> Bool {
        let normalized = text.lowercased()
        return normalized.contains("thread/resume failed: no rollout found for thread id")
            || normalized.contains("error: thread/resume: thread/resume failed: no rollout found")
    }

    private func sendPromptWithCodex(_ prompt: String, path: String, images: [URL], allowResumeFallback: Bool = true) {
        let projectDirURL = URL(fileURLWithPath: path)
        if !FileManager.default.fileExists(atPath: projectDirURL.path) {
            DispatchQueue.main.async {
                self.appendBlock(.error(message: NSLocalizedString("tab.project.path.missing", comment: "")), content: String(format: NSLocalizedString("tab.project.path.missing.detail", comment: ""), path))
                self.isProcessing = false
                self.claudeActivity = .idle
            }
            return
        }

        let codexExecutable = resolvedExecutableCommand(for: .codex)
        var cmd: String
        let resumeSessionId = sessionId?.trimmingCharacters(in: .whitespacesAndNewlines)
        let shouldResume = !(resumeSessionId ?? "").isEmpty
        if shouldResume {
            cmd = "\(codexExecutable) exec resume --json"
        } else {
            cmd = "\(codexExecutable) exec --json"
        }

        cmd += " \(codexConfigOverride("sandbox_mode", value: codexSandboxMode.rawValue))"
        cmd += " \(codexConfigOverride("approval_policy", value: codexApprovalPolicy.rawValue))"
        cmd += " --skip-git-repo-check"
        cmd += " -m \(shellEscape(selectedModel.rawValue))"

        for dir in additionalDirs where !dir.isEmpty {
            cmd += " --add-dir \(shellEscape(dir))"
        }
        for imageURL in images {
            cmd += " -i \(shellEscape(imageURL.path))"
        }

        if shouldResume, let sid = resumeSessionId, !sid.isEmpty {
            cmd += " \(shellEscape(sid))"
        }
        cmd += " \(shellEscape(prompt))"

        let proc = Process()
        let outPipe = Pipe()
        let errPipe = Pipe()
        proc.executableURL = URL(fileURLWithPath: "/bin/zsh")
        proc.arguments = ["-f", "-c", cmd]
        proc.currentDirectoryURL = projectDirURL
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = Self.buildFullPATH()
        env["TERM"] = "dumb"
        env["NO_COLOR"] = "1"
        proc.environment = env
        proc.standardOutput = outPipe
        proc.standardError = errPipe

        DispatchQueue.main.async { [weak self] in
            self?.currentProcess = proc
            self?.currentOutPipe = outPipe
            self?.currentErrPipe = errPipe
        }

        let procId = ObjectIdentifier(proc)
        var jsonBuffer = ""
        let bufferQueue = DispatchQueue(label: "com.doffice.codex.jsonBuffer")
        let stderrStateQueue = DispatchQueue(label: "com.doffice.codex.stderrState")
        var sawMissingRolloutResumeError = false

        errPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty,
                  let rawText = String(data: data, encoding: .utf8) else { return }
            let sanitized = self?.sanitizeTerminalText(rawText) ?? rawText.trimmingCharacters(in: .whitespacesAndNewlines)
            stderrStateQueue.sync {
                if !sanitized.isEmpty {
                    if Self.isCodexMissingRolloutResumeError(sanitized) {
                        sawMissingRolloutResumeError = true
                    }
                }
            }
            DispatchQueue.main.async { [weak self] in
                guard let self = self,
                      self.currentProcess.map({ ObjectIdentifier($0) == procId }) ?? false
                else { return }
                let text = sanitized
                guard !text.isEmpty,
                      !text.contains(" WARN "),
                      !text.hasPrefix("{") else { return }
                if shouldResume && allowResumeFallback && Self.isCodexMissingRolloutResumeError(text) {
                    return
                }
                self.appendBlock(.error(message: "stderr"), content: text)
            }
        }

        outPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty,
                  let chunk = String(data: data, encoding: .utf8) else { return }
            bufferQueue.sync {
                jsonBuffer += chunk

                if jsonBuffer.utf8.count > 1_048_576 {
                    jsonBuffer = ""
                    return
                }

                while let nl = jsonBuffer.range(of: "\n") {
                    let line = String(jsonBuffer[..<nl.lowerBound])
                    jsonBuffer = String(jsonBuffer[nl.upperBound...])
                    guard !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                          let data = line.data(using: .utf8),
                          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                        continue
                    }

                    DispatchQueue.main.async { [weak self] in
                        guard let self = self,
                              self.currentProcess.map({ ObjectIdentifier($0) == procId }) ?? false
                        else { return }
                        self.handleCodexStreamEvent(json)
                    }
                }
            }
        }

        do {
            try proc.run()

            let watchdog = DispatchWorkItem { [weak proc] in
                guard let p = proc, p.isRunning else { return }
                print("[Doffice] ⚠️ Codex process watchdog: 30분 타임아웃 도달, 강제 종료")
                p.terminate()
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + 1800, execute: watchdog)

            proc.waitUntilExit()
            watchdog.cancel()
        } catch {
            print("[도피스] Codex 프로세스 실행 실패: \(error)")
            DispatchQueue.main.async { [weak self] in
                self?.appendBlock(.error(message: "Codex launch failed"), content: error.localizedDescription)
                self?.isProcessing = false
                self?.claudeActivity = .error
                self?.currentProcess = nil
                self?.currentOutPipe = nil
                self?.currentErrPipe = nil
            }
            return
        }

        outPipe.fileHandleForReading.readabilityHandler = nil
        errPipe.fileHandleForReading.readabilityHandler = nil

        let shouldRetryWithoutResume = stderrStateQueue.sync {
            shouldResume && allowResumeFallback && sawMissingRolloutResumeError
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.cancelledProcessIds.contains(procId) {
                self.cancelledProcessIds.remove(procId)
                return
            }
            let isStillCurrentProcess = self.currentProcess.map { ObjectIdentifier($0) == procId } ?? true
            guard isStillCurrentProcess else { return }

            self.currentProcess = nil
            self.currentOutPipe = nil
            self.currentErrPipe = nil
            if shouldRetryWithoutResume {
                self.sessionId = nil
                self.claudeActivity = .thinking
                self.appendBlock(
                    .status(message: "Codex session restart"),
                    content: "이전 Codex 세션을 이어갈 수 없어 새 세션으로 다시 시도합니다."
                )
                DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                    self?.sendPromptWithCodex(prompt, path: path, images: images, allowResumeFallback: false)
                }
                return
            }
            if self.isProcessing {
                self.isProcessing = false
                self.claudeActivity = self.claudeActivity == .error ? .error : .done
                self.finalizeParallelTasks(as: self.claudeActivity == .error ? .failed : .completed)
            }
        }
    }

    // MARK: - Gemini CLI

    private func sendPromptWithGemini(_ prompt: String, path: String, images: [URL]) {
        let projectDirURL = URL(fileURLWithPath: path)
        if !FileManager.default.fileExists(atPath: projectDirURL.path) {
            DispatchQueue.main.async {
                self.appendBlock(.error(message: NSLocalizedString("tab.project.path.missing", comment: "")), content: String(format: NSLocalizedString("tab.project.path.missing.detail", comment: ""), path))
                self.isProcessing = false
                self.claudeActivity = .idle
            }
            return
        }

        // Gemini CLI: pipe prompt via stdin, capture plain text stdout
        // NOTE: Gemini CLI hangs with -m flag for most models,
        // so we only pass it when not using the default model.
        let geminiCmd = resolvedExecutableCommand(for: .gemini)
        var cmd = "printf '%s\\n' \(shellEscape(prompt)) | \(geminiCmd)"

        // Gemini CLI yolo mode
        if permissionMode == .bypassPermissions {
            cmd += " --yolo"
        }

        // Suppress stderr noise
        cmd += " 2>/dev/null"

        let proc = Process()
        let outPipe = Pipe()
        let errPipe = Pipe()
        proc.executableURL = URL(fileURLWithPath: "/bin/zsh")
        proc.arguments = ["-f", "-c", cmd]
        proc.currentDirectoryURL = projectDirURL
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = Self.buildFullPATH()
        proc.environment = env
        proc.standardOutput = outPipe
        proc.standardError = errPipe

        DispatchQueue.main.async { [weak self] in
            self?.currentProcess = proc
            self?.currentOutPipe = outPipe
            self?.currentErrPipe = errPipe
        }
        let procId = ObjectIdentifier(proc)

        // Stream stdout — Gemini CLI outputs plain text (not JSON)
        // Accumulate all output into a single response block for clean rendering
        var textBuffer = ""
        var responseBlockId: UUID?
        let bufferQueue = DispatchQueue(label: "com.doffice.gemini.textBuffer")

        outPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let chunk = String(data: data, encoding: .utf8) else { return }
            bufferQueue.sync {
                textBuffer += chunk

                if textBuffer.utf8.count > 1_048_576 {
                    textBuffer = ""
                    return
                }

                // Collect complete lines
                var newLines: [String] = []
                while let nl = textBuffer.range(of: "\n") {
                    let line = String(textBuffer[..<nl.lowerBound])
                    textBuffer = String(textBuffer[nl.upperBound...])

                    // Strip ANSI escape codes
                    let cleaned = line
                        .replacingOccurrences(of: "\u{1B}\\[[0-9;]*[a-zA-Z]", with: "", options: .regularExpression)

                    // Skip interactive prompt markers
                    let trimmed = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmed == ">" || trimmed == " >" || trimmed.isEmpty { continue }

                    // Strip "✦ " prefix
                    let content = trimmed.hasPrefix("✦") ? String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces) : cleaned
                    if !content.isEmpty {
                        newLines.append(content)
                    }
                }

                guard !newLines.isEmpty else { return }

                DispatchQueue.main.async { [weak self] in
                    guard let self = self,
                          self.currentProcess.map({ ObjectIdentifier($0) == procId }) ?? false
                    else { return }
                    self.claudeActivity = .writing

                    // Append to existing response block or create new one
                    if let blockId = responseBlockId,
                       let idx = self.blocks.lastIndex(where: { $0.id == blockId }) {
                        self.blocks[idx].content += "\n" + newLines.joined(separator: "\n")
                    } else {
                        let block = StreamBlock(type: .text, content: newLines.joined(separator: "\n"))
                        responseBlockId = block.id
                        self.blocks.append(block)
                    }
                }
            }
        }

        // stderr is suppressed via 2>/dev/null in the command,
        // but handle any remaining output silently
        errPipe.fileHandleForReading.readabilityHandler = { handle in
            _ = handle.availableData // drain to prevent pipe blocking
        }

        do {
            try proc.run()

            let watchdog = DispatchWorkItem { [weak proc] in
                guard let p = proc, p.isRunning else { return }
                p.terminate()
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + 1800, execute: watchdog)

            proc.waitUntilExit()
            watchdog.cancel()
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.appendBlock(.error(message: "Gemini launch failed"), content: error.localizedDescription)
                self?.isProcessing = false
                self?.claudeActivity = .error
                self?.currentProcess = nil
                self?.currentOutPipe = nil
                self?.currentErrPipe = nil
            }
            return
        }

        outPipe.fileHandleForReading.readabilityHandler = nil
        errPipe.fileHandleForReading.readabilityHandler = nil

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.cancelledProcessIds.contains(procId) {
                self.cancelledProcessIds.remove(procId)
                return
            }
            let isStillCurrentProcess = self.currentProcess.map { ObjectIdentifier($0) == procId } ?? true
            guard isStillCurrentProcess else { return }

            self.currentProcess = nil
            self.currentOutPipe = nil
            self.currentErrPipe = nil
            if self.isProcessing {
                self.isProcessing = false
                self.claudeActivity = self.claudeActivity == .error ? .error : .done
                self.finalizeParallelTasks(as: self.claudeActivity == .error ? .failed : .completed)
            }
        }
    }

    // MARK: - Gemini Stream Event Handler

    private func handleGeminiStreamEvent(_ json: [String: Any]) {
        guard isRunning, !json.isEmpty else { return }
        let type = json["type"] as? String ?? ""

        switch type {
        case "init":
            if let sid = json["session_id"] as? String { sessionId = sid }
            if let model = json["model"] as? String {
                updateReportedModel(model)
            }

        case "message":
            let role = json["role"] as? String ?? ""
            let content = json["content"] as? String ?? ""
            guard !content.isEmpty else { return }

            if role == "assistant" {
                claudeActivity = .writing
                // delta=true 이면 스트리밍 조각 → 마지막 thought 블록에 연결
                let isDelta = json["delta"] as? Bool ?? false
                if isDelta,
                   !blocks.isEmpty,
                   case .thought = blocks[blocks.count - 1].blockType {
                    blocks[blocks.count - 1].content += content
                } else {
                    appendBlock(.thought, content: content)
                }
            }

        case "tool_use":
            let toolName = json["tool_name"] as? String ?? ""
            let toolId = json["tool_id"] as? String ?? UUID().uuidString
            let params = json["parameters"] as? [String: Any] ?? [:]

            guard !seenToolUseIds.contains(toolId) else { return }
            seenToolUseIds.insert(toolId)

            switch toolName {
            case "shell", "bash", "execute_command":
                claudeActivity = .running
                commandCount += 1
                let cmd = params["command"] as? String ?? params["cmd"] as? String ?? ""
                appendBlock(.toolUse(name: "Bash", input: cmd), content: cmd)
                timeline.append(TimelineEvent(timestamp: Date(), type: .toolUse, detail: "Bash: \(String(cmd.prefix(40)))"))
            case "read_file":
                claudeActivity = .reading
                let file = params["file_path"] as? String ?? ""
                appendBlock(.toolUse(name: "Read", input: file), content: (file as NSString).lastPathComponent)
            case "write_file", "create_file":
                claudeActivity = .writing
                let file = params["file_path"] as? String ?? ""
                recordFileChange(path: file, action: "Write")
                appendBlock(.fileChange(path: file, action: "Write"), content: (file as NSString).lastPathComponent)
                timeline.append(TimelineEvent(timestamp: Date(), type: .fileChange, detail: "Write: \((file as NSString).lastPathComponent)"))
            case "edit_file", "replace_in_file":
                claudeActivity = .writing
                let file = params["file_path"] as? String ?? ""
                recordFileChange(path: file, action: "Edit")
                appendBlock(.fileChange(path: file, action: "Edit"), content: (file as NSString).lastPathComponent)
                timeline.append(TimelineEvent(timestamp: Date(), type: .fileChange, detail: "Edit: \((file as NSString).lastPathComponent)"))
            case "glob", "list_directory", "grep", "search":
                claudeActivity = .searching
                let pattern = params["pattern"] as? String ?? params["dir_path"] as? String ?? toolName
                appendBlock(.toolUse(name: toolName, input: pattern), content: pattern)
            default:
                claudeActivity = .running
                let preview = toolPreview(toolName: toolName, toolInput: params)
                appendBlock(.toolUse(name: toolName, input: preview), content: preview)
            }

        case "tool_result":
            let output = json["output"] as? String ?? ""
            let status = json["status"] as? String ?? ""
            if status == "error" {
                appendBlock(.toolError, content: output)
                errorCount += 1
            } else if !output.isEmpty {
                appendBlock(.toolOutput, content: String(output.prefix(2000)))
            }

        case "result":
            let stats = json["stats"] as? [String: Any] ?? [:]
            let totalTokens = stats["total_tokens"] as? Int ?? 0
            let inputTokens = stats["input_tokens"] as? Int ?? 0
            let outputTokens = stats["output_tokens"] as? Int ?? 0
            let durationMs = stats["duration_ms"] as? Int ?? 0

            let diffIn = max(0, inputTokens - inputTokensUsed)
            let diffOut = max(0, outputTokens - outputTokensUsed)
            if diffIn > 0 || diffOut > 0 {
                TokenTracker.shared.recordTokens(input: diffIn, output: diffOut)
            }
            inputTokensUsed = inputTokens
            outputTokensUsed = outputTokens
            tokensUsed = totalTokens

            appendBlock(.completion(cost: 0, duration: durationMs), content: "완료")
            timeline.append(TimelineEvent(timestamp: Date(), type: .completed, detail: "작업 완료"))

            isProcessing = false
            claudeActivity = .done
            completedPromptCount += 1
            finalizeParallelTasks(as: .completed)
            finalizePromptHistory()
            generateSummary()
            sendCompletionNotification()
            seenToolUseIds.removeAll()

            NotificationCenter.default.post(
                name: .dofficeTabCycleCompleted,
                object: self,
                userInfo: [
                    "tabId": id,
                    "completedPromptCount": completedPromptCount,
                    "resultText": lastResultText
                ]
            )

        default:
            break
        }
    }

    private func handleCodexStreamEvent(_ json: [String: Any]) {
        guard isRunning, !json.isEmpty else { return }
        let type = json["type"] as? String ?? ""

        switch type {
        case "thread.started":
            if let sid = json["thread_id"] as? String, !sid.isEmpty {
                sessionId = sid
            }

        case "item.started":
            guard let item = json["item"] as? [String: Any] else { return }
            handleCodexItem(item, started: true)

        case "item.completed":
            guard let item = json["item"] as? [String: Any] else { return }
            handleCodexItem(item, started: false)

        case "turn.completed":
            if let usage = json["usage"] as? [String: Any] {
                let input = usage["input_tokens"] as? Int ?? 0
                let output = usage["output_tokens"] as? Int ?? 0
                if input > 0 || output > 0 {
                    inputTokensUsed += input
                    outputTokensUsed += output
                    tokensUsed = inputTokensUsed + outputTokensUsed
                    TokenTracker.shared.recordTokens(input: input, output: output)
                    enforceTokenBudgetIfNeeded()
                }
            }

            appendBlock(.completion(cost: nil, duration: nil), content: "완료")
            timeline.append(TimelineEvent(timestamp: Date(), type: .completed, detail: "작업 완료"))
            isProcessing = false
            claudeActivity = .done
            completedPromptCount += 1
            finalizeParallelTasks(as: .completed)
            generateSummary()
            sendCompletionNotification()
            PluginHost.shared.fireEvent(.onSessionComplete, context: ["tabId": id])
            NotificationCenter.default.post(
                name: .dofficeTabCycleCompleted,
                object: self,
                userInfo: [
                    "tabId": id,
                    "completedPromptCount": completedPromptCount,
                    "resultText": lastResultText
                ]
            )
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                if self?.claudeActivity == .done { self?.claudeActivity = .idle }
            }

        case "exec_approval_request":
            claudeActivity = .error
            errorCount += 1
            appendBlock(.error(message: "Codex approval required"), content: "현재 Codex exec JSON 모드에서는 실시간 승인 응답을 지원하지 않습니다. 승인 정책이나 샌드박스 설정을 조정해 다시 시도해주세요.")

        case "error":
            let message = (json["message"] as? String) ?? "Codex execution failed"
            claudeActivity = .error
            errorCount += 1
            appendBlock(.error(message: message), content: message)

        default:
            break
        }
    }

    private func handleCodexItem(_ item: [String: Any], started: Bool) {
        let itemType = item["type"] as? String ?? ""

        switch itemType {
        case "agent_message":
            guard !started else { return }
            let text = item["text"] as? String ?? ""
            guard !text.isEmpty else { return }
            claudeActivity = .writing
            lastResultText = text
            appendBlock(.thought, content: text)

        case "command_execution":
            let command = item["command"] as? String ?? ""
            if started {
                claudeActivity = .running
                commandCount += 1
                appendBlock(.toolUse(name: "Bash", input: command), content: command)
                timeline.append(TimelineEvent(timestamp: Date(), type: .toolUse, detail: "Bash: \(String(command.prefix(40)))"))
            } else {
                let output = sanitizeTerminalText(item["aggregated_output"] as? String ?? "")
                let exitCode = item["exit_code"] as? Int ?? 0
                if !output.isEmpty {
                    appendBlock(.toolOutput, content: output)
                }
                if exitCode != 0 {
                    errorCount += 1
                    appendBlock(.toolError, content: "exit \(exitCode)")
                    claudeActivity = .error
                }
            }

        case "file_change":
            guard !started else { return }
            let changes = item["changes"] as? [[String: Any]] ?? []
            claudeActivity = .writing
            for change in changes {
                let path = change["path"] as? String ?? ""
                guard !path.isEmpty else { continue }
                let kind = (change["kind"] as? String ?? "update").lowercased()
                let action: String
                switch kind {
                case "add":
                    action = "Write"
                case "delete":
                    action = "Delete"
                default:
                    action = "Edit"
                }
                recordFileChange(path: path, action: action)
                appendBlock(.fileChange(path: path, action: action), content: (path as NSString).lastPathComponent)
                timeline.append(TimelineEvent(timestamp: Date(), type: .fileChange, detail: "\(action): \((path as NSString).lastPathComponent)"))
            }

        default:
            break
        }
    }

    // MARK: - Stream Event Handler (핵심 파서)

    private func handleStreamEvent(_ json: [String: Any]) {
        guard isRunning else { return }
        // 비정상 데이터로 인한 크래시 방지
        guard !json.isEmpty else { return }
        let type = json["type"] as? String ?? ""

        switch type {
        case "system":
            if let sid = json["session_id"] as? String { sessionId = sid }
            if let model = json["model"] as? String {
                updateReportedModel(model)
            }

        case "assistant":
            guard let msg = json["message"] as? [String: Any],
                  let content = msg["content"] as? [[String: Any]] else { return }

            // usage가 message 안에 있을 수도, 최상위에 있을 수도 있음
            let usageObj = msg["usage"] as? [String: Any] ?? json["usage"] as? [String: Any]
            if let usage = usageObj {
                let input = usage["input_tokens"] as? Int ?? 0
                let output = usage["output_tokens"] as? Int ?? 0
                // 3개 @Published를 개별 갱신하지 않고 한 번에 처리
                let newInput = inputTokensUsed + input
                let newOutput = outputTokensUsed + output
                inputTokensUsed = newInput
                outputTokensUsed = newOutput
                tokensUsed = newInput + newOutput
                TokenTracker.shared.recordTokens(input: input, output: output)
                enforceTokenBudgetIfNeeded()
            }

            for block in content {
                let blockType = block["type"] as? String ?? ""

                if blockType == "text" {
                    let text = block["text"] as? String ?? ""
                    if !text.isEmpty {
                        // Assistant response text is visible output, so the office actor
                        // should return to the workstation instead of lingering in a
                        // remote "thinking" spot.
                        claudeActivity = .writing
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
                    let toolPreview = toolPreview(toolName: toolName, toolInput: toolInput)
                    toolUseContexts[toolUseId] = ToolUseContext(id: toolUseId, name: toolName, input: toolInput, preview: toolPreview)

                    switch toolName {
                    case "Bash":
                        claudeActivity = .running
                        commandCount += 1
                        let cmd = toolInput["command"] as? String ?? ""
                        // 보안: 위험 명령 감지
                        if let match = DangerousCommandDetector.shared.check(command: cmd) {
                            dangerousCommandWarning = "⚠️ \(match.pattern.severity.displayName): \(match.pattern.description)\n→ \(match.matchedText)"
                            AuditLog.shared.log(.dangerousCommand, tabId: id, projectName: projectName, detail: cmd, isDangerous: true)
                        }
                        // 감사 로그
                        AuditLog.shared.log(.bashCommand, tabId: id, projectName: projectName, detail: cmd)
                        let desc = toolInput["description"] as? String
                        let header = desc.map { "\(cmd)  // \($0)" } ?? cmd
                        appendBlock(.toolUse(name: "Bash", input: cmd), content: header)
                        timeline.append(TimelineEvent(timestamp: Date(), type: .toolUse, detail: "Bash: \(String(cmd.prefix(40)))"))
                    case "Read":
                        claudeActivity = .reading
                        let file = toolInput["file_path"] as? String ?? ""
                        // 보안: 민감 파일 감지
                        if let match = SensitiveFileShield.shared.check(filePath: file, action: "Read") {
                            sensitiveFileWarning = String(format: NSLocalizedString("sensitive.file.read", comment: ""), match.patternMatched, file)
                            AuditLog.shared.log(.sensitiveFileAccess, tabId: id, projectName: projectName, detail: "Read: \(file)", isDangerous: true)
                        }
                        AuditLog.shared.log(.fileRead, tabId: id, projectName: projectName, detail: file)
                        appendBlock(.toolUse(name: "Read", input: file), content: (file as NSString).lastPathComponent)
                        readCommandCount += 1
                        NotificationCenter.default.post(name: .init("dofficeAchievementFileRead"), object: readCommandCount)
                    case "Write":
                        claudeActivity = .writing
                        let file = toolInput["file_path"] as? String ?? ""
                        if let match = SensitiveFileShield.shared.check(filePath: file, action: "Write") {
                            sensitiveFileWarning = String(format: NSLocalizedString("sensitive.file.write", comment: ""), match.patternMatched, file)
                            AuditLog.shared.log(.sensitiveFileAccess, tabId: id, projectName: projectName, detail: "Write: \(file)", isDangerous: true)
                        }
                        AuditLog.shared.log(.fileWrite, tabId: id, projectName: projectName, detail: file)
                        recordFileChange(path: file, action: "Write")
                        appendBlock(.fileChange(path: file, action: "Write"), content: (file as NSString).lastPathComponent)
                        timeline.append(TimelineEvent(timestamp: Date(), type: .fileChange, detail: "Write: \((file as NSString).lastPathComponent)"))
                        NotificationCenter.default.post(name: .init("dofficeAchievementFileEdit"), object: nil)
                    case "Edit":
                        claudeActivity = .writing
                        let file = toolInput["file_path"] as? String ?? ""
                        if let match = SensitiveFileShield.shared.check(filePath: file, action: "Edit") {
                            sensitiveFileWarning = String(format: NSLocalizedString("sensitive.file.edit", comment: ""), match.patternMatched, file)
                            AuditLog.shared.log(.sensitiveFileAccess, tabId: id, projectName: projectName, detail: "Edit: \(file)", isDangerous: true)
                        }
                        AuditLog.shared.log(.fileEdit, tabId: id, projectName: projectName, detail: file)
                        recordFileChange(path: file, action: "Edit")
                        appendBlock(.fileChange(path: file, action: "Edit"), content: (file as NSString).lastPathComponent)
                        timeline.append(TimelineEvent(timestamp: Date(), type: .fileChange, detail: "Edit: \((file as NSString).lastPathComponent)"))
                        NotificationCenter.default.post(name: .init("dofficeAchievementFileEdit"), object: nil)
                    case "Grep":
                        claudeActivity = .searching
                        let pattern = toolInput["pattern"] as? String ?? ""
                        appendBlock(.toolUse(name: "Grep", input: pattern), content: pattern)
                        NotificationCenter.default.post(name: .init("dofficeAchievementUnlock"), object: "first_grep")
                    case "Glob":
                        claudeActivity = .searching
                        let pattern = toolInput["pattern"] as? String ?? ""
                        appendBlock(.toolUse(name: "Glob", input: pattern), content: pattern)
                        NotificationCenter.default.post(name: .init("dofficeAchievementUnlock"), object: "first_glob")
                    case "Task":
                        claudeActivity = .thinking
                        let taskLabel = registerParallelTask(toolUseId: toolUseId, input: toolInput)
                        appendBlock(.toolUse(name: "Task", input: taskLabel), content: taskLabel)
                    default:
                        appendBlock(.toolUse(name: toolName, input: ""), content: toolPreview.isEmpty ? toolName : toolPreview)
                    }

                    activeToolBlockIndex = blocks.count - 1
                }
            }

        case "user":
            handleUserToolResult(json)

        case "result":
            let cost = json["total_cost_usd"] as? Double ?? 0
            let duration = json["duration_ms"] as? Int ?? 0
            let resultText = json["result"] as? String ?? ""
            let permissionDenials = json["permission_denials"] as? [[String: Any]] ?? []
            totalCost += cost
            TokenTracker.shared.recordCost(cost)

            // result 이벤트에서 토큰 파싱 — total_*를 우선 사용 (이중 카운팅 방지)
            let hasTotals = json["total_input_tokens"] as? Int != nil
            if hasTotals,
               let totalInput = json["total_input_tokens"] as? Int,
               let totalOutput = json["total_output_tokens"] as? Int {
                // 권위적 전체 값 → 현재 누적과의 차이만 TokenTracker에 기록
                let diffIn = max(0, totalInput - inputTokensUsed)
                let diffOut = max(0, totalOutput - outputTokensUsed)
                if diffIn > 0 || diffOut > 0 {
                    TokenTracker.shared.recordTokens(input: diffIn, output: diffOut)
                }
                inputTokensUsed = totalInput
                outputTokensUsed = totalOutput
                tokensUsed = totalInput + totalOutput
                enforceTokenBudgetIfNeeded()
            } else if let usage = json["usage"] as? [String: Any] {
                // total_*가 없을 때만 증분 usage 사용
                let input = usage["input_tokens"] as? Int ?? 0
                let output = usage["output_tokens"] as? Int ?? 0
                if input > 0 || output > 0 {
                    inputTokensUsed += input
                    outputTokensUsed += output
                    tokensUsed = inputTokensUsed + outputTokensUsed
                    TokenTracker.shared.recordTokens(input: input, output: output)
                    enforceTokenBudgetIfNeeded()
                }
            }

            if let sid = json["session_id"] as? String { sessionId = sid }
            if let latestDenial = permissionDenials.last {
                pendingPermissionDenial = permissionDenialCandidate(from: latestDenial)
            }

            appendBlock(.completion(cost: cost, duration: duration),
                        content: "완료")
            timeline.append(TimelineEvent(timestamp: Date(), type: .completed, detail: "작업 완료"))

            // 슬립워크 완료 체크
            if sleepWorkTask != nil {
                sleepWorkCompleted = true
                sleepWorkTask = nil
                AuditLog.shared.log(.sleepWorkEnd, tabId: id, projectName: projectName, detail: "슬립워크 완료")
            }

            // 즉시 완료 상태로 전환 (프로세스 종료 기다리지 않음)
            isProcessing = false
            claudeActivity = .done
            lastResultText = resultText
            completedPromptCount += 1
            finalizeParallelTasks(as: .completed)
            finalizePromptHistory()
            generateSummary()
            seenToolUseIds.removeAll()
            if let denial = pendingPermissionDenial {
                presentPermissionApprovalIfNeeded(denial)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                if self?.claudeActivity == .done { self?.claudeActivity = .idle }
            }

            if permissionDenials.isEmpty {
                sendCompletionNotification()
                PluginHost.shared.fireEvent(.onSessionComplete, context: ["tabId": id])
                NotificationCenter.default.post(
                    name: .dofficeTabCycleCompleted,
                    object: self,
                    userInfo: [
                        "tabId": id,
                        "completedPromptCount": completedPromptCount,
                        "resultText": resultText
                    ]
                )
            }

        default:
            break
        }
    }

    private func handleUserToolResult(_ json: [String: Any]) {
        let toolUseId = extractToolUseId(from: json)

        if let result = json["tool_use_result"] as? [String: Any] {
            let stdout = result["stdout"] as? String ?? ""
            let stderr = result["stderr"] as? String ?? ""
            let interrupted = result["interrupted"] as? Bool ?? false
            let isError = (result["is_error"] as? Bool) ?? isToolResultError(from: json)
            let cleanedStdout = sanitizeTerminalText(stdout)
            let cleanedStderr = sanitizeTerminalText(stderr)

            if !cleanedStdout.isEmpty {
                appendBlock(.toolOutput, content: cleanedStdout)
            }
            if !cleanedStderr.isEmpty {
                errorCount += 1
                appendBlock(.toolError, content: cleanedStderr)
                timeline.append(TimelineEvent(timestamp: Date(), type: .error, detail: String(cleanedStderr.prefix(50))))
            } else if isError, let message = extractToolResultText(from: json) {
                let cleanedMessage = sanitizeTerminalText(message)
                errorCount += 1
                appendBlock(.toolError, content: cleanedMessage)
                timeline.append(TimelineEvent(timestamp: Date(), type: .error, detail: String(cleanedMessage.prefix(50))))
                recordPermissionDenialIfNeeded(message: cleanedMessage, toolUseId: toolUseId)
            }

            if interrupted {
                appendBlock(.toolEnd(success: false), content: "중단됨")
            } else {
                appendBlock(.toolEnd(success: !isError))
            }

            if let toolUseId {
                updateParallelTask(toolUseId: toolUseId, succeeded: !isError && !interrupted)
            }

            activeToolBlockIndex = nil
            return
        }

        if let message = extractToolResultText(from: json) {
            let cleanedMessage = sanitizeTerminalText(message)
            let isError = isToolResultError(from: json) || cleanedMessage.lowercased().contains("error:")
            if isError {
                errorCount += 1
                appendBlock(.toolError, content: cleanedMessage)
                timeline.append(TimelineEvent(timestamp: Date(), type: .error, detail: String(cleanedMessage.prefix(50))))
                recordPermissionDenialIfNeeded(message: cleanedMessage, toolUseId: toolUseId)
                appendBlock(.toolEnd(success: false))
            } else if !cleanedMessage.isEmpty {
                appendBlock(.toolOutput, content: cleanedMessage)
                appendBlock(.toolEnd(success: true))
            }

            if let toolUseId {
                updateParallelTask(toolUseId: toolUseId, succeeded: !isError)
            }

            activeToolBlockIndex = nil
        }
    }

    private func extractToolUseId(from json: [String: Any]) -> String? {
        guard let message = json["message"] as? [String: Any],
              let content = message["content"] as? [[String: Any]] else { return nil }
        return content.first(where: { ($0["type"] as? String) == "tool_result" })?["tool_use_id"] as? String
    }

    private func extractToolResultText(from json: [String: Any]) -> String? {
        if let raw = json["tool_use_result"] as? String {
            return cleanedToolResultText(raw)
        }

        guard let message = json["message"] as? [String: Any],
              let content = message["content"] as? [[String: Any]] else { return nil }

        for item in content where (item["type"] as? String) == "tool_result" {
            if let text = item["content"] as? String {
                return cleanedToolResultText(text)
            }
        }
        return nil
    }

    private func isToolResultError(from json: [String: Any]) -> Bool {
        guard let message = json["message"] as? [String: Any],
              let content = message["content"] as? [[String: Any]] else { return false }
        return content.contains {
            ($0["type"] as? String) == "tool_result" && (($0["is_error"] as? Bool) ?? false)
        }
    }

    private func cleanedToolResultText(_ text: String) -> String {
        text.replacingOccurrences(of: "^Error:\\s*", with: "", options: .regularExpression)
    }

    private func recordPermissionDenialIfNeeded(message: String, toolUseId: String?) {
        guard isPermissionDenialMessage(message) else { return }

        let context = toolUseId.flatMap { toolUseContexts[$0] }
        pendingPermissionDenial = PermissionDenialCandidate(
            toolUseId: toolUseId,
            toolName: context?.name ?? "Tool",
            toolInput: context?.input ?? [:],
            message: message
        )
    }

    private func permissionDenialCandidate(from denial: [String: Any]) -> PermissionDenialCandidate {
        let toolUseId = denial["tool_use_id"] as? String
        let context = toolUseId.flatMap { toolUseContexts[$0] }
        let toolName = denial["tool_name"] as? String ?? context?.name ?? "Tool"
        let toolInput = denial["tool_input"] as? [String: Any] ?? context?.input ?? [:]
        let message = pendingPermissionDenial?.message
            ?? permissionDenialMessage(toolName: toolName, toolInput: toolInput)
            ?? "Claude requested permissions to use \(toolName), but you haven't granted it yet."

        return PermissionDenialCandidate(
            toolUseId: toolUseId,
            toolName: toolName,
            toolInput: toolInput,
            message: message
        )
    }

    private func presentPermissionApprovalIfNeeded(_ denial: PermissionDenialCandidate) {
        let command = approvalCommandText(for: denial)
        let fingerprint = [denial.toolName, command].joined(separator: "|")
        guard pendingApproval == nil, lastPermissionFingerprint != fingerprint else { return }

        let retryMode = retryPermissionMode(for: denial.toolName)
        let retrySummary = retryMode == .acceptEdits
            ? NSLocalizedString("tab.permission.retry.edit", comment: "")
            : NSLocalizedString("tab.permission.retry.full", comment: "")

        lastPermissionFingerprint = fingerprint
        let approvalCommand = command
        pendingApproval = PendingApproval(
            command: approvalCommand,
            reason: String(format: NSLocalizedString("tab.permission.needed", comment: ""), approvalReasonPrefix(for: denial.toolName), retrySummary),
            onApprove: { [weak self] in
                self?.pendingPermissionDenial = nil
                self?.appendBlock(.status(message: NSLocalizedString("tab.permission.approved", comment: "")))
                self?.sendPrompt(self?.approvalRetryPrompt(for: denial.toolName) ?? "Permission granted. Please continue the previous task.", permissionOverride: retryMode)
            },
            onDeny: { [weak self] in
                self?.pendingPermissionDenial = nil
                self?.appendBlock(.status(message: NSLocalizedString("tab.permission.denied", comment: "")))
            }
        )
        // 세션 알림: 승인 필요
        let tabName = workerName.isEmpty ? projectName : workerName
        NotificationCenter.default.post(name: .init("dofficeApprovalNeeded"), object: nil, userInfo: ["tabName": tabName, "tabId": id, "toolName": denial.toolName])
    }

    private func retryPermissionMode(for toolName: String) -> PermissionMode {
        switch toolName {
        case "Write", "Edit", "NotebookEdit":
            return .acceptEdits
        default:
            return .bypassPermissions
        }
    }

    private func approvalRetryPrompt(for toolName: String) -> String {
        switch retryPermissionMode(for: toolName) {
        case .acceptEdits:
            return "Permission granted. You may now make the required file edits. Please continue the previous task."
        default:
            return "Permission granted. You may now use the required tool. Please continue the previous task."
        }
    }

    private func approvalReasonPrefix(for toolName: String) -> String {
        switch toolName {
        case "Write", "Edit", "NotebookEdit":
            return NSLocalizedString("tab.approval.file.edit", comment: "")
        case "Bash":
            return NSLocalizedString("tab.approval.command.run", comment: "")
        case "WebFetch":
            return NSLocalizedString("tab.approval.web.fetch", comment: "")
        case "WebSearch":
            return NSLocalizedString("tab.approval.web.search", comment: "")
        default:
            return toolName
        }
    }

    private func approvalCommandText(for denial: PermissionDenialCandidate) -> String {
        let detail = toolPreview(toolName: denial.toolName, toolInput: denial.toolInput)
        if detail.isEmpty {
            return denial.message
        }
        return "\(denial.toolName) · \(detail)"
    }

    private func permissionDenialMessage(toolName: String, toolInput: [String: Any]) -> String? {
        switch toolName {
        case "Write", "Edit", "NotebookEdit":
            if let filePath = toolInput["file_path"] as? String {
                return "Claude requested permissions to write to \(filePath), but you haven't granted it yet."
            }
        case "Bash":
            if let command = toolInput["command"] as? String {
                return "Claude requested permissions to run \(command), but you haven't granted it yet."
            }
        case "WebFetch":
            return "Claude requested permissions to use WebFetch, but you haven't granted it yet."
        case "WebSearch":
            return "Claude requested permissions to use WebSearch, but you haven't granted it yet."
        default:
            return "Claude requested permissions to use \(toolName), but you haven't granted it yet."
        }
        return nil
    }

    private func isPermissionDenialMessage(_ message: String) -> Bool {
        message.lowercased().contains("requested permissions")
    }

    private func toolPreview(toolName: String, toolInput: [String: Any]) -> String {
        switch toolName {
        case "Bash":
            return toolInput["command"] as? String ?? ""
        case "Read", "Write", "Edit", "NotebookEdit":
            return toolInput["file_path"] as? String ?? ""
        case "Grep", "Glob":
            return toolInput["pattern"] as? String ?? ""
        case "Task":
            return parallelTaskLabel(from: toolInput)
        case "WebFetch":
            return toolInput["url"] as? String ?? ""
        case "WebSearch":
            return toolInput["query"] as? String ?? ""
        default:
            return ""
        }
    }

    private func registerParallelTask(toolUseId: String, input: [String: Any]) -> String {
        let label = parallelTaskLabel(from: input)
        let assigneeId = parallelTaskAssigneeId(seed: toolUseId)

        if let index = parallelTasks.firstIndex(where: { $0.id == toolUseId }) {
            parallelTasks[index].state = .running
            return parallelTasks[index].label
        }

        parallelTasks.append(
            ParallelTaskRecord(
                id: toolUseId,
                label: label,
                assigneeCharacterId: assigneeId,
                state: .running
            )
        )
        return label
    }

    private func updateParallelTask(toolUseId: String, succeeded: Bool) {
        guard let index = parallelTasks.firstIndex(where: { $0.id == toolUseId }) else { return }
        parallelTasks[index].state = succeeded ? .completed : .failed
    }

    private func finalizeParallelTasks(as state: ParallelTaskState) {
        guard parallelTasks.contains(where: { $0.state == .running }) else { return }
        parallelTasks = parallelTasks.map { task in
            guard task.state == .running else { return task }
            var updated = task
            updated.state = state
            return updated
        }
    }

    private func parallelTaskLabel(from input: [String: Any]) -> String {
        let candidates: [String?] = [
            input["description"] as? String,
            input["subtask"] as? String,
            input["title"] as? String,
            input["name"] as? String,
            input["prompt"] as? String
        ]

        for candidate in candidates {
            guard let candidate else { continue }
            let cleaned = candidate
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleaned.isEmpty {
                return String(cleaned.prefix(18))
            }
        }

        return NSLocalizedString("tab.parallel.task", comment: "")
    }

    private func parallelTaskAssigneeId(seed: String) -> String {
        let preferredPool = Self.hiredCharactersProvider().filter {
            !$0.isOnVacation && $0.id != characterId
        }
        let pool = preferredPool

        guard !pool.isEmpty else {
            return characterId ?? "parallel-\(id)"
        }

        let alreadyUsed = Set(parallelTasks.map(\.assigneeCharacterId))
        let available = pool.filter { !alreadyUsed.contains($0.id) }
        let effectivePool = available.isEmpty ? pool : available
        let hash = Int(UInt(bitPattern: seed.hashValue) % UInt(effectivePool.count))
        return effectivePool[hash].id
    }

    // MARK: - Block Management

    private func shouldMergeBlock(existing: StreamBlock.BlockType, new: StreamBlock.BlockType) -> Bool {
        switch (existing, new) {
        case (.toolOutput, .toolOutput), (.toolError, .toolError):
            return true
        default:
            return false
        }
    }

    @discardableResult
    public func appendBlock(_ type: StreamBlock.BlockType, content: String = "") -> StreamBlock {
        if let lastIndex = blocks.indices.last,
           !blocks[lastIndex].isComplete,
           shouldMergeBlock(existing: blocks[lastIndex].blockType, new: type),
           blocks[lastIndex].content.count < 50000 {  // Prevent unbounded growth
            blocks[lastIndex].content += "\n" + content
            return blocks[lastIndex]
        }
        let block = StreamBlock(type: type, content: content)
        blocks.append(block)
        trimBlocksIfNeeded()
        return block
    }

    public var isAutomationTab: Bool {
        automationSourceTabId != nil
    }

    public func cancelProcessing() {
        if isRawMode {
            // Raw mode: Ctrl+C 전송 + 상태 리셋
            sendRawSignal(3) // ETX (Ctrl+C)
            isProcessing = false
            claudeActivity = .idle
            return
        }

        // 파이프 핸들러 즉시 정리 (메인 스레드 블로킹 방지)
        currentOutPipe?.fileHandleForReading.readabilityHandler = nil
        currentErrPipe?.fileHandleForReading.readabilityHandler = nil
        currentOutPipe = nil
        currentErrPipe = nil

        if let proc = currentProcess {
            let pid = proc.processIdentifier
            let procId = ObjectIdentifier(proc)
            cancelledProcessIds.insert(procId)

            // SIGTERM 먼저 전송
            proc.terminate()

            // 1초 후 SIGKILL 후속 (forceStop과 동일 패턴)
            DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
                if proc.isRunning {
                    kill(-pid, SIGKILL)
                    kill(pid, SIGKILL)
                }
            }
        }
        currentProcess = nil
        isProcessing = false; claudeActivity = .idle
        finalizeParallelTasks(as: .failed)
        appendBlock(.status(message: NSLocalizedString("tab.cancelled", comment: "")))
    }

    public func startSleepWork(task: String, tokenBudget: Int?) {
        sleepWorkTask = task
        sleepWorkTokenBudget = tokenBudget
        sleepWorkStartTokens = tokensUsed
        sleepWorkCompleted = false
        sleepWorkExceeded = false
        AuditLog.shared.log(.sleepWorkStart, tabId: id, projectName: projectName, detail: "\(NSLocalizedString("models.budget.label", comment: "")): \(tokenBudget.map { "\($0) tokens" } ?? NSLocalizedString("models.budget.unlimited", comment: ""))")
        sendPrompt(task)
    }

    public func forceStop() {
        // Raw mode PTY 정리
        if isRawMode && rawMasterFD >= 0 {
            close(rawMasterFD)
            rawMasterFD = -1
            isRawMode = false
        }

        // 파이프 핸들러 즉시 정리
        currentOutPipe?.fileHandleForReading.readabilityHandler = nil
        currentErrPipe?.fileHandleForReading.readabilityHandler = nil
        currentOutPipe = nil
        currentErrPipe = nil

        if let proc = currentProcess {
            let procId = ObjectIdentifier(proc)
            cancelledProcessIds.insert(procId)

            if proc.isRunning {
                proc.terminate()
                let pid = proc.processIdentifier
                DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
                    if proc.isRunning {
                        // 프로세스 그룹 전체에 SIGKILL (자식 프로세스 포함)
                        kill(-pid, SIGKILL)
                        kill(pid, SIGKILL)
                    }
                }
            }
        }
        currentProcess = nil
        isProcessing = false; claudeActivity = .idle; isRunning = false
        finalizeParallelTasks(as: .failed)
        appendBlock(.status(message: NSLocalizedString("tab.force.stopped", comment: "")))
    }

    /// 작업을 강제 중지하고 git 변경사항을 작업 전 상태로 롤백
    public func cancelAndRevert() {
        forceStop()
        let recoveryBundleURL = SessionStore.shared.writeRecoveryBundle(for: self, reason: "작업 취소 전 변경사항 백업")
        guard gitInfo.isGitRepo else { return }
        let p = projectPath
        // 작업 중 변경된 파일만 복원
        let changedPaths = Set(fileChanges.map(\.path))
        for filePath in changedPaths {
            _ = Self.shellSync("git -C \"\(p)\" checkout -- \"\(filePath)\" 2>/dev/null")
        }
        // 새로 생성된 파일 (Write action) 삭제
        let newFiles = fileChanges.filter { $0.action == "Write" }.map(\.path)
        for filePath in newFiles {
            _ = Self.shellSync("git -C \"\(p)\" clean -f -- \"\(filePath)\" 2>/dev/null")
        }
        if let recoveryBundleURL {
            appendBlock(.status(message: NSLocalizedString("tab.cancel.revert.done", comment: "")), content: String(format: NSLocalizedString("tab.cancel.revert.backup", comment: ""), recoveryBundleURL.path))
        } else {
            appendBlock(.status(message: NSLocalizedString("tab.cancel.revert.done", comment: "")))
        }
    }

    public func clearBlocks() { blocks.removeAll() }

    // MARK: - 프롬프트 히스토리 (되돌리기)

    private func finalizePromptHistory() {
        guard !promptHistory.isEmpty else { return }
        let lastIndex = promptHistory.count - 1
        let changesForThisPrompt = Array(fileChanges.suffix(from: min(pendingHistoryFileChangeStartIndex, fileChanges.count)))
        promptHistory[lastIndex].fileChanges = changesForThisPrompt
        promptHistory[lastIndex].isCompleted = true
        // 히스토리 100개 제한
        if promptHistory.count > 100 {
            promptHistory.removeFirst(promptHistory.count - 100)
        }
        objectWillChange.send()
    }

    public func revertToBeforePrompt(_ entry: PromptHistoryEntry) {
        guard let commitHash = entry.gitCommitHashBefore, gitInfo.isGitRepo else {
            appendBlock(.status(message: NSLocalizedString("history.no.git.diff", comment: "")))
            return
        }
        let p = projectPath
        let escapedHash = shellEscape(commitHash)
        for file in entry.fileChanges where file.action == "Write" || file.action == "Edit" {
            _ = Self.shellSync("git -C \"\(p)\" checkout \(escapedHash) -- \(shellEscape(file.path)) 2>/dev/null")
        }
        // 새로 생성된 파일 삭제
        let newFiles = entry.fileChanges.filter { $0.action == "Write" }
        for file in newFiles {
            _ = Self.shellSync("git -C \"\(p)\" clean -f -- \(shellEscape(file.path)) 2>/dev/null")
        }
        appendBlock(.status(message: NSLocalizedString("history.reverted", comment: "")))
        refreshGitInfo()
    }

    public func loadDiffForHistoryEntry(_ entry: PromptHistoryEntry) -> String {
        guard let before = entry.gitCommitHashBefore else {
            // git 커밋이 없으면 변경된 파일 목록만 반환
            if entry.fileChanges.isEmpty { return NSLocalizedString("history.no.git.diff", comment: "") }
            return entry.fileChanges.map { "\($0.action): \($0.path)" }.joined(separator: "\n")
        }
        let p = projectPath
        // 현재 워킹 트리와 before 커밋 사이의 diff (인젝션 방지)
        let escapedHash = shellEscape(before)
        let escapedPaths = entry.fileChanges.map { shellEscape($0.path) }.joined(separator: " ")
        let diff = Self.shellSync("git -C \"\(p)\" diff \(escapedHash) -- \(escapedPaths) 2>/dev/null")
        if let diff = diff, !diff.isEmpty { return diff }
        // diff가 비어있으면 파일 목록 반환
        if entry.fileChanges.isEmpty { return NSLocalizedString("history.no.git.diff", comment: "") }
        return entry.fileChanges.map { "\($0.action): \($0.path)" }.joined(separator: "\n")
    }

    private static let maxTimelineEvents = 500

    private func trimTimelineIfNeeded() {
        if timeline.count > Self.maxTimelineEvents {
            timeline.removeFirst(timeline.count - Self.maxTimelineEvents)
        }
    }

    private func trimBlocksIfNeeded() {
        let overflow = blocks.count - Self.maxRetainedBlocks
        guard overflow > 0 else { return }

        let preserveSessionStart: Bool
        if let first = blocks.first, case .sessionStart = first.blockType {
            preserveSessionStart = true
        } else {
            preserveSessionStart = false
        }

        let removalStart = preserveSessionStart ? 1 : 0
        let removableCount = min(overflow, max(0, blocks.count - removalStart))
        guard removableCount > 0 else { return }

        let removalEnd = removalStart + removableCount
        blocks.removeSubrange(removalStart..<removalEnd)

        if let activeToolBlockIndex {
            if activeToolBlockIndex < removalEnd {
                self.activeToolBlockIndex = nil
            } else {
                self.activeToolBlockIndex = activeToolBlockIndex - removableCount
            }
        }
    }

    private func recordFileChange(path: String, action: String) {
        let record = FileChangeRecord(
            path: path,
            fileName: (path as NSString).lastPathComponent,
            action: action,
            timestamp: Date()
        )

        if let last = fileChanges.last,
           last.path == record.path,
           last.action == record.action {
            fileChanges[fileChanges.count - 1] = record
        } else {
            fileChanges.append(record)
        }

        let overflow = fileChanges.count - Self.maxRetainedFileChanges
        if overflow > 0 {
            fileChanges.removeFirst(overflow)
        }
    }

    // Legacy compat
    public func send(_ text: String) { sendPrompt(text) }
    public func sendCommand(_ command: String) { sendPrompt(command) }
    public func sendKey(_ key: UInt8) { if key == 3 { cancelProcessing() } }
    public func stop() { cancelProcessing(); isRunning = false }

    // MARK: - Notifications

    private func sendCompletionNotification() {
        let content = UNMutableNotificationContent()
        content.title = "✅ \(workerName) — \(projectName) 완료"

        let elapsed = Int(Date().timeIntervalSince(startTime))
        let timeStr: String
        if elapsed < 60 { timeStr = String(format: NSLocalizedString("time.seconds", comment: ""), elapsed) }
        else if elapsed < 3600 { timeStr = String(format: NSLocalizedString("time.minutes.seconds", comment: ""), elapsed / 60, elapsed % 60) }
        else { timeStr = String(format: NSLocalizedString("time.hours.minutes", comment: ""), elapsed / 3600, (elapsed % 3600) / 60) }

        let fileCount = Set(fileChanges.map(\.fileName)).count
        var details: [String] = []
        details.append("⏱ \(timeStr)")
        if totalCost > 0 { details.append("💰 $\(String(format: "%.4f", totalCost))") }
        if tokensUsed > 0 { details.append("🔤 \(tokensUsed >= 1000 ? String(format: "%.1fk", Double(tokensUsed)/1000) : "\(tokensUsed)") tokens") }
        if fileCount > 0 { details.append(String(format: "📄 " + NSLocalizedString("notif.files.modified", comment: ""), fileCount)) }
        if commandCount > 0 { details.append(String(format: "⚙ " + NSLocalizedString("notif.commands", comment: ""), commandCount)) }
        if errorCount > 0 { details.append(String(format: "⚠ " + NSLocalizedString("notif.errors", comment: ""), errorCount)) }

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

    public func refreshGitInfo() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            let p = self.projectPath
            let br = Self.shellSync("git -C \"\(p)\" branch --show-current 2>/dev/null")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let ch = Self.shellSync("git -C \"\(p)\" status --porcelain 2>/dev/null")?.components(separatedBy: "\n").filter { !$0.isEmpty }.count ?? 0
            let log = Self.shellSync("git -C \"\(p)\" log -1 --format='%s|||%cr' 2>/dev/null")?.trimmingCharacters(in: .whitespacesAndNewlines)
            var msg = ""; var age = ""
            if let l = log { let pp = l.components(separatedBy: "|||"); if pp.count >= 2 { msg = pp[0]; age = pp[1] } }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.gitInfo = GitInfo(branch: br, changedFiles: ch, lastCommit: String(msg.prefix(40)), lastCommitAge: age, isGitRepo: !br.isEmpty)
                self.branch = br
            }
        }
    }

    public func generateSummary() {
        let files = blocks.compactMap { b -> String? in
            if case .fileChange(let path, _) = b.blockType { return (path as NSString).lastPathComponent }
            return nil
        }
        summary = SessionSummary(filesModified: Array(Set(files)), duration: Date().timeIntervalSince(startTime),
                                 tokenCount: tokensUsed, cost: totalCost, commandCount: commandCount, errorCount: errorCount, timestamp: Date())
    }

    public func exportLog() -> URL? {
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

    private func resolvedExecutableCommand(for provider: AgentProvider) -> String {
        let checker = provider.installChecker
        checker.check(force: true)
        let executablePath = checker.path.trimmingCharacters(in: .whitespacesAndNewlines)
        let executable = executablePath.isEmpty ? provider.executableName : executablePath
        return shellEscape(executable)
    }

    private func effectiveAllowedTools() -> String {
        let raw = allowedTools
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if shouldBlockParallelSubagents {
            return raw.filter { $0.caseInsensitiveCompare("Task") != .orderedSame }.joined(separator: ",")
        }
        return raw.joined(separator: ",")
    }

    private func effectiveDisallowedTools() -> String {
        var raw = disallowedTools
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if shouldBlockParallelSubagents &&
            !raw.contains(where: { $0.caseInsensitiveCompare("Task") == .orderedSame }) {
            raw.append("Task")
        }

        return raw.joined(separator: ",")
    }

    private var shouldBlockParallelSubagents: Bool {
        isAutomationTab || !AppSettings.shared.allowParallelSubagents
    }

    private func enforceTokenBudgetIfNeeded() {
        // 슬립워크 예산 체크
        if let budget = sleepWorkTokenBudget, sleepWorkTask != nil {
            let used = tokensUsed - sleepWorkStartTokens
            if used >= budget * 2 {
                sleepWorkExceeded = true
                sleepWorkTask = nil
                budgetStopIssued = true
                currentProcess?.terminate()
                currentProcess = nil
                isProcessing = false
                claudeActivity = .idle
                AuditLog.shared.log(.sleepWorkEnd, tabId: id, projectName: projectName, detail: "예산 2배 초과로 중단: \(used)/\(budget) tokens")
                appendBlock(.status(message: NSLocalizedString("tab.sleepwork.stopped", comment: "")), content: NSLocalizedString("tab.sleepwork.stopped.detail", comment: ""))
                return
            }
        }

        // 비용 경고 체크 (80% 도달)
        if let warning = TokenTracker.shared.costWarningNeeded(tabCost: totalCost) {
            if dangerousCommandWarning == nil {  // 다른 경고가 없을 때만
                sensitiveFileWarning = warning  // 임시로 sensitiveFileWarning 재활용
            }
        }

        guard isProcessing, !budgetStopIssued else { return }
        guard let reason = TokenTracker.shared.runningStopReason(
            isAutomation: isAutomationTab,
            currentTabTokens: tokensUsed,
            tokenLimit: tokenLimit
        ) else { return }

        budgetStopIssued = true
        currentProcess?.terminate()
        currentProcess = nil
        isProcessing = false
        claudeActivity = .error
        PluginHost.shared.fireEvent(.onSessionError, context: ["tabId": id])
        finalizeParallelTasks(as: .failed)
        appendBlock(.status(message: NSLocalizedString("tab.token.protection.stopped", comment: "")), content: reason)
    }

    /// Cached login shell PATH (resolved once at first call)
    private static var cachedLoginPath: String?
    private static var loginPathChecked = false

    /// GUI 앱에서도 claude CLI를 찾을 수 있도록 PATH를 완전히 구성
    public static func buildFullPATH() -> String {
        let home = NSHomeDirectory()
        var paths: [String] = []

        // Homebrew (Apple Silicon + Intel)
        paths += ["/opt/homebrew/bin", "/opt/homebrew/sbin", "/usr/local/bin", "/usr/local/sbin"]

        // npm global 설치 경로들
        paths += ["/usr/local/opt/node/bin", home + "/.npm-global/bin"]

        // Codex Desktop bundle CLI
        paths.append("/Applications/Codex.app/Contents/Resources")

        // nvm 설치 경로 — glob 직접 해결
        let nvmBase = home + "/.nvm/versions/node"
        if let nodeDirs = try? FileManager.default.contentsOfDirectory(atPath: nvmBase) {
            for dir in nodeDirs.sorted().reversed() {
                let binPath = nvmBase + "/" + dir + "/bin"
                if FileManager.default.fileExists(atPath: binPath) {
                    paths.append(binPath)
                }
            }
        }

        // fnm 설치 경로
        let fnmBase = home + "/Library/Application Support/fnm/node-versions"
        if let fnmDirs = try? FileManager.default.contentsOfDirectory(atPath: fnmBase) {
            for dir in fnmDirs.sorted().reversed() {
                let binPath = fnmBase + "/" + dir + "/installation/bin"
                if FileManager.default.fileExists(atPath: binPath) {
                    paths.append(binPath)
                }
            }
        }

        // volta
        paths.append(home + "/.volta/bin")

        // pnpm
        paths.append(home + "/Library/pnpm")
        paths.append(home + "/.local/share/pnpm")

        // Bun runtime
        paths.append(home + "/.bun/bin")

        // Rust / Cargo
        paths.append(home + "/.cargo/bin")

        // Deno
        paths.append(home + "/.deno/bin")

        // MacPorts
        paths.append("/opt/local/bin")

        // 일반적인 경로들
        paths += [home + "/.local/bin", home + "/bin", "/usr/bin", "/bin", "/usr/sbin", "/sbin"]

        // 기존 PATH 유지
        let existing = ProcessInfo.processInfo.environment["PATH"] ?? ""
        if !existing.isEmpty { paths.append(existing) }

        // Merge paths from login shell (async, non-blocking)
        // 로그인 셸 PATH는 백그라운드에서 비동기로 가져옴 — 메인 스레드 블로킹 방지
        if !loginPathChecked {
            loginPathChecked = true
            DispatchQueue.global(qos: .utility).async {
                let result = shellSyncLoginWithTimeout("echo $PATH", timeout: 3)?.trimmingCharacters(in: .whitespacesAndNewlines)
                if let r = result, !r.isEmpty {
                    cachedLoginPath = r
                }
            }
        }
        if let loginPath = cachedLoginPath, !loginPath.isEmpty {
            paths.append(loginPath)
        }

        return paths.joined(separator: ":")
    }

    public static func shellSync(_ command: String) -> String? {
        let p = Process(); let pipe = Pipe()
        p.standardOutput = pipe; p.standardError = FileHandle.nullDevice
        p.executableURL = URL(fileURLWithPath: "/bin/zsh")
        p.arguments = ["-f", "-c", command]
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = buildFullPATH()
        p.environment = env
        do { try p.run(); p.waitUntilExit()
            let d = pipe.fileHandleForReading.readDataToEndOfFile()
            let o = String(data: d, encoding: .utf8); return o?.isEmpty == true ? nil : o
        } catch { return nil }
    }

    /// Login shell with timeout — prevents hang if user's .zshrc is slow or broken
    public static func shellSyncLoginWithTimeout(_ command: String, timeout: TimeInterval = 3) -> String? {
        let p = Process(); let pipe = Pipe()
        p.standardOutput = pipe; p.standardError = FileHandle.nullDevice
        p.executableURL = URL(fileURLWithPath: "/bin/zsh")
        p.arguments = ["-l", "-c", command]
        p.environment = ProcessInfo.processInfo.environment
        do {
            try p.run()
            // 타임아웃: 지정 시간 내에 끝나지 않으면 강제 종료
            let deadline = Date().addingTimeInterval(timeout)
            while p.isRunning && Date() < deadline {
                Thread.sleep(forTimeInterval: 0.05)
            }
            if p.isRunning {
                p.terminate()
                return nil
            }
            let d = pipe.fileHandleForReading.readDataToEndOfFile()
            let o = String(data: d, encoding: .utf8)
            return o?.isEmpty == true ? nil : o
        } catch { return nil }
    }

    // MARK: - Chrome Window Capture (ScreenCaptureKit)

    public static func captureBrowserWindow() async -> CGImage? {
        // Check screen recording permission before attempting capture
        // to avoid repeatedly triggering the system permission dialog
        guard CGPreflightScreenCaptureAccess() else { return nil }

        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            let browserApps = ["Google Chrome", "Arc", "Safari", "Microsoft Edge", "Firefox", "Brave Browser"]

            // 브라우저 윈도우 찾기
            for window in content.windows {
                guard let app = window.owningApplication,
                      browserApps.contains(app.applicationName),
                      window.frame.width > 200 && window.frame.height > 200 else { continue }

                let filter = SCContentFilter(desktopIndependentWindow: window)
                let config = SCStreamConfiguration()
                config.width = Int(window.frame.width / 4)   // 축소 (성능)
                config.height = Int(window.frame.height / 4)
                config.capturesAudio = false
                config.showsCursor = false

                let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
                return image
            }
        } catch {
            // 권한 없거나 에러 → 무시
        }
        return nil
    }
}

extension TerminalTab {
    public var statusPresentation: TabStatusPresentation {
        if startError != nil || claudeActivity == .error {
            return TabStatusPresentation(category: .attention, label: NSLocalizedString("status.error", comment: ""), symbol: "exclamationmark.triangle.fill", tint: Theme.red, sortPriority: 0)
        }
        if isCompleted {
            return TabStatusPresentation(category: .completed, label: NSLocalizedString("status.completed", comment: ""), symbol: "checkmark.circle.fill", tint: Theme.green, sortPriority: 3)
        }
        if isProcessing {
            switch claudeActivity {
            case .thinking:
                return TabStatusPresentation(category: .processing, label: NSLocalizedString("status.thinking", comment: ""), symbol: "brain.head.profile", tint: Theme.purple, sortPriority: 1)
            case .reading:
                return TabStatusPresentation(category: .processing, label: NSLocalizedString("status.reading", comment: ""), symbol: "book.fill", tint: Theme.accent, sortPriority: 1)
            case .writing:
                return TabStatusPresentation(category: .processing, label: NSLocalizedString("status.writing", comment: ""), symbol: "square.and.pencil", tint: Theme.green, sortPriority: 1)
            case .searching:
                return TabStatusPresentation(category: .processing, label: NSLocalizedString("status.searching", comment: ""), symbol: "magnifyingglass", tint: Theme.cyan, sortPriority: 1)
            case .running:
                return TabStatusPresentation(category: .processing, label: NSLocalizedString("status.running", comment: ""), symbol: "terminal.fill", tint: Theme.yellow, sortPriority: 1)
            case .done:
                return TabStatusPresentation(category: .completed, label: NSLocalizedString("status.completed", comment: ""), symbol: "checkmark.circle.fill", tint: Theme.green, sortPriority: 3)
            case .error:
                return TabStatusPresentation(category: .attention, label: NSLocalizedString("status.error", comment: ""), symbol: "exclamationmark.triangle.fill", tint: Theme.red, sortPriority: 0)
            case .idle:
                return TabStatusPresentation(category: .active, label: NSLocalizedString("status.active", comment: ""), symbol: "bolt.circle.fill", tint: Theme.green.opacity(0.85), sortPriority: 2)
            }
        }
        if isRunning {
            return TabStatusPresentation(category: .active, label: "대기", symbol: "pause.circle.fill", tint: Theme.green.opacity(0.75), sortPriority: 2)
        }
        return TabStatusPresentation(category: .idle, label: NSLocalizedString("status.idle", comment: ""), symbol: "moon.zzz.fill", tint: Theme.textDim, sortPriority: 4)
    }

    public var sidebarSearchTokens: String {
        [
            projectName,
            projectPath,
            workerName,
            branch ?? "",
            statusPresentation.label,
            claudeActivity.rawValue,
            gitInfo.branch
        ]
        .joined(separator: " ")
        .lowercased()
    }

    public var assignedCharacter: WorkerCharacter? {
        Self.characterLookup(characterId ?? "")
    }

    public var workerJob: WorkerJob {
        assignedCharacter?.jobRole ?? .developer
    }

    public var isWorkerOnVacation: Bool {
        assignedCharacter?.isOnVacation ?? false
    }

    public var hasCodeChanges: Bool {
        fileChanges.contains { $0.action == "Write" || $0.action == "Edit" }
    }

    public var latestUserPromptText: String? {
        blocks.reversed().first {
            if case .userPrompt = $0.blockType { return true }
            return false
        }?.content
    }

    public var workflowRequirementText: String {
        let source = workflowSourceRequest.trimmingCharacters(in: .whitespacesAndNewlines)
        if !source.isEmpty { return source }
        return latestUserPromptText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    public var lastCompletionSummary: String {
        lastResultText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func resetWorkflowTracking(request: String) {
        workflowSourceRequest = request
        workflowPlanSummary = ""
        workflowDesignSummary = ""
        workflowReviewSummary = ""
        workflowQASummary = ""
        workflowSRESummary = ""
        automationReportPath = nil
        workflowStages.removeAll()
        reviewerAttemptCount = 0
        qaAttemptCount = 0
        automatedRevisionCount = 0
    }

    public func upsertWorkflowStage(
        role: WorkerJob,
        workerName: String,
        assigneeCharacterId: String?,
        state: WorkflowStageState,
        handoffLabel: String,
        detail: String
    ) {
        let effectiveAssignee = assigneeCharacterId ?? characterId ?? "workflow-\(role.rawValue)-\(id)"
        let stageId = role.rawValue
        if let index = workflowStages.firstIndex(where: { $0.id == stageId }) {
            workflowStages[index].workerName = workerName
            workflowStages[index].assigneeCharacterId = effectiveAssignee
            workflowStages[index].state = state
            workflowStages[index].handoffLabel = handoffLabel
            workflowStages[index].detail = detail
            workflowStages[index].updatedAt = Date()
            return
        }

        workflowStages.append(
            WorkflowStageRecord(
                id: stageId,
                role: role,
                workerName: workerName,
                assigneeCharacterId: effectiveAssignee,
                state: state,
                handoffLabel: handoffLabel,
                detail: detail,
                updatedAt: Date()
            )
        )
    }

    public func updateWorkflowStage(
        role: WorkerJob,
        state: WorkflowStageState,
        detail: String? = nil,
        handoffLabel: String? = nil
    ) {
        guard let index = workflowStages.firstIndex(where: { $0.role == role }) else { return }
        workflowStages[index].state = state
        if let detail {
            workflowStages[index].detail = detail
        }
        if let handoffLabel {
            workflowStages[index].handoffLabel = handoffLabel
        }
        workflowStages[index].updatedAt = Date()
    }

    private func workflowStageOrder(for role: WorkerJob) -> Int {
        switch role {
        case .planner: return 0
        case .designer: return 1
        case .developer: return 2
        case .reviewer: return 3
        case .qa: return 4
        case .reporter: return 5
        case .sre: return 6
        case .boss: return 7
        }
    }

    public var workflowTimelineStages: [WorkflowStageRecord] {
        workflowStages.sorted { lhs, rhs in
            let lhsOrder = workflowStageOrder(for: lhs.role)
            let rhsOrder = workflowStageOrder(for: rhs.role)
            if lhsOrder != rhsOrder { return lhsOrder < rhsOrder }
            return lhs.updatedAt < rhs.updatedAt
        }
    }

    private var workflowBubbleTasks: [ParallelTaskRecord] {
        let visibleStages = workflowTimelineStages.filter { $0.state != .skipped }
        guard !visibleStages.isEmpty else { return [] }

        let active = visibleStages.filter { $0.state == .running || $0.state == .failed }
        let completed = visibleStages
            .filter { $0.state == .completed }
            .sorted { $0.updatedAt > $1.updatedAt }
        let queued = visibleStages.filter { $0.state == .queued }

        let ordered = active + completed + queued
        return Array(ordered.prefix(4)).map { stage in
            let parallelState: ParallelTaskState
            switch stage.state {
            case .failed:
                parallelState = .failed
            case .completed:
                parallelState = .completed
            case .queued, .running, .skipped:
                parallelState = .running
            }
            return ParallelTaskRecord(
                id: "workflow-\(stage.id)",
                label: stage.workerName,
                assigneeCharacterId: stage.assigneeCharacterId,
                state: parallelState
            )
        }
    }

    public var officeParallelTasks: [ParallelTaskRecord] {
        let workflowTasks = workflowBubbleTasks
        if workflowTasks.isEmpty {
            return Array(parallelTasks.prefix(4))
        }

        let extraTasks = parallelTasks.filter { task in
            !workflowTasks.contains(where: { $0.assigneeCharacterId == task.assigneeCharacterId && $0.label == task.label })
        }
        return Array((workflowTasks + extraTasks).prefix(4))
    }

    public var workflowProgressSummary: String? {
        guard !workflowStages.isEmpty else { return nil }

        if let running = workflowTimelineStages.last(where: { $0.state == .running }) {
            return "\(running.role.displayName) 진행 중 · \(running.workerName)"
        }
        if let failed = workflowTimelineStages.last(where: { $0.state == .failed }) {
            return "\(failed.role.displayName) 피드백 반영 중"
        }
        if let completed = workflowTimelineStages.last(where: { $0.state == .completed }) {
            return "\(completed.role.displayName) 완료"
        }
        if let queued = workflowTimelineStages.last(where: { $0.state == .queued }) {
            return "\(queued.role.displayName) 대기 중"
        }
        return nil
    }

    public var officeParallelSummary: String? {
        if let workflowSummary = workflowProgressSummary {
            return workflowSummary
        }

        guard !parallelTasks.isEmpty else { return nil }
        let completed = parallelTasks.filter { $0.state == .completed }.count
        let failed = parallelTasks.filter { $0.state == .failed }.count
        let running = parallelTasks.filter { $0.state == .running }.count

        if running > 0 {
            return "병렬 \(completed)/\(parallelTasks.count) 완료"
        }
        if failed > 0 {
            return "병렬 \(failed)개 실패"
        }
        return "병렬 작업 완료"
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - Claude Usage Fetcher (실제 Claude 플랜 사용량 조회)
// ═══════════════════════════════════════════════════════

public enum ClaudeUsageFetcher {
    /// Claude CLI를 인터랙티브 PTY로 실행하여 /usage 결과를 캡처
    public static func fetch() -> String {
        guard let claudePath = findClaude() else {
            return "❌ Claude CLI를 찾을 수 없습니다."
        }

        var masterFD: Int32 = 0
        var slaveFD: Int32 = 0
        guard openpty(&masterFD, &slaveFD, nil, nil, nil) == 0 else {
            return "❌ PTY 열기 실패"
        }

        // 터미널 크기 설정 (충분히 넓게)
        var winSize = winsize(ws_row: 50, ws_col: 120, ws_xpixel: 0, ws_ypixel: 0)
        ioctl(masterFD, TIOCSWINSZ, &winSize)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: claudePath)
        process.environment = ProcessInfo.processInfo.environment
        process.environment?["PATH"] = TerminalTab.buildFullPATH()
        process.environment?["TERM"] = "xterm-256color"
        process.environment?["COLUMNS"] = "120"
        process.environment?["LINES"] = "50"

        let slaveHandle = FileHandle(fileDescriptor: slaveFD, closeOnDealloc: false)
        process.standardInput = slaveHandle
        process.standardOutput = slaveHandle
        process.standardError = slaveHandle

        do { try process.launch() } catch {
            close(masterFD); close(slaveFD)
            return "❌ Claude 실행 실패: \(error.localizedDescription)"
        }
        close(slaveFD)

        defer {
            process.terminate()
            close(masterFD)
        }

        // 시작 대기
        Thread.sleep(forTimeInterval: 5.0)
        drainFD(masterFD)

        // /usage 입력 (Tab으로 자동완성 확정)
        writeSlow(masterFD, "/usage")
        Thread.sleep(forTimeInterval: 0.3)
        _ = Darwin.write(masterFD, "\r", 1)  // Enter

        // 데이터 수집 — 최대 15초, "Esc to cancel" 감지 시 조기 종료
        var allData = Data()
        let startTime = Date()
        while Date().timeIntervalSince(startTime) < 15.0 {
            Thread.sleep(forTimeInterval: 0.5)
            var buf = [UInt8](repeating: 0, count: 8192)
            let flags = fcntl(masterFD, F_GETFL)
            fcntl(masterFD, F_SETFL, flags | O_NONBLOCK)
            while true {
                let n = Darwin.read(masterFD, &buf, buf.count)
                if n <= 0 { break }
                allData.append(buf, count: n)
            }
            fcntl(masterFD, F_SETFL, flags)

            let partial = String(data: allData, encoding: .utf8) ?? ""
            if partial.contains("Esc") && partial.contains("cancel") { break }
            if partial.contains("% used") && partial.contains("Reset") { break }
        }

        // 정리
        _ = Darwin.write(masterFD, "\u{1b}", 1) // Esc
        Thread.sleep(forTimeInterval: 0.5)
        _ = Darwin.write(masterFD, "\u{03}", 1) // Ctrl+C
        Thread.sleep(forTimeInterval: 0.3)
        writeSlow(masterFD, "/exit\r")
        Thread.sleep(forTimeInterval: 0.5)

        let raw = String(data: allData, encoding: .utf8) ?? ""
        return parseUsageOutput(raw)
    }

    private static func findClaude() -> String? {
        for dir in TerminalTab.buildFullPATH().split(separator: ":").map(String.init) {
            let p = dir + "/claude"
            if FileManager.default.isExecutableFile(atPath: p) { return p }
        }
        return nil
    }

    private static func writeSlow(_ fd: Int32, _ text: String) {
        for ch in text {
            var c = [UInt8](String(ch).utf8)
            Darwin.write(fd, &c, c.count)
            Thread.sleep(forTimeInterval: 0.04)
        }
    }

    private static func drainFD(_ fd: Int32) {
        let flags = fcntl(fd, F_GETFL)
        fcntl(fd, F_SETFL, flags | O_NONBLOCK)
        var buf = [UInt8](repeating: 0, count: 4096)
        while Darwin.read(fd, &buf, buf.count) > 0 {}
        fcntl(fd, F_SETFL, flags)
    }

    private static func stripANSI(_ raw: String) -> String {
        // 모든 제어 시퀀스를 바이트 레벨에서 제거
        var result = ""
        var i = raw.startIndex
        while i < raw.endIndex {
            let ch = raw[i]
            if ch == "\u{1b}" {
                // ESC 시퀀스 스킵
                let nextIdx = raw.index(after: i)
                guard nextIdx < raw.endIndex else { break }
                i = nextIdx
                let next = raw[i]
                if next == "[" || next == "]" {
                    // CSI / OSC 시퀀스: 종료 문자까지 스킵
                    i = raw.index(after: i)
                    while i < raw.endIndex {
                        let c = raw[i]
                        i = raw.index(after: i)
                        if next == "[" && c.isLetter { break }
                        if next == "]" && (c == "\u{07}" || c == "\u{1b}") { break }
                    }
                } else {
                    // 단일 ESC + 문자
                    let afterNext = raw.index(after: i)
                    guard afterNext <= raw.endIndex else { break }
                    i = afterNext
                }
            } else if ch.asciiValue ?? 32 < 32 && ch != "\n" {
                // 제어 문자 스킵 (\r, \t 등)
                i = raw.index(after: i)
            } else {
                result.append(ch)
                i = raw.index(after: i)
            }
        }
        return result
    }

    private static func parseUsageOutput(_ raw: String) -> String {
        let text = stripANSI(raw)

        // 섹션별 퍼센트 + 리셋 정보 추출
        struct UsageSection {
            let label: String
            let percent: Int
            let resetInfo: String
        }

        let sectionKeys: [(key: String, label: String)] = [
            ("Current session", "현재 세션 (Current Session)"),
            ("Current week (all models)", "이번 주 — 전체 모델 (All Models)"),
            ("Current week (Sonnet only)", "이번 주 — Sonnet 전용"),
            ("Current week (Opus only)", "이번 주 — Opus 전용"),
            ("Current day", "오늘 (Current Day)"),
        ]

        var sections: [UsageSection] = []

        for (key, label) in sectionKeys {
            guard text.contains(key) else { continue }
            // "XX% used" 찾기
            let pctPattern = "(\(NSRegularExpression.escapedPattern(for: key))).*?(\\d+)%\\s*used"
            guard let regex = try? NSRegularExpression(pattern: pctPattern, options: [.dotMatchesLineSeparators]),
                  let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
                  let pctRange = Range(match.range(at: 2), in: text) else { continue }
            let pct = Int(text[pctRange]) ?? 0

            // "Resets ..." 찾기 — key 이후에서 가장 가까운 것
            var resetInfo = ""
            if let keyRange = text.range(of: key) {
                let after = String(text[keyRange.upperBound...])
                let resetPattern = "Resets?\\s+(.+?)(?:\\n|$)"
                if let rRegex = try? NSRegularExpression(pattern: resetPattern),
                   let rMatch = rRegex.firstMatch(in: after, range: NSRange(after.startIndex..., in: after)),
                   let rRange = Range(rMatch.range(at: 1), in: after) {
                    resetInfo = String(after[rRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                    // 쓸데없는 문자 정리
                    resetInfo = resetInfo.replacingOccurrences(of: "[^a-zA-Z0-9:/ ().,]", with: "", options: .regularExpression)
                }
            }

            sections.append(UsageSection(label: label, percent: pct, resetInfo: resetInfo))
        }

        // Extra usage 상태
        var extraInfo = ""
        if text.contains("Extra usage not enabled") {
            extraInfo = "❌ Extra usage 비활성 · /extra-usage로 활성화"
        } else if text.contains("extra usage") || text.contains("Extra usage") {
            if let regex = try? NSRegularExpression(pattern: "Extra usage.*?(\\d+)%", options: [.dotMatchesLineSeparators]),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let pctRange = Range(match.range(at: 1), in: text) {
                extraInfo = "✅ Extra usage 활성: \(text[pctRange])% 사용"
            } else {
                extraInfo = "✅ Extra usage 활성"
            }
        }

        // 파싱 실패 시
        if sections.isEmpty {
            // 원본에서 핵심만 추출
            let cleanLines = text.components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty && $0.count > 3 }
                .filter { !$0.contains("Tips") && !$0.contains("Welcome") && !$0.contains("─") && !$0.contains("╭") && !$0.contains("╰") }
            if cleanLines.isEmpty {
                return "📊 Claude 사용량 조회 실패\n\n터미널에서 직접 /usage를 실행해보세요."
            }
            return "📊 Claude 사용량\n\n" + cleanLines.prefix(15).joined(separator: "\n")
        }

        // 예쁜 결과 조립
        var lines = [
            "📊 Claude 플랜 사용량",
            "══════════════════════════════════════",
        ]

        for s in sections {
            let barLen = 32
            let filled = Int(Double(barLen) * Double(s.percent) / 100.0)
            let bar = String(repeating: "█", count: filled) + String(repeating: "░", count: barLen - filled)
            let color = s.percent >= 80 ? "🔴" : s.percent >= 50 ? "🟡" : "🟢"

            lines.append("")
            lines.append("\(color) \(s.label)")
            lines.append("  \(bar) \(s.percent)% used")
            if !s.resetInfo.isEmpty {
                lines.append("  ⏰ 리셋: \(s.resetInfo)")
            }
        }

        if !extraInfo.isEmpty {
            lines.append("")
            lines.append(extraInfo)
        }

        lines.append("")
        lines.append("══════════════════════════════════════")

        return lines.joined(separator: "\n")
    }
}
