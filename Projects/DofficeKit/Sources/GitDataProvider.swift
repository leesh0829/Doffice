import SwiftUI
import Combine
import DesignSystem

// ═══════════════════════════════════════════════════════
// MARK: - Git Data Models
// ═══════════════════════════════════════════════════════

public struct GitCommitNode: Identifiable, Equatable {
    public let id: String            // full SHA
    public let shortHash: String
    public let message: String
    public let body: String          // full message body (for co-authors, etc.)
    public let author: String
    public let authorEmail: String
    public let date: Date
    public let parentHashes: [String]
    public let coAuthors: [String]
    public let refs: [GitRef]
    public var lane: Int = 0         // column for graph drawing
    public var activeLanes: Set<Int> = [] // which lanes are active at this row (for drawing vertical lines)

    public struct GitRef: Equatable {
        public let name: String
        public let type: RefType
        public enum RefType: Equatable { case branch, remoteBranch, tag, head }
    }
}

public struct GitFileChange: Identifiable, Hashable {
    public let id: String
    public let path: String
    public let fileName: String
    public let status: ChangeStatus
    public let isStaged: Bool

    public init(path: String, fileName: String, status: ChangeStatus, isStaged: Bool) {
        self.id = "\(isStaged ? "S" : "U")_\(status.rawValue)_\(path)"
        self.path = path
        self.fileName = fileName
        self.status = status
        self.isStaged = isStaged
    }

    public enum ChangeStatus: String, Hashable {
        case modified = "M", added = "A", deleted = "D"
        case renamed = "R", copied = "C", untracked = "?"
        case typeChanged = "T", conflict = "U"

        public var icon: String {
            switch self {
            case .modified: return "pencil.circle.fill"
            case .added: return "plus.circle.fill"
            case .deleted: return "minus.circle.fill"
            case .renamed: return "arrow.right.circle.fill"
            case .copied: return "doc.on.doc.fill"
            case .untracked: return "questionmark.circle.fill"
            case .typeChanged: return "arrow.triangle.2.circlepath"
            case .conflict: return "exclamationmark.triangle.fill"
            }
        }

        public var color: Color {
            switch self {
            case .modified: return Theme.yellow
            case .added: return Theme.green
            case .deleted: return Theme.red
            case .renamed: return Theme.cyan
            case .copied: return Theme.accent
            case .untracked: return Theme.textDim
            case .typeChanged: return Theme.orange
            case .conflict: return Theme.red
            }
        }
    }
}

public struct GitBranchInfo: Identifiable {
    public var id: String { name }
    public let name: String
    public let isRemote: Bool
    public let isCurrent: Bool
    public let upstream: String?
    public let ahead: Int
    public let behind: Int
}

public struct GitStashEntry: Identifiable {
    public let id: Int
    public let message: String
}

// ═══════════════════════════════════════════════════════
// MARK: - Blame Model
// ═══════════════════════════════════════════════════════

public struct BlameLine: Identifiable {
    public let id: Int              // line number (1-based)
    public let hash: String         // commit SHA
    public let shortHash: String
    public let author: String
    public let date: Date
    public let content: String      // actual line content
}

// ═══════════════════════════════════════════════════════
// MARK: - Diff Models
// ═══════════════════════════════════════════════════════

public struct GitDiffResult {
    public let filePath: String
    public let hunks: [DiffHunk]
    public let isBinary: Bool
    public let stats: (additions: Int, deletions: Int)

    public static func == (lhs: GitDiffResult, rhs: GitDiffResult) -> Bool {
        lhs.filePath == rhs.filePath && lhs.hunks == rhs.hunks && lhs.isBinary == rhs.isBinary
    }
}

public struct DiffHunk: Equatable {
    public let header: String // @@ -1,3 +1,4 @@
    public let lines: [DiffLine]
}

public struct DiffLine: Equatable {
    public let type: LineType
    public let content: String
    public let oldLineNum: Int?
    public let newLineNum: Int?

    public enum LineType: Equatable {
        case context, addition, deletion
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - Git Data Provider
// ═══════════════════════════════════════════════════════

@MainActor
public class GitDataProvider: ObservableObject {
    // MARK: - Published State

    @Published public var commits: [GitCommitNode] = []
    @Published public var workingDirStaged: [GitFileChange] = []
    @Published public var workingDirUnstaged: [GitFileChange] = []
    @Published public var branches: [GitBranchInfo] = []
    @Published public var stashes: [GitStashEntry] = []
    @Published public var currentBranch: String = ""
    @Published public var isLoading = false
    @Published public var selectedCommitFiles: [GitFileChange] = []
    @Published public var maxLaneCount: Int = 1

    // Diff support
    @Published public var diffResult: GitDiffResult?

    // Search
    @Published public var searchQuery: String = ""

    // Conflict detection
    @Published public var conflictFiles: [GitFileChange] = []

    // Error reporting
    @Published public var lastError: String?

    // Pagination
    @Published public var commitPage: Int = 0
    public let commitsPerPage = 100
    private var allCommitsLoaded = false

    // Precomputed lookup: SHA -> lane (for O(1) parent lane lookup in graph drawing)
    public var commitLaneMap: [String: Int] = [:]

    private var projectPath: String = ""
    private var refreshTimer: AnyCancellable?

    // Git availability check (cached)
    private static var gitAvailable: Bool?
    private static func checkGitAvailable() -> Bool {
        if let cached = gitAvailable { return cached }
        let result = TerminalTab.shellSync("git --version 2>/dev/null")
        gitAvailable = result?.contains("git version") ?? false
        return gitAvailable ?? false
    }

    // Lane colors — computed each time to respect dark/light mode changes
    public static var laneColors: [Color] {
        [Theme.accent, Theme.green, Theme.purple, Theme.orange,
         Theme.cyan, Theme.pink, Theme.yellow, Theme.red]
    }

