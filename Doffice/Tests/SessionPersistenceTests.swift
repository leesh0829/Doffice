import XCTest
import SwiftUI
@testable import Doffice

final class SessionPersistenceTests: XCTestCase {
    func testApplySavedSessionConfigurationRestoresAdvancedOptions() {
        let tab = TerminalTab(
            id: "tab-config",
            projectName: "Demo",
            projectPath: "/tmp/demo",
            workerName: "Tester",
            workerColor: .blue
        )

        let saved = makeSavedSession(
            branch: "feature/restore",
            selectedModel: ClaudeModel.opus.rawValue,
            effortLevel: EffortLevel.max.rawValue,
            outputMode: OutputMode.resultOnly.rawValue,
            tokenLimit: 42_000,
            permissionMode: PermissionMode.acceptEdits.rawValue,
            systemPrompt: "Follow project conventions",
            maxBudgetUSD: 12.5,
            allowedTools: "Read,Edit",
            disallowedTools: "Bash",
            additionalDirs: ["/tmp/extra-a", "/tmp/extra-b"],
            continueSession: true,
            useWorktree: true,
            fallbackModel: "sonnet",
            sessionName: "restore-me",
            jsonSchema: "{\"type\":\"object\"}",
            mcpConfigPaths: ["/tmp/mcp.json"],
            customAgent: "reviewer",
            customAgentsJSON: "{\"agents\":[]}",
            pluginDirs: ["/tmp/plugins"],
            customTools: "Read,Edit",
            enableChrome: false,
            forkSession: true,
            fromPR: "42",
            enableBrief: true,
            tmuxMode: true,
            strictMcpConfig: true,
            settingSources: "user,workspace",
            settingsFileOrJSON: "{\"sandbox\":\"danger-full-access\"}",
            betaHeaders: "x-beta:true",
            sessionId: "session-123"
        )

        tab.applySavedSessionConfiguration(saved)

        XCTAssertEqual(tab.selectedModel, .opus)
        XCTAssertEqual(tab.effortLevel, .max)
        XCTAssertEqual(tab.outputMode, .resultOnly)
        XCTAssertEqual(tab.tokenLimit, 42_000)
        XCTAssertEqual(tab.permissionMode, .acceptEdits)
        XCTAssertEqual(tab.systemPrompt, "Follow project conventions")
        XCTAssertEqual(tab.maxBudgetUSD, 12.5)
        XCTAssertEqual(tab.allowedTools, "Read,Edit")
        XCTAssertEqual(tab.disallowedTools, "Bash")
        XCTAssertEqual(tab.additionalDirs, ["/tmp/extra-a", "/tmp/extra-b"])
        XCTAssertTrue(tab.continueSession)
        XCTAssertTrue(tab.useWorktree)
        XCTAssertEqual(tab.fallbackModel, "sonnet")
        XCTAssertEqual(tab.sessionName, "restore-me")
        XCTAssertEqual(tab.jsonSchema, "{\"type\":\"object\"}")
        XCTAssertEqual(tab.mcpConfigPaths, ["/tmp/mcp.json"])
        XCTAssertEqual(tab.customAgent, "reviewer")
        XCTAssertEqual(tab.customAgentsJSON, "{\"agents\":[]}")
        XCTAssertEqual(tab.pluginDirs, ["/tmp/plugins"])
        XCTAssertEqual(tab.customTools, "Read,Edit")
        XCTAssertFalse(tab.enableChrome)
        XCTAssertTrue(tab.forkSession)
        XCTAssertEqual(tab.fromPR, "42")
        XCTAssertTrue(tab.enableBrief)
        XCTAssertTrue(tab.tmuxMode)
        XCTAssertTrue(tab.strictMcpConfig)
        XCTAssertEqual(tab.settingSources, "user,workspace")
        XCTAssertEqual(tab.settingsFileOrJSON, "{\"sandbox\":\"danger-full-access\"}")
        XCTAssertEqual(tab.betaHeaders, "x-beta:true")
        XCTAssertEqual(tab.branch, "feature/restore")
        XCTAssertEqual(tab.persistedSessionId, "session-123")
    }

