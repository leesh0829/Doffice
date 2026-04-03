import SwiftUI
import AppKit
import DesignSystem
import DofficeKit

extension SidebarView {
    var filteredProjectGroups: [SessionManager.ProjectGroup] {
        let loweredQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        let groups = manager.projectGroups.compactMap { group -> SessionManager.ProjectGroup? in
            let matchingTabs = group.tabs
                .filter { tab in
                    matchesQuery(tab, loweredQuery: loweredQuery) && matchesFilter(tab)
                }
                .sorted(by: tabSortComparator(lhs:rhs:))

            guard !matchingTabs.isEmpty else { return nil }
            return SessionManager.ProjectGroup(
                id: group.id,
                projectName: group.projectName,
                tabs: matchingTabs,
                hasActiveTab: matchingTabs.contains(where: { $0.id == manager.activeTabId })
            )
        }

        return groups.sorted { lhs, rhs in
            compareGroups(lhs, rhs)
        }
    }

    func matchesQuery(_ tab: TerminalTab, loweredQuery: String) -> Bool {
        guard !loweredQuery.isEmpty else { return true }
        return tab.sidebarSearchTokens.contains(loweredQuery)
    }

    func matchesFilter(_ tab: TerminalTab) -> Bool {
        switch statusFilter {
        case .all:
            return true
        case .active:
            return tab.statusPresentation.category == .active || tab.statusPresentation.category == .processing
        case .processing:
            return tab.statusPresentation.category == .processing
        case .completed:
            return tab.statusPresentation.category == .completed
        case .attention:
            return tab.statusPresentation.category == .attention
        }
    }

    func countForFilter(_ filter: SessionStatusFilter) -> Int {
        manager.userVisibleTabs.filter { tab in
            switch filter {
            case .all:
                return true
            case .active:
                return tab.statusPresentation.category == .active || tab.statusPresentation.category == .processing
            case .processing:
                return tab.statusPresentation.category == .processing
            case .completed:
                return tab.statusPresentation.category == .completed
            case .attention:
                return tab.statusPresentation.category == .attention
            }
        }.count
    }

    func tabSortComparator(lhs: TerminalTab, rhs: TerminalTab) -> Bool {
        switch sortOption {
        case .recent:
            if lhs.lastActivityTime != rhs.lastActivityTime { return lhs.lastActivityTime > rhs.lastActivityTime }
        case .name:
            let nameComparison = lhs.projectName.localizedCaseInsensitiveCompare(rhs.projectName)
            if nameComparison != .orderedSame { return nameComparison == .orderedAscending }
        case .tokens:
            if lhs.tokensUsed != rhs.tokensUsed { return lhs.tokensUsed > rhs.tokensUsed }
        case .status:
            if lhs.statusPresentation.sortPriority != rhs.statusPresentation.sortPriority {
                return lhs.statusPresentation.sortPriority < rhs.statusPresentation.sortPriority
            }
        }

        if lhs.projectName != rhs.projectName {
            return lhs.projectName.localizedCaseInsensitiveCompare(rhs.projectName) == .orderedAscending
        }
        return lhs.workerName.localizedCaseInsensitiveCompare(rhs.workerName) == .orderedAscending
    }

    func compareGroups(_ lhs: SessionManager.ProjectGroup, _ rhs: SessionManager.ProjectGroup) -> Bool {
        switch sortOption {
        case .recent:
            let lhsDate = lhs.tabs.map(\.lastActivityTime).max() ?? .distantPast
            let rhsDate = rhs.tabs.map(\.lastActivityTime).max() ?? .distantPast
            if lhsDate != rhsDate { return lhsDate > rhsDate }
        case .name:
            let comparison = lhs.projectName.localizedCaseInsensitiveCompare(rhs.projectName)
            if comparison != .orderedSame { return comparison == .orderedAscending }
        case .tokens:
            let lhsTokens = lhs.tabs.reduce(0) { $0 + $1.tokensUsed }
            let rhsTokens = rhs.tabs.reduce(0) { $0 + $1.tokensUsed }
            if lhsTokens != rhsTokens { return lhsTokens > rhsTokens }
        case .status:
            let lhsPriority = lhs.tabs.map(\.statusPresentation.sortPriority).min() ?? .max
            let rhsPriority = rhs.tabs.map(\.statusPresentation.sortPriority).min() ?? .max
            if lhsPriority != rhsPriority { return lhsPriority < rhsPriority }
        }

        return lhs.projectName.localizedCaseInsensitiveCompare(rhs.projectName) == .orderedAscending
    }
}
