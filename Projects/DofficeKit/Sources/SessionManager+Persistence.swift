import SwiftUI
import Darwin
import AppKit
import DesignSystem

extension SessionManager {
    // MARK: - Reports

    public func availableReports() -> [ReportReference] {
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

    // MARK: - Session Save / Restore

    // Feature 4: 세션 저장 (빈 자동화 탭 제외)
    public func saveSessions(immediately: Bool = false) {
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
    public func restoreSessions() {
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

            // 브라우저 탭 복원
            if session.isBrowserTab == true {
                let tab = addTab(
                    projectName: session.projectName,
                    projectPath: session.projectPath,
                    autoStart: false,
                    restoredSession: session
                )
                tab.isBrowserTab = true
                tab.browserURL = session.browserURL ?? ""
                tab.isRunning = true
                tab.claudeActivity = .idle
                continue
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

    internal func showInterruptedSessionsAlert(_ sessions: [SavedSession], recoveryBundles: [URL]) {
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

    // MARK: - Refresh / Stop

    /// Cmd+R: 전체 새로고침 - 기존 탭 정리 후 다시 스캔
    public func refresh() {
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

    public func stopScanning() {
        scanTimer?.invalidate()
        scanTimer = nil
    }

    // MARK: - Report Count

    public func scheduleAvailableReportCountRefresh() {
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

    internal func availableReportsSignature(
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

    internal static func computeReportCount(
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

    internal func shell(_ command: String) -> String? {
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
            var outputData = Data()
            let outputGroup = DispatchGroup()
            outputGroup.enter()
            DispatchQueue.global(qos: .utility).async {
                outputData = pipe.fileHandleForReading.readDataToEndOfFile()
                outputGroup.leave()
            }
            process.waitUntilExit()
            outputGroup.wait()
            let output = String(data: outputData, encoding: .utf8)
            return output?.isEmpty == true ? nil : output
        } catch {
            return nil
        }
    }
}
