import SwiftUI

struct MainView: View {
    @EnvironmentObject var manager: SessionManager
    @ObservedObject var settings = AppSettings.shared
    @State private var sidebarWidth: CGFloat = 230
    @State private var showSettings = false
    @State private var showClaudeNotInstalledAlert = false
    @State private var showBugReport = false
    @State private var showUpdateSheet = false
    @ObservedObject private var updater = UpdateChecker.shared

    var body: some View {
        VStack(spacing: 0) {
            titleBar

            HStack(spacing: 0) {
                SidebarView()
                    .frame(width: sidebarWidth)

                Rectangle().fill(Theme.border).frame(width: 1)

                VStack(spacing: 0) {
                    PixelStripView()
                        .frame(height: 110)
                    Rectangle().fill(Theme.border).frame(height: 1)
                    TerminalAreaView()
                }
            }

            statusBar
        }
        .background(Theme.bg)
        .overlay(alignment: .topTrailing) {
            if let ach = AchievementManager.shared.recentUnlock {
                AchievementToastView(achievement: ach)
                    .padding(.top, 44)
                    .padding(.trailing, 16)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                    .animation(.spring(response: 0.4, dampingFraction: 0.75), value: ach.id)
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
        .onAppear {
            if manager.tabs.isEmpty {
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
            if let i = notif.object as? Int, i >= 1, i <= manager.tabs.count { manager.selectTab(manager.tabs[i-1].id) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .workmanExportLog)) { _ in exportActiveLog() }
        .onReceive(NotificationCenter.default.publisher(for: .workmanClaudeNotInstalled)) { _ in
            showClaudeNotInstalledAlert = true
        }
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

            Spacer()

            if updater.hasUpdate {
                Button(action: { showUpdateSheet = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.circle.fill").font(.system(size: 10)).foregroundColor(Theme.green)
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

            Button(action: { showBugReport = true }) {
                Image(systemName: "ladybug.fill").font(Theme.monoSmall)
                    .foregroundColor(Theme.textDim).padding(4)
            }.buttonStyle(.plain).help("버그 신고")

            Button(action: { showSettings = true }) {
                Image(systemName: "gearshape.fill").font(Theme.monoSmall)
                    .foregroundColor(Theme.textDim).padding(4)
            }.buttonStyle(.plain).help("Settings")

            Button(action: { manager.refresh() }) {
                Image(systemName: "arrow.clockwise").font(Theme.mono(11, weight: .semibold))
                    .foregroundColor(Theme.textDim).padding(4)
            }.buttonStyle(.plain).help("Cmd+R")

            Text("\(manager.tabs.count)")
                .font(Theme.mono(10, weight: .bold)).foregroundColor(Theme.textDim)
                .padding(.horizontal, 5).padding(.vertical, 2)
                .background(Theme.bgSurface).cornerRadius(3)
        }
        .padding(.horizontal, 14).frame(height: 36)
        .background(Theme.bgCard)
        .overlay(Rectangle().fill(Theme.border).frame(height: 1), alignment: .bottom)
    }

    // MARK: - Status Bar

    private var statusBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 4) {
                Circle().fill(Theme.green).frame(width: 4, height: 4)
                Text("\(manager.tabs.filter { $0.isRunning }.count) active")
                    .font(Theme.monoSmall).foregroundColor(Theme.textSecondary)
            }

            if let top = manager.tabs.max(by: { $0.tokensUsed < $1.tokensUsed }), top.tokensUsed > 0 {
                Text("·").foregroundColor(Theme.textDim).font(Theme.monoTiny)
                HStack(spacing: 3) {
                    RoundedRectangle(cornerRadius: 1).fill(top.workerColor).frame(width: 2, height: 8)
                    Text("\(top.workerName) \(fmtTok(top.tokensUsed))")
                        .font(Theme.monoSmall).foregroundColor(Theme.textSecondary)
                }
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
                Image(systemName: "ladybug.fill").font(.system(size: 16)).foregroundColor(Theme.red)
                Text("버그 신고").font(Theme.mono(14, weight: .bold)).foregroundColor(Theme.textPrimary)
                Spacer()
            }

            if sent {
                // Success
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 36)).foregroundColor(Theme.green)
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
                        .foregroundColor(.white)
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
        guard let window = NSApp.mainWindow else { return }
        if let cgImage = CGWindowListCreateImage(
            window.frame,
            .optionIncludingWindow,
            CGWindowID(window.windowNumber),
            [.boundsIgnoreFraming]
        ) {
            screenshotImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        }
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
        Sessions: \(SessionManager.shared.tabs.count)
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
