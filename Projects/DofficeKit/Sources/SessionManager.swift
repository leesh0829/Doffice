import SwiftUI
import Darwin
import AppKit
import DesignSystem

public class SessionManager: ObservableObject {
    public static let shared = SessionManager()

    // Centralized process detection strings (edit here to add new CLI tools)
    static let claudeExecSuffixes: Set<String> = ["/claude"]
    static let claudeExecContains: Set<String> = ["/claude-", "/@anthropic"]
    static let claudePathKeywords: Set<String> = ["claude", "node"]
    static let claudeCwdMarker = ".claude"
    static let codexPathKeywords: Set<String> = ["/codex", "codex.app"]

    @Published public var tabs: [TerminalTab] = []
    @Published public var activeTabId: String?
    @Published public var showNewTabSheet: Bool = false
    @Published public var showSessionSearch: Bool = false
    @Published public var searchQuery: String = "" {
        didSet { debounceSearchResults() }
    }
    @Published public internal(set) var cachedSearchResults: [SearchResult] = []
    var searchDebounceTimer: Timer?
    @Published public var groups: [SessionGroup] = []
    @Published public var selectedGroupPath: String? = nil {  // nil = 전체 보기
        didSet {
            UserDefaults.standard.set(selectedGroupPath ?? "", forKey: "doffice.selectedGroupPath")
        }
    }
    @Published public var focusSingleTab: Bool = false       // 개별 워커 포커스
    @Published public var pinnedTabIds: Set<String> = []    // Shift+클릭으로 선택한 탭들 (그리드 멀티뷰)
    @Published public internal(set) var availableReportCount: Int = 0
    @Published public private(set) var totalTokensUsed: Int = 0
    @Published public private(set) var userVisibleTabCount: Int = 0

    public var userVisibleTabs: [TerminalTab] {
        tabs.filter { $0.automationSourceTabId == nil }
    }

    /// Recalculates cached `totalTokensUsed` from all tabs.
    public func updateTokenCount() {
        totalTokensUsed = tabs.reduce(0) { $0 + $1.tokensUsed }
    }

    /// Recalculates cached `userVisibleTabCount`.
    private func updateUserVisibleTabCount() {
        userVisibleTabCount = tabs.filter { $0.automationSourceTabId == nil }.count
    }

    /// Convenience: update all tab-derived caches.
    func updateTabDerivedCaches() {
        updateTokenCount()
        updateUserVisibleTabCount()
        AppSettings.shared.activeTabCount = tabs.count
    }

