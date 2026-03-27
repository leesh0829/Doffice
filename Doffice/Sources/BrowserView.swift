import SwiftUI
import WebKit
import Combine

// ═══════════════════════════════════════════════════════
// MARK: - Browser Tab Model
// ═══════════════════════════════════════════════════════

struct BrowserTab: Identifiable, Equatable {
    let id: UUID
    var url: URL?
    var title: String
    var isLoading: Bool
    var canGoBack: Bool
    var canGoForward: Bool
    var estimatedProgress: Double

    init(
        id: UUID = UUID(),
        url: URL? = nil,
        title: String = "New Tab",
        isLoading: Bool = false,
        canGoBack: Bool = false,
        canGoForward: Bool = false,
        estimatedProgress: Double = 0
    ) {
        self.id = id
        self.url = url
        self.title = title
        self.isLoading = isLoading
        self.canGoBack = canGoBack
        self.canGoForward = canGoForward
        self.estimatedProgress = estimatedProgress
    }

    var displayTitle: String {
        if title.isEmpty || title == "about:blank" { return "New Tab" }
        return title
    }

    var displayURL: String {
        url?.absoluteString ?? "about:blank"
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - History Entry Model
// ═══════════════════════════════════════════════════════

struct BrowserHistoryEntry: Identifiable, Codable, Equatable {
    let id: UUID
    var url: String
    var title: String
    var visitedAt: Date

    init(id: UUID = UUID(), url: String, title: String, visitedAt: Date = Date()) {
        self.id = id
        self.url = url
        self.title = title
        self.visitedAt = visitedAt
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - Saved Tab Model (for persistence)
// ═══════════════════════════════════════════════════════

private struct SavedTab: Codable {
    let urlString: String
    let title: String
}

// ═══════════════════════════════════════════════════════
// MARK: - Bookmark Model
// ═══════════════════════════════════════════════════════

struct BrowserBookmark: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var urlString: String

    init(id: UUID = UUID(), title: String, urlString: String) {
        self.id = id
        self.title = title
        self.urlString = urlString
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - Browser Manager
// ═══════════════════════════════════════════════════════

class BrowserManager: ObservableObject {
    @Published var tabs: [BrowserTab] = []
    @Published var activeTabId: UUID?
    @Published var bookmarks: [BrowserBookmark] = []
    @Published var showBookmarks: Bool = false
    @Published var history: [BrowserHistoryEntry] = []
    @Published var showHistory: Bool = false

    private let bookmarksKey = "browser_bookmarks"
    private let historyKey = "browser_history"
    private let savedTabsKey = "browser_saved_tabs"
    private let maxHistoryEntries = 500
    private var terminationObserver: NSObjectProtocol?
    private var historySaveWorkItem: DispatchWorkItem?

    init() {
        loadBookmarks()
        loadHistory()
        restoreTabs()
        if tabs.isEmpty { createNewTab() }

        // Save tabs and flush pending history when app is about to terminate
        terminationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.historySaveWorkItem?.cancel()
            self?.saveHistory()
            self?.saveTabs()
        }
    }

    deinit {
        if let obs = terminationObserver {
            NotificationCenter.default.removeObserver(obs)
        }
    }

    var activeTab: BrowserTab? {
        tabs.first(where: { $0.id == activeTabId })
    }

    var activeTabIndex: Int? {
        tabs.firstIndex(where: { $0.id == activeTabId })
    }

    // ── Tab Management ──

    @discardableResult
    func createNewTab(url: URL? = nil) -> UUID {
        let tab = BrowserTab(url: url ?? URL(string: "https://www.google.com")!)
        tabs.append(tab)
        activeTabId = tab.id
        return tab.id
    }

    func closeTab(_ id: UUID) {
        guard tabs.count > 1 else { return }
        if let idx = tabs.firstIndex(where: { $0.id == id }) {
            let wasActive = activeTabId == id
            tabs.remove(at: idx)
            if wasActive {
                let newIdx = min(idx, tabs.count - 1)
                activeTabId = tabs[newIdx].id
            }
        }
    }

    func selectTab(_ id: UUID) {
        activeTabId = id
    }

    func updateTab(id: UUID, title: String? = nil, url: URL? = nil,
                   isLoading: Bool? = nil, canGoBack: Bool? = nil,
                   canGoForward: Bool? = nil, estimatedProgress: Double? = nil) {
        guard let idx = tabs.firstIndex(where: { $0.id == id }) else { return }
        if let title = title { tabs[idx].title = title }
        if let url = url { tabs[idx].url = url }
        if let isLoading = isLoading { tabs[idx].isLoading = isLoading }
        if let canGoBack = canGoBack { tabs[idx].canGoBack = canGoBack }
        if let canGoForward = canGoForward { tabs[idx].canGoForward = canGoForward }
        if let estimatedProgress = estimatedProgress { tabs[idx].estimatedProgress = estimatedProgress }
    }

    // ── Bookmarks ──

    func addBookmark(title: String, urlString: String) {
        let bookmark = BrowserBookmark(title: title, urlString: urlString)
        bookmarks.append(bookmark)
        saveBookmarks()
    }

    func removeBookmark(_ id: UUID) {
        bookmarks.removeAll(where: { $0.id == id })
        saveBookmarks()
    }

    func isBookmarked(url: String) -> Bool {
        bookmarks.contains(where: { $0.urlString == url })
    }

    private func saveBookmarks() {
        if let data = try? JSONEncoder().encode(bookmarks) {
            UserDefaults.standard.set(data, forKey: bookmarksKey)
        }
    }

    private func loadBookmarks() {
        guard let data = UserDefaults.standard.data(forKey: bookmarksKey),
              let decoded = try? JSONDecoder().decode([BrowserBookmark].self, from: data) else { return }
        bookmarks = decoded
    }

    // ── History ──

    func recordHistory(url: String, title: String) {
        let entry = BrowserHistoryEntry(url: url, title: title)
        // Skip if same URL as most recent entry (consecutive dedup only)
        if let last = history.first, last.url == url { return }
        history.insert(entry, at: 0)
        if history.count > maxHistoryEntries {
            history.removeLast(history.count - maxHistoryEntries)
        }
        // Debounce history persistence — navigations can happen in rapid bursts
        historySaveWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.saveHistory()
        }
        historySaveWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: workItem)
    }

    func removeHistoryEntry(_ id: UUID) {
        history.removeAll(where: { $0.id == id })
        saveHistory()
    }

    func clearHistory() {
        history.removeAll()
        saveHistory()
    }

    private func saveHistory() {
        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: historyKey)
        }
    }

    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: historyKey),
              let decoded = try? JSONDecoder().decode([BrowserHistoryEntry].self, from: data) else { return }
        history = decoded
    }

    // ── Tab Persistence ──

    func saveTabs() {
        let saved = tabs.compactMap { tab -> SavedTab? in
            guard let url = tab.url else { return nil }
            return SavedTab(urlString: url.absoluteString, title: tab.title)
        }
        if let data = try? JSONEncoder().encode(saved) {
            UserDefaults.standard.set(data, forKey: savedTabsKey)
        }
    }

    private func restoreTabs() {
        guard let data = UserDefaults.standard.data(forKey: savedTabsKey),
              let saved = try? JSONDecoder().decode([SavedTab].self, from: data),
              !saved.isEmpty else { return }
        for savedTab in saved {
            if let url = URL(string: savedTab.urlString) {
                let tab = BrowserTab(url: url, title: savedTab.title)
                tabs.append(tab)
            }
        }
        if !tabs.isEmpty {
            activeTabId = tabs.first?.id
        }
        // Clear saved tabs after restoring
        UserDefaults.standard.removeObject(forKey: savedTabsKey)
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - WKWebView Coordinator & NSViewRepresentable
// ═══════════════════════════════════════════════════════

struct WebViewRepresentable: NSViewRepresentable {
    let tabId: UUID
    let url: URL?
    @ObservedObject var manager: BrowserManager

    // Actions piped from parent
    var goBackTrigger: PassthroughSubject<Void, Never>
    var goForwardTrigger: PassthroughSubject<Void, Never>
    var reloadTrigger: PassthroughSubject<Void, Never>
    var navigateTrigger: PassthroughSubject<URL, Never>

    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var parent: WebViewRepresentable
        var cancellables = Set<AnyCancellable>()
        weak var webView: WKWebView?

        init(_ parent: WebViewRepresentable) {
            self.parent = parent
        }

        // ── Navigation Delegate ──

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.manager.updateTab(id: parent.tabId, isLoading: true)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.manager.updateTab(
                id: parent.tabId,
                title: webView.title,
                url: webView.url,
                isLoading: false,
                canGoBack: webView.canGoBack,
                canGoForward: webView.canGoForward,
                estimatedProgress: 1.0
            )
            // Record history
            if let url = webView.url?.absoluteString,
               url != "about:blank",
               !url.isEmpty {
                let title = webView.title ?? url
                parent.manager.recordHistory(url: url, title: title)
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.manager.updateTab(id: parent.tabId, isLoading: false, estimatedProgress: 0)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            parent.manager.updateTab(id: parent.tabId, isLoading: false, estimatedProgress: 0)
        }

        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            parent.manager.updateTab(
                id: parent.tabId,
                url: webView.url,
                canGoBack: webView.canGoBack,
                canGoForward: webView.canGoForward
            )
        }

        // ── UI Delegate: handle new window requests ──

        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if let url = navigationAction.request.url {
                parent.manager.createNewTab(url: url)
            }
            return nil
        }

        // ── Progress observation ──

        func observeProgress(_ webView: WKWebView) {
            webView.publisher(for: \.estimatedProgress)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] progress in
                    guard let self = self else { return }
                    self.parent.manager.updateTab(id: self.parent.tabId, estimatedProgress: progress)
                }
                .store(in: &cancellables)

            webView.publisher(for: \.title)
                .receive(on: DispatchQueue.main)
                .compactMap { $0 }
                .sink { [weak self] title in
                    guard let self = self else { return }
                    self.parent.manager.updateTab(id: self.parent.tabId, title: title)
                }
                .store(in: &cancellables)

            webView.publisher(for: \.canGoBack)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] val in
                    self?.parent.manager.updateTab(id: self?.parent.tabId ?? UUID(), canGoBack: val)
                }
                .store(in: &cancellables)

            webView.publisher(for: \.canGoForward)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] val in
                    self?.parent.manager.updateTab(id: self?.parent.tabId ?? UUID(), canGoForward: val)
                }
                .store(in: &cancellables)
        }

        func bindActions(_ webView: WKWebView) {
            self.webView = webView

            parent.goBackTrigger
                .receive(on: DispatchQueue.main)
                .sink { [weak webView] in webView?.goBack() }
                .store(in: &cancellables)

            parent.goForwardTrigger
                .receive(on: DispatchQueue.main)
                .sink { [weak webView] in webView?.goForward() }
                .store(in: &cancellables)

            parent.reloadTrigger
                .receive(on: DispatchQueue.main)
                .sink { [weak webView] in webView?.reload() }
                .store(in: &cancellables)

            parent.navigateTrigger
                .receive(on: DispatchQueue.main)
                .sink { [weak webView] url in webView?.load(URLRequest(url: url)) }
                .store(in: &cancellables)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSView {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.setValue(false, forKey: "drawsBackground")

        context.coordinator.observeProgress(webView)
        context.coordinator.bindActions(webView)

        // 항상 URL 로드 시도 — nil이면 Google 홈
        let loadURL = url ?? URL(string: "https://www.google.com")!
        webView.load(URLRequest(url: loadURL))

        // Container view로 감싸서 SwiftUI 레이아웃 경계를 존중하도록 함
        let container = NSView(frame: .zero)
        container.wantsLayer = true
        container.layer?.masksToBounds = true
        webView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            webView.topAnchor.constraint(equalTo: container.topAnchor),
            webView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        return container
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // Updates are driven via Combine subjects, not SwiftUI diffing
    }

    private var blankPageHTML: String {
        """
        <html><head><style>
        body { background: #000; color: #707070; font-family: monospace;
               display: flex; align-items: center; justify-content: center;
               height: 100vh; margin: 0; }
        </style></head><body><p>about:blank</p></body></html>
        """
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - Single Tab Content View
// ═══════════════════════════════════════════════════════

private struct BrowserTabContentView: View {
    let tabId: UUID
    let url: URL?
    @ObservedObject var manager: BrowserManager

    let goBack = PassthroughSubject<Void, Never>()
    let goForward = PassthroughSubject<Void, Never>()
    let reload = PassthroughSubject<Void, Never>()
    let navigate = PassthroughSubject<URL, Never>()

    var body: some View {
        WebViewRepresentable(
            tabId: tabId,
            url: url,
            manager: manager,
            goBackTrigger: goBack,
            goForwardTrigger: goForward,
            reloadTrigger: reload,
            navigateTrigger: navigate
        )
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - Browser Panel View
// ═══════════════════════════════════════════════════════

struct BrowserPanelView: View {
    @StateObject private var manager = BrowserManager()
    @State private var urlBarText: String = ""
    @State private var isURLBarFocused: Bool = false
    @FocusState private var urlFieldFocused: Bool

    // Combine subjects per tab for navigation actions
    @State private var goBackSubjects: [UUID: PassthroughSubject<Void, Never>] = [:]
    @State private var goForwardSubjects: [UUID: PassthroughSubject<Void, Never>] = [:]
    @State private var reloadSubjects: [UUID: PassthroughSubject<Void, Never>] = [:]
    @State private var navigateSubjects: [UUID: PassthroughSubject<URL, Never>] = [:]

    var body: some View {
        VStack(spacing: 0) {
            tabBar
            urlBar
            progressBar
            ZStack {
                Theme.bg
                browserContent
            }
        }
        .background(Theme.bg)
        .onAppear {
            for tab in manager.tabs { ensureSubjects(for: tab.id) }
            syncURLBar()
        }
        .onChange(of: manager.activeTabId) { _ in syncURLBar() }
        .overlay(bookmarksSidebar, alignment: .leading)
        .overlay(historySidebar, alignment: .leading)
        // Keyboard shortcuts
        .keyboardShortcut(for: .focusURLBar) { urlFieldFocused = true }
    }

    // ── Tab Bar ──

    private var tabBar: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    ForEach(manager.tabs) { tab in
                        tabButton(tab)
                    }
                }
                .padding(.horizontal, Theme.sp2)
            }
            Spacer(minLength: 0)

            HStack(spacing: 2) {
                // History toggle
                toolbarButton(icon: "clock.arrow.circlepath", active: manager.showHistory) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        manager.showHistory.toggle()
                        if manager.showHistory { manager.showBookmarks = false }
                    }
                }

                // Bookmark toggle
                toolbarButton(icon: "book", active: manager.showBookmarks) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        manager.showBookmarks.toggle()
                        if manager.showBookmarks { manager.showHistory = false }
                    }
                }

                // New tab button
                toolbarButton(icon: "plus") {
                    let id = manager.createNewTab()
                    ensureSubjects(for: id)
                    urlFieldFocused = true
                }
            }
            .padding(.trailing, Theme.sp2)
        }
        .frame(height: 32)
        .background(Theme.bgCard)
        .overlay(Rectangle().fill(Theme.border).frame(height: 1), alignment: .bottom)
    }

    private func tabButton(_ tab: BrowserTab) -> some View {
        let isActive = manager.activeTabId == tab.id
        return Button(action: {
            manager.selectTab(tab.id)
        }) {
            HStack(spacing: 4) {
                if tab.isLoading {
                    ProgressView()
                        .controlSize(.mini)
                        .scaleEffect(0.6)
                        .frame(width: 10, height: 10)
                } else {
                    Image(systemName: "globe")
                        .font(.system(size: Theme.iconSize(8)))
                        .foregroundColor(Theme.textDim)
                }

                Text(tab.displayTitle)
                    .font(Theme.chrome(9))
                    .foregroundColor(isActive ? Theme.textPrimary : Theme.textSecondary)
                    .lineLimit(1)
                    .frame(maxWidth: 120, alignment: .leading)

                if manager.tabs.count > 1 {
                    Button(action: {
                        closeTabAndCleanup(tab.id)
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundColor(Theme.textDim)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Theme.sp2)
            .padding(.vertical, Theme.sp1)
            .background(
                RoundedRectangle(cornerRadius: Theme.cornerSmall)
                    .fill(isActive ? Theme.bgSelected : .clear)
            )
        }
        .buttonStyle(.plain)
    }

    // ── URL Bar ──

    private var urlBar: some View {
        HStack(spacing: 4) {
            // Navigation buttons
            navButton(icon: "chevron.left", enabled: manager.activeTab?.canGoBack ?? false) {
                if let id = manager.activeTabId { goBackSubjects[id]?.send() }
            }
            navButton(icon: "chevron.right", enabled: manager.activeTab?.canGoForward ?? false) {
                if let id = manager.activeTabId { goForwardSubjects[id]?.send() }
            }
            navButton(icon: manager.activeTab?.isLoading == true ? "xmark" : "arrow.clockwise",
                      enabled: true) {
                if let id = manager.activeTabId { reloadSubjects[id]?.send() }
            }

            // URL text field
            HStack(spacing: 4) {
                Image(systemName: "lock.fill")
                    .font(.system(size: Theme.iconSize(8)))
                    .foregroundColor(
                        urlBarText.hasPrefix("https://") ? Theme.green : Theme.textDim
                    )

                TextField("URL or search", text: $urlBarText)
                    .onSubmit { navigateToURL() }
                    .focused($urlFieldFocused)
                    .font(Theme.mono(10))
                    .foregroundColor(Theme.textPrimary)
                    .textFieldStyle(.plain)

                if !urlBarText.isEmpty {
                    Button(action: { urlBarText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: Theme.iconSize(9)))
                            .foregroundColor(Theme.textDim)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Theme.sp2)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: Theme.cornerMedium)
                    .fill(Theme.bgSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.cornerMedium)
                            .stroke(urlFieldFocused ? Theme.accent.opacity(0.5) : Theme.borderSubtle, lineWidth: 1)
                    )
            )

            // Bookmark current page
            navButton(
                icon: isCurrentPageBookmarked ? "bookmark.fill" : "bookmark",
                enabled: manager.activeTab?.url != nil
            ) {
                toggleBookmarkForCurrentPage()
            }
        }
        .padding(.horizontal, Theme.sp2)
        .padding(.vertical, 4)
        .background(Theme.bgCard)
        .overlay(Rectangle().fill(Theme.borderSubtle).frame(height: 1), alignment: .bottom)
    }

    // ── Progress Bar ──

    private var progressBar: some View {
        GeometryReader { geo in
            let progress = manager.activeTab?.estimatedProgress ?? 0
            let isLoading = manager.activeTab?.isLoading ?? false
            if isLoading && progress < 1.0 {
                Rectangle()
                    .fill(Theme.accent)
                    .frame(width: geo.size.width * CGFloat(progress), height: 2)
                    .animation(.linear(duration: 0.2), value: progress)
            }
        }
        .frame(height: 2)
    }

    // ── Browser Content (tab views) ──

    private var browserContent: some View {
        Group {
            if let tab = manager.tabs.first(where: { $0.id == manager.activeTabId }) {
                let subjects = ensuredSubjects(for: tab.id)
                WebViewRepresentable(
                    tabId: tab.id,
                    url: tab.url,
                    manager: manager,
                    goBackTrigger: subjects.goBack,
                    goForwardTrigger: subjects.goForward,
                    reloadTrigger: subjects.reload,
                    navigateTrigger: subjects.navigate
                )
                .id(tab.id)
            }
        }
    }

    // ── Bookmarks Sidebar ──

    private var bookmarksSidebar: some View {
        Group {
            if manager.showBookmarks {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("Bookmarks")
                            .font(Theme.chrome(10, weight: .bold))
                            .foregroundColor(Theme.textPrimary)
                        Spacer()
                        Button(action: { manager.showBookmarks = false }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(Theme.textDim)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, Theme.sp3)
                    .padding(.vertical, Theme.sp2)
                    .overlay(Rectangle().fill(Theme.border).frame(height: 1), alignment: .bottom)

                    if manager.bookmarks.isEmpty {
                        VStack(spacing: Theme.sp2) {
                            Image(systemName: "bookmark")
                                .font(.system(size: Theme.iconSize(20)))
                                .foregroundColor(Theme.textMuted)
                            Text("No bookmarks yet")
                                .font(Theme.chrome(9))
                                .foregroundColor(Theme.textDim)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(spacing: 1) {
                                ForEach(manager.bookmarks) { bookmark in
                                    bookmarkRow(bookmark)
                                }
                            }
                            .padding(.vertical, Theme.sp1)
                        }
                    }

                    // Quick-access dev URLs
                    VStack(alignment: .leading, spacing: 2) {
                        Rectangle().fill(Theme.border).frame(height: 1)
                        Text("DEV")
                            .font(Theme.mono(8, weight: .bold))
                            .foregroundColor(Theme.textDim)
                            .padding(.horizontal, Theme.sp3)
                            .padding(.top, Theme.sp1)

                        devShortcutRow("localhost:3000", icon: "network", color: Theme.green)
                        devShortcutRow("localhost:5173", icon: "swift", color: Theme.orange)
                        devShortcutRow("localhost:8080", icon: "server.rack", color: Theme.cyan)
                        devShortcutRow("localhost:4000", icon: "leaf", color: Theme.purple)
                    }
                    .padding(.bottom, Theme.sp2)
                }
                .frame(width: 220)
                .background(Theme.bgCard)
                .overlay(Rectangle().fill(Theme.border).frame(width: 1), alignment: .trailing)
                .transition(.move(edge: .leading))
            }
        }
    }

    private func bookmarkRow(_ bookmark: BrowserBookmark) -> some View {
        Button(action: {
            if let url = URL(string: bookmark.urlString), let id = manager.activeTabId {
                navigateSubjects[id]?.send(url)
                urlBarText = bookmark.urlString
            }
        }) {
            HStack(spacing: Theme.sp2) {
                Image(systemName: "bookmark.fill")
                    .font(.system(size: Theme.iconSize(8)))
                    .foregroundColor(Theme.accent)

                VStack(alignment: .leading, spacing: 1) {
                    Text(bookmark.title)
                        .font(Theme.chrome(9))
                        .foregroundColor(Theme.textPrimary)
                        .lineLimit(1)
                    Text(bookmark.urlString)
                        .font(Theme.mono(7))
                        .foregroundColor(Theme.textDim)
                        .lineLimit(1)
                }

                Spacer()

                Button(action: { manager.removeBookmark(bookmark.id) }) {
                    Image(systemName: "trash")
                        .font(.system(size: 8))
                        .foregroundColor(Theme.textDim)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Theme.sp3)
            .padding(.vertical, Theme.sp1 + 2)
            .background(Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }

    private func devShortcutRow(_ urlString: String, icon: String, color: Color) -> some View {
        Button(action: {
            let fullURL = "http://\(urlString)"
            if let url = URL(string: fullURL), let id = manager.activeTabId {
                navigateSubjects[id]?.send(url)
                urlBarText = fullURL
            }
        }) {
            HStack(spacing: Theme.sp2) {
                Image(systemName: icon)
                    .font(.system(size: Theme.iconSize(8)))
                    .foregroundColor(color)
                Text(urlString)
                    .font(Theme.mono(9))
                    .foregroundColor(Theme.textSecondary)
                Spacer()
            }
            .padding(.horizontal, Theme.sp3)
            .padding(.vertical, 3)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
    }

    // ── History Sidebar ──

    private var historySidebar: some View {
        Group {
            if manager.showHistory {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("History")
                            .font(Theme.chrome(10, weight: .bold))
                            .foregroundColor(Theme.textPrimary)
                        Spacer()
                        if !manager.history.isEmpty {
                            Button(action: { manager.clearHistory() }) {
                                Text("Clear")
                                    .font(Theme.chrome(8, weight: .medium))
                                    .foregroundColor(Theme.textDim)
                            }
                            .buttonStyle(.plain)
                        }
                        Button(action: { manager.showHistory = false }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(Theme.textDim)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, Theme.sp3)
                    .padding(.vertical, Theme.sp2)
                    .overlay(Rectangle().fill(Theme.border).frame(height: 1), alignment: .bottom)

                    if manager.history.isEmpty {
                        VStack(spacing: Theme.sp2) {
                            Image(systemName: "clock")
                                .font(.system(size: Theme.iconSize(20)))
                                .foregroundColor(Theme.textMuted)
                            Text("No history yet")
                                .font(Theme.chrome(9))
                                .foregroundColor(Theme.textDim)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(spacing: 1) {
                                ForEach(manager.history) { entry in
                                    historyRow(entry)
                                }
                            }
                            .padding(.vertical, Theme.sp1)
                        }
                    }
                }
                .frame(width: 260)
                .background(Theme.bgCard)
                .overlay(Rectangle().fill(Theme.border).frame(width: 1), alignment: .trailing)
                .transition(.move(edge: .leading))
            }
        }
    }

    private func historyRow(_ entry: BrowserHistoryEntry) -> some View {
        Button(action: {
            if let url = URL(string: entry.url), let id = manager.activeTabId {
                navigateSubjects[id]?.send(url)
                urlBarText = entry.url
            }
        }) {
            HStack(spacing: Theme.sp2) {
                Image(systemName: "clock.fill")
                    .font(.system(size: Theme.iconSize(8)))
                    .foregroundColor(Theme.textDim)

                VStack(alignment: .leading, spacing: 1) {
                    Text(entry.title.isEmpty ? entry.url : entry.title)
                        .font(Theme.chrome(9))
                        .foregroundColor(Theme.textPrimary)
                        .lineLimit(1)
                    HStack(spacing: 4) {
                        Text(entry.url)
                            .font(Theme.mono(7))
                            .foregroundColor(Theme.textDim)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        Text(historyTimeString(entry.visitedAt))
                            .font(Theme.mono(7))
                            .foregroundColor(Theme.textDim)
                    }
                }

                Button(action: { manager.removeHistoryEntry(entry.id) }) {
                    Image(systemName: "trash")
                        .font(.system(size: 8))
                        .foregroundColor(Theme.textDim)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Theme.sp3)
            .padding(.vertical, Theme.sp1 + 2)
            .background(Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
    }

    private func historyTimeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            formatter.dateFormat = "HH:mm"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            formatter.dateFormat = "M/d"
        }
        return formatter.string(from: date)
    }

    // ── Toolbar Buttons ──

    private func toolbarButton(icon: String, active: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: Theme.iconSize(10), weight: .medium))
                .foregroundColor(active ? Theme.accent : Theme.textDim)
                .frame(width: 26, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: Theme.cornerSmall)
                        .fill(active ? Theme.accent.opacity(0.12) : .clear)
                )
        }
        .buttonStyle(.plain)
    }

    private func navButton(icon: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: Theme.iconSize(9), weight: .medium))
                .foregroundColor(enabled ? Theme.textSecondary : Theme.textMuted)
                .frame(width: 26, height: 26)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    // ── Navigation Logic ──

    private func navigateToURL() {
        guard let id = manager.activeTabId else { return }
        let input = urlBarText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }

        let url: URL?
        if input.hasPrefix("http://") || input.hasPrefix("https://") {
            url = URL(string: input)
        } else if input.contains(".") && !input.contains(" ") {
            // Treat as a URL
            url = URL(string: "https://\(input)")
        } else {
            // Treat as a search query
            let encoded = input.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? input
            url = URL(string: "https://www.google.com/search?q=\(encoded)")
        }

        if let url = url {
            navigateSubjects[id]?.send(url)
            urlBarText = url.absoluteString
        }
    }

    private func syncURLBar() {
        let url = manager.activeTab?.displayURL ?? ""
        urlBarText = (url == "about:blank") ? "" : url
    }

    // ── Bookmark Helpers ──

    private var isCurrentPageBookmarked: Bool {
        guard let url = manager.activeTab?.url?.absoluteString else { return false }
        return manager.isBookmarked(url: url)
    }

    private func toggleBookmarkForCurrentPage() {
        guard let tab = manager.activeTab, let url = tab.url else { return }
        if manager.isBookmarked(url: url.absoluteString) {
            if let bm = manager.bookmarks.first(where: { $0.urlString == url.absoluteString }) {
                manager.removeBookmark(bm.id)
            }
        } else {
            manager.addBookmark(title: tab.displayTitle, urlString: url.absoluteString)
        }
    }

    // ── Tab Cleanup ──

    private func closeTabAndCleanup(_ id: UUID) {
        goBackSubjects.removeValue(forKey: id)
        goForwardSubjects.removeValue(forKey: id)
        reloadSubjects.removeValue(forKey: id)
        navigateSubjects.removeValue(forKey: id)
        manager.closeTab(id)
    }

    // ── Subject Management ──

    private func ensureSubjects(for id: UUID) {
        if goBackSubjects[id] == nil { goBackSubjects[id] = PassthroughSubject() }
        if goForwardSubjects[id] == nil { goForwardSubjects[id] = PassthroughSubject() }
        if reloadSubjects[id] == nil { reloadSubjects[id] = PassthroughSubject() }
        if navigateSubjects[id] == nil { navigateSubjects[id] = PassthroughSubject() }
    }

    private func ensuredSubjects(for id: UUID) -> (
        goBack: PassthroughSubject<Void, Never>,
        goForward: PassthroughSubject<Void, Never>,
        reload: PassthroughSubject<Void, Never>,
        navigate: PassthroughSubject<URL, Never>
    ) {
        ensureSubjects(for: id)
        return (goBackSubjects[id]!, goForwardSubjects[id]!, reloadSubjects[id]!, navigateSubjects[id]!)
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - Keyboard Shortcut Helpers
// ═══════════════════════════════════════════════════════

private enum BrowserShortcut {
    case focusURLBar
    case newTab
    case closeTab
}

private extension View {
    @ViewBuilder
    func keyboardShortcut(for shortcut: BrowserShortcut, action: @escaping () -> Void) -> some View {
        self.background(
            Group {
                switch shortcut {
                case .focusURLBar:
                    Button("") { action() }
                        .keyboardShortcut("l", modifiers: .command)
                        .frame(width: 0, height: 0)
                        .opacity(0)
                case .newTab:
                    Button("") { action() }
                        .keyboardShortcut("t", modifiers: .command)
                        .frame(width: 0, height: 0)
                        .opacity(0)
                case .closeTab:
                    Button("") { action() }
                        .keyboardShortcut("w", modifiers: .command)
                        .frame(width: 0, height: 0)
                        .opacity(0)
                }
            }
        )
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - Split Browser View (Browser + Terminal)
// ═══════════════════════════════════════════════════════

struct BrowserSplitView: View {
    @State private var splitRatio: CGFloat = 0.5

    var terminalContent: AnyView
    var browserContent: AnyView

    init<T: View, B: View>(terminal: T, browser: B) {
        self.terminalContent = AnyView(terminal)
        self.browserContent = AnyView(browser)
    }

    init() {
        self.terminalContent = AnyView(
            Text("Terminal")
                .font(Theme.mono(12))
                .foregroundColor(Theme.textDim)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.bg)
        )
        self.browserContent = AnyView(BrowserPanelView())
    }

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                terminalContent
                    .frame(width: geo.size.width * splitRatio)

                // Resize handle
                Rectangle()
                    .fill(Theme.border)
                    .frame(width: 3)
                    .contentShape(Rectangle().inset(by: -4))
                    .onHover { hovering in
                        if hovering {
                            NSCursor.resizeLeftRight.push()
                        } else {
                            NSCursor.pop()
                        }
                    }
                    .gesture(
                        DragGesture(minimumDistance: 1)
                            .onChanged { value in
                                let newRatio = value.location.x / geo.size.width
                                splitRatio = min(max(newRatio, 0.15), 0.85)
                            }
                    )

                browserContent
                    .frame(width: geo.size.width * (1 - splitRatio) - 3)
            }
        }
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - Previews
// ═══════════════════════════════════════════════════════

#if DEBUG
struct BrowserPanelView_Previews: PreviewProvider {
    static var previews: some View {
        BrowserPanelView()
            .frame(width: 900, height: 600)
            .preferredColorScheme(.dark)
    }
}
#endif
