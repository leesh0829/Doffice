import Foundation
import SwiftUI
import UniformTypeIdentifiers
import DesignSystem

// ═══════════════════════════════════════════════════════
// MARK: - Plugin Host (런타임 플러그인 관리)
// ═══════════════════════════════════════════════════════

/// 활성 플러그인에서 로드된 확장 포인트들을 관리
public class PluginHost: ObservableObject {
    public static let shared = PluginHost()

    /// 활성 패널 목록
    @Published public var panels: [LoadedPanel] = []
    /// 활성 명령어 목록
    @Published public var commands: [LoadedCommand] = []
    /// 상태바 위젯 목록
    @Published public var statusBarItems: [LoadedStatusBarItem] = []

    // ── 네이티브 확장 ──
    @Published public var themes: [LoadedTheme] = []
    @Published public var achievements: [PluginManifest.AchievementDecl] = []
    @Published public var bossLines: [String] = []
    @Published public var effects: [LoadedEffect] = []

    public struct LoadedPanel: Identifiable {
        public let id: String
        public let pluginName: String
        public let title: String
        public let icon: String
        public let htmlURL: URL
        public let position: String
        public let width: Int?
        public let height: Int?
    }

    public struct LoadedCommand: Identifiable {
        public let id: String
        public let pluginName: String
        public let title: String
        public let icon: String
        public let scriptPath: String
    }

    public struct LoadedStatusBarItem: Identifiable {
        public let id: String
        public let pluginName: String
        public let scriptPath: String
        public let interval: Int
        public var text: String = ""
        public var icon: String = ""
        public var color: String = ""
    }

    public struct LoadedTheme: Identifiable {
        public let id: String
        public let pluginName: String
        public let decl: PluginManifest.ThemeDecl
    }

    public struct LoadedEffect: Identifiable {
        public let id: String
        public let pluginName: String
        public let trigger: PluginEventType
        public let effectType: PluginEffectType
        public let config: [String: EffectValue]
        public let enabled: Bool
    }

    // MARK: - 이벤트 발행

    public func fireEvent(_ event: PluginEventType, context: [String: Any] = [:]) {
        NotificationCenter.default.post(
            name: .pluginEffectEvent,
            object: nil,
            userInfo: ["event": event, "context": context]
        )
    }

    public func reload() {
        // Move file I/O and JSON decoding off the main thread
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?._reloadOnBackground()
        }
    }

    private func _reloadOnBackground() {
        var newPanels: [LoadedPanel] = []
        var newCommands: [LoadedCommand] = []
        var newStatusBars: [LoadedStatusBarItem] = []
        var newThemes: [LoadedTheme] = []
        var newEffects: [LoadedEffect] = []
        var newAchievements: [PluginManifest.AchievementDecl] = []
        var newBossLines: [String] = []

        for pluginPath in PluginManager.shared.activePluginPaths {
            let baseURL = URL(fileURLWithPath: pluginPath)
            let manifestURL = baseURL.appendingPathComponent("plugin.json")

            // Use cached manifest from PluginManager when available
            let manifest: PluginManifest
            if let cached = PluginManager.shared.manifestCacheGet(pluginPath) {
                manifest = cached
            } else {
                guard let data = try? Data(contentsOf: manifestURL),
                      let decoded = try? JSONDecoder().decode(PluginManifest.self, from: data) else { continue }
                manifest = decoded
                PluginManager.shared.manifestCacheSet(pluginPath, manifest)
            }
            guard let contributes = manifest.contributes else { continue }

            let pluginName = manifest.name

            // 패널
            if let panelDecls = contributes.panels {
                for decl in panelDecls {
                    let htmlURL = baseURL.appendingPathComponent(decl.entry)
                    guard FileManager.default.fileExists(atPath: htmlURL.path) else { continue }
                    newPanels.append(LoadedPanel(
                        id: "\(pluginName)::\(decl.id)",
                        pluginName: pluginName,
                        title: decl.title,
                        icon: decl.icon ?? "puzzlepiece.fill",
                        htmlURL: htmlURL,
                        position: decl.position ?? "panel",
                        width: decl.width,
                        height: decl.height
                    ))
                }
            }

            // 명령어
            if let cmdDecls = contributes.commands {
                for decl in cmdDecls {
                    let scriptPath = baseURL.appendingPathComponent(decl.script).path
                    guard FileManager.default.fileExists(atPath: scriptPath) else { continue }
                    newCommands.append(LoadedCommand(
                        id: "\(pluginName)::\(decl.id)",
                        pluginName: pluginName,
                        title: decl.title,
                        icon: decl.icon ?? "terminal",
                        scriptPath: scriptPath
                    ))
                }
            }

            // 상태바
            if let statusDecls = contributes.statusBar {
                for decl in statusDecls {
                    let scriptPath = baseURL.appendingPathComponent(decl.script).path
                    guard FileManager.default.fileExists(atPath: scriptPath) else { continue }
                    newStatusBars.append(LoadedStatusBarItem(
                        id: "\(pluginName)::\(decl.id)",
                        pluginName: pluginName,
                        scriptPath: scriptPath,
                        interval: decl.interval ?? 30
                    ))
                }
            }

            // ── 네이티브 확장 ──

            // 테마
            if let themeDecls = contributes.themes {
                for decl in themeDecls {
                    newThemes.append(LoadedTheme(
                        id: "\(pluginName)::\(decl.id)",
                        pluginName: pluginName,
                        decl: decl
                    ))
                }
            }

            // 업적
            if let achDecls = contributes.achievements {
                newAchievements.append(contentsOf: achDecls)
            }

            // 사장 대사
            if let lines = contributes.bossLines {
                newBossLines.append(contentsOf: lines)
            }

            // 이펙트
            if let effectDecls = contributes.effects {
                for decl in effectDecls {
                    guard let trigger = PluginEventType(rawValue: decl.trigger),
                          let effectType = PluginEffectType(rawValue: decl.type) else { continue }
                    newEffects.append(LoadedEffect(
                        id: "\(pluginName)::\(decl.id)",
                        pluginName: pluginName,
                        trigger: trigger,
                        effectType: effectType,
                        config: decl.config ?? [:],
                        enabled: decl.enabled ?? true
                    ))
                }
            }
        }

        // 개별 비활성화된 확장 포인트 필터링
        let disabled = PluginManager.shared.disabledExtensions

        DispatchQueue.main.async {
            self.panels = newPanels.filter { !disabled.contains($0.id) }
            self.commands = newCommands.filter { !disabled.contains($0.id) }
            self.statusBarItems = newStatusBars.filter { !disabled.contains($0.id) }
            self.themes = newThemes.filter { !disabled.contains($0.id) }
            self.effects = newEffects.filter { !disabled.contains($0.id) }
            // Note: achievements use raw AchievementDecl with local IDs (not "pluginName::id"),
            // so they cannot be matched against disabledExtensions which stores composite IDs.
            self.achievements = newAchievements
            self.bossLines = newBossLines
            self.startStatusBarTimers()
            // 충돌 캐시 갱신
            PluginManager.shared.detectConflicts()
        }
    }

    // MARK: - 테마 적용

    public func applyTheme(_ theme: LoadedTheme) {
        let d = theme.decl
        var config = AppSettings.shared.customTheme
        config.accentHex = d.accentHex
        config.useGradient = d.useGradient ?? false
        config.gradientStartHex = d.gradientStartHex
        config.gradientEndHex = d.gradientEndHex
        config.fontName = d.fontName
        AppSettings.shared.isDarkMode = d.isDark
        AppSettings.shared.saveCustomTheme(config)
        AppSettings.shared.requestRefreshIfNeeded()
    }

    // MARK: - 명령어 실행

    public func executeCommand(_ command: LoadedCommand, projectPath: String? = nil) {
        #if os(macOS)
        PluginManager.shared.requestPermission(
            pluginName: command.pluginName,
            scriptPath: command.scriptPath
        ) {
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/bin/zsh")
                process.arguments = ["-c", command.scriptPath]
                if let path = projectPath {
                    process.currentDirectoryURL = URL(fileURLWithPath: path)
                }
                process.environment = ProcessInfo.processInfo.environment
                try? process.run()
                process.waitUntilExit()
            }
        }
        #endif
    }

    // MARK: - 상태바 타이머

    private var statusTimers: [String: Timer] = [:]

    private func startStatusBarTimers() {
        #if os(macOS)
        for timer in statusTimers.values { timer.invalidate() }
        statusTimers.removeAll()

        for item in statusBarItems {
            refreshStatusBarItem(item.id)
            let timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(item.interval), repeats: true) { [weak self] _ in
                self?.refreshStatusBarItem(item.id)
            }
            statusTimers[item.id] = timer
        }
        #endif
    }

    #if os(macOS)
    private func refreshStatusBarItem(_ id: String) {
        guard let idx = statusBarItems.firstIndex(where: { $0.id == id }) else { return }
        let item = statusBarItems[idx]

        DispatchQueue.global(qos: .utility).async { [weak self] in
            let process = Process()
            let pipe = Pipe()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-c", item.scriptPath]
            process.standardOutput = pipe
            process.environment = ProcessInfo.processInfo.environment
            try? process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

            DispatchQueue.main.async {
                guard let self = self,
                      let idx = self.statusBarItems.firstIndex(where: { $0.id == id }) else { return }
                self.statusBarItems[idx].text = json["text"] as? String ?? ""
                self.statusBarItems[idx].icon = json["icon"] as? String ?? ""
                self.statusBarItems[idx].color = json["color"] as? String ?? ""
            }
        }
    }
    #endif
}

