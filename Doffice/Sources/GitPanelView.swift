import SwiftUI

// ═══════════════════════════════════════════════════════
// MARK: - Git Panel View (Full Git Client)
// ═══════════════════════════════════════════════════════

struct GitPanelView: View {
    @EnvironmentObject var manager: SessionManager
    @StateObject private var git = GitDataProvider()

    // Selection & navigation
    @State private var selectedCommitId: String?
    @State private var hoveredCommitId: String?
    @State private var selectedFileForDiff: GitFileChange?
    @State private var selectedKeyboardIndex: Int = 0

    // Action sheet (Claude-based operations)
    @State private var showActionSheet = false
    @State private var actionType: GitAction = .commit
    @State private var actionInput: String = ""

    // Right panel tabs
    @State private var rightTab: RightPanelTab = .changes

    // Left sidebar section collapse state
    @State private var sidebarBranchesExpanded = true
    @State private var sidebarTagsExpanded = false
    @State private var sidebarStashesExpanded = false
    @State private var sidebarRemotesExpanded = false

    // Inline commit
    @State private var commitMessage: String = ""

    // File selection for selective commit
    @State private var selectedFilesForCommit: Set<String> = []

    // Confirmation alerts
    @State private var showDiscardAlert = false
    @State private var fileToDiscard: GitFileChange?
    @State private var showDeleteBranchAlert = false
    @State private var branchToDelete: String?
    @State private var showForcePushWarning = false

    // Conflict resolution
    @State private var showConflictList = false

    // Search
    @State private var searchText: String = ""

    // Diff view mode
    @State private var showDiffViewer = false

    // Toast notification
    @State private var toastMessage: String?
    @State private var toastIcon: String = "checkmark.circle.fill"
    @State private var toastColor: Color = .green
    @State private var toastVisible = false
    private var toastDismissWork: DispatchWorkItem? = nil

    enum GitAction: String, CaseIterable {
        case commit = "커밋", push = "푸시", pull = "풀"
        case branch = "브랜치", stash = "스태시"
        case merge = "병합", checkout = "체크아웃"

        var displayName: String {
            switch self {
            case .commit: return NSLocalizedString("git.commit", comment: "")
            case .push: return NSLocalizedString("git.push", comment: "")
            case .pull: return NSLocalizedString("git.pull", comment: "")
            case .branch: return NSLocalizedString("git.branch", comment: "")
            case .stash: return NSLocalizedString("git.stash", comment: "")
            case .merge: return NSLocalizedString("git.merge", comment: "")
            case .checkout: return rawValue
            }
        }
    }
    enum RightPanelTab: String { case changes, info }

    private var activeTab: TerminalTab? { manager.activeTab }
    private var projectPath: String { activeTab?.projectPath ?? "" }

    // Derived data
    private var allTags: [GitCommitNode.GitRef] {
        git.commits.flatMap { c in c.refs.filter { $0.type == .tag } }
    }
    private var localBranches: [GitBranchInfo] { git.branches.filter { !$0.isRemote } }
    private var remoteBranches: [GitBranchInfo] { git.branches.filter { $0.isRemote } }
    private var remoteNames: [String] {
        Array(Set(remoteBranches.compactMap { br -> String? in
            let parts = br.name.split(separator: "/", maxSplits: 1)
            return parts.count >= 1 ? String(parts[0]) : nil
        })).sorted()
    }

