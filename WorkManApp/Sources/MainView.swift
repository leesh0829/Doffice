import SwiftUI

struct MainView: View {
    @EnvironmentObject var manager: SessionManager
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject private var achievementManager = AchievementManager.shared
    @State private var sidebarWidth: CGFloat = 230
    @State private var showSettings = false
    @State private var showClaudeNotInstalledAlert = false
    @State private var showRoleNoticeAlert = false
    @State private var roleNoticeTitle = ""
    @State private var roleNoticeMessage = ""
    @State private var showBugReport = false
    @State private var showUpdateSheet = false
    @ObservedObject private var updater = UpdateChecker.shared
    @Environment(\.openWindow) private var openWindow
    @AppStorage("officeExpanded") private var officeExpanded = true
    @AppStorage("viewMode") private var viewModeRaw: Int = 1

    private enum ViewMode: Int { case split = 0, office = 1, terminal = 2, strip = 3 }
    private var viewMode: ViewMode { ViewMode(rawValue: viewModeRaw) ?? .split }
    private var officeHeight: CGFloat { officeExpanded ? 380 : 240 }

    var body: some View {
        VStack(spacing: 0) {
            titleBar

            HStack(spacing: 0) {
                SidebarView()
                    .frame(width: sidebarWidth)

                Rectangle().fill(Theme.border).frame(width: 1)

                ZStack {
                    switch viewMode {
                    case .split:
                        splitView
                    case .office:
                        officeFullView
                    case .terminal:
                        TerminalAreaView()
                    case .strip:
                        stripView
                    }
                }
            }

            statusBar
        }
        .background(Theme.bg)
        .overlay(alignment: .topTrailing) {
            if let ach = achievementManager.recentUnlock {
                AchievementToastView(achievement: ach) {
                    achievementManager.dismissRecentUnlock()
                }
                .padding(.top, 44)
                .padding(.trailing, 18)
                .transition(
                    .asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .scale(scale: 0.96).combined(with: .opacity)
                    )
                )
                .animation(.easeOut(duration: 0.2), value: ach.id)
                .zIndex(10)
            }
        }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .sheet(isPresented: $showBugReport) { BugReportView() }
        .sheet(isPresented: $showUpdateSheet) { UpdateSheet() }
        .alert("Claude Code 미설치", isPresented: $showClaudeNotInstalledAlert) {
            Button("설치 방법 보기") {
                if let url = URL(string: "https://docs.anthropic.com/en/docs/claude-code/overview") {
                    NSWorkspace.shared.open(url)
                }
            }
            Button("확인", role: .cancel) {}
        } message: {
            Text("Claude Code CLI가 설치되어 있지 않습니다.\n\n터미널에서 아래 명령어로 설치해주세요:\n\nnpm install -g @anthropic-ai/claude-code\n\n설치 후 앱을 다시 실행해주세요.")
        }
        .alert(roleNoticeTitle, isPresented: $showRoleNoticeAlert) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(roleNoticeMessage)
        }
        .onAppear {
            settings.ensureCoffeeSupportPreset()
            if manager.userVisibleTabs.isEmpty {
                manager.restoreSessions()
                manager.autoDetectAndConnect()
            }
            // 앱 시작 시 Claude Code 설치 확인
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if !ClaudeInstallChecker.shared.isInstalled {
                    showClaudeNotInstalledAlert = true
                }
            }
            // 업데이트 확인
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                updater.checkForUpdates()
            }
        }
        .onDisappear { manager.stopScanning() }
        .onReceive(NotificationCenter.default.publisher(for: .workmanRefresh)) { _ in manager.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: .workmanNewTab)) { _ in manager.showNewTabSheet = true }
        .onReceive(NotificationCenter.default.publisher(for: .workmanCloseTab)) { _ in
            if let id = manager.activeTabId { manager.removeTab(id) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .workmanSelectTab)) { notif in
            let tabs = manager.userVisibleTabs
            if let i = notif.object as? Int, i >= 1, i <= tabs.count { manager.selectTab(tabs[i-1].id) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .workmanExportLog)) { _ in exportActiveLog() }
        .onReceive(NotificationCenter.default.publisher(for: .workmanClaudeNotInstalled)) { _ in
            showClaudeNotInstalledAlert = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .workmanRoleNotice)) { notif in
            roleNoticeTitle = notif.userInfo?["title"] as? String ?? "직업 안내"
            roleNoticeMessage = notif.userInfo?["message"] as? String ?? ""
            showRoleNoticeAlert = true
        }
        .onChange(of: viewModeRaw) { _, newValue in
            if newValue == ViewMode.terminal.rawValue {
                OfficeSceneStore.shared.suspend()
            }
        }
    }

    private func viewModeButton(icon: String, mode: ViewMode, label: String) -> some View {
        let isActive = viewMode == mode
        return Button(action: { withAnimation(.easeInOut(duration: 0.2)) { viewModeRaw = mode.rawValue } }) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(isActive ? Theme.accent : Theme.textDim)
                .frame(width: 30, height: 24)
                .background(isActive ? Theme.accent.opacity(0.12) : .clear)
        }
        .buttonStyle(.plain)
        .help(label)
    }

    // MARK: - Split View (기본 모드: 오피스 + 터미널)

    private var splitView: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottomTrailing) {
                OfficeSceneView()
                    .frame(height: officeHeight)

                // 오피스 시점 + 확장/축소 버튼
                HStack(spacing: 3) {
                    // 전체 맵 ↔ 포커스 시점 토글
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            settings.officeViewMode = settings.officeViewMode == "grid" ? "side" : "grid"
                        }
                    }) {
                        Image(systemName: settings.officeViewMode == "grid" ? "scope" : "rectangle.expand.vertical")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Theme.textDim.opacity(0.6))
                            .frame(width: 26, height: 20)
                            .background(RoundedRectangle(cornerRadius: 5).fill(Theme.bgCard.opacity(0.7)))
                            .overlay(RoundedRectangle(cornerRadius: 5).stroke(Theme.border.opacity(0.3), lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                    .help(settings.officeViewMode == "grid" ? "선택 캐릭터 포커스로 전환" : "오피스 전체 보기로 전환")

                    // 확장/축소
                    Button(action: { withAnimation(.easeInOut(duration: 0.25)) { officeExpanded.toggle() } }) {
                        Image(systemName: officeExpanded ? "chevron.up.2" : "chevron.down.2")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Theme.textDim.opacity(0.5))
                            .frame(width: 26, height: 20)
                            .background(RoundedRectangle(cornerRadius: 5).fill(Theme.bgCard.opacity(0.7)))
                            .overlay(RoundedRectangle(cornerRadius: 5).stroke(Theme.border.opacity(0.3), lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                    .help(officeExpanded ? "오피스 축소" : "오피스 확장")
                }
                .padding(4)
            }
            Rectangle().fill(Theme.border).frame(height: 1)
            TerminalAreaView()
        }
    }

    // MARK: - Strip View (v1.2 스타일: 픽셀 스트립 + 터미널)

    private var stripView: some View {
        VStack(spacing: 0) {
            PixelStripView()
                .frame(height: 120)
            Rectangle().fill(Theme.border).frame(height: 1)
            TerminalAreaView()
        }
    }

    // MARK: - Office Full View (오피스 전체 화면)

    private var officeFullView: some View {
        OfficeSceneView()
    }

    private func openOfficeWindow() {
        openWindow(id: "office-window")
        // 메인 창을 터미널 모드로 전환
        withAnimation(.easeInOut(duration: 0.2)) { viewModeRaw = ViewMode.terminal.rawValue }
    }

    private func exportActiveLog() {
        guard let tab = manager.activeTab, let url = tab.exportLog() else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = url.lastPathComponent
        panel.allowedContentTypes = [.plainText]
        if panel.runModal() == .OK, let dest = panel.url {
            try? FileManager.default.copyItem(at: url, to: dest)
        }
    }

    // MARK: - Title Bar

    private var titleBar: some View {
        HStack(spacing: 8) {
            Color.clear.frame(width: 58, height: 1) // macOS 신호등 버튼 영역

            HStack(spacing: 4) {
                Text(settings.appDisplayName).font(Theme.mono(13, weight: .bold)).foregroundColor(Theme.accent)
                if !settings.companyName.isEmpty {
                    Text("·").foregroundColor(Theme.textDim).font(Theme.monoTiny)
                    Text(settings.companyName).font(Theme.mono(9)).foregroundColor(Theme.textDim)
                }
            }

            // 뷰 모드 전환 (항상 보이도록 앱 이름 바로 옆에 배치)
            HStack(spacing: 1) {
                viewModeButton(icon: "rectangle.split.1x2", mode: .split, label: "분할")
                viewModeButton(icon: "building.2", mode: .office, label: "오피스")
                viewModeButton(icon: "person.2.fill", mode: .strip, label: "스트립")
                viewModeButton(icon: "terminal", mode: .terminal, label: "터미널")
            }
            .background(RoundedRectangle(cornerRadius: 5).fill(Theme.bgSurface))
            .overlay(RoundedRectangle(cornerRadius: 5).stroke(Theme.border.opacity(0.3), lineWidth: 0.5))

            Spacer()

            if updater.hasUpdate {
                Button(action: { showUpdateSheet = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.circle.fill").font(.system(size: Theme.iconSize(10))).foregroundColor(Theme.green)
                        Text("v\(updater.latestVersion)").font(Theme.mono(9, weight: .bold)).foregroundColor(Theme.green)
                    }
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(Theme.green.opacity(0.1)).cornerRadius(5)
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(Theme.green.opacity(0.3), lineWidth: 1))
                }.buttonStyle(.plain).help("업데이트 가능")
            }

            if ClaudeInstallChecker.shared.isInstalled {
                Text("Claude \(ClaudeInstallChecker.shared.version)")
                    .font(Theme.monoTiny).foregroundColor(Theme.textDim)
            }

            if manager.totalTokensUsed > 0 {
                HStack(spacing: 5) {
                    Image(systemName: "bolt.fill").font(Theme.monoTiny).foregroundColor(Theme.yellow)
                    Text(fmtTok(manager.totalTokensUsed))
                        .font(Theme.mono(11, weight: .medium)).foregroundColor(Theme.textSecondary)
                }
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Theme.bgSurface).cornerRadius(5)
            }

            let level = AchievementManager.shared.currentLevel
            Text("Lv.\(level.level) \(level.title)")
                .font(Theme.mono(9, weight: .bold)).foregroundColor(Theme.yellow)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(Theme.yellow.opacity(0.1)).cornerRadius(3)

            // 오피스 별도 창 열기 (듀얼 모니터)
            Button(action: { openOfficeWindow() }) {
                HStack(spacing: 4) {
                    Image(systemName: "rectangle.on.rectangle")
                        .font(.system(size: 11, weight: .medium))
                    Text("분리")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                }
                .foregroundColor(Theme.textDim)
                .padding(.horizontal, 9).padding(.vertical, 5)
                .background(RoundedRectangle(cornerRadius: 5).fill(Theme.bgSurface))
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(Theme.border.opacity(0.3), lineWidth: 0.5))
            }
            .buttonStyle(.plain)
            .help("오피스를 별도 창으로 분리 (듀얼 모니터)")

            Button(action: { showBugReport = true }) {
                Image(systemName: "ladybug.fill").font(.system(size: 13))
                    .foregroundColor(Theme.textDim).padding(6)
            }.buttonStyle(.plain).help("버그 신고")

            Button(action: { showSettings = true }) {
                Image(systemName: "gearshape.fill").font(.system(size: 13))
                    .foregroundColor(Theme.textDim).padding(6)
            }.buttonStyle(.plain).help("Settings")

            Button(action: { manager.refresh() }) {
                Image(systemName: "arrow.clockwise").font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Theme.textDim).padding(6)
            }.buttonStyle(.plain).help("Cmd+R")

            Text("\(manager.userVisibleTabCount)")
                .font(Theme.mono(11, weight: .bold)).foregroundColor(Theme.textDim)
                .padding(.horizontal, 6).padding(.vertical, 3)
                .background(Theme.bgSurface).cornerRadius(4)
        }
        .padding(.horizontal, 14).frame(height: 36)
        .background(Theme.bgCard)
        .overlay(Rectangle().fill(Theme.border).frame(height: 1), alignment: .bottom)
    }

    // MARK: - Status Bar

    private var activeTabCount: Int { manager.userVisibleTabs.lazy.filter(\.isRunning).count }

    private var statusBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 4) {
                Circle().fill(Theme.green).frame(width: 4, height: 4)
                Text("\(activeTabCount) active")
                    .font(Theme.monoSmall).foregroundColor(Theme.textSecondary)
            }

            Spacer()

            Text("Cmd+R refresh · Cmd+T new · Cmd+1-9 switch")
                .font(Theme.monoTiny).foregroundColor(Theme.textDim.opacity(0.6))
        }
        .padding(.horizontal, 14).frame(height: 24)
        .background(Theme.bgCard)
        .overlay(Rectangle().fill(Theme.textDim.opacity(0.3)).frame(height: 1), alignment: .top)
    }

    private func fmtTok(_ c: Int) -> String { c >= 1000 ? String(format: "%.1fk", Double(c)/1000) : "\(c)" }
}

