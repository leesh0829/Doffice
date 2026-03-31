import Foundation

// ═══════════════════════════════════════════════════════
// MARK: - Tmux Session Bridge
// ═══════════════════════════════════════════════════════
//
// tmux를 이용한 세션 영속성 지원
// 앱이 종료되어도 세션이 살아있고, 재시작 시 reattach 가능

class TmuxSessionBridge {
    static let shared = TmuxSessionBridge()

    private let sessionPrefix = "doffice-"

    // MARK: - tmux 설치 확인

    var isTmuxAvailable: Bool {
        tmuxPath != nil
    }

    private var _tmuxPath: String??
    var tmuxPath: String? {
        if let cached = _tmuxPath { return cached }
        let paths = ["/opt/homebrew/bin/tmux", "/usr/local/bin/tmux", "/usr/bin/tmux"]
        for path in paths {
            if FileManager.default.fileExists(atPath: path) {
                _tmuxPath = .some(path)
                return path
            }
        }
        // PATH에서 찾기
        let result = shellSync("which tmux 2>/dev/null")
        let found = result.trimmingCharacters(in: .whitespacesAndNewlines)
        if !found.isEmpty && FileManager.default.fileExists(atPath: found) {
            _tmuxPath = .some(found)
            return found
        }
        _tmuxPath = .some(nil)
        return nil
    }

    // MARK: - Session Management

    /// 새 tmux 세션 생성
    func createSession(id: String, cwd: String, cols: Int = 120, rows: Int = 36) -> Bool {
        guard let tmux = tmuxPath else { return false }
        let sessionName = sessionPrefix + id
        let cmd = "\(tmux) new-session -d -s \(shellEscape(sessionName)) -x \(cols) -y \(rows)"
        let result = shellSync(cmd, cwd: cwd)
        return !result.contains("error") && !result.contains("duplicate")
    }

    /// 기존 세션이 있는지 확인
    func sessionExists(id: String) -> Bool {
        guard let tmux = tmuxPath else { return false }
        let sessionName = sessionPrefix + id
        let result = shellSync("\(tmux) has-session -t \(shellEscape(sessionName)) 2>&1")
        return !result.contains("can't find session") && !result.contains("error")
    }

    /// 모든 doffice 세션 목록
    func listSessions() -> [TmuxSession] {
        guard let tmux = tmuxPath else { return [] }
        let format = "#{session_name}\t#{session_created}\t#{session_windows}\t#{session_attached}"
        let result = shellSync("\(tmux) list-sessions -F '\(format)' 2>/dev/null")

        return result.split(separator: "\n").compactMap { line in
            let parts = line.split(separator: "\t")
            guard parts.count >= 4,
                  parts[0].hasPrefix(sessionPrefix) else { return nil }

            let name = String(parts[0])
            let id = String(name.dropFirst(sessionPrefix.count))
            let created = Date(timeIntervalSince1970: Double(parts[1]) ?? 0)
            let windows = Int(parts[2]) ?? 0
            let attached = parts[3] == "1"

            return TmuxSession(
                id: id,
                sessionName: name,
                created: created,
                windowCount: windows,
                isAttached: attached
            )
        }
    }

    /// 세션에 명령어 전송 (send-keys)
    func sendKeys(sessionId: String, keys: String) {
        guard let tmux = tmuxPath else { return }
        let sessionName = sessionPrefix + sessionId
        let _ = shellSync("\(tmux) send-keys -t \(shellEscape(sessionName)) \(shellEscape(keys)) Enter")
    }

    /// 세션에 텍스트 전송 (raw text, Enter 없이)
    func sendText(sessionId: String, text: String) {
        guard let tmux = tmuxPath else { return }
        let sessionName = sessionPrefix + sessionId
        let _ = shellSync("\(tmux) send-keys -t \(shellEscape(sessionName)) -l \(shellEscape(text))")
    }

    /// 세션 종료
    func killSession(id: String) {
        guard let tmux = tmuxPath else { return }
        let sessionName = sessionPrefix + id
        let _ = shellSync("\(tmux) kill-session -t \(shellEscape(sessionName)) 2>/dev/null")
    }

    /// 모든 doffice 세션 종료
    func killAllSessions() {
        for session in listSessions() {
            killSession(id: session.id)
        }
    }

    /// 세션의 현재 출력 캡처
    func capturePane(sessionId: String, lines: Int = 50) -> String {
        guard let tmux = tmuxPath else { return "" }
        let sessionName = sessionPrefix + sessionId
        return shellSync("\(tmux) capture-pane -t \(shellEscape(sessionName)) -p -S -\(lines) 2>/dev/null")
    }

    /// 세션 윈도우 크기 조정
    func resizeWindow(sessionId: String, cols: Int, rows: Int) {
        guard let tmux = tmuxPath else { return }
        let sessionName = sessionPrefix + sessionId
        let _ = shellSync("\(tmux) resize-window -t \(shellEscape(sessionName)) -x \(cols) -y \(rows) 2>/dev/null")
    }

    // MARK: - Async API (메인 스레드 블로킹 방지)

    /// 비동기 세션 목록 조회 (UI에서 사용)
    func listSessionsAsync() async -> [TmuxSession] {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let result = self.listSessions()
                continuation.resume(returning: result)
            }
        }
    }

    /// 비동기 세션 생성
    func createSessionAsync(id: String, cwd: String, cols: Int = 120, rows: Int = 36) async -> Bool {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let result = self.createSession(id: id, cwd: cwd, cols: cols, rows: rows)
                continuation.resume(returning: result)
            }
        }
    }

    // MARK: - Helpers

    /// 동기 셸 실행 — 가능하면 백그라운드 스레드에서 호출할 것.
    private func shellSync(_ cmd: String, cwd: String? = nil) -> String {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", cmd]
        process.standardOutput = pipe
        process.standardError = pipe
        if let cwd = cwd {
            process.currentDirectoryURL = URL(fileURLWithPath: cwd)
        }

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return ""
        }
    }

    /// 셸 이스케이프 — 단일 따옴표로 감싸기
    /// NOTE: TerminalTab, PluginManager에도 동일한 함수 있음. 향후 공유 유틸리티로 통합 권장.
    private func shellEscape(_ str: String) -> String {
        "'" + str.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}

// MARK: - Data Types

struct TmuxSession: Identifiable {
    let id: String
    let sessionName: String
    let created: Date
    let windowCount: Int
    let isAttached: Bool
}