    func testRestoreSavedSessionSnapshotPreservesMetricsWithoutReplay() {
        let tab = TerminalTab(
            id: "tab-snapshot",
            projectName: "Demo",
            projectPath: "/tmp/demo",
            workerName: "Tester",
            workerColor: .green
        )
        tab.initialPrompt = "should be cleared"

        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let saved = makeSavedSession(
            tokensUsed: 120,
            inputTokensUsed: 45,
            outputTokensUsed: 75,
            totalCost: 1.75,
            startTime: start,
            lastActivityTime: start.addingTimeInterval(90),
            summaryFiles: ["Sources/App.swift"],
            summaryDuration: 33,
            summaryTokens: 120,
            commandCount: 7,
            errorCount: 2,
            lastPrompt: "continue the refactor",
            lastResultText: "done",
            completedPromptCount: 3
        )

        tab.restoreSavedSessionSnapshot(saved)

        XCTAssertEqual(tab.tokensUsed, 120)
        XCTAssertEqual(tab.inputTokensUsed, 45)
        XCTAssertEqual(tab.outputTokensUsed, 75)
        XCTAssertEqual(tab.totalCost, 1.75)
        XCTAssertEqual(tab.commandCount, 7)
        XCTAssertEqual(tab.errorCount, 2)
        XCTAssertEqual(tab.completedPromptCount, 3)
        XCTAssertEqual(tab.lastPromptText, "continue the refactor")
        XCTAssertEqual(tab.lastResultText, "done")
        XCTAssertNil(tab.initialPrompt)
        XCTAssertFalse(tab.isCompleted)
        XCTAssertTrue(tab.isRunning)
        XCTAssertEqual(tab.startTime, start)
        XCTAssertEqual(tab.lastActivityTime, start.addingTimeInterval(90))
        XCTAssertEqual(tab.summary?.filesModified, ["Sources/App.swift"])
        XCTAssertEqual(tab.summary?.duration, 33)
        XCTAssertEqual(tab.summary?.tokenCount, 120)
    }

    func testSaveLoadAndRecoveryBundleKeepSessionIdentityAndFiles() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let sessionsURL = root.appendingPathComponent("sessions.json")
        let projectURL = root.appendingPathComponent("DemoProject", isDirectory: true)
        let sourceURL = projectURL.appendingPathComponent("Sources/App.swift")

        try fileManager.createDirectory(at: sourceURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "print(\"hello\")\n".write(to: sourceURL, atomically: true, encoding: .utf8)
        defer { try? fileManager.removeItem(at: root) }

        let store = SessionStore(fileURL: sessionsURL, writeDelay: 0)
        let tab = TerminalTab(
            id: "tab-identity",
            projectName: "DemoProject",
            projectPath: projectURL.path,
            workerName: "Worker",
            workerColor: .orange
        )
        tab.selectedModel = .opus
        tab.effortLevel = .high
        tab.outputMode = .full
        tab.permissionMode = .acceptEdits
        tab.branch = "main"
        tab.continueSession = true
        tab.lastPromptText = "fix restore"
        tab.lastResultText = "restored"
        tab.completedPromptCount = 2
        tab.tokensUsed = 88
        tab.inputTokensUsed = 31
        tab.outputTokensUsed = 57
        tab.totalCost = 0.91
        tab.commandCount = 5
        tab.errorCount = 1
        tab.fileChanges = [
            FileChangeRecord(
                path: sourceURL.path,
                fileName: "App.swift",
                action: "Edit",
                timestamp: Date(),
                success: true
            )
        ]

        tab.applySavedSessionConfiguration(
            makeSavedSession(
                branch: "main",
                selectedModel: ClaudeModel.opus.rawValue,
                effortLevel: EffortLevel.high.rawValue,
                outputMode: OutputMode.full.rawValue,
                permissionMode: PermissionMode.acceptEdits.rawValue,
                continueSession: true,
                sessionId: "session-identity"
            )
        )

        store.save(tabs: [tab], immediately: true)

        let reloadedStore = SessionStore(fileURL: sessionsURL, writeDelay: 0)
        let loaded = try XCTUnwrap(reloadedStore.load().first)
        XCTAssertEqual(loaded.tabId, "tab-identity")
        XCTAssertEqual(loaded.selectedModel, ClaudeModel.opus.rawValue)
        XCTAssertEqual(loaded.effortLevel, EffortLevel.high.rawValue)
        XCTAssertEqual(loaded.permissionMode, PermissionMode.acceptEdits.rawValue)
        XCTAssertEqual(loaded.branch, "main")
        XCTAssertEqual(loaded.sessionId, "session-identity")
        XCTAssertEqual(loaded.lastPrompt, "fix restore")
        XCTAssertEqual(loaded.fileChanges?.count, 1)

        let bundleURL = try XCTUnwrap(reloadedStore.writeRecoveryBundle(for: loaded, reason: "unit-test"))
        let readmeURL = bundleURL.appendingPathComponent("README.md")
        let copiedFileURL = bundleURL.appendingPathComponent("files/Sources/App.swift")
        XCTAssertTrue(fileManager.fileExists(atPath: readmeURL.path))
        XCTAssertTrue(fileManager.fileExists(atPath: copiedFileURL.path))

        let readme = try String(contentsOf: readmeURL, encoding: .utf8)
        XCTAssertTrue(readme.contains("Session ID: session-identity"))
        XCTAssertTrue(readme.contains("fix restore"))
        XCTAssertTrue(readme.contains("`Edit` \(sourceURL.path)"))
    }

