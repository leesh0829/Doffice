import Foundation
import SwiftUI
import AppKit

// MARK: - Feature 4: 세션 기록 저장/복원

struct SavedFileChange: Codable {
    let path: String
    let fileName: String
    let action: String
    let timestamp: Date
    let success: Bool

    init(record: FileChangeRecord) {
        path = record.path
        fileName = record.fileName
        action = record.action
        timestamp = record.timestamp
        success = record.success
    }

    var fileChangeRecord: FileChangeRecord {
        FileChangeRecord(
            path: path,
            fileName: fileName,
            action: action,
            timestamp: timestamp,
            success: success
        )
    }
}

struct SavedSession: Codable {
    let tabId: String?
    let projectName: String
    let projectPath: String
    let workerName: String
    let workerColorHex: String
    let characterId: String?
    let tokensUsed: Int
    let inputTokensUsed: Int?
    let outputTokensUsed: Int?
    let totalCost: Double?
    let branch: String?
    let startTime: Date
    let lastActivityTime: Date?
    let isCompleted: Bool
    let initialPrompt: String?
    // Summary
    let summaryFiles: [String]?
    let summaryDuration: TimeInterval?
    let summaryTokens: Int?
    let commandCount: Int?
    let errorCount: Int?
    // 강제 종료 시 복원용
    let wasProcessing: Bool?
    let lastPrompt: String?
    let lastResultText: String?
    let completedPromptCount: Int?
    let selectedModel: String?
    let effortLevel: String?
    let outputMode: String?
    let tokenLimit: Int?
    let permissionMode: String?
    let systemPrompt: String?
    let maxBudgetUSD: Double?
    let allowedTools: String?
    let disallowedTools: String?
    let additionalDirs: [String]?
    let continueSession: Bool?
    let useWorktree: Bool?
    let fallbackModel: String?
    let sessionName: String?
    let jsonSchema: String?
    let mcpConfigPaths: [String]?
    let customAgent: String?
    let customAgentsJSON: String?
    let pluginDirs: [String]?
    let customTools: String?
    let enableChrome: Bool?
    let forkSession: Bool?
    let fromPR: String?
    let manualLaunch: Bool?
    let enableBrief: Bool?
    let tmuxMode: Bool?
    let strictMcpConfig: Bool?
    let settingSources: String?
    let settingsFileOrJSON: String?
    let betaHeaders: String?
    let sessionId: String?
    let fileChanges: [SavedFileChange]?
    let chatHistory: [SavedChatBlock]?
    let tabOrder: Int?
}

struct SavedChatBlock: Codable {
    let type: String        // "user", "thought", "completion", "tool", "text", "error", "status"
    let content: String
    let toolName: String?
    let timestamp: Date

    init(block: StreamBlock) {
        switch block.blockType {
        case .userPrompt: self.type = "user"
        case .thought: self.type = "thought"
        case .completion: self.type = "completion"
        case .toolUse(let name, _): self.type = "tool"; self.toolName = name; self.content = block.content; self.timestamp = block.timestamp; return
        case .text: self.type = "text"
        case .error(let msg): self.type = "error"; self.toolName = nil; self.content = msg.isEmpty ? block.content : msg; self.timestamp = block.timestamp; return
        case .status(let msg): self.type = "status"; self.toolName = nil; self.content = msg; self.timestamp = block.timestamp; return
        default: self.type = "text"
        }
        self.toolName = nil
        self.content = block.content
        self.timestamp = block.timestamp
    }

    func toBlock() -> StreamBlock {
        let blockType: StreamBlock.BlockType
        switch type {
        case "user": blockType = .userPrompt
        case "thought": blockType = .thought
        case "completion": blockType = .completion(cost: nil, duration: nil)
        case "tool": blockType = .toolUse(name: toolName ?? "Tool", input: "")
        case "error": blockType = .error(message: content)
        case "status": blockType = .status(message: content)
        default: blockType = .text
        }
        var block = StreamBlock(type: blockType, content: content)
        block.isComplete = true
        return block
    }
}

struct SessionHistory: Codable {
    var sessions: [SavedSession] = []
    var lastSaved: Date = Date()
}

