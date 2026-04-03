import SwiftUI
import Darwin
import AppKit
import DesignSystem

extension SessionManager {
    // MARK: - Prompt Builder

    internal func templateValue(_ text: String, fallback: String) -> String {
        text.isEmpty ? fallback : text
    }

    internal func templateFileList(_ paths: [String], fallback: String) -> String {
        let unique = Array(Set(paths)).sorted()
        return unique.isEmpty ? fallback : unique.map { "- \($0)" }.joined(separator: "\n")
    }

    internal func buildPlannerPrompt(for tab: TerminalTab, request: String) -> String {
        AutomationTemplateStore.shared.render(
            .planner,
            context: [
                "project_name": tab.projectName,
                "project_path": tab.projectPath,
                "request": templateValue(request, fallback: NSLocalizedString("workflow.request.none", comment: ""))
            ]
        )
    }

    internal func buildDesignerPrompt(for tab: TerminalTab) -> String {
        AutomationTemplateStore.shared.render(
            .designer,
            context: [
                "project_name": tab.projectName,
                "project_path": tab.projectPath,
                "request": templateValue(tab.workflowRequirementText, fallback: NSLocalizedString("workflow.request.none", comment: "")),
                "plan_summary": templateValue(tab.workflowPlanSummary, fallback: NSLocalizedString("workflow.plan.summary.none", comment: ""))
            ]
        )
    }

    internal func buildDeveloperExecutionPrompt(for tab: TerminalTab) -> String {
        AutomationTemplateStore.shared.render(
            .developerExecution,
            context: [
                "project_name": tab.projectName,
                "project_path": tab.projectPath,
                "request": templateValue(tab.workflowRequirementText, fallback: NSLocalizedString("workflow.request.none", comment: "")),
                "plan_summary": templateValue(tab.workflowPlanSummary, fallback: NSLocalizedString("workflow.plan.summary.none", comment: "")),
                "design_summary": templateValue(tab.workflowDesignSummary, fallback: NSLocalizedString("workflow.design.memo.none", comment: ""))
            ]
        )
    }

    internal func buildDeveloperRevisionPrompt(for tab: TerminalTab, feedback: String, from role: WorkerJob) -> String {
        AutomationTemplateStore.shared.render(
            .developerRevision,
            context: [
                "project_name": tab.projectName,
                "project_path": tab.projectPath,
                "request": templateValue(tab.workflowRequirementText, fallback: NSLocalizedString("workflow.request.none", comment: "")),
                "plan_summary": templateValue(tab.workflowPlanSummary, fallback: NSLocalizedString("workflow.plan.summary.none", comment: "")),
                "design_summary": templateValue(tab.workflowDesignSummary, fallback: NSLocalizedString("workflow.design.memo.none", comment: "")),
                "feedback_role": role.displayName,
                "feedback": templateValue(feedback, fallback: NSLocalizedString("workflow.feedback.none", comment: ""))
            ]
        )
    }

    internal func buildReviewPrompt(for tab: TerminalTab) -> String {
        AutomationTemplateStore.shared.render(
            .reviewer,
            context: [
                "project_name": tab.projectName,
                "project_path": tab.projectPath,
                "request": templateValue(tab.workflowRequirementText, fallback: NSLocalizedString("workflow.request.none.review", comment: "")),
                "plan_summary": templateValue(tab.workflowPlanSummary, fallback: NSLocalizedString("workflow.plan.summary.none", comment: "")),
                "design_summary": templateValue(tab.workflowDesignSummary, fallback: NSLocalizedString("workflow.design.summary.none", comment: "")),
                "dev_summary": templateValue(tab.lastCompletionSummary, fallback: NSLocalizedString("workflow.dev.summary.none", comment: "")),
                "changed_files": templateFileList(tab.fileChanges.suffix(10).map(\.path), fallback: NSLocalizedString("workflow.files.none", comment: ""))
            ]
        )
    }