    // MARK: - Filtered Commits (search)

    public var filteredCommits: [GitCommitNode] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return commits }
        return commits.filter {
            $0.message.localizedCaseInsensitiveContains(query) ||
            $0.author.localizedCaseInsensitiveContains(query) ||
            $0.shortHash.localizedCaseInsensitiveContains(query)
        }
    }

    // MARK: - Lifecycle

    public func start(projectPath: String) {
        guard !projectPath.isEmpty else { return }
        self.projectPath = projectPath
        commitPage = 0
        allCommitsLoaded = false

        guard Self.checkGitAvailable() else {
            lastError = NSLocalizedString("git.not.installed", comment: "")
            return
        }

        refreshAll()
        refreshTimer = Timer.publish(every: 8, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.refreshAll() }
    }

    public func stop() {
        refreshTimer?.cancel()
        refreshTimer = nil
    }

    // MARK: - Full Refresh

    public func refreshAll() {
        guard !projectPath.isEmpty, !isLoading else { return }
        guard Self.checkGitAvailable() else {
            lastError = NSLocalizedString("git.not.installed", comment: "")
            isLoading = false
            return
        }
        isLoading = true
        lastError = nil
        let path = projectPath
        let page = commitPage
        let perPage = commitsPerPage
        let totalLimit = (page + 1) * perPage

        DispatchQueue.global(qos: .userInitiated).async {
            let commits = GitDataParser.parseCommits(path: path, limit: totalLimit)
            let (staged, unstaged) = GitDataParser.parseWorkingDir(path: path)
            let branches = GitDataParser.parseBranches(path: path)
            let stashes = GitDataParser.parseStashes(path: path)
            let conflicts = GitDataParser.parseConflicts(path: path)
            let currentBr = TerminalTab.shellSync("git -C \"\(path)\" branch --show-current 2>/dev/null")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let maxLane = (commits.map { $0.lane }.max() ?? 0) + 1
            var laneMap: [String: Int] = [:]
            for c in commits { laneMap[c.id] = c.lane }
            let fullyLoaded = commits.count < totalLimit

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.commits = commits
                self.workingDirStaged = staged
                self.workingDirUnstaged = unstaged
                self.branches = branches
                self.stashes = stashes
                self.conflictFiles = conflicts
                self.currentBranch = currentBr
                self.maxLaneCount = maxLane
                self.commitLaneMap = laneMap
                self.allCommitsLoaded = fullyLoaded
                self.isLoading = false
            }
        }
    }

    // MARK: - Pagination

    public func loadMoreCommits() {
        guard !allCommitsLoaded, !isLoading else { return }
        commitPage += 1
        isLoading = true
        lastError = nil
        let path = projectPath
        let totalLimit = (commitPage + 1) * commitsPerPage

        DispatchQueue.global(qos: .userInitiated).async {
            let commits = GitDataParser.parseCommits(path: path, limit: totalLimit)
            let maxLane = (commits.map { $0.lane }.max() ?? 0) + 1
            var laneMap: [String: Int] = [:]
            for c in commits { laneMap[c.id] = c.lane }
            let fullyLoaded = commits.count < totalLimit

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.commits = commits
                self.maxLaneCount = maxLane
                self.commitLaneMap = laneMap
                self.allCommitsLoaded = fullyLoaded
                self.isLoading = false
            }
        }
    }

    // MARK: - Commit Files

    public func fetchCommitFiles(hash: String) {
        // Validate hash is hex-only (prevent command injection)
        guard hash.allSatisfy({ $0.isHexDigit }) else { return }
        let path = projectPath
        DispatchQueue.global(qos: .userInitiated).async {
            let raw = TerminalTab.shellSync("git -C \"\(path)\" diff-tree --no-commit-id --name-status -r \(hash) 2>/dev/null") ?? ""
            let files = raw.components(separatedBy: "\n").compactMap { line -> GitFileChange? in
                let parts = line.split(separator: "\t", maxSplits: 1)
                guard parts.count == 2 else { return nil }
                let statusStr = String(parts[0]).trimmingCharacters(in: .whitespaces)
                let filePath = String(parts[1])
                let status = GitFileChange.ChangeStatus(rawValue: String(statusStr.prefix(1))) ?? .modified
                return GitFileChange(path: filePath, fileName: (filePath as NSString).lastPathComponent, status: status, isStaged: true)
            }
            DispatchQueue.main.async { [weak self] in self?.selectedCommitFiles = files }
        }
    }

    // MARK: - Diff Support

    /// Fetch raw diff string for a file.
    public func fetchFileDiff(projectPath: String? = nil, path filePath: String, staged: Bool, hash: String? = nil) -> String {
        let root = projectPath ?? self.projectPath
        guard !root.isEmpty else { return "" }
        let safePath = GitDataParser.sanitizePath(filePath)

        if let hash = hash {
            // Commit diff
            guard hash.allSatisfy({ $0.isHexDigit }) else { return "" }
            return TerminalTab.shellSync("git -C \"\(root)\" diff \(hash)^..\(hash) -- \"\(safePath)\" 2>/dev/null") ?? ""
        }

        if staged {
            return TerminalTab.shellSync("git -C \"\(root)\" diff --cached -- \"\(safePath)\" 2>/dev/null") ?? ""
        }

        // Check if untracked by looking at status
        let statusRaw = TerminalTab.shellSync("git -C \"\(root)\" status --porcelain -- \"\(safePath)\" 2>/dev/null") ?? ""
        let isUntracked = statusRaw.hasPrefix("??")

        if isUntracked {
            // Read file content for untracked files
            let fullPath = root.hasSuffix("/") ? "\(root)\(safePath)" : "\(root)/\(safePath)"
            return TerminalTab.shellSync("cat \"\(fullPath)\" 2>/dev/null") ?? ""
        }

        return TerminalTab.shellSync("git -C \"\(root)\" diff -- \"\(safePath)\" 2>/dev/null") ?? ""
    }

    /// Fetch and parse diff into structured result. Updates `diffResult` on main thread.
    public func fetchParsedDiff(path filePath: String, staged: Bool, hash: String? = nil) {
        let root = projectPath
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let rawDiff: String
            let safePath = GitDataParser.sanitizePath(filePath)

            if let hash = hash {
                guard hash.allSatisfy({ $0.isHexDigit }) else {
                    DispatchQueue.main.async { self.diffResult = nil }
                    return
                }
                rawDiff = TerminalTab.shellSync("git -C \"\(root)\" diff \(hash)^..\(hash) -- \"\(safePath)\" 2>/dev/null") ?? ""
            } else if staged {
                rawDiff = TerminalTab.shellSync("git -C \"\(root)\" diff --cached -- \"\(safePath)\" 2>/dev/null") ?? ""
            } else {
                let statusRaw = TerminalTab.shellSync("git -C \"\(root)\" status --porcelain -- \"\(safePath)\" 2>/dev/null") ?? ""
                if statusRaw.hasPrefix("??") {
                    let fullPath = root.hasSuffix("/") ? "\(root)\(safePath)" : "\(root)/\(safePath)"
                    let content = TerminalTab.shellSync("cat \"\(fullPath)\" 2>/dev/null") ?? ""
                    let lines = content.components(separatedBy: "\n")
                    let diffLines = lines.enumerated().map { idx, line in
                        DiffLine(type: .addition, content: line, oldLineNum: nil, newLineNum: idx + 1)
                    }
                    let hunk = DiffHunk(header: "@@ -0,0 +1,\(lines.count) @@", lines: diffLines)
                    let result = GitDiffResult(
                        filePath: filePath,
                        hunks: [hunk],
                        isBinary: false,
                        stats: (additions: lines.count, deletions: 0)
                    )
                    DispatchQueue.main.async { self.diffResult = result }
                    return
                }
                rawDiff = TerminalTab.shellSync("git -C \"\(root)\" diff -- \"\(safePath)\" 2>/dev/null") ?? ""
            }

            let result = GitDataParser.parseDiff(filePath: filePath, rawDiff: rawDiff)
            DispatchQueue.main.async { self.diffResult = result }
        }
    }

    // MARK: - Staging Operations

    public func stageFile(path filePath: String) {
        let safePath = GitDataParser.sanitizePath(filePath)
        let path = projectPath
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = TerminalTab.shellSync("git -C \"\(path)\" add -- \"\(safePath)\" 2>&1")
            DispatchQueue.main.async {
                if let result = result, result.contains("fatal") {
                    self?.lastError = result
                }
                self?.refreshAll()
            }
        }
    }

    public func unstageFile(path filePath: String) {
        let safePath = GitDataParser.sanitizePath(filePath)
        let path = projectPath
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = TerminalTab.shellSync("git -C \"\(path)\" restore --staged -- \"\(safePath)\" 2>&1")
            DispatchQueue.main.async {
                if let result = result, result.contains("fatal") {
                    self?.lastError = result
                }
                self?.refreshAll()
            }
        }
    }

    public func stageAll() {
        let path = projectPath
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = TerminalTab.shellSync("git -C \"\(path)\" add -A 2>&1")
            DispatchQueue.main.async {
                if let result = result, result.contains("fatal") {
                    self?.lastError = result
                }
                self?.refreshAll()
            }
        }
    }

    public func unstageAll() {
        let path = projectPath
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = TerminalTab.shellSync("git -C \"\(path)\" reset HEAD 2>&1")
            DispatchQueue.main.async {
                if let result = result, result.contains("fatal") {
                    self?.lastError = result
                }
                self?.refreshAll()
            }
        }
    }

    public func discardFile(path filePath: String) {
        let safePath = GitDataParser.sanitizePath(filePath)
        let path = projectPath
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = TerminalTab.shellSync("git -C \"\(path)\" checkout -- \"\(safePath)\" 2>&1")
            DispatchQueue.main.async {
                if let result = result, result.contains("fatal") {
                    self?.lastError = result
                }
                self?.refreshAll()
            }
        }
    }

    // MARK: - Direct Git Operations

    public func commitDirectly(message: String, completion: ((Bool) -> Void)? = nil) {
        guard !message.isEmpty else {
            lastError = "Commit message cannot be empty"
            completion?(false)
            return
        }
        let path = projectPath
        // Escape double quotes in commit message to prevent injection
        let safeMessage = message.replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "$", with: "\\$")
            .replacingOccurrences(of: "`", with: "\\`")
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = TerminalTab.shellSync("git -C \"\(path)\" commit -m \"\(safeMessage)\" 2>&1") ?? ""
            let failed = result.contains("fatal") || result.contains("error")
            DispatchQueue.main.async {
                if failed { self?.lastError = result }
                self?.refreshAll()
                completion?(!failed)
            }
        }
    }

    public func commitSelectedFiles(message: String, selectedPaths: [String], completion: ((Bool) -> Void)? = nil) {
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty else {
            lastError = "Commit message cannot be empty"
            completion?(false)
            return
        }

        let stagedPaths = Set(workingDirStaged.map(\.path))
        let unstagedOnlyPaths = Set(workingDirUnstaged.map(\.path)).subtracting(stagedPaths)
        let eligiblePaths = stagedPaths.union(unstagedOnlyPaths)
        let effectiveSelection = Set(selectedPaths).intersection(eligiblePaths)

        guard !effectiveSelection.isEmpty else {
            lastError = "No files selected to commit"
            completion?(false)
            return
        }

        let pathsToStage = Array(effectiveSelection.intersection(unstagedOnlyPaths)).sorted()
        let pathsToRestore = Array(stagedPaths.subtracting(effectiveSelection)).sorted()
        let path = projectPath
        let safeMessage = trimmedMessage
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "$", with: "\\$")
            .replacingOccurrences(of: "`", with: "\\`")

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            func quotedPaths(_ paths: [String]) -> String {
                paths.map { "\"\(GitDataParser.sanitizePath($0))\"" }.joined(separator: " ")
            }

            func run(_ command: String) -> String {
                TerminalTab.shellSync(command) ?? ""
            }

            func failed(_ output: String) -> Bool {
                output.contains("fatal") || output.contains("error")
            }

            var commandError: String?
            var restoreWarning: String?
            var commitSucceeded = false

            if !pathsToStage.isEmpty {
                let output = run("git -C \"\(path)\" add -- \(quotedPaths(pathsToStage)) 2>&1")
                if failed(output) { commandError = output }
            }

            if commandError == nil, !pathsToRestore.isEmpty {
                let output = run("git -C \"\(path)\" restore --staged -- \(quotedPaths(pathsToRestore)) 2>&1")
                if failed(output) { commandError = output }
            }

            if commandError == nil {
                let output = run("git -C \"\(path)\" commit -m \"\(safeMessage)\" 2>&1")
                commitSucceeded = !failed(output)
                if !commitSucceeded { commandError = output }
            }

            if !pathsToRestore.isEmpty {
                let output = run("git -C \"\(path)\" add -- \(quotedPaths(pathsToRestore)) 2>&1")
                if failed(output) { restoreWarning = output }
            }

            if !commitSucceeded, !pathsToStage.isEmpty {
                let output = run("git -C \"\(path)\" restore --staged -- \(quotedPaths(pathsToStage)) 2>&1")
                if commandError == nil, failed(output) { commandError = output }
            }

            DispatchQueue.main.async {
                if let commandError {
                    self?.lastError = commandError
                } else if let restoreWarning {
                    self?.lastError = "Commit succeeded, but some staged selections could not be restored.\n\(restoreWarning)"
                }
                self?.refreshAll()
                completion?(commitSucceeded)
            }
        }
    }

    public func createBranch(name: String, completion: ((Bool) -> Void)? = nil) {
        guard GitDataParser.isValidBranchName(name) else {
            lastError = "Invalid branch name: \(name)"
            completion?(false)
            return
        }
        let path = projectPath
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = TerminalTab.shellSync("git -C \"\(path)\" checkout -b \"\(name)\" 2>&1") ?? ""
            let failed = result.contains("fatal") || result.contains("error")
            DispatchQueue.main.async {
                if failed { self?.lastError = result }
                self?.refreshAll()
                completion?(!failed)
            }
        }
    }

    public func deleteBranch(name: String, force: Bool = false, completion: ((Bool) -> Void)? = nil) {
        guard GitDataParser.isValidBranchName(name) else {
            lastError = "Invalid branch name: \(name)"
            completion?(false)
            return
        }
        let path = projectPath
        let flag = force ? "-D" : "-d"
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = TerminalTab.shellSync("git -C \"\(path)\" branch \(flag) \"\(name)\" 2>&1") ?? ""
            let failed = result.contains("fatal") || result.contains("error")
            DispatchQueue.main.async {
                if failed { self?.lastError = result }
                self?.refreshAll()
                completion?(!failed)
            }
        }
    }

    public func createTag(name: String, message: String? = nil, completion: ((Bool) -> Void)? = nil) {
        guard GitDataParser.isValidRefName(name) else {
            lastError = "Invalid tag name: \(name)"
            completion?(false)
            return
        }
        let path = projectPath
        let tagMessage = message
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result: String?
            if let message = tagMessage, !message.isEmpty {
                let safeMsg = message.replacingOccurrences(of: "\"", with: "\\\"")
                    .replacingOccurrences(of: "$", with: "\\$")
                    .replacingOccurrences(of: "`", with: "\\`")
                result = TerminalTab.shellSync("git -C \"\(path)\" tag -a \"\(name)\" -m \"\(safeMsg)\" 2>&1")
            } else {
                result = TerminalTab.shellSync("git -C \"\(path)\" tag \"\(name)\" 2>&1")
            }
            let failed = result.map { $0.contains("fatal") || $0.contains("error") } ?? false
            DispatchQueue.main.async {
                if failed { self?.lastError = result ?? "" }
                self?.refreshAll()
                completion?(!failed)
            }
        }
    }

    public func deleteTag(name: String, completion: ((Bool) -> Void)? = nil) {
        guard GitDataParser.isValidRefName(name) else {
            lastError = "Invalid tag name: \(name)"
            completion?(false)
            return
        }
        let path = projectPath
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = TerminalTab.shellSync("git -C \"\(path)\" tag -d \"\(name)\" 2>&1") ?? ""
            let failed = result.contains("fatal") || result.contains("error")
            DispatchQueue.main.async {
                if failed { self?.lastError = result }
                self?.refreshAll()
                completion?(!failed)
            }
        }
    }

    public func stashSave(message: String? = nil, completion: ((Bool) -> Void)? = nil) {
        let path = projectPath
        let stashMessage = message
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result: String?
            if let message = stashMessage, !message.isEmpty {
                let safeMsg = message.replacingOccurrences(of: "\"", with: "\\\"")
                    .replacingOccurrences(of: "$", with: "\\$")
                    .replacingOccurrences(of: "`", with: "\\`")
                result = TerminalTab.shellSync("git -C \"\(path)\" stash push -m \"\(safeMsg)\" 2>&1")
            } else {
                result = TerminalTab.shellSync("git -C \"\(path)\" stash push 2>&1")
            }
            let failed = result?.contains("fatal") ?? false
            DispatchQueue.main.async {
                if failed { self?.lastError = result ?? "" }
                self?.refreshAll()
                completion?(!failed)
            }
        }
    }

    public func stashApply(index: Int, completion: ((Bool) -> Void)? = nil) {
        guard index >= 0 else {
            lastError = "Invalid stash index"
            completion?(false)
            return
        }
        let path = projectPath
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = TerminalTab.shellSync("git -C \"\(path)\" stash apply stash@{\(index)} 2>&1") ?? ""
            let failed = result.contains("fatal") || result.contains("error")
            DispatchQueue.main.async {
                if failed { self?.lastError = result }
                self?.refreshAll()
                completion?(!failed)
            }
        }
    }

    public func stashDrop(index: Int, completion: ((Bool) -> Void)? = nil) {
        guard index >= 0 else {
            lastError = "Invalid stash index"
            completion?(false)
            return
        }
        let path = projectPath
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = TerminalTab.shellSync("git -C \"\(path)\" stash drop stash@{\(index)} 2>&1") ?? ""
            let failed = result.contains("fatal") || result.contains("error")
            DispatchQueue.main.async {
                if failed { self?.lastError = result }
                self?.refreshAll()
                completion?(!failed)
            }
        }
    }

    // MARK: - Cherry-pick

    public func cherryPick(hash: String, completion: ((Bool) -> Void)? = nil) {
        guard hash.allSatisfy({ $0.isHexDigit }) else {
            lastError = "Invalid commit hash"
            completion?(false)
            return
        }
        let path = projectPath
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = TerminalTab.shellSync("git -C \"\(path)\" cherry-pick \(hash) 2>&1") ?? ""
            let failed = result.contains("fatal") || result.contains("error") || result.contains("conflict")
            DispatchQueue.main.async {
                if failed { self?.lastError = result }
                self?.refreshAll()
                completion?(!failed)
            }
        }
    }

    // MARK: - Revert Commit

    public func revertCommit(hash: String, completion: ((Bool) -> Void)? = nil) {
        guard hash.allSatisfy({ $0.isHexDigit }) else {
            lastError = "Invalid commit hash"
            completion?(false)
            return
        }
        let path = projectPath
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = TerminalTab.shellSync("git -C \"\(path)\" revert --no-edit \(hash) 2>&1") ?? ""
            let failed = result.contains("fatal") || result.contains("error") || result.contains("conflict")
            DispatchQueue.main.async {
                if failed { self?.lastError = result }
                self?.refreshAll()
                completion?(!failed)
            }
        }
    }

    // MARK: - Amend Commit

    public func amendCommit(message: String? = nil, completion: ((Bool) -> Void)? = nil) {
        let path = projectPath
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result: String
            if let message = message, !message.isEmpty {
                let safeMsg = message.replacingOccurrences(of: "\"", with: "\\\"")
                    .replacingOccurrences(of: "$", with: "\\$")
                    .replacingOccurrences(of: "`", with: "\\`")
                result = TerminalTab.shellSync("git -C \"\(path)\" commit --amend -m \"\(safeMsg)\" 2>&1") ?? ""
            } else {
                result = TerminalTab.shellSync("git -C \"\(path)\" commit --amend --no-edit 2>&1") ?? ""
            }
            let failed = result.contains("fatal") || result.contains("error")
            DispatchQueue.main.async {
                if failed { self?.lastError = result }
                self?.refreshAll()
                completion?(!failed)
            }
        }
    }

    // MARK: - Blame

    @Published public var blameLines: [BlameLine] = []
    @Published public var blameFilePath: String = ""

    public func fetchBlame(filePath: String) {
        let safePath = GitDataParser.sanitizePath(filePath)
        let path = projectPath
        blameFilePath = filePath
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let raw = TerminalTab.shellSync("git -C \"\(path)\" blame --porcelain -- \"\(safePath)\" 2>/dev/null") ?? ""
            let lines = GitDataParser.parseBlame(raw)
            DispatchQueue.main.async {
                self?.blameLines = lines
            }
        }
    }

    // MARK: - File History

    @Published public var fileHistory: [GitCommitNode] = []
    @Published public var fileHistoryPath: String = ""

    public func fetchFileHistory(filePath: String) {
        let safePath = GitDataParser.sanitizePath(filePath)
        let path = projectPath
        fileHistoryPath = filePath
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let fieldSep = "<<F>>"
            let format = "%x00%H\(fieldSep)%h\(fieldSep)%s\(fieldSep)%an\(fieldSep)%ae\(fieldSep)%aI\(fieldSep)%P\(fieldSep)%D\(fieldSep)%b"
            let raw = TerminalTab.shellSync("git -C \"\(path)\" log --follow --format='\(format)' -n 50 -- \"\(safePath)\" 2>/dev/null") ?? ""
            let commits = GitDataParser.parseCommitRecords(raw)
            DispatchQueue.main.async {
                self?.fileHistory = commits
            }
        }
    }

    // MARK: - Reset to Commit

    public func resetToCommit(hash: String, mode: String = "mixed", completion: ((Bool) -> Void)? = nil) {
        guard hash.allSatisfy({ $0.isHexDigit }) else {
            lastError = "Invalid commit hash"
            completion?(false)
            return
        }
        guard ["soft", "mixed", "hard"].contains(mode) else {
            lastError = "Invalid reset mode"
            completion?(false)
            return
        }
        let path = projectPath
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = TerminalTab.shellSync("git -C \"\(path)\" reset --\(mode) \(hash) 2>&1") ?? ""
            let failed = result.contains("fatal") || result.contains("error")
            DispatchQueue.main.async {
                if failed { self?.lastError = result }
                self?.refreshAll()
                completion?(!failed)
            }
        }
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - Git Data Parser (nonisolated, runs on background)
// ═══════════════════════════════════════════════════════

