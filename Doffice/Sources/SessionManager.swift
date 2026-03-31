import SwiftUI
import Darwin
import AppKit

class SessionManager: ObservableObject {
    static let shared = SessionManager()

    @Published var tabs: [TerminalTab] = []
    @Published var activeTabId: String?
    @Published var showNewTabSheet: Bool = false
    @Published var showSSHSheet: Bool = false

    // Pane layout for split view (nil = single pane mode)
    @Published var _paneLayout: PaneNode?
    @Published var showSessionSearch: Bool = false
    @Published var searchQuery: String = "" {
        didSet { debounceSearchResults() }
    }
    @Published private(set) var cachedSearchResults: [SearchResult] = []
    private var searchDebounceTimer: Timer?
    @Published var groups: [SessionGroup] = []
    @Published var selectedGroupPath: String? = nil {  // nil = 전체 보기
        didSet {
            UserDefaults.standard.set(selectedGroupPath ?? "", forKey: "doffice.selectedGroupPath")
        }
    }
    @Published var focusSingleTab: Bool = false       // 개별 워커 포커스
    @Published var pinnedTabIds: Set<String> = []    // Shift+클릭으로 선택한 탭들 (그리드 멀티뷰)
    @Published private(set) var availableReportCount: Int = 0
    @Published private(set) var totalTokensUsed: Int = 0
    @Published private(set) var userVisibleTabCount: Int = 0

    var userVisibleTabs: [TerminalTab] {
        tabs.filter { $0.automationSourceTabId == nil }
    }

    /// Recalculates cached `totalTokensUsed` from all tabs.
    func updateTokenCount() {
        totalTokensUsed = tabs.reduce(0) { $0 + $1.tokensUsed }
    }

    /// Recalculates cached `userVisibleTabCount`.
    private func updateUserVisibleTabCount() {
        userVisibleTabCount = tabs.filter { $0.automationSourceTabId == nil }.count
    }

    /// Convenience: update all tab-derived caches.
    private func updateTabDerivedCaches() {
        updateTokenCount()
        updateUserVisibleTabCount()
    }

    var manualLaunchCapacity: Int {
        let registry = CharacterRegistry.shared
        let occupiedIds = occupiedCharacterIds()
        let freeDevelopers = registry.hiredCharacters(for: .developer).filter {
            !$0.isOnVacation && !occupiedIds.contains($0.id)
        }.count
        let remainingHireSlots = max(0, CharacterRegistry.maxHiredCount - registry.hiredCharacters.count)
        let unlockedAvailable = registry.availableCharacters.filter {
            registry.isUnlocked($0)
        }.count
        return freeDevelopers + min(remainingHireSlots, unlockedAvailable)
    }

    // 현재 선택된 그룹의 탭들 (nil이면 전체)
    var visibleTabs: [TerminalTab] {
        guard let path = selectedGroupPath else { return userVisibleTabs }
        return userVisibleTabs.filter { $0.projectPath == path }
    }

    let workerNames = ["Pixel", "Byte", "Code", "Bug", "Chip", "Kit", "Dot", "Rex"]

    private var workerIndex = 0
    private var scanTimer: Timer?
    private var autoSaveTimer: Timer?
    private var scanTickCount = 0
    private var cachedProjectGroups: [ProjectGroup]?
    private var cachedAvailableReports: [ReportReference] = []
    private var cachedAvailableReportsSignature: Int?
    private var cachedAvailableReportsAt: TimeInterval = 0
    private var tabCompletionObserver: NSObjectProtocol?
    private var sessionStoreObserver: NSObjectProtocol?
    private var appLifecycleObservers: [NSObjectProtocol] = []
    private let reportScanQueue = DispatchQueue(label: "doffice.report-count", qos: .utility)
    private var reportScanWorkItem: DispatchWorkItem?
    private var reportRefreshToken = UUID()
    private var isAppActive = true
    /// 사용자가 명시적으로 닫은 프로젝트 경로 (rescan에서 재추가 방지)
    private var dismissedPaths = Set<String>()

    // MARK: - Session Search

    struct SearchResult: Identifiable {
        let id = UUID()
        let tabId: String
        let tabName: String
        let projectPath: String
        let blockId: UUID
        let blockContent: String
        let blockType: StreamBlock.BlockType
        let timestamp: Date
        let matchRange: Range<String.Index>
    }

    var searchResults: [SearchResult] { cachedSearchResults }