    internal func buildQAPrompt(for tab: TerminalTab, reviewSummary: String?) -> String {
        AutomationTemplateStore.shared.render(
            .qa,
            context: [
                "project_name": tab.projectName,
                "project_path": tab.projectPath,
                "request": templateValue(tab.workflowRequirementText, fallback: NSLocalizedString("workflow.qa.no.requirements", comment: "")),
                "plan_summary": templateValue(tab.workflowPlanSummary, fallback: NSLocalizedString("workflow.plan.summary.none", comment: "")),
                "design_summary": templateValue(tab.workflowDesignSummary, fallback: NSLocalizedString("workflow.design.summary.none", comment: "")),
                "dev_summary": templateValue(tab.lastCompletionSummary, fallback: NSLocalizedString("workflow.dev.summary.none", comment: "")),
                "review_summary": templateValue(reviewSummary ?? "", fallback: NSLocalizedString("workflow.review.summary.none", comment: "")),
                "changed_files": templateFileList(tab.fileChanges.suffix(8).map(\.path), fallback: NSLocalizedString("workflow.files.none", comment: ""))
            ]
        )
    }

    internal func buildReporterPrompt(for sourceTab: TerminalTab, qaSummary: String?, validationSummary: String?, reportPath: String) -> String {
        AutomationTemplateStore.shared.render(
            .reporter,
            context: [
                "project_name": sourceTab.projectName,
                "project_path": sourceTab.projectPath,
                "report_path": reportPath,
                "request": templateValue(sourceTab.workflowRequirementText, fallback: NSLocalizedString("workflow.request.none", comment: "")),
                "plan_summary": templateValue(sourceTab.workflowPlanSummary, fallback: NSLocalizedString("workflow.plan.summary.none", comment: "")),
                "design_summary": templateValue(sourceTab.workflowDesignSummary, fallback: NSLocalizedString("workflow.design.summary.none", comment: "")),
                "dev_summary": templateValue(sourceTab.lastCompletionSummary, fallback: NSLocalizedString("workflow.dev.completion.none", comment: "")),
                "review_summary": templateValue(sourceTab.workflowReviewSummary, fallback: NSLocalizedString("workflow.review.summary.report.none", comment: "")),
                "qa_summary": templateValue(qaSummary ?? "", fallback: NSLocalizedString("workflow.qa.summary.none", comment: "")),
                "validation_summary": templateValue(validationSummary ?? "", fallback: NSLocalizedString("workflow.validation.none", comment: "")),
                "changed_files": templateFileList(sourceTab.fileChanges.map(\.path), fallback: NSLocalizedString("workflow.files.changed.none", comment: ""))
            ]
        )
    }

    internal func buildSREPrompt(for sourceTab: TerminalTab, qaSummary: String?, validationSummary: String?) -> String {
        AutomationTemplateStore.shared.render(
            .sre,
            context: [
                "project_name": sourceTab.projectName,
                "project_path": sourceTab.projectPath,
                "request": templateValue(sourceTab.workflowRequirementText, fallback: NSLocalizedString("workflow.request.none", comment: "")),
                "dev_summary": templateValue(sourceTab.lastCompletionSummary, fallback: NSLocalizedString("workflow.dev.completion.none", comment: "")),
                "qa_summary": templateValue(qaSummary ?? "", fallback: NSLocalizedString("workflow.qa.summary.none", comment: "")),
                "validation_summary": templateValue(validationSummary ?? "", fallback: NSLocalizedString("workflow.validation.none", comment: "")),
                "changed_files": templateFileList(sourceTab.fileChanges.map(\.path), fallback: NSLocalizedString("workflow.files.changed.none", comment: ""))
            ]
        )
    }

    internal func makeReportPath(for tab: TerminalTab) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let safeProjectName = tab.projectName
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9_-]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        let fileName = "\(formatter.string(from: Date()))-\(safeProjectName.isEmpty ? "report" : safeProjectName)-report.md"
        return (tab.projectPath as NSString).appendingPathComponent(".doffice/reports/\(fileName)")
    }

    internal func ensureReportDirectoryExists(for reportPath: String) {
        let directory = (reportPath as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true, attributes: nil)
    }
}