// ═══════════════════════════════════════════════════════
// MARK: - Plugin Manager (Homebrew 플러그인 관리)
// ═══════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════
// MARK: - Registry Item (마켓플레이스 항목)
// ═══════════════════════════════════════════════════════

/// 원격 레지스트리에 등록된 플러그인 (GitHub registry.json)
public struct RegistryPlugin: Codable, Identifiable, Equatable {
    public let id: String              // 고유 식별자
    public var name: String            // 표시 이름
    public var author: String          // 제작자
    public var description: String     // 설명
    public var version: String         // 최신 버전
    public var downloadURL: String     // tar.gz / zip 다운로드 URL
    public var characterCount: Int     // 포함된 캐릭터 수
    public var tags: [String]          // 태그 (예: ["cat", "pixel-art", "korean"])
    public var previewImageURL: String? // 미리보기 이미지 URL (옵션)
    public var stars: Int?             // 인기도 (옵션)
}

/// 플러그인 메타데이터
public struct PluginEntry: Codable, Identifiable, Equatable {
    public let id: String          // UUID
    public var name: String        // 표시 이름
    public var source: String      // brew formula 또는 tap URL (예: "user/tap/formula")
    public var localPath: String   // 설치된 로컬 경로
    public var version: String     // 버전
    public var installedAt: Date
    public var enabled: Bool
    public var sourceType: SourceType

    public enum SourceType: String, Codable {
        case brewFormula    // brew install <formula>
        case brewTap        // brew tap <user/repo> → brew install <formula>
        case rawURL         // curl로 직접 다운로드
        case local          // 로컬 디렉토리 직접 링크
    }
}

public class PluginManager: ObservableObject {
    typealias ShellCommandRunner = (_ command: String, _ cwd: String?) -> (Bool, String)
    typealias DownloadHandler = (_ url: URL, _ destinationURL: URL, _ completion: @escaping (Result<Void, Error>) -> Void) -> Void
    typealias InstallSideEffectHandler = (_ entry: PluginEntry) -> Void

    public static let shared = PluginManager()

    @Published public var plugins: [PluginEntry] = []
    @Published public var isInstalling: Bool = false
    @Published public var installProgress: String = ""
    @Published public var lastError: String?

    // 업데이트 감지
    @Published public var updatablePlugins: [String: String] = [:]   // pluginID → newVersion
    @Published public var isCheckingUpdates: Bool = false

    // 마켓플레이스 검색/필터
    @Published public var searchQuery: String = ""
    @Published public var selectedTags: Set<String> = []

    // 개별 확장 포인트 비활성화 목록 (extensionID set)
    @Published public var disabledExtensions: Set<String> = []
    private let disabledExtensionsKey = "DofficeDisabledExtensions"

    // 플러그인 권한 (신뢰된 플러그인 목록)
    @Published public var trustedPlugins: Set<String> = []   // pluginName set
    private let trustedPluginsKey = "DofficeTrustedPlugins"
    @Published public var pendingPermission: PermissionRequest?

    // 매니페스트 캐시 (detectConflicts 성능 개선)
    /// Manifest cache shared with PluginHost to avoid redundant disk I/O + JSON decoding.
    /// Access must go through the thread-safe helpers below.
    private var _manifestCache: [String: PluginManifest] = [:]  // pluginPath → manifest
    private let manifestCacheQueue = DispatchQueue(label: "com.doffice.manifestCache", attributes: .concurrent)

    func manifestCacheGet(_ key: String) -> PluginManifest? {
        manifestCacheQueue.sync { _manifestCache[key] }
    }

    func manifestCacheSet(_ key: String, _ value: PluginManifest) {
        manifestCacheQueue.async(flags: .barrier) { self._manifestCache[key] = value }
    }

    func manifestCacheClear() {
        manifestCacheQueue.async(flags: .barrier) { self._manifestCache.removeAll() }
    }

    // 충돌 감지 캐시 (pluginRow마다 재계산 방지)
    @Published public var cachedConflicts: [PluginConflict] = []

    // 핫 리로드
    private var fileWatchers: [String: DispatchSourceFileSystemObject] = [:]

    // 마켓플레이스
    @Published public var registryPlugins: [RegistryPlugin] = []
    @Published public var isLoadingRegistry: Bool = false
    @Published public var registryError: String?

    private let storageKey = "DofficePlugins"
    private let pluginBaseDir: URL
    private let userDefaults: UserDefaults
    private let shellCommandRunner: ShellCommandRunner
    private let downloadHandler: DownloadHandler
    private let installSideEffectHandler: InstallSideEffectHandler

    /// 레지스트리 URL — GitHub Pages 또는 raw 파일
    /// 기여자는 이 저장소에 PR로 registry.json에 자기 플러그인을 추가
    public static let registryURL = "https://raw.githubusercontent.com/jjunhaa0211/Doffice/main/registry.json"

    init(
        pluginBaseDir: URL = PluginManager.defaultPluginBaseDir(),
        userDefaults: UserDefaults = .standard,
        shellCommandRunner: @escaping ShellCommandRunner = PluginManager.defaultShellCommandRunner,
        downloadHandler: @escaping DownloadHandler = PluginManager.defaultDownloadHandler,
        installSideEffectHandler: @escaping InstallSideEffectHandler = PluginManager.defaultInstallSideEffectHandler
    ) {
        self.pluginBaseDir = pluginBaseDir
        self.userDefaults = userDefaults
        self.shellCommandRunner = shellCommandRunner
        self.downloadHandler = downloadHandler
        self.installSideEffectHandler = installSideEffectHandler
        try? FileManager.default.createDirectory(at: pluginBaseDir, withIntermediateDirectories: true)
        loadPlugins()
    }

    // MARK: - Persistence

    private func loadPlugins() {
        if let data = userDefaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([PluginEntry].self, from: data) {
            plugins = decoded
        } else {
            plugins = []
        }
        loadDisabledExtensions()
        loadTrustedPlugins()
    }

    private func loadDisabledExtensions() {
        if let arr = userDefaults.stringArray(forKey: disabledExtensionsKey) {
            disabledExtensions = Set(arr)
        }
    }

    private func saveDisabledExtensions() {
        userDefaults.set(Array(disabledExtensions), forKey: disabledExtensionsKey)
    }

    /// 개별 확장 포인트 활성/비활성 토글
    public func toggleExtension(_ extensionId: String) {
        if disabledExtensions.contains(extensionId) {
            disabledExtensions.remove(extensionId)
        } else {
            disabledExtensions.insert(extensionId)
        }
        saveDisabledExtensions()
        PluginHost.shared.reload()
    }

    /// 확장 포인트가 활성화되어 있는지 확인
    public func isExtensionEnabled(_ extensionId: String) -> Bool {
        !disabledExtensions.contains(extensionId)
    }

    // MARK: - 플러그인 권한 시스템

    public struct PermissionRequest: Identifiable {
        public let id = UUID()
        public let pluginName: String
        public let scriptPath: String
        public let onAllow: () -> Void
        public let onDeny: () -> Void
    }

    private func loadTrustedPlugins() {
        if let arr = userDefaults.stringArray(forKey: trustedPluginsKey) {
            trustedPlugins = Set(arr)
        }
    }

    private func saveTrustedPlugins() {
        userDefaults.set(Array(trustedPlugins), forKey: trustedPluginsKey)
    }

    /// 플러그인을 신뢰 목록에 추가
    public func trustPlugin(_ pluginName: String) {
        trustedPlugins.insert(pluginName)
        saveTrustedPlugins()
    }

    /// 플러그인 신뢰 해제
    public func untrustPlugin(_ pluginName: String) {
        trustedPlugins.remove(pluginName)
        saveTrustedPlugins()
    }

    /// 플러그인이 신뢰된 상태인지 확인
    public func isPluginTrusted(_ pluginName: String) -> Bool {
        trustedPlugins.contains(pluginName)
    }

    /// 스크립트 실행 전 권한 확인 (신뢰된 플러그인이면 바로 실행, 아니면 요청)
    public func requestPermission(pluginName: String, scriptPath: String, onAllow: @escaping () -> Void, onDeny: @escaping () -> Void = {}) {
        if isPluginTrusted(pluginName) {
            onAllow()
            return
        }

        DispatchQueue.main.async {
            self.pendingPermission = PermissionRequest(
                pluginName: pluginName,
                scriptPath: scriptPath,
                onAllow: onAllow,
                onDeny: onDeny
            )
        }
    }

    /// 권한 요청 승인
    public func approvePermission(alwaysTrust: Bool = false) {
        guard let req = pendingPermission else { return }
        if alwaysTrust {
            trustPlugin(req.pluginName)
        }
        req.onAllow()
        pendingPermission = nil
    }

    /// 권한 요청 거부
    public func denyPermission() {
        pendingPermission?.onDeny()
        pendingPermission = nil
    }

