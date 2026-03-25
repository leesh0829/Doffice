import SwiftUI
import UserNotifications

@main
struct WorkManApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var manager = SessionManager.shared
    @ObservedObject private var settings = AppSettings.shared

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(manager)
                .environmentObject(settings)
                .frame(minWidth: 1000, minHeight: 650)
                .preferredColorScheme(settings.colorScheme)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1200, height: 800)

        // 오피스 전용 창 (듀얼 모니터용)
        WindowGroup("도피스 오피스", id: "office-window") {
            OfficeWindowView()
                .environmentObject(manager)
                .environmentObject(settings)
                .preferredColorScheme(settings.colorScheme)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 900, height: 600)
        .commands {
            CommandGroup(after: .toolbar) {
                Button("Restart Session") {
                    NotificationCenter.default.post(name: .workmanRestartSession, object: nil)
                }
                .keyboardShortcut("r", modifiers: .command)
            }

            CommandGroup(after: .newItem) {
                Button("New Session") {
                    NotificationCenter.default.post(name: .workmanNewTab, object: nil)
                }
                .keyboardShortcut("t", modifiers: .command)

                Button("Close Session") {
                    NotificationCenter.default.post(name: .workmanCloseTab, object: nil)
                }
                .keyboardShortcut("w", modifiers: .command)

                Divider()

                Button("Next Tab") {
                    NotificationCenter.default.post(name: .workmanNextTab, object: nil)
                }
                .keyboardShortcut("]", modifiers: [.command, .shift])

                Button("Previous Tab") {
                    NotificationCenter.default.post(name: .workmanPreviousTab, object: nil)
                }
                .keyboardShortcut("[", modifiers: [.command, .shift])

                Divider()

                Button("Cancel Processing") {
                    NotificationCenter.default.post(name: .workmanCancelProcessing, object: nil)
                }
                .keyboardShortcut(".", modifiers: .command)

                Button("Clear Terminal") {
                    NotificationCenter.default.post(name: .workmanClearTerminal, object: nil)
                }
                .keyboardShortcut("k", modifiers: .command)

                Button("Command Palette") {
                    NotificationCenter.default.post(name: .workmanCommandPalette, object: nil)
                }
                .keyboardShortcut("p", modifiers: .command)

                Button("Action Center") {
                    NotificationCenter.default.post(name: .workmanActionCenter, object: nil)
                }
                .keyboardShortcut("j", modifiers: .command)

                Divider()

                Button("Toggle Split View") {
                    NotificationCenter.default.post(name: .workmanToggleSplit, object: nil)
                }
                .keyboardShortcut("\\", modifiers: .command)

                Button("Toggle Office View") {
                    NotificationCenter.default.post(name: .workmanToggleOffice, object: nil)
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])

                Button("Toggle Terminal View") {
                    NotificationCenter.default.post(name: .workmanToggleTerminal, object: nil)
                }
                .keyboardShortcut("t", modifiers: [.command, .shift])

                Divider()

                Button("Export Session Log") {
                    NotificationCenter.default.post(name: .workmanExportLog, object: nil)
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])

                Divider()

                ForEach(1...9, id: \.self) { index in
                    Button("Session \(index)") {
                        NotificationCenter.default.post(name: .workmanSelectTab, object: index)
                    }
                    .keyboardShortcut(KeyEquivalent(Character("\(index)")), modifiers: .command)
                }
            }
        }
    }
}

