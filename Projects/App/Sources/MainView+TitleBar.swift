import SwiftUI
import DesignSystem
import DofficeKit

extension MainView {

    // MARK: - Title Bar

    // 타이틀바 공용: 아이콘 버튼
    func chromeIconButton(_ icon: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: Theme.chromeIconSize(12), weight: .medium))
                .foregroundColor(Theme.textDim)
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .help(help)
    }

    // 타이틀바 공용: 작은 pill 배지
    func chromePill(_ text: String, color: Color) -> some View {
        Text(text)
            .font(Theme.chrome(9, weight: .medium))
            .foregroundColor(color)
            .padding(.horizontal, Theme.sp2)
            .padding(.vertical, 2)
            .background(RoundedRectangle(cornerRadius: Theme.cornerSmall).fill(Theme.accentBg(color)))
            .overlay(RoundedRectangle(cornerRadius: Theme.cornerSmall).stroke(Theme.accentBorder(color), lineWidth: 1))
    }

    var titleBar: some View {
        HStack(spacing: Theme.sp2) {
            Color.clear.frame(width: 68, height: 1)

            chromeIconButton(sidebarCollapsed ? "sidebar.left" : "sidebar.leading", help: sidebarCollapsed ? NSLocalizedString("main.sidebar.open", comment: "") : NSLocalizedString("main.sidebar.close", comment: "")) {
                withAnimation(.easeInOut(duration: 0.2)) { sidebarCollapsed.toggle() }
            }

            // 앱 이름
            HStack(spacing: 4) {
                Text(settings.appDisplayName)
                    .font(Theme.mono(13, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                if !settings.companyName.isEmpty {
                    Text("·").foregroundColor(Theme.textMuted)
                    Text(settings.companyName).font(Theme.mono(9)).foregroundColor(Theme.textDim)
                }
            }

            // 뷰 모드 전환
            HStack(spacing: 0) {
                viewModeButton(icon: "rectangle.split.1x2", mode: .split, label: NSLocalizedString("view.split", comment: ""))
                viewModeButton(icon: "building.2", mode: .office, label: NSLocalizedString("view.office", comment: ""))
                viewModeButton(icon: "person.2.fill", mode: .strip, label: NSLocalizedString("view.strip", comment: ""))
                viewModeButton(icon: "terminal", mode: .terminal, label: NSLocalizedString("view.terminal", comment: ""))
            }
            .fixedSize(horizontal: true, vertical: true)
            .background(RoundedRectangle(cornerRadius: Theme.cornerMedium).fill(Theme.bgSurface))
            .overlay(RoundedRectangle(cornerRadius: Theme.cornerMedium).stroke(Theme.border, lineWidth: 1))

            Menu {
                ForEach(settings.layoutPresets) { preset in
                    Button(action: {
                        settings.applyPreset(preset)
                        viewModeRaw = preset.viewModeRaw
                    }) {
                        Text(preset.name)
                    }
                }
                Divider()
                Button(NSLocalizedString("main.save.layout", comment: "")) {
                    settings.saveCurrentAsPreset(
                        name: String(format: NSLocalizedString("main.preset.name", comment: ""), settings.layoutPresets.count + 1),
                        viewModeRaw: viewModeRaw,
                        sidebarWidth: Double(sidebarWidth)
                    )
                }
            } label: {
                Image(systemName: "rectangle.3.group")
                    .font(.system(size: Theme.chromeIconSize(11)))
                    .foregroundColor(Theme.textDim)
            }
            .menuStyle(.borderlessButton)
            .frame(width: 28)
            .help(NSLocalizedString("main.layout.preset", comment: ""))

            Spacer()

            // 업데이트 배지
            if updater.hasUpdate {
                Button(action: { showUpdateSheet = true }) {
                    HStack(spacing: 4) {
                        AppStatusDot(color: Theme.green, size: 6)
                        Text("v\(updater.latestVersion)").font(Theme.chrome(9, weight: .medium)).foregroundColor(Theme.green)
                    }
                    .padding(.horizontal, Theme.sp2).padding(.vertical, 3)
                    .background(RoundedRectangle(cornerRadius: Theme.cornerSmall).fill(Theme.accentBg(Theme.green)))
                    .overlay(RoundedRectangle(cornerRadius: Theme.cornerSmall).stroke(Theme.accentBorder(Theme.green), lineWidth: 1))
                }.buttonStyle(.plain).help(NSLocalizedString("main.update.available", comment: ""))
            }

            if ClaudeInstallChecker.shared.isInstalled || CodexInstallChecker.shared.isInstalled {
                Text([
                    ClaudeInstallChecker.shared.isInstalled ? "Claude \(ClaudeInstallChecker.shared.version)" : nil,
                    CodexInstallChecker.shared.isInstalled ? "Codex \(CodexInstallChecker.shared.version)" : nil,
                ].compactMap { $0 }.joined(separator: " · "))
                    .font(Theme.chrome(8)).foregroundColor(Theme.textMuted)
            }

            // 토큰 사용량
            if manager.totalTokensUsed > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "bolt.fill").font(.system(size: 8)).foregroundColor(Theme.yellow)
                    Text(manager.totalTokensUsed.tokenFormatted)
                        .font(Theme.chrome(10, weight: .medium)).foregroundColor(Theme.textSecondary)
                }
                .padding(.horizontal, Theme.sp2).padding(.vertical, 3)
                .background(RoundedRectangle(cornerRadius: Theme.cornerSmall).fill(Theme.bgSurface))
                .overlay(RoundedRectangle(cornerRadius: Theme.cornerSmall).stroke(Theme.border, lineWidth: 1))
            }

            // 레벨
            chromePill("Lv.\(AchievementManager.shared.currentLevel.level)", color: Theme.yellow)

            // 유틸리티 버튼들
            HStack(spacing: 0) {
                chromeIconButton("rectangle.on.rectangle", help: NSLocalizedString("main.office.detach", comment: "")) { openOfficeWindow() }
                chromeIconButton("ladybug.fill", help: NSLocalizedString("main.bug.report", comment: "")) { showBugReport = true }
                chromeIconButton("gearshape.fill", help: NSLocalizedString("settings", comment: "")) { showSettings = true }
                chromeIconButton("arrow.clockwise", help: NSLocalizedString("main.refresh.shortcut", comment: "")) { manager.refresh() }
                chromeIconButton(settings.isLocked ? "lock.fill" : "lock.open", help: NSLocalizedString("main.session.lock", comment: "")) {
                    if settings.lockPIN.isEmpty { settings.isLocked.toggle() } else { settings.isLocked = true }
                }
            }

            // 세션 수
            Text("\(manager.userVisibleTabCount)")
                .font(Theme.chrome(10, weight: .bold)).foregroundColor(Theme.textDim)
                .padding(.horizontal, Theme.sp2).padding(.vertical, 3)
                .background(RoundedRectangle(cornerRadius: Theme.cornerSmall).fill(Theme.bgSurface))
                .overlay(RoundedRectangle(cornerRadius: Theme.cornerSmall).stroke(Theme.border, lineWidth: 1))
        }
        .padding(.horizontal, Theme.sp3).frame(height: Theme.toolbarHeight)
        .background(Theme.bgCard)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.border).frame(height: 1) }
        .padding(.top, -1)
    }

    func viewModeButton(icon: String, mode: ViewMode, label: String) -> some View {
        let isActive = viewMode == mode
        return Button(action: {
            withAnimation(chromeAnimation) {
                viewModeRaw = mode.rawValue
            }
        }) {
            Image(systemName: icon)
                .font(.system(size: Theme.iconSize(11), weight: .medium))
                .foregroundColor(isActive ? Theme.accent : Theme.textDim)
                .frame(width: 30, height: 24)
                .background(isActive ? Theme.accent.opacity(0.12) : .clear)
        }
        .buttonStyle(.plain)
        .help(label)
    }

    func protectedSidebarWidth(totalWidth: CGFloat) -> CGFloat {
        let requestedWidth = max(sidebarWidth, preferredSidebarWidth)
        let safeMaximum = max(minimumSidebarWidth, totalWidth - minimumPrimaryContentWidth)
        return min(requestedWidth, safeMaximum)
    }

    func shouldForceCompactSidebar(totalWidth: CGFloat, sidebarWidth: CGFloat) -> Bool {
        totalWidth < 1240 || sidebarWidth <= 204
    }
}