    private func debounceSearchResults() {
        searchDebounceTimer?.invalidate()
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else {
            cachedSearchResults = []
            return
        }
        searchDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.recomputeSearchResults(query: query)
        }
    }

    private func recomputeSearchResults(query: String) {
        var results: [SearchResult] = []
        for tab in userVisibleTabs {
            let tabName = tab.projectName.isEmpty ? tab.workerName : tab.projectName
            for block in tab.blocks {
                let content = block.content
                guard !content.isEmpty else { continue }
                let lowered = content.lowercased()
                if let range = lowered.range(of: query) {
                    results.append(SearchResult(
                        tabId: tab.id,
                        tabName: tabName,
                        projectPath: tab.projectPath,
                        blockId: block.id,
                        blockContent: content,
                        blockType: block.blockType,
                        timestamp: block.timestamp,
                        matchRange: range
                    ))
                }
            }
        }
        cachedSearchResults = results
    }

    func navigateToSearchResult(_ result: SearchResult) {
        selectTab(result.tabId)
        // Post notification so TerminalAreaView can scroll to the block
        NotificationCenter.default.post(
            name: .dofficeScrollToBlock,
            object: result.blockId
        )
    }

    var activeTab: TerminalTab? {
        guard let activeTabId,
              let tab = tabs.first(where: { $0.id == activeTabId }) else {
            return userVisibleTabs.first
        }
        if let sourceId = tab.automationSourceTabId {
            return tabs.first(where: { $0.id == sourceId }) ?? tab
        }
        return tab
    }

    private init() {
        isAppActive = NSApplication.shared.isActive
        tabCompletionObserver = NotificationCenter.default.addObserver(
            forName: .dofficeTabCycleCompleted,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let tab = notification.object as? TerminalTab else { return }
            self?.handleTabCycleCompleted(tab)
        }
        sessionStoreObserver = NotificationCenter.default.addObserver(
            forName: .dofficeSessionStoreDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.invalidateAvailableReportsCache()
            self?.scheduleAvailableReportCountRefresh()
        }
        appLifecycleObservers = [
            NotificationCenter.default.addObserver(
                forName: NSApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.isAppActive = true
                self?.scheduleAvailableReportCountRefresh()
            },
            NotificationCenter.default.addObserver(
                forName: NSApplication.didResignActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.isAppActive = false
            }
        ]
        scheduleAvailableReportCountRefresh()

        // Restore persisted selectedGroupPath
        let storedPath = UserDefaults.standard.string(forKey: "doffice.selectedGroupPath") ?? ""
        if !storedPath.isEmpty {
            selectedGroupPath = storedPath
        }

        // 30초마다 자동 저장 (강제 종료 대비)
        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.saveSessions()
        }
    }

    deinit {
        scanTimer?.invalidate()
        autoSaveTimer?.invalidate()
        if let tabCompletionObserver {
            NotificationCenter.default.removeObserver(tabCompletionObserver)
        }
        if let sessionStoreObserver {
            NotificationCenter.default.removeObserver(sessionStoreObserver)
        }
        for observer in appLifecycleObservers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // 프로젝트 경로별 그룹 (순서 유지)
    struct ProjectGroup: Identifiable {
        let id: String // projectPath
        let projectName: String
        let tabs: [TerminalTab]
        var hasActiveTab: Bool
        init(id: String, projectName: String, tabs: [TerminalTab], hasActiveTab: Bool) {
            self.id = id; self.projectName = projectName; self.tabs = tabs; self.hasActiveTab = hasActiveTab
        }
    }

    struct ReportReference: Identifiable {
        let id: String
        let projectName: String
        let projectPath: String
        let path: String
        let updatedAt: Date
    }

    var projectGroups: [ProjectGroup] {
        if let cached = cachedProjectGroups { return cached }
        var dict: [String: [TerminalTab]] = [:]
        var order: [String] = []
        for tab in userVisibleTabs {
            if dict[tab.projectPath] == nil { order.append(tab.projectPath) }
            dict[tab.projectPath, default: []].append(tab)
        }
        let result = order.compactMap { path -> ProjectGroup? in
            guard let tabs = dict[path], let first = tabs.first else { return nil }
            return ProjectGroup(
                id: path,
                projectName: first.projectName,
                tabs: tabs,
                hasActiveTab: tabs.contains(where: { $0.id == activeTabId })
            )
        }
        cachedProjectGroups = result
        return result
    }

    /// Call whenever tabs or activeTabId change to invalidate the cached project groups.
    private func invalidateProjectGroupsCache() {
        cachedProjectGroups = nil
    }

    private func invalidateAvailableReportsCache() {
        cachedAvailableReports.removeAll()
        cachedAvailableReportsSignature = nil
        cachedAvailableReportsAt = 0
    }

    func invalidateReportCache() {
        invalidateAvailableReportsCache()
        objectWillChange.send()
    }

    // MARK: - Auto Detect on Launch

    /// Scans for running terminal sessions and Claude Code processes,
    /// auto-creates tabs for each unique project found.
    func autoDetectAndConnect() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let detected = self?.scanRunningTerminals() ?? []

            DispatchQueue.main.async {
                guard let self = self else { return }

                if detected.isEmpty { return }

                // 같은 프로젝트에 몇 개 세션이 붙어있는지 카운트
                var projectSessionCount: [String: Int] = [:]
                for session in detected {
                    projectSessionCount[session.path, default: 0] += 1
                }

                for session in detected {
                    if self.tabs.contains(where: { $0.projectPath == session.path }) {
                        // 이미 있으면 세션 수만 업데이트
                        if let tab = self.tabs.first(where: { $0.projectPath == session.path }) {
                            tab.sessionCount = projectSessionCount[session.path] ?? 1
                        }
                        continue
                    }
                    // 사용자가 닫은 경로는 재추가하지 않음
                    if self.dismissedPaths.contains(session.path) { continue }
                    self.addTab(
                        projectName: session.projectName,
                        projectPath: session.path,
                        isClaude: session.isClaude,
                        detectedPid: session.pid,
                        sessionCount: projectSessionCount[session.path] ?? 1,
                        branch: session.branch
                    )
                }

                if let claudeTab = self.tabs.first(where: { $0.isClaude }) {
                    self.activeTabId = claudeTab.id
                } else {
                    self.activeTabId = self.tabs.first?.id
                }
            }
        }

        // 10초마다 리스캔, git 갱신은 30초마다, 업적/저장은 60초마다
        scanTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.scanTickCount += 1
            let isBackground = !self.isAppActive
            if !isBackground || self.scanTickCount % 6 == 0 {
                self.rescanForNewSessions()
            }
            // 토큰 합계 갱신 (개별 탭 tokensUsed 변경 반영)
            self.updateTokenCount()
            // git 정보 갱신: 매 3번째 tick (30초)
            if (!isBackground && self.scanTickCount % 3 == 0) || (isBackground && self.scanTickCount % 12 == 0) {
                self.tabs.forEach { $0.refreshGitInfo() }
            }
            // 업적 체크 + 세션 저장: 매 6번째 tick (60초)
            if (!isBackground && self.scanTickCount % 6 == 0) || (isBackground && self.scanTickCount % 18 == 0) {
                AchievementManager.shared.checkSessionAchievements(tabs: self.tabs)
                self.saveSessions()
                self.scheduleAvailableReportCountRefresh()
            }
        }

        // 최초 git 정보 로드
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.tabs.forEach { $0.refreshGitInfo() }
        }
    }

    // MARK: - Detected Session Info

    struct DetectedSession {
        let pid: Int
        let path: String
        let projectName: String
        let branch: String?
        let isClaude: Bool
        let parentApp: String? // Terminal.app, iTerm2, etc.
    }

    // MARK: - Process Scanning

    private func scanRunningTerminals() -> [DetectedSession] {
        var results: [DetectedSession] = []
        var seenPaths = Set<String>()

        // Claude Code 세션만 감지 (진짜 터미널에 붙어있는 것만)
        let claudeSessions = findClaudeCodeSessions()
        for session in claudeSessions {
            if !seenPaths.contains(session.path) {
                seenPaths.insert(session.path)
                results.append(session)
            }
        }

        return results
    }

    private func findClaudeCodeSessions() -> [DetectedSession] {
        var results: [DetectedSession] = []

        // 네이티브 API로 claude 프로세스 찾기 (ps/lsof 불필요 → 권한 팝업 없음)
        let pids = findClaudePidsNative()

        for pid in pids {
            if let projectPath = getClaudeProjectPath(pid: pid) {
                let projectName = getProjectName(path: projectPath)
                let branch = getBranch(path: projectPath)

                results.append(DetectedSession(
                    pid: pid,
                    path: projectPath,
                    projectName: projectName,
                    branch: branch,
                    isClaude: true,
                    parentApp: nil
                ))
            }
        }

        return results
    }

    /// 네이티브 API로 claude 프로세스 PID 찾기
    private func findClaudePidsNative() -> [Int] {
        // proc_listallpids로 모든 PID 가져오기
        let bufferSize = proc_listallpids(nil, 0)
        guard bufferSize > 0 else { return [] }

        var pids = [Int32](repeating: 0, count: Int(bufferSize))
        let actualSize = proc_listallpids(&pids, Int32(MemoryLayout<Int32>.size * pids.count))
        guard actualSize > 0 else { return [] }

        var claudePids: [Int] = []
        let count = Int(actualSize) / MemoryLayout<Int32>.size

        for i in 0..<count {
            let pid = pids[i]
            guard pid > 0 else { continue }

            // proc_pidpath로 실행 파일 경로 확인
            var pathBuf = [CChar](repeating: 0, count: Int(MAXPATHLEN))
            let pathLen = proc_pidpath(pid, &pathBuf, UInt32(MAXPATHLEN))
            guard pathLen > 0 else { continue }

            let execPath = String(cString: pathBuf)

            // claude 실행파일인지 확인
            let lower = execPath.lowercased()
            guard lower.contains("claude") || lower.contains("node") else { continue }

            // node인 경우 커맨드 라인에 claude가 포함되는지 확인
            if lower.contains("node") && !lower.contains("claude") {
                // proc_pidinfo로 args 대신 cwd에서 .claude 폴더 확인
                if let cwd = getCwdNative(pid: Int(pid)) {
                    if !cwd.contains(".claude") { continue }
                }
            }

            // DofficeApp 자체가 spawn한 프로세스 제외 (ppid 확인)
            var bsdInfo = proc_bsdinfo()
            let infoSize = proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &bsdInfo, Int32(MemoryLayout<proc_bsdinfo>.size))
            if infoSize > 0 {
                if bsdInfo.pbi_ppid == UInt32(ProcessInfo.processInfo.processIdentifier) { continue }
                // tty 없는 프로세스 제외 (백그라운드)
                // dev_t가 0이면 tty 없음 → 하지만 우리가 spawn한 것은 이미 위에서 제외
            }

            // claude 실행파일 경로를 가진 프로세스
            if lower.hasSuffix("/claude") || lower.contains("/claude-") || lower.contains("/@anthropic") {
                claudePids.append(Int(pid))
            }
        }

        return claudePids
    }

    /// Claude Code 프로세스의 프로젝트 경로를 추출 (lsof 미사용 → 화면 녹화 권한 불필요)
    private func getClaudeProjectPath(pid: Int) -> String? {
        let home = NSHomeDirectory()

        // Strategy A: proc_pidinfo로 cwd 가져오기 (권한 불필요)
        if let cwd = getCwdNative(pid: pid), cwd != "/", cwd != home {
            if let repoRoot = shell("git -C \"\(cwd)\" rev-parse --show-toplevel 2>/dev/null")?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               !repoRoot.isEmpty, repoRoot != home {
                return repoRoot
            }
            return cwd
        }

        // Strategy B: 부모 프로세스 cwd 확인 (네이티브 API)
        var current = pid
        for _ in 0..<5 {
            guard let ppid = getParentPidNative(pid: current), ppid > 1 else { break }

            if let cwd = getCwdNative(pid: ppid), cwd != "/", cwd != home {
                if let repoRoot = shell("git -C \"\(cwd)\" rev-parse --show-toplevel 2>/dev/null")?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                   !repoRoot.isEmpty, repoRoot != home {
                    return repoRoot
                }
                return cwd
            }
            current = ppid
        }

        // Strategy D: claude 임시 파일
        if let cwdFiles = shell("find /var/folders -name 'claude-*-cwd' -newer /var/folders 2>/dev/null | head -5") {
            for cwdFile in cwdFiles.components(separatedBy: "\n") where !cwdFile.isEmpty {
                if let content = shell("cat \"\(cwdFile)\" 2>/dev/null")?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                   !content.isEmpty, content != home, content != "/" {
                    return content
                }
            }
        }

        return nil
    }

    /// macOS 네이티브 API로 프로세스 cwd 가져오기 (권한 불필요)
    private func getCwdNative(pid: Int) -> String? {
        // proc_pidinfo PROC_PIDVNODEPATHINFO
        var pathInfo = proc_vnodepathinfo()
        let size = MemoryLayout<proc_vnodepathinfo>.size
        let ret = proc_pidinfo(Int32(pid), PROC_PIDVNODEPATHINFO, 0, &pathInfo, Int32(size))
        guard ret == size else { return nil }
        let cwd = withUnsafePointer(to: pathInfo.pvi_cdir.vip_path) { ptr in
            ptr.withMemoryRebound(to: CChar.self, capacity: Int(MAXPATHLEN)) { String(cString: $0) }
        }
        return cwd.isEmpty ? nil : cwd
    }

    // MARK: - Rescan (periodic)

    private func rescanForNewSessions() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let detected = self?.scanRunningTerminals() ?? []

            DispatchQueue.main.async {
                guard let self = self else { return }

                let detectedPaths = Set(detected.map { $0.path })

                // 같은 프로젝트 세션 카운트
                var projectSessionCount: [String: Int] = [:]
                for session in detected {
                    projectSessionCount[session.path, default: 0] += 1
                }

                // 기존 탭 중 사라진 세션 → 완료 표시
                for tab in self.tabs {
                    if tab.detectedPid != nil && !detectedPaths.contains(tab.projectPath) {
                        tab.isCompleted = true
                        tab.claudeActivity = .done
                        tab.generateSummary()
                        AchievementManager.shared.checkCompletionAchievements(tab: tab)
                        if tab.errorCount > 0 {
                            AchievementManager.shared.checkErrorRecovery()
                        }
                    }
                    // 세션 수 업데이트
                    tab.sessionCount = projectSessionCount[tab.projectPath] ?? tab.sessionCount
                }

                // 새 세션 추가 (사용자가 닫은 경로는 제외)
                for session in detected {
                    if !self.tabs.contains(where: { $0.projectPath == session.path }),
                       !self.dismissedPaths.contains(session.path) {
                        self.addTab(
                            projectName: session.projectName,
                            projectPath: session.path,
                            isClaude: session.isClaude,
                            detectedPid: session.pid,
                            sessionCount: projectSessionCount[session.path] ?? 1,
                            branch: session.branch
                        )
                    }
                }
            }
        }
    }

    // MARK: - Helper: Process Info

    private func getCwd(pid: Int) -> String? {
        // 네이티브 API로 cwd 가져오기 (lsof 불필요)
        return getCwdNative(pid: pid)
    }

    private func getParentCwd(pid: Int) -> String? {
        var current = pid
        for _ in 0..<3 {
            guard let ppid = getParentPidNative(pid: current), ppid > 1 else { return nil }
            if let cwd = getCwd(pid: ppid) { return cwd }
            current = ppid
        }
        return nil
    }

    /// 네이티브 API로 부모 PID 가져오기
    private func getParentPidNative(pid: Int) -> Int? {
        var info = proc_bsdinfo()
        let ret = proc_pidinfo(Int32(pid), PROC_PIDTBSDINFO, 0, &info, Int32(MemoryLayout<proc_bsdinfo>.size))
        guard ret > 0 else { return nil }
        let ppid = Int(info.pbi_ppid)
        return ppid > 0 ? ppid : nil
    }

    private func getProjectName(path: String) -> String {
        // Use git repo root name if available
        if let toplevel = shell("git -C \"\(path)\" rev-parse --show-toplevel 2>/dev/null")?
            .trimmingCharacters(in: .whitespacesAndNewlines) {
            return (toplevel as NSString).lastPathComponent
        }
        return (path as NSString).lastPathComponent
    }

    private func getBranch(path: String) -> String? {
        return shell("git -C \"\(path)\" branch --show-current 2>/dev/null")?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func hasClaudeChild(pid: Int) -> Bool {
        // 네이티브 API — 이미 findClaudePidsNative에서 처리하므로 간소화
        return false
    }

    private func getTerminalApp(pid: Int) -> String? {
        // 네이티브 API로 부모 프로세스 트리 탐색
        var currentPid = pid
        for _ in 0..<10 {
            guard let ppid = getParentPidNative(pid: currentPid), ppid > 1 else { break }

            var pathBuf = [CChar](repeating: 0, count: Int(MAXPATHLEN))
            let pathLen = proc_pidpath(Int32(ppid), &pathBuf, UInt32(MAXPATHLEN))
            if pathLen > 0 {
                let execPath = String(cString: pathBuf)
                if execPath.contains("Terminal") { return "Terminal" }
                if execPath.contains("iTerm") { return "iTerm2" }
                if execPath.contains("Warp") { return "Warp" }
                if execPath.contains("Alacritty") { return "Alacritty" }
                if execPath.contains("kitty") { return "kitty" }
                if execPath.contains("tmux") { return "tmux" }
            }
            currentPid = ppid
        }
        return nil
    }

    // MARK: - Tab Management

    @discardableResult
    func addTab(projectName: String, projectPath: String, isClaude: Bool = false, detectedPid: Int? = nil, sessionCount: Int = 1, branch: String? = nil, initialPrompt: String? = nil, preferredCharacterId: String? = nil, automationSourceTabId: String? = nil, automationReportPath: String? = nil, manualLaunch: Bool = false, autoStart: Bool = true, restoredSession: SavedSession? = nil) -> TerminalTab {
        let registry = CharacterRegistry.shared
        let occupiedIds = occupiedCharacterIds()
        let availableDevelopers = registry.hiredCharacters(for: .developer).filter {
            !$0.isOnVacation && !occupiedIds.contains($0.id)
        }

        let name: String
        let color: Color
        let characterId: String?

        if let restoredSession {
            if let restoredCharacterId = restoredSession.characterId,
               let restoredCharacter = registry.character(with: restoredCharacterId),
               restoredCharacter.isHired,
               !restoredCharacter.isOnVacation,
               (automationSourceTabId != nil || !occupiedIds.contains(restoredCharacter.id)) {
                name = restoredCharacter.name
                color = Color(hex: restoredCharacter.shirtColor)
                characterId = restoredCharacter.id
            } else {
                name = restoredSession.workerName
                color = Color(hex: restoredSession.workerColorHex)
                characterId = nil
            }
        } else if let preferred = registry.character(with: preferredCharacterId),
           preferred.isHired, !preferred.isOnVacation,
           (automationSourceTabId != nil || !occupiedIds.contains(preferred.id)) {
            name = preferred.name
            color = Color(hex: preferred.shirtColor)
            characterId = preferred.id
        } else if manualLaunch, let char = randomManualCharacter() {
            name = char.name
            color = Color(hex: char.shirtColor)
            characterId = char.id
        } else if let char = availableDevelopers.first {
            name = char.name
            color = Color(hex: char.shirtColor)
            characterId = char.id
        } else {
            // 고용된 캐릭터가 없으면 기본값
            let baseName = workerNames[workerIndex % workerNames.count]
            let sameCount = tabs.filter { $0.workerName.hasPrefix(baseName) }.count
            name = sameCount > 0 ? "\(baseName) \(sameCount + 1)" : baseName
            color = Theme.workerColors[workerIndex % Theme.workerColors.count]
            characterId = nil
        }

        let tab = TerminalTab(
            id: restoredSession?.tabId ?? UUID().uuidString,
            projectName: projectName,
            projectPath: projectPath,
            workerName: name,
            workerColor: color
        )
        tab.isClaude = isClaude
        tab.detectedPid = detectedPid
        tab.sessionCount = sessionCount
        tab.branch = branch
        tab.initialPrompt = initialPrompt
        tab.characterId = characterId
        tab.automationSourceTabId = automationSourceTabId
        tab.automationReportPath = automationReportPath
        tab.manualLaunch = manualLaunch || (restoredSession != nil)

        tabs.append(tab)
        invalidateProjectGroupsCache()
        invalidateAvailableReportsCache()
        scheduleAvailableReportCountRefresh()
        updateTabDerivedCaches()
        if activeTabId == nil {
            activeTabId = tab.id
        }
        workerIndex += 1

        if autoStart {
            tab.start()
        }
        return tab
    }

    private func occupiedCharacterIds() -> Set<String> {
        Set(
            tabs.compactMap { tab in
                guard let characterId = tab.characterId else { return nil }
                if tab.automationSourceTabId != nil {
                    return tab.isProcessing ? characterId : nil
                }
                return tab.isCompleted ? nil : characterId
            }
        )
    }

    private func randomManualCharacter() -> WorkerCharacter? {
        let registry = CharacterRegistry.shared
        let occupiedIds = occupiedCharacterIds()

        let hiredDevelopers = registry.hiredCharacters(for: .developer).filter {
            !$0.isOnVacation && !occupiedIds.contains($0.id)
        }
        if let hired = hiredDevelopers.randomElement() {
            return hired
        }

        let unlockedAvailable = registry.availableCharacters.filter {
            registry.isUnlocked($0)
        }
        guard registry.hiredCharacters.count < CharacterRegistry.maxHiredCount else {
            return nil
        }
        guard let candidate = unlockedAvailable.randomElement() else {
            return nil
        }

        registry.hire(candidate.id)
        registry.setJobRole(.developer, for: candidate.id)
        return registry.character(with: candidate.id)
    }

    func notifyManualLaunchCapacity(requested: Int = 1) {
        let message: String
        if CharacterRegistry.shared.hiredCharacters.count >= CharacterRegistry.maxHiredCount && manualLaunchCapacity == 0 {
            message = String(format: NSLocalizedString("session.limit.max", comment: ""), CharacterRegistry.maxHiredCount)
        } else if manualLaunchCapacity == 0 {
            message = NSLocalizedString("session.limit.no.available", comment: "")
        } else {
            message = String(format: NSLocalizedString("session.limit.partial", comment: ""), manualLaunchCapacity, requested)
        }

        NotificationCenter.default.post(
            name: .dofficeRoleNotice,
            object: nil,
            userInfo: [
                "title": NSLocalizedString("session.limit.title", comment: ""),
                "message": message
            ]
        )
    }

    func removeTab(_ id: String) {
        if let tab = tabs.first(where: { $0.id == id }) {
            // rescan이 닫은 세션을 다시 추가하지 않도록 경로 기억
            if tab.detectedPid != nil {
                dismissedPaths.insert(tab.projectPath)
            }
            tab.stop()
            if tab.automationSourceTabId == nil {
                let childTabs = tabs.filter { $0.automationSourceTabId == tab.id }
                for childTab in childTabs {
                    childTab.stop()
                }
                tabs.removeAll { $0.automationSourceTabId == tab.id }
            }
        }
        tabs.removeAll(where: { $0.id == id })
        invalidateProjectGroupsCache()
        invalidateAvailableReportsCache()
        scheduleAvailableReportCountRefresh()
        updateTabDerivedCaches()
        if activeTabId == id {
            activeTabId = userVisibleTabs.last?.id
        }
    }

    func selectTab(_ id: String) {
        activeTabId = id
        invalidateProjectGroupsCache()
    }

    func togglePinTab(_ id: String) {
        if pinnedTabIds.contains(id) {
            pinnedTabIds.remove(id)
        } else {
            pinnedTabIds.insert(id)
            focusSingleTab = false  // 멀티 선택 시 단일 포커스 해제
        }
    }

    func clearPinnedTabs() {
        pinnedTabIds.removeAll()
    }

    /// Convenience: add tab with just a project path
    @discardableResult
    func addTab(projectPath: String) -> TerminalTab {
        let name = getProjectName(path: projectPath)
        return addTab(projectName: name, projectPath: projectPath, manualLaunch: true)
    }

    /// SSH 연결 탭 생성
    @discardableResult
    func addSSHTab(profile: SSHProfile) -> TerminalTab {
        let tab = addTab(
            projectName: "SSH: \(profile.displayName)",
            projectPath: NSHomeDirectory(),
            manualLaunch: true,
            autoStart: false
        )
        tab.sshProfile = profile
        tab.isSSH = true
        // SSH는 raw terminal로 실행
        NotificationCenter.default.post(
            name: .dofficeSSHTabCreated,
            object: tab,
            userInfo: ["profile": profile]
        )
        return tab
    }

    /// tmux 세션 복구 (tmux I/O는 백그라운드에서 수행)
    func restoreTmuxSessions() {
        let bridge = TmuxSessionBridge.shared
        guard bridge.isTmuxAvailable else { return }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let existingSessions = bridge.listSessions()
            DispatchQueue.main.async {
                guard let self else { return }
                for session in existingSessions {
                    guard !self.tabs.contains(where: { $0.tmuxSessionId == session.id }) else { continue }
                    let tab = self.addTab(projectPath: NSHomeDirectory())
                    tab.tmuxSessionId = session.id
                }
            }
        }
    }

    func moveTab(from source: IndexSet, to destination: Int) {
        tabs.move(fromOffsets: source, toOffset: destination)
        invalidateProjectGroupsCache()
    }

    // MARK: - Group Management

    func createGroup(name: String, color: Color, tabIds: [String]) {
        let group = SessionGroup(name: name, color: color, tabIds: tabIds)
        groups.append(group)
        for id in tabIds {
            tabs.first(where: { $0.id == id })?.groupId = group.id
        }
    }

    func addToGroup(tabId: String, groupId: String) {
        if let group = groups.first(where: { $0.id == groupId }) {
            if !group.tabIds.contains(tabId) {
                group.tabIds.append(tabId)
            }
            tabs.first(where: { $0.id == tabId })?.groupId = groupId
        }
    }

    func removeFromGroup(tabId: String) {
        if let tab = tabs.first(where: { $0.id == tabId }), let gid = tab.groupId {
            if let group = groups.first(where: { $0.id == gid }) {
                group.tabIds.removeAll(where: { $0 == tabId })
                if group.tabIds.isEmpty {
                    groups.removeAll(where: { $0.id == gid })
                }
            }
            tab.groupId = nil
        }
    }

    func deleteGroup(_ groupId: String) {
        for tab in tabs where tab.groupId == groupId {
            tab.groupId = nil
        }
        groups.removeAll(where: { $0.id == groupId })
    }

    func tabsInGroup(_ groupId: String) -> [TerminalTab] {
        tabs.filter { $0.groupId == groupId }
    }

    func ungroupedTabs() -> [TerminalTab] {
        tabs.filter { $0.groupId == nil }
    }

    func prepareDirectDeveloperWorkflowIfNeeded(for tab: TerminalTab, prompt: String) {
        guard tab.workerJob == .developer,
              tab.automationSourceTabId == nil,
              !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        tab.resetWorkflowTracking(request: prompt)
        tab.upsertWorkflowStage(
            role: .developer,
            workerName: tab.workerName,
            assigneeCharacterId: tab.characterId,
            state: .running,
            handoffLabel: String(format: NSLocalizedString("workflow.handoff.user", comment: ""), tab.workerName),
            detail: NSLocalizedString("workflow.dev.user.start", comment: "")
        )
    }

    func routePromptIfNeeded(for tab: TerminalTab, prompt: String) -> Bool {
        guard tab.workerJob == .developer,
              tab.automationSourceTabId == nil,
              !tab.isProcessing else {
            return false
        }

        if let reason = automationThrottleReason(for: .planner) {
            tab.appendBlock(.status(message: NSLocalizedString("token.protection.mode", comment: "")), content: reason)
            return false
        }

        guard let plannerCharacter = availableAutomationCharacter(for: .planner, sourceId: tab.id) else {
            if !CharacterRegistry.shared.hiredCharacters(for: .planner).isEmpty {
                tab.appendBlock(.status(message: NSLocalizedString("workflow.planner.waiting.title", comment: "")), content: NSLocalizedString("workflow.planner.busy", comment: ""))
            }
            return false
        }

        guard !hasAutomationInFlight(for: tab.id, roles: [.planner, .designer, .reviewer, .qa, .reporter, .sre]) else {
            tab.appendBlock(
                .status(message: NSLocalizedString("workflow.collab.in.progress", comment: "")),
                content: NSLocalizedString("workflow.collab.in.progress.detail", comment: "")
            )
            return true
        }

        tab.resetWorkflowTracking(request: prompt)
        tab.officeSeatLockReason = NSLocalizedString("workflow.planning.waiting", comment: "")
        tab.lastActivityTime = Date()
        tab.appendBlock(.userPrompt, content: prompt)

        let plannerPrompt = buildPlannerPrompt(for: tab, request: prompt)
        let plannerTab = startOrReuseAutomationTab(
            role: .planner,
            projectName: "\(tab.projectName) Plan",
            projectPath: tab.projectPath,
            prompt: plannerPrompt,
            preferredCharacter: plannerCharacter,
            automationSourceTabId: tab.id
        )
        tab.upsertWorkflowStage(
            role: .planner,
            workerName: plannerTab.workerName,
            assigneeCharacterId: plannerCharacter.id,
            state: .running,
            handoffLabel: String(format: NSLocalizedString("workflow.handoff.user", comment: ""), plannerTab.workerName),
            detail: NSLocalizedString("workflow.planner.handoff.detail", comment: "")
        )

        tab.appendBlock(
            .status(message: String(format: NSLocalizedString("workflow.planner.assigned", comment: ""), plannerTab.workerName)),
            content: NSLocalizedString("workflow.planner.assigned.detail", comment: "")
        )
        return true
    }

    private func hasAutomationInFlight(for sourceId: String, roles: [WorkerJob]) -> Bool {
        tabs.contains {
            roles.contains($0.workerJob) &&
            $0.automationSourceTabId == sourceId &&
            $0.isProcessing
        }
    }

    private func automationThrottleReason(for role: WorkerJob) -> String? {
        let tracker = TokenTracker.shared
        let critical = tracker.dailyUsagePercent >= 0.9 ||
            tracker.weeklyUsagePercent >= 0.9 ||
            tracker.dailyRemaining < 25_000 ||
            tracker.weeklyRemaining < 80_000
        if critical {
            return String(format: NSLocalizedString("workflow.throttle.critical", comment: ""), role.displayName)
        }

        let conservativeRoles: Set<WorkerJob> = [.planner, .designer, .reporter, .sre]
        let conserve = tracker.dailyUsagePercent >= 0.75 ||
            tracker.weeklyUsagePercent >= 0.75 ||
            tracker.dailyRemaining < 80_000 ||
            tracker.weeklyRemaining < 250_000
        if conserve && conservativeRoles.contains(role) {
            return String(format: NSLocalizedString("workflow.throttle.conserve", comment: ""), role.displayName)
        }
        return nil
    }

    private func availableAutomationCharacter(for role: WorkerJob, sourceId: String) -> WorkerCharacter? {
        let registry = CharacterRegistry.shared
        let occupiedIds = occupiedCharacterIds()
        return registry.hiredCharacters(for: role).first { character in
            if reusableAutomationTab(for: sourceId, role: role, preferredCharacterId: character.id) != nil {
                return true
            }
            return !occupiedIds.contains(character.id)
        }
    }

    private func reusableAutomationTab(
        for sourceId: String,
        role: WorkerJob,
        preferredCharacterId: String?
    ) -> TerminalTab? {
        let matches = tabs.filter {
            $0.automationSourceTabId == sourceId &&
            $0.workerJob == role &&
            (preferredCharacterId == nil || $0.characterId == preferredCharacterId)
        }

        guard let keeper = matches.first(where: \.isProcessing) ?? matches.first else {
            return nil
        }

        for duplicate in matches where duplicate.id != keeper.id && !duplicate.isProcessing {
            removeTab(duplicate.id)
        }

        return keeper
    }

    @discardableResult
    private func startOrReuseAutomationTab(
        role: WorkerJob,
        projectName: String,
        projectPath: String,
        prompt: String,
        preferredCharacter: WorkerCharacter,
        automationSourceTabId: String,
        automationReportPath: String? = nil
    ) -> TerminalTab {
        if let existing = reusableAutomationTab(
            for: automationSourceTabId,
            role: role,
            preferredCharacterId: preferredCharacter.id
        ) {
            existing.projectName = projectName
            existing.projectPath = projectPath
            existing.workerName = preferredCharacter.name
            existing.workerColor = Color(hex: preferredCharacter.shirtColor)
            existing.characterId = preferredCharacter.id
            existing.automationSourceTabId = automationSourceTabId
            existing.automationReportPath = automationReportPath
            existing.lastActivityTime = Date()
            applyAutomationSettings(to: existing, role: role)
            existing.sendPrompt(prompt, bypassWorkflowRouting: true)
            return existing
        }

        let tab = addTab(
            projectName: projectName,
            projectPath: projectPath,
            initialPrompt: prompt,
            preferredCharacterId: preferredCharacter.id,
            automationSourceTabId: automationSourceTabId,
            automationReportPath: automationReportPath,
            autoStart: false
        )
        applyAutomationSettings(to: tab, role: role)
        tab.start()
        return tab
    }

    private func applyAutomationSettings(to tab: TerminalTab, role: WorkerJob) {
        switch role {
        case .planner, .designer, .reporter, .sre:
            tab.selectedModel = .haiku
            tab.effortLevel = .low
            tab.tokenLimit = 8_000
        case .reviewer, .qa:
            tab.selectedModel = .sonnet
            tab.effortLevel = .low
            tab.tokenLimit = 12_000
        default:
            break
        }
    }

    private func handleTabCycleCompleted(_ tab: TerminalTab) {
        switch tab.workerJob {
        case .planner:
            handlePlannerCompletion(tab)
        case .designer:
            handleDesignerCompletion(tab)
        case .developer:
            handleDeveloperCompletion(tab)
        case .reviewer:
            handleReviewerCompletion(tab)
        case .qa:
            handleQACompletion(tab)
        case .reporter:
            handleReporterCompletion(tab)
        case .sre:
            handleSRECompletion(tab)
        default:
            break
        }
    }

    private func handlePlannerCompletion(_ plannerTab: TerminalTab) {
        guard let sourceId = plannerTab.automationSourceTabId,
              let sourceTab = tabs.first(where: { $0.id == sourceId }) else { return }

        sourceTab.workflowPlanSummary = plannerTab.lastCompletionSummary
        sourceTab.updateWorkflowStage(
            role: .planner,
            state: .completed,
            detail: plannerTab.lastCompletionSummary.isEmpty
                ? NSLocalizedString("workflow.planning.completed", comment: "")
                : String(plannerTab.lastCompletionSummary.prefix(260))
        )
        sourceTab.appendBlock(
            .status(message: NSLocalizedString("workflow.planning.done", comment: "")),
            content: plannerTab.lastCompletionSummary.isEmpty
                ? NSLocalizedString("workflow.planning.summary", comment: "")
                : String(plannerTab.lastCompletionSummary.prefix(260))
        )

        if let reason = automationThrottleReason(for: .designer) {
            sourceTab.appendBlock(.status(message: NSLocalizedString("workflow.design.skipped", comment: "")), content: reason)
        } else if let designerCharacter = availableAutomationCharacter(for: .designer, sourceId: sourceId),
                  !hasAutomationInFlight(for: sourceId, roles: [.designer]) {
            sourceTab.officeSeatLockReason = NSLocalizedString("workflow.design.waiting", comment: "")
            let designerPrompt = buildDesignerPrompt(for: sourceTab)
            let designerTab = startOrReuseAutomationTab(
                role: .designer,
                projectName: "\(sourceTab.projectName) Design",
                projectPath: sourceTab.projectPath,
                prompt: designerPrompt,
                preferredCharacter: designerCharacter,
                automationSourceTabId: sourceId
            )
            sourceTab.upsertWorkflowStage(
                role: .designer,
                workerName: designerTab.workerName,
                assigneeCharacterId: designerCharacter.id,
                state: .running,
                handoffLabel: String(format: NSLocalizedString("workflow.handoff.role", comment: ""), plannerTab.workerName, designerTab.workerName),
                detail: NSLocalizedString("workflow.design.detail", comment: "")
            )
            sourceTab.appendBlock(
                .status(message: String(format: NSLocalizedString("workflow.designer.assigned", comment: ""), designerTab.workerName)),
                content: NSLocalizedString("workflow.designer.detail", comment: "")
            )
            return
        }

        dispatchDeveloperFromPreparation(for: sourceTab, handoffSourceName: plannerTab.workerName)
    }

    private func handleDesignerCompletion(_ designerTab: TerminalTab) {
        guard let sourceId = designerTab.automationSourceTabId,
              let sourceTab = tabs.first(where: { $0.id == sourceId }) else { return }

        sourceTab.workflowDesignSummary = designerTab.lastCompletionSummary
        sourceTab.updateWorkflowStage(
            role: .designer,
            state: .completed,
            detail: designerTab.lastCompletionSummary.isEmpty
                ? NSLocalizedString("workflow.design.completed", comment: "")
                : String(designerTab.lastCompletionSummary.prefix(260))
        )
        sourceTab.appendBlock(
            .status(message: NSLocalizedString("workflow.design.done", comment: "")),
            content: designerTab.lastCompletionSummary.isEmpty
                ? NSLocalizedString("workflow.design.summary", comment: "")
                : String(designerTab.lastCompletionSummary.prefix(260))
        )

        dispatchDeveloperFromPreparation(for: sourceTab, handoffSourceName: designerTab.workerName)
    }

    private func handleDeveloperCompletion(_ tab: TerminalTab) {
        guard tab.hasCodeChanges else {
            tab.officeSeatLockReason = nil
            tab.updateWorkflowStage(
                role: .developer,
                state: .completed,
                detail: NSLocalizedString("workflow.dev.no.code.detail", comment: "")
            )
            tab.appendBlock(.status(message: NSLocalizedString("workflow.dev.no.code.skip", comment: "")))
            launchCompletionRecipients(
                for: tab,
                validationSummary: NSLocalizedString("workflow.dev.no.code.summary", comment: ""),
                qaSummary: nil,
                handoffSourceName: tab.workerName
            )
            return
        }

        tab.updateWorkflowStage(
            role: .developer,
            state: .completed,
            detail: NSLocalizedString("workflow.dev.completed.detail", comment: "")
        )

        if let reason = automationThrottleReason(for: .reviewer) {
            tab.appendBlock(.status(message: NSLocalizedString("workflow.review.skip.title", comment: "")), content: reason)
            launchQA(for: tab, reviewSummary: nil, handoffSourceName: tab.workerName)
            return
        }

        if AppSettings.shared.reviewerMaxPasses == 0 {
            tab.updateWorkflowStage(
                role: .reviewer,
                state: .skipped,
                detail: NSLocalizedString("workflow.review.disabled", comment: "")
            )
            tab.appendBlock(.status(message: NSLocalizedString("workflow.review.skipped", comment: "")), content: NSLocalizedString("workflow.review.skipped.detail", comment: ""))
            launchQA(for: tab, reviewSummary: nil, handoffSourceName: tab.workerName)
            return
        }

        if tab.reviewerAttemptCount >= AppSettings.shared.reviewerMaxPasses {
            tab.officeSeatLockReason = nil
            tab.updateWorkflowStage(
                role: .reviewer,
                state: .failed,
                detail: String(format: NSLocalizedString("workflow.review.limit.reached", comment: ""), AppSettings.shared.reviewerMaxPasses)
            )
            tab.appendBlock(
                .status(message: NSLocalizedString("workflow.review.limit.title", comment: "")),
                content: String(format: NSLocalizedString("workflow.review.limit.detail", comment: ""), AppSettings.shared.reviewerMaxPasses)
            )
            return
        }

        if let reviewerCharacter = availableAutomationCharacter(for: .reviewer, sourceId: tab.id) {
            guard !tabs.contains(where: {
                $0.projectPath == tab.projectPath &&
                $0.workerJob == .reviewer &&
                $0.isProcessing &&
                $0.automationSourceTabId == tab.id
            }) else { return }

            let reviewPrompt = buildReviewPrompt(for: tab)
            let reviewTab = startOrReuseAutomationTab(
                role: .reviewer,
                projectName: "\(tab.projectName) Review",
                projectPath: tab.projectPath,
                prompt: reviewPrompt,
                preferredCharacter: reviewerCharacter,
                automationSourceTabId: tab.id
            )
            tab.reviewerAttemptCount += 1
            tab.officeSeatLockReason = NSLocalizedString("workflow.review.waiting", comment: "")
            tab.upsertWorkflowStage(
                role: .reviewer,
                workerName: reviewTab.workerName,
                assigneeCharacterId: reviewerCharacter.id,
                state: .running,
                handoffLabel: String(format: NSLocalizedString("workflow.handoff.role", comment: ""), tab.workerName, reviewTab.workerName),
                detail: NSLocalizedString("workflow.review.detail", comment: "")
            )
            tab.appendBlock(.status(message: String(format: NSLocalizedString("workflow.review.assigned", comment: ""), reviewTab.workerName)), content: NSLocalizedString("workflow.review.assigned.detail", comment: ""))
            return
        }

        launchQA(for: tab, reviewSummary: nil, handoffSourceName: tab.workerName)
    }

    private func handleReviewerCompletion(_ reviewerTab: TerminalTab) {
        guard let sourceId = reviewerTab.automationSourceTabId,
              let sourceTab = tabs.first(where: { $0.id == sourceId }) else { return }

        sourceTab.workflowReviewSummary = reviewerTab.lastCompletionSummary
        let summary = reviewerTab.lastCompletionSummary.uppercased()
        if summary.contains("REVIEW_STATUS: PASS") {
            sourceTab.updateWorkflowStage(
                role: .reviewer,
                state: .completed,
                detail: reviewerTab.lastCompletionSummary.isEmpty
                    ? NSLocalizedString("workflow.review.passed", comment: "")
                    : String(reviewerTab.lastCompletionSummary.prefix(240))
            )
            sourceTab.appendBlock(
                .status(message: NSLocalizedString("workflow.review.pass", comment: "")),
                content: reviewerTab.lastCompletionSummary.isEmpty
                    ? NSLocalizedString("workflow.review.pass.detail", comment: "")
                    : String(reviewerTab.lastCompletionSummary.prefix(240))
            )
            if CharacterRegistry.shared.hiredCharacters(for: .qa).isEmpty {
                sourceTab.officeSeatLockReason = nil
                launchCompletionRecipients(
                    for: sourceTab,
                    validationSummary: reviewerTab.lastCompletionSummary,
                    qaSummary: nil,
                    handoffSourceName: reviewerTab.workerName
                )
            } else {
                launchQA(
                    for: sourceTab,
                    reviewSummary: reviewerTab.lastCompletionSummary,
                    handoffSourceName: reviewerTab.workerName
                )
            }
            return
        }

        if summary.contains("REVIEW_STATUS: FAIL") || summary.contains("REVIEW_STATUS: BLOCKED") {
            sourceTab.officeSeatLockReason = nil
            sourceTab.updateWorkflowStage(
                role: .reviewer,
                state: .failed,
                detail: reviewerTab.lastCompletionSummary.isEmpty
                    ? NSLocalizedString("workflow.review.feedback", comment: "")
                    : String(reviewerTab.lastCompletionSummary.prefix(260))
            )
            sourceTab.appendBlock(
                .status(message: NSLocalizedString("workflow.review.fix.needed", comment: "")),
                content: reviewerTab.lastCompletionSummary.isEmpty
                    ? NSLocalizedString("workflow.review.fix.detail", comment: "")
                    : String(reviewerTab.lastCompletionSummary.prefix(260))
            )
            guard sourceTab.automatedRevisionCount < AppSettings.shared.automationRevisionLimit else {
                sourceTab.appendBlock(
                    .status(message: NSLocalizedString("workflow.revision.limit.title", comment: "")),
                    content: String(format: NSLocalizedString("workflow.revision.limit.detail", comment: ""), AppSettings.shared.automationRevisionLimit)
                )
                return
            }
            requestDeveloperRevision(
                for: sourceTab,
                feedback: reviewerTab.lastCompletionSummary,
                from: .reviewer
            )
        }
    }

    private func handleQACompletion(_ qaTab: TerminalTab) {
        guard let sourceId = qaTab.automationSourceTabId,
              let sourceTab = tabs.first(where: { $0.id == sourceId }) else { return }

        sourceTab.workflowQASummary = qaTab.lastCompletionSummary
        let summary = qaTab.lastCompletionSummary.uppercased()
        if summary.contains("QA_STATUS: PASS") {
            sourceTab.officeSeatLockReason = nil
            sourceTab.updateWorkflowStage(
                role: .qa,
                state: .completed,
                detail: qaTab.lastCompletionSummary.isEmpty
                    ? NSLocalizedString("workflow.qa.passed.detail", comment: "")
                    : String(qaTab.lastCompletionSummary.prefix(240))
            )
            launchCompletionRecipients(
                for: sourceTab,
                validationSummary: sourceTab.workflowReviewSummary,
                qaSummary: qaTab.lastCompletionSummary,
                handoffSourceName: qaTab.workerName
            )
            return
        }

        if summary.contains("QA_STATUS: FAIL") || summary.contains("QA_STATUS: BLOCKED") {
            sourceTab.officeSeatLockReason = nil
            sourceTab.updateWorkflowStage(
                role: .qa,
                state: .failed,
                detail: qaTab.lastCompletionSummary.isEmpty
                    ? NSLocalizedString("workflow.qa.failed.detail", comment: "")
                    : String(qaTab.lastCompletionSummary.prefix(240))
            )
            sourceTab.appendBlock(.status(message: NSLocalizedString("workflow.qa.fail.title", comment: "")), content: qaTab.lastCompletionSummary.isEmpty ? NSLocalizedString("workflow.qa.fail.msg", comment: "") : String(qaTab.lastCompletionSummary.prefix(240)))
            guard sourceTab.automatedRevisionCount < AppSettings.shared.automationRevisionLimit else {
                sourceTab.appendBlock(
                    .status(message: NSLocalizedString("workflow.revision.limit.title", comment: "")),
                    content: String(format: NSLocalizedString("workflow.revision.limit.detail", comment: ""), AppSettings.shared.automationRevisionLimit)
                )
                return
            }
            requestDeveloperRevision(
                for: sourceTab,
                feedback: qaTab.lastCompletionSummary,
                from: .qa
            )
        }
    }

    private func handleReporterCompletion(_ reporterTab: TerminalTab) {
        guard let sourceId = reporterTab.automationSourceTabId,
              let sourceTab = tabs.first(where: { $0.id == sourceId }) else { return }

        sourceTab.updateWorkflowStage(
            role: .reporter,
            state: .completed,
            detail: reporterTab.lastCompletionSummary.isEmpty
                ? NSLocalizedString("workflow.reporter.completed.detail", comment: "")
                : String(reporterTab.lastCompletionSummary.prefix(240))
        )
        if let reportPath = reporterTab.automationReportPath {
            sourceTab.automationReportPath = reportPath
            invalidateAvailableReportsCache()
            scheduleAvailableReportCountRefresh()
            sourceTab.appendBlock(
                .status(message: NSLocalizedString("workflow.reporter.report.done", comment: "")),
                content: "Markdown: \(reportPath)"
            )
        } else {
            sourceTab.appendBlock(.status(message: NSLocalizedString("workflow.reporter.done", comment: "")), content: reporterTab.lastCompletionSummary)
        }
    }

    private func handleSRECompletion(_ sreTab: TerminalTab) {
        guard let sourceId = sreTab.automationSourceTabId,
              let sourceTab = tabs.first(where: { $0.id == sourceId }) else { return }

        sourceTab.workflowSRESummary = sreTab.lastCompletionSummary
        sourceTab.updateWorkflowStage(
            role: .sre,
            state: .completed,
            detail: sreTab.lastCompletionSummary.isEmpty
                ? NSLocalizedString("workflow.sre.completed.detail", comment: "")
                : String(sreTab.lastCompletionSummary.prefix(260))
        )
        sourceTab.appendBlock(
            .status(message: NSLocalizedString("workflow.sre.done", comment: "")),
            content: sreTab.lastCompletionSummary.isEmpty
                ? NSLocalizedString("workflow.sre.done.detail", comment: "")
                : String(sreTab.lastCompletionSummary.prefix(260))
        )
    }

    private func launchQA(for sourceTab: TerminalTab, reviewSummary: String?, handoffSourceName: String) {
        if let reason = automationThrottleReason(for: .qa) {
            sourceTab.officeSeatLockReason = nil
            sourceTab.appendBlock(.status(message: NSLocalizedString("workflow.qa.skip.title", comment: "")), content: reason)
            launchCompletionRecipients(
                for: sourceTab,
                validationSummary: reviewSummary ?? sourceTab.workflowReviewSummary,
                qaSummary: nil,
                handoffSourceName: handoffSourceName
            )
            return
        }

        if AppSettings.shared.qaMaxPasses == 0 {
            sourceTab.officeSeatLockReason = nil
            sourceTab.updateWorkflowStage(
                role: .qa,
                state: .skipped,
                detail: NSLocalizedString("workflow.qa.disabled", comment: "")
            )
            sourceTab.appendBlock(.status(message: NSLocalizedString("workflow.qa.skip.title", comment: "")), content: NSLocalizedString("workflow.qa.disabled.detail", comment: ""))
            launchCompletionRecipients(
                for: sourceTab,
                validationSummary: reviewSummary ?? sourceTab.workflowReviewSummary,
                qaSummary: nil,
                handoffSourceName: handoffSourceName
            )
            return
        }

        guard !tabs.contains(where: {
            $0.projectPath == sourceTab.projectPath &&
            $0.workerJob == .qa &&
            $0.isProcessing &&
            $0.automationSourceTabId == sourceTab.id
        }) else { return }

        if sourceTab.qaAttemptCount >= AppSettings.shared.qaMaxPasses {
            sourceTab.officeSeatLockReason = nil
            sourceTab.updateWorkflowStage(
                role: .qa,
                state: .failed,
                detail: String(format: NSLocalizedString("workflow.qa.limit.reached", comment: ""), AppSettings.shared.qaMaxPasses)
            )
            sourceTab.appendBlock(
                .status(message: NSLocalizedString("workflow.qa.limit.title", comment: "")),
                content: String(format: NSLocalizedString("workflow.qa.limit.detail", comment: ""), AppSettings.shared.qaMaxPasses)
            )
            return
        }

        guard let qaCharacter = availableAutomationCharacter(for: .qa, sourceId: sourceTab.id) else {
            sourceTab.officeSeatLockReason = nil
            sourceTab.appendBlock(.status(message: NSLocalizedString("workflow.qa.busy", comment: "")))
            launchCompletionRecipients(
                for: sourceTab,
                validationSummary: reviewSummary ?? sourceTab.workflowReviewSummary,
                qaSummary: nil,
                handoffSourceName: handoffSourceName
            )
            return
        }

        let qaPrompt = buildQAPrompt(for: sourceTab, reviewSummary: reviewSummary)
        let qaTab = startOrReuseAutomationTab(
            role: .qa,
            projectName: "\(sourceTab.projectName) QA",
            projectPath: sourceTab.projectPath,
            prompt: qaPrompt,
            preferredCharacter: qaCharacter,
            automationSourceTabId: sourceTab.id
        )
        sourceTab.qaAttemptCount += 1
        sourceTab.officeSeatLockReason = NSLocalizedString("workflow.qa.waiting", comment: "")
        sourceTab.upsertWorkflowStage(
            role: .qa,
            workerName: qaTab.workerName,
            assigneeCharacterId: qaCharacter.id,
            state: .running,
            handoffLabel: String(format: NSLocalizedString("workflow.handoff.role", comment: ""), handoffSourceName, qaTab.workerName),
            detail: NSLocalizedString("workflow.qa.detail", comment: "")
        )
        let message = reviewSummary == nil ? String(format: NSLocalizedString("workflow.qa.assigned", comment: ""), qaTab.workerName) : NSLocalizedString("workflow.review.pass.qa", comment: "")
        sourceTab.appendBlock(.status(message: message), content: NSLocalizedString("workflow.qa.detail", comment: ""))
    }

    private func dispatchDeveloperFromPreparation(for sourceTab: TerminalTab, handoffSourceName: String) {
        sourceTab.officeSeatLockReason = nil
        sourceTab.upsertWorkflowStage(
            role: .developer,
            workerName: sourceTab.workerName,
            assigneeCharacterId: sourceTab.characterId,
            state: .running,
            handoffLabel: String(format: NSLocalizedString("workflow.handoff.role", comment: ""), handoffSourceName, sourceTab.workerName),
            detail: sourceTab.workflowDesignSummary.isEmpty
                ? NSLocalizedString("workflow.dev.from.plan", comment: "")
                : NSLocalizedString("workflow.dev.from.plan.design", comment: "")
        )
        sourceTab.appendBlock(
            .status(message: NSLocalizedString("workflow.dev.start", comment: "")),
            content: sourceTab.workflowDesignSummary.isEmpty
                ? NSLocalizedString("workflow.dev.start.from.plan", comment: "")
                : NSLocalizedString("workflow.dev.start.from.plan.design", comment: "")
        )
        sourceTab.sendPrompt(
            buildDeveloperExecutionPrompt(for: sourceTab),
            bypassWorkflowRouting: true
        )
    }

    private func requestDeveloperRevision(for sourceTab: TerminalTab, feedback: String, from role: WorkerJob) {
        guard sourceTab.automatedRevisionCount < AppSettings.shared.automationRevisionLimit else {
            sourceTab.officeSeatLockReason = nil
            sourceTab.appendBlock(
                .status(message: NSLocalizedString("workflow.revision.limit.title", comment: "")),
                content: String(format: NSLocalizedString("workflow.revision.limit.stop", comment: ""), AppSettings.shared.automationRevisionLimit)
            )
            return
        }
        sourceTab.automatedRevisionCount += 1
        sourceTab.upsertWorkflowStage(
            role: .developer,
            workerName: sourceTab.workerName,
            assigneeCharacterId: sourceTab.characterId,
            state: .running,
            handoffLabel: String(format: NSLocalizedString("workflow.handoff.role", comment: ""), role.displayName, sourceTab.workerName),
            detail: NSLocalizedString("workflow.revision.detail", comment: "")
        )
        sourceTab.appendBlock(
            .status(message: String(format: NSLocalizedString("workflow.revision.feedback", comment: ""), role.displayName)),
            content: NSLocalizedString("workflow.revision.feedback.detail", comment: "")
        )
        sourceTab.sendPrompt(
            buildDeveloperRevisionPrompt(for: sourceTab, feedback: feedback, from: role),
            bypassWorkflowRouting: true
        )
    }

    private func launchCompletionRecipients(
        for sourceTab: TerminalTab,
        validationSummary: String?,
        qaSummary: String?,
        handoffSourceName: String
    ) {
        let reporterCharacter = automationThrottleReason(for: .reporter) == nil
            ? availableAutomationCharacter(for: .reporter, sourceId: sourceTab.id)
            : nil
        let sreCharacter = automationThrottleReason(for: .sre) == nil
            ? availableAutomationCharacter(for: .sre, sourceId: sourceTab.id)
            : nil
        var launchedAny = false

        if let reporterCharacter,
           !tabs.contains(where: {
               $0.projectPath == sourceTab.projectPath &&
               $0.workerJob == .reporter &&
               $0.isProcessing &&
               $0.automationSourceTabId == sourceTab.id
           }) {
            let reportPath = makeReportPath(for: sourceTab)
            ensureReportDirectoryExists(for: reportPath)
            let reporterPrompt = buildReporterPrompt(
                for: sourceTab,
                qaSummary: qaSummary,
                validationSummary: validationSummary,
                reportPath: reportPath
            )
            let reporterTab = startOrReuseAutomationTab(
                role: .reporter,
                projectName: "\(sourceTab.projectName) Report",
                projectPath: sourceTab.projectPath,
                prompt: reporterPrompt,
                preferredCharacter: reporterCharacter,
                automationSourceTabId: sourceTab.id,
                automationReportPath: reportPath
            )
            sourceTab.automationReportPath = reportPath
            sourceTab.upsertWorkflowStage(
                role: .reporter,
                workerName: reporterTab.workerName,
                assigneeCharacterId: reporterCharacter.id,
                state: .running,
                handoffLabel: String(format: NSLocalizedString("workflow.handoff.role", comment: ""), handoffSourceName, reporterTab.workerName),
                detail: NSLocalizedString("workflow.reporter.detail", comment: "")
            )
            sourceTab.appendBlock(
                .status(message: String(format: NSLocalizedString("workflow.reporter.assigned", comment: ""), reporterTab.workerName)),
                content: NSLocalizedString("workflow.reporter.assigned.detail", comment: "")
            )
            launchedAny = true
        }

        if let sreCharacter,
           !tabs.contains(where: {
               $0.projectPath == sourceTab.projectPath &&
               $0.workerJob == .sre &&
               $0.isProcessing &&
               $0.automationSourceTabId == sourceTab.id
           }) {
            let srePrompt = buildSREPrompt(for: sourceTab, qaSummary: qaSummary, validationSummary: validationSummary)
            let sreTab = startOrReuseAutomationTab(
                role: .sre,
                projectName: "\(sourceTab.projectName) SRE",
                projectPath: sourceTab.projectPath,
                prompt: srePrompt,
                preferredCharacter: sreCharacter,
                automationSourceTabId: sourceTab.id
            )
            sourceTab.upsertWorkflowStage(
                role: .sre,
                workerName: sreTab.workerName,
                assigneeCharacterId: sreCharacter.id,
                state: .running,
                handoffLabel: String(format: NSLocalizedString("workflow.handoff.role", comment: ""), handoffSourceName, sreTab.workerName),
                detail: NSLocalizedString("workflow.sre.detail", comment: "")
            )
            sourceTab.appendBlock(
                .status(message: String(format: NSLocalizedString("workflow.sre.assigned", comment: ""), sreTab.workerName)),
                content: NSLocalizedString("workflow.sre.assigned.detail", comment: "")
            )
            launchedAny = true
        }

        if !launchedAny {
            if let reporterReason = automationThrottleReason(for: .reporter) {
                sourceTab.appendBlock(.status(message: NSLocalizedString("workflow.report.skip", comment: "")), content: reporterReason)
            }
            if let sreReason = automationThrottleReason(for: .sre) {
                sourceTab.appendBlock(.status(message: NSLocalizedString("workflow.sre.skip", comment: "")), content: sreReason)
            }
            sourceTab.appendBlock(
                .status(message: NSLocalizedString("workflow.completion.done", comment: "")),
                content: NSLocalizedString("workflow.completion.no.roles", comment: "")
            )
        }
    }

    private func templateValue(_ text: String, fallback: String) -> String {
        text.isEmpty ? fallback : text
    }

    private func templateFileList(_ paths: [String], fallback: String) -> String {
        let unique = Array(Set(paths)).sorted()
        return unique.isEmpty ? fallback : unique.map { "- \($0)" }.joined(separator: "\n")
    }

    private func buildPlannerPrompt(for tab: TerminalTab, request: String) -> String {
        AutomationTemplateStore.shared.render(
            .planner,
            context: [
                "project_name": tab.projectName,
                "project_path": tab.projectPath,
                "request": templateValue(request, fallback: NSLocalizedString("workflow.request.none", comment: ""))
            ]
        )
    }

    private func buildDesignerPrompt(for tab: TerminalTab) -> String {
        AutomationTemplateStore.shared.render(
            .designer,
            context: [
                "project_name": tab.projectName,
                "project_path": tab.projectPath,
                "request": templateValue(tab.workflowRequirementText, fallback: NSLocalizedString("workflow.request.none", comment: "")),
                "plan_summary": templateValue(tab.workflowPlanSummary, fallback: NSLocalizedString("workflow.plan.summary.none", comment: ""))
            ]
        )
    }

    private func buildDeveloperExecutionPrompt(for tab: TerminalTab) -> String {
        AutomationTemplateStore.shared.render(
            .developerExecution,
            context: [
                "project_name": tab.projectName,
                "project_path": tab.projectPath,
                "request": templateValue(tab.workflowRequirementText, fallback: NSLocalizedString("workflow.request.none", comment: "")),
                "plan_summary": templateValue(tab.workflowPlanSummary, fallback: NSLocalizedString("workflow.plan.summary.none", comment: "")),
                "design_summary": templateValue(tab.workflowDesignSummary, fallback: NSLocalizedString("workflow.design.memo.none", comment: ""))
            ]
        )
    }

    private func buildDeveloperRevisionPrompt(for tab: TerminalTab, feedback: String, from role: WorkerJob) -> String {
        AutomationTemplateStore.shared.render(
            .developerRevision,
            context: [
                "project_name": tab.projectName,
                "project_path": tab.projectPath,
                "request": templateValue(tab.workflowRequirementText, fallback: NSLocalizedString("workflow.request.none", comment: "")),
                "plan_summary": templateValue(tab.workflowPlanSummary, fallback: NSLocalizedString("workflow.plan.summary.none", comment: "")),
                "design_summary": templateValue(tab.workflowDesignSummary, fallback: NSLocalizedString("workflow.design.memo.none", comment: "")),
                "feedback_role": role.displayName,
                "feedback": templateValue(feedback, fallback: NSLocalizedString("workflow.feedback.none", comment: ""))
            ]
        )
    }

    private func buildReviewPrompt(for tab: TerminalTab) -> String {
        AutomationTemplateStore.shared.render(
            .reviewer,
            context: [
                "project_name": tab.projectName,
                "project_path": tab.projectPath,
                "request": templateValue(tab.workflowRequirementText, fallback: NSLocalizedString("workflow.request.none.review", comment: "")),
                "plan_summary": templateValue(tab.workflowPlanSummary, fallback: NSLocalizedString("workflow.plan.summary.none", comment: "")),
                "design_summary": templateValue(tab.workflowDesignSummary, fallback: NSLocalizedString("workflow.design.summary.none", comment: "")),
                "dev_summary": templateValue(tab.lastCompletionSummary, fallback: NSLocalizedString("workflow.dev.summary.none", comment: "")),
                "changed_files": templateFileList(tab.fileChanges.suffix(10).map(\.path), fallback: NSLocalizedString("workflow.files.none", comment: ""))
            ]
        )
    }

    private func buildQAPrompt(for tab: TerminalTab, reviewSummary: String?) -> String {
        AutomationTemplateStore.shared.render(
            .qa,
            context: [
                "project_name": tab.projectName,
                "project_path": tab.projectPath,
                "request": templateValue(tab.workflowRequirementText, fallback: NSLocalizedString("workflow.qa.no.requirements", comment: "")),
                "plan_summary": templateValue(tab.workflowPlanSummary, fallback: NSLocalizedString("workflow.plan.summary.none", comment: "")),
                "design_summary": templateValue(tab.workflowDesignSummary, fallback: NSLocalizedString("workflow.design.summary.none", comment: "")),
                "dev_summary": templateValue(tab.lastCompletionSummary, fallback: NSLocalizedString("workflow.dev.summary.none", comment: "")),
                "review_summary": templateValue(reviewSummary ?? "", fallback: NSLocalizedString("workflow.review.summary.none", comment: "")),
                "changed_files": templateFileList(tab.fileChanges.suffix(8).map(\.path), fallback: NSLocalizedString("workflow.files.none", comment: ""))
            ]
        )
    }

    private func buildReporterPrompt(for sourceTab: TerminalTab, qaSummary: String?, validationSummary: String?, reportPath: String) -> String {
        AutomationTemplateStore.shared.render(
            .reporter,
            context: [
                "project_name": sourceTab.projectName,
                "project_path": sourceTab.projectPath,
                "report_path": reportPath,
                "request": templateValue(sourceTab.workflowRequirementText, fallback: NSLocalizedString("workflow.request.none", comment: "")),
                "plan_summary": templateValue(sourceTab.workflowPlanSummary, fallback: NSLocalizedString("workflow.plan.summary.none", comment: "")),
                "design_summary": templateValue(sourceTab.workflowDesignSummary, fallback: NSLocalizedString("workflow.design.summary.none", comment: "")),
                "dev_summary": templateValue(sourceTab.lastCompletionSummary, fallback: NSLocalizedString("workflow.dev.completion.none", comment: "")),
                "review_summary": templateValue(sourceTab.workflowReviewSummary, fallback: NSLocalizedString("workflow.review.summary.report.none", comment: "")),
                "qa_summary": templateValue(qaSummary ?? "", fallback: NSLocalizedString("workflow.qa.summary.none", comment: "")),
                "validation_summary": templateValue(validationSummary ?? "", fallback: NSLocalizedString("workflow.validation.none", comment: "")),
                "changed_files": templateFileList(sourceTab.fileChanges.map(\.path), fallback: NSLocalizedString("workflow.files.changed.none", comment: ""))
            ]
        )
    }

    private func buildSREPrompt(for sourceTab: TerminalTab, qaSummary: String?, validationSummary: String?) -> String {
        AutomationTemplateStore.shared.render(
            .sre,
            context: [
                "project_name": sourceTab.projectName,
                "project_path": sourceTab.projectPath,
                "request": templateValue(sourceTab.workflowRequirementText, fallback: NSLocalizedString("workflow.request.none", comment: "")),
                "dev_summary": templateValue(sourceTab.lastCompletionSummary, fallback: NSLocalizedString("workflow.dev.completion.none", comment: "")),
                "qa_summary": templateValue(qaSummary ?? "", fallback: NSLocalizedString("workflow.qa.summary.none", comment: "")),
                "validation_summary": templateValue(validationSummary ?? "", fallback: NSLocalizedString("workflow.validation.none", comment: "")),
                "changed_files": templateFileList(sourceTab.fileChanges.map(\.path), fallback: NSLocalizedString("workflow.files.changed.none", comment: ""))
            ]
        )
    }

    private func makeReportPath(for tab: TerminalTab) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let safeProjectName = tab.projectName
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9_-]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        let fileName = "\(formatter.string(from: Date()))-\(safeProjectName.isEmpty ? "report" : safeProjectName)-report.md"
        return (tab.projectPath as NSString).appendingPathComponent(".doffice/reports/\(fileName)")
    }

    private func ensureReportDirectoryExists(for reportPath: String) {
        let directory = (reportPath as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true, attributes: nil)
    }

    func availableReports() -> [ReportReference] {
        dispatchPrecondition(condition: .onQueue(.main))
        let currentProjects = userVisibleTabs.map { ($0.projectName, $0.projectPath) }
        let savedProjects = SessionStore.shared.load().map { ($0.projectName, $0.projectPath) }
        let signature = availableReportsSignature(currentProjects: currentProjects, savedProjects: savedProjects)
        let now = Date().timeIntervalSinceReferenceDate
        if cachedAvailableReportsSignature == signature, now - cachedAvailableReportsAt < 4 {
            return cachedAvailableReports
        }

        var uniqueProjects: [(String, String)] = []
        var seenPaths = Set<String>()
        for (projectName, projectPath) in currentProjects + savedProjects {
            guard seenPaths.insert(projectPath).inserted else { continue }
            uniqueProjects.append((projectName, projectPath))
        }

        var references: [ReportReference] = []
        for (projectName, projectPath) in uniqueProjects {
            let reportsDir = (projectPath as NSString).appendingPathComponent(".doffice/reports")
            guard let files = try? FileManager.default.contentsOfDirectory(atPath: reportsDir) else { continue }

            for file in files where file.hasSuffix(".md") {
                let fullPath = (reportsDir as NSString).appendingPathComponent(file)
                let attrs = try? FileManager.default.attributesOfItem(atPath: fullPath)
                let updatedAt = attrs?[.modificationDate] as? Date ?? .distantPast
                references.append(
                    ReportReference(
                        id: fullPath,
                        projectName: projectName,
                        projectPath: projectPath,
                        path: fullPath,
                        updatedAt: updatedAt
                    )
                )
            }
        }

        let sorted = references.sorted { lhs, rhs in
            if lhs.updatedAt != rhs.updatedAt { return lhs.updatedAt > rhs.updatedAt }
            return lhs.path.localizedCaseInsensitiveCompare(rhs.path) == .orderedAscending
        }
        cachedAvailableReports = sorted
        cachedAvailableReportsSignature = signature
        cachedAvailableReportsAt = now
        availableReportCount = sorted.count
        return sorted
    }

    // Feature 4: 세션 저장 (빈 자동화 탭 제외)
    func saveSessions(immediately: Bool = false) {
        let savableTabs = userVisibleTabs.filter { tab in
            // 사용자가 직접 추가한 세션(manualLaunch)은 항상 저장
            if tab.manualLaunch { return true }
            // 토큰 사용 없고, 완료되지 않았고, 처리 중도 아닌 빈 자동 탭은 저장하지 않음
            if tab.tokensUsed == 0 && !tab.isCompleted && !tab.isProcessing && tab.completedPromptCount == 0 {
                return false
            }
            return true
        }
        SessionStore.shared.save(tabs: savableTabs, immediately: immediately)
    }

    // Feature 4: 세션 복원 (이전 기록에서 경로 로드 - 같은 프로젝트 여러 탭 지원)
    func restoreSessions() {
        let saved = SessionStore.shared.load()
            .sorted { ($0.tabOrder ?? Int.max) < ($1.tabOrder ?? Int.max) }
        var interruptedSessions: [SavedSession] = []
        var recoveryBundles: [URL] = []

        // 워크플로우 자동 생성 탭 키워드 (Plan, Review, QA, Report 등이 중첩된 이름)
        let workflowSuffixes = ["Plan", "Review", "QA", "Report"]

        for session in saved {
            // 완료된 세션은 복원하지 않음
            guard !session.isCompleted && FileManager.default.fileExists(atPath: session.projectPath) else { continue }

            // 토큰 사용 없고 프롬프트도 없는 빈 자동 세션은 건너뜀 (사용자 추가 세션은 유지)
            let isManualSession = session.manualLaunch ?? false
            if !isManualSession &&
               session.tokensUsed == 0 &&
                (session.initialPrompt == nil || session.initialPrompt?.isEmpty == true) &&
                (session.lastPrompt == nil || session.lastPrompt?.isEmpty == true) &&
                session.wasProcessing != true {
                continue
            }

            // 워크플로우 자동 생성 탭 필터링 (이름에 Plan/Review/QA/Report가 2개 이상 포함)
            let suffixCount = workflowSuffixes.reduce(0) { count, suffix in
                count + session.projectName.components(separatedBy: " ").filter { $0 == suffix }.count
            }
            if suffixCount >= 2 {
                continue
            }

            // 강제 종료로 중단된 세션 감지
            if session.wasProcessing == true {
                interruptedSessions.append(session)
            }

            let recoveryBundleURL: URL?
            if session.wasProcessing == true {
                recoveryBundleURL = SessionStore.shared.writeRecoveryBundle(
                    for: session,
                    reason: "앱 복원 중 중단된 세션 백업"
                )
                if let recoveryBundleURL {
                    recoveryBundles.append(recoveryBundleURL)
                }
            } else {
                recoveryBundleURL = nil
            }

            let tab = addTab(
                projectName: session.projectName,
                projectPath: session.projectPath,
                branch: session.branch,
                initialPrompt: nil,
                autoStart: false,
                restoredSession: session
            )
            tab.applySavedSessionConfiguration(session)
            tab.restoreSavedSessionSnapshot(session)
            tab.appendRestorationNotice(from: session, recoveryBundleURL: recoveryBundleURL)
        }

        // 강제 종료로 중단된 작업이 있으면 알림
        if !interruptedSessions.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.showInterruptedSessionsAlert(interruptedSessions, recoveryBundles: recoveryBundles)
            }
        }
    }

    private func showInterruptedSessionsAlert(_ sessions: [SavedSession], recoveryBundles: [URL]) {
        let alert = NSAlert()
        let names = sessions.map { $0.projectName }.joined(separator: ", ")
        alert.messageText = String(format: NSLocalizedString("recovery.alert.title", comment: ""), sessions.count)
        alert.informativeText = String(format: NSLocalizedString("recovery.alert.message", comment: ""), names)
        alert.alertStyle = .warning
        if !recoveryBundles.isEmpty {
            alert.addButton(withTitle: NSLocalizedString("recovery.show.folder", comment: ""))
        }
        alert.addButton(withTitle: NSLocalizedString("recovery.ok", comment: ""))

        let response = alert.runModal()
        if !recoveryBundles.isEmpty && response == .alertFirstButtonReturn {
            NSWorkspace.shared.activateFileViewerSelecting(recoveryBundles)
        }
    }

    /// Cmd+R: 전체 새로고침 - 기존 탭 정리 후 다시 스캔
    func refresh() {
        saveSessions() // 새로고침 전 저장

        // 사용자가 직접 추가한 세션은 보존, 자동 감지 세션만 정리
        let manualTabs = tabs.filter { $0.manualLaunch }
        let autoTabs = tabs.filter { !$0.manualLaunch }

        for tab in autoTabs {
            tab.stop()
        }

        tabs = manualTabs
        if !tabs.contains(where: { $0.id == activeTabId }) {
            activeTabId = tabs.first?.id
        }

        // 사용자 세션은 모드 전환 시 재시작 (안전하게 상태 리셋 후)
        for tab in manualTabs {
            if !tab.isCompleted {
                tab.forceStop()
                tab.start()
            }
        }

        invalidateProjectGroupsCache()
        invalidateAvailableReportsCache()
        scheduleAvailableReportCountRefresh()
        updateTabDerivedCaches()

        // 자동 감지 다시 스캔
        autoDetectAndConnect()
    }

    func stopScanning() {
        scanTimer?.invalidate()
        scanTimer = nil
    }

    func scheduleAvailableReportCountRefresh() {
        reportScanWorkItem?.cancel()

        let currentProjects = userVisibleTabs.map { ($0.projectName, $0.projectPath) }
        let savedProjects = SessionStore.shared.load().map { ($0.projectName, $0.projectPath) }
        let signature = availableReportsSignature(currentProjects: currentProjects, savedProjects: savedProjects)

        if cachedAvailableReportsSignature == signature {
            availableReportCount = cachedAvailableReports.count
            return
        }

        let refreshToken = UUID()
        reportRefreshToken = refreshToken
        let workItem = DispatchWorkItem { [weak self] in
            let count = Self.computeReportCount(currentProjects: currentProjects, savedProjects: savedProjects)
            DispatchQueue.main.async {
                guard let self = self,
                      self.reportRefreshToken == refreshToken else { return }
                if self.cachedAvailableReportsSignature == signature {
                    self.availableReportCount = self.cachedAvailableReports.count
                } else {
                    self.availableReportCount = count
                }
            }
        }
        reportScanWorkItem = workItem
        reportScanQueue.async(execute: workItem)
    }

    private func availableReportsSignature(
        currentProjects: [(String, String)],
        savedProjects: [(String, String)]
    ) -> Int {
        var hasher = Hasher()
        for pair in (currentProjects + savedProjects).sorted(by: { $0.1 < $1.1 }) {
            hasher.combine(pair.0)
            hasher.combine(pair.1)
        }
        return hasher.finalize()
    }

    private static func computeReportCount(
        currentProjects: [(String, String)],
        savedProjects: [(String, String)]
    ) -> Int {
        var uniqueProjects: [(String, String)] = []
        var seenPaths = Set<String>()
        for (projectName, projectPath) in currentProjects + savedProjects {
            guard seenPaths.insert(projectPath).inserted else { continue }
            uniqueProjects.append((projectName, projectPath))
        }

        var count = 0
        for (_, projectPath) in uniqueProjects {
            let reportsDir = (projectPath as NSString).appendingPathComponent(".doffice/reports")
            guard let files = try? FileManager.default.contentsOfDirectory(atPath: reportsDir) else { continue }
            count += files.filter { $0.hasSuffix(".md") }.count
        }
        return count
    }

    // MARK: - Shell Helper

    private func shell(_ command: String) -> String? {
        let process = Process()
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-f", "-c", command]
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = TerminalTab.buildFullPATH()
        process.environment = env

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)
            return output?.isEmpty == true ? nil : output
        } catch {
            return nil
        }
    }
}