extension Notification.Name {
    static let workmanRefresh = Notification.Name("workmanRefresh")
    static let workmanNewTab = Notification.Name("workmanNewTab")
    static let workmanCloseTab = Notification.Name("workmanCloseTab")
    static let workmanSelectTab = Notification.Name("workmanSelectTab")
    static let workmanToggleSplit = Notification.Name("workmanToggleSplit")
    static let workmanExportLog = Notification.Name("workmanExportLog")
    static let workmanRestartSession = Notification.Name("workmanRestartSession")
    static let workmanNextTab = Notification.Name("workmanNextTab")
    static let workmanPreviousTab = Notification.Name("workmanPreviousTab")
    static let workmanCancelProcessing = Notification.Name("workmanCancelProcessing")
    static let workmanClearTerminal = Notification.Name("workmanClearTerminal")
    static let workmanToggleOffice = Notification.Name("workmanToggleOffice")
    static let workmanToggleTerminal = Notification.Name("workmanToggleTerminal")
    static let workmanClaudeNotInstalled = Notification.Name("workmanClaudeNotInstalled")
    static let workmanTabCycleCompleted = Notification.Name("workmanTabCycleCompleted")
    static let workmanRoleNotice = Notification.Name("workmanRoleNotice")
    static let workmanSessionStoreDidChange = Notification.Name("workmanSessionStoreDidChange")
    static let workmanScrollToBlock = Notification.Name("workmanScrollToBlock")
    static let workmanCommandPalette = Notification.Name("workmanCommandPalette")
    static let workmanActionCenter = Notification.Name("workmanActionCenter")
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var menuBarManager = MenuBarManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 번들 ID 변경 시 이전 데이터 마이그레이션
        migrateFromOldBundleIfNeeded()

        // 사용자 언어 설정 적용
        AppSettings.shared.applyLanguage()

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        menuBarManager.setup()

        // 글로벌 크래시 핸들러 — 예기치 않은 종료 시 세션 자동 저장
        setupCrashRecovery()

