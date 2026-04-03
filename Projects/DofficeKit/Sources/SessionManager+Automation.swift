import SwiftUI
import Darwin
import AppKit
import DesignSystem

extension SessionManager {
    // MARK: - Automation Workflow

    public func prepareDirectDeveloperWorkflowIfNeeded(for tab: TerminalTab, prompt: String) {
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

    public func routePromptIfNeeded(for tab: TerminalTab, prompt: String) -> Bool {
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

    internal func hasAutomationInFlight(for sourceId: String, roles: [WorkerJob]) -> Bool {
        tabs.contains {
            roles.contains($0.workerJob) &&
            $0.automationSourceTabId == sourceId &&
            $0.isProcessing
        }
    }

    internal func automationThrottleReason(for role: WorkerJob) -> String? {
        guard AppSettings.shared.tokenProtectionEnabled else { return nil }
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

    internal func availableAutomationCharacter(for role: WorkerJob, sourceId: String) -> WorkerCharacter? {
        let registry = CharacterRegistry.shared
        let occupiedIds = occupiedCharacterIds()
        return registry.hiredCharacters(for: role).first { character in
            if reusableAutomationTab(for: sourceId, role: role, preferredCharacterId: character.id) != nil {
                return true
            }
            return !occupiedIds.contains(character.id)
        }
    }

    internal func reusableAutomationTab(
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
    internal func startOrReuseAutomationTab(
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

    internal func applyAutomationSettings(to tab: TerminalTab, role: WorkerJob) {
        let protectionEnabled = AppSettings.shared.tokenProtectionEnabled
        switch role {
        case .planner, .designer, .reporter, .sre:
            tab.selectedModel = .haiku
            tab.effortLevel = .low
            if protectionEnabled { tab.tokenLimit = 8_000 }
        case .reviewer, .qa:
            tab.selectedModel = .sonnet
            tab.effortLevel = .low
            if protectionEnabled { tab.tokenLimit = 12_000 }
        default:
            break
        }
    }

    internal func handleTabCycleCompleted(_ tab: TerminalTab) {
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

    internal func handlePlannerCompletion(_ plannerTab: TerminalTab) {
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

    internal func handleDesignerCompletion(_ designerTab: TerminalTab) {
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

    internal func handleDeveloperCompletion(_ tab: TerminalTab) {
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

    internal func handleReviewerCompletion(_ reviewerTab: TerminalTab) {
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

    internal func handleQACompletion(_ qaTab: TerminalTab) {
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

    internal func handleReporterCompletion(_ reporterTab: TerminalTab) {
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

    internal func handleSRECompletion(_ sreTab: TerminalTab) {
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

    internal func launchQA(for sourceTab: TerminalTab, reviewSummary: String?, handoffSourceName: String) {
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

    internal func dispatchDeveloperFromPreparation(for sourceTab: TerminalTab, handoffSourceName: String) {
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

    internal func requestDeveloperRevision(for sourceTab: TerminalTab, feedback: String, from role: WorkerJob) {
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

    internal func launchCompletionRecipients(
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
}