public enum GitDataParser {

    private static let gitDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    // MARK: - Input Validation

    /// Sanitize a file path to prevent command injection.
    /// Removes null bytes, backticks, dollar signs, and other shell metacharacters.
    public static func sanitizePath(_ path: String) -> String {
        var safe = path
        // Remove characters that could be used for injection
        let forbidden: [Character] = ["\0", "`", "$", ";", "&", "|", "\n", "\r"]
        safe.removeAll { forbidden.contains($0) }
        // Remove leading dashes that could be interpreted as flags
        while safe.hasPrefix("-") {
            safe = String(safe.dropFirst())
        }
        return safe
    }

    /// Validate a branch name against git's rules.
    public static func isValidBranchName(_ name: String) -> Bool {
        guard !name.isEmpty else { return false }
        // Must not contain shell metacharacters
        let forbidden: [Character] = [" ", "~", "^", ":", "\\", "\0", "\t", "\n", "`", "$", ";", "&", "|"]
        for ch in forbidden {
            if name.contains(ch) { return false }
        }
        if name.contains("..") || name.contains("@{") { return false }
        if name.hasPrefix("-") || name.hasPrefix(".") { return false }
        if name.hasSuffix(".") || name.hasSuffix(".lock") || name.hasSuffix("/") { return false }
        return true
    }