class SessionStore {
    static let shared = SessionStore()

    private static func defaultFileURL() -> URL {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            print("[도피스] Application Support 디렉토리를 찾을 수 없습니다. 임시 디렉토리를 사용합니다.")
            return FileManager.default.temporaryDirectory.appendingPathComponent("doffice_sessions.json")
        }
        let dir = appSupport.appendingPathComponent("Doffice", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            print("[도피스] Application Support/Doffice 디렉토리 생성 실패: \(error.localizedDescription). 임시 디렉토리를 사용합니다.")
            return FileManager.default.temporaryDirectory.appendingPathComponent("doffice_sessions.json")
        }
        return dir.appendingPathComponent("sessions.json")
    }

    private let fileURL: URL
    private let writeDelay: TimeInterval
    private let ioQueue = DispatchQueue(label: "doffice.session-store", qos: .utility)
    private let stateLock = NSLock()
    private var cachedHistory = SessionHistory()
    private var hasLoadedCache = false
    private var saveWorkItem: DispatchWorkItem?

    init(fileURL: URL? = nil, writeDelay: TimeInterval = 0.75) {
        let resolved = fileURL ?? Self.defaultFileURL()
        try? FileManager.default.createDirectory(
            at: resolved.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        self.fileURL = resolved
        self.writeDelay = writeDelay
    }

    var sessionCount: Int {
        snapshot().sessions.count
    }

    func save(tabs: [TerminalTab], immediately: Bool = false) {
        let saved = tabs.enumerated().map { (index, tab) in
            SavedSession(
                tabId: tab.id,
                projectName: tab.projectName,
                projectPath: tab.projectPath,
                workerName: tab.workerName,
                workerColorHex: colorToHex(tab.workerColor),
                characterId: tab.characterId,
                tokensUsed: tab.tokensUsed,
                inputTokensUsed: tab.inputTokensUsed,
                outputTokensUsed: tab.outputTokensUsed,
                totalCost: tab.totalCost,
                branch: tab.branch,
                startTime: tab.startTime,
                lastActivityTime: tab.lastActivityTime,
                isCompleted: tab.isCompleted,
                initialPrompt: tab.initialPrompt,
                summaryFiles: tab.summary?.filesModified,
                summaryDuration: tab.summary?.duration,
                summaryTokens: tab.summary?.tokenCount,
                commandCount: tab.commandCount,
                errorCount: tab.errorCount,
                wasProcessing: tab.isProcessing,
                lastPrompt: tab.lastPromptText,
                lastResultText: tab.lastResultText,
                completedPromptCount: tab.completedPromptCount,
                selectedModel: tab.selectedModel.rawValue,
                effortLevel: tab.effortLevel.rawValue,
                outputMode: tab.outputMode.rawValue,
                tokenLimit: tab.tokenLimit,
                permissionMode: tab.permissionMode.rawValue,
                systemPrompt: tab.systemPrompt,
                maxBudgetUSD: tab.maxBudgetUSD,
                allowedTools: tab.allowedTools,
                disallowedTools: tab.disallowedTools,
                additionalDirs: tab.additionalDirs,
                continueSession: tab.continueSession,
                useWorktree: tab.useWorktree,
                fallbackModel: tab.fallbackModel,
                sessionName: tab.sessionName,
                jsonSchema: tab.jsonSchema,
                mcpConfigPaths: tab.mcpConfigPaths,
                customAgent: tab.customAgent,
                customAgentsJSON: tab.customAgentsJSON,
                pluginDirs: tab.pluginDirs,
                customTools: tab.customTools,
                enableChrome: tab.enableChrome,
                forkSession: tab.forkSession,
                fromPR: tab.fromPR,
                manualLaunch: tab.manualLaunch,
                enableBrief: tab.enableBrief,
                tmuxMode: tab.tmuxMode,
                strictMcpConfig: tab.strictMcpConfig,
                settingSources: tab.settingSources,
                settingsFileOrJSON: tab.settingsFileOrJSON,
                betaHeaders: tab.betaHeaders,
                sessionId: tab.persistedSessionId,
                fileChanges: tab.fileChanges.map(SavedFileChange.init(record:)),
                chatHistory: tab.blocks.suffix(100).compactMap { block in
                    switch block.blockType {
                    case .userPrompt, .thought, .completion, .text, .error, .status:
                        return SavedChatBlock(block: block)
                    case .toolUse:
                        return SavedChatBlock(block: block)
                    default: return nil
                    }
                },
                tabOrder: index
            )
        }

        let history = SessionHistory(sessions: saved, lastSaved: Date())
        updateCache(history, postNotification: true)
        if immediately {
            writeImmediately(history)
        } else {
            scheduleWrite(history)
        }
    }

    func snapshot() -> SessionHistory {
        loadHistory()
    }

    func load() -> [SavedSession] {
        snapshot().sessions
    }

    func loadLastSaved() -> Date? {
        let history = snapshot()
        return history.sessions.isEmpty ? nil : history.lastSaved
    }

    private func colorToHex(_ color: Color) -> String {
        let nsColor = NSColor(color)
        let resolved = nsColor.usingColorSpace(.sRGB) ??
            nsColor.usingColorSpace(.deviceRGB) ??
            NSColor(srgbRed: 0.5, green: 0.5, blue: 0.5, alpha: 1)
        let r = Int(resolved.redComponent * 255)
        let g = Int(resolved.greenComponent * 255)
        let b = Int(resolved.blueComponent * 255)
        return String(format: "%02x%02x%02x", r, g, b)
    }

    private func loadHistory() -> SessionHistory {
        stateLock.lock()
        if hasLoadedCache {
            let history = cachedHistory
            stateLock.unlock()
            return history
        }
        stateLock.unlock()

        let loadedHistory: SessionHistory
        do {
            let data = try Data(contentsOf: fileURL)
            loadedHistory = try JSONDecoder().decode(SessionHistory.self, from: data)
        } catch let error as NSError where error.domain == NSCocoaErrorDomain && error.code == NSFileReadNoSuchFileError {
            // 파일이 아직 없는 경우 (첫 실행) — 정상
            loadedHistory = SessionHistory()
        } catch {
            print("[도피스] 세션 파일 로드 실패: \(error.localizedDescription). 빈 세션으로 시작합니다.")
            loadedHistory = SessionHistory()
        }

        stateLock.lock()
        cachedHistory = loadedHistory
        hasLoadedCache = true
        let history = cachedHistory
        stateLock.unlock()
        return history
    }

    private func updateCache(_ history: SessionHistory, postNotification: Bool) {
        stateLock.lock()
        cachedHistory = history
        hasLoadedCache = true
        stateLock.unlock()

        guard postNotification else { return }
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .dofficeSessionStoreDidChange, object: nil)
        }
    }

    private func scheduleWrite(_ history: SessionHistory) {
        saveWorkItem?.cancel()
        let snapshot = history
        let workItem = DispatchWorkItem {
            self.persist(snapshot)
        }
        saveWorkItem = workItem
        ioQueue.asyncAfter(deadline: .now() + writeDelay, execute: workItem)
    }

    private func writeImmediately(_ history: SessionHistory) {
        saveWorkItem?.cancel()
        saveWorkItem = nil
        persist(history)
    }

    private func persist(_ history: SessionHistory) {
        do {
            let data = try JSONEncoder().encode(history)
            try data.write(to: fileURL, options: .atomicWrite)
        } catch {
            print("[도피스] 세션 저장 실패 (\(fileURL.path)): \(error.localizedDescription)")
            // 기본 경로에 쓰기 실패 시 임시 디렉토리에 백업 시도
            let fallbackURL = FileManager.default.temporaryDirectory.appendingPathComponent("doffice_sessions_backup.json")
            do {
                let data = try JSONEncoder().encode(history)
                try data.write(to: fallbackURL, options: .atomicWrite)
                print("[도피스] 임시 디렉토리에 세션 백업 저장 완료: \(fallbackURL.path)")
            } catch {
                print("[도피스] 임시 디렉토리 백업도 실패: \(error.localizedDescription)")
            }
        }
    }

    @discardableResult
    func writeRecoveryBundle(for tab: TerminalTab, reason: String) -> URL? {
        let saved = SavedSession(
            tabId: tab.id,
            projectName: tab.projectName,
            projectPath: tab.projectPath,
            workerName: tab.workerName,
            workerColorHex: colorToHex(tab.workerColor),
            characterId: tab.characterId,
            tokensUsed: tab.tokensUsed,
            inputTokensUsed: tab.inputTokensUsed,
            outputTokensUsed: tab.outputTokensUsed,
            totalCost: tab.totalCost,
            branch: tab.branch,
            startTime: tab.startTime,
            lastActivityTime: tab.lastActivityTime,
            isCompleted: tab.isCompleted,
            initialPrompt: tab.initialPrompt,
            summaryFiles: tab.summary?.filesModified,
            summaryDuration: tab.summary?.duration,
            summaryTokens: tab.summary?.tokenCount,
            commandCount: tab.commandCount,
            errorCount: tab.errorCount,
            wasProcessing: tab.isProcessing,
            lastPrompt: tab.lastPromptText,
            lastResultText: tab.lastResultText,
            completedPromptCount: tab.completedPromptCount,
            selectedModel: tab.selectedModel.rawValue,
            effortLevel: tab.effortLevel.rawValue,
            outputMode: tab.outputMode.rawValue,
            tokenLimit: tab.tokenLimit,
            permissionMode: tab.permissionMode.rawValue,
            systemPrompt: tab.systemPrompt,
            maxBudgetUSD: tab.maxBudgetUSD,
            allowedTools: tab.allowedTools,
            disallowedTools: tab.disallowedTools,
            additionalDirs: tab.additionalDirs,
            continueSession: tab.continueSession,
            useWorktree: tab.useWorktree,
            fallbackModel: tab.fallbackModel,
            sessionName: tab.sessionName,
            jsonSchema: tab.jsonSchema,
            mcpConfigPaths: tab.mcpConfigPaths,
            customAgent: tab.customAgent,
            customAgentsJSON: tab.customAgentsJSON,
            pluginDirs: tab.pluginDirs,
            customTools: tab.customTools,
            enableChrome: tab.enableChrome,
            forkSession: tab.forkSession,
            fromPR: tab.fromPR,
            manualLaunch: tab.manualLaunch,
            enableBrief: tab.enableBrief,
            tmuxMode: tab.tmuxMode,
            strictMcpConfig: tab.strictMcpConfig,
            settingSources: tab.settingSources,
            settingsFileOrJSON: tab.settingsFileOrJSON,
            betaHeaders: tab.betaHeaders,
            sessionId: tab.persistedSessionId,
            fileChanges: tab.fileChanges.map(SavedFileChange.init(record:)),
            chatHistory: nil,
            tabOrder: nil
        )
        return writeRecoveryBundle(for: saved, reason: reason)
    }

    @discardableResult
    func writeRecoveryBundle(for saved: SavedSession, reason: String) -> URL? {
        let root = recoveryRoot(for: saved.projectPath)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let stamp = formatter.string(from: Date())
        let bundleURL = root.appendingPathComponent("\(stamp)_\(sanitizePathComponent(saved.projectName))", isDirectory: true)
        let filesURL = bundleURL.appendingPathComponent("files", isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: filesURL, withIntermediateDirectories: true)
        } catch {
            print("[도피스] Failed to create recovery bundle: \(error)")
            return nil
        }

        let copiedFiles = copyChangedFiles(saved.fileChanges ?? [], projectPath: saved.projectPath, destinationRoot: filesURL)
        let promptPreview = (saved.lastPrompt ?? saved.initialPrompt ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let resultPreview = saved.lastResultText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        var lines: [String] = [
            "# 도피스 Recovery",
            "",
            "- Project: \(saved.projectName)",
            "- Path: \(saved.projectPath)",
            "- Worker: \(saved.workerName)",
            "- Reason: \(reason)",
            "- Saved At: \(Date())"
        ]

        if let branch = saved.branch, !branch.isEmpty {
            lines.append("- Branch: \(branch)")
        }
        if let selectedModel = saved.selectedModel {
            lines.append("- Model: \(selectedModel)")
        }
        if let effortLevel = saved.effortLevel {
            lines.append("- Effort: \(effortLevel)")
        }
        if let permissionMode = saved.permissionMode {
            lines.append("- Permission: \(permissionMode)")
        }
        if let sessionId = saved.sessionId, !sessionId.isEmpty {
            lines.append("- Session ID: \(sessionId)")
        }
        lines.append("- Continue Session: \((saved.continueSession ?? false) ? "true" : "false")")
        lines.append("- Tokens: \(saved.tokensUsed)")
        if let totalCost = saved.totalCost {
            lines.append("- Cost: $\(String(format: "%.4f", totalCost))")
        }
        if let completedPromptCount = saved.completedPromptCount {
            lines.append("- Completed Prompts: \(completedPromptCount)")
        }

        if !promptPreview.isEmpty {
            lines += [
                "",
                "## Last Prompt",
                "",
                "```text",
                promptPreview,
                "```"
            ]
        }

        if !resultPreview.isEmpty {
            lines += [
                "",
                "## Last Result",
                "",
                "```text",
                String(resultPreview.prefix(4000)),
                "```"
            ]
        }

        let changedFiles = saved.fileChanges ?? []
        if !changedFiles.isEmpty {
            lines += [
                "",
                "## Changed Files"
            ]
            for file in changedFiles {
                lines.append("- `\(file.action)` \(file.path)")
            }
        }

        if !copiedFiles.isEmpty {
            lines += [
                "",
                "## Copied Snapshots"
            ]
            for copied in copiedFiles {
                lines.append("- `\(copied)`")
            }
        }

        let readmeURL = bundleURL.appendingPathComponent("README.md")
        do {
            try lines.joined(separator: "\n").write(to: readmeURL, atomically: true, encoding: .utf8)
            return bundleURL
        } catch {
            print("[도피스] Failed to write recovery README: \(error)")
            return nil
        }
    }

    private func recoveryRoot(for projectPath: String) -> URL {
        let projectURL = URL(fileURLWithPath: projectPath, isDirectory: true)
        if FileManager.default.fileExists(atPath: projectURL.path) {
            let localRoot = projectURL.appendingPathComponent(".doffice/recovery", isDirectory: true)
            try? FileManager.default.createDirectory(at: localRoot, withIntermediateDirectories: true)
            return localRoot
        }

        let fallback = fileURL.deletingLastPathComponent().appendingPathComponent("recovery", isDirectory: true)
        try? FileManager.default.createDirectory(at: fallback, withIntermediateDirectories: true)
        return fallback
    }

    private func copyChangedFiles(_ files: [SavedFileChange], projectPath: String, destinationRoot: URL) -> [String] {
        let uniqueFiles = Dictionary(grouping: files, by: \.path).compactMap { $0.value.last }
        var copiedPaths: [String] = []

        for file in uniqueFiles {
            let sourceURL = URL(fileURLWithPath: file.path)
            guard FileManager.default.fileExists(atPath: sourceURL.path) else { continue }

            let relativePath: String
            if sourceURL.path.hasPrefix(projectPath + "/") {
                relativePath = String(sourceURL.path.dropFirst(projectPath.count + 1))
            } else {
                relativePath = "\(sanitizePathComponent(file.fileName.isEmpty ? "file" : file.fileName))"
            }

            let destinationURL = destinationRoot.appendingPathComponent(relativePath)
            let parent = destinationURL.deletingLastPathComponent()
            try? FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
            try? FileManager.default.removeItem(at: destinationURL)

            do {
                try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
                copiedPaths.append(relativePath)
            } catch {
                print("[도피스] Failed to copy recovery file \(sourceURL.path): \(error)")
            }
        }

        return copiedPaths.sorted()
    }

    private func sanitizePathComponent(_ input: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let cleaned = input.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" }
        let value = String(cleaned)
            .replacingOccurrences(of: "_+", with: "_", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        return value.isEmpty ? "recovery" : value
    }
}
