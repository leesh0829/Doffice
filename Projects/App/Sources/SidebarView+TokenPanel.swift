import SwiftUI
import AppKit
import DesignSystem
import DofficeKit

extension SidebarView {
    var tokenUsagePanel: some View {
        sidebarPanel(title: "Usage", icon: "chart.bar.fill", tint: Theme.cyan) {
            VStack(spacing: 10) {
                VStack(spacing: 4) {
                    HStack {
                        Text(NSLocalizedString("misc.today", comment: "")).font(Theme.chrome(9, weight: .medium)).foregroundColor(Theme.textSecondary)
                        Spacer()
                        Text(tracker.formatTokens(tracker.todayTokens))
                            .font(Theme.chrome(10, weight: .bold)).foregroundColor(Theme.textPrimary)
                        Text("/").font(Theme.chrome(8)).foregroundColor(Theme.textDim)
                        Text(tracker.formatTokens(tracker.dailyTokenLimit))
                            .font(Theme.chrome(9)).foregroundColor(Theme.textDim)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2).fill(Theme.bg).frame(height: 4)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(dailyBarColor)
                                .frame(width: max(0, geo.size.width * min(1, tracker.dailyUsagePercent)), height: 4)
                        }
                    }.frame(height: 4)
                    HStack {
                        Text(NSLocalizedString("misc.remaining", comment: "")).font(Theme.chrome(7)).foregroundColor(Theme.textDim)
                        Spacer()
                        Text(tracker.formatTokens(tracker.dailyRemaining))
                            .font(Theme.chrome(8, weight: .semibold))
                            .foregroundColor(tracker.dailyUsagePercent > 0.8 ? Theme.red : Theme.green)
                    }
                    if tracker.todayCost > 0 {
                        HStack {
                            Text(NSLocalizedString("misc.cost", comment: "")).font(Theme.chrome(7)).foregroundColor(Theme.textDim)
                            Spacer()
                            Text(String(format: "$%.4f", tracker.todayCost))
                                .font(Theme.chrome(8)).foregroundColor(Theme.yellow)
                        }
                    }
                }

                Divider().overlay(Theme.border.opacity(0.6))

                VStack(spacing: 4) {
                    HStack {
                        Text(NSLocalizedString("misc.thisweek", comment: "")).font(Theme.chrome(9, weight: .medium)).foregroundColor(Theme.textSecondary)
                        Spacer()
                        Text(tracker.formatTokens(tracker.weekTokens))
                            .font(Theme.chrome(10, weight: .bold)).foregroundColor(Theme.textPrimary)
                        Text("/").font(Theme.chrome(8)).foregroundColor(Theme.textDim)
                        Text(tracker.formatTokens(tracker.weeklyTokenLimit))
                            .font(Theme.chrome(9)).foregroundColor(Theme.textDim)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2).fill(Theme.bg).frame(height: 4)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(weeklyBarColor)
                                .frame(width: max(0, geo.size.width * min(1, tracker.weeklyUsagePercent)), height: 4)
                        }
                    }.frame(height: 4)
                    HStack {
                        Text(NSLocalizedString("misc.remaining", comment: "")).font(Theme.chrome(7)).foregroundColor(Theme.textDim)
                        Spacer()
                        Text(tracker.formatTokens(tracker.weeklyRemaining))
                            .font(Theme.chrome(8, weight: .semibold))
                            .foregroundColor(tracker.weeklyUsagePercent > 0.8 ? Theme.red : Theme.green)
                    }
                    if tracker.weekCost > 0 {
                        HStack {
                            Text(NSLocalizedString("misc.cost", comment: "")).font(Theme.chrome(7)).foregroundColor(Theme.textDim)
                            Spacer()
                            Text(String(format: "$%.4f", tracker.weekCost))
                                .font(Theme.chrome(8)).foregroundColor(Theme.yellow)
                        }
                    }
                }

                // 결제 기간
                if AppSettings.shared.billingDay > 0 {
                    Divider().overlay(Theme.border.opacity(0.6))
                    VStack(spacing: 4) {
                        HStack {
                            Text(NSLocalizedString("sidebar.billing.period", comment: "")).font(Theme.chrome(9, weight: .medium)).foregroundColor(Theme.textSecondary)
                            Spacer()
                            Text(tracker.billingPeriodLabel).font(Theme.chrome(8)).foregroundColor(Theme.textDim)
                        }
                        HStack {
                            Text(NSLocalizedString("sidebar.tokens", comment: "")).font(Theme.chrome(7)).foregroundColor(Theme.textDim)
                            Spacer()
                            Text(tracker.formatTokens(tracker.billingPeriodTokens))
                                .font(Theme.chrome(10, weight: .bold)).foregroundColor(Theme.orange)
                        }
                        HStack {
                            Text(NSLocalizedString("misc.cost", comment: "")).font(Theme.chrome(7)).foregroundColor(Theme.textDim)
                            Spacer()
                            Text(String(format: "$%.4f", tracker.billingPeriodCost))
                                .font(Theme.chrome(8)).foregroundColor(Theme.yellow)
                        }
                    }
                }

                if manager.totalTokensUsed > 0 {
                    Divider().overlay(Theme.border.opacity(0.6))
                    HStack {
                        Text(NSLocalizedString("sidebar.current.session", comment: "")).font(Theme.chrome(8, weight: .medium)).foregroundColor(Theme.textDim)
                        Spacer()
                        let (totalIn, totalOut) = manager.userVisibleTabs.reduce((0, 0)) { ($0.0 + $1.inputTokensUsed, $0.1 + $1.outputTokensUsed) }
                        if totalIn > 0 || totalOut > 0 {
                            HStack(spacing: 4) {
                                Text("In").font(Theme.chrome(7)).foregroundColor(Theme.textDim)
                                Text(totalIn.tokenFormatted).font(Theme.chrome(8, weight: .semibold)).foregroundStyle(Theme.accentBackground)
                                Text("Out").font(Theme.chrome(7)).foregroundColor(Theme.textDim)
                                Text(totalOut.tokenFormatted).font(Theme.chrome(8, weight: .semibold)).foregroundColor(Theme.green)
                            }
                        } else {
                            Text(manager.totalTokensUsed.tokenFormatted).font(Theme.chrome(8, weight: .semibold)).foregroundColor(Theme.textPrimary)
                        }
                    }
                }
            }
        }
    }

    var dailyBarColor: Color {
        if tracker.dailyUsagePercent > 0.9 { return Theme.red }
        if tracker.dailyUsagePercent > 0.7 { return Theme.yellow }
        return Theme.green
    }

    var weeklyBarColor: Color {
        if tracker.weeklyUsagePercent > 0.9 { return Theme.red }
        if tracker.weeklyUsagePercent > 0.7 { return Theme.yellow }
        return Theme.cyan
    }

    var tokenPanel: some View {
        sidebarPanel(title: "Tokens", icon: "bolt.fill", tint: Theme.yellow) {
            VStack(spacing: 8) {
                HStack {
                    Text(NSLocalizedString("sidebar.total.usage", comment: ""))
                        .font(Theme.chrome(8, weight: .medium))
                        .foregroundColor(Theme.textDim)
                    Spacer()
                    Text(manager.totalTokensUsed.tokenFormatted)
                        .font(Theme.chrome(12, weight: .semibold)).foregroundColor(Theme.textPrimary)
                }
                ForEach(manager.userVisibleTabs.sorted(by: { $0.tokensUsed > $1.tokensUsed })) { tab in
                    if tab.tokensUsed > 0 {
                        HStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 1).fill(tab.workerColor).frame(width: 3, height: 12)
                            Text(tab.workerName).font(Theme.chrome(9)).foregroundColor(Theme.textSecondary)
                            Spacer()
                            Text(tab.tokensUsed.tokenFormatted).font(Theme.chrome(9)).foregroundColor(Theme.textDim)
                            GeometryReader { geo in
                                let ratio = tab.tokenLimit > 0
                                    ? min(1.0, CGFloat(tab.tokensUsed) / CGFloat(tab.tokenLimit))
                                    : min(1.0, CGFloat(tab.tokensUsed) / CGFloat(max(1, manager.totalTokensUsed)))
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 2).fill(Theme.bgSurface)
                                    RoundedRectangle(cornerRadius: 2).fill(tab.workerColor.opacity(0.5))
                                        .frame(width: max(2, geo.size.width * ratio))
                                }
                            }.frame(width: 40, height: 3)
                        }
                    }
                }
            }
        }
    }

}