    /// Validate a ref name (tags, etc.)
    public static func isValidRefName(_ name: String) -> Bool {
        return isValidBranchName(name)
    }

    // MARK: - Commits

    public static func parseCommits(path: String, limit: Int = 150) -> [GitCommitNode] {
        // Use %x00 (NUL) as record separator between commits to handle multi-line bodies
        let fieldSep = "<<F>>"
        // Format: hash, shortHash, subject, author, email, date, parents, refs
        // Body is fetched separately per-record to avoid multi-line breakage
        let format = "%x00%H\(fieldSep)%h\(fieldSep)%s\(fieldSep)%an\(fieldSep)%ae\(fieldSep)%aI\(fieldSep)%P\(fieldSep)%D\(fieldSep)%b"
        let raw = TerminalTab.shellSync("git -C \"\(path)\" log --all --topo-order --format='\(format)' -n \(limit) 2>/dev/null") ?? ""

        var commits: [GitCommitNode] = []
        // Split by NUL character to separate commits (handles multi-line bodies)
        let records = raw.components(separatedBy: "\0").filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        for record in records {
            let trimmed = record.trimmingCharacters(in: .whitespacesAndNewlines)
            // Find the first field separator to split fields
            let parts = trimmed.components(separatedBy: fieldSep)
            guard parts.count >= 8 else { continue }

            let hash = parts[0].trimmingCharacters(in: .init(charactersIn: "'"))
            let shortHash = parts[1]
            let subject = parts[2]
            let author = parts[3]
            let email = parts[4]
            let dateStr = parts[5]
            let parents = parts[6].split(separator: " ").map(String.init)
            // Everything from parts[7] onward is refs + body (body may contain fieldSep theoretically)
            let refStr = parts[7].trimmingCharacters(in: .init(charactersIn: "'"))
            let body = parts.count > 8 ? parts[8...].joined(separator: fieldSep).trimmingCharacters(in: .whitespacesAndNewlines) : ""

            let date = gitDateFormatter.date(from: dateStr) ?? Date()
            let refs = parseRefs(refStr)
            let coAuthors = parseCoAuthors(body)

            commits.append(GitCommitNode(
                id: hash, shortHash: shortHash, message: subject, body: body,
                author: author, authorEmail: email, date: date,
                parentHashes: parents, coAuthors: coAuthors, refs: refs
            ))
        }

        return assignLanes(commits)
    }

