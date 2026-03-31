import SwiftUI
import Carbon.HIToolbox
import DesignSystem

// ═══════════════════════════════════════════════════════
// MARK: - Shortcut Model
// ═══════════════════════════════════════════════════════

/// 단축키 데이터 — 키값(Key Equivalent)과 수식키(Modifier Flags)를 캡슐화
public struct KeyShortcut: Codable, Equatable, Hashable {
    public var keyEquivalent: String   // 예: "t", "k", "[", "1"
    public var command: Bool           // ⌘
    public var shift: Bool             // ⇧
    public var option: Bool            // ⌥
    public var control: Bool           // ⌃

    public var modifiers: NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if command  { flags.insert(.command) }
        if shift    { flags.insert(.shift) }
        if option   { flags.insert(.option) }
        if control  { flags.insert(.control) }
        return flags
    }

    public var swiftUIModifiers: SwiftUI.EventModifiers {
        var mods: SwiftUI.EventModifiers = []
        if command  { mods.insert(.command) }
        if shift    { mods.insert(.shift) }
        if option   { mods.insert(.option) }
        if control  { mods.insert(.control) }
        return mods
    }

    /// 사람이 읽을 수 있는 표시 문자열 (예: "⌘⇧T")
    public var displayString: String {
        var parts: [String] = []
        if control { parts.append("⌃") }
        if option  { parts.append("⌥") }
        if shift   { parts.append("⇧") }
        if command { parts.append("⌘") }

        let keyDisplay: String
        switch keyEquivalent.lowercased() {
        case " ":  keyDisplay = "Space"
        case "\r": keyDisplay = "↩"
        case "\t": keyDisplay = "⇥"
        case "[":  keyDisplay = "["
        case "]":  keyDisplay = "]"
        case "\\": keyDisplay = "\\"
        case ".":  keyDisplay = "."
        default:   keyDisplay = keyEquivalent.uppercased()
        }
        parts.append(keyDisplay)
        return parts.joined()
    }

    /// NSEvent에서 수식키 + keyEquivalent 매칭
    public func matches(_ event: NSEvent) -> Bool {
        let required: NSEvent.ModifierFlags = [.command, .shift, .option, .control]
        let eventMods = event.modifierFlags.intersection(required)
        guard eventMods == modifiers else { return false }

        guard let chars = event.charactersIgnoringModifiers?.lowercased() else { return false }
        return chars == keyEquivalent.lowercased()
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - Shortcut Action
// ═══════════════════════════════════════════════════════

/// 앱에서 단축키로 제어할 수 있는 모든 액션
public enum ShortcutAction: String, CaseIterable, Codable, Identifiable {
    // ── 세션 ──
    case restartSession     = "restartSession"
    case newSession         = "newSession"
    case closeSession       = "closeSession"
    case nextTab            = "nextTab"
    case previousTab        = "previousTab"

    // ── 터미널 ──
    case cancelProcessing   = "cancelProcessing"
    case clearTerminal      = "clearTerminal"

    // ── 뷰 제어 ──
    case commandPalette     = "commandPalette"
    case actionCenter       = "actionCenter"
    case toggleSplitView    = "toggleSplitView"
    case toggleOfficeView   = "toggleOfficeView"
    case toggleTerminalView = "toggleTerminalView"
    case toggleBrowserView  = "toggleBrowserView"

    // ── 액션 ──
    case exportSessionLog   = "exportSessionLog"

    public var id: String { rawValue }

    /// UI 표시용 카테고리
    public var category: ShortcutCategory {
        switch self {
        case .restartSession, .newSession, .closeSession, .nextTab, .previousTab:
            return .session
        case .cancelProcessing, .clearTerminal:
            return .terminal
        case .commandPalette, .actionCenter, .toggleSplitView, .toggleOfficeView, .toggleTerminalView, .toggleBrowserView:
            return .view
        case .exportSessionLog:
            return .action
        }
    }

    /// 로컬라이즈된 표시 이름
    public var localizedName: String {
        NSLocalizedString("shortcut.action.\(rawValue)", comment: "")
    }

    /// 이 액션에 대응하는 Notification.Name
    public var notificationName: Notification.Name {
        switch self {
        case .restartSession:     return .dofficeRestartSession
        case .newSession:         return .dofficeNewTab
        case .closeSession:       return .dofficeCloseTab
        case .nextTab:            return .dofficeNextTab
        case .previousTab:        return .dofficePreviousTab
        case .cancelProcessing:   return .dofficeCancelProcessing
        case .clearTerminal:      return .dofficeClearTerminal
        case .commandPalette:     return .dofficeCommandPalette
        case .actionCenter:       return .dofficeActionCenter
        case .toggleSplitView:    return .dofficeToggleSplit
        case .toggleOfficeView:   return .dofficeToggleOffice
        case .toggleTerminalView: return .dofficeToggleTerminal
        case .toggleBrowserView:  return .dofficeToggleBrowser
        case .exportSessionLog:   return .dofficeExportLog
        }
    }
}

public enum ShortcutCategory: String, CaseIterable {
    case session  = "session"
    case terminal = "terminal"
    case view     = "view"
    case action   = "action"

    public var localizedName: String {
        NSLocalizedString("shortcut.category.\(rawValue)", comment: "")
    }

    public var icon: String {
        switch self {
        case .session:  return "rectangle.stack"
        case .terminal: return "terminal"
        case .view:     return "sidebar.squares.leading"
        case .action:   return "bolt.fill"
        }
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - Default Shortcuts
// ═══════════════════════════════════════════════════════

/// 기본 단축키 프리셋 — 언제든 복원 가능
public let defaultShortcutMap: [ShortcutAction: KeyShortcut] = [
    .restartSession:     KeyShortcut(keyEquivalent: "r", command: true, shift: false, option: false, control: false),
    .newSession:         KeyShortcut(keyEquivalent: "t", command: true, shift: false, option: false, control: false),
    .closeSession:       KeyShortcut(keyEquivalent: "w", command: true, shift: false, option: false, control: false),
    .nextTab:            KeyShortcut(keyEquivalent: "]", command: true, shift: true,  option: false, control: false),
    .previousTab:        KeyShortcut(keyEquivalent: "[", command: true, shift: true,  option: false, control: false),
    .cancelProcessing:   KeyShortcut(keyEquivalent: ".", command: true, shift: false, option: false, control: false),
    .clearTerminal:      KeyShortcut(keyEquivalent: "k", command: true, shift: false, option: false, control: false),
    .commandPalette:     KeyShortcut(keyEquivalent: "p", command: true, shift: false, option: false, control: false),
    .actionCenter:       KeyShortcut(keyEquivalent: "j", command: true, shift: false, option: false, control: false),
    .toggleSplitView:    KeyShortcut(keyEquivalent: "\\", command: true, shift: false, option: false, control: false),
    .toggleOfficeView:   KeyShortcut(keyEquivalent: "o", command: true, shift: true,  option: false, control: false),
    .toggleTerminalView: KeyShortcut(keyEquivalent: "t", command: true, shift: true,  option: false, control: false),
    .toggleBrowserView:  KeyShortcut(keyEquivalent: "b", command: true, shift: true,  option: false, control: false),
    .exportSessionLog:   KeyShortcut(keyEquivalent: "e", command: true, shift: true,  option: false, control: false),
]

// ═══════════════════════════════════════════════════════
// MARK: - macOS 시스템 예약 단축키
// ═══════════════════════════════════════════════════════

/// 충돌 감지를 위한 macOS 필수 시스템 단축키 목록
private let reservedSystemShortcuts: [KeyShortcut] = [
    KeyShortcut(keyEquivalent: "q", command: true, shift: false, option: false, control: false), // 앱 종료
    KeyShortcut(keyEquivalent: "h", command: true, shift: false, option: false, control: false), // 숨기기
    KeyShortcut(keyEquivalent: "m", command: true, shift: false, option: false, control: false), // 최소화
    KeyShortcut(keyEquivalent: "a", command: true, shift: false, option: false, control: false), // 전체 선택
    KeyShortcut(keyEquivalent: "c", command: true, shift: false, option: false, control: false), // 복사
    KeyShortcut(keyEquivalent: "v", command: true, shift: false, option: false, control: false), // 붙여넣기
    KeyShortcut(keyEquivalent: "x", command: true, shift: false, option: false, control: false), // 잘라내기
    KeyShortcut(keyEquivalent: "z", command: true, shift: false, option: false, control: false), // 실행 취소
    KeyShortcut(keyEquivalent: "z", command: true, shift: true, option: false, control: false),  // 다시 실행
    KeyShortcut(keyEquivalent: ",", command: true, shift: false, option: false, control: false), // 환경 설정
    KeyShortcut(keyEquivalent: " ", command: true, shift: false, option: false, control: false), // Spotlight
]

// ═══════════════════════════════════════════════════════
// MARK: - ShortcutManager
// ═══════════════════════════════════════════════════════

public class ShortcutManager: ObservableObject {
    public static let shared = ShortcutManager()

    /// 현재 단축키 매핑 — nil 값은 "할당 해제(Unassigned)" 상태
    @Published public var shortcuts: [ShortcutAction: KeyShortcut?] = [:] {
        didSet { saveToStorage() }
    }

    private let storageKey = "doffice.customShortcuts"

    // 이벤트 모니터 참조
    private var localMonitor: Any?

    private init() {
        loadFromStorage()
    }

    // MARK: - 조회

    /// 특정 액션에 할당된 단축키 반환 (nil = 할당 해제)
    public func shortcut(for action: ShortcutAction) -> KeyShortcut? {
        if let entry = shortcuts[action] {
            return entry  // nil이면 명시적으로 unassigned
        }
        // 저장된 적 없으면 기본값 사용
        return defaultShortcutMap[action]
    }

    /// 기본값과 다른지 여부
    public func isCustomized(_ action: ShortcutAction) -> Bool {
        guard let entry = shortcuts[action] else { return false }
        return entry != defaultShortcutMap[action]
    }

    // MARK: - 변경

    /// 단축키 변경 — 충돌 검사 포함
    public func setShortcut(_ shortcut: KeyShortcut?, for action: ShortcutAction) {
        shortcuts[action] = shortcut
    }

    /// 특정 액션을 기본값으로 복원
    public func resetToDefault(_ action: ShortcutAction) {
        shortcuts[action] = defaultShortcutMap[action]
    }

    /// 모든 단축키를 기본값으로 초기화
    public func resetAllToDefaults() {
        shortcuts = defaultShortcutMap.mapValues { Optional($0) }
    }

    // MARK: - 충돌 감지

    public enum ConflictResult: Equatable {
        case none
        case conflictsWithAction(ShortcutAction)
        case conflictsWithSystem
    }

    /// 새 단축키가 기존 매핑이나 시스템 단축키와 충돌하는지 검사
    public func checkConflict(_ shortcut: KeyShortcut, excludingAction: ShortcutAction) -> ConflictResult {
        // 시스템 단축키 충돌 검사
        if reservedSystemShortcuts.contains(shortcut) {
            return .conflictsWithSystem
        }

        // 다른 액션과의 충돌 검사
        for action in ShortcutAction.allCases where action != excludingAction {
            if let existing = self.shortcut(for: action), existing == shortcut {
                return .conflictsWithAction(action)
            }
        }

        return .none
    }

    // MARK: - 이벤트 모니터

    /// 중앙 집중식 키보드 이벤트 라우터 설치
    public func installEventMonitor() {
        guard localMonitor == nil else { return }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }

            // 텍스트 입력 중이면 단축키 처리하지 않음
            if let responder = NSApp.keyWindow?.firstResponder,
               responder is NSTextView || responder is NSTextField {
                return event
            }

            for action in ShortcutAction.allCases {
                if let shortcut = self.shortcut(for: action), shortcut.matches(event) {
                    NotificationCenter.default.post(name: action.notificationName, object: nil)
                    return nil  // 이벤트 소비
                }
            }

            // 세션 선택 단축키 (⌘1~⌘9) — 이건 고정
            let mods = event.modifierFlags.intersection([.command, .shift, .option, .control])
            if mods == .command,
               let chars = event.charactersIgnoringModifiers,
               let digit = Int(chars), (1...9).contains(digit) {
                NotificationCenter.default.post(name: .dofficeSelectTab, object: digit)
                return nil
            }

            return event
        }
    }

    /// 이벤트 모니터 해제
    public func removeEventMonitor() {
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }

    // MARK: - 저장/불러오기

    private func saveToStorage() {
        // [String: KeyShortcut?] 형태로 인코딩
        var dict: [String: KeyShortcut?] = [:]
        for (action, shortcut) in shortcuts {
            dict[action.rawValue] = shortcut
        }
        if let data = try? JSONEncoder().encode(dict) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func loadFromStorage() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let dict = try? JSONDecoder().decode([String: KeyShortcut?].self, from: data) else {
            return
        }
        var result: [ShortcutAction: KeyShortcut?] = [:]
        for (key, value) in dict {
            if let action = ShortcutAction(rawValue: key) {
                result[action] = value
            }
        }
        shortcuts = result
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - Key Recorder View (키 캡처 UI)
// ═══════════════════════════════════════════════════════

/// 사용자가 원하는 키 조합을 직접 눌러서 캡처하는 커스텀 컨트롤
public struct KeyRecorderView: View {
    public let action: ShortcutAction
    public let currentShortcut: KeyShortcut?
    public let onRecord: (KeyShortcut?) -> Void

    @State private var isRecording = false
    @State private var localMonitor: Any?

    public var body: some View {
        HStack(spacing: 6) {
            // 단축키 표시 / 녹화 버튼
            Button(action: { startRecording() }) {
                HStack(spacing: 4) {
                    if isRecording {
                        Text(NSLocalizedString("shortcut.recording", comment: ""))
                            .font(Theme.mono(9, weight: .medium))
                            .foregroundStyle(Theme.accentBackground)
                    } else if let shortcut = currentShortcut {
                        Text(shortcut.displayString)
                            .font(Theme.mono(10, weight: .bold))
                            .foregroundColor(Theme.textPrimary)
                    } else {
                        Text(NSLocalizedString("shortcut.unassigned", comment: ""))
                            .font(Theme.mono(9))
                            .foregroundColor(Theme.textDim)
                    }
                }
                .frame(minWidth: 80)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: Theme.cornerMedium)
                        .fill(isRecording ? Theme.accent.opacity(0.08) : Theme.bgSurface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.cornerMedium)
                        .stroke(isRecording ? Theme.accent : Theme.border, lineWidth: isRecording ? 1.5 : 0.5)
                )
            }
            .buttonStyle(.plain)

            // 할당 해제 버튼
            if currentShortcut != nil {
                Button(action: { onRecord(nil) }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: Theme.iconSize(10)))
                        .foregroundColor(Theme.textDim)
                }
                .buttonStyle(.plain)
                .help(NSLocalizedString("shortcut.unassign", comment: ""))
            }
        }
        .onDisappear { stopRecording() }
    }

    private func startRecording() {
        guard !isRecording else { return }
        isRecording = true
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let mods = event.modifierFlags

            // Escape 키 → 녹화 취소
            if event.keyCode == UInt16(kVK_Escape) {
                stopRecording()
                return nil
            }

            // 수식키만 누른 경우는 무시
            guard let chars = event.charactersIgnoringModifiers, !chars.isEmpty else { return nil }

            let shortcut = KeyShortcut(
                keyEquivalent: chars.lowercased(),
                command: mods.contains(.command),
                shift: mods.contains(.shift),
                option: mods.contains(.option),
                control: mods.contains(.control)
            )

            // 최소한 하나의 수식키가 필요
            guard shortcut.command || shortcut.control || shortcut.option else {
                return nil
            }

            stopRecording()
            onRecord(shortcut)
            return nil
        }
    }

    private func stopRecording() {
        isRecording = false
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - Shortcuts Settings Tab View
// ═══════════════════════════════════════════════════════

public struct ShortcutsSettingsTab: View {
    @ObservedObject private var manager = ShortcutManager.shared
    @State private var conflictAlert: ConflictAlertData?
    @State private var showResetConfirm = false

    public init() {}

    private struct ConflictAlertData: Identifiable {
        let id = UUID()
        let action: ShortcutAction
        let shortcut: KeyShortcut
        let conflict: ShortcutManager.ConflictResult
    }

    public var body: some View {
        VStack(spacing: 14) {
            ForEach(ShortcutCategory.allCases, id: \.rawValue) { category in
                shortcutCategorySection(category)
            }

            // 기본값 복원 버튼
            HStack {
                Spacer()
                Button(action: { showResetConfirm = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: Theme.iconSize(9), weight: .bold))
                        Text(NSLocalizedString("shortcut.reset.all", comment: ""))
                            .font(Theme.mono(9, weight: .bold))
                    }
                    .foregroundColor(Theme.red)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: Theme.cornerMedium).fill(Theme.red.opacity(0.08)))
                    .overlay(RoundedRectangle(cornerRadius: Theme.cornerMedium).stroke(Theme.red.opacity(0.2), lineWidth: 0.5))
                }
                .buttonStyle(.plain)
            }
        }
        .alert(NSLocalizedString("shortcut.reset.title", comment: ""), isPresented: $showResetConfirm) {
            Button(NSLocalizedString("shortcut.reset.confirm", comment: ""), role: .destructive) {
                manager.resetAllToDefaults()
            }
            Button(NSLocalizedString("cancel", comment: ""), role: .cancel) {}
        } message: {
            Text(NSLocalizedString("shortcut.reset.message", comment: ""))
        }
        .alert(item: $conflictAlert) { alert in
            Alert(
                title: Text(NSLocalizedString("shortcut.conflict.title", comment: "")),
                message: Text(conflictMessage(for: alert)),
                primaryButton: .default(Text(NSLocalizedString("shortcut.conflict.replace", comment: ""))) {
                    applyShortcutForce(alert.shortcut, for: alert.action, conflict: alert.conflict)
                },
                secondaryButton: .cancel(Text(NSLocalizedString("cancel", comment: "")))
            )
        }
    }

    private func shortcutCategorySection(_ category: ShortcutCategory) -> some View {
        let actions = ShortcutAction.allCases.filter { $0.category == category }

        return VStack(alignment: .leading, spacing: Theme.sp3) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Image(systemName: category.icon)
                        .font(.system(size: Theme.iconSize(10), weight: .medium))
                        .foregroundStyle(Theme.accentBackground)
                    Text(category.localizedName)
                        .font(Theme.mono(11, weight: .semibold))
                        .foregroundColor(Theme.textPrimary)
                }
            }

            VStack(spacing: 0) {
                ForEach(actions) { action in
                    shortcutRow(action)
                    if action != actions.last {
                        Rectangle().fill(Theme.border.opacity(0.3)).frame(height: 1)
                    }
                }
            }
            .background(RoundedRectangle(cornerRadius: Theme.cornerMedium).fill(Theme.bgSurface))
            .overlay(RoundedRectangle(cornerRadius: Theme.cornerMedium).stroke(Theme.border.opacity(0.4), lineWidth: 0.5))
        }
        .padding(Theme.sp4)
        .background(RoundedRectangle(cornerRadius: Theme.cornerLarge).fill(Theme.bgCard))
        .overlay(RoundedRectangle(cornerRadius: Theme.cornerLarge).stroke(Theme.border, lineWidth: 1))
    }

    private func shortcutRow(_ action: ShortcutAction) -> some View {
        let current = manager.shortcut(for: action)
        let isCustom = manager.isCustomized(action)

        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(action.localizedName)
                    .font(Theme.mono(10, weight: .medium))
                    .foregroundColor(Theme.textPrimary)
                if isCustom, let defaultShortcut = defaultShortcutMap[action] {
                    Text("\(NSLocalizedString("shortcut.default", comment: "")): \(defaultShortcut.displayString)")
                        .font(Theme.mono(8))
                        .foregroundColor(Theme.textDim)
                }
            }

            Spacer()

            HStack(spacing: 6) {
                KeyRecorderView(action: action, currentShortcut: current) { newShortcut in
                    handleShortcutChange(newShortcut, for: action)
                }

                if isCustom {
                    Button(action: { manager.resetToDefault(action) }) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: Theme.iconSize(9)))
                            .foregroundColor(Theme.textDim)
                    }
                    .buttonStyle(.plain)
                    .help(NSLocalizedString("shortcut.reset.single", comment: ""))
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
    }

    // MARK: - 충돌 처리

    private func handleShortcutChange(_ shortcut: KeyShortcut?, for action: ShortcutAction) {
        guard let shortcut else {
            manager.setShortcut(nil, for: action)
            return
        }

        let conflict = manager.checkConflict(shortcut, excludingAction: action)
        switch conflict {
        case .none:
            manager.setShortcut(shortcut, for: action)
        case .conflictsWithSystem, .conflictsWithAction:
            conflictAlert = ConflictAlertData(action: action, shortcut: shortcut, conflict: conflict)
        }
    }

    private func applyShortcutForce(_ shortcut: KeyShortcut, for action: ShortcutAction, conflict: ShortcutManager.ConflictResult) {
        if case .conflictsWithAction(let other) = conflict {
            // 충돌하는 기존 액션의 단축키를 해제
            manager.setShortcut(nil, for: other)
        }
        manager.setShortcut(shortcut, for: action)
    }

    private func conflictMessage(for alert: ConflictAlertData) -> String {
        switch alert.conflict {
        case .conflictsWithSystem:
            return String(format: NSLocalizedString("shortcut.conflict.system", comment: ""), alert.shortcut.displayString)
        case .conflictsWithAction(let other):
            return String(format: NSLocalizedString("shortcut.conflict.action", comment: ""), alert.shortcut.displayString, other.localizedName)
        case .none:
            return ""
        }
    }
}
