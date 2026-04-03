import SwiftUI
import DesignSystem
import DofficeKit

extension MainView {

    // MARK: - Status Bar

    var processingTabCount: Int {
        manager.userVisibleTabs.lazy.filter { $0.statusPresentation.category == .processing }.count
    }

    var activeTabCount: Int {
        manager.userVisibleTabs.lazy.filter { $0.statusPresentation.category == .active }.count
    }

    var attentionTabCount: Int {
        manager.userVisibleTabs.lazy.filter { $0.statusPresentation.category == .attention }.count
    }

    var completedTabCount: Int {
        manager.userVisibleTabs.lazy.filter { $0.statusPresentation.category == .completed }.count
    }

    var statusBar: some View {
        HStack(spacing: 10) {
            if manager.userVisibleTabs.isEmpty {
                HStack(spacing: 4) {
                    Circle().fill(Theme.textDim.opacity(0.7)).frame(width: 4, height: 4)
                    Text(NSLocalizedString("main.no.sessions", comment: ""))
                        .font(Theme.monoSmall)
                        .foregroundColor(Theme.textSecondary)
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        if activeTabCount > 0 {
                            AppStatusBadge(title: String(format: NSLocalizedString("main.active.count", comment: ""), activeTabCount), symbol: "bolt.circle.fill", tint: Theme.green)
                        }
                        if processingTabCount > 0 {
                            AppStatusBadge(title: String(format: NSLocalizedString("main.processing.count", comment: ""), processingTabCount), symbol: "gearshape.2.fill", tint: Theme.accent)
                        }
                        if attentionTabCount > 0 {
                            Button(action: { showActionCenter = true }) {
                                AppStatusBadge(title: String(format: NSLocalizedString("main.attention.count", comment: ""), attentionTabCount), symbol: "exclamationmark.triangle.fill", tint: Theme.red)
                            }.buttonStyle(.plain)
                        }
                        if completedTabCount > 0 {
                            Button(action: { showActionCenter = true }) {
                                AppStatusBadge(title: String(format: NSLocalizedString("main.completed.count", comment: ""), completedTabCount), symbol: "checkmark.circle.fill", tint: Theme.green)
                            }.buttonStyle(.plain)
                        }
                    }
                }
            }

            // 플러그인 패널 탭
            if !pluginHost.panels.isEmpty {
                Rectangle().fill(Theme.border).frame(width: 1, height: 14)
                ForEach(pluginHost.panels) { panel in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            activePluginPanelId = activePluginPanelId == panel.id ? nil : panel.id
                        }
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: panel.icon)
                                .font(.system(size: Theme.chromeIconSize(9), weight: .medium))
                            Text(panel.title)
                                .font(Theme.chrome(8))
                        }
                        .foregroundColor(activePluginPanelId == panel.id ? Theme.accent : Theme.textDim)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: 4).fill(activePluginPanelId == panel.id ? Theme.accent.opacity(0.1) : Color.clear))
                    }.buttonStyle(.plain)
                }
            }

            // 플러그인 상태바 위젯
            if !pluginHost.statusBarItems.isEmpty {
                Rectangle().fill(Theme.border).frame(width: 1, height: 14)
                ForEach(pluginHost.statusBarItems) { item in
                    HStack(spacing: 3) {
                        if !item.icon.isEmpty {
                            Image(systemName: item.icon)
                                .font(.system(size: Theme.chromeIconSize(8)))
                        }
                        Text(item.text)
                            .font(Theme.chrome(8))
                    }
                    .foregroundColor(Theme.textSecondary)
                }
            }

            Spacer()

            Text("⌘P palette · ⌘T new · ⌘J center · ⌘1-9 switch · ⌘K clear")
                .font(Theme.chrome(8)).foregroundColor(Theme.textMuted)
                .lineLimit(1).fixedSize(horizontal: false, vertical: true)
                .layoutPriority(-1)
        }
        .padding(.horizontal, Theme.sp3).frame(height: 26)
        .background(Theme.bg)
        .overlay(alignment: .top) { Rectangle().fill(Theme.border).frame(height: 1) }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(NSLocalizedString("main.a11y.session.summary", comment: ""))
        .accessibilityValue(statusBarAccessibilitySummary)
    }

    func pluginPanelHeader(_ panel: PluginHost.LoadedPanel) -> some View {
        HStack(spacing: 8) {
            Image(systemName: panel.icon)
                .font(.system(size: Theme.iconSize(12), weight: .bold))
                .foregroundStyle(Theme.accentBackground)
            Text(panel.title)
                .font(Theme.mono(11, weight: .bold))
                .foregroundColor(Theme.textPrimary)
            Text("by \(panel.pluginName)")
                .font(Theme.mono(8))
                .foregroundColor(Theme.textDim)
            Spacer()
            Button(action: { withAnimation { activePluginPanelId = nil } }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(Theme.textDim)
            }.buttonStyle(.plain)
        }
        .padding(.horizontal, Theme.sp3).padding(.vertical, 6)
        .background(Theme.bgCard)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.border).frame(height: 1) }
    }

    var statusBarAccessibilitySummary: String {
        if manager.userVisibleTabs.isEmpty {
            return NSLocalizedString("main.a11y.no.active", comment: "")
        }

        return [
            activeTabCount > 0 ? String(format: NSLocalizedString("main.a11y.active", comment: ""), activeTabCount) : nil,
            processingTabCount > 0 ? String(format: NSLocalizedString("main.a11y.processing", comment: ""), processingTabCount) : nil,
            attentionTabCount > 0 ? String(format: NSLocalizedString("main.a11y.attention", comment: ""), attentionTabCount) : nil,
            completedTabCount > 0 ? String(format: NSLocalizedString("main.a11y.completed", comment: ""), completedTabCount) : nil
        ]
        .compactMap { $0 }
        .joined(separator: ", ")
    }
}
