import SwiftUI
import Combine

// ═══════════════════════════════════════════════════════
// MARK: - Automation Engine (send-keys & Script Runner)
// ═══════════════════════════════════════════════════════

class AutomationEngine: ObservableObject {
    static let shared = AutomationEngine()

    @Published var isRunning = false
    @Published var currentScriptName: String?
    @Published var macros: [AutomationMacro] = []

    private var scriptTask: Task<Void, Never>?
    private let storageKey = "doffice.automationMacros"

    private init() { loadMacros() }

    // MARK: - Send Keys

    /// 특정 탭에 텍스트 전송
    func sendKeys(tabId: String, text: String) {
        guard let tab = SessionManager.shared.tabs.first(where: { $0.id == tabId }) else { return }

        if AppSettings.shared.rawTerminalMode {
            // Raw 터미널 모드: SwiftTerm에 직접 전송
            NotificationCenter.default.post(
                name: .dofficeSendKeysToTerminal,
                object: nil,
                userInfo: ["tabId": tabId, "text": text]
            )
        } else {
            // Normal 모드: 프롬프트로 전송
            tab.sendPrompt(text)
        }
    }

    /// 특정 탭에 특수 키 전송
    func sendSpecialKey(tabId: String, key: AutomationKey) {
        NotificationCenter.default.post(
            name: .dofficeSendKeysToTerminal,
            object: nil,
            userInfo: ["tabId": tabId, "text": key.escapeSequence]
        )
    }

    /// 현재 활성 탭에 텍스트 전송
    func sendKeysToActive(text: String) {
        guard let tabId = SessionManager.shared.activeTabId else { return }
        sendKeys(tabId: tabId, text: text)
    }

    // MARK: - Script Execution

    func runScript(_ script: AutomationScript) {
        guard !isRunning else { return }

        isRunning = true
        currentScriptName = script.name

        scriptTask = Task { @MainActor in
            for step in script.steps {
                guard !Task.isCancelled else { break }
                await executeStep(step)
            }
            isRunning = false
            currentScriptName = nil
        }
    }

    func stopScript() {
        scriptTask?.cancel()
        isRunning = false
        currentScriptName = nil
    }

    @MainActor
    private func executeStep(_ step: AutomationStep) async {
        let manager = SessionManager.shared

        switch step {
        case .sendText(let tabId, let text):
            let targetId = tabId ?? manager.activeTabId ?? ""
            sendKeys(tabId: targetId, text: text)

        case .sendSpecialKey(let tabId, let keyName):
            let targetId = tabId ?? manager.activeTabId ?? ""
            if let key = AutomationKey(rawValue: keyName) {
                sendSpecialKey(tabId: targetId, key: key)
            }

        case .wait(let seconds):
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))

        case .waitForOutput(let tabId, let pattern, let timeout):
            let targetId = tabId ?? manager.activeTabId ?? ""
            await waitForOutput(tabId: targetId, pattern: pattern, timeout: timeout)

        case .splitPane(let axisStr):
            let axis: SplitAxis = axisStr == "vertical" ? .vertical : .horizontal
            if let activeId = manager.activeTabId {
                manager.splitPane(tabId: activeId, axis: axis)
            }

        case .newTab(let projectPath):
            let path = projectPath ?? NSHomeDirectory()
            let _ = manager.addTab(projectPath: path)
        }
    }

    /// 패턴 감지까지 대기 — 메인 스레드 점유를 최소화하기 위해
    /// 블록 확인만 메인에서 하고 sleep은 백그라운드에서 수행
    private func waitForOutput(tabId: String, pattern: String, timeout: Double) async {
        let startTime = Date()
        let checkInterval: UInt64 = 500_000_000 // 0.5s

        while !Task.isCancelled && Date().timeIntervalSince(startTime) < timeout {
            let found = await MainActor.run {
                SessionManager.shared.tabs
                    .first(where: { $0.id == tabId })?
                    .blocks.suffix(5)
                    .contains(where: { $0.content.contains(pattern) }) ?? false
            }
            if found { return }
            do { try await Task.sleep(nanoseconds: checkInterval) }
            catch { return } // 취소 시 즉시 종료
        }
    }

    // MARK: - Script Loading

    func loadScript(from url: URL) -> AutomationScript? {
        guard let data = try? Data(contentsOf: url),
              let script = try? JSONDecoder().decode(AutomationScript.self, from: data) else {
            return nil
        }
        return script
    }

    // MARK: - Macros

    func loadMacros() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode([AutomationMacro].self, from: data) {
            macros = saved
        }
    }

    func saveMacros() {
        if let data = try? JSONEncoder().encode(macros) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    func addMacro(_ macro: AutomationMacro) {
        macros.append(macro)
        saveMacros()
    }

    func deleteMacro(id: String) {
        macros.removeAll { $0.id == id }
        saveMacros()
    }

    func runMacro(name: String) {
        guard let macro = macros.first(where: { $0.name.lowercased() == name.lowercased() }) else { return }
        runScript(macro.script)
    }
}

// MARK: - Data Types

enum AutomationKey: String, Codable {
    case enter, tab, escape, backspace
    case ctrlC = "ctrl-c"
    case ctrlD = "ctrl-d"
    case ctrlZ = "ctrl-z"
    case ctrlL = "ctrl-l"
    case up, down, left, right

    var escapeSequence: String {
        switch self {
        case .enter: return "\r"
        case .tab: return "\t"
        case .escape: return "\u{1B}"
        case .backspace: return "\u{7F}"
        case .ctrlC: return "\u{03}"
        case .ctrlD: return "\u{04}"
        case .ctrlZ: return "\u{1A}"
        case .ctrlL: return "\u{0C}"
        case .up: return "\u{1B}[A"
        case .down: return "\u{1B}[B"
        case .right: return "\u{1B}[C"
        case .left: return "\u{1B}[D"
        }
    }
}

struct AutomationScript: Codable {
    let name: String
    let steps: [AutomationStep]
}

enum AutomationStep: Codable {
    case sendText(tabId: String?, text: String)
    case sendSpecialKey(tabId: String?, key: String)
    case wait(seconds: Double)
    case waitForOutput(tabId: String?, pattern: String, timeout: Double)
    case splitPane(axis: String)
    case newTab(projectPath: String?)
}

struct AutomationMacro: Codable, Identifiable {
    let id: String
    var name: String
    var description: String
    var script: AutomationScript

    init(id: String = UUID().uuidString, name: String, description: String = "", script: AutomationScript) {
        self.id = id; self.name = name; self.description = description; self.script = script
    }
}

// Notification.Name.dofficeSendKeysToTerminal is declared in DofficeApp.swift