    private static func parseRefs(_ str: String) -> [GitCommitNode.GitRef] {
        guard !str.isEmpty else { return [] }
        return str.components(separatedBy: ", ").compactMap { r in
            let trimmed = r.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("HEAD -> ") {
                return .init(name: String(trimmed.dropFirst(8)), type: .head)
            } else if trimmed.hasPrefix("tag: ") {
                return .init(name: String(trimmed.dropFirst(5)), type: .tag)
            } else if trimmed.contains("/") {
                return .init(name: trimmed, type: .remoteBranch)
            } else if !trimmed.isEmpty && trimmed != "HEAD" {
                return .init(name: trimmed, type: .branch)
            }
            return nil
        }
    }

    private static func parseCoAuthors(_ body: String) -> [String] {
        body.components(separatedBy: "\n")
            .filter { $0.lowercased().contains("co-authored-by:") }
            .compactMap { line in
                let parts = line.components(separatedBy: ":")
                guard parts.count >= 2 else { return nil }
                return parts.dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespaces)
            }
    }

    // MARK: - Lane Assignment

    private static func assignLanes(_ commits: [GitCommitNode]) -> [GitCommitNode] {
        var result = commits
        var activeLanes: [String?] = [] // SHA expected in each lane
        // O(1) lookup: SHA → lane index (avoids O(n) firstIndex(of:) per commit)
        var shaToLane: [String: Int] = [:]
        // O(1) lookup: set of empty lane indices
        var emptyLanes: [Int] = []

        for i in 0..<result.count {
            let commit = result[i]

            // Find lane where this commit was expected — O(1) via dictionary
            var myLane = shaToLane[commit.id]

            if myLane == nil {
                if let emptyIdx = emptyLanes.popLast() {
                    myLane = emptyIdx
                } else {
                    myLane = activeLanes.count
                    activeLanes.append(nil)
                }
            } else {
                shaToLane.removeValue(forKey: commit.id)
            }

            guard let lane = myLane else { continue }
            result[i].lane = lane

            // Record which lanes are active at this position (for graph drawing)
            var activeSet = Set<Int>()
            activeSet.reserveCapacity(activeLanes.count)
            for (idx, sha) in activeLanes.enumerated() {
                if sha != nil { activeSet.insert(idx) }
            }
            activeSet.insert(lane)
            result[i].activeLanes = activeSet

            // Update lanes: replace current lane with first parent, add others
            if commit.parentHashes.isEmpty {
                activeLanes[lane] = nil
                emptyLanes.append(lane)
            } else {
                let firstParent = commit.parentHashes[0]
                // Remove old mapping if exists
                if let oldSha = activeLanes[lane] { shaToLane.removeValue(forKey: oldSha) }
                activeLanes[lane] = firstParent
                shaToLane[firstParent] = lane

                for pIdx in commit.parentHashes.indices.dropFirst() {
                    let parentHash = commit.parentHashes[pIdx]
                    if shaToLane[parentHash] == nil { // O(1) check
                        if let emptyIdx = emptyLanes.popLast() {
                            activeLanes[emptyIdx] = parentHash
                            shaToLane[parentHash] = emptyIdx
                        } else {
                            shaToLane[parentHash] = activeLanes.count
                            activeLanes.append(parentHash)
                        }
                    }
                }
            }

            // Collapse trailing nils
            while activeLanes.last == nil && activeLanes.count > 1 {
                let removedIdx = activeLanes.count - 1
                activeLanes.removeLast()
                emptyLanes.removeAll { $0 == removedIdx }
            }
        }

        return result
    }

    // MARK: - Working Directory

    public static func parseWorkingDir(path: String) -> (staged: [GitFileChange], unstaged: [GitFileChange]) {
        let raw = TerminalTab.shellSync("git -C \"\(path)\" status --porcelain 2>/dev/null") ?? ""
        var staged: [GitFileChange] = []
        var unstaged: [GitFileChange] = []

        for line in raw.components(separatedBy: "\n") where line.count >= 3 {
            let chars = Array(line)
            let indexStatus = chars[0]
            let workStatus = chars[1]
            let filePath = String(line.dropFirst(3))
            let fileName = (filePath as NSString).lastPathComponent

            if indexStatus != " " && indexStatus != "?" {
                let s = GitFileChange.ChangeStatus(rawValue: String(indexStatus)) ?? .modified
                staged.append(GitFileChange(path: filePath, fileName: fileName, status: s, isStaged: true))
            }
            if workStatus != " " || indexStatus == "?" {
                let s: GitFileChange.ChangeStatus = indexStatus == "?" ? .untracked : (GitFileChange.ChangeStatus(rawValue: String(workStatus)) ?? .modified)
                unstaged.append(GitFileChange(path: filePath, fileName: fileName, status: s, isStaged: false))
            }
        }
        return (staged, unstaged)
    }

    // MARK: - Branches

    public static func parseBranches(path: String) -> [GitBranchInfo] {
        let raw = TerminalTab.shellSync("git -C \"\(path)\" branch -a --format='%(refname:short)|%(upstream:short)|%(upstream:track)' 2>/dev/null") ?? ""
        let current = TerminalTab.shellSync("git -C \"\(path)\" branch --show-current 2>/dev/null")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        return raw.components(separatedBy: "\n").compactMap { line in
            let trimmed = line.trimmingCharacters(in: .init(charactersIn: "'"))
            let parts = trimmed.components(separatedBy: "|")
            guard !parts[0].isEmpty else { return nil }
            let name = parts[0]
            let upstream = parts.count > 1 && !parts[1].isEmpty ? parts[1] : nil
            let isRemote = name.hasPrefix("origin/") || name.contains("/")

            var ahead = 0, behind = 0
            if parts.count > 2 {
                let track = parts[2]
                if let r = track.range(of: "ahead (\\d+)", options: .regularExpression) {
                    ahead = Int(track[r].components(separatedBy: " ").last ?? "") ?? 0
                }
                if let r = track.range(of: "behind (\\d+)", options: .regularExpression) {
                    behind = Int(track[r].components(separatedBy: " ").last ?? "") ?? 0
                }
            }

            return GitBranchInfo(name: name, isRemote: isRemote, isCurrent: name == current, upstream: upstream, ahead: ahead, behind: behind)
        }
    }

    // MARK: - Stashes

    public static func parseStashes(path: String) -> [GitStashEntry] {
        let raw = TerminalTab.shellSync("git -C \"\(path)\" stash list --format='%gd|%gs' 2>/dev/null") ?? ""
        return raw.components(separatedBy: "\n").enumerated().compactMap { idx, line in
            let trimmed = line.trimmingCharacters(in: .init(charactersIn: "'"))
            guard !trimmed.isEmpty else { return nil }
            let parts = trimmed.components(separatedBy: "|")
            return GitStashEntry(id: idx, message: parts.count > 1 ? parts[1] : trimmed)
        }
    }

    // MARK: - Conflict Detection

    public static func parseConflicts(path: String) -> [GitFileChange] {
        let raw = TerminalTab.shellSync("git -C \"\(path)\" diff --name-only --diff-filter=U 2>/dev/null") ?? ""
        return raw.components(separatedBy: "\n").compactMap { line -> GitFileChange? in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            let fileName = (trimmed as NSString).lastPathComponent
            return GitFileChange(path: trimmed, fileName: fileName, status: .conflict, isStaged: false)
        }
    }

    // MARK: - Diff Parsing

    /// Parse raw git diff output into a structured GitDiffResult.
    public static func parseDiff(filePath: String, rawDiff: String) -> GitDiffResult {
        // Check for binary
        if rawDiff.contains("Binary files") {
            return GitDiffResult(filePath: filePath, hunks: [], isBinary: true, stats: (0, 0))
        }

        var hunks: [DiffHunk] = []
        var totalAdditions = 0
        var totalDeletions = 0

        let lines = rawDiff.components(separatedBy: "\n")
        var currentHunkHeader: String?
        var currentHunkLines: [DiffLine] = []
        var oldLineNum = 0
        var newLineNum = 0

        for line in lines {
            if line.hasPrefix("@@") {
                // Save previous hunk
                if let header = currentHunkHeader {
                    hunks.append(DiffHunk(header: header, lines: currentHunkLines))
                }
                currentHunkHeader = line
                currentHunkLines = []

                // Parse line numbers from header: @@ -oldStart,oldCount +newStart,newCount @@
                let parts = line.components(separatedBy: " ")
                if parts.count >= 3 {
                    let oldPart = parts[1] // e.g., "-1,3"
                    let newPart = parts[2] // e.g., "+1,4"
                    let oldStart = oldPart.dropFirst().components(separatedBy: ",").first.flatMap { Int($0) } ?? 1
                    let newStart = newPart.dropFirst().components(separatedBy: ",").first.flatMap { Int($0) } ?? 1
                    oldLineNum = oldStart
                    newLineNum = newStart
                }
            } else if currentHunkHeader != nil {
                if line.hasPrefix("+") && !line.hasPrefix("+++") {
                    currentHunkLines.append(DiffLine(
                        type: .addition,
                        content: String(line.dropFirst()),
                        oldLineNum: nil,
                        newLineNum: newLineNum
                    ))
                    newLineNum += 1
                    totalAdditions += 1
                } else if line.hasPrefix("-") && !line.hasPrefix("---") {
                    currentHunkLines.append(DiffLine(
                        type: .deletion,
                        content: String(line.dropFirst()),
                        oldLineNum: oldLineNum,
                        newLineNum: nil
                    ))
                    oldLineNum += 1
                    totalDeletions += 1
                } else if line.hasPrefix(" ") {
                    currentHunkLines.append(DiffLine(
                        type: .context,
                        content: String(line.dropFirst()),
                        oldLineNum: oldLineNum,
                        newLineNum: newLineNum
                    ))
                    oldLineNum += 1
                    newLineNum += 1
                } else if line == "\\ No newline at end of file" {
                    // Skip this meta-line
                } else if !line.hasPrefix("diff") && !line.hasPrefix("index") && !line.hasPrefix("---") && !line.hasPrefix("+++") && !line.isEmpty {
                    // Context line without leading space (some edge cases)
                    currentHunkLines.append(DiffLine(
                        type: .context,
                        content: line,
                        oldLineNum: oldLineNum,
                        newLineNum: newLineNum
                    ))
                    oldLineNum += 1
                    newLineNum += 1
                }
            }
        }

        // Save last hunk
        if let header = currentHunkHeader {
            hunks.append(DiffHunk(header: header, lines: currentHunkLines))
        }

        return GitDiffResult(
            filePath: filePath,
            hunks: hunks,
            isBinary: false,
            stats: (additions: totalAdditions, deletions: totalDeletions)
        )
    }

    // MARK: - Blame Parsing

    public static func parseBlame(_ raw: String) -> [BlameLine] {
        guard !raw.isEmpty else { return [] }
        var lines: [BlameLine] = []
        var currentHash = ""
        var currentAuthor = ""
        var currentDate = Date()
        var lineNum = 0

        let dateFormatter: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
            f.locale = Locale(identifier: "en_US_POSIX")
            return f
        }()

        for line in raw.components(separatedBy: "\n") {
            if line.isEmpty { continue }

            // Header line: <hash> <orig-line> <final-line> [<num-lines>]
            let headerParts = line.split(separator: " ")
            if headerParts.count >= 3,
               headerParts[0].count == 40,
               headerParts[0].allSatisfy({ $0.isHexDigit }) {
                currentHash = String(headerParts[0])
                lineNum = Int(headerParts[2]) ?? (lineNum + 1)
            } else if line.hasPrefix("author ") {
                currentAuthor = String(line.dropFirst(7))
            } else if line.hasPrefix("author-time ") {
                if let ts = TimeInterval(line.dropFirst(12)) {
                    currentDate = Date(timeIntervalSince1970: ts)
                }
            } else if line.hasPrefix("\t") {
                // Content line
                let content = String(line.dropFirst())
                lines.append(BlameLine(
                    id: lineNum,
                    hash: currentHash,
                    shortHash: String(currentHash.prefix(7)),
                    author: currentAuthor,
                    date: currentDate,
                    content: content
                ))
            }
        }
        return lines
    }

    // MARK: - Commit Records Parsing (shared)

    public static func parseCommitRecords(_ raw: String) -> [GitCommitNode] {
        let fieldSep = "<<F>>"
        var commits: [GitCommitNode] = []
        let records = raw.components(separatedBy: "\0").filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        for record in records {
            let trimmed = record.trimmingCharacters(in: .whitespacesAndNewlines)
            let parts = trimmed.components(separatedBy: fieldSep)
            guard parts.count >= 8 else { continue }

            let hash = parts[0].trimmingCharacters(in: .init(charactersIn: "'"))
            let shortHash = parts[1]
            let subject = parts[2]
            let author = parts[3]
            let email = parts[4]
            let dateStr = parts[5]
            let parents = parts[6].split(separator: " ").map(String.init)
            let refStr = parts[7].trimmingCharacters(in: .init(charactersIn: "'"))
            let body = parts.count > 8 ? parts[8...].joined(separator: fieldSep).trimmingCharacters(in: .whitespacesAndNewlines) : ""

            let date = gitDateFormatter.date(from: dateStr) ?? Date()
            let refs = parseRefs(refStr)
            let coAuthors = parseCoAuthors(body)

            commits.append(GitCommitNode(
                id: hash, shortHash: shortHash, message: subject, body: body,
                author: author, authorEmail: email, date: date,
                parentHashes: parents, coAuthors: coAuthors, refs: refs
            ))
        }
        return commits
    }
}
