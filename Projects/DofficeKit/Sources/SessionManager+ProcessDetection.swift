import SwiftUI
import Darwin
import AppKit
import DesignSystem

extension SessionManager {
    // MARK: - Auto Detect on Launch

    /// Scans for running terminal sessions and Claude Code processes,
    /// auto-creates tabs for each unique project found.
    public func autoDetectAndConnect() {
        scanTimer?.invalidate()
        scanTimer = nil
        scanTickCount = 0

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
                    if let tab = self.tabs.first(where: { $0.projectPath == session.path && $0.provider == session.provider }) {
                        // 이미 있으면 세션 수만 업데이트
                        tab.sessionCount = projectSessionCount[session.path] ?? 1
                        continue
                    }
                    // 사용자가 닫은 경로는 재추가하지 않음
                    if self.dismissedPaths.contains(session.path) { continue }
                    self.addTab(
                        projectName: session.projectName,
                        projectPath: session.path,
                        provider: session.provider,
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

    public struct DetectedSession {
        public let pid: Int
        public let path: String
        public let projectName: String
        public let branch: String?
        public let provider: AgentProvider
        public let parentApp: String? // Terminal.app, iTerm2, etc.

        public var isClaude: Bool { provider == .claude }
        public var key: String { "\(provider.rawValue)::\(path)" }
    }

    // MARK: - Process Scanning

    internal func scanRunningTerminals() -> [DetectedSession] {
        var results: [DetectedSession] = []
        var seenKeys = Set<String>()

        let sessions = findClaudeCodeSessions() + findCodexCodeSessions()
        for session in sessions {
            if !seenKeys.contains(session.key) {
                seenKeys.insert(session.key)
                results.append(session)
            }
        }

        return results
    }

    internal func findClaudeCodeSessions() -> [DetectedSession] {
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
                    provider: .claude,
                    parentApp: nil
                ))
            }
        }

        return results
    }

    internal func findCodexCodeSessions() -> [DetectedSession] {
        var results: [DetectedSession] = []
        let pids = findCodexPidsNative()

        for pid in pids {
            if let projectPath = getAgentProjectPath(pid: pid) {
                let projectName = getProjectName(path: projectPath)
                let branch = getBranch(path: projectPath)

                results.append(DetectedSession(
                    pid: pid,
                    path: projectPath,
                    projectName: projectName,
                    branch: branch,
                    provider: .codex,
                    parentApp: nil
                ))
            }
        }

        return results
    }

    /// 네이티브 API로 claude 프로세스 PID 찾기
    internal func findClaudePidsNative() -> [Int] {
        // proc_listallpids로 모든 PID 가져오기
        let bufferSize = proc_listallpids(nil, 0)
        guard bufferSize > 0 else { return [] }

        var pids = [Int32](repeating: 0, count: Int(bufferSize))
        let actualSize = proc_listallpids(&pids, Int32(MemoryLayout<Int32>.size * pids.count))
        guard actualSize > 0 else { return [] }

        var claudePids: [Int] = []
        let count = Int(actualSize) / MemoryLayout<Int32>.size

        var pathBuf = [CChar](repeating: 0, count: Int(MAXPATHLEN))
        for i in 0..<count {
            let pid = pids[i]
            guard pid > 0 else { continue }

            // proc_pidpath로 실행 파일 경로 확인
            let pathLen = proc_pidpath(pid, &pathBuf, UInt32(MAXPATHLEN))
            guard pathLen > 0 else { continue }

            let execPath = String(cString: pathBuf)

            // claude 실행파일인지 확인
            let lower = execPath.lowercased()
            guard Self.claudePathKeywords.contains(where: { lower.contains($0) }) else { continue }

            // node인 경우 커맨드 라인에 claude가 포함되는지 확인
            if lower.contains("node") && !lower.contains("claude") {
                // proc_pidinfo로 args 대신 cwd에서 .claude 폴더 확인
                if let cwd = getCwdNative(pid: Int(pid)) {
                    if !cwd.contains(Self.claudeCwdMarker) { continue }
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
            if Self.claudeExecSuffixes.contains(where: { lower.hasSuffix($0) }) ||
               Self.claudeExecContains.contains(where: { lower.contains($0) }) {
                claudePids.append(Int(pid))
            }
        }

        return claudePids
    }

    internal func findCodexPidsNative() -> [Int] {
        let bufferSize = proc_listallpids(nil, 0)
        guard bufferSize > 0 else { return [] }

        var pids = [Int32](repeating: 0, count: Int(bufferSize))
        let actualSize = proc_listallpids(&pids, Int32(MemoryLayout<Int32>.size * pids.count))
        guard actualSize > 0 else { return [] }

        var codexPids: [Int] = []
        let count = Int(actualSize) / MemoryLayout<Int32>.size

        var codexPathBuf = [CChar](repeating: 0, count: Int(MAXPATHLEN))
        for i in 0..<count {
            let pid = pids[i]
            guard pid > 0 else { continue }

            let pathLen = proc_pidpath(pid, &codexPathBuf, UInt32(MAXPATHLEN))
            guard pathLen > 0 else { continue }

            let execPath = String(cString: codexPathBuf).lowercased()
            guard Self.codexPathKeywords.contains(where: { execPath.contains($0) }) else { continue }

            var bsdInfo = proc_bsdinfo()
            let infoSize = proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &bsdInfo, Int32(MemoryLayout<proc_bsdinfo>.size))
            if infoSize > 0, bsdInfo.pbi_ppid == UInt32(ProcessInfo.processInfo.processIdentifier) {
                continue
            }

            codexPids.append(Int(pid))
        }

        return codexPids
    }

    /// Claude Code 프로세스의 프로젝트 경로를 추출 (lsof 미사용 → 화면 녹화 권한 불필요)
    internal func getClaudeProjectPath(pid: Int) -> String? {
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

    internal func getAgentProjectPath(pid: Int) -> String? {
        getClaudeProjectPath(pid: pid)
    }

    /// macOS 네이티브 API로 프로세스 cwd 가져오기 (권한 불필요)
    internal func getCwdNative(pid: Int) -> String? {
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

    internal func rescanForNewSessions() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let detected = self?.scanRunningTerminals() ?? []

            DispatchQueue.main.async {
                guard let self = self else { return }

                let detectedKeys = Set(detected.map(\.key))

                // 같은 프로젝트 세션 카운트
                var projectSessionCount: [String: Int] = [:]
                for session in detected {
                    projectSessionCount[session.path, default: 0] += 1
                }

                // 기존 탭 중 사라진 세션 → 완료 표시
                for tab in self.tabs {
                    let tabKey = "\(tab.provider.rawValue)::\(tab.projectPath)"
                    if tab.detectedPid != nil && !detectedKeys.contains(tabKey) {
                        tab.isCompleted = true
                        tab.claudeActivity = .done
                        tab.generateSummary()
                        AchievementManager.shared.checkCompletionAchievements(tab: tab)
                    }
                    // 세션 수 업데이트
                    tab.sessionCount = projectSessionCount[tab.projectPath] ?? tab.sessionCount
                }

                // 새 세션 추가 (사용자가 닫은 경로는 제외)
                for session in detected {
                    if !self.tabs.contains(where: { $0.projectPath == session.path && $0.provider == session.provider }),
                       !self.dismissedPaths.contains(session.path) {
                        self.addTab(
                            projectName: session.projectName,
                            projectPath: session.path,
                            provider: session.provider,
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

    internal func getCwd(pid: Int) -> String? {
        // 네이티브 API로 cwd 가져오기 (lsof 불필요)
        return getCwdNative(pid: pid)
    }

    internal func getParentCwd(pid: Int) -> String? {
        var current = pid
        for _ in 0..<3 {
            guard let ppid = getParentPidNative(pid: current), ppid > 1 else { return nil }
            if let cwd = getCwd(pid: ppid) { return cwd }
            current = ppid
        }
        return nil
    }

    /// 네이티브 API로 부모 PID 가져오기
    internal func getParentPidNative(pid: Int) -> Int? {
        var info = proc_bsdinfo()
        let ret = proc_pidinfo(Int32(pid), PROC_PIDTBSDINFO, 0, &info, Int32(MemoryLayout<proc_bsdinfo>.size))
        guard ret > 0 else { return nil }
        let ppid = Int(info.pbi_ppid)
        return ppid > 0 ? ppid : nil
    }

    internal func getProjectName(path: String) -> String {
        // Use git repo root name if available
        if let toplevel = shell("git -C \"\(path)\" rev-parse --show-toplevel 2>/dev/null")?
            .trimmingCharacters(in: .whitespacesAndNewlines) {
            return (toplevel as NSString).lastPathComponent
        }
        return (path as NSString).lastPathComponent
    }

    internal func getBranch(path: String) -> String? {
        return shell("git -C \"\(path)\" branch --show-current 2>/dev/null")?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    internal func hasClaudeChild(pid: Int) -> Bool {
        // 네이티브 API — 이미 findClaudePidsNative에서 처리하므로 간소화
        return false
    }

    internal func getTerminalApp(pid: Int) -> String? {
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
}