// ═══════════════════════════════════════════════════════
// MARK: - Bug Report View
// ═══════════════════════════════════════════════════════

struct BugReportView: View {
    @Environment(\.dismiss) var dismiss
    @State private var title = ""
    @State private var description = ""
    @State private var screenshotImage: NSImage?
    @State private var isSending = false
    @State private var sent = false

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "ladybug.fill").font(.system(size: Theme.iconSize(16))).foregroundColor(Theme.red)
                Text("버그 신고").font(Theme.mono(14, weight: .bold)).foregroundColor(Theme.textPrimary)
                Spacer()
            }

            if sent {
                // Success
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: Theme.iconSize(36))).foregroundColor(Theme.green)
                    Text("전송 완료!").font(Theme.mono(13, weight: .bold)).foregroundColor(Theme.green)
                    Text("소중한 피드백 감사합니다.").font(Theme.monoSmall).foregroundColor(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 30)
            } else {
                // Title
                VStack(alignment: .leading, spacing: 4) {
                    Text("제목").font(Theme.mono(9, weight: .bold)).foregroundColor(Theme.textDim)
                    TextField("어떤 문제가 발생했나요?", text: $title)
                        .textFieldStyle(.roundedBorder).font(Theme.monoSmall)
                }

                // Description
                VStack(alignment: .leading, spacing: 4) {
                    Text("상세 설명").font(Theme.mono(9, weight: .bold)).foregroundColor(Theme.textDim)
                    TextEditor(text: $description)
                        .font(Theme.monoSmall).foregroundColor(Theme.textPrimary)
                        .frame(height: 100)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.border, lineWidth: 0.5))
                }

                // Screenshot
                VStack(alignment: .leading, spacing: 4) {
                    Text("스크린샷 (선택)").font(Theme.mono(9, weight: .bold)).foregroundColor(Theme.textDim)

                    HStack(spacing: 8) {
                        Button(action: captureScreenshot) {
                            HStack(spacing: 4) {
                                Image(systemName: "camera.fill").font(Theme.monoSmall)
                                Text("현재 화면 캡처").font(Theme.monoSmall)
                            }
                            .foregroundColor(Theme.accent)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Theme.accent.opacity(0.08))
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.accent.opacity(0.2), lineWidth: 0.5)))
                        }.buttonStyle(.plain)

                        Button(action: pickImage) {
                            HStack(spacing: 4) {
                                Image(systemName: "photo").font(Theme.monoSmall)
                                Text("파일 선택").font(Theme.monoSmall)
                            }
                            .foregroundColor(Theme.textSecondary)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Theme.bgSurface)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.border, lineWidth: 0.5)))
                        }.buttonStyle(.plain)

                        Spacer()

                        if screenshotImage != nil {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill").font(Theme.monoSmall).foregroundColor(Theme.green)
                                Text("첨부됨").font(Theme.monoSmall).foregroundColor(Theme.green)
                                Button(action: { screenshotImage = nil }) {
                                    Image(systemName: "xmark.circle.fill").font(Theme.monoSmall).foregroundColor(Theme.textDim)
                                }.buttonStyle(.plain)
                            }
                        }
                    }

                    // Preview
                    if let img = screenshotImage {
                        Image(nsImage: img)
                            .resizable().aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 100)
                            .cornerRadius(6)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.border, lineWidth: 0.5))
                    }
                }
            }

            // Buttons
            HStack {
                Button("닫기") { dismiss() }.keyboardShortcut(.escape)
                Spacer()
                if !sent {
                    Button(action: sendReport) {
                        HStack(spacing: 4) {
                            if isSending { ProgressView().scaleEffect(0.6) }
                            else { Image(systemName: "paperplane.fill").font(Theme.monoSmall) }
                            Text("보내기").font(Theme.mono(11, weight: .medium))
                        }
                        .foregroundColor(Theme.textOnAccent)
                        .padding(.horizontal, 16).padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 6).fill(title.isEmpty ? Theme.textDim : Theme.accent))
                    }
                    .buttonStyle(.plain).keyboardShortcut(.return)
                    .disabled(title.isEmpty || isSending)
                }
            }
        }
        .padding(24).frame(width: 460)
        .background(Theme.bgCard)
    }

    private func captureScreenshot() {
        guard let window = NSApp.mainWindow,
              let contentView = window.contentView else { return }

        let bounds = contentView.bounds
        guard let bitmap = contentView.bitmapImageRepForCachingDisplay(in: bounds) else { return }
        contentView.cacheDisplay(in: bounds, to: bitmap)

        let image = NSImage(size: bounds.size)
        image.addRepresentation(bitmap)
        screenshotImage = image
    }

    private func pickImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .tiff]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url, let img = NSImage(contentsOf: url) {
            screenshotImage = img
        }
    }

    private func sendReport() {
        isSending = true

        // 스크린샷을 임시 파일로 저장
        var attachmentPath: String?
        if let img = screenshotImage, let tiff = img.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiff),
           let png = bitmap.representation(using: .png, properties: [:]) {
            let tmpURL = FileManager.default.temporaryDirectory.appendingPathComponent("workman_bug_\(Int(Date().timeIntervalSince1970)).png")
            try? png.write(to: tmpURL)
            attachmentPath = tmpURL.path
        }

        // 시스템 정보 수집
        let sysInfo = """
        App: WorkMan
        macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)
        Claude: \(ClaudeInstallChecker.shared.version)
        Sessions: \(SessionManager.shared.userVisibleTabCount)
        Theme: \(AppSettings.shared.isDarkMode ? "Dark" : "Light")
        Font Scale: \(AppSettings.shared.fontSizeScale)
        """

        let body = """
        [버그 제목] \(title)

        [상세 설명]
        \(description)

        [시스템 정보]
        \(sysInfo)
        """

        // mailto URL (이미지는 첨부 안내)
        let mailBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let mailSubject = "[WorkMan Bug] \(title)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let mailURL = "mailto:goodjunha@gmail.com?subject=\(mailSubject)&body=\(mailBody)"

        if let url = URL(string: mailURL) {
            NSWorkspace.shared.open(url)
        }

        // 스크린샷이 있으면 Finder에서 열어서 수동 첨부 안내
        if let path = attachmentPath {
            NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isSending = false
            sent = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { dismiss() }
        }
    }
}