    private var displayedCommits: [GitCommitNode] {
        let base = git.commits
        guard !searchText.isEmpty else { return base }
        let q = searchText.lowercased()
        return base.filter {
            $0.message.lowercased().contains(q) ||
            $0.author.lowercased().contains(q) ||
            $0.shortHash.lowercased().contains(q)
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            gitToolbar
            Rectangle().fill(Theme.border).frame(height: 1)

            // Conflict banner
            if !git.conflictFiles.isEmpty {
                conflictBanner
                Rectangle().fill(Theme.border).frame(height: 1)
            }

            if projectPath.isEmpty {
                emptyState("탭을 선택하세요", icon: "arrow.triangle.branch")
            } else if git.lastError == "Git이 설치되지 않았습니다" {
                emptyState("Git이 설치되지 않았습니다.\n터미널에서 Xcode Command Line Tools를 설치하세요:\nxcode-select --install", icon: "exclamationmark.triangle")
            } else {
                GeometryReader { geo in
                    HStack(spacing: 0) {
                        // Left sidebar
                        leftSidebar
                            .frame(width: 200)
                        Rectangle().fill(Theme.border).frame(width: 1)

                        // Center: commit graph
                        centerPanel
                            .frame(minWidth: 360)
                        Rectangle().fill(Theme.border).frame(width: 1)

                        // Right detail panel
                        rightPanel
                            .frame(minWidth: 280)
                    }
                }

                // Bottom action bar
                Rectangle().fill(Theme.border).frame(height: 1)
                bottomActionBar
            }
        }
        .background(Theme.bg)
        .overlay(alignment: .top) {
            if toastVisible, let msg = toastMessage {
                GitToastView(message: msg, icon: toastIcon, color: toastColor) {
                    withAnimation(.easeOut(duration: 0.2)) { toastVisible = false }
                }
                .padding(.top, 50)
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .scale(scale: 0.95).combined(with: .opacity)
                ))
                .zIndex(100)
            }
        }
        .onAppear { git.start(projectPath: projectPath) }
        .onDisappear { git.stop() }
        .onChange(of: manager.activeTabId) { _, _ in
            git.stop(); selectedCommitId = nil; selectedFileForDiff = nil; showDiffViewer = false
            if !projectPath.isEmpty { git.start(projectPath: projectPath) }
        }
        .sheet(isPresented: $showActionSheet) { actionSheet }
        .alert(NSLocalizedString("git.discard", comment: ""), isPresented: $showDiscardAlert) {
            Button(NSLocalizedString("cancel", comment: ""), role: .cancel) { fileToDiscard = nil }
            Button(NSLocalizedString("delete", comment: ""), role: .destructive) {
                if let f = fileToDiscard {
                    git.discardFile(path: f.path)
                    showToast("변경사항 삭제됨: \(f.fileName)", icon: "trash.fill", color: Theme.red)
                    fileToDiscard = nil
                }
            }
        } message: {
            Text("'\(fileToDiscard?.fileName ?? "")'의 변경사항을 되돌립니다. 이 작업은 취소할 수 없습니다.")
        }
        .alert(NSLocalizedString("git.branch.delete", comment: ""), isPresented: $showDeleteBranchAlert) {
            Button(NSLocalizedString("cancel", comment: ""), role: .cancel) { branchToDelete = nil }
            Button(NSLocalizedString("delete", comment: ""), role: .destructive) {
                if let b = branchToDelete {
                    git.deleteBranch(name: b) { success in
                        if success {
                            showToast("브랜치 삭제됨: \(b)", icon: "trash.fill", color: Theme.red)
                        } else {
                            showErrorToast("브랜치 삭제 실패")
                        }
                    }
                }
                branchToDelete = nil
            }
        } message: {
            Text("브랜치 '\(branchToDelete ?? "")'를 삭제합니다.")
        }
        .alert("Force Push 경고", isPresented: $showForcePushWarning) {
            Button(NSLocalizedString("cancel", comment: ""), role: .cancel) { }
            Button("강제 푸시", role: .destructive) {
                if let tab = activeTab {
                    tab.sendPrompt("현재 브랜치를 리모트에 force push 해주세요.")
                }
            }
        } message: {
            Text("Force Push는 리모트의 커밋 히스토리를 덮어씁니다. 다른 협업자의 작업이 손실될 수 있습니다. 정말 진행하시겠습니까?")
        }
    }

    // ═══════════════════════════════════════════════════════
    // MARK: - Toolbar
    // ═══════════════════════════════════════════════════════

    private var gitToolbar: some View {
        HStack(spacing: Theme.sp2) {
            // Branch pill
            HStack(spacing: 4) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: Theme.iconSize(10), weight: .medium))
                    .foregroundColor(Theme.green)
                Text(git.currentBranch.isEmpty ? "—" : git.currentBranch)
                    .font(Theme.code(10, weight: .medium))
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(1)

                if let br = git.branches.first(where: { $0.isCurrent }) {
                    if br.ahead > 0 {
                        Text("↑\(br.ahead)").font(Theme.code(8, weight: .bold)).foregroundColor(Theme.green)
                    }
                    if br.behind > 0 {
                        Text("↓\(br.behind)").font(Theme.code(8, weight: .bold)).foregroundColor(Theme.orange)
                    }
                }
            }
            .padding(.horizontal, Theme.sp2).padding(.vertical, Theme.sp1 + 1)
            .background(RoundedRectangle(cornerRadius: Theme.cornerMedium).fill(Theme.accentBg(Theme.green)))
            .overlay(RoundedRectangle(cornerRadius: Theme.cornerMedium).stroke(Theme.accentBorder(Theme.green), lineWidth: 1))

            // Stats pills
            if !git.commits.isEmpty {
                statPill(icon: "clock.arrow.circlepath", text: "\(git.commits.count)", color: Theme.textDim)
            }
            if !allTags.isEmpty {
                statPill(icon: "tag.fill", text: "\(allTags.count)", color: Theme.yellow)
            }
            if !git.stashes.isEmpty {
                statPill(icon: "tray.full.fill", text: "\(git.stashes.count)", color: Theme.cyan)
            }
            if !git.conflictFiles.isEmpty {
                statPill(icon: "exclamationmark.triangle.fill", text: "\(git.conflictFiles.count)", color: Theme.red)
            }

            Spacer()

            // Action buttons
            Button(action: { actionType = .commit; actionInput = ""; showActionSheet = true }) {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: Theme.iconSize(9)))
                    Text("커밋").font(Theme.chrome(9, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(RoundedRectangle(cornerRadius: 6).fill(Theme.green))
            }
            .buttonStyle(.plain)

            toolbarActionBtn(NSLocalizedString("git.push", comment: ""), icon: "arrow.up.circle.fill", color: Theme.accent) {
                executeGitAction(.push, input: "")
            }
            toolbarActionBtn(NSLocalizedString("git.pull", comment: ""), icon: "arrow.down.circle.fill", color: Theme.cyan) {
                executeGitAction(.pull, input: "")
            }

            Rectangle().fill(Theme.border).frame(width: 1, height: 16)

            Button(action: { actionType = .branch; actionInput = ""; showActionSheet = true }) {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.triangle.branch").font(.system(size: Theme.iconSize(8)))
                    Text("브랜치").font(Theme.chrome(8, weight: .medium))
                }
                .foregroundColor(Theme.textSecondary)
                .padding(.horizontal, 6).padding(.vertical, 4)
            }
            .buttonStyle(.plain)

            Button(action: { actionType = .stash; actionInput = ""; showActionSheet = true }) {
                HStack(spacing: 3) {
                    Image(systemName: "tray.and.arrow.down.fill").font(.system(size: Theme.iconSize(8)))
                    Text("스태시").font(Theme.chrome(8, weight: .medium))
                }
                .foregroundColor(Theme.textSecondary)
                .padding(.horizontal, 6).padding(.vertical, 4)
            }
            .buttonStyle(.plain)

            Rectangle().fill(Theme.border).frame(width: 1, height: 16)

            Button(action: { git.refreshAll() }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: Theme.iconSize(10), weight: .medium))
                    .foregroundColor(Theme.textDim)
                    .rotationEffect(.degrees(git.isLoading ? 360 : 0))
                    .animation(git.isLoading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: git.isLoading)
            }.buttonStyle(.plain)
        }
        .padding(.horizontal, Theme.sp3).padding(.vertical, Theme.sp2 - 1)
        .background(Theme.bgCard)
    }

    private func statPill(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 8, weight: .medium))
            Text(text).font(Theme.chrome(8, weight: .medium))
        }
        .foregroundColor(color)
        .padding(.horizontal, Theme.sp2 - 2).padding(.vertical, 3)
        .background(RoundedRectangle(cornerRadius: Theme.cornerSmall).fill(Theme.accentBg(color)))
    }

    private func toolbarActionBtn(_ label: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: Theme.iconSize(8)))
                Text(label).font(Theme.chrome(8, weight: .medium))
            }
            .foregroundColor(color)
            .padding(.horizontal, Theme.sp2).padding(.vertical, Theme.sp1 + 1)
            .background(RoundedRectangle(cornerRadius: Theme.cornerMedium).fill(Theme.accentBg(color)))
            .overlay(RoundedRectangle(cornerRadius: Theme.cornerMedium).stroke(Theme.accentBorder(color), lineWidth: 1))
        }.buttonStyle(.plain)
    }

    // ═══════════════════════════════════════════════════════
    // MARK: - Conflict Banner
    // ═══════════════════════════════════════════════════════

    private var conflictBanner: some View {
        VStack(spacing: 0) {
            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { showConflictList.toggle() } }) {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Theme.red)
                    Text("\(git.conflictFiles.count)개 파일 충돌")
                        .font(Theme.chrome(10, weight: .bold))
                        .foregroundColor(Theme.red)
                    Spacer()
                    Image(systemName: showConflictList ? "chevron.up" : "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(Theme.red.opacity(0.6))
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Theme.red.opacity(0.08))
            }
            .buttonStyle(.plain)

            if showConflictList {
                VStack(spacing: 2) {
                    ForEach(git.conflictFiles) { file in
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 9))
                                .foregroundColor(Theme.red)
                            Text(file.fileName)
                                .font(Theme.mono(9, weight: .medium))
                                .foregroundColor(Theme.textPrimary)
                                .lineLimit(1)
                            Spacer()
                            Button("Ours") {
                                resolveConflict(file.path, strategy: "ours")
                            }
                            .font(Theme.mono(7, weight: .bold))
                            .foregroundColor(Theme.green)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(RoundedRectangle(cornerRadius: 4).fill(Theme.green.opacity(0.1)))
                            .buttonStyle(.plain)

                            Button("Theirs") {
                                resolveConflict(file.path, strategy: "theirs")
                            }
                            .font(Theme.mono(7, weight: .bold))
                            .foregroundColor(Theme.accent)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(RoundedRectangle(cornerRadius: 4).fill(Theme.accent.opacity(0.1)))
                            .buttonStyle(.plain)

                            Button("수동 해결") {
                                if let tab = activeTab {
                                    tab.sendPrompt("'\(file.path)' 파일의 충돌을 수동으로 해결해주세요.")
                                }
                            }
                            .font(Theme.mono(7, weight: .bold))
                            .foregroundColor(Theme.yellow)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(RoundedRectangle(cornerRadius: 4).fill(Theme.yellow.opacity(0.1)))
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 12).padding(.vertical, 4)
                    }
                }
                .padding(.bottom, 6)
                .background(Theme.red.opacity(0.03))
            }
        }
    }

    private func resolveConflict(_ filePath: String, strategy: String) {
        guard let tab = activeTab else { return }
        tab.sendPrompt("'\(filePath)' 파일의 충돌을 \(strategy) 전략으로 해결해주세요. 그리고 해당 파일을 스테이징해주세요.")
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak git] in git?.refreshAll() }
    }

    // ═══════════════════════════════════════════════════════
    // MARK: - Left Sidebar
    // ═══════════════════════════════════════════════════════

    private var leftSidebar: some View {
        VStack(spacing: 0) {
            // Sidebar header
            HStack(spacing: 6) {
                Image(systemName: "sidebar.left")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(Theme.textDim)
                Text("탐색")
                    .font(Theme.chrome(9, weight: .bold))
                    .foregroundColor(Theme.textSecondary)
                Spacer()
            }
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(Theme.bgCard)
            Rectangle().fill(Theme.border).frame(height: 1)

            ScrollView {
                VStack(spacing: 0) {
                    // Branches section
                    sidebarSection(
                        title: "브랜치",
                        icon: "arrow.triangle.branch",
                        color: Theme.accent,
                        count: localBranches.count,
                        isExpanded: $sidebarBranchesExpanded
                    ) {
                        ForEach(localBranches) { br in
                            sidebarBranchItem(br)
                        }
                    }

                    sidebarDivider

                    // Tags section
                    sidebarSection(
                        title: NSLocalizedString("git.tags", comment: ""),
                        icon: "tag.fill",
                        color: Theme.yellow,
                        count: allTags.count,
                        isExpanded: $sidebarTagsExpanded
                    ) {
                        ForEach(allTags, id: \.name) { tag in
                            sidebarTagItem(tag)
                        }
                    }

                    sidebarDivider

                    // Stashes section
                    sidebarSection(
                        title: "스태시",
                        icon: "tray.full.fill",
                        color: Theme.cyan,
                        count: git.stashes.count,
                        isExpanded: $sidebarStashesExpanded
                    ) {
                        ForEach(git.stashes) { stash in
                            sidebarStashItem(stash)
                        }
                    }

                    sidebarDivider

                    // Remotes section
                    sidebarSection(
                        title: NSLocalizedString("git.remotes", comment: ""),
                        icon: "cloud.fill",
                        color: Theme.purple,
                        count: remoteNames.count,
                        isExpanded: $sidebarRemotesExpanded
                    ) {
                        ForEach(remoteNames, id: \.self) { remote in
                            sidebarRemoteItem(remote)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .background(Theme.bgCard.opacity(0.5))
    }

    private var sidebarDivider: some View {
        Rectangle().fill(Theme.border.opacity(0.5)).frame(height: 0.5)
            .padding(.horizontal, 8)
    }

    private func sidebarSection<Content: View>(
        title: String,
        icon: String,
        color: Color,
        count: Int,
        isExpanded: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        VStack(spacing: 0) {
            Button(action: { withAnimation(.easeInOut(duration: 0.15)) { isExpanded.wrappedValue.toggle() } }) {
                HStack(spacing: 6) {
                    Image(systemName: isExpanded.wrappedValue ? "chevron.down" : "chevron.right")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundColor(Theme.textDim)
                        .frame(width: 10)
                    Image(systemName: icon)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(color)
                    Text(title)
                        .font(Theme.chrome(9, weight: .semibold))
                        .foregroundColor(Theme.textSecondary)
                    Spacer()
                    Text("\(count)")
                        .font(Theme.mono(7, weight: .bold))
                        .foregroundColor(color.opacity(0.7))
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(Capsule().fill(color.opacity(0.08)))
                }
                .padding(.horizontal, 8).padding(.vertical, 6)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded.wrappedValue {
                VStack(spacing: 1) {
                    content()
                }
                .padding(.leading, 8).padding(.trailing, 4).padding(.bottom, 4)
            }
        }
    }

    private func sidebarBranchItem(_ br: GitBranchInfo) -> some View {
        Button(action: {
            if !br.isCurrent {
                actionType = .checkout; actionInput = br.name; showActionSheet = true
            }
        }) {
            HStack(spacing: 6) {
                Image(systemName: br.isCurrent ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(br.isCurrent ? Theme.green : Theme.textDim.opacity(0.4))
                Text(br.name)
                    .font(Theme.mono(8, weight: br.isCurrent ? .bold : .regular))
                    .foregroundColor(br.isCurrent ? Theme.textPrimary : Theme.textSecondary)
                    .lineLimit(1)
                Spacer()
                if br.ahead > 0 {
                    Text("↑\(br.ahead)").font(Theme.mono(6, weight: .bold)).foregroundColor(Theme.green)
                }
                if br.behind > 0 {
                    Text("↓\(br.behind)").font(Theme.mono(6, weight: .bold)).foregroundColor(Theme.orange)
                }
            }
            .padding(.vertical, 3).padding(.horizontal, 6)
            .background(RoundedRectangle(cornerRadius: 4).fill(br.isCurrent ? Theme.green.opacity(0.06) : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            if !br.isCurrent {
                Button("체크아웃") {
                    actionType = .checkout; actionInput = br.name; showActionSheet = true
                }
                Divider()
                Button("브랜치 삭제", role: .destructive) {
                    branchToDelete = br.name
                    showDeleteBranchAlert = true
                }
            }
        }
    }

    private func sidebarTagItem(_ tag: GitCommitNode.GitRef) -> some View {
        Button(action: {
            if let commit = git.commits.first(where: { $0.refs.contains(where: { $0.name == tag.name && $0.type == .tag }) }) {
                selectCommit(commit)
            }
        }) {
            HStack(spacing: 6) {
                Image(systemName: "tag.fill")
                    .font(.system(size: 7))
                    .foregroundColor(Theme.yellow.opacity(0.7))
                Text(tag.name)
                    .font(Theme.mono(8))
                    .foregroundColor(Theme.textSecondary)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.vertical, 3).padding(.horizontal, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("태그 삭제", role: .destructive) {
                git.deleteTag(name: tag.name)
            }
        }
    }

    private func sidebarStashItem(_ stash: GitStashEntry) -> some View {
        Button(action: {
            // Preview stash — select it
            selectedCommitId = nil
        }) {
            HStack(spacing: 6) {
                Image(systemName: "tray.fill")
                    .font(.system(size: 7))
                    .foregroundColor(Theme.cyan.opacity(0.7))
                VStack(alignment: .leading, spacing: 1) {
                    Text("stash@{\(stash.id)}")
                        .font(Theme.mono(7, weight: .medium))
                        .foregroundColor(Theme.cyan)
                    Text(stash.message)
                        .font(Theme.mono(7))
                        .foregroundColor(Theme.textDim)
                        .lineLimit(1)
                }
                Spacer()
            }
            .padding(.vertical, 3).padding(.horizontal, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("적용 (Apply)") { git.stashApply(index: stash.id) }
            Button("삭제 (Drop)", role: .destructive) { git.stashDrop(index: stash.id) }
        }
    }

    private func sidebarRemoteItem(_ remote: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "cloud.fill")
                .font(.system(size: 7))
                .foregroundColor(Theme.purple.opacity(0.7))
            Text(remote)
                .font(Theme.mono(8, weight: .medium))
                .foregroundColor(Theme.textSecondary)
            Spacer()
            let count = remoteBranches.filter { $0.name.hasPrefix("\(remote)/") }.count
            Text("\(count)")
                .font(Theme.mono(6, weight: .bold))
                .foregroundColor(Theme.textDim)
        }
        .padding(.vertical, 3).padding(.horizontal, 6)
    }

    // ═══════════════════════════════════════════════════════
    // MARK: - Center Panel (Graph + Commits)
    // ═══════════════════════════════════════════════════════

    private var centerPanel: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(Theme.textDim)
                TextField("커밋 검색 (메시지, 작성자, 해시)...", text: $searchText)
                    .font(Theme.mono(9))
                    .textFieldStyle(.plain)
                    .foregroundColor(Theme.textPrimary)
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 9))
                            .foregroundColor(Theme.textDim)
                    }.buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Theme.bgSurface.opacity(0.5))
            Rectangle().fill(Theme.border.opacity(0.5)).frame(height: 0.5)

            // Working directory bar
            if !git.workingDirStaged.isEmpty || !git.workingDirUnstaged.isEmpty {
                workingDirectoryBar
                Rectangle().fill(Theme.border).frame(height: 1)
            }

            // Column headers
            HStack(spacing: 0) {
                Text("그래프").frame(width: CGFloat(max(git.maxLaneCount, 1)) * 20 + 12, alignment: .center)
                Text("메시지").padding(.leading, 4)
                Spacer()
                Text("작성자").frame(width: 90, alignment: .center)
                Text("날짜").frame(width: 90, alignment: .trailing).padding(.trailing, 12)
            }
            .font(Theme.mono(7, weight: .bold))
            .foregroundColor(Theme.textDim.opacity(0.5))
            .padding(.vertical, 4)
            .background(Theme.bgSurface.opacity(0.3))

            Rectangle().fill(Theme.border.opacity(0.5)).frame(height: 0.5)

            // Commit list
            ScrollViewReader { scrollProxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(displayedCommits.enumerated()), id: \.element.id) { idx, commit in
                            commitRow(commit)
                                .id(commit.id)
                                .onTapGesture {
                                    selectCommit(commit)
                                    selectedKeyboardIndex = idx
                                }
                                .onHover { hovering in hoveredCommitId = hovering ? commit.id : nil }
                        }

                        // Load more / commit count
                        HStack(spacing: 8) {
                            Text("\(displayedCommits.count)개 커밋 표시됨")
                                .font(Theme.mono(8))
                                .foregroundColor(Theme.textDim)
                            if !searchText.isEmpty {
                                Text("(전체 \(git.commits.count)개 중)")
                                    .font(Theme.mono(7))
                                    .foregroundColor(Theme.textDim.opacity(0.6))
                            }
                            Spacer()
                            Button(action: { git.loadMoreCommits() }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.down.circle")
                                        .font(.system(size: 8))
                                    Text("더 불러오기")
                                        .font(Theme.mono(8, weight: .medium))
                                }
                                .foregroundColor(Theme.accent)
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(RoundedRectangle(cornerRadius: 5).fill(Theme.accent.opacity(0.06)))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 12).padding(.vertical, 8)
                    }
                }
                .onKeyPress(.upArrow) {
                    navigateCommit(direction: -1, scrollProxy: scrollProxy)
                    return .handled
                }
                .onKeyPress(.downArrow) {
                    navigateCommit(direction: 1, scrollProxy: scrollProxy)
                    return .handled
                }
            }
        }
    }

    private func navigateCommit(direction: Int, scrollProxy: ScrollViewProxy) {
        let commits = displayedCommits
        guard !commits.isEmpty else { return }
        let newIndex = max(0, min(commits.count - 1, selectedKeyboardIndex + direction))
        selectedKeyboardIndex = newIndex
        let commit = commits[newIndex]
        selectCommit(commit)
        withAnimation(.easeInOut(duration: 0.1)) {
            scrollProxy.scrollTo(commit.id, anchor: .center)
        }
    }

    private var workingDirectoryBar: some View {
        Button(action: {
            selectedCommitId = nil
            selectedFileForDiff = nil
            showDiffViewer = false
        }) {
            HStack(spacing: 0) {
                wipNode
                    .frame(width: CGFloat(max(git.maxLaneCount, 1)) * 20 + 12)

                HStack(spacing: 8) {
                    Text(NSLocalizedString("git.working.directory", comment: ""))
                        .font(Theme.mono(10, weight: .bold))
                        .foregroundColor(Theme.yellow)

                    if !git.workingDirStaged.isEmpty {
                        badge("\(git.workingDirStaged.count) staged", color: Theme.green)
                    }
                    badge("\(git.workingDirUnstaged.count) 변경", color: Theme.orange)

                    Spacer()

                    Text("\(git.workingDirStaged.count + git.workingDirUnstaged.count) files")
                        .font(Theme.mono(8))
                        .foregroundColor(Theme.textDim)
                        .padding(.trailing, 12)
                }
            }
            .padding(.vertical, 8)
            .background(selectedCommitId == nil ? Theme.yellow.opacity(0.04) : .clear)
            .overlay(alignment: .leading) {
                if selectedCommitId == nil {
                    Rectangle().fill(Theme.yellow).frame(width: 3)
                }
            }
        }.buttonStyle(.plain)
    }

    private var wipNode: some View {
        Canvas { ctx, size in
            let midX = size.width / 2
            let midY = size.height / 2
            let r: CGFloat = 5
            let rect = CGRect(x: midX - r, y: midY - r, width: r * 2, height: r * 2)
            ctx.stroke(Path(ellipseIn: rect), with: .color(Color.orange), style: StrokeStyle(lineWidth: 1.5, dash: [3, 2]))
        }
        .frame(width: 20, height: 20)
    }

    // MARK: - Commit Row

    private func commitRow(_ commit: GitCommitNode) -> some View {
        let isSelected = selectedCommitId == commit.id
        let isHovered = hoveredCommitId == commit.id
        let graphW = CGFloat(max(git.maxLaneCount, 1)) * 20 + 12
        let hasTag = commit.refs.contains { $0.type == .tag }

        return HStack(spacing: 0) {
            graphColumn(commit: commit).frame(width: graphW, height: 38)

            HStack(spacing: 5) {
                ForEach(commit.refs, id: \.name) { ref in refBadge(ref) }
                Text(commit.message)
                    .font(Theme.mono(10, weight: isSelected ? .bold : .regular))
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(1)
            }
            .padding(.leading, 4)

            Spacer(minLength: 8)

            Text(commit.author)
                .font(Theme.mono(8))
                .foregroundColor(Theme.textSecondary)
                .lineLimit(1)
                .frame(width: 90, alignment: .center)

            Text(Self.relativeDate(commit.date))
                .font(Theme.mono(8))
                .foregroundColor(Theme.textDim)
                .frame(width: 90, alignment: .trailing)
                .padding(.trailing, 12)
        }
        .padding(.vertical, Theme.sp1)
        .background(
            isSelected ? Theme.accentBg(Theme.accent) :
            isHovered ? Theme.bgHover :
            .clear
        )
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.borderSubtle).frame(height: 1)
        }
        .overlay(alignment: .leading) {
            if isSelected {
                Rectangle().fill(Theme.accent).frame(width: 2)
            } else if commit.refs.contains(where: { $0.type == .head }) {
                Rectangle().fill(Theme.green).frame(width: 2)
            }
        }
        .contentShape(Rectangle())
    }

    // MARK: - Graph Drawing

    private func graphColumn(commit: GitCommitNode) -> some View {
        let laneColors = GitDataProvider.laneColors
        let colW: CGFloat = 20
        let activeLanes = commit.activeLanes
        let commitLane = commit.lane
        let parentHashes = commit.parentHashes
        let laneMap = git.commitLaneMap
        let isMerge = parentHashes.count > 1
        let hasTag = commit.refs.contains { $0.type == .tag }

        return Canvas { ctx, size in
            let rowH = size.height
            let midY = rowH / 2

            for laneIdx in activeLanes where laneIdx != commitLane {
                let x = CGFloat(laneIdx) * colW + 10
                let color = laneColors[laneIdx % laneColors.count]
                let p = Path { p in p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: rowH)) }
                ctx.stroke(p, with: .color(color.opacity(0.25)), lineWidth: 1.5)
            }

            let nodeX = CGFloat(commitLane) * colW + 10
            let nodeColor = laneColors[commitLane % laneColors.count]

            ctx.stroke(Path { p in p.move(to: CGPoint(x: nodeX, y: 0)); p.addLine(to: CGPoint(x: nodeX, y: midY)) },
                       with: .color(nodeColor.opacity(0.4)), lineWidth: 1.5)
            if !parentHashes.isEmpty {
                ctx.stroke(Path { p in p.move(to: CGPoint(x: nodeX, y: midY)); p.addLine(to: CGPoint(x: nodeX, y: rowH)) },
                           with: .color(nodeColor.opacity(0.4)), lineWidth: 1.5)
            }

            for pIdx in parentHashes.indices.dropFirst() {
                if let parentLane = laneMap[parentHashes[pIdx]] {
                    let parentX = CGFloat(parentLane) * colW + 10
                    let mergeColor = laneColors[parentLane % laneColors.count]
                    let mp = Path { p in
                        p.move(to: CGPoint(x: nodeX, y: midY))
                        p.addCurve(to: CGPoint(x: parentX, y: rowH),
                                   control1: CGPoint(x: nodeX, y: midY + rowH * 0.3),
                                   control2: CGPoint(x: parentX, y: rowH - rowH * 0.3))
                    }
                    ctx.stroke(mp, with: .color(mergeColor.opacity(0.4)), lineWidth: 1.5)
                }
            }

            let r: CGFloat = hasTag ? 5 : 4
            let nodeRect = CGRect(x: nodeX - r, y: midY - r, width: r * 2, height: r * 2)
            if hasTag {
                let diamond = Path { p in
                    p.move(to: CGPoint(x: nodeX, y: midY - r))
                    p.addLine(to: CGPoint(x: nodeX + r, y: midY))
                    p.addLine(to: CGPoint(x: nodeX, y: midY + r))
                    p.addLine(to: CGPoint(x: nodeX - r, y: midY))
                    p.closeSubpath()
                }
                ctx.fill(diamond, with: .color(Color.yellow))
                ctx.stroke(diamond, with: .color(Color.yellow.opacity(0.6)), lineWidth: 1)
            } else {
                ctx.fill(Path(ellipseIn: nodeRect), with: .color(nodeColor))
                if isMerge {
                    let ring = CGRect(x: nodeX - r - 1.5, y: midY - r - 1.5, width: (r + 1.5) * 2, height: (r + 1.5) * 2)
                    ctx.stroke(Path(ellipseIn: ring), with: .color(nodeColor), lineWidth: 1.5)
                }
            }
        }
    }

    // MARK: - Ref Badges

    private func refBadge(_ ref: GitCommitNode.GitRef) -> some View {
        let (tint, icon): (Color, String) = {
            switch ref.type {
            case .head: return (Theme.green, "chevron.right")
            case .branch: return (Theme.accent, "arrow.triangle.branch")
            case .remoteBranch: return (Theme.purple, "cloud.fill")
            case .tag: return (Theme.yellow, "tag.fill")
            }
        }()

        return HStack(spacing: 2) {
            Image(systemName: icon).font(.system(size: 6, weight: .bold))
            Text(ref.name).font(Theme.code(7, weight: .bold)).lineLimit(1)
        }
        .foregroundColor(tint)
        .padding(.horizontal, Theme.sp1 + 1).padding(.vertical, 2)
        .background(RoundedRectangle(cornerRadius: Theme.cornerSmall).fill(Theme.accentBg(tint)))
        .overlay(RoundedRectangle(cornerRadius: Theme.cornerSmall).stroke(Theme.accentBorder(tint), lineWidth: 1))
    }

    // ═══════════════════════════════════════════════════════
    // MARK: - Right Panel
    // ═══════════════════════════════════════════════════════

    private var rightPanel: some View {
        VStack(spacing: 0) {
            if showDiffViewer, let file = selectedFileForDiff {
                // Diff viewer mode
                diffViewerPanel(file: file)
            } else if let cid = selectedCommitId, let commit = git.commits.first(where: { $0.id == cid }) {
                // Commit selected — show tabs
                commitRightPanel(commit)
            } else {
                // Working directory mode
                workingDirectoryDetail
            }
        }
        .background(Theme.bgCard)
    }

    // MARK: - Commit Right Panel (Tabs: Changes / Info)

    private func commitRightPanel(_ commit: GitCommitNode) -> some View {
        VStack(spacing: 0) {
            // Tab bar
            HStack(spacing: 0) {
                commitRightTabButton(NSLocalizedString("git.changes", comment: ""), tab: .changes, icon: "doc.text.fill")
                commitRightTabButton("정보", tab: .info, icon: "info.circle.fill")
                Spacer()
            }
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(Theme.bgCard)
            Rectangle().fill(Theme.border).frame(height: 1)

            switch rightTab {
            case .changes:
                commitChangesTab(commit)
            case .info:
                commitInfoTab(commit)
            }
        }
    }

    private func commitRightTabButton(_ label: String, tab: RightPanelTab, icon: String) -> some View {
        let selected = rightTab == tab
        return Button(action: { withAnimation(.easeInOut(duration: 0.15)) { rightTab = tab } }) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: Theme.iconSize(8)))
                Text(label).font(Theme.chrome(8, weight: selected ? .bold : .regular))
            }
            .foregroundColor(selected ? Theme.accent : Theme.textDim)
            .padding(.horizontal, 8).padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 5).fill(selected ? Theme.accent.opacity(0.1) : .clear))
        }.buttonStyle(.plain)
    }

    // MARK: - Commit Changes Tab

    private func commitChangesTab(_ commit: GitCommitNode) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                // Commit header
                HStack(spacing: 6) {
                    Text(commit.shortHash)
                        .font(Theme.mono(9, weight: .bold))
                        .foregroundColor(Theme.accent)
                    Text(commit.message)
                        .font(Theme.mono(9))
                        .foregroundColor(Theme.textPrimary)
                        .lineLimit(1)
                    Spacer()
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 6).fill(Theme.bgSurface))

                if git.selectedCommitFiles.isEmpty {
                    HStack {
                        Spacer()
                        VStack(spacing: 6) {
                            ProgressView().scaleEffect(0.7)
                            Text("파일 로딩 중...")
                                .font(Theme.mono(8))
                                .foregroundColor(Theme.textDim)
                        }
                        .padding(.vertical, 20)
                        Spacer()
                    }
                } else {
                    sectionHeader("변경 파일", count: git.selectedCommitFiles.count, icon: "doc.text.fill", color: Theme.textSecondary)

                    ForEach(git.selectedCommitFiles) { f in
                        Button(action: {
                            selectedFileForDiff = f
                            git.fetchParsedDiff(path: f.path, staged: false, hash: commit.id)
                            showDiffViewer = true
                        }) {
                            fileChangeRow(f, showDiffArrow: true)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(10)
        }
    }

    // MARK: - Commit Info Tab

    private func commitInfoTab(_ commit: GitCommitNode) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                // Commit message card
                VStack(alignment: .leading, spacing: 6) {
                    Text(commit.message)
                        .font(Theme.mono(12, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    if !commit.body.isEmpty {
                        let clean = commit.body.components(separatedBy: "\n")
                            .filter { !$0.lowercased().contains("co-authored-by") }
                            .joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                        if !clean.isEmpty {
                            Text(clean).font(Theme.mono(9)).foregroundColor(Theme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 8).fill(Theme.bgSurface))

                // Metadata
                VStack(spacing: 5) {
                    metaRow("커밋", commit.shortHash, mono: true, copyValue: commit.id)
                    if !commit.parentHashes.isEmpty {
                        metaRow("부모", commit.parentHashes.map { String($0.prefix(7)) }.joined(separator: " ← "), mono: true)
                    }
                    metaRow("작성자", commit.author)
                    metaRow("날짜", Self.formatDate(commit.date))
                    if !commit.coAuthors.isEmpty {
                        metaRow("공동작성", commit.coAuthors.joined(separator: "\n"))
                    }

                    if !commit.refs.isEmpty {
                        HStack(alignment: .top, spacing: 8) {
                            Text("참조").font(Theme.mono(8, weight: .bold)).foregroundColor(Theme.textDim)
                                .frame(width: 52, alignment: .trailing)
                            FlowLayout(spacing: 4) {
                                ForEach(commit.refs, id: \.name) { r in refBadge(r) }
                            }
                        }
                    }
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 8).fill(Theme.bgSurface))
            }
            .padding(10)
        }
    }

    // MARK: - Working Directory Detail

    private var workingDirectoryDetail: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: "folder.badge.gearshape")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Theme.accent)
                Text(NSLocalizedString("git.working.directory", comment: ""))
                    .font(Theme.chrome(9, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                Spacer()
                Text("\(git.workingDirStaged.count + git.workingDirUnstaged.count)개 변경")
                    .font(Theme.mono(8))
                    .foregroundColor(Theme.textDim)
            }
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(Theme.bgCard)
            Rectangle().fill(Theme.border).frame(height: 1)

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    // Staged files section
                    if !git.workingDirStaged.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                sectionHeader(NSLocalizedString("git.staged", comment: ""), count: git.workingDirStaged.count, icon: "checkmark.circle.fill", color: Theme.green)
                                Spacer()

                                // Select All / Deselect All toggle
                                Button(action: {
                                    let allPaths = Set(git.workingDirStaged.map { $0.path })
                                    if selectedFilesForCommit.count == allPaths.count {
                                        selectedFilesForCommit.removeAll()
                                    } else {
                                        selectedFilesForCommit = allPaths
                                    }
                                }) {
                                    Text(selectedFilesForCommit.count == git.workingDirStaged.count && !selectedFilesForCommit.isEmpty ? "선택 해제" : "전체 선택")
                                        .font(Theme.mono(7, weight: .bold))
                                        .foregroundColor(Theme.accent)
                                        .padding(.horizontal, 6).padding(.vertical, 2)
                                        .background(RoundedRectangle(cornerRadius: 4).fill(Theme.accent.opacity(0.08)))
                                }
                                .buttonStyle(.plain)

                                Button(action: { git.unstageAll(); showInfoToast("전체 파일 언스테이지됨") }) {
                                    Text("모두 언스테이지")
                                        .font(Theme.mono(7, weight: .bold))
                                        .foregroundColor(Theme.orange)
                                        .padding(.horizontal, 6).padding(.vertical, 2)
                                        .background(RoundedRectangle(cornerRadius: 4).fill(Theme.orange.opacity(0.08)))
                                }
                                .buttonStyle(.plain)
                            }

                            // Selection count indicator
                            if !selectedFilesForCommit.isEmpty {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.square.fill")
                                        .font(.system(size: 8))
                                        .foregroundColor(Theme.accent)
                                    Text("\(selectedFilesForCommit.count)/\(git.workingDirStaged.count) 파일 선택됨")
                                        .font(Theme.mono(8))
                                        .foregroundColor(Theme.accent)
                                }
                                .padding(.horizontal, 4)
                            }

                            ForEach(git.workingDirStaged) { f in
                                HStack(spacing: 0) {
                                    // Selection checkbox
                                    Button(action: {
                                        if selectedFilesForCommit.contains(f.path) {
                                            selectedFilesForCommit.remove(f.path)
                                        } else {
                                            selectedFilesForCommit.insert(f.path)
                                        }
                                    }) {
                                        Image(systemName: selectedFilesForCommit.contains(f.path) ? "checkmark.square.fill" : "square")
                                            .font(.system(size: 11))
                                            .foregroundColor(selectedFilesForCommit.contains(f.path) ? Theme.accent : Theme.textDim)
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.leading, 6)
                                    .padding(.trailing, 2)

                                    Button(action: {
                                        selectedFileForDiff = f
                                        git.fetchParsedDiff(path: f.path, staged: true)
                                        showDiffViewer = true
                                    }) {
                                        fileChangeRow(f, showDiffArrow: true)
                                    }
                                    .buttonStyle(.plain)

                                    Button(action: { git.unstageFile(path: f.path); showInfoToast("언스테이지: \(f.fileName)") }) {
                                        Text(NSLocalizedString("git.unstage", comment: ""))
                                            .font(Theme.mono(7, weight: .bold))
                                            .foregroundColor(Theme.orange)
                                            .padding(.horizontal, 6).padding(.vertical, 2)
                                            .background(RoundedRectangle(cornerRadius: 4).fill(Theme.orange.opacity(0.08)))
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.trailing, 6)
                                }
                            }
                        }
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Theme.bgSurface))
                    }

                    // Unstaged files section
                    if !git.workingDirUnstaged.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                sectionHeader(NSLocalizedString("git.changes", comment: ""), count: git.workingDirUnstaged.count, icon: "pencil.circle.fill", color: Theme.orange)
                                Spacer()
                                Button(action: { git.stageAll(); showSuccessToast("전체 파일 스테이지됨") }) {
                                    Text("모두 스테이지")
                                        .font(Theme.mono(7, weight: .bold))
                                        .foregroundColor(Theme.green)
                                        .padding(.horizontal, 6).padding(.vertical, 2)
                                        .background(RoundedRectangle(cornerRadius: 4).fill(Theme.green.opacity(0.08)))
                                }
                                .buttonStyle(.plain)
                            }

                            ForEach(git.workingDirUnstaged) { f in
                                HStack(spacing: 0) {
                                    Button(action: {
                                        selectedFileForDiff = f
                                        git.fetchParsedDiff(path: f.path, staged: false)
                                        showDiffViewer = true
                                    }) {
                                        fileChangeRow(f, showDiffArrow: true)
                                    }
                                    .buttonStyle(.plain)

                                    Button(action: { git.stageFile(path: f.path); showSuccessToast("스테이지: \(f.fileName)") }) {
                                        Text(NSLocalizedString("git.stage", comment: ""))
                                            .font(Theme.mono(7, weight: .bold))
                                            .foregroundColor(Theme.green)
                                            .padding(.horizontal, 6).padding(.vertical, 2)
                                            .background(RoundedRectangle(cornerRadius: 4).fill(Theme.green.opacity(0.08)))
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.trailing, 2)

                                    Button(action: {
                                        fileToDiscard = f
                                        showDiscardAlert = true
                                    }) {
                                        Text(NSLocalizedString("git.discard", comment: ""))
                                            .font(Theme.mono(7, weight: .bold))
                                            .foregroundColor(Theme.red)
                                            .padding(.horizontal, 6).padding(.vertical, 2)
                                            .background(RoundedRectangle(cornerRadius: 4).fill(Theme.red.opacity(0.08))
                                                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Theme.red.opacity(0.15), lineWidth: 0.5)))
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.trailing, 6)
                                }
                            }
                        }
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Theme.bgSurface))
                    }

                    // Inline commit box
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(Theme.green)
                            Text(NSLocalizedString("git.commit.message", comment: ""))
                                .font(Theme.chrome(9, weight: .bold))
                                .foregroundColor(Theme.textSecondary)
                        }

                        TextEditor(text: $commitMessage)
                            .font(Theme.mono(9))
                            .foregroundColor(Theme.textPrimary)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 60, maxHeight: 120)
                            .padding(6)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Theme.bgSurface))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.border, lineWidth: 1))

                        HStack {
                            if !selectedFilesForCommit.isEmpty {
                                Text("\(selectedFilesForCommit.count)/\(git.workingDirStaged.count) 파일 선택됨")
                                    .font(Theme.mono(8))
                                    .foregroundColor(Theme.accent)
                            }
                            Spacer()
                            Button(action: {
                                guard !commitMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                                let msg = commitMessage
                                if selectedFilesForCommit.isEmpty || selectedFilesForCommit.count == git.workingDirStaged.count {
                                    git.commitDirectly(message: msg) { success in
                                        if success {
                                            let short = msg.count > 30 ? String(msg.prefix(30)) + "..." : msg
                                            showSuccessToast("커밋 완료: \(short)")
                                        } else {
                                            showErrorToast("커밋 실패: \(git.lastError ?? "알 수 없는 오류")")
                                        }
                                    }
                                } else {
                                    let allStaged = git.workingDirStaged.map { $0.path }
                                    let unselected = allStaged.filter { !selectedFilesForCommit.contains($0) }
                                    for path in unselected { git.unstageFile(path: path) }
                                    git.commitDirectly(message: msg) { success in
                                        for path in unselected { git.stageFile(path: path) }
                                        if success {
                                            let short = msg.count > 30 ? String(msg.prefix(30)) + "..." : msg
                                            showSuccessToast("커밋 완료: \(short)")
                                        } else {
                                            showErrorToast("커밋 실패: \(git.lastError ?? "알 수 없는 오류")")
                                        }
                                    }
                                }
                                commitMessage = ""
                                selectedFilesForCommit.removeAll()
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 9))
                                    Text(selectedFilesForCommit.isEmpty ? "커밋" : "선택 커밋")
                                        .font(Theme.chrome(9, weight: .bold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .background(RoundedRectangle(cornerRadius: 6).fill(
                                    commitMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                        ? Theme.green.opacity(0.3)
                                        : Theme.green
                                ))
                            }
                            .buttonStyle(.plain)
                            .disabled(commitMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Theme.bgSurface))

                    // Stash section
                    if !git.stashes.isEmpty {
                        stashSection
                    }

                    // Quick actions
                    quickActionGrid
                }
                .padding(10)
            }
        }
    }

    // ═══════════════════════════════════════════════════════
    // MARK: - Diff Viewer
    // ═══════════════════════════════════════════════════════

    private func diffViewerPanel(file: GitFileChange) -> some View {
        VStack(spacing: 0) {
            // Diff header
            HStack(spacing: 8) {
                Button(action: {
                    showDiffViewer = false
                    selectedFileForDiff = nil
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Theme.textDim)
                }
                .buttonStyle(.plain)

                Image(systemName: file.status.icon)
                    .font(.system(size: 9))
                    .foregroundColor(file.status.color)
                Text(file.fileName)
                    .font(Theme.mono(9, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(1)
                Text(file.path)
                    .font(Theme.mono(7))
                    .foregroundColor(Theme.textDim)
                    .lineLimit(1)
                Spacer()

                Text("통합 뷰")
                    .font(Theme.mono(7, weight: .bold))
                    .foregroundColor(Theme.accent)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(RoundedRectangle(cornerRadius: 4).fill(Theme.accent.opacity(0.1)))
            }
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(Theme.bgCard)
            Rectangle().fill(Theme.border).frame(height: 1)

            // Diff content
            if let diff = git.diffResult {
                if diff.isBinary {
                    VStack(spacing: 8) {
                        Image(systemName: "doc.zipper")
                            .font(.system(size: 24))
                            .foregroundColor(Theme.textDim.opacity(0.4))
                        Text("바이너리 파일")
                            .font(Theme.mono(10, weight: .medium))
                            .foregroundColor(Theme.textDim)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if diff.hunks.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 24))
                            .foregroundColor(Theme.textDim.opacity(0.4))
                        Text("변경사항 없음")
                            .font(Theme.mono(10))
                            .foregroundColor(Theme.textDim)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView([.horizontal, .vertical]) {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(diff.hunks.enumerated()), id: \.offset) { hunkIdx, hunk in
                                // Hunk header
                                HStack(spacing: 0) {
                                    Text(hunk.header)
                                        .font(Theme.mono(8, weight: .medium))
                                        .foregroundColor(Theme.purple)
                                        .padding(.horizontal, 8).padding(.vertical, 4)
                                    Spacer()
                                }
                                .background(Theme.purple.opacity(0.06))
                                .overlay(alignment: .bottom) {
                                    Rectangle().fill(Theme.purple.opacity(0.15)).frame(height: 0.5)
                                }

                                // Lines
                                ForEach(Array(hunk.lines.enumerated()), id: \.offset) { lineIdx, line in
                                    diffLineView(line)
                                }

                                if hunkIdx < diff.hunks.count - 1 {
                                    Rectangle().fill(Theme.border.opacity(0.3)).frame(height: 1)
                                        .padding(.vertical, 2)
                                }
                            }
                        }
                        .frame(minWidth: 400)
                    }
                }
            } else {
                VStack(spacing: 8) {
                    ProgressView().scaleEffect(0.7)
                    Text("Diff 로딩 중...")
                        .font(Theme.mono(8))
                        .foregroundColor(Theme.textDim)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func diffLineView(_ line: DiffLine) -> some View {
        let bgColor: Color = {
            switch line.type {
            case .addition: return Theme.green.opacity(0.1)
            case .deletion: return Theme.red.opacity(0.1)
            case .context: return .clear
            }
        }()

        let textColor: Color = {
            switch line.type {
            case .addition: return Theme.green
            case .deletion: return Theme.red
            case .context: return Theme.textSecondary
            }
        }()

        let prefix: String = {
            switch line.type {
            case .addition: return "+"
            case .deletion: return "-"
            case .context: return " "
            }
        }()

        return HStack(spacing: 0) {
            // Old line number
            Text(line.oldLineNum.map { "\($0)" } ?? "")
                .font(Theme.mono(7))
                .foregroundColor(Theme.textDim.opacity(0.5))
                .frame(width: 36, alignment: .trailing)
                .padding(.trailing, 4)

            // New line number
            Text(line.newLineNum.map { "\($0)" } ?? "")
                .font(Theme.mono(7))
                .foregroundColor(Theme.textDim.opacity(0.5))
                .frame(width: 36, alignment: .trailing)
                .padding(.trailing, 8)

            // Prefix
            Text(prefix)
                .font(Theme.mono(8, weight: .bold))
                .foregroundColor(textColor)
                .frame(width: 12)

            // Content
            Text(line.content)
                .font(Theme.mono(8))
                .foregroundColor(textColor)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 0.5)
        .background(bgColor)
    }

    // ═══════════════════════════════════════════════════════
    // MARK: - Bottom Action Bar
    // ═══════════════════════════════════════════════════════

    private var bottomActionBar: some View {
        HStack(spacing: 8) {
            // Stage All button
            Button(action: { git.stageAll(); showSuccessToast("전체 파일 스테이지됨") }) {
                HStack(spacing: 3) {
                    Image(systemName: "plus.circle.fill").font(.system(size: 9))
                    Text("전체 스테이지").font(Theme.mono(8, weight: .medium))
                }
                .foregroundColor(Theme.green)
                .padding(.horizontal, 8).padding(.vertical, 7)
                .background(RoundedRectangle(cornerRadius: 5).fill(Theme.green.opacity(0.06))
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(Theme.green.opacity(0.12), lineWidth: 0.5)))
            }
            .buttonStyle(.plain)

            // File selection count indicator
            if !selectedFilesForCommit.isEmpty {
                Text("\(selectedFilesForCommit.count)/\(git.workingDirStaged.count) 파일 선택됨")
                    .font(Theme.mono(7, weight: .bold))
                    .foregroundColor(Theme.accent)
                    .padding(.horizontal, 6).padding(.vertical, 3)
                    .background(Capsule().fill(Theme.accent.opacity(0.1)))
            }

            Spacer()

            // Error indicator
            if let error = git.lastError {
                HStack(spacing: 3) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 8))
                        .foregroundColor(Theme.red)
                    Text(error)
                        .font(Theme.mono(7))
                        .foregroundColor(Theme.red)
                        .lineLimit(1)
                }
                .help(error)
            }

            // Push button
            Button(action: { executeGitAction(.push, input: "") }) {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.up.circle.fill").font(.system(size: 8))
                    Text(NSLocalizedString("git.push", comment: "")).font(Theme.mono(8, weight: .medium))
                    if let br = git.branches.first(where: { $0.isCurrent }), br.ahead > 0 {
                        Text("↑\(br.ahead)")
                            .font(Theme.mono(6, weight: .bold))
                            .foregroundColor(Theme.green)
                    }
                }
                .foregroundColor(Theme.accent)
                .padding(.horizontal, 8).padding(.vertical, 5)
                .background(RoundedRectangle(cornerRadius: 5).fill(Theme.accent.opacity(0.06))
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(Theme.accent.opacity(0.12), lineWidth: 0.5)))
            }
            .buttonStyle(.plain)

            // Pull button
            Button(action: { executeGitAction(.pull, input: "") }) {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.down.circle.fill").font(.system(size: 8))
                    Text(NSLocalizedString("git.pull", comment: "")).font(Theme.mono(8, weight: .medium))
                    if let br = git.branches.first(where: { $0.isCurrent }), br.behind > 0 {
                        Text("↓\(br.behind)")
                            .font(Theme.mono(6, weight: .bold))
                            .foregroundColor(Theme.orange)
                    }
                }
                .foregroundColor(Theme.cyan)
                .padding(.horizontal, 8).padding(.vertical, 5)
                .background(RoundedRectangle(cornerRadius: 5).fill(Theme.cyan.opacity(0.06))
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(Theme.cyan.opacity(0.12), lineWidth: 0.5)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Theme.sp3).padding(.vertical, Theme.sp2)
        .background(Theme.bgCard)
    }

    // ═══════════════════════════════════════════════════════
    // MARK: - Shared Components
    // ═══════════════════════════════════════════════════════

    private func sectionHeader(_ title: String, count: Int, icon: String, color: Color) -> some View {
        HStack(spacing: Theme.sp1 + 2) {
            Image(systemName: icon).font(.system(size: Theme.iconSize(9))).foregroundColor(color)
            Text(title).font(Theme.mono(9, weight: .semibold)).foregroundColor(color)
            Text("\(count)").font(Theme.mono(8, weight: .medium)).foregroundColor(Theme.textMuted)
                .padding(.horizontal, Theme.sp1).padding(.vertical, 1)
                .background(RoundedRectangle(cornerRadius: 3).fill(Theme.bgTertiary))
            Spacer()
        }
    }

    private func fileChangeRow(_ file: GitFileChange, showDiffArrow: Bool = false) -> some View {
        HStack(spacing: Theme.sp2 - 2) {
            Image(systemName: file.status.icon)
                .font(.system(size: 9)).foregroundColor(file.status.color).frame(width: 14)
            Text(file.fileName)
                .font(Theme.code(9, weight: .medium)).foregroundColor(Theme.textPrimary).lineLimit(1)
            Spacer()
            Text(file.status.rawValue)
                .font(Theme.code(7, weight: .bold))
                .foregroundColor(file.status.color)
                .padding(.horizontal, Theme.sp1 + 1).padding(.vertical, 1)
                .background(RoundedRectangle(cornerRadius: Theme.cornerSmall).fill(Theme.accentBg(file.status.color)))
                .overlay(RoundedRectangle(cornerRadius: Theme.cornerSmall).stroke(Theme.accentBorder(file.status.color), lineWidth: 1))
            if showDiffArrow {
                Image(systemName: "chevron.right")
                    .font(.system(size: 7, weight: .medium))
                    .foregroundColor(Theme.textMuted)
            }
        }
        .padding(.vertical, Theme.sp1).padding(.horizontal, Theme.sp2)
        .background(RoundedRectangle(cornerRadius: 4).fill(file.status.color.opacity(0.04)))
        .contentShape(Rectangle())
    }

    private var stashSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionHeader("스태시", count: git.stashes.count, icon: "tray.full.fill", color: Theme.cyan)
            ForEach(git.stashes) { s in
                HStack(spacing: 6) {
                    Text("stash@{\(s.id)}").font(Theme.mono(8, weight: .medium)).foregroundColor(Theme.cyan)
                    Text(s.message).font(Theme.mono(8)).foregroundColor(Theme.textSecondary).lineLimit(1)
                    Spacer()
                    Button(action: { git.stashApply(index: s.id) }) {
                        Text("적용").font(Theme.mono(7, weight: .bold)).foregroundColor(Theme.green)
                            .padding(.horizontal, 4).padding(.vertical, 1)
                            .background(RoundedRectangle(cornerRadius: 3).fill(Theme.green.opacity(0.08)))
                    }.buttonStyle(.plain)
                    Button(action: { git.stashDrop(index: s.id) }) {
                        Text(NSLocalizedString("delete", comment: "")).font(Theme.mono(7, weight: .bold)).foregroundColor(Theme.red)
                            .padding(.horizontal, 4).padding(.vertical, 1)
                            .background(RoundedRectangle(cornerRadius: 3).fill(Theme.red.opacity(0.08)))
                    }.buttonStyle(.plain)
                }
                .padding(.vertical, 3).padding(.horizontal, 8)
                .background(RoundedRectangle(cornerRadius: 4).fill(Theme.bgSurface))
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(Theme.bgSurface.opacity(0.5)))
    }

    private var quickActionGrid: some View {
        let actions: [(String, String, GitAction, Color)] = [
            (NSLocalizedString("git.commit", comment: ""), "checkmark.circle.fill", .commit, Theme.green),
            (NSLocalizedString("git.push", comment: ""), "arrow.up.circle.fill", .push, Theme.accent),
            (NSLocalizedString("git.pull", comment: ""), "arrow.down.circle.fill", .pull, Theme.cyan),
            (NSLocalizedString("git.branch", comment: ""), "arrow.triangle.branch", .branch, Theme.purple),
            (NSLocalizedString("git.stash", comment: ""), "tray.and.arrow.down.fill", .stash, Theme.yellow),
            ("병합", "arrow.triangle.merge", .merge, Theme.orange),
        ]
        return VStack(alignment: .leading, spacing: 6) {
            sectionHeader("빠른 명령", count: actions.count, icon: "bolt.fill", color: Theme.textSecondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 6)], spacing: 6) {
                ForEach(actions, id: \.0) { (label, icon, action, color) in
                    Button(action: {
                        actionType = action; actionInput = ""
                        if action == .push || action == .pull { executeGitAction(action, input: "") }
                        else { showActionSheet = true }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: icon).font(.system(size: Theme.iconSize(9)))
                            Text(label).font(Theme.mono(8, weight: .medium))
                        }
                        .foregroundColor(color).frame(maxWidth: .infinity).padding(.vertical, 7)
                        .background(RoundedRectangle(cornerRadius: 6).fill(color.opacity(0.06))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(color.opacity(0.12), lineWidth: 0.5)))
                    }.buttonStyle(.plain)
                }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(Theme.bgSurface))
    }

    // ═══════════════════════════════════════════════════════
    // MARK: - Action Sheet (Claude-based Operations)
    // ═══════════════════════════════════════════════════════

    private var actionSheet: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: actionIcon(actionType)).font(.system(size: 16)).foregroundColor(Theme.accent)
                Text("Git \(actionType.displayName)").font(Theme.mono(14, weight: .bold)).foregroundColor(Theme.textPrimary)
                Spacer()
            }

            Group {
                switch actionType {
                case .commit:
                    VStack(alignment: .leading, spacing: 6) {
                        Text(NSLocalizedString("git.commit.message", comment: "")).font(Theme.mono(9, weight: .medium)).foregroundColor(Theme.textDim)
                        TextEditor(text: $actionInput).font(Theme.monoNormal).frame(height: 80).padding(4)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Theme.bgSurface))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.border, lineWidth: 1))
                    }
                case .branch:
                    VStack(alignment: .leading, spacing: 6) {
                        Text("브랜치 이름").font(Theme.mono(9, weight: .medium)).foregroundColor(Theme.textDim)
                        TextField("feature/...", text: $actionInput).font(Theme.monoNormal).textFieldStyle(.plain).padding(8)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Theme.bgSurface))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.border, lineWidth: 1))
                    }
                case .stash:
                    VStack(alignment: .leading, spacing: 6) {
                        Text("스태시 메시지 (선택)").font(Theme.mono(9, weight: .medium)).foregroundColor(Theme.textDim)
                        TextField("작업 중인 변경사항...", text: $actionInput).font(Theme.monoNormal).textFieldStyle(.plain).padding(8)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Theme.bgSurface))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.border, lineWidth: 1))
                    }
                case .merge, .checkout:
                    VStack(alignment: .leading, spacing: 6) {
                        Text(actionType == .merge ? "병합할 브랜치" : "체크아웃할 브랜치")
                            .font(Theme.mono(9, weight: .medium)).foregroundColor(Theme.textDim)
                        ScrollView {
                            VStack(spacing: 2) {
                                ForEach(git.branches.filter { b in actionType == .merge ? (!b.isCurrent && !b.isRemote) : !b.isCurrent }) { br in
                                    Button(action: { actionInput = br.name }) {
                                        HStack {
                                            Image(systemName: br.isRemote ? "cloud" : "arrow.triangle.branch").font(.system(size: 9))
                                            Text(br.name).font(Theme.mono(10))
                                            Spacer()
                                            if actionInput == br.name {
                                                Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundColor(Theme.green)
                                            }
                                        }
                                        .foregroundColor(actionInput == br.name ? Theme.accent : Theme.textSecondary)
                                        .padding(.horizontal, 8).padding(.vertical, 5)
                                        .background(RoundedRectangle(cornerRadius: 4).fill(actionInput == br.name ? Theme.accent.opacity(0.1) : .clear))
                                    }.buttonStyle(.plain)
                                }
                            }
                        }.frame(maxHeight: 150)
                    }
                default: EmptyView()
                }
            }

            HStack {
                Button(NSLocalizedString("cancel", comment: "")) { showActionSheet = false }
                    .font(Theme.mono(10, weight: .medium)).foregroundColor(Theme.textDim)
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Theme.bgSurface))
                    .buttonStyle(.plain)
                Spacer()
                Button(action: { executeGitAction(actionType, input: actionInput); showActionSheet = false }) {
                    HStack(spacing: 4) {
                        Image(systemName: "paperplane.fill").font(.system(size: 9))
                        Text("Claude에게 요청").font(Theme.mono(10, weight: .bold))
                    }
                    .foregroundColor(.white).padding(.horizontal, 16).padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Theme.accent))
                }
                .buttonStyle(.plain)
                .disabled(needsInput && actionInput.isEmpty)
                .opacity(needsInput && actionInput.isEmpty ? 0.5 : 1)
            }
        }
        .padding(20).frame(width: 420).background(Theme.bgCard)
    }

    private var needsInput: Bool {
        switch actionType {
        case .commit, .branch, .merge, .checkout: return true
        default: return false
        }
    }

    private func actionIcon(_ action: GitAction) -> String {
        switch action {
        case .commit: return "checkmark.circle"
        case .push: return "arrow.up.circle"
        case .pull: return "arrow.down.circle"
        case .branch: return "arrow.triangle.branch"
        case .stash: return "tray.and.arrow.down"
        case .merge: return "arrow.triangle.merge"
        case .checkout: return "arrow.uturn.right"
        }
    }

    // ═══════════════════════════════════════════════════════
    // MARK: - Actions & Helpers
    // ═══════════════════════════════════════════════════════

    private func executeGitAction(_ action: GitAction, input: String) {
        guard let tab = activeTab else { return }
        let prompt: String
        switch action {
        case .commit: prompt = "현재 변경사항을 커밋해주세요. 커밋 메시지: \"\(input)\""
        case .push: prompt = "현재 브랜치를 리모트에 푸시해주세요."
        case .pull: prompt = "리모트에서 최신 변경사항을 풀해주세요."
        case .branch: prompt = "새 브랜치 '\(input)'를 생성하고 체크아웃해주세요."
        case .stash: prompt = input.isEmpty ? "현재 변경사항을 스태시해주세요." : "현재 변경사항을 스태시해주세요. 메시지: \"\(input)\""
        case .merge: prompt = "브랜치 '\(input)'를 현재 브랜치에 병합해주세요."
        case .checkout: prompt = "브랜치 '\(input)'로 체크아웃해주세요."
        }
        tab.sendPrompt(prompt)

        // Toast feedback
        let toastMsg: String = {
            switch action {
            case .push: return "푸시 요청됨"
            case .pull: return "풀 요청됨"
            case .commit: return "커밋 요청됨"
            case .branch: return "브랜치 생성 요청: \(input)"
            case .stash: return "스태시 요청됨"
            case .merge: return "병합 요청: \(input)"
            case .checkout: return "체크아웃 요청: \(input)"
            }
        }()
        showInfoToast(toastMsg)

        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak git] in git?.refreshAll() }
    }

    private func selectCommit(_ commit: GitCommitNode) {
        selectedCommitId = commit.id
        selectedFileForDiff = nil
        showDiffViewer = false
        rightTab = .changes
        git.fetchCommitFiles(hash: commit.id)
    }

    private func badge(_ text: String, color: Color) -> some View {
        Text(text).font(Theme.mono(7, weight: .bold)).foregroundColor(color)
            .padding(.horizontal, 5).padding(.vertical, 1)
            .background(Capsule().fill(color.opacity(0.12)))
    }

    private func metaRow(_ label: String, _ value: String, mono: Bool = false, copyValue: String? = nil) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label).font(Theme.mono(8, weight: .bold)).foregroundColor(Theme.textDim)
                .frame(width: 52, alignment: .trailing)
            Text(value).font(mono ? Theme.mono(9, weight: .medium) : Theme.mono(9))
                .foregroundColor(Theme.textPrimary).textSelection(.enabled)
            if let cv = copyValue {
                Button(action: { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(cv, forType: .string) }) {
                    Image(systemName: "doc.on.doc").font(.system(size: 8)).foregroundColor(Theme.textDim)
                }.buttonStyle(.plain)
            }
            Spacer()
        }
    }

    private func emptyState(_ msg: String, icon: String) -> some View {
        VStack(spacing: Theme.sp3) {
            Image(systemName: icon)
                .font(.system(size: Theme.iconSize(24), weight: .light))
                .foregroundColor(Theme.textMuted)
            Text(msg)
                .font(Theme.mono(10))
                .foregroundColor(Theme.textDim)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private static let fullDateFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy.MM.dd HH:mm:ss"; return f
    }()

    private static let shortDateFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "M.d"; return f
    }()

    static func relativeDate(_ date: Date) -> String {
        let s = Int(Date().timeIntervalSince(date))
        if s < 60 { return "방금" }
        if s < 3600 { return "\(s / 60)분 전" }
        if s < 86400 { return "\(s / 3600)시간 전" }
        if s < 604800 { return "\(s / 86400)일 전" }
        return shortDateFormatter.string(from: date)
    }

    static func formatDate(_ date: Date) -> String { fullDateFormatter.string(from: date) }

    // MARK: - Toast

    private func showToast(_ message: String, icon: String = "checkmark.circle.fill", color: Color = Theme.green) {
        toastMessage = message
        toastIcon = icon
        toastColor = color
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            toastVisible = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.easeOut(duration: 0.3)) {
                toastVisible = false
            }
        }
    }

    private func showSuccessToast(_ message: String) {
        showToast(message, icon: "checkmark.circle.fill", color: Theme.green)
    }

    private func showErrorToast(_ message: String) {
        showToast(message, icon: "exclamationmark.triangle.fill", color: Theme.red)
    }

    private func showInfoToast(_ message: String) {
        showToast(message, icon: "info.circle.fill", color: Theme.accent)
    }
}

// MARK: - Git Toast View

struct GitToastView: View {
    let message: String
    let icon: String
    let color: Color
    let onDismiss: () -> Void
    @State private var isVisible = false

    var body: some View {
        Button(action: onDismiss) {
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(color.opacity(0.15)).frame(width: 28, height: 28)
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(color)
                }

                Text(message)
                    .font(Theme.mono(10, weight: .medium))
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(2)

                Spacer(minLength: 8)

                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(Theme.textDim.opacity(0.5))
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .frame(minWidth: 200, maxWidth: 360, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Theme.bgCard.opacity(0.98))
                    .shadow(color: Color.black.opacity(0.18), radius: 16, y: 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(color.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isVisible ? 1 : 0.95)
        .opacity(isVisible ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                isVisible = true
            }
        }
    }
}
