import SwiftUI
import Darwin
import AppKit
import DesignSystem

extension SessionManager {
    // MARK: - Session Search

    public struct SearchResult: Identifiable {
        public let id = UUID()
        public let tabId: String
        public let tabName: String
        public let projectPath: String
        public let blockId: UUID
        public let blockContent: String
        public let blockType: StreamBlock.BlockType
        public let timestamp: Date
        public let matchRange: Range<String.Index>
    }

    public var searchResults: [SearchResult] { cachedSearchResults }

    internal func debounceSearchResults() {
        searchDebounceTimer?.invalidate()
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else {
            cachedSearchResults = []
            return
        }
        searchDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.recomputeSearchResults(query: query)
        }
    }

    internal func recomputeSearchResults(query: String) {
        var results: [SearchResult] = []
        for tab in userVisibleTabs {
            let tabName = tab.projectName.isEmpty ? tab.workerName : tab.projectName
            for block in tab.blocks {
                let content = block.content
                guard !content.isEmpty else { continue }
                let lowered = content.lowercased()
                if let range = lowered.range(of: query) {
                    results.append(SearchResult(
                        tabId: tab.id,
                        tabName: tabName,
                        projectPath: tab.projectPath,
                        blockId: block.id,
                        blockContent: content,
                        blockType: block.blockType,
                        timestamp: block.timestamp,
                        matchRange: range
                    ))
                }
            }
        }
        cachedSearchResults = results
    }

    public func navigateToSearchResult(_ result: SearchResult) {
        selectTab(result.tabId)
        // Post notification so TerminalAreaView can scroll to the block
        NotificationCenter.default.post(
            name: .dofficeScrollToBlock,
            object: result.blockId
        )
    }
}