    public var manualLaunchCapacity: Int {
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
    public var visibleTabs: [TerminalTab] {
        guard let path = selectedGroupPath else { return userVisibleTabs }
        return userVisibleTabs.filter { $0.projectPath == path }
    }

    public let workerNames = ["Pixel", "Byte", "Code", "Bug", "Chip", "Kit", "Dot", "Rex"]

    var workerIndex = 0
    var scanTimer: Timer?
    var autoSaveTimer: Timer?
    var scanTickCount = 0
    var cachedProjectGroups: [ProjectGroup]?
    var cachedAvailableReports: [ReportReference] = []
    var cachedAvailableReportsSignature: Int?
    var cachedAvailableReportsAt: TimeInterval = 0
    var tabCompletionObserver: NSObjectProtocol?
    var sessionStoreObserver: NSObjectProtocol?
    var appLifecycleObservers: [NSObjectProtocol] = []
    let reportScanQueue = DispatchQueue(label: "doffice.report-count", qos: .utility)
    var reportScanWorkItem: DispatchWorkItem?
    var reportRefreshToken = UUID()
    var isAppActive = true
    /// 사용자가 명시적으로 닫은 프로젝트 경로 (rescan에서 재추가 방지)
    var dismissedPaths = Set<String>()

    public var activeTab: TerminalTab? {
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
        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
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
    public struct ProjectGroup: Identifiable {
        public let id: String // projectPath
        public let projectName: String
        public let tabs: [TerminalTab]
        public var hasActiveTab: Bool
        public init(id: String, projectName: String, tabs: [TerminalTab], hasActiveTab: Bool) {
            self.id = id; self.projectName = projectName; self.tabs = tabs; self.hasActiveTab = hasActiveTab
        }
    }

    public struct ReportReference: Identifiable {
        public let id: String
        public let projectName: String
        public let projectPath: String
        public let path: String
        public let updatedAt: Date
    }

    public var projectGroups: [ProjectGroup] {
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
    func invalidateProjectGroupsCache() {
        cachedProjectGroups = nil
    }

    func invalidateAvailableReportsCache() {
        cachedAvailableReports.removeAll()
        cachedAvailableReportsSignature = nil
        cachedAvailableReportsAt = 0
    }

    public func invalidateReportCache() {
        invalidateAvailableReportsCache()
        objectWillChange.send()
    }

    // MARK: - Tab Management

    @discardableResult
    public func addTab(projectName: String, projectPath: String, provider: AgentProvider = .claude, isClaude: Bool = false, detectedPid: Int? = nil, sessionCount: Int = 1, branch: String? = nil, initialPrompt: String? = nil, preferredCharacterId: String? = nil, automationSourceTabId: String? = nil, automationReportPath: String? = nil, manualLaunch: Bool = false, autoStart: Bool = true, restoredSession: SavedSession? = nil) -> TerminalTab {
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
        tab.selectedModel = provider.defaultModel
        tab.isClaude = provider == .claude || isClaude
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

    @discardableResult
    public func addBrowserTab(url: String = "") -> TerminalTab {
        let tab = addTab(
            projectName: "Browser",
            projectPath: NSHomeDirectory(),
            autoStart: false
        )
        tab.isBrowserTab = true
        tab.browserURL = url
        tab.isRunning = true
        tab.claudeActivity = .idle
        selectTab(tab.id)
        return tab
    }

    func occupiedCharacterIds() -> Set<String> {
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

    func randomManualCharacter() -> WorkerCharacter? {
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

    public func notifyManualLaunchCapacity(requested: Int = 1) {
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

    public func removeTab(_ id: String) {
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

    public func selectTab(_ id: String) {
        activeTabId = id
        invalidateProjectGroupsCache()
    }

    public func togglePinTab(_ id: String) {
        if pinnedTabIds.contains(id) {
            pinnedTabIds.remove(id)
        } else {
            pinnedTabIds.insert(id)
            focusSingleTab = false  // 멀티 선택 시 단일 포커스 해제
        }
    }

    public func clearPinnedTabs() {
        pinnedTabIds.removeAll()
    }

    public func moveTab(from source: IndexSet, to destination: Int) {
        tabs.move(fromOffsets: source, toOffset: destination)
        invalidateProjectGroupsCache()
    }

    // MARK: - Group Management

    public func createGroup(name: String, color: Color, tabIds: [String]) {
        let group = SessionGroup(name: name, color: color, tabIds: tabIds)
        groups.append(group)
        for id in tabIds {
            tabs.first(where: { $0.id == id })?.groupId = group.id
        }
    }

    public func addToGroup(tabId: String, groupId: String) {
        if let group = groups.first(where: { $0.id == groupId }) {
            if !group.tabIds.contains(tabId) {
                group.tabIds.append(tabId)
            }
            tabs.first(where: { $0.id == tabId })?.groupId = groupId
        }
    }

    public func removeFromGroup(tabId: String) {
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

    public func deleteGroup(_ groupId: String) {
        for tab in tabs where tab.groupId == groupId {
            tab.groupId = nil
        }
        groups.removeAll(where: { $0.id == groupId })
    }

    public func tabsInGroup(_ groupId: String) -> [TerminalTab] {
        tabs.filter { $0.groupId == groupId }
    }

    public func ungroupedTabs() -> [TerminalTab] {
        tabs.filter { $0.groupId == nil }
    }
}
