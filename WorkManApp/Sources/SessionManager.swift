import SwiftUI
import Darwin
import AppKit

class SessionManager: ObservableObject {
    static let shared = SessionManager()

    @Published var tabs: [TerminalTab] = []
    @Published var activeTabId: String?
    @Published var showNewTabSheet: Bool = false
    @Published var groups: [SessionGroup] = []
    @Published var selectedGroupPath: String? = nil  // nil = 전체 보기
    @Published var focusSingleTab: Bool = false       // 개별 워커 포커스
    @Published private(set) var availableReportCount: Int = 0

    var totalTokensUsed: Int {
        tabs.reduce(0) { $0 + $1.tokensUsed }
    }

    var userVisibleTabs: [TerminalTab] {
        tabs.filter { $0.automationSourceTabId == nil }
    }

    var userVisibleTabCount: Int {
        userVisibleTabs.count
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
    private let reportScanQueue = DispatchQueue(label: "workman.report-count", qos: .utility)
    private var reportScanWorkItem: DispatchWorkItem?
    private var reportRefreshToken = UUID()
    private var isAppActive = true

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
            forName: .workmanTabCycleCompleted,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let tab = notification.object as? TerminalTab else { return }
            self?.handleTabCycleCompleted(tab)
        }
        sessionStoreObserver = NotificationCenter.default.addObserver(
            forName: .workmanSessionStoreDidChange,
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

        // 30초마다 자동 저장 (강제 종료 대비)
        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.saveSessions()
        }
    }

    deinit {
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

            // WorkManApp 자체가 spawn한 프로세스 제외 (ppid 확인)
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
                    }
                    // 세션 수 업데이트
                    tab.sessionCount = projectSessionCount[tab.projectPath] ?? tab.sessionCount
                }

                // 새 세션 추가
                for session in detected {
                    if !self.tabs.contains(where: { $0.projectPath == session.path }) {
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
    func addTab(projectName: String, projectPath: String, isClaude: Bool = false, detectedPid: Int? = nil, sessionCount: Int = 1, branch: String? = nil, initialPrompt: String? = nil, preferredCharacterId: String? = nil, automationSourceTabId: String? = nil, automationReportPath: String? = nil, manualLaunch: Bool = false) -> TerminalTab {
        let registry = CharacterRegistry.shared
        let occupiedIds = occupiedCharacterIds()
        let availableDevelopers = registry.hiredCharacters(for: .developer).filter {
            !$0.isOnVacation && !occupiedIds.contains($0.id)
        }

        let name: String
        let color: Color
        let characterId: String?

        if let preferred = registry.character(with: preferredCharacterId),
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
            id: UUID().uuidString,
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

        tabs.append(tab)
        invalidateProjectGroupsCache()
        invalidateAvailableReportsCache()
        scheduleAvailableReportCountRefresh()
        if activeTabId == nil {
            activeTabId = tab.id
        }
        workerIndex += 1

        tab.start()
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
            message = "직원은 최대 \(CharacterRegistry.maxHiredCount)명까지 권장합니다. 지금은 더 이상 새 터미널에 배정할 수 없습니다."
        } else if manualLaunchCapacity == 0 {
            message = "지금 바로 투입 가능한 직원이 없습니다. 현재 작업이 끝난 뒤 다시 시도해주세요."
        } else {
            message = "현재 바로 배정 가능한 직원은 \(manualLaunchCapacity)명뿐입니다. 요청한 \(requested)개 전체를 동시에 만들 수 없습니다."
        }

        NotificationCenter.default.post(
            name: .workmanRoleNotice,
            object: nil,
            userInfo: [
                "title": "터미널 추가 제한",
                "message": message
            ]
        )
    }

    func removeTab(_ id: String) {
        if let tab = tabs.first(where: { $0.id == id }) {
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
        if activeTabId == id {
            activeTabId = userVisibleTabs.last?.id
        }
    }

    func selectTab(_ id: String) {
        activeTabId = id
        invalidateProjectGroupsCache()
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
            handoffLabel: "사용자 → \(tab.workerName)",
            detail: "사용자 요구사항을 받아 개발을 시작합니다."
        )
    }

    func routePromptIfNeeded(for tab: TerminalTab, prompt: String) -> Bool {
        guard tab.workerJob == .developer,
              tab.automationSourceTabId == nil,
              !tab.isProcessing else {
            return false
        }

        if let reason = automationThrottleReason(for: .planner) {
            tab.appendBlock(.status(message: "토큰 보호 모드"), content: reason)
            return false
        }

        guard let plannerCharacter = availableAutomationCharacter(for: .planner, sourceId: tab.id) else {
            if !CharacterRegistry.shared.hiredCharacters(for: .planner).isEmpty {
                tab.appendBlock(.status(message: "기획자 대기 중"), content: "지금 비어 있는 기획자가 없어 이번 작업은 개발자가 바로 이어받습니다.")
            }
            return false
        }

        guard !hasAutomationInFlight(for: tab.id, roles: [.planner, .designer, .reviewer, .qa, .reporter, .sre]) else {
            tab.appendBlock(
                .status(message: "협업 단계 진행 중"),
                content: "현재 다른 역할이 이 작업을 정리하고 있습니다. 완료 후 개발자에게 전달됩니다."
            )
            return true
        }

        tab.resetWorkflowTracking(request: prompt)
        tab.officeSeatLockReason = "기획 정리 대기"
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
            handoffLabel: "사용자 → \(plannerTab.workerName)",
            detail: "기획자가 요구사항을 정리하고 필요하면 디자이너와 협의합니다."
        )

        tab.appendBlock(
            .status(message: "기획자 투입: \(plannerTab.workerName)"),
            content: "기획자가 요구사항을 정리하고 필요하면 디자이너와 협의한 뒤 개발자에게 전달합니다."
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
            return "토큰 사용량이 높아 자동 \(role.displayName) 단계를 잠시 줄였습니다."
        }

        let conservativeRoles: Set<WorkerJob> = [.planner, .designer, .reporter, .sre]
        let conserve = tracker.dailyUsagePercent >= 0.75 ||
            tracker.weeklyUsagePercent >= 0.75 ||
            tracker.dailyRemaining < 80_000 ||
            tracker.weeklyRemaining < 250_000
        if conserve && conservativeRoles.contains(role) {
            return "토큰 사용량 절약을 위해 자동 \(role.displayName) 단계를 생략합니다."
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
            automationReportPath: automationReportPath
        )
        applyAutomationSettings(to: tab, role: role)
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
                ? "기획 정리가 완료되었습니다."
                : String(plannerTab.lastCompletionSummary.prefix(260))
        )
        sourceTab.appendBlock(
            .status(message: "기획 완료"),
            content: plannerTab.lastCompletionSummary.isEmpty
                ? "기획자가 요구사항과 수용 기준을 정리했습니다."
                : String(plannerTab.lastCompletionSummary.prefix(260))
        )

        if let reason = automationThrottleReason(for: .designer) {
            sourceTab.appendBlock(.status(message: "디자인 단계 생략"), content: reason)
        } else if let designerCharacter = availableAutomationCharacter(for: .designer, sourceId: sourceId),
                  !hasAutomationInFlight(for: sourceId, roles: [.designer]) {
            sourceTab.officeSeatLockReason = "디자인 협의 대기"
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
                handoffLabel: "\(plannerTab.workerName) → \(designerTab.workerName)",
                detail: "기획 정리 결과를 바탕으로 UI/UX와 표현 방향을 정리합니다."
            )
            sourceTab.appendBlock(
                .status(message: "디자이너 투입: \(designerTab.workerName)"),
                content: "디자이너가 화면 흐름과 상호작용 포인트를 정리합니다."
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
                ? "디자인 협의가 완료되었습니다."
                : String(designerTab.lastCompletionSummary.prefix(260))
        )
        sourceTab.appendBlock(
            .status(message: "디자인 협의 완료"),
            content: designerTab.lastCompletionSummary.isEmpty
                ? "디자이너가 UI/UX 보강 포인트를 정리했습니다."
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
                detail: "코드 수정 없이 답변을 마쳤습니다."
            )
            tab.appendBlock(.status(message: "검토 단계 스킵 · 코드 수정 없음"))
            launchCompletionRecipients(
                for: tab,
                validationSummary: "코드 수정 없음",
                qaSummary: nil,
                handoffSourceName: tab.workerName
            )
            return
        }

        tab.updateWorkflowStage(
            role: .developer,
            state: .completed,
            detail: "구현을 마치고 검토 단계로 넘깁니다."
        )

        if let reason = automationThrottleReason(for: .reviewer) {
            tab.appendBlock(.status(message: "리뷰 단계 생략"), content: reason)
            launchQA(for: tab, reviewSummary: nil, handoffSourceName: tab.workerName)
            return
        }

        if AppSettings.shared.reviewerMaxPasses == 0 {
            tab.updateWorkflowStage(
                role: .reviewer,
                state: .skipped,
                detail: "설정에서 코드 리뷰 자동 단계를 비활성화했습니다."
            )
            tab.appendBlock(.status(message: "리뷰 단계 생략"), content: "설정에서 코드 리뷰 자동 단계를 끄셨습니다.")
            launchQA(for: tab, reviewSummary: nil, handoffSourceName: tab.workerName)
            return
        }

        if tab.reviewerAttemptCount >= AppSettings.shared.reviewerMaxPasses {
            tab.officeSeatLockReason = nil
            tab.updateWorkflowStage(
                role: .reviewer,
                state: .failed,
                detail: "코드 리뷰 자동 한도(\(AppSettings.shared.reviewerMaxPasses)회)에 도달했습니다."
            )
            tab.appendBlock(
                .status(message: "리뷰 자동 한도 도달"),
                content: "코드 리뷰어가 최대 \(AppSettings.shared.reviewerMaxPasses)회까지 검토했습니다. 토큰 보호를 위해 자동 재검토를 중단합니다."
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
            tab.officeSeatLockReason = "코드 리뷰 대기"
            tab.upsertWorkflowStage(
                role: .reviewer,
                workerName: reviewTab.workerName,
                assigneeCharacterId: reviewerCharacter.id,
                state: .running,
                handoffLabel: "\(tab.workerName) → \(reviewTab.workerName)",
                detail: "리뷰어가 변경 파일과 리스크를 검토합니다."
            )
            tab.appendBlock(.status(message: "코드 리뷰 투입: \(reviewTab.workerName)"), content: "리뷰어가 변경 파일과 리스크를 먼저 확인합니다.")
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
                    ? "리뷰가 통과되었습니다."
                    : String(reviewerTab.lastCompletionSummary.prefix(240))
            )
            sourceTab.appendBlock(
                .status(message: "리뷰 통과"),
                content: reviewerTab.lastCompletionSummary.isEmpty
                    ? "리뷰어가 치명적인 문제를 찾지 못했습니다."
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
                    ? "리뷰 피드백이 발생했습니다."
                    : String(reviewerTab.lastCompletionSummary.prefix(260))
            )
            sourceTab.appendBlock(
                .status(message: "리뷰 수정 필요"),
                content: reviewerTab.lastCompletionSummary.isEmpty
                    ? "리뷰어가 수정이 필요한 이슈를 남겼습니다."
                    : String(reviewerTab.lastCompletionSummary.prefix(260))
            )
            guard sourceTab.automatedRevisionCount < AppSettings.shared.automationRevisionLimit else {
                sourceTab.appendBlock(
                    .status(message: "자동 재작업 한도 도달"),
                    content: "자동 재작업은 최대 \(AppSettings.shared.automationRevisionLimit)회까지만 진행합니다. 추가 검토는 수동으로 진행해주세요."
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
                    ? "QA가 통과되었습니다."
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
                    ? "QA에서 이슈를 발견했습니다."
                    : String(qaTab.lastCompletionSummary.prefix(240))
            )
            sourceTab.appendBlock(.status(message: "QA 미통과"), content: qaTab.lastCompletionSummary.isEmpty ? "QA가 이슈를 발견했습니다." : String(qaTab.lastCompletionSummary.prefix(240)))
            guard sourceTab.automatedRevisionCount < AppSettings.shared.automationRevisionLimit else {
                sourceTab.appendBlock(
                    .status(message: "자동 재작업 한도 도달"),
                    content: "자동 재작업은 최대 \(AppSettings.shared.automationRevisionLimit)회까지만 진행합니다. 추가 검토는 수동으로 진행해주세요."
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
                ? "최종 보고서 작성이 완료되었습니다."
                : String(reporterTab.lastCompletionSummary.prefix(240))
        )
        if let reportPath = reporterTab.automationReportPath {
            sourceTab.automationReportPath = reportPath
            invalidateAvailableReportsCache()
            scheduleAvailableReportCountRefresh()
            sourceTab.appendBlock(
                .status(message: "보고서 작성 완료"),
                content: "Markdown: \(reportPath)"
            )
        } else {
            sourceTab.appendBlock(.status(message: "보고자 완료"), content: reporterTab.lastCompletionSummary)
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
                ? "SRE 검토가 완료되었습니다."
                : String(sreTab.lastCompletionSummary.prefix(260))
        )
        sourceTab.appendBlock(
            .status(message: "SRE 검토 완료"),
            content: sreTab.lastCompletionSummary.isEmpty
                ? "SRE가 운영/배포 관점 점검을 마쳤습니다."
                : String(sreTab.lastCompletionSummary.prefix(260))
        )
    }

    private func launchQA(for sourceTab: TerminalTab, reviewSummary: String?, handoffSourceName: String) {
        if let reason = automationThrottleReason(for: .qa) {
            sourceTab.officeSeatLockReason = nil
            sourceTab.appendBlock(.status(message: "QA 단계 생략"), content: reason)
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
                detail: "설정에서 QA 자동 단계를 비활성화했습니다."
            )
            sourceTab.appendBlock(.status(message: "QA 단계 생략"), content: "설정에서 QA 자동 단계를 끄셨습니다.")
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
                detail: "QA 자동 한도(\(AppSettings.shared.qaMaxPasses)회)에 도달했습니다."
            )
            sourceTab.appendBlock(
                .status(message: "QA 자동 한도 도달"),
                content: "QA는 최대 \(AppSettings.shared.qaMaxPasses)회까지만 자동으로 재시도합니다. 토큰 보호를 위해 자동 테스트를 중단합니다."
            )
            return
        }

        guard let qaCharacter = availableAutomationCharacter(for: .qa, sourceId: sourceTab.id) else {
            sourceTab.officeSeatLockReason = nil
            sourceTab.appendBlock(.status(message: "QA 담당자가 없거나 바쁩니다"))
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
        sourceTab.officeSeatLockReason = "QA 검토 대기"
        sourceTab.upsertWorkflowStage(
            role: .qa,
            workerName: qaTab.workerName,
            assigneeCharacterId: qaCharacter.id,
            state: .running,
            handoffLabel: "\(handoffSourceName) → \(qaTab.workerName)",
            detail: "QA가 변경된 기능을 직접 테스트합니다."
        )
        let message = reviewSummary == nil ? "QA 투입: \(qaTab.workerName)" : "리뷰 통과 · QA 투입"
        sourceTab.appendBlock(.status(message: message), content: "QA가 변경된 기능을 직접 테스트합니다.")
    }

    private func dispatchDeveloperFromPreparation(for sourceTab: TerminalTab, handoffSourceName: String) {
        sourceTab.officeSeatLockReason = nil
        sourceTab.upsertWorkflowStage(
            role: .developer,
            workerName: sourceTab.workerName,
            assigneeCharacterId: sourceTab.characterId,
            state: .running,
            handoffLabel: "\(handoffSourceName) → \(sourceTab.workerName)",
            detail: sourceTab.workflowDesignSummary.isEmpty
                ? "기획 정리 내용을 바탕으로 개발을 진행합니다."
                : "기획/디자인 정리 내용을 바탕으로 개발을 진행합니다."
        )
        sourceTab.appendBlock(
            .status(message: "개발 시작"),
            content: sourceTab.workflowDesignSummary.isEmpty
                ? "기획 정리 내용을 바탕으로 개발자가 구현을 시작합니다."
                : "기획/디자인 정리 내용을 바탕으로 개발자가 구현을 시작합니다."
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
                .status(message: "자동 재작업 한도 도달"),
                content: "자동 재작업은 최대 \(AppSettings.shared.automationRevisionLimit)회까지만 진행합니다. 이후에는 사용자가 직접 판단할 수 있도록 멈춥니다."
            )
            return
        }
        sourceTab.automatedRevisionCount += 1
        sourceTab.upsertWorkflowStage(
            role: .developer,
            workerName: sourceTab.workerName,
            assigneeCharacterId: sourceTab.characterId,
            state: .running,
            handoffLabel: "\(role.displayName) → \(sourceTab.workerName)",
            detail: "피드백을 반영해 재작업을 진행합니다."
        )
        sourceTab.appendBlock(
            .status(message: "\(role.displayName) 피드백 반영"),
            content: "개발자가 피드백을 반영해 다시 작업합니다."
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
                handoffLabel: "\(handoffSourceName) → \(reporterTab.workerName)",
                detail: "최종 결과와 요구사항을 Markdown으로 정리합니다."
            )
            sourceTab.appendBlock(
                .status(message: "보고자 투입: \(reporterTab.workerName)"),
                content: "최종 요구사항, 구현 결과, 검증 내용을 Markdown으로 정리합니다."
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
                handoffLabel: "\(handoffSourceName) → \(sreTab.workerName)",
                detail: "배포/운영 리스크와 실행 환경을 점검합니다."
            )
            sourceTab.appendBlock(
                .status(message: "SRE 투입: \(sreTab.workerName)"),
                content: "배포/운영 리스크와 실행 환경 관점을 점검합니다."
            )
            launchedAny = true
        }

        if !launchedAny {
            if let reporterReason = automationThrottleReason(for: .reporter) {
                sourceTab.appendBlock(.status(message: "보고 단계 생략"), content: reporterReason)
            }
            if let sreReason = automationThrottleReason(for: .sre) {
                sourceTab.appendBlock(.status(message: "SRE 단계 생략"), content: sreReason)
            }
            sourceTab.appendBlock(
                .status(message: "후속 단계 완료"),
                content: "사용 가능한 후속 역할이 없어 이 단계에서 마무리합니다."
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
                "request": templateValue(request, fallback: "요구사항 정보가 없습니다.")
            ]
        )
    }

    private func buildDesignerPrompt(for tab: TerminalTab) -> String {
        AutomationTemplateStore.shared.render(
            .designer,
            context: [
                "project_name": tab.projectName,
                "project_path": tab.projectPath,
                "request": templateValue(tab.workflowRequirementText, fallback: "요구사항 정보가 없습니다."),
                "plan_summary": templateValue(tab.workflowPlanSummary, fallback: "기획 요약 없음")
            ]
        )
    }

    private func buildDeveloperExecutionPrompt(for tab: TerminalTab) -> String {
        AutomationTemplateStore.shared.render(
            .developerExecution,
            context: [
                "project_name": tab.projectName,
                "project_path": tab.projectPath,
                "request": templateValue(tab.workflowRequirementText, fallback: "요구사항 정보가 없습니다."),
                "plan_summary": templateValue(tab.workflowPlanSummary, fallback: "기획 요약 없음"),
                "design_summary": templateValue(tab.workflowDesignSummary, fallback: "디자인/경험 메모 없음")
            ]
        )
    }

    private func buildDeveloperRevisionPrompt(for tab: TerminalTab, feedback: String, from role: WorkerJob) -> String {
        AutomationTemplateStore.shared.render(
            .developerRevision,
            context: [
                "project_name": tab.projectName,
                "project_path": tab.projectPath,
                "request": templateValue(tab.workflowRequirementText, fallback: "요구사항 정보가 없습니다."),
                "plan_summary": templateValue(tab.workflowPlanSummary, fallback: "기획 요약 없음"),
                "design_summary": templateValue(tab.workflowDesignSummary, fallback: "디자인/경험 메모 없음"),
                "feedback_role": role.displayName,
                "feedback": templateValue(feedback, fallback: "구체적인 피드백 없음")
            ]
        )
    }

    private func buildReviewPrompt(for tab: TerminalTab) -> String {
        AutomationTemplateStore.shared.render(
            .reviewer,
            context: [
                "project_name": tab.projectName,
                "project_path": tab.projectPath,
                "request": templateValue(tab.workflowRequirementText, fallback: "요구사항 정보가 없습니다. 변경 파일과 최근 완료 요약을 기준으로 검토하세요."),
                "plan_summary": templateValue(tab.workflowPlanSummary, fallback: "기획 요약 없음"),
                "design_summary": templateValue(tab.workflowDesignSummary, fallback: "디자인 요약 없음"),
                "dev_summary": templateValue(tab.lastCompletionSummary, fallback: "개발 완료 메시지 없음"),
                "changed_files": templateFileList(tab.fileChanges.suffix(10).map(\.path), fallback: "- 변경 파일 정보 없음")
            ]
        )
    }

    private func buildQAPrompt(for tab: TerminalTab, reviewSummary: String?) -> String {
        AutomationTemplateStore.shared.render(
            .qa,
            context: [
                "project_name": tab.projectName,
                "project_path": tab.projectPath,
                "request": templateValue(tab.workflowRequirementText, fallback: "요구사항 정보가 없습니다. 최근 변경 사항과 결과를 기준으로 검증하세요."),
                "plan_summary": templateValue(tab.workflowPlanSummary, fallback: "기획 요약 없음"),
                "design_summary": templateValue(tab.workflowDesignSummary, fallback: "디자인 요약 없음"),
                "dev_summary": templateValue(tab.lastCompletionSummary, fallback: "개발 완료 메시지 없음"),
                "review_summary": templateValue(reviewSummary ?? "", fallback: "코드 리뷰 요약 없음"),
                "changed_files": templateFileList(tab.fileChanges.suffix(8).map(\.path), fallback: "- 변경 파일 정보 없음")
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
                "request": templateValue(sourceTab.workflowRequirementText, fallback: "요구사항 정보가 없습니다."),
                "plan_summary": templateValue(sourceTab.workflowPlanSummary, fallback: "기획 요약 없음"),
                "design_summary": templateValue(sourceTab.workflowDesignSummary, fallback: "디자인 요약 없음"),
                "dev_summary": templateValue(sourceTab.lastCompletionSummary, fallback: "개발 완료 요약 없음"),
                "review_summary": templateValue(sourceTab.workflowReviewSummary, fallback: "리뷰 요약 없음"),
                "qa_summary": templateValue(qaSummary ?? "", fallback: "QA 요약 없음"),
                "validation_summary": templateValue(validationSummary ?? "", fallback: "추가 검증 요약 없음"),
                "changed_files": templateFileList(sourceTab.fileChanges.map(\.path), fallback: "- 변경 파일 없음")
            ]
        )
    }

    private func buildSREPrompt(for sourceTab: TerminalTab, qaSummary: String?, validationSummary: String?) -> String {
        AutomationTemplateStore.shared.render(
            .sre,
            context: [
                "project_name": sourceTab.projectName,
                "project_path": sourceTab.projectPath,
                "request": templateValue(sourceTab.workflowRequirementText, fallback: "요구사항 정보가 없습니다."),
                "dev_summary": templateValue(sourceTab.lastCompletionSummary, fallback: "개발 완료 요약 없음"),
                "qa_summary": templateValue(qaSummary ?? "", fallback: "QA 요약 없음"),
                "validation_summary": templateValue(validationSummary ?? "", fallback: "추가 검증 요약 없음"),
                "changed_files": templateFileList(sourceTab.fileChanges.map(\.path), fallback: "- 변경 파일 없음")
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
        return (tab.projectPath as NSString).appendingPathComponent(".workman/reports/\(fileName)")
    }

    private func ensureReportDirectoryExists(for reportPath: String) {
        let directory = (reportPath as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true, attributes: nil)
    }

    func availableReports() -> [ReportReference] {
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
            let reportsDir = (projectPath as NSString).appendingPathComponent(".workman/reports")
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
    func saveSessions() {
        let savableTabs = userVisibleTabs.filter { tab in
            // 토큰 사용 없고, 완료되지 않았고, 처리 중도 아닌 빈 탭은 저장하지 않음
            if tab.tokensUsed == 0 && !tab.isCompleted && !tab.isProcessing && tab.completedPromptCount == 0 {
                return false
            }
            return true
        }
        SessionStore.shared.save(tabs: savableTabs)
    }

    // Feature 4: 세션 복원 (이전 기록에서 경로 로드 - 같은 프로젝트 여러 탭 지원)
    func restoreSessions() {
        let saved = SessionStore.shared.load()
        var interruptedSessions: [SavedSession] = []

        // 워크플로우 자동 생성 탭 키워드 (Plan, Review, QA, Report 등이 중첩된 이름)
        let workflowSuffixes = ["Plan", "Review", "QA", "Report"]

        for session in saved {
            // 완료된 세션은 복원하지 않음
            guard !session.isCompleted && FileManager.default.fileExists(atPath: session.projectPath) else { continue }

            // 토큰 사용 없고 프롬프트도 없는 빈 세션은 건너뜀
            if session.tokensUsed == 0 && (session.initialPrompt == nil || session.initialPrompt?.isEmpty == true) && session.wasProcessing != true {
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

            addTab(
                projectName: session.projectName,
                projectPath: session.projectPath,
                branch: session.branch,
                initialPrompt: session.initialPrompt
            )
        }

        // 강제 종료로 중단된 작업이 있으면 알림
        if !interruptedSessions.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.showInterruptedSessionsAlert(interruptedSessions)
            }
        }
    }

    private func showInterruptedSessionsAlert(_ sessions: [SavedSession]) {
        let alert = NSAlert()
        let names = sessions.map { $0.projectName }.joined(separator: ", ")
        alert.messageText = "이전에 중단된 작업이 \(sessions.count)개 있습니다"
        alert.informativeText = "앱이 비정상 종료되어 다음 작업이 완료되지 못했습니다:\n\(names)\n\n변경사항이 남아있을 수 있습니다. 작업 전 상태로 되돌리시겠습니까?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "모두 되돌리기")
        alert.addButton(withTitle: "그대로 유지")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            for session in sessions {
                let path = session.projectPath
                // git 저장소인 경우 변경사항 롤백
                let isGitRepo = TerminalTab.shellSync("git -C \"\(path)\" rev-parse --is-inside-work-tree 2>/dev/null")?.trimmingCharacters(in: .whitespacesAndNewlines) == "true"
                if isGitRepo {
                    _ = TerminalTab.shellSync("git -C \"\(path)\" checkout -- . 2>/dev/null")
                    _ = TerminalTab.shellSync("git -C \"\(path)\" clean -fd 2>/dev/null")
                }
            }
        }
    }

    /// Cmd+R: 전체 새로고침 - 기존 탭 정리 후 다시 스캔
    func refresh() {
        saveSessions() // 새로고침 전 저장
        // 기존 터미널 프로세스 정리
        for tab in tabs {
            tab.stop()
        }
        tabs.removeAll()
        activeTabId = nil
        invalidateProjectGroupsCache()
        invalidateAvailableReportsCache()
        scheduleAvailableReportCountRefresh()
        workerIndex = 0

        // 다시 스캔
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
            let reportsDir = (projectPath as NSString).appendingPathComponent(".workman/reports")
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
        process.arguments = ["-il", "-c", command]
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
