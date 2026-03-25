import SwiftUI
import Darwin
import UserNotifications
import ScreenCaptureKit

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

    static func detect(from value: String) -> ClaudeModel? {
        let lowered = value.lowercased()
        return allCases.first { lowered.contains($0.rawValue) }
    }
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
    case acceptEdits = "acceptEdits"
    case bypassPermissions = "bypassPermissions"
    case auto = "auto"
    case defaultMode = "default"
    case plan = "plan"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .acceptEdits: return "✏️"
        case .bypassPermissions: return "⚡"
        case .auto: return "🤖"
        case .defaultMode: return "🛡️"
        case .plan: return "📋"
        }
    }
    var displayName: String {
        switch self {
        case .acceptEdits: return "수정만 허용"
        case .bypassPermissions: return "전체 허용"
        case .auto: return "자동"
        case .defaultMode: return "기본"
        case .plan: return "계획만"
        }
    }
    var desc: String {
        switch self {
        case .acceptEdits: return "파일 수정 권한 자동 승인"
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

enum ParallelTaskState: String {
    case running
    case completed
    case failed

    var label: String {
        switch self {
        case .running: return "진행"
        case .completed: return "완료"
        case .failed: return "실패"
        }
    }

    var tint: Color {
        switch self {
        case .running: return Theme.cyan
        case .completed: return Theme.green
        case .failed: return Theme.red
        }
    }
}

struct ParallelTaskRecord: Identifiable, Equatable {
    let id: String
    let label: String
    let assigneeCharacterId: String
    var state: ParallelTaskState
}

enum TabStatusCategory: String, CaseIterable {
    case active
    case processing
    case completed
    case attention
    case idle
}

struct TabStatusPresentation {
    let category: TabStatusCategory
    let label: String
    let symbol: String
    let tint: Color
    let sortPriority: Int
}

enum WorkflowStageState: String {
    case queued
    case running
    case completed
    case failed
    case skipped

    var label: String {
        switch self {
        case .queued: return "대기"
        case .running: return "진행"
        case .completed: return "완료"
        case .failed: return "재작업"
        case .skipped: return "건너뜀"
        }
    }

    var tint: Color {
        switch self {
        case .queued: return Theme.textDim
        case .running: return Theme.cyan
        case .completed: return Theme.green
        case .failed: return Theme.red
        case .skipped: return Theme.textSecondary
        }
    }
}

struct WorkflowStageRecord: Identifiable, Equatable {
    let id: String
    let role: WorkerJob
    var workerName: String
    var assigneeCharacterId: String
    var state: WorkflowStageState
    var handoffLabel: String
    var detail: String
    var updatedAt: Date
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
    var isInstalled = false, version = "", path = "", errorInfo = ""
    func check() {
        // 1) Try `which claude` with our enriched PATH
        if let p = TerminalTab.shellSync("which claude 2>/dev/null")?.trimmingCharacters(in: .whitespacesAndNewlines), !p.isEmpty {
            isInstalled = true; path = p
            version = TerminalTab.shellSync("claude --version 2>/dev/null")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return
        }

        // 2) Check well-known installation paths directly
        let home = NSHomeDirectory()
        let knownPaths = [
            "/usr/local/bin/claude",
            "/opt/homebrew/bin/claude",
            home + "/.npm-global/bin/claude",
        ]
        let allPATHDirs = TerminalTab.buildFullPATH().split(separator: ":").map(String.init)
        let allCandidates = knownPaths + allPATHDirs.map { $0 + "/claude" }

        for candidate in allCandidates {
            if FileManager.default.isExecutableFile(atPath: candidate) {
                isInstalled = true; path = candidate
                version = TerminalTab.shellSync("\"\(candidate)\" --version 2>/dev/null")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return
            }
        }

        // 3) Fallback: try login shell with timeout (prevents hang)
        if let p = TerminalTab.shellSyncLoginWithTimeout("which claude 2>/dev/null", timeout: 3)?.trimmingCharacters(in: .whitespacesAndNewlines), !p.isEmpty {
            isInstalled = true; path = p
            version = TerminalTab.shellSyncLoginWithTimeout("\"\(p)\" --version 2>/dev/null", timeout: 3)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return
        }

        // Not found
        isInstalled = false
        errorInfo = "Claude CLI not found. Install with: npm install -g @anthropic-ai/claude-code"
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - Token Tracker (일간/주간 토큰 추적)
// ═══════════════════════════════════════════════════════

class TokenTracker: ObservableObject {
    static let shared = TokenTracker()
    static let recommendedDailyLimit = 500_000
    static let recommendedWeeklyLimit = 2_500_000
    private let saveKey = "WorkManTokenHistory"
    private let automationDailyReserve = 100_000
    private let automationWeeklyReserve = 300_000
    private let globalDailyReserve = 12_000
    private let globalWeeklyReserve = 40_000
    private let emergencyDailyReserve = 6_000
    private let emergencyWeeklyReserve = 20_000
    private let persistenceQueue = DispatchQueue(label: "workman.token-tracker", qos: .utility)
    private var saveWorkItem: DispatchWorkItem?

    struct DayRecord: Codable {
        var date: String // "yyyy-MM-dd"
        var inputTokens: Int
        var outputTokens: Int
        var cost: Double
        var totalTokens: Int { inputTokens + outputTokens }
    }

    @Published var history: [DayRecord] = []

    private var cachedWeekTokens: Int = 0
    private var cachedWeekCost: Double = 0
    private var cachedBillingTokens: Int = 0
    private var cachedBillingCost: Double = 0
    private var cacheTimestamp: Date = .distantPast

    // 사용자 설정 한도
    @AppStorage("dailyTokenLimit") var dailyTokenLimit: Int = TokenTracker.recommendedDailyLimit
    @AppStorage("weeklyTokenLimit") var weeklyTokenLimit: Int = TokenTracker.recommendedWeeklyLimit

    private var dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    init() { load() }

    private var todayKey: String { dateFormatter.string(from: Date()) }

    // MARK: - Record

    func recordTokens(input: Int, output: Int) {
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

    func recordCost(_ cost: Double) {
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

    var todayRecord: DayRecord {
        history.first(where: { $0.date == todayKey }) ?? DayRecord(date: todayKey, inputTokens: 0, outputTokens: 0, cost: 0)
    }

    var todayTokens: Int { todayRecord.totalTokens }
    var todayCost: Double { todayRecord.cost }

    var weekTokens: Int {
        refreshCacheIfNeeded()
        return cachedWeekTokens
    }

    var weekCost: Double {
        refreshCacheIfNeeded()
        return cachedWeekCost
    }

    // ── 결제 기간 (Billing Period) 사용량 ──

    /// 결제일 기준 이번 달 시작일
    var billingPeriodStart: Date {
        let billingDay = max(1, AppSettings.shared.billingDay)
        let cal = Calendar.current
        let now = Date()
        let todayDay = cal.component(.day, from: now)
        let year = cal.component(.year, from: now)
        let month = cal.component(.month, from: now)

        if billingDay <= 0 {
            // 미설정이면 이번 달 1일부터
            return cal.date(from: DateComponents(year: year, month: month, day: 1))!
        }
        if todayDay >= billingDay {
            // 이번 달 결제일 이후
            return cal.date(from: DateComponents(year: year, month: month, day: billingDay))!
        } else {
            // 아직 결제일 전 → 지난달 결제일부터
            let lastMonth = cal.date(byAdding: .month, value: -1, to: now)!
            let lmYear = cal.component(.year, from: lastMonth)
            let lmMonth = cal.component(.month, from: lastMonth)
            let maxDay = cal.range(of: .day, in: .month, for: lastMonth)!.upperBound - 1
            return cal.date(from: DateComponents(year: lmYear, month: lmMonth, day: min(billingDay, maxDay)))!
        }
    }

    var billingPeriodTokens: Int {
        refreshCacheIfNeeded()
        return cachedBillingTokens
    }

    var billingPeriodCost: Double {
        refreshCacheIfNeeded()
        return cachedBillingCost
    }

    private func refreshCacheIfNeeded() {
        let now = Date()
        guard now.timeIntervalSince(cacheTimestamp) > 30 else { return }
        cacheTimestamp = now

        let cal = Calendar.current
        let weekAgo = cal.date(byAdding: .day, value: -7, to: now)!
        let weekRecords = history.filter { dateFormatter.date(from: $0.date).map { $0 >= weekAgo } ?? false }
        cachedWeekTokens = weekRecords.reduce(0) { $0 + $1.totalTokens }
        cachedWeekCost = weekRecords.reduce(0) { $0 + $1.cost }

        let bStart = billingPeriodStart
        let billingRecords = history.filter { dateFormatter.date(from: $0.date).map { $0 >= bStart } ?? false }
        cachedBillingTokens = billingRecords.reduce(0) { $0 + $1.totalTokens }
        cachedBillingCost = billingRecords.reduce(0) { $0 + $1.cost }
    }

    var billingPeriodDays: Int {
        let cal = Calendar.current
        return cal.dateComponents([.day], from: billingPeriodStart, to: Date()).day ?? 0
    }

    var billingPeriodLabel: String {
        let df = DateFormatter()
        df.dateFormat = "M/d"
        let start = df.string(from: billingPeriodStart)
        let billingDay = max(1, AppSettings.shared.billingDay)
        let cal = Calendar.current
        let nextBilling = cal.date(byAdding: .month, value: 1, to: billingPeriodStart)
            ?? cal.date(byAdding: .day, value: 30, to: billingPeriodStart)!
        let end = df.string(from: cal.date(byAdding: .day, value: -1, to: nextBilling)!)
        return "\(start) ~ \(end)"
    }

    var totalAllTimeTokens: Int {
        history.reduce(0) { $0 + $1.totalTokens }
    }

    var totalAllTimeCost: Double {
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

    var dailyRemaining: Int { max(0, safeDailyLimit - todayTokens) }
    var weeklyRemaining: Int { max(0, safeWeeklyLimit - weekTokens) }

    var dailyUsagePercent: Double { Double(todayTokens) / Double(safeDailyLimit) }
    var weeklyUsagePercent: Double { Double(weekTokens) / Double(safeWeeklyLimit) }

    private func protectionUsageSummary() -> String {
        "오늘 \(formatTokens(todayTokens))/\(formatTokens(safeDailyLimit)), 이번 주 \(formatTokens(weekTokens))/\(formatTokens(safeWeeklyLimit)) 사용 중입니다."
    }

    func startBlockReason(isAutomation: Bool) -> String? {
        if dailyRemaining <= effectiveGlobalDailyReserve ||
            weeklyRemaining <= effectiveGlobalWeeklyReserve ||
            dailyUsagePercent >= 0.985 ||
            weeklyUsagePercent >= 0.985 {
            return "전체 토큰 보호선을 넘겨 새 작업을 잠시 막았습니다. \(protectionUsageSummary()) 설정 > 토큰에서 한도를 올리거나 토큰 이력을 초기화하면 바로 다시 입력할 수 있습니다."
        }

        if isAutomation &&
            (dailyRemaining <= effectiveAutomationDailyReserve ||
             weeklyRemaining <= effectiveAutomationWeeklyReserve ||
             dailyUsagePercent >= 0.82 ||
             weeklyUsagePercent >= 0.82) {
            return "자동 보조 작업은 토큰 보호를 위해 잠시 제한되었습니다. \(protectionUsageSummary())"
        }

        return nil
    }

    func runningStopReason(isAutomation: Bool, currentTabTokens: Int, tokenLimit: Int) -> String? {
        if currentTabTokens >= tokenLimit {
            return "세션 토큰 한도에 도달해 자동 중단했습니다."
        }

        if dailyRemaining <= effectiveEmergencyDailyReserve ||
            weeklyRemaining <= effectiveEmergencyWeeklyReserve {
            return "전체 토큰 보호선을 넘겨 현재 작업을 중단했습니다. \(protectionUsageSummary())"
        }

        if isAutomation &&
            (dailyRemaining <= effectiveGlobalDailyReserve ||
             weeklyRemaining <= effectiveGlobalWeeklyReserve ||
             dailyUsagePercent >= 0.94 ||
             weeklyUsagePercent >= 0.94) {
            return "자동 보조 작업 토큰 보호선에 도달해 중단했습니다. \(protectionUsageSummary())"
        }

        // 비용 제한 체크
        let settings = AppSettings.shared
        if settings.dailyCostLimit > 0 && todayCost >= settings.dailyCostLimit {
            return "일일 비용 제한($\(String(format: "%.2f", settings.dailyCostLimit)))에 도달해 중단했습니다. 오늘 사용: $\(String(format: "%.2f", todayCost))"
        }

        return nil
    }

    func costWarningNeeded(tabCost: Double) -> String? {
        let settings = AppSettings.shared
        guard settings.costWarningAt80 else { return nil }
        if settings.perSessionCostLimit > 0 && tabCost >= settings.perSessionCostLimit * 0.8 {
            return "세션 비용이 제한의 80%에 도달했습니다: $\(String(format: "%.2f", tabCost)) / $\(String(format: "%.2f", settings.perSessionCostLimit))"
        }
        if settings.dailyCostLimit > 0 && todayCost >= settings.dailyCostLimit * 0.8 {
            return "일일 비용이 제한의 80%에 도달했습니다: $\(String(format: "%.2f", todayCost)) / $\(String(format: "%.2f", settings.dailyCostLimit))"
        }
        return nil
    }

    // MARK: - Persistence

    private func scheduleSave(delay: TimeInterval = 0.75) {
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
        let cutoff = cal.date(byAdding: .day, value: -30, to: Date())!
        history = loaded.filter { dateFormatter.date(from: $0.date).map { $0 >= cutoff } ?? false }
    }

    func clearOldEntries() {
        let key = todayKey
        history = history.filter { $0.date == key }
        scheduleSave(delay: 0)
    }

    func clearAllEntries() {
        history.removeAll()
        saveWorkItem?.cancel()
        UserDefaults.standard.removeObject(forKey: saveKey)
    }

    func applyRecommendedMinimumLimits() {
        if dailyTokenLimit < Self.recommendedDailyLimit {
            dailyTokenLimit = Self.recommendedDailyLimit
        }
        if weeklyTokenLimit < Self.recommendedWeeklyLimit {
            weeklyTokenLimit = Self.recommendedWeeklyLimit
        }
    }

    /// Returns records for the last 7 days (oldest first), filling missing days with zero records.
    var last7DaysRecords: [DayRecord] {
        let cal = Calendar.current
        let now = Date()
        var result: [DayRecord] = []
        for offset in (0..<7).reversed() {
            let day = cal.date(byAdding: .day, value: -offset, to: now)!
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
    func weekdayLabel(for dateString: String) -> String {
        guard let date = dateFormatter.date(from: dateString) else { return "?" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "E"
        return f.string(from: date)
    }

    /// Average daily tokens over last 7 days
    var averageDailyTokens: Int {
        let records = last7DaysRecords
        let total = records.reduce(0) { $0 + $1.totalTokens }
        return total / max(1, records.count)
    }

    /// Average daily cost over last 7 days
    var averageDailyCost: Double {
        let records = last7DaysRecords
        let total = records.reduce(0.0) { $0 + $1.cost }
        return total / Double(max(1, records.count))
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
    private static let maxRetainedBlocks = 420
    private static let maxRetainedFileChanges = 240

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
    var readCommandCount: Int = 0
    @Published var pendingApproval: PendingApproval?
    @Published var lastResultText: String = ""

    // 보안 경고
    @Published var dangerousCommandWarning: String?
    @Published var sensitiveFileWarning: String?

    // 슬립워크
    @Published var sleepWorkTask: String?
    @Published var sleepWorkTokenBudget: Int?
    @Published var sleepWorkStartTokens: Int = 0
    @Published var sleepWorkCompleted: Bool = false
    @Published var sleepWorkExceeded: Bool = false  // 2x budget exceeded
    @Published var lastPromptText: String = ""
    @Published var attachedImages: [URL] = []  // 첨부된 이미지 경로들
    @Published var completedPromptCount: Int = 0
    @Published var parallelTasks: [ParallelTaskRecord] = []

    // 세션 타임라인
    struct TimelineEvent: Identifiable {
        let id = UUID()
        let timestamp: Date
        let type: TimelineEventType
        let detail: String
    }

    enum TimelineEventType: String {
        case started = "시작"
        case prompt = "명령"
        case toolUse = "도구"
        case fileChange = "파일"
        case error = "에러"
        case completed = "완료"
    }

    @Published var timeline: [TimelineEvent] = []

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
    private var toolUseContexts: [String: ToolUseContext] = [:]
    private var pendingPermissionDenial: PermissionDenialCandidate?
    private var lastPermissionFingerprint: String?
    @Published var scrollTrigger: Int = 0          // 스크롤 트리거
    private var budgetStopIssued = false

    // Legacy compat
    var outputText: String { blocks.map { $0.content }.joined(separator: "\n") }
    var masterFD: Int32 = -1

    // ── Raw Terminal Mode (PTY) ──
    @Published var rawOutput: String = ""
    @Published var rawScrollTrigger: Int = 0
    @Published var isRawMode: Bool = false
    private var rawMasterFD: Int32 = -1
    let vt100 = VT100Terminal(rows: 50, cols: 120)

    var initialPrompt: String?
    var characterId: String?  // CharacterRegistry 연동
    var automationSourceTabId: String?
    var automationReportPath: String?
    var manualLaunch: Bool = false
    @Published var workflowSourceRequest: String = ""
    @Published var workflowPlanSummary: String = ""
    @Published var workflowDesignSummary: String = ""
    @Published var workflowReviewSummary: String = ""
    @Published var workflowQASummary: String = ""
    @Published var workflowSRESummary: String = ""
    @Published var officeSeatLockReason: String?
    @Published var workflowStages: [WorkflowStageRecord] = []
    @Published var reviewerAttemptCount: Int = 0
    @Published var qaAttemptCount: Int = 0
    @Published var automatedRevisionCount: Int = 0

    // ── 고급 CLI 옵션 ──
    @Published var permissionMode: PermissionMode = .bypassPermissions
    @Published var systemPrompt: String = ""
    @Published var maxBudgetUSD: Double = 0       // 0 = 무제한
    @Published var allowedTools: String = ""       // 쉼표 구분
    @Published var disallowedTools: String = ""    // 쉼표 구분
    @Published var additionalDirs: [String] = []
    @Published var continueSession: Bool = false   // --continue
    @Published var useWorktree: Bool = false        // --worktree

    // ── 추가 CLI 옵션 (v1.5) ──
    @Published var fallbackModel: String = ""          // --fallback-model
    @Published var sessionName: String = ""            // --name
    @Published var jsonSchema: String = ""             // --json-schema
    @Published var mcpConfigPaths: [String] = []       // --mcp-config
    @Published var customAgent: String = ""            // --agent
    @Published var customAgentsJSON: String = ""       // --agents (JSON)
    @Published var pluginDirs: [String] = []           // --plugin-dir
    @Published var customTools: String = ""            // --tools (빌트인 도구 제한)
    @Published var enableChrome: Bool = true           // --chrome
    @Published var forkSession: Bool = false           // --fork-session
    @Published var fromPR: String = ""                 // --from-pr
    @Published var enableBrief: Bool = false           // --brief
    @Published var tmuxMode: Bool = false              // --tmux
    @Published var strictMcpConfig: Bool = false       // --strict-mcp-config
    @Published var settingSources: String = ""         // --setting-sources
    @Published var settingsFileOrJSON: String = ""     // --settings
    @Published var betaHeaders: String = ""            // --betas

    // ── 세션 연속성 (--resume으로 멀티턴 유지) ──

    // ── 크롬 윈도우 캡처 ──
    @Published var chromeScreenshot: CGImage?

    init(id: String = UUID().uuidString, projectName: String, projectPath: String, workerName: String, workerColor: Color) {
        self.id = id; self.projectName = projectName; self.projectPath = projectPath
        self.workerName = workerName; self.workerColor = workerColor
    }

    private func sessionStartSummary(modelLabel: String? = nil) -> String {
        let resolvedModel = modelLabel.flatMap { ClaudeModel.detect(from: $0) } ?? selectedModel
        let resolvedLabel = modelLabel ?? resolvedModel.displayName
        return "\(resolvedModel.icon) \(resolvedLabel) · \(effortLevel.icon) \(effortLevel.rawValue) · v\(ClaudeInstallChecker.shared.version)"
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
        if let first = blocks.first, case .sessionStart = first.blockType {
            let displayLabel = ClaudeModel.detect(from: reportedModel)?.displayName ?? reportedModel
            first.content = sessionStartSummary(modelLabel: displayLabel)
        }
    }

    var persistedSessionId: String? { sessionId }

    func applySavedSessionConfiguration(_ saved: SavedSession) {
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
           let savedCharacter = CharacterRegistry.shared.character(with: savedCharacterId),
           savedCharacter.isHired,
           !savedCharacter.isOnVacation {
            characterId = savedCharacterId
        }
        if let savedSessionId = saved.sessionId, !savedSessionId.isEmpty {
            sessionId = savedSessionId
        }
    }

    func restoreSavedSessionSnapshot(_ saved: SavedSession) {
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
        isClaude = true
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

    func appendRestorationNotice(from saved: SavedSession, recoveryBundleURL: URL?) {
        var details: [String] = ["자동으로 다시 실행하지 않았습니다."]

        if let lastPrompt = saved.lastPrompt, !lastPrompt.isEmpty {
            details.append("마지막 입력: \(String(lastPrompt.prefix(180)))")
        } else if let initialPrompt = saved.initialPrompt, !initialPrompt.isEmpty {
            details.append("초기 입력: \(String(initialPrompt.prefix(180)))")
        }

        if let recoveryBundleURL {
            details.append("복구 폴더: \(recoveryBundleURL.path)")
        }

        if saved.sessionId != nil && (saved.continueSession ?? false) {
            details.append("다음 입력부터 이전 대화를 이어서 보낼 수 있습니다.")
        }

        let title = saved.wasProcessing == true ? "중단된 세션 복원" : "이전 세션 복원"
        appendBlock(.status(message: title), content: details.joined(separator: "\n"))
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
        isRunning = true; startTime = Date()

        // Raw terminal mode: SwiftTerm이 자체 관리
        if AppSettings.shared.rawTerminalMode {
            if !isRawMode { // 이미 raw 모드면 재시작 안 함
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
        isClaude = true

        let checker = ClaudeInstallChecker.shared; checker.check()
        if !checker.isInstalled {
            appendBlock(.error(message: "Claude Code 미설치"), content: "Claude Code CLI를 찾을 수 없습니다.\n\n설치: npm install -g @anthropic-ai/claude-code\n\nPATH가 설정되지 않았을 수 있습니다.\n'which claude'로 경로를 확인하거나,\nnvm/fnm 사용 시 .zshrc 설정을 확인하세요.")
            startError = "Claude Code not installed"
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .workmanClaudeNotInstalled, object: nil)
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
        isProcessing = true
        claudeActivity = .running
        // PTY 생성/프로세스 실행은 SwiftTermContainer에서 처리
    }

    func writeRawInput(_ text: String) {}
    func sendRawSignal(_ signal: UInt8) {}
    func updatePTYWindowSize(cols: UInt16, rows: UInt16) {}

    // MARK: - Send Prompt (stream-json 이벤트 스트림)

    func sendPrompt(_ prompt: String, permissionOverride: PermissionMode? = nil, bypassWorkflowRouting: Bool = false) {
        guard !prompt.isEmpty else { return }

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

        // 이전 프로세스가 남아있으면 안전하게 정리
        if let prev = currentProcess, prev.isRunning {
            prev.terminate()
            currentProcess = nil
        }

        if let reason = TokenTracker.shared.startBlockReason(isAutomation: isAutomationTab) {
            appendBlock(.status(message: "토큰 보호 모드"), content: reason)
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
        initialPrompt = nil
        lastPromptText = prompt
        isProcessing = true
        claudeActivity = .thinking
        lastActivityTime = Date()

        let path = FileManager.default.fileExists(atPath: projectPath) ? projectPath : NSHomeDirectory()
        let effectivePermissionMode = permissionOverride ?? permissionMode

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            var cmd = "claude -p --output-format stream-json --verbose"

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
            // 플러그인
            for pluginDir in self.pluginDirs where !pluginDir.isEmpty {
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
            DispatchQueue.main.async { self.attachedImages.removeAll() }

            // 프로젝트 경로 존재 여부 확인
            let projectDirURL = URL(fileURLWithPath: path)
            if !FileManager.default.fileExists(atPath: projectDirURL.path) {
                DispatchQueue.main.async {
                    self.appendBlock(.error(message: "프로젝트 경로 없음"), content: "경로를 찾을 수 없습니다: \(path)\n디렉토리가 삭제되었거나 외장 드라이브가 분리되었을 수 있습니다.")
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

            // 프로세스 참조를 메인 스레드에서 안전하게 설정
            DispatchQueue.main.sync {
                self.currentProcess = proc
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
            let bufferQueue = DispatchQueue(label: "com.workman.jsonBuffer")

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
                    print("[WorkMan] ⚠️ Process watchdog: 30분 타임아웃 도달, 강제 종료")
                    p.terminate()
                }
                DispatchQueue.global().asyncAfter(deadline: .now() + 1800, execute: watchdog)

                proc.waitUntilExit()
                watchdog.cancel()
            } catch {
                print("[도피스] 프로세스 실행 실패: \(error)")
                DispatchQueue.main.async {
                    self.appendBlock(.error(message: "프로세스 실행 실패"), content: "Claude Code를 실행할 수 없습니다.\n\n오류: \(error.localizedDescription)\n\nPATH가 올바르게 설정되어 있는지 확인하세요.\n터미널에서 'which claude'를 실행해 경로를 확인할 수 있습니다.")
                }
            }

            outPipe.fileHandleForReading.readabilityHandler = nil
            errPipe.fileHandleForReading.readabilityHandler = nil

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                // 이 프로세스가 현재 프로세스인지 확인 (다른 프로세스가 이미 대체했을 수 있음)
                let isStillCurrentProcess = self.currentProcess.map { ObjectIdentifier($0) == procId } ?? true
                guard isStillCurrentProcess else { return }

                self.currentProcess = nil
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
                            dangerousCommandWarning = "⚠️ \(match.pattern.severity.rawValue): \(match.pattern.description)\n→ \(match.matchedText)"
                            AuditLog.shared.log(.dangerousCommand, tabId: id, projectName: projectName, detail: cmd, isDangerous: true)
                        }
                        // 감사 로그
                        AuditLog.shared.log(.bashCommand, tabId: id, projectName: projectName, detail: cmd)
                        let desc = toolInput["description"] as? String
                        let header = desc != nil ? "\(cmd)  // \(desc!)" : cmd
                        appendBlock(.toolUse(name: "Bash", input: cmd), content: header)
                        timeline.append(TimelineEvent(timestamp: Date(), type: .toolUse, detail: "Bash: \(String(cmd.prefix(40)))"))
                    case "Read":
                        claudeActivity = .reading
                        let file = toolInput["file_path"] as? String ?? ""
                        // 보안: 민감 파일 감지
                        if let match = SensitiveFileShield.shared.check(filePath: file, action: "Read") {
                            sensitiveFileWarning = "🔒 민감 파일 접근: \(match.patternMatched)\n→ \(file)"
                            AuditLog.shared.log(.sensitiveFileAccess, tabId: id, projectName: projectName, detail: "Read: \(file)", isDangerous: true)
                        }
                        AuditLog.shared.log(.fileRead, tabId: id, projectName: projectName, detail: file)
                        appendBlock(.toolUse(name: "Read", input: file), content: (file as NSString).lastPathComponent)
                        readCommandCount += 1
                        AchievementManager.shared.recordFileRead(sessionReadCount: readCommandCount)
                    case "Write":
                        claudeActivity = .writing
                        let file = toolInput["file_path"] as? String ?? ""
                        if let match = SensitiveFileShield.shared.check(filePath: file, action: "Write") {
                            sensitiveFileWarning = "🔒 민감 파일 쓰기: \(match.patternMatched)\n→ \(file)"
                            AuditLog.shared.log(.sensitiveFileAccess, tabId: id, projectName: projectName, detail: "Write: \(file)", isDangerous: true)
                        }
                        AuditLog.shared.log(.fileWrite, tabId: id, projectName: projectName, detail: file)
                        recordFileChange(path: file, action: "Write")
                        appendBlock(.fileChange(path: file, action: "Write"), content: (file as NSString).lastPathComponent)
                        timeline.append(TimelineEvent(timestamp: Date(), type: .fileChange, detail: "Write: \((file as NSString).lastPathComponent)"))
                        AchievementManager.shared.recordFileEdit()
                    case "Edit":
                        claudeActivity = .writing
                        let file = toolInput["file_path"] as? String ?? ""
                        if let match = SensitiveFileShield.shared.check(filePath: file, action: "Edit") {
                            sensitiveFileWarning = "🔒 민감 파일 수정: \(match.patternMatched)\n→ \(file)"
                            AuditLog.shared.log(.sensitiveFileAccess, tabId: id, projectName: projectName, detail: "Edit: \(file)", isDangerous: true)
                        }
                        AuditLog.shared.log(.fileEdit, tabId: id, projectName: projectName, detail: file)
                        recordFileChange(path: file, action: "Edit")
                        appendBlock(.fileChange(path: file, action: "Edit"), content: (file as NSString).lastPathComponent)
                        timeline.append(TimelineEvent(timestamp: Date(), type: .fileChange, detail: "Edit: \((file as NSString).lastPathComponent)"))
                        AchievementManager.shared.recordFileEdit()
                    case "Grep":
                        claudeActivity = .searching
                        let pattern = toolInput["pattern"] as? String ?? ""
                        appendBlock(.toolUse(name: "Grep", input: pattern), content: pattern)
                        AchievementManager.shared.unlock("first_grep")
                    case "Glob":
                        claudeActivity = .searching
                        let pattern = toolInput["pattern"] as? String ?? ""
                        appendBlock(.toolUse(name: "Glob", input: pattern), content: pattern)
                        AchievementManager.shared.unlock("first_glob")
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
                NotificationCenter.default.post(
                    name: .workmanTabCycleCompleted,
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
            ? "이번 한 번만 수정 권한으로 재시도합니다."
            : "이번 한 번만 전체 권한으로 재시도합니다."

        lastPermissionFingerprint = fingerprint
        let approvalCommand = command
        pendingApproval = PendingApproval(
            command: approvalCommand,
            reason: "\(approvalReasonPrefix(for: denial.toolName)) 권한이 필요합니다. 승인하면 \(retrySummary)",
            onApprove: { [weak self] in
                self?.pendingPermissionDenial = nil
                self?.appendBlock(.status(message: "권한 승인됨 · 다시 시도합니다"))
                self?.sendPrompt(self?.approvalRetryPrompt(for: denial.toolName) ?? "Permission granted. Please continue the previous task.", permissionOverride: retryMode)
            },
            onDeny: { [weak self] in
                self?.pendingPermissionDenial = nil
                self?.appendBlock(.status(message: "권한 요청이 거부되었습니다"))
            }
        )
        // 세션 알림: 승인 필요
        let tabName = workerName.isEmpty ? projectName : workerName
        SessionNotificationManager.shared.postApprovalNeeded(tabName: tabName, tabId: id, toolName: denial.toolName)
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
            return "파일 수정"
        case "Bash":
            return "명령 실행"
        case "WebFetch":
            return "웹 가져오기"
        case "WebSearch":
            return "웹 검색"
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

        return "병렬 작업"
    }

    private func parallelTaskAssigneeId(seed: String) -> String {
        let registry = CharacterRegistry.shared
        let preferredPool = registry.hiredCharacters.filter {
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
    func appendBlock(_ type: StreamBlock.BlockType, content: String = "") -> StreamBlock {
        if let lastBlock = blocks.last,
           !lastBlock.isComplete,
           shouldMergeBlock(existing: lastBlock.blockType, new: type),
           lastBlock.content.count < 50000 {  // Prevent unbounded growth
            lastBlock.content += "\n" + content
            return lastBlock
        }
        let block = StreamBlock(type: type, content: content)
        blocks.append(block)
        trimBlocksIfNeeded()
        return block
    }

    var isAutomationTab: Bool {
        automationSourceTabId != nil
    }

    func cancelProcessing() {
        if isRawMode {
            // Raw mode: Ctrl+C 전송
            sendRawSignal(3) // ETX (Ctrl+C)
            return
        }
        currentProcess?.terminate(); currentProcess = nil
        isProcessing = false; claudeActivity = .idle
        finalizeParallelTasks(as: .failed)
        appendBlock(.status(message: "취소됨"))
    }

    func startSleepWork(task: String, tokenBudget: Int?) {
        sleepWorkTask = task
        sleepWorkTokenBudget = tokenBudget
        sleepWorkStartTokens = tokensUsed
        sleepWorkCompleted = false
        sleepWorkExceeded = false
        AuditLog.shared.log(.sleepWorkStart, tabId: id, projectName: projectName, detail: "예산: \(tokenBudget.map { "\($0) tokens" } ?? "무제한")")
        sendPrompt(task)
    }

    func forceStop() {
        // Raw mode PTY 정리
        if isRawMode && rawMasterFD >= 0 {
            close(rawMasterFD)
            rawMasterFD = -1
            isRawMode = false
        }
        if let proc = currentProcess, proc.isRunning {
            proc.terminate()
            let pid = proc.processIdentifier
            DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
                if proc.isRunning { kill(pid, SIGKILL) }
            }
        }
        currentProcess = nil
        isProcessing = false; claudeActivity = .idle; isRunning = false
        finalizeParallelTasks(as: .failed)
        appendBlock(.status(message: "강제 중지됨"))
    }

    /// 작업을 강제 중지하고 git 변경사항을 작업 전 상태로 롤백
    func cancelAndRevert() {
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
            appendBlock(.status(message: "작업 취소 및 변경사항 롤백 완료"), content: "백업 폴더: \(recoveryBundleURL.path)")
        } else {
            appendBlock(.status(message: "작업 취소 및 변경사항 롤백 완료"))
        }
    }

    func clearBlocks() { blocks.removeAll() }

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
                appendBlock(.status(message: "슬립워크 중단"), content: "토큰 예산의 2배를 초과했습니다. 다음에 이어서 작업할지 확인해주세요.")
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
        finalizeParallelTasks(as: .failed)
        appendBlock(.status(message: "토큰 보호로 중단"), content: reason)
    }

    /// Cached login shell PATH (resolved once at first call)
    private static var cachedLoginPath: String?
    private static var loginPathChecked = false

    /// GUI 앱에서도 claude CLI를 찾을 수 있도록 PATH를 완전히 구성
    static func buildFullPATH() -> String {
        let home = NSHomeDirectory()
        var paths: [String] = []

        // Homebrew (Apple Silicon + Intel)
        paths += ["/opt/homebrew/bin", "/opt/homebrew/sbin", "/usr/local/bin", "/usr/local/sbin"]

        // npm global 설치 경로들
        paths += ["/usr/local/opt/node/bin", home + "/.npm-global/bin"]

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

    static func shellSync(_ command: String) -> String? {
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
    static func shellSyncLoginWithTimeout(_ command: String, timeout: TimeInterval = 3) -> String? {
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

    static func captureBrowserWindow() async -> CGImage? {
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
    var statusPresentation: TabStatusPresentation {
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

    var sidebarSearchTokens: String {
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

    var assignedCharacter: WorkerCharacter? {
        CharacterRegistry.shared.character(with: characterId)
    }

    var workerJob: WorkerJob {
        assignedCharacter?.jobRole ?? .developer
    }

    var isWorkerOnVacation: Bool {
        assignedCharacter?.isOnVacation ?? false
    }

    var hasCodeChanges: Bool {
        fileChanges.contains { $0.action == "Write" || $0.action == "Edit" }
    }

    var latestUserPromptText: String? {
        blocks.reversed().first {
            if case .userPrompt = $0.blockType { return true }
            return false
        }?.content
    }

    var workflowRequirementText: String {
        let source = workflowSourceRequest.trimmingCharacters(in: .whitespacesAndNewlines)
        if !source.isEmpty { return source }
        return latestUserPromptText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    var lastCompletionSummary: String {
        lastResultText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func resetWorkflowTracking(request: String) {
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

    func upsertWorkflowStage(
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

    func updateWorkflowStage(
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

    var workflowTimelineStages: [WorkflowStageRecord] {
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

    var officeParallelTasks: [ParallelTaskRecord] {
        let workflowTasks = workflowBubbleTasks
        if workflowTasks.isEmpty {
            return Array(parallelTasks.prefix(4))
        }

        let extraTasks = parallelTasks.filter { task in
            !workflowTasks.contains(where: { $0.assigneeCharacterId == task.assigneeCharacterId && $0.label == task.label })
        }
        return Array((workflowTasks + extraTasks).prefix(4))
    }

    var workflowProgressSummary: String? {
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

    var officeParallelSummary: String? {
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

enum ClaudeUsageFetcher {
    /// Claude CLI를 인터랙티브 PTY로 실행하여 /usage 결과를 캡처
    static func fetch() -> String {
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
                i = raw.index(after: i)
                guard i < raw.endIndex else { break }
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
                    i = raw.index(after: i)
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