        // Claude 설치 확인 (백그라운드에서 실행 — 메인 스레드 블로킹 방지)
        DispatchQueue.global(qos: .userInitiated).async {
            ClaudeInstallChecker.shared.check()
            DispatchQueue.main.async {
                if ClaudeInstallChecker.shared.isInstalled {
                    print("[도피스] Claude Code \(ClaudeInstallChecker.shared.version) found at \(ClaudeInstallChecker.shared.path)")
                } else {
                    print("[도피스] ⚠️ Claude Code not installed")
                }
            }
        }
    }

    /// 이전 번들 ID (com.junha.workman)의 UserDefaults 데이터를 현재 앱으로 마이그레이션
    private func migrateFromOldBundleIfNeeded() {
        let migrationKey = "doffice.migrated.from.workman"
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }

        // 이전 번들의 UserDefaults 읽기
        guard let oldDefaults = UserDefaults(suiteName: "com.junha.workman") else {
            UserDefaults.standard.set(true, forKey: migrationKey)
            return
        }

        let oldDict = oldDefaults.dictionaryRepresentation()
        guard !oldDict.isEmpty else {
            UserDefaults.standard.set(true, forKey: migrationKey)
            return
        }

        // 마이그레이션 대상 키 (중요 데이터)
        let keysToMigrate = [
            // 도전과제 & 레벨
            "WorkManAchievements",
            // 캐릭터
            "WorkManCharacters",
            "WorkManCharacterManualUnlocks",
            // 토큰 사용량
            "WorkManTokenHistory",
            // 감사 로그
            "WorkManAuditLog",
            // 앱 설정
            "isDarkMode", "fontSizeScale", "officeViewMode", "officePreset",
            "backgroundTheme", "reviewerMaxPasses", "qaMaxPasses",
            "automationRevisionLimit", "allowParallelSubagents",
            "terminalSidebarLightweight", "rawTerminalMode",
            "autoRefreshOnSettingsChange", "appDisplayName", "companyName",
            "hasCompletedOnboarding",
            // 커피 지원 & 휴게실
            "breakRoomShowSofa", "breakRoomShowCoffeeMachine", "breakRoomShowPlant",
            "breakRoomShowSideTable", "breakRoomShowClock", "breakRoomShowPicture",
            "breakRoomShowNeonSign", "breakRoomShowRug", "breakRoomShowBookshelf",
            "breakRoomShowAquarium", "breakRoomShowArcade", "breakRoomShowWhiteboard",
            "breakRoomShowLamp", "breakRoomShowCat", "breakRoomShowTV",
            "breakRoomShowFan", "breakRoomShowCalendar", "breakRoomShowPoster",
            // 토큰 한도
            "userDailyTokenLimit", "userWeeklyTokenLimit",
            // 뷰 모드
            "viewModeRaw", "officeExpanded", "sidebarWidth",
            // 세션 관련
            "workman.selectedGroupPath",
            "workman.sidebarStatusFilter", "workman.sidebarSortOption",
            // 새 세션 프리셋
            "workman.new-session.favorite-projects",
            "workman.new-session.recent-projects",
            "workman.new-session.last-draft",
            // 자동화 템플릿
            "workman.automation.templates.v1",
            // 오피스 레이아웃
            "workman.office.layout.cozy.v1",
            "workman.office.layout.startup.v1",
            "workman.office.layout.enterprise.v1",
        ]

        var migratedCount = 0
        for key in keysToMigrate {
            if let value = oldDict[key], UserDefaults.standard.object(forKey: key) == nil {
                UserDefaults.standard.set(value, forKey: key)
                migratedCount += 1
            }
        }

        // @AppStorage 키도 포함: 패턴 매칭으로 나머지 키 마이그레이션
        for (key, value) in oldDict {
            if key.hasPrefix("workman.") || key.hasPrefix("WorkMan"),
               UserDefaults.standard.object(forKey: key) == nil {
                UserDefaults.standard.set(value, forKey: key)
                migratedCount += 1
            }
        }

        // 세션 JSON 파일도 마이그레이션 (Application Support/WorkMan → 동일 경로 유지)
        // SessionStore는 이미 "WorkMan" 경로를 사용하므로 파일 이동 불필요

        UserDefaults.standard.set(true, forKey: migrationKey)
        if migratedCount > 0 {
            print("[도피스] ✅ 이전 데이터 마이그레이션 완료: \(migratedCount)개 항목")
        }
    }

    private func setupCrashRecovery() {
        // SIGTERM, SIGINT 등 시그널 수신 시 세션 저장
        let signals: [Int32] = [SIGTERM, SIGINT, SIGHUP]
        for sig in signals {
            signal(sig) { _ in
                SessionManager.shared.saveSessions(immediately: true)
                exit(0)
            }
        }

        // NSException (Objective-C 예외) 핸들러
        NSSetUncaughtExceptionHandler { exception in
            print("[WorkMan] ⚠️ Uncaught exception: \(exception.name) — \(exception.reason ?? "unknown")")
            SessionManager.shared.saveSessions(immediately: true)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        SessionManager.shared.saveSessions(immediately: true)
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        let manager = SessionManager.shared
        let runningTabs = manager.tabs.filter { $0.isProcessing }

        // 진행 중인 작업이 없으면 바로 종료
        guard !runningTabs.isEmpty else { return .terminateNow }

        let alert = NSAlert()
        alert.messageText = "진행 중인 작업이 \(runningTabs.count)개 있습니다"
        alert.informativeText = "앱을 종료하면 현재 진행 중인 작업은 완료되지 않습니다.\n자동 롤백은 하지 않고, 복구 폴더를 만든 뒤 안전하게 중단할 수 있습니다."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "백업 후 중단하고 종료")
        alert.addButton(withTitle: "그대로 종료")
        alert.addButton(withTitle: "취소")

        let response = alert.runModal()
        switch response {
        case .alertFirstButtonReturn:
            // 모든 진행 중인 작업을 백업한 뒤 중단
            for tab in runningTabs {
                _ = SessionStore.shared.writeRecoveryBundle(for: tab, reason: "앱 종료 전 진행 중 작업 백업")
                tab.forceStop()
            }
            manager.saveSessions(immediately: true)
            return .terminateNow
        case .alertSecondButtonReturn:
            // 롤백 없이 그대로 종료
            for tab in runningTabs {
                tab.forceStop()
            }
            manager.saveSessions(immediately: true)
            return .terminateNow
        default:
            // 취소 - 종료하지 않음
            return .terminateCancel
        }
    }

    // Feature 3: 메뉴바에서 창 다시 열기
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            // 창이 없으면 새로 열기
            for window in NSApp.windows {
                window.makeKeyAndOrderFront(self)
            }
        }
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}