    private func savePlugins() {
        if let data = try? JSONEncoder().encode(plugins) {
            userDefaults.set(data, forKey: storageKey)
        }
        manifestCacheClear()
    }

    // MARK: - 활성 플러그인 경로 목록 (세션에 주입)

    public var activePluginPaths: [String] {
        plugins.filter { $0.enabled && FileManager.default.fileExists(atPath: $0.localPath) }
            .map { $0.localPath }
    }

    // MARK: - 마켓플레이스 (레지스트리)

    public func fetchRegistry() {
        isLoadingRegistry = true
        registryError = nil

        guard let url = URL(string: Self.registryURL) else {
            registryPlugins = Self.mergedRegistry(remote: [])
            registryError = nil
            isLoadingRegistry = false
            return
        }

        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoadingRegistry = false

                let remoteItems = Self.resolveRegistryItems(data: data, response: response, error: error)
                self.registryPlugins = Self.mergedRegistry(remote: remoteItems)
                self.registryError = nil
                self.checkForUpdates()
            }
        }.resume()
    }

    /// 레지스트리에서 설치
    public func installFromRegistry(_ item: RegistryPlugin) {
        if let bundledID = Self.bundledPluginID(from: item.downloadURL) {
            installBundledPlugin(item, bundledID: bundledID)
            return
        }
        install(source: item.downloadURL)
    }

    /// 이미 설치되어 있는지 확인
    public func isInstalled(_ registryItem: RegistryPlugin) -> Bool {
        plugins.contains { $0.source == registryItem.downloadURL || $0.name == registryItem.name }
    }

    // MARK: - 마켓플레이스 검색/필터

    /// 검색어 + 태그 필터가 적용된 레지스트리 목록
    public var filteredRegistryPlugins: [RegistryPlugin] {
        var result = registryPlugins

        // 검색어 필터
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !query.isEmpty {
            result = result.filter {
                $0.name.lowercased().contains(query)
                || $0.description.lowercased().contains(query)
                || $0.author.lowercased().contains(query)
                || $0.tags.contains { $0.lowercased().contains(query) }
            }
        }

        // 태그 필터
        if !selectedTags.isEmpty {
            result = result.filter { item in
                !selectedTags.isDisjoint(with: Set(item.tags.map { $0.lowercased() }))
            }
        }

        return result
    }

    /// 레지스트리에 있는 모든 태그 (카운트 포함)
    public var allRegistryTags: [(tag: String, count: Int)] {
        var tagCounts: [String: Int] = [:]
        for item in registryPlugins {
            for tag in item.tags {
                let lower = tag.lowercased()
                tagCounts[lower, default: 0] += 1
            }
        }
        return tagCounts.sorted { $0.value > $1.value }.map { (tag: $0.key, count: $0.value) }
    }

    // MARK: - 업데이트 감지

    /// 레지스트리와 설치된 플러그인 버전 비교
    public func checkForUpdates() {
        isCheckingUpdates = true
        var updates: [String: String] = [:]

        for plugin in plugins {
            guard plugin.enabled else { continue }
            if let registryItem = registryPlugins.first(where: {
                $0.id == plugin.name || $0.name == plugin.name || $0.downloadURL == plugin.source
            }) {
                if Self.isNewerVersion(registryItem.version, than: plugin.version) {
                    updates[plugin.id] = registryItem.version
                }
            }
        }

        updatablePlugins = updates
        isCheckingUpdates = false
    }

    /// 업데이트 가능한 플러그인인지 확인
    public func hasUpdate(_ plugin: PluginEntry) -> Bool {
        updatablePlugins[plugin.id] != nil
    }

    /// 업데이트 가능한 새 버전
    public func availableVersion(for plugin: PluginEntry) -> String? {
        updatablePlugins[plugin.id]
    }

    /// 업데이트 가능한 플러그인을 레지스트리에서 재설치
    public func updatePlugin(_ plugin: PluginEntry) {
        guard let registryItem = registryPlugins.first(where: {
            $0.id == plugin.name || $0.name == plugin.name || $0.downloadURL == plugin.source
        }) else { return }
        installFromRegistry(registryItem)
    }

    /// 모든 업데이트 가능한 플러그인 일괄 업데이트
    public func updateAllPlugins() {
        let updatable = plugins.filter { hasUpdate($0) }
        for plugin in updatable {
            updatePlugin(plugin)
        }
    }

    /// Semver 비교 (major.minor.patch)
    private static func isNewerVersion(_ new: String, than old: String) -> Bool {
        let newParts = new.split(separator: ".").compactMap { Int($0) }
        let oldParts = old.split(separator: ".").compactMap { Int($0) }
        let maxLen = max(newParts.count, oldParts.count)
        for i in 0..<maxLen {
            let n = i < newParts.count ? newParts[i] : 0
            let o = i < oldParts.count ? oldParts[i] : 0
            if n > o { return true }
            if n < o { return false }
        }
        return false
    }

    // MARK: - 의존성 검증

    /// 플러그인 의존성 충족 여부 확인
    public func validateDependencies(for pluginPath: String) -> [DependencyIssue] {
        let manifest: PluginManifest
        if let cached = manifestCacheGet(pluginPath) {
            manifest = cached
        } else {
            let baseURL = URL(fileURLWithPath: pluginPath)
            let manifestURL = baseURL.appendingPathComponent("plugin.json")
            guard let data = try? Data(contentsOf: manifestURL),
                  let decoded = try? JSONDecoder().decode(PluginManifest.self, from: data) else {
                return []
            }
            manifest = decoded
            manifestCacheSet(pluginPath, manifest)
        }
        guard let requires = manifest.requires, !requires.isEmpty else {
            return []
        }

        var issues: [DependencyIssue] = []
        for dep in requires {
            let installed = plugins.first { $0.name == dep.pluginId && $0.enabled }
            if installed == nil {
                issues.append(DependencyIssue(
                    pluginId: dep.pluginId,
                    kind: .missing,
                    requiredVersion: dep.minVersion,
                    installedVersion: nil
                ))
            } else if let minVer = dep.minVersion, let inst = installed {
                if Self.isNewerVersion(minVer, than: inst.version) {
                    issues.append(DependencyIssue(
                        pluginId: dep.pluginId,
                        kind: .versionTooLow,
                        requiredVersion: minVer,
                        installedVersion: inst.version
                    ))
                }
            }
        }
        return issues
    }

    public struct DependencyIssue {
        public let pluginId: String
        public let kind: Kind
        public let requiredVersion: String?
        public let installedVersion: String?

        public enum Kind {
            case missing
            case versionTooLow
        }

        public var localizedMessage: String {
            switch kind {
            case .missing:
                return String(format: NSLocalizedString("plugin.dep.missing", comment: ""), pluginId)
            case .versionTooLow:
                return String(format: NSLocalizedString("plugin.dep.version.low", comment: ""),
                              pluginId, requiredVersion ?? "?", installedVersion ?? "?")
            }
        }
    }

    // MARK: - 플러그인 상세 정보

    /// 플러그인이 기여하는 확장 포인트 요약
    public func contributionSummary(for plugin: PluginEntry) -> [ContributionBadge] {
        let baseURL = URL(fileURLWithPath: plugin.localPath)
        let manifest: PluginManifest
        if let cached = manifestCacheGet(plugin.localPath) {
            manifest = cached
        } else {
            let manifestURL = baseURL.appendingPathComponent("plugin.json")
            guard let data = try? Data(contentsOf: manifestURL),
                  let decoded = try? JSONDecoder().decode(PluginManifest.self, from: data) else {
                return []
            }
            manifest = decoded
            manifestCacheSet(plugin.localPath, manifest)
        }
        guard let c = manifest.contributes else {
            return []
        }

        var badges: [ContributionBadge] = []
        if let themes = c.themes, !themes.isEmpty {
            badges.append(ContributionBadge(icon: "paintpalette.fill", label: NSLocalizedString("plugin.badge.theme", comment: ""), count: themes.count))
        }
        if let effects = c.effects, !effects.isEmpty {
            badges.append(ContributionBadge(icon: "sparkles", label: NSLocalizedString("plugin.badge.effect", comment: ""), count: effects.count))
        }
        if let furniture = c.furniture, !furniture.isEmpty {
            badges.append(ContributionBadge(icon: "chair.lounge.fill", label: NSLocalizedString("plugin.badge.furniture", comment: ""), count: furniture.count))
        }
        if c.characters != nil {
            let charURL = baseURL.appendingPathComponent(c.characters!)
            if let charData = try? Data(contentsOf: charURL),
               let arr = try? JSONSerialization.jsonObject(with: charData) as? [[String: Any]] {
                badges.append(ContributionBadge(icon: "person.2.fill", label: NSLocalizedString("plugin.badge.character", comment: ""), count: arr.count))
            }
        }
        if let panels = c.panels, !panels.isEmpty {
            badges.append(ContributionBadge(icon: "rectangle.on.rectangle", label: NSLocalizedString("plugin.badge.panel", comment: ""), count: panels.count))
        }
        if let commands = c.commands, !commands.isEmpty {
            badges.append(ContributionBadge(icon: "terminal", label: NSLocalizedString("plugin.badge.command", comment: ""), count: commands.count))
        }
        if let achievements = c.achievements, !achievements.isEmpty {
            badges.append(ContributionBadge(icon: "trophy.fill", label: NSLocalizedString("plugin.badge.achievement", comment: ""), count: achievements.count))
        }
        if let presets = c.officePresets, !presets.isEmpty {
            badges.append(ContributionBadge(icon: "building.2.fill", label: NSLocalizedString("plugin.badge.office", comment: ""), count: presets.count))
        }
        if let lines = c.bossLines, !lines.isEmpty {
            badges.append(ContributionBadge(icon: "text.bubble.fill", label: NSLocalizedString("plugin.badge.bossline", comment: ""), count: lines.count))
        }
        return badges
    }

    public struct ContributionBadge {
        public let icon: String
        public let label: String
        public let count: Int
    }

    // MARK: - 충돌 감지

    /// 활성 플러그인 간 확장 포인트 ID 충돌 감지
    @discardableResult
    public func detectConflicts() -> [PluginConflict] {
        var conflicts: [PluginConflict] = []

        // pluginName → (extensionType, [IDs]) 맵
        var themeMap: [String: String] = [:]    // themeID → pluginName
        var effectMap: [String: String] = [:]
        var furnitureMap: [String: String] = [:]
        var achievementMap: [String: String] = [:]

        for pluginPath in activePluginPaths {
            let manifest: PluginManifest
            if let cached = manifestCacheGet(pluginPath) {
                manifest = cached
            } else {
                let baseURL = URL(fileURLWithPath: pluginPath)
                let manifestURL = baseURL.appendingPathComponent("plugin.json")
                guard let data = try? Data(contentsOf: manifestURL),
                      let decoded = try? JSONDecoder().decode(PluginManifest.self, from: data) else { continue }
                manifest = decoded
                manifestCacheSet(pluginPath, manifest)
            }

            guard let c = manifest.contributes else { continue }

            let name = manifest.name

            if let themes = c.themes {
                for t in themes {
                    if let existing = themeMap[t.id] {
                        conflicts.append(PluginConflict(pluginA: existing, pluginB: name, extensionType: NSLocalizedString("plugin.badge.theme", comment: ""), conflictingId: t.id))
                    } else { themeMap[t.id] = name }
                }
            }
            if let effects = c.effects {
                for e in effects {
                    if let existing = effectMap[e.id] {
                        conflicts.append(PluginConflict(pluginA: existing, pluginB: name, extensionType: NSLocalizedString("plugin.badge.effect", comment: ""), conflictingId: e.id))
                    } else { effectMap[e.id] = name }
                }
            }
            if let furniture = c.furniture {
                for f in furniture {
                    if let existing = furnitureMap[f.id] {
                        conflicts.append(PluginConflict(pluginA: existing, pluginB: name, extensionType: NSLocalizedString("plugin.badge.furniture", comment: ""), conflictingId: f.id))
                    } else { furnitureMap[f.id] = name }
                }
            }
            if let achievements = c.achievements {
                for a in achievements {
                    if let existing = achievementMap[a.id] {
                        conflicts.append(PluginConflict(pluginA: existing, pluginB: name, extensionType: NSLocalizedString("plugin.badge.achievement", comment: ""), conflictingId: a.id))
                    } else { achievementMap[a.id] = name }
                }
            }
        }
        cachedConflicts = conflicts
        return conflicts
    }

    /// 특정 플러그인에 해당하는 충돌만 반환 (캐시 사용)
    public func conflicts(for pluginName: String) -> [PluginConflict] {
        cachedConflicts.filter { $0.pluginA == pluginName || $0.pluginB == pluginName }
    }

    public struct PluginConflict {
        public let pluginA: String
        public let pluginB: String
        public let extensionType: String
        public let conflictingId: String

        public var localizedMessage: String {
            String(format: NSLocalizedString("plugin.conflict.desc", comment: ""),
                   pluginA, pluginB, extensionType, conflictingId)
        }
    }

    // MARK: - 핫 리로드 (로컬 플러그인 파일 변경 감지)

    /// 로컬 플러그인 디렉토리 감시 시작
    public func startWatchingLocalPlugins() {
        stopWatchingAll()

        for plugin in plugins where plugin.sourceType == .local && plugin.enabled {
            watchDirectory(plugin.localPath, pluginId: plugin.id)
        }
    }

    /// 모든 파일 감시 해제
    public func stopWatchingAll() {
        for (_, source) in fileWatchers {
            source.cancel()
        }
        fileWatchers.removeAll()
    }

    private func watchDirectory(_ path: String, pluginId: String) {
        #if os(macOS)
        let fd = open(path, O_EVTONLY)
        guard fd >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete],
            queue: DispatchQueue.global(qos: .utility)
        )

        source.setEventHandler {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                PluginHost.shared.reload()
                NotificationCenter.default.post(name: .pluginReload, object: nil)
                NotificationCenter.default.post(name: .init("dofficePluginCharactersChanged"), object: nil)
            }
        }

        source.setCancelHandler { close(fd) }
        source.resume()
        fileWatchers[pluginId] = source
        #endif
    }

    // MARK: - 플러그인 내보내기

    #if os(macOS)
    /// 플러그인을 tar.gz로 내보내기 (NSSavePanel)
    public func exportPlugin(_ plugin: PluginEntry) {
        let panel = NSSavePanel()
        panel.title = NSLocalizedString("plugin.export.panel.title", comment: "")
        panel.nameFieldStringValue = "\(plugin.name)-v\(plugin.version).tar.gz"
        panel.allowedContentTypes = [.archive]

        panel.begin { [weak self] result in
            guard result == .OK, let destURL = panel.url else { return }

            DispatchQueue.global(qos: .userInitiated).async {
                let destPath = self?.shellEscape(destURL.path) ?? ""
                let parentDir = self?.shellEscape(URL(fileURLWithPath: plugin.localPath).deletingLastPathComponent().path) ?? ""
                let dirName = URL(fileURLWithPath: plugin.localPath).lastPathComponent

                let (ok, output) = self?.runShell("tar -czf \(destPath) -C \(parentDir) \(self?.shellEscape(dirName) ?? "")") ?? (false, "")

                DispatchQueue.main.async {
                    if ok {
                        self?.installProgress = String(format: NSLocalizedString("plugin.export.success", comment: ""), destURL.lastPathComponent)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            self?.installProgress = ""
                        }
                    } else {
                        self?.lastError = String(format: NSLocalizedString("plugin.export.failed", comment: ""), output)
                    }
                }
            }
        }
    }
    #endif

    // MARK: - 소스 타입 자동 감지

    public func detectSourceType(_ input: String) -> PluginEntry.SourceType {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        // 로컬 경로 (/, ~/ 로 시작)
        let expanded = NSString(string: trimmed).expandingTildeInPath
        if trimmed.hasPrefix("/") || trimmed.hasPrefix("~/") || trimmed.hasPrefix("./") {
            if FileManager.default.fileExists(atPath: expanded) {
                return .local
            }
        }
        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
            return .rawURL
        }
        // "user/tap/formula" 형식 → brew tap
        let components = trimmed.split(separator: "/")
        if components.count >= 3 && !trimmed.hasPrefix("/") {
            return .brewTap
        }
        // 단순 formula 이름
        return .brewFormula
    }

    // MARK: - 설치

    public func install(source: String) {
        let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isInstalling = true
        lastError = nil
        installProgress = NSLocalizedString("plugin.progress.analyzing", comment: "")

        let sourceType = detectSourceType(trimmed)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            switch sourceType {
            #if os(macOS)
            case .brewFormula:
                self.installBrewFormula(trimmed)
            case .brewTap:
                self.installBrewTap(trimmed)
            #else
            case .brewFormula, .brewTap:
                self.finishWithError(NSLocalizedString("plugin.error.brew.not.supported", comment: ""))
            #endif
            case .rawURL:
                self.installFromURL(trimmed)
            case .local:
                self.installLocal(trimmed)
            }
        }
    }

    private func installBundledPlugin(_ item: RegistryPlugin, bundledID: String) {
        guard let bundled = Self.bundledPluginDefinition(for: bundledID) else {
            finishWithError(NSLocalizedString("plugin.error.path.not.found", comment: ""))
            return
        }

        isInstalling = true
        lastError = nil
        installProgress = String(format: NSLocalizedString("plugin.progress.installing", comment: ""), item.name)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let fm = FileManager.default
            let pluginDir = self.pluginBaseDir.appendingPathComponent(bundled.directoryName)

            do {
                if fm.fileExists(atPath: pluginDir.path) {
                    try fm.removeItem(at: pluginDir)
                }
                try fm.createDirectory(at: pluginDir, withIntermediateDirectories: true)

                for file in bundled.files {
                    let destination = pluginDir.appendingPathComponent(file.path)
                    let parentDir = destination.deletingLastPathComponent()
                    try fm.createDirectory(at: parentDir, withIntermediateDirectories: true)
                    try file.contents.write(to: destination, atomically: true, encoding: .utf8)
                }
            } catch {
                self.finishWithError(error.localizedDescription)
                return
            }

            if let validationMessage = self.pluginValidationError(at: pluginDir.path) {
                self.cleanupManagedPluginDirectory(pluginDir)
                self.finishWithError(validationMessage)
                return
            }

            let entry = PluginEntry(
                id: UUID().uuidString,
                name: item.name,
                source: item.downloadURL,
                localPath: pluginDir.path,
                version: item.version,
                installedAt: Date(),
                enabled: true,
                sourceType: .rawURL
            )
            self.finishInstall(entry)
        }
    }

    #if os(macOS)
    private func installBrewFormula(_ formula: String) {
        updateProgress(NSLocalizedString("plugin.progress.brew.install", comment: ""))

        let brewPath = Self.findBrewPath()
        guard let brew = brewPath else {
            finishWithError(NSLocalizedString("plugin.error.brew.not.found", comment: ""))
            return
        }

        // brew install
        let (installOk, installOut) = runShell("\(brew) install \(shellEscape(formula))")
        if !installOk && !installOut.contains("already installed") {
            finishWithError(String(format: NSLocalizedString("plugin.error.install.failed", comment: ""), installOut))
            return
        }

        // brew --prefix로 설치 경로 가져오기
        let (_, prefixOut) = runShell("\(brew) --prefix \(shellEscape(formula))")
        let prefix = prefixOut.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !prefix.isEmpty && FileManager.default.fileExists(atPath: prefix) else {
            finishWithError(NSLocalizedString("plugin.error.path.not.found", comment: ""))
            return
        }

        if let validationMessage = pluginValidationError(at: prefix) {
            finishWithError(validationMessage)
            return
        }

        // 버전 확인
        let (_, versionOut) = runShell("\(brew) list --versions \(shellEscape(formula))")
        let version = versionOut.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: " ").last ?? "unknown"

        let entry = PluginEntry(
            id: UUID().uuidString,
            name: formula,
            source: formula,
            localPath: prefix,
            version: version,
            installedAt: Date(),
            enabled: true,
            sourceType: .brewFormula
        )

        finishInstall(entry)
    }

    private func installBrewTap(_ tapFormula: String) {
        let parts = tapFormula.split(separator: "/")
        guard parts.count >= 3 else {
            finishWithError(NSLocalizedString("plugin.error.invalid.tap", comment: ""))
            return
        }

        let tapName = "\(parts[0])/\(parts[1])"
        let formula = String(parts[2...].joined(separator: "/"))

        let brewPath = Self.findBrewPath()
        guard let brew = brewPath else {
            finishWithError(NSLocalizedString("plugin.error.brew.not.found", comment: ""))
            return
        }

        // brew tap
        updateProgress(String(format: NSLocalizedString("plugin.progress.tapping", comment: ""), tapName))
        let (tapOk, tapOut) = runShell("\(brew) tap \(shellEscape(String(tapName)))")
        if !tapOk && !tapOut.contains("already tapped") {
            finishWithError(String(format: NSLocalizedString("plugin.error.tap.failed", comment: ""), tapOut))
            return
        }

        // brew install
        updateProgress(String(format: NSLocalizedString("plugin.progress.installing", comment: ""), formula))
        let (installOk, installOut) = runShell("\(brew) install \(shellEscape(tapFormula))")
        if !installOk && !installOut.contains("already installed") {
            finishWithError(String(format: NSLocalizedString("plugin.error.install.failed", comment: ""), installOut))
            return
        }

        // 경로 가져오기
        let (_, prefixOut) = runShell("\(brew) --prefix \(shellEscape(tapFormula))")
        let prefix = prefixOut.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !prefix.isEmpty && FileManager.default.fileExists(atPath: prefix) else {
            finishWithError(NSLocalizedString("plugin.error.path.not.found", comment: ""))
            return
        }

        if let validationMessage = pluginValidationError(at: prefix) {
            finishWithError(validationMessage)
            return
        }

        let (_, versionOut) = runShell("\(brew) list --versions \(shellEscape(tapFormula))")
        let version = versionOut.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: " ").last ?? "unknown"

        let entry = PluginEntry(
            id: UUID().uuidString,
            name: formula,
            source: tapFormula,
            localPath: prefix,
            version: version,
            installedAt: Date(),
            enabled: true,
            sourceType: .brewTap
        )

        finishInstall(entry)
    }
    #endif

    private func installFromURL(_ urlString: String) {
        guard let url = URL(string: urlString) else {
            finishWithError(NSLocalizedString("plugin.error.invalid.url", comment: ""))
            return
        }

        let fileName = url.lastPathComponent.isEmpty ? "plugin" : url.lastPathComponent
        let pluginName = (fileName as NSString).deletingPathExtension
        let pluginDir = pluginBaseDir.appendingPathComponent(pluginName)
        let fm = FileManager.default

        updateProgress(String(format: NSLocalizedString("plugin.progress.downloading", comment: ""), fileName))
        do {
            if fm.fileExists(atPath: pluginDir.path) {
                try fm.removeItem(at: pluginDir)
            }
            try fm.createDirectory(at: pluginDir, withIntermediateDirectories: true)
        } catch {
            finishWithError(String(format: NSLocalizedString("plugin.error.download.failed", comment: ""), error.localizedDescription))
            return
        }

        let destURL = pluginDir.appendingPathComponent(fileName)
        downloadHandler(url, destURL) { [weak self] result in
            guard let self = self else { return }
            if case let .failure(error) = result {
                self.finishWithError(String(format: NSLocalizedString("plugin.error.download.failed", comment: ""), error.localizedDescription))
                return
            }

            // 압축 해제
            if let message = self.extractIfNeeded(destURL, to: pluginDir, fileName: fileName) {
                self.cleanupManagedPluginDirectory(pluginDir)
                self.finishWithError(message)
                return
            }

            if let validationMessage = self.pluginValidationError(at: pluginDir.path) {
                self.cleanupManagedPluginDirectory(pluginDir)
                self.finishWithError(validationMessage)
                return
            }

            let entry = PluginEntry(
                id: UUID().uuidString,
                name: pluginName,
                source: urlString,
                localPath: pluginDir.path,
                version: "1.0.0",
                installedAt: Date(),
                enabled: true,
                sourceType: .rawURL
            )
            self.finishInstall(entry)
        }
    }

    private func extractIfNeeded(_ fileURL: URL, to dir: URL, fileName: String) -> String? {
        #if os(macOS)
        if fileName.hasSuffix(".tar.gz") || fileName.hasSuffix(".tgz") {
            updateProgress(NSLocalizedString("plugin.progress.extracting", comment: ""))
            let (ok, out) = runShell("tar -xzf \(shellEscape(fileURL.path)) -C \(shellEscape(dir.path))")
            if ok {
                try? FileManager.default.removeItem(at: fileURL)
                return nil
            }
            return String(format: NSLocalizedString("plugin.error.extract.failed", comment: ""), out)
        } else if fileName.hasSuffix(".zip") {
            updateProgress(NSLocalizedString("plugin.progress.extracting", comment: ""))
            let (ok, out) = runShell("unzip -o \(shellEscape(fileURL.path)) -d \(shellEscape(dir.path))")
            if ok {
                try? FileManager.default.removeItem(at: fileURL)
                return nil
            }
            return String(format: NSLocalizedString("plugin.error.extract.failed", comment: ""), out)
        }
        #else
        // iOS: zip만 Foundation으로 지원 (tar.gz는 미지원)
        if fileName.hasSuffix(".zip") {
            updateProgress(NSLocalizedString("plugin.progress.extracting", comment: ""))
            // FileManager에서 직접 압축해제는 미지원 → 파일 그대로 유지
        }
        #endif
        return nil
    }

    // MARK: - 로컬 디렉토리 등록

    private func installLocal(_ path: String) {
        let expanded = NSString(string: path).expandingTildeInPath
        guard FileManager.default.fileExists(atPath: expanded) else {
            finishWithError(NSLocalizedString("plugin.error.path.not.found", comment: ""))
            return
        }

        let name = URL(fileURLWithPath: expanded).lastPathComponent
        let validation = Self.validatePluginDir(expanded)
        guard validation.isValid else {
            finishWithError(validation.warnings.first ?? NSLocalizedString("plugin.warn.empty", comment: ""))
            return
        }

        let entry = PluginEntry(
            id: UUID().uuidString,
            name: name,
            source: path,
            localPath: expanded,
            version: validation.version ?? "dev",
            installedAt: Date(),
            enabled: true,
            sourceType: .local
        )

        finishInstall(entry)
    }

    // MARK: - 플러그인 유효성 검증

    public struct PluginValidation {
        public var isValid: Bool
        public var hasClaudeMD: Bool
        public var hasHooks: Bool
        public var hasSlashCommands: Bool
        public var hasMCPServers: Bool
        public var hasSettings: Bool
        public var hasCharacters: Bool
        public var characterCount: Int
        public var version: String?
        public var warnings: [String]
    }

    public static func validatePluginDir(_ path: String) -> PluginValidation {
        let fm = FileManager.default
        let base = URL(fileURLWithPath: path)

        let claudeMD = base.appendingPathComponent("CLAUDE.md")
        let hooksDir = base.appendingPathComponent("hooks")
        let slashDir = base.appendingPathComponent("slash-commands")
        let mcpDir = base.appendingPathComponent("mcp-servers")
        let settingsFile = base.appendingPathComponent("settings.json")
        let packageJSON = base.appendingPathComponent("package.json")

        let charactersFile = base.appendingPathComponent("characters.json")

        let hasClaudeMD = fm.fileExists(atPath: claudeMD.path)
        let hasHooks = fm.fileExists(atPath: hooksDir.path)
        let hasSlashCommands = fm.fileExists(atPath: slashDir.path)
        let hasMCPServers = fm.fileExists(atPath: mcpDir.path)
        let hasSettings = fm.fileExists(atPath: settingsFile.path)
        let hasCharacters = fm.fileExists(atPath: charactersFile.path)

        var characterCount = 0
        if hasCharacters,
           let data = try? Data(contentsOf: charactersFile),
           let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            characterCount = arr.count
        }

        var version: String?
        if let data = try? Data(contentsOf: packageJSON),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let v = json["version"] as? String {
            version = v
        }

        var warnings: [String] = []
        let hasAnything = hasClaudeMD || hasHooks || hasSlashCommands || hasMCPServers || hasSettings || hasCharacters
        if !hasAnything {
            warnings.append(NSLocalizedString("plugin.warn.empty", comment: ""))
        }

        return PluginValidation(
            isValid: hasAnything,
            hasClaudeMD: hasClaudeMD,
            hasHooks: hasHooks,
            hasSlashCommands: hasSlashCommands,
            hasMCPServers: hasMCPServers,
            hasSettings: hasSettings,
            hasCharacters: hasCharacters,
            characterCount: characterCount,
            version: version,
            warnings: warnings
        )
    }

    // MARK: - 새 플러그인 스캐폴딩

    public func scaffold(name: String, at parentDir: String, options: ScaffoldOptions = ScaffoldOptions()) -> String? {
        let pluginDir = URL(fileURLWithPath: parentDir).appendingPathComponent(name)
        let fm = FileManager.default

        do {
            try fm.createDirectory(at: pluginDir, withIntermediateDirectories: true)

            // CLAUDE.md
            let claudeMD = """
            # \(name) Plugin

            이 플러그인은 도피스(Doffice)용 Claude Code 플러그인입니다.

            ## 설명
            플러그인 설명을 여기에 작성하세요.
            """
            try claudeMD.write(to: pluginDir.appendingPathComponent("CLAUDE.md"), atomically: true, encoding: .utf8)

            // hooks/
            if options.includeHooks {
                let hooksDir = pluginDir.appendingPathComponent("hooks")
                try fm.createDirectory(at: hooksDir, withIntermediateDirectories: true)

                let preHook = """
                // preToolUse hook — 도구 실행 전에 호출됩니다.
                // return { decision: "allow" } 또는 { decision: "deny", reason: "..." }
                export default function preToolUse({ tool, input }) {
                  // 예: 특정 디렉토리 보호
                  // if (tool === "Write" && input.file_path?.startsWith("/protected/")) {
                  //   return { decision: "deny", reason: "보호된 디렉토리입니다" };
                  // }
                  return { decision: "allow" };
                }
                """
                try preHook.write(to: hooksDir.appendingPathComponent("preToolUse.js"), atomically: true, encoding: .utf8)
            }

            // slash-commands/
            if options.includeSlashCommands {
                let slashDir = pluginDir.appendingPathComponent("slash-commands")
                try fm.createDirectory(at: slashDir, withIntermediateDirectories: true)

                let exampleCmd = """
                # /\(name)-hello

                사용자에게 인사를 건네세요.
                이 명령은 \(name) 플러그인의 예제입니다.
                """
                try exampleCmd.write(to: slashDir.appendingPathComponent("\(name)-hello.md"), atomically: true, encoding: .utf8)
            }

            // settings.json
            if options.includeSettings {
                let settings: [String: Any] = [
                    "name": name,
                    "version": "0.1.0",
                    "description": "\(name) plugin for Doffice"
                ]
                let data = try JSONSerialization.data(withJSONObject: settings, options: .prettyPrinted)
                try data.write(to: pluginDir.appendingPathComponent("settings.json"))
            }

            // characters.json (캐릭터 팩)
            if options.includeCharacters {
                let exampleCharacters: [[String: Any]] = [
                    [
                        "id": "example_char",
                        "name": "Example",
                        "archetype": "예제 캐릭터",
                        "hairColor": "4a3728",
                        "skinTone": "ffd5b8",
                        "shirtColor": "f08080",
                        "pantsColor": "3a4050",
                        "hatType": "none",
                        "accessory": "glasses",
                        "species": "Human",
                        "jobRole": "developer"
                    ]
                ]
                let charData = try JSONSerialization.data(withJSONObject: exampleCharacters, options: .prettyPrinted)
                try charData.write(to: pluginDir.appendingPathComponent("characters.json"))

                // README
                let readme = """
                # \(name) 캐릭터 팩

                ## characters.json 형식

                ```json
                [
                  {
                    "id": "고유ID",
                    "name": "표시 이름",
                    "archetype": "성격/설명",
                    "hairColor": "hex (6자리, # 없이)",
                    "skinTone": "hex",
                    "shirtColor": "hex",
                    "pantsColor": "hex",
                    "hatType": "none|beanie|cap|hardhat|wizard|crown|headphones|beret",
                    "accessory": "none|glasses|sunglasses|scarf|mask|earring",
                    "species": "Human|Cat|Dog|Rabbit|Bear|Penguin|Fox|Robot|Claude|Alien|Ghost|Dragon|Chicken|Owl|Frog|Panda|Unicorn|Skeleton",
                    "jobRole": "developer|qa|reporter|boss|planner|reviewer|designer|sre"
                  }
                ]
                ```

                ## 배포 방법
                1. GitHub에 올리고 Homebrew tap 생성
                2. 또는 tar.gz로 묶어서 Release에 올리기
                3. 도피스 설정 > 플러그인에서 설치
                """
                try readme.write(to: pluginDir.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)
            }

            // plugin.json (매니페스트 — 확장 포인트 선언)
            var contributes: [String: Any] = [:]
            if options.includeCharacters {
                contributes["characters"] = "characters.json"
            }
            if options.includePanel {
                contributes["panels"] = [[
                    "id": "main-panel",
                    "title": "\(name) Panel",
                    "icon": "puzzlepiece.fill",
                    "entry": "panel/index.html",
                    "position": "panel"
                ]]

                // panel/index.html 생성
                let panelDir = pluginDir.appendingPathComponent("panel")
                try fm.createDirectory(at: panelDir, withIntermediateDirectories: true)
                let panelHTML = """
                <!DOCTYPE html>
                <html>
                <head>
                <meta charset="utf-8">
                <style>
                  * { margin: 0; padding: 0; box-sizing: border-box; }
                  body {
                    font-family: 'SF Mono', 'Menlo', monospace;
                    background: transparent;
                    color: #e0e0e0;
                    padding: 16px;
                  }
                  h1 { font-size: 14px; margin-bottom: 12px; color: #5b9cf6; }
                  .card {
                    background: rgba(255,255,255,0.05);
                    border: 1px solid rgba(255,255,255,0.1);
                    border-radius: 8px;
                    padding: 12px;
                    margin-bottom: 8px;
                  }
                  button {
                    background: #5b9cf6;
                    color: white;
                    border: none;
                    border-radius: 6px;
                    padding: 8px 16px;
                    font-family: inherit;
                    font-size: 12px;
                    cursor: pointer;
                  }
                  button:hover { opacity: 0.8; }
                </style>
                </head>
                <body>
                  <h1>\(name) Plugin</h1>
                  <div class="card">
                    <p>이 패널은 플러그인의 예제입니다.</p>
                    <p>HTML/CSS/JS로 자유롭게 UI를 만들 수 있습니다.</p>
                  </div>
                  <button onclick="window.webkit.messageHandlers.doffice.postMessage({action:'notify', text:'Hello from \(name)!'})">
                    앱에 알림 보내기
                  </button>
                  <script>
                    // window.webkit.messageHandlers.doffice.postMessage({action: 'getSessionInfo'})
                    // → 앱이 세션 정보를 이 WebView에 전달
                  </script>
                </body>
                </html>
                """
                try panelHTML.write(to: panelDir.appendingPathComponent("index.html"), atomically: true, encoding: .utf8)
            }

            let pluginJSON: [String: Any] = [
                "name": name,
                "version": "0.1.0",
                "description": "\(name) — Doffice plugin",
                "author": Self.currentUserName,
                "contributes": contributes
            ]
            let pluginData = try JSONSerialization.data(withJSONObject: pluginJSON, options: [.prettyPrinted, .sortedKeys])
            try pluginData.write(to: pluginDir.appendingPathComponent("plugin.json"))

            // package.json (버전 추적용)
            let packageJSON: [String: Any] = [
                "name": name,
                "version": "0.1.0",
                "description": "\(name) — Doffice plugin"
            ]
            let pkgData = try JSONSerialization.data(withJSONObject: packageJSON, options: .prettyPrinted)
            try pkgData.write(to: pluginDir.appendingPathComponent("package.json"))

            return pluginDir.path
        } catch {
            return nil
        }
    }

    public struct ScaffoldOptions {
        public var includeHooks: Bool = true
        public var includeSlashCommands: Bool = true
        public var includeCharacters: Bool = true
        public var includeSettings: Bool = true
        public var includePanel: Bool = true
        public init(includeHooks: Bool = true, includeSlashCommands: Bool = true, includeCharacters: Bool = true, includeSettings: Bool = true, includePanel: Bool = true) {
            self.includeHooks = includeHooks
            self.includeSlashCommands = includeSlashCommands
            self.includeCharacters = includeCharacters
            self.includeSettings = includeSettings
            self.includePanel = includePanel
        }
    }

    // MARK: - Finder에서 열기

    public func revealInFinder(_ plugin: PluginEntry) {
        #if os(macOS)
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: plugin.localPath)
        #endif
    }

    // MARK: - 삭제

    public func uninstall(_ plugin: PluginEntry) {
        switch plugin.sourceType {
        case .brewFormula, .brewTap:
            #if os(macOS)
            if let brew = Self.findBrewPath() {
                _ = runShell("\(brew) uninstall \(shellEscape(plugin.source))")
            }
            #endif
        case .rawURL:
            try? FileManager.default.removeItem(atPath: plugin.localPath)
        case .local:
            break
        }

        DispatchQueue.main.async {
            self.plugins.removeAll { $0.id == plugin.id }
            self.savePlugins()
            // 제거된 플러그인 정리
            NotificationCenter.default.post(name: .init("dofficePluginCharactersChanged"), object: nil)
            PluginHost.shared.reload()
        }
    }

    // MARK: - 토글

    public func toggleEnabled(_ plugin: PluginEntry) {
        if let idx = plugins.firstIndex(where: { $0.id == plugin.id }) {
            plugins[idx].enabled.toggle()
            savePlugins()
        }
    }

    // MARK: - 업데이트 (brew upgrade)

    #if os(macOS)
    public func upgrade(_ plugin: PluginEntry) {
        guard plugin.sourceType != .rawURL else { return }
        guard let brew = Self.findBrewPath() else { return }

        isInstalling = true
        installProgress = String(format: NSLocalizedString("plugin.progress.upgrading", comment: ""), plugin.name)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let (ok, output) = self.runShell("\(brew) upgrade \(self.shellEscape(plugin.source))")

            if !ok && !output.contains("already installed") && !output.contains("already the newest") {
                self.finishWithError(String(format: NSLocalizedString("plugin.error.upgrade.failed", comment: ""), output))
                return
            }

            // 새 버전 확인
            let (_, versionOut) = self.runShell("\(brew) list --versions \(self.shellEscape(plugin.source))")
            let version = versionOut.trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: " ").last ?? plugin.version

            DispatchQueue.main.async {
                if let idx = self.plugins.firstIndex(where: { $0.id == plugin.id }) {
                    self.plugins[idx].version = version
                    self.savePlugins()
                }
                self.isInstalling = false
                self.installProgress = ""
            }
        }
    }
    #endif

    // MARK: - Platform Helpers

    private static var currentUserName: String {
        #if os(macOS)
        return NSUserName()
        #else
        return "user"
        #endif
    }

    // MARK: - Shell Helpers

    private static func defaultPluginBaseDir() -> URL {
        #if os(macOS)
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("DofficePlugins")
        }
        return appSupport.appendingPathComponent("Doffice").appendingPathComponent("Plugins")
        #else
        return URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("DofficePlugins")
        #endif
    }

    private static func defaultShellCommandRunner(_ command: String, _ cwd: String?) -> (Bool, String) {
        #if os(macOS)
        let process = Process()
        let pipe = Pipe()
        let errorPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", command]
        process.standardOutput = pipe
        process.standardError = errorPipe
        process.environment = ProcessInfo.processInfo.environment
        if let cwd {
            process.currentDirectoryURL = URL(fileURLWithPath: cwd)
        }

        do {
            try process.run()
        } catch {
            return (false, error.localizedDescription)
        }

        var outData = Data()
        var errData = Data()
        let group = DispatchGroup()
        group.enter()
        DispatchQueue.global(qos: .utility).async {
            outData = pipe.fileHandleForReading.readDataToEndOfFile()
            group.leave()
        }
        group.enter()
        DispatchQueue.global(qos: .utility).async {
            errData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            group.leave()
        }

        process.waitUntilExit()
        group.wait()
        let output = String(data: outData, encoding: .utf8) ?? ""
        let errOutput = String(data: errData, encoding: .utf8) ?? ""
        let success = process.terminationStatus == 0
        return (success, success ? output : (errOutput.isEmpty ? output : errOutput))
        #else
        _ = command
        _ = cwd
        return (false, NSLocalizedString("plugin.error.brew.not.supported", comment: ""))
        #endif
    }

    private static func defaultDownloadHandler(_ url: URL, _ destinationURL: URL, _ completion: @escaping (Result<Void, Error>) -> Void) {
        URLSession.shared.downloadTask(with: url) { tempURL, _, error in
            if let error {
                completion(.failure(error))
                return
            }

            guard let tempURL else {
                completion(.failure(NSError(domain: "PluginManager", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: NSLocalizedString("plugin.error.download.failed", comment: "")
                ])))
                return
            }

            do {
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }
                try FileManager.default.moveItem(at: tempURL, to: destinationURL)
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    private static func defaultInstallSideEffectHandler(_ entry: PluginEntry) {
        _ = entry
        NotificationCenter.default.post(name: .init("dofficePluginCharactersChanged"), object: nil)
        PluginHost.shared.reload()
    }

    #if os(macOS)
    private static func findBrewPath() -> String? {
        let candidates = ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]
        return candidates.first { FileManager.default.fileExists(atPath: $0) }
    }

    @discardableResult
    private func runShell(_ command: String) -> (Bool, String) {
        shellCommandRunner(command, nil)
    }

    private func shellEscape(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
    #endif

    // MARK: - Progress Helpers

    private func updateProgress(_ msg: String) {
        DispatchQueue.main.async { self.installProgress = msg }
    }

    private func finishWithError(_ msg: String) {
        DispatchQueue.main.async {
            self.lastError = msg
            self.isInstalling = false
            self.installProgress = ""
        }
    }

    private func pluginValidationError(at path: String) -> String? {
        let validation = Self.validatePluginDir(path)
        guard !validation.isValid else { return nil }
        return validation.warnings.first ?? NSLocalizedString("plugin.warn.empty", comment: "")
    }

    private func cleanupManagedPluginDirectory(_ directory: URL) {
        try? FileManager.default.removeItem(at: directory)
    }

    private func finishInstall(_ entry: PluginEntry) {
        DispatchQueue.main.async {
            if let idx = self.plugins.firstIndex(where: { $0.source == entry.source }) {
                self.plugins[idx].name = entry.name
                self.plugins[idx].localPath = entry.localPath
                self.plugins[idx].version = entry.version
                self.plugins[idx].installedAt = entry.installedAt
                self.plugins[idx].enabled = entry.enabled
                self.plugins[idx].sourceType = entry.sourceType
            } else {
                self.plugins.append(entry)
            }
            self.savePlugins()
            self.installSideEffectHandler(entry)
            self.lastError = nil
            self.isInstalling = false
            self.installProgress = ""
        }
    }

    // MARK: - Registry Helpers

    public static func decodeRegistryPayload(_ data: Data) -> [RegistryPlugin]? {
        guard let json = try? JSONSerialization.jsonObject(with: data) else { return nil }

        let rawItems: [[String: Any]]
        if let array = json as? [[String: Any]] {
            rawItems = array
        } else if let object = json as? [String: Any],
                  let array = object["plugins"] as? [[String: Any]] {
            rawItems = array
        } else {
            return nil
        }

        let items = rawItems.compactMap(Self.registryPlugin(from:))
        return items.isEmpty ? nil : items
    }

    public static func bundledRegistryCatalog() -> [RegistryPlugin] {
        [
            RegistryPlugin(
                id: "flea-market-hidden-pack",
                name: "플리 마켓 히든 캐릭터 팩",
                author: "Doffice",
                description: "플리 마켓에서 바로 고용할 수 있는 히든 캐릭터 3종을 추가합니다.",
                version: "1.0.0",
                downloadURL: "bundled://flea-market-hidden-pack",
                characterCount: 3,
                tags: ["hidden", "market", "characters"],
                previewImageURL: nil,
                stars: 42
            ),
            RegistryPlugin(
                id: "typing-combo-pack",
                name: "타이핑 콤보 팩",
                author: "Doffice",
                description: "터미널 외부에서 타이핑할 때 콤보 카운터, 파티클, 화면 흔들림 이펙트가 발동합니다.",
                version: "1.0.0",
                downloadURL: "bundled://typing-combo-pack",
                characterCount: 0,
                tags: ["effects", "combo", "typing", "particles"],
                previewImageURL: nil,
                stars: 128
            ),
            RegistryPlugin(
                id: "premium-furniture-pack",
                name: "프리미엄 가구 팩",
                author: "Doffice",
                description: "아쿠아리움, 아케이드 머신, 네온사인 등 프리미엄 가구 8종을 추가합니다.",
                version: "1.0.0",
                downloadURL: "bundled://premium-furniture-pack",
                characterCount: 0,
                tags: ["furniture", "office", "premium"],
                previewImageURL: nil,
                stars: 85
            ),
            RegistryPlugin(
                id: "vacation-beach-pack",
                name: "바캉스 비치 팩",
                author: "Doffice",
                description: "사무실을 열대 해변으로! 야자수, 파라솔, 비치 테마 2종, 캐릭터 2종 포함.",
                version: "1.0.0",
                downloadURL: "bundled://vacation-beach-pack",
                characterCount: 2,
                tags: ["theme", "beach", "furniture", "characters", "effects"],
                previewImageURL: nil,
                stars: 156
            ),
            RegistryPlugin(
                id: "battleground-pack",
                name: "배틀그라운드 팩",
                author: "Doffice",
                description: "사무실이 전장으로! 참나무, 바위, 수풀 가구 8종 + 배그 테마 + 전투 이펙트.",
                version: "1.0.0",
                downloadURL: "bundled://battleground-pack",
                characterCount: 3,
                tags: ["theme", "battle", "furniture", "characters", "effects"],
                previewImageURL: nil,
                stars: 201
            )
        ]
    }

    private static func resolveRegistryItems(data: Data?, response: URLResponse?, error: Error?) -> [RegistryPlugin] {
        if error != nil {
            return []
        }

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            return []
        }

        guard let data else { return [] }
        return decodeRegistryPayload(data) ?? []
    }

    private static func mergedRegistry(remote: [RegistryPlugin]) -> [RegistryPlugin] {
        var seenIDs = Set<String>()
        var seenNames = Set<String>()
        var merged: [RegistryPlugin] = []

        for item in bundledRegistryCatalog() + remote {
            let idKey = item.id.lowercased()
            let nameKey = item.name.lowercased()
            guard !seenIDs.contains(idKey), !seenNames.contains(nameKey) else { continue }
            seenIDs.insert(idKey)
            seenNames.insert(nameKey)
            merged.append(item)
        }

        return merged
    }

    private static func registryPlugin(from raw: [String: Any]) -> RegistryPlugin? {
        guard let name = firstString(in: raw, keys: ["name", "title"]),
              let downloadURL = firstString(in: raw, keys: ["downloadURL", "downloadUrl", "download_url", "url"]) else {
            return nil
        }

        let id = firstString(in: raw, keys: ["id"]) ?? slugifiedRegistryID(from: name)
        let author = firstString(in: raw, keys: ["author", "creator", "maker"]) ?? "Unknown"
        let description = firstString(in: raw, keys: ["description", "summary"]) ?? ""
        let version = firstString(in: raw, keys: ["version"]) ?? "1.0.0"
        let previewImageURL = firstString(in: raw, keys: ["previewImageURL", "previewImageUrl", "preview_image_url"])
        let tags = stringArray(in: raw, keys: ["tags"])
        let stars = firstInt(in: raw, keys: ["stars", "starCount", "star_count"])
        let characterCount = firstInt(in: raw, keys: ["characterCount", "character_count"])
            ?? ((raw["characters"] as? [[String: Any]])?.count ?? 0)

        return RegistryPlugin(
            id: id,
            name: name,
            author: author,
            description: description,
            version: version,
            downloadURL: downloadURL,
            characterCount: characterCount,
            tags: tags,
            previewImageURL: previewImageURL,
            stars: stars
        )
    }

    private static func bundledPluginID(from source: String) -> String? {
        guard let url = URL(string: source), url.scheme == "bundled" else { return nil }

        let host = url.host?.trimmingCharacters(in: CharacterSet(charactersIn: "/")) ?? ""
        let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let identifier = host.isEmpty ? path : host
        return identifier.isEmpty ? nil : identifier
    }

    private struct BundledPluginFile {
        let path: String
        let contents: String
    }

    private struct BundledPluginDefinition {
        let directoryName: String
        let files: [BundledPluginFile]
    }

    /// Bundle 리소스에서 번들 플러그인 로드 (plugins/ 디렉토리)
    private static func loadBundledFromBundle(id: String) -> BundledPluginDefinition? {
        // Bundle.main에서 plugins/<id> 디렉토리 찾기
        guard let bundleURL = Bundle.main.resourceURL?.appendingPathComponent("plugins").appendingPathComponent(id),
              FileManager.default.fileExists(atPath: bundleURL.path) else {
            return nil
        }

        let fm = FileManager.default
        var files: [BundledPluginFile] = []

        // 재귀적으로 모든 파일 수집
        if let enumerator = fm.enumerator(at: bundleURL, includingPropertiesForKeys: nil) {
            while let fileURL = enumerator.nextObject() as? URL {
                var isDir: ObjCBool = false
                fm.fileExists(atPath: fileURL.path, isDirectory: &isDir)
                if !isDir.boolValue {
                    let relativePath = fileURL.path.replacingOccurrences(of: bundleURL.path + "/", with: "")
                    do {
                        let content = try String(contentsOf: fileURL, encoding: .utf8)
                        files.append(BundledPluginFile(path: relativePath, contents: content))
                    } catch {
                        print("[Plugin] Failed to read bundled file \(relativePath): \(error.localizedDescription)")
                    }
                }
            }
        }

        guard !files.isEmpty, files.contains(where: { $0.path == "plugin.json" }) else {
            return nil
        }

        return BundledPluginDefinition(directoryName: id, files: files)
    }

    private static func bundledPluginDefinition(for id: String) -> BundledPluginDefinition? {
        // 먼저 Bundle 리소스에서 찾기
        if let def = loadBundledFromBundle(id: id) { return def }

        // fallback: 인라인 데이터 (flea-market-hidden-pack만)
        switch id {
        case "flea-market-hidden-pack":
            let characters = """
            [
              {
                "id": "night_vendor",
                "name": "히든 야시장",
                "archetype": "플리 마켓의 비밀 셀러",
                "hairColor": "3b2f2f",
                "skinTone": "e8c4a0",
                "shirtColor": "6d597a",
                "pantsColor": "2b2d42",
                "hatType": "cap",
                "accessory": "glasses",
                "species": "Fox",
                "jobRole": "reviewer"
              },
              {
                "id": "lucky_tag",
                "name": "히든 럭키태그",
                "archetype": "숨겨둔 딜을 먼저 찾는 흥정 장인",
                "hairColor": "b08968",
                "skinTone": "f1d3b3",
                "shirtColor": "84a59d",
                "pantsColor": "3d405b",
                "hatType": "beanie",
                "accessory": "earring",
                "species": "Cat",
                "jobRole": "planner"
              },
              {
                "id": "ghost_dealer",
                "name": "히든 고스트딜러",
                "archetype": "새벽에만 등장하는 히든 캐릭터",
                "hairColor": "d9d9ff",
                "skinTone": "d9d9ff",
                "shirtColor": "adb5bd",
                "pantsColor": "495057",
                "hatType": "wizard",
                "accessory": "mask",
                "species": "Ghost",
                "jobRole": "designer"
              }
            ]
            """

            let pluginJSON = """
            {
              "name": "플리 마켓 히든 캐릭터 팩",
              "version": "1.0.0",
              "description": "플리 마켓에서 바로 고용할 수 있는 히든 캐릭터 3종 팩",
              "author": "Doffice",
              "contributes": {
                "characters": "characters.json"
              }
            }
            """

            let packageJSON = """
            {
              "name": "flea-market-hidden-pack",
              "version": "1.0.0",
              "description": "Bundled hidden character pack for the Doffice marketplace"
            }
            """

            let readme = """
            # 플리 마켓 히든 캐릭터 팩

            Doffice 마켓플레이스에서 바로 설치할 수 있는 기본 캐릭터 플러그인입니다.
            설치하면 히든 캐릭터 3종이 캐릭터 목록에 추가됩니다.
            """

            return BundledPluginDefinition(
                directoryName: "flea-market-hidden-pack",
                files: [
                    BundledPluginFile(path: "plugin.json", contents: pluginJSON),
                    BundledPluginFile(path: "package.json", contents: packageJSON),
                    BundledPluginFile(path: "characters.json", contents: characters),
                    BundledPluginFile(path: "README.md", contents: readme)
                ]
            )
        default:
            return nil
        }
    }

    private static func firstString(in raw: [String: Any], keys: [String]) -> String? {
        for key in keys {
            if let value = raw[key] as? String {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    return trimmed
                }
            }
        }
        return nil
    }

    private static func firstInt(in raw: [String: Any], keys: [String]) -> Int? {
        for key in keys {
            if let value = raw[key] as? Int {
                return max(0, value)
            }
            if let value = raw[key] as? NSNumber {
                return max(0, value.intValue)
            }
            if let value = raw[key] as? String,
               let parsed = Int(value.trimmingCharacters(in: .whitespacesAndNewlines)) {
                return max(0, parsed)
            }
        }
        return nil
    }

    private static func stringArray(in raw: [String: Any], keys: [String]) -> [String] {
        for key in keys {
            if let values = raw[key] as? [String] {
                return values.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            }
            if let value = raw[key] as? String {
                return value
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            }
        }
        return []
    }

    private static func slugifiedRegistryID(from text: String) -> String {
        let allowed = CharacterSet.alphanumerics
        let components = text.lowercased()
            .components(separatedBy: allowed.inverted)
            .filter { !$0.isEmpty }
        return components.isEmpty ? UUID().uuidString.lowercased() : components.joined(separator: "-")
    }
}