    private func makeSavedSession(
        projectName: String = "DemoProject",
        projectPath: String = "/tmp/demo",
        workerName: String = "Worker",
        workerColorHex: String = "112233",
        tokensUsed: Int = 0,
        inputTokensUsed: Int? = nil,
        outputTokensUsed: Int? = nil,
        totalCost: Double? = nil,
        branch: String? = nil,
        startTime: Date = Date(timeIntervalSince1970: 1_700_000_000),
        lastActivityTime: Date? = nil,
        summaryFiles: [String]? = nil,
        summaryDuration: TimeInterval? = nil,
        summaryTokens: Int? = nil,
        commandCount: Int? = nil,
        errorCount: Int? = nil,
        lastPrompt: String? = nil,
        lastResultText: String? = nil,
        completedPromptCount: Int? = nil,
        selectedModel: String? = nil,
        effortLevel: String? = nil,
        outputMode: String? = nil,
        tokenLimit: Int? = nil,
        permissionMode: String? = nil,
        systemPrompt: String? = nil,
        maxBudgetUSD: Double? = nil,
        allowedTools: String? = nil,
        disallowedTools: String? = nil,
        additionalDirs: [String]? = nil,
        continueSession: Bool? = nil,
        useWorktree: Bool? = nil,
        fallbackModel: String? = nil,
        sessionName: String? = nil,
        jsonSchema: String? = nil,
        mcpConfigPaths: [String]? = nil,
        customAgent: String? = nil,
        customAgentsJSON: String? = nil,
        pluginDirs: [String]? = nil,
        customTools: String? = nil,
        enableChrome: Bool? = nil,
        forkSession: Bool? = nil,
        fromPR: String? = nil,
        enableBrief: Bool? = nil,
        tmuxMode: Bool? = nil,
        strictMcpConfig: Bool? = nil,
        settingSources: String? = nil,
        settingsFileOrJSON: String? = nil,
        betaHeaders: String? = nil,
        sessionId: String? = nil,
        fileChanges: [SavedFileChange]? = nil
    ) -> SavedSession {
        SavedSession(
            tabId: "saved-tab",
            projectName: projectName,
            projectPath: projectPath,
            workerName: workerName,
            workerColorHex: workerColorHex,
            characterId: nil,
            tokensUsed: tokensUsed,
            inputTokensUsed: inputTokensUsed,
            outputTokensUsed: outputTokensUsed,
            totalCost: totalCost,
            branch: branch,
            startTime: startTime,
            lastActivityTime: lastActivityTime,
            isCompleted: false,
            initialPrompt: "original prompt",
            summaryFiles: summaryFiles,
            summaryDuration: summaryDuration,
            summaryTokens: summaryTokens,
            commandCount: commandCount,
            errorCount: errorCount,
            wasProcessing: true,
            lastPrompt: lastPrompt,
            lastResultText: lastResultText,
            completedPromptCount: completedPromptCount,
            selectedModel: selectedModel,
            effortLevel: effortLevel,
            outputMode: outputMode,
            tokenLimit: tokenLimit,
            permissionMode: permissionMode,
            systemPrompt: systemPrompt,
            maxBudgetUSD: maxBudgetUSD,
            allowedTools: allowedTools,
            disallowedTools: disallowedTools,
            additionalDirs: additionalDirs,
            continueSession: continueSession,
            useWorktree: useWorktree,
            fallbackModel: fallbackModel,
            sessionName: sessionName,
            jsonSchema: jsonSchema,
            mcpConfigPaths: mcpConfigPaths,
            customAgent: customAgent,
            customAgentsJSON: customAgentsJSON,
            pluginDirs: pluginDirs,
            customTools: customTools,
            enableChrome: enableChrome,
            forkSession: forkSession,
            fromPR: fromPR,
            enableBrief: enableBrief,
            tmuxMode: tmuxMode,
            strictMcpConfig: strictMcpConfig,
            settingSources: settingSources,
            settingsFileOrJSON: settingsFileOrJSON,
            betaHeaders: betaHeaders,
            sessionId: sessionId,
            fileChanges: fileChanges
        )
    }
}
