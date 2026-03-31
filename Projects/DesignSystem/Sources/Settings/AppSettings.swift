import SwiftUI
import UniformTypeIdentifiers

// ═══════════════════════════════════════════════════════
// MARK: - App Settings (전역 설정)
// ═══════════════════════════════════════════════════════

public class AppSettings: ObservableObject {
    public static let shared = AppSettings()

    public init() {}

    // ── Batch Update Support ──
    // Prevents multiple objectWillChange.send() calls during bulk settings changes.
    // Individual didSet calls still fire for single-property changes (needed for @ObservedObject).
    private var _batchUpdateInProgress = false

    /// Perform multiple settings changes with only a single objectWillChange notification.
    /// Use this from settings UI when changing multiple properties at once.
    public func performBatchUpdate(_ changes: () -> Void) {
        _batchUpdateInProgress = true
        changes()
        _batchUpdateInProgress = false
        objectWillChange.send()
        Theme.invalidateFontCache()
    }

    /// Sends objectWillChange only if not inside a batch update.
    private func notifyIfNeeded() {
        guard !_batchUpdateInProgress else { return }
        objectWillChange.send()
    }

    @AppStorage("isDarkMode") public var isDarkMode: Bool = false {
        didSet { notifyIfNeeded() }
    }

    // themeMode: "light" | "dark" | "custom"
    // 빈 문자열이면 isDarkMode에서 파생 (기존 사용자 마이그레이션)
    @AppStorage("themeMode") private var _themeMode: String = ""

    public var themeMode: String {
        get { _themeMode.isEmpty ? (isDarkMode ? "dark" : "light") : _themeMode }
        set {
            _themeMode = newValue
            if newValue == "light" { isDarkMode = false }
            else if newValue == "dark" { isDarkMode = true }
            notifyIfNeeded()
        }
    }
    @AppStorage("fontSizeScale") public var fontSizeScale: Double = 1.5 {
        didSet { notifyIfNeeded() }
    }

    // ── 오피스 뷰 모드 ──
    @AppStorage("officeViewMode") public var officeViewMode: String = "grid" {
        didSet { notifyIfNeeded() }
    }
    @AppStorage("officePreset") public var officePreset: String = "cozy" {
        didSet { notifyIfNeeded() }
    }

    // ── 배경 테마 ──
    @AppStorage("backgroundTheme") public var backgroundTheme: String = "auto" {
        didSet { notifyIfNeeded() }
    }

    // ── 커스텀 테마 (JSON) ──
    @AppStorage("customThemeJSON") public var customThemeJSON: String = "" {
        didSet {
            _cachedCustomTheme = nil
            notifyIfNeeded()
        }
    }

    private var _cachedCustomTheme: CustomThemeConfig?

    public var customTheme: CustomThemeConfig {
        if let cached = _cachedCustomTheme { return cached }
        guard !customThemeJSON.isEmpty,
              let data = customThemeJSON.data(using: .utf8),
              let config = try? JSONDecoder().decode(CustomThemeConfig.self, from: data) else {
            return .default
        }
        _cachedCustomTheme = config
        return config
    }

    public func saveCustomTheme(_ config: CustomThemeConfig) {
        if let data = try? JSONEncoder().encode(config),
           let json = String(data: data, encoding: .utf8) {
            customThemeJSON = json
        }
    }

    public func exportThemeToFile() {
        let config = customTheme
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(config) else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "doffice_theme.json"
        panel.title = NSLocalizedString("settings.customtheme.export", comment: "")
        if panel.runModal() == .OK, let url = panel.url {
            try? data.write(to: url)
        }
    }

    public func importThemeFromFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.title = NSLocalizedString("settings.customtheme.import", comment: "")
        if panel.runModal() == .OK, let url = panel.url {
            guard let data = try? Data(contentsOf: url),
                  let config = try? JSONDecoder().decode(CustomThemeConfig.self, from: data) else { return }
            saveCustomTheme(config)
        }
    }

    // ── 자동화/성능 보호 설정 ──
    @AppStorage("reviewerMaxPasses") public var reviewerMaxPasses: Int = 2 {
        didSet { notifyIfNeeded() }
    }
    @AppStorage("qaMaxPasses") public var qaMaxPasses: Int = 2 {
        didSet { notifyIfNeeded() }
    }
    @AppStorage("automationRevisionLimit") public var automationRevisionLimit: Int = 3 {
        didSet { notifyIfNeeded() }
    }
    @AppStorage("allowParallelSubagents") public var allowParallelSubagents: Bool = false {
        didSet { notifyIfNeeded() }
    }
    @AppStorage("terminalSidebarLightweight") public var terminalSidebarLightweight: Bool = true {
        didSet { notifyIfNeeded() }
    }

    // ── 성능 모드 ──
    @AppStorage("performanceMode") public var performanceMode: Bool = false {
        didSet { notifyIfNeeded() }
    }
    @AppStorage("autoPerformanceMode") public var autoPerformanceMode: Bool = true {
        didSet { notifyIfNeeded() }
    }

    /// 외부에서 세션 수를 주입 (DofficeKit에서 SessionManager.shared.tabs.count 바인딩)
    public var activeTabCount: Int = 0

    public var effectivePerformanceMode: Bool {
        if performanceMode { return true }
        if autoPerformanceMode {
            // 10개 이상 세션이면 자동 성능 모드
            return activeTabCount >= 10
        }
        return false
    }

    // ── 언어 설정 ──
    // "auto" = 시스템 언어 따르기, "ko"/"en"/"ja" = 강제 지정
    @AppStorage("appLanguage") public var appLanguage: String = "auto" {
        didSet {
            notifyIfNeeded()
            applyLanguage()
        }
    }

    public func applyLanguage() {
        if appLanguage == "auto" {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.set([appLanguage], forKey: "AppleLanguages")
        }
    }

    public var currentLanguageLabel: String {
        switch appLanguage {
        case "ko": return NSLocalizedString("theme.lang.korean", comment: "")
        case "en": return "English"
        case "ja": return "日本語"
        default: return NSLocalizedString("settings.language.system", comment: "")
        }
    }

    // ── 터미널 모드 ──
    @AppStorage("rawTerminalMode") public var rawTerminalMode: Bool = false {
        didSet { notifyIfNeeded() }
    }

    // ── 자동 새로고침 ──
    @AppStorage("autoRefreshOnSettingsChange") public var autoRefreshOnSettingsChange: Bool = true {
        didSet { notifyIfNeeded() }
    }

    /// 설정 변경 후 새로고침 요청 (autoRefresh가 꺼져 있으면 알림만)
    @Published public var pendingRefresh: Bool = false

    public func requestRefreshIfNeeded() {
        if autoRefreshOnSettingsChange {
            NotificationCenter.default.post(name: .dofficeRefresh, object: nil)
        } else {
            pendingRefresh = true
        }
    }

    // ── 휴게실 가구 설정 (UI 빈도 낮음 → didSet 불필요) ──
    @AppStorage("breakRoomShowSofa") public var breakRoomShowSofa: Bool = true
    @AppStorage("breakRoomShowCoffeeMachine") public var breakRoomShowCoffeeMachine: Bool = true
    @AppStorage("breakRoomShowPlant") public var breakRoomShowPlant: Bool = true
    @AppStorage("breakRoomShowSideTable") public var breakRoomShowSideTable: Bool = true
    @AppStorage("breakRoomShowClock") public var breakRoomShowClock: Bool = true
    @AppStorage("breakRoomShowPicture") public var breakRoomShowPicture: Bool = true
    @AppStorage("breakRoomShowNeonSign") public var breakRoomShowNeonSign: Bool = true
    @AppStorage("breakRoomShowRug") public var breakRoomShowRug: Bool = true
    // 새 악세서리
    @AppStorage("breakRoomShowBookshelf") public var breakRoomShowBookshelf: Bool = false
    @AppStorage("breakRoomShowAquarium") public var breakRoomShowAquarium: Bool = false
    @AppStorage("breakRoomShowArcade") public var breakRoomShowArcade: Bool = false
    @AppStorage("breakRoomShowWhiteboard") public var breakRoomShowWhiteboard: Bool = false
    @AppStorage("breakRoomShowLamp") public var breakRoomShowLamp: Bool = false
    @AppStorage("breakRoomShowCat") public var breakRoomShowCat: Bool = false
    @AppStorage("breakRoomShowTV") public var breakRoomShowTV: Bool = false
    @AppStorage("breakRoomShowFan") public var breakRoomShowFan: Bool = false
    @AppStorage("breakRoomShowCalendar") public var breakRoomShowCalendar: Bool = false
    @AppStorage("breakRoomShowPoster") public var breakRoomShowPoster: Bool = false
    @AppStorage("breakRoomShowTrashcan") public var breakRoomShowTrashcan: Bool = false
    @AppStorage("breakRoomShowCushion") public var breakRoomShowCushion: Bool = false

    // ── 가구 위치 (JSON) ──
    @AppStorage("furniturePositionsJSON") public var furniturePositionsJSON: String = ""

    // ── 앱/회사 이름 ──
    @AppStorage("appDisplayName") public var appDisplayName: String = "도피스" {
        didSet { notifyIfNeeded() }
    }
    @AppStorage("companyName") public var companyName: String = "" {
        didSet { notifyIfNeeded() }
    }
    @AppStorage("coffeeSupportEnabled") public var coffeeSupportEnabled: Bool = true {
        didSet { notifyIfNeeded() }
    }
    @AppStorage("coffeeSupportButtonTitle") public var coffeeSupportButtonTitle: String = "후원하기" {
        didSet { notifyIfNeeded() }
    }
    @AppStorage("coffeeSupportMessage") public var coffeeSupportMessage: String = "카카오뱅크 7777015832634로 커피 후원해주세요. 카카오뱅크나 토스를 열면 계좌가 먼저 복사됩니다." {
        didSet { notifyIfNeeded() }
    }
    @AppStorage("coffeeSupportBankName") public var coffeeSupportBankName: String = "카카오뱅크" {
        didSet { notifyIfNeeded() }
    }
    @AppStorage("coffeeSupportAccountNumber") public var coffeeSupportAccountNumber: String = "7777015832634" {
        didSet { notifyIfNeeded() }
    }
    @AppStorage("coffeeSupportURL") public var coffeeSupportURL: String = "" {
        didSet { notifyIfNeeded() }
    }
    @AppStorage("coffeeSupportCopyValue") public var coffeeSupportCopyValue: String = "" {
        didSet { notifyIfNeeded() }
    }
    @AppStorage("coffeeSupportPresetVersion") private var coffeeSupportPresetVersion: Int = 0

    // ── 편집 모드 ──
    @Published public var isEditMode: Bool = false

    // ── 보안 설정 ──
    @AppStorage("dailyCostLimit") public var dailyCostLimit: Double = 0 {  // 0 = 무제한
        didSet { notifyIfNeeded() }
    }
    @AppStorage("perSessionCostLimit") public var perSessionCostLimit: Double = 0 {
        didSet { notifyIfNeeded() }
    }
    @AppStorage("costWarningAt80") public var costWarningAt80: Bool = true {
        didSet { notifyIfNeeded() }
    }

    // ── 온보딩 ──
    @AppStorage("hasCompletedOnboarding") public var hasCompletedOnboarding: Bool = false {
        didSet { notifyIfNeeded() }
    }

    // ── 결제일 알림 ──
    @AppStorage("billingDay") public var billingDay: Int = 0  // 0 = 미설정, 1~31
    @AppStorage("billingLastNotifiedMonth") public var billingLastNotifiedMonth: String = ""

    // ── 세션 잠금 ──
    @AppStorage("lockPIN") public var lockPIN: String = ""
    @AppStorage("autoLockMinutes") public var autoLockMinutes: Int = 0  // 0 = 비활성
    @Published public var isLocked: Bool = false

    public var colorScheme: ColorScheme { isDarkMode ? .dark : .light }

    public var coffeeSupportDisplayTitle: String {
        let trimmed = coffeeSupportButtonTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? NSLocalizedString("coffee.default.button", comment: "") : trimmed
    }

    public var trimmedCoffeeSupportBankName: String {
        coffeeSupportBankName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var trimmedCoffeeSupportAccountNumber: String {
        coffeeSupportAccountNumber.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var coffeeSupportAccountDisplayText: String {
        let bank = trimmedCoffeeSupportBankName.isEmpty ? NSLocalizedString("coffee.default.bank", comment: "") : trimmedCoffeeSupportBankName
        let account = trimmedCoffeeSupportAccountNumber.isEmpty ? "7777015832634" : trimmedCoffeeSupportAccountNumber
        return "\(bank) \(account)"
    }

    public var trimmedCoffeeSupportURL: String {
        coffeeSupportURL.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var trimmedCoffeeSupportCopyValue: String {
        coffeeSupportCopyValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var normalizedCoffeeSupportURL: URL? {
        Self.normalizedCoffeeSupportURL(from: trimmedCoffeeSupportURL)
    }

    public var hasCoffeeSupportDestination: Bool {
        !trimmedCoffeeSupportAccountNumber.isEmpty || normalizedCoffeeSupportURL != nil || !trimmedCoffeeSupportCopyValue.isEmpty
    }

    // ── 가구 위치 헬퍼 ──
    public func furniturePosition(for id: String) -> CGPoint? {
        guard !furniturePositionsJSON.isEmpty,
              let data = furniturePositionsJSON.data(using: .utf8),
              let dict = try? JSONDecoder().decode([String: [Double]].self, from: data),
              let arr = dict[id], arr.count == 2 else { return nil }
        return CGPoint(x: arr[0], y: arr[1])
    }

    public func setFurniturePosition(_ pos: CGPoint, for id: String) {
        var dict: [String: [Double]] = [:]
        if !furniturePositionsJSON.isEmpty,
           let data = furniturePositionsJSON.data(using: .utf8),
           let existing = try? JSONDecoder().decode([String: [Double]].self, from: data) {
            dict = existing
        }
        dict[id] = [Double(pos.x), Double(pos.y)]
        if let data = try? JSONEncoder().encode(dict), let json = String(data: data, encoding: .utf8) {
            furniturePositionsJSON = json
        }
    }

    public func resetFurniturePositions() {
        furniturePositionsJSON = ""
    }

    public func ensureCoffeeSupportPreset() {
        let targetVersion = 1
        guard coffeeSupportPresetVersion < targetVersion else { return }

        let currentTitle = coffeeSupportButtonTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if currentTitle.isEmpty || currentTitle == "커피 후원" {
            coffeeSupportButtonTitle = "후원하기"
        }

        let currentMessage = coffeeSupportMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        if currentMessage.isEmpty || currentMessage == "이 앱이 도움이 되셨다면 커피 한 잔으로 응원해주세요." {
            coffeeSupportMessage = "카카오뱅크 7777015832634로 커피 후원해주세요. 카카오뱅크나 토스를 열면 계좌가 먼저 복사됩니다."
        }

        if trimmedCoffeeSupportBankName.isEmpty {
            coffeeSupportBankName = "카카오뱅크"
        }
        if trimmedCoffeeSupportAccountNumber.isEmpty {
            coffeeSupportAccountNumber = "7777015832634"
        }
        if trimmedCoffeeSupportCopyValue.isEmpty {
            coffeeSupportCopyValue = coffeeSupportAccountDisplayText
        }

        coffeeSupportPresetVersion = targetVersion
    }

    public func coffeeSupportURL(for tier: CoffeeSupportTier) -> URL? {
        Self.normalizedCoffeeSupportURL(from: renderCoffeeSupportTemplate(trimmedCoffeeSupportURL, tier: tier))
    }

    public func coffeeSupportCopyText(for tier: CoffeeSupportTier) -> String {
        renderCoffeeSupportTemplate(trimmedCoffeeSupportCopyValue, tier: tier)
    }

    private func renderCoffeeSupportTemplate(_ template: String, tier: CoffeeSupportTier) -> String {
        guard !template.isEmpty else { return "" }
        let replacements: [String: String] = [
            "{{amount}}": "\(tier.amount)",
            "{{amount_text}}": tier.amountLabel,
            "{{tier}}": tier.title,
            "{{app_name}}": appDisplayName
        ]

        var rendered = template
        for (token, value) in replacements {
            rendered = rendered.replacingOccurrences(of: token, with: value)
        }
        return rendered.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalizedCoffeeSupportURL(from raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let url = URL(string: trimmed), let scheme = url.scheme, !scheme.isEmpty {
            return url
        }

        return URL(string: "https://" + trimmed)
    }

    // ── 레이아웃 프리셋 ──

    public struct LayoutPreset: Codable, Identifiable {
        public let id: String
        public var name: String
        public var viewModeRaw: Int
        public var sidebarWidth: Double
        public var isDarkMode: Bool
        public var fontSizeScale: Double

        public init(id: String, name: String, viewModeRaw: Int, sidebarWidth: Double, isDarkMode: Bool, fontSizeScale: Double) {
            self.id = id
            self.name = name
            self.viewModeRaw = viewModeRaw
            self.sidebarWidth = sidebarWidth
            self.isDarkMode = isDarkMode
            self.fontSizeScale = fontSizeScale
        }
    }

    @AppStorage("layoutPresets") public var layoutPresetsData: Data = Data()

    public var layoutPresets: [LayoutPreset] {
        get { (try? JSONDecoder().decode([LayoutPreset].self, from: layoutPresetsData)) ?? [] }
        set { layoutPresetsData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    public func saveCurrentAsPreset(name: String, viewModeRaw: Int, sidebarWidth: Double) {
        var presets = layoutPresets
        let preset = LayoutPreset(
            id: UUID().uuidString, name: name,
            viewModeRaw: viewModeRaw, sidebarWidth: sidebarWidth,
            isDarkMode: isDarkMode, fontSizeScale: fontSizeScale
        )
        presets.append(preset)
        layoutPresets = presets
    }

    public func applyPreset(_ preset: LayoutPreset) {
        isDarkMode = preset.isDarkMode
        fontSizeScale = preset.fontSizeScale
    }

    public func deletePreset(_ id: String) {
        var presets = layoutPresets
        presets.removeAll { $0.id == id }
        layoutPresets = presets
    }
}


public enum AutomationTemplateKind: String, CaseIterable, Identifiable {
    case planner
    case designer
    case developerExecution
    case developerRevision
    case reviewer
    case qa
    case reporter
    case sre

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .planner: return NSLocalizedString("template.pipeline.planner", comment: "")
        case .designer: return NSLocalizedString("template.pipeline.designer", comment: "")
        case .developerExecution: return NSLocalizedString("template.pipeline.dev.exec", comment: "")
        case .developerRevision: return NSLocalizedString("template.pipeline.dev.revision", comment: "")
        case .reviewer: return NSLocalizedString("template.pipeline.reviewer", comment: "")
        case .qa: return "QA"
        case .reporter: return NSLocalizedString("template.pipeline.reporter", comment: "")
        case .sre: return "SRE"
        }
    }

    public var shortLabel: String {
        switch self {
        case .developerExecution: return NSLocalizedString("template.pipeline.dev.exec.short", comment: "")
        case .developerRevision: return NSLocalizedString("template.pipeline.dev.revision.short", comment: "")
        default: return displayName
        }
    }

    public var icon: String {
        switch self {
        case .planner: return "list.bullet.rectangle.portrait.fill"
        case .designer: return "paintbrush.pointed.fill"
        case .developerExecution: return "hammer.fill"
        case .developerRevision: return "arrow.triangle.2.circlepath"
        case .reviewer: return "checklist.checked"
        case .qa: return "checkmark.seal.fill"
        case .reporter: return "doc.text.fill"
        case .sre: return "server.rack"
        }
    }

    public var summary: String {
        switch self {
        case .planner: return NSLocalizedString("template.pipeline.planner.desc", comment: "")
        case .designer: return NSLocalizedString("template.pipeline.designer.desc", comment: "")
        case .developerExecution: return NSLocalizedString("template.pipeline.dev.exec.desc", comment: "")
        case .developerRevision: return NSLocalizedString("template.pipeline.dev.revision.desc", comment: "")
        case .reviewer: return NSLocalizedString("template.pipeline.reviewer.desc", comment: "")
        case .qa: return NSLocalizedString("template.pipeline.qa.desc", comment: "")
        case .reporter: return NSLocalizedString("template.pipeline.reporter.desc", comment: "")
        case .sre: return NSLocalizedString("template.pipeline.sre.desc", comment: "")
        }
    }

    public var placeholderTokens: [String] {
        switch self {
        case .planner:
            return ["{{project_name}}", "{{project_path}}", "{{request}}"]
        case .designer:
            return ["{{project_name}}", "{{project_path}}", "{{request}}", "{{plan_summary}}"]
        case .developerExecution:
            return ["{{project_name}}", "{{project_path}}", "{{request}}", "{{plan_summary}}", "{{design_summary}}"]
        case .developerRevision:
            return ["{{project_name}}", "{{project_path}}", "{{request}}", "{{plan_summary}}", "{{design_summary}}", "{{feedback_role}}", "{{feedback}}"]
        case .reviewer:
            return ["{{project_name}}", "{{project_path}}", "{{request}}", "{{plan_summary}}", "{{design_summary}}", "{{dev_summary}}", "{{changed_files}}"]
        case .qa:
            return ["{{project_name}}", "{{project_path}}", "{{request}}", "{{plan_summary}}", "{{design_summary}}", "{{dev_summary}}", "{{review_summary}}", "{{changed_files}}"]
        case .reporter:
            return ["{{project_name}}", "{{report_path}}", "{{request}}", "{{plan_summary}}", "{{design_summary}}", "{{dev_summary}}", "{{review_summary}}", "{{qa_summary}}", "{{validation_summary}}", "{{changed_files}}"]
        case .sre:
            return ["{{project_name}}", "{{project_path}}", "{{request}}", "{{dev_summary}}", "{{qa_summary}}", "{{validation_summary}}", "{{changed_files}}"]
        }
    }

    public var pinnedLines: [String] {
        switch self {
        case .planner:
            return ["PLANNER_STATUS: READY"]
        case .designer:
            return ["DESIGN_STATUS: READY"]
        case .reviewer:
            return ["REVIEW_STATUS: PASS", "REVIEW_STATUS: FAIL", "REVIEW_STATUS: BLOCKED"]
        case .qa:
            return ["QA_STATUS: PASS", "QA_STATUS: FAIL", "QA_STATUS: BLOCKED"]
        case .reporter:
            return ["REPORT_STATUS: WRITTEN", "REPORT_PATH: {{report_path}}"]
        case .sre:
            return ["SRE_STATUS: CHECKED"]
        case .developerExecution, .developerRevision:
            return []
        }
    }

    public var defaultTemplate: String {
        switch self {
        case .planner:
            return """
당신은 도피스의 기획자입니다.
아래 사용자 요구사항을 보고 개발자가 바로 구현할 수 있게 정리하세요.

프로젝트: {{project_name}}
경로: {{project_path}}

사용자 요구사항:
{{request}}

정리 양식:
- 요구사항 한 줄 요약
- 반드시 구현할 핵심 항목
- 수용 기준
- 주의할 점
- 디자이너/개발자 메모
"""
        case .designer:
            return """
당신은 도피스의 디자이너입니다.
아래 요구사항과 기획 요약을 바탕으로 UI/UX, 상호작용, 화면 흐름 관점의 정리본을 만들어 주세요.

프로젝트: {{project_name}}
경로: {{project_path}}

원래 요구사항:
{{request}}

기획 요약:
{{plan_summary}}

정리 양식:
- 화면/상태 흐름
- 사용자 경험상 주의할 점
- edge case
- 개발 메모
"""
        case .developerExecution:
            return """
아래 요구사항을 구현하세요.

프로젝트: {{project_name}}
경로: {{project_path}}

원래 요구사항:
{{request}}

기획 요약:
{{plan_summary}}

디자인/경험 메모:
{{design_summary}}

구현 지침:
1. 필요한 코드를 직접 수정하세요.
2. 변경 파일과 검증 결과를 명확히 남기세요.
3. 작업을 마치면 완료 요약을 짧게 정리하세요.
"""
        case .developerRevision:
            return """
아래 요구사항을 다시 구현하세요.

프로젝트: {{project_name}}
경로: {{project_path}}

원래 요구사항:
{{request}}

기획 요약:
{{plan_summary}}

디자인/경험 메모:
{{design_summary}}

추가 수정 피드백 ({{feedback_role}}):
{{feedback}}

재작업 지침:
1. 피드백을 반영해 필요한 코드를 직접 수정하세요.
2. 어떤 점을 고쳤는지 완료 요약에 꼭 포함하세요.
3. 검증 결과까지 함께 남기세요.
"""
        case .reviewer:
            return """
당신은 도피스의 코드 리뷰어입니다.
아래 개발 작업이 완료되었고 코드 수정도 발생했습니다. 코드는 수정하지 말고, 변경 내용과 리스크를 검토하세요.

프로젝트: {{project_name}}
경로: {{project_path}}

최근 요구사항:
{{request}}

기획 요약:
{{plan_summary}}

디자인 요약:
{{design_summary}}

개발 완료 요약:
{{dev_summary}}

변경된 파일:
{{changed_files}}

검토 양식:
- 핵심 findings
- 테스트/검증 부족
- 오픈 질문 또는 우려점
- 최종 판단
"""
        case .qa:
            return """
당신은 도피스의 QA 담당자입니다.
아래 개발 작업이 완료되었습니다. 변경된 흐름을 직접 실행/테스트해 검증하세요.

프로젝트: {{project_name}}
경로: {{project_path}}

최근 요구사항:
{{request}}

기획 요약:
{{plan_summary}}

디자인 요약:
{{design_summary}}

개발 완료 요약:
{{dev_summary}}

코드 리뷰 요약:
{{review_summary}}

변경된 파일:
{{changed_files}}

검증 양식:
- 실제로 실행/테스트한 항목
- 확인 결과
- 재현 단계 또는 관찰 내용
- 남은 리스크
- 최종 판단
"""
        case .reporter:
            return """
당신은 도피스의 보고자입니다.
최종 Markdown 보고서를 작성하세요.

프로젝트: {{project_name}}
저장 경로: {{report_path}}

원래 요구사항:
{{request}}

기획 요약:
{{plan_summary}}

디자인 요약:
{{design_summary}}

개발 결과 요약:
{{dev_summary}}

코드 리뷰 요약:
{{review_summary}}

QA 결과:
{{qa_summary}}

추가 검증 요약:
{{validation_summary}}

변경 파일:
{{changed_files}}

보고서 기본 구조 (첫 줄의 주석은 반드시 포함하세요):
<!-- 도피스:Reporter -->
# 작업 보고서
## 요구사항
## 구현 결과
## QA 검증 결과
## 변경 파일
## 남은 리스크 및 다음 단계
"""
        case .sre:
            return """
당신은 도피스의 SRE입니다.
아래 구현 결과를 운영/배포/실행 안정성 관점에서 점검하세요.

프로젝트: {{project_name}}
경로: {{project_path}}

원래 요구사항:
{{request}}

개발 결과 요약:
{{dev_summary}}

QA 요약:
{{qa_summary}}

추가 검증 요약:
{{validation_summary}}

변경 파일:
{{changed_files}}

점검 양식:
- 배포/실행 리스크
- 환경 변수/설정 포인트
- 모니터링/알람 제안
- 롤백/수동 점검 포인트
- 최종 안정성 메모
"""
        }
    }

    public var automationContract: String {
        switch self {
        case .planner:
            return """
자동화 상태 계약:
- 응답 마지막 줄에 정확히 아래 한 줄을 남기세요.
PLANNER_STATUS: READY
"""
        case .designer:
            return """
자동화 상태 계약:
- 응답 마지막 줄에 정확히 아래 한 줄을 남기세요.
DESIGN_STATUS: READY
"""
        case .reviewer:
            return """
자동화 상태 계약:
- 응답 마지막 줄에는 아래 셋 중 하나만 정확히 한 줄로 남기세요.
REVIEW_STATUS: PASS
REVIEW_STATUS: FAIL
REVIEW_STATUS: BLOCKED
"""
        case .qa:
            return """
자동화 상태 계약:
- 응답 마지막 줄에는 아래 셋 중 하나만 정확히 한 줄로 남기세요.
QA_STATUS: PASS
QA_STATUS: FAIL
QA_STATUS: BLOCKED
"""
        case .reporter:
            return """
자동화 상태 계약:
- {{report_path}} 파일을 Markdown으로 작성하거나 갱신하세요.
- 응답 마지막 두 줄을 정확히 아래처럼 남기세요.
REPORT_STATUS: WRITTEN
REPORT_PATH: {{report_path}}
"""
        case .sre:
            return """
자동화 상태 계약:
- 응답 마지막 줄에 정확히 아래 한 줄을 남기세요.
SRE_STATUS: CHECKED
"""
        case .developerExecution, .developerRevision:
            return ""
        }
    }
}

public final class AutomationTemplateStore: ObservableObject {
    public static let shared = AutomationTemplateStore()

    private let saveKey = "doffice.automation.templates.v1"
    private let persistenceQueue = DispatchQueue(label: "doffice.automation-template-store", qos: .utility)
    private var saveWorkItem: DispatchWorkItem?
    @Published public private(set) var revision: Int = 0

    private var overrides: [String: String] = [:]

    private init() {
        load()
    }

    public func template(for kind: AutomationTemplateKind) -> String {
        overrides[kind.rawValue] ?? kind.defaultTemplate
    }

    public func binding(for kind: AutomationTemplateKind) -> Binding<String> {
        Binding(
            get: { self.template(for: kind) },
            set: { self.setTemplate($0, for: kind) }
        )
    }

    public func isCustomized(_ kind: AutomationTemplateKind) -> Bool {
        overrides[kind.rawValue] != nil
    }

    public func setTemplate(_ text: String, for kind: AutomationTemplateKind) {
        if text == kind.defaultTemplate {
            overrides.removeValue(forKey: kind.rawValue)
        } else {
            overrides[kind.rawValue] = text
        }
        revision &+= 1
        scheduleSave()
    }

    public func reset(_ kind: AutomationTemplateKind) {
        overrides.removeValue(forKey: kind.rawValue)
        revision &+= 1
        scheduleSave()
    }

    public func resetAll() {
        overrides.removeAll()
        revision &+= 1
        scheduleSave()
    }

    public func render(_ kind: AutomationTemplateKind, context: [String: String]) -> String {
        let body = renderText(template(for: kind), context: context)
        let contract = renderText(kind.automationContract, context: context)
        guard !contract.isEmpty else { return body }
        return body + "\n\n" + contract
    }

    private func renderText(_ template: String, context: [String: String]) -> String {
        var rendered = template
        for (key, value) in context {
            rendered = rendered.replacingOccurrences(of: "{{\(key)}}", with: value)
        }
        return rendered
    }

    private func scheduleSave(delay: TimeInterval = 0.25) {
        saveWorkItem?.cancel()
        let snapshot = overrides
        let key = saveKey
        let workItem = DispatchWorkItem {
            if snapshot.isEmpty {
                UserDefaults.standard.removeObject(forKey: key)
            } else if let data = try? JSONEncoder().encode(snapshot) {
                UserDefaults.standard.set(data, forKey: key)
            }
        }
        saveWorkItem = workItem
        persistenceQueue.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: saveKey),
              let decoded = try? JSONDecoder().decode([String: String].self, from: data) else {
            return
        }
        overrides = decoded
    }
}


public struct CoffeeSupportTier: Identifiable, Hashable {
    public let id: String
    public let title: String
    public let subtitle: String
    public let amount: Int
    public let icon: String

    public init(id: String, title: String, subtitle: String, amount: Int, icon: String) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.amount = amount
        self.icon = icon
    }

    private static let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }()

    public var amountLabel: String {
        let number = NSNumber(value: amount)
        let formatted = Self.formatter.string(from: number) ?? "\(amount)"
        return "\(formatted)원"
    }

    public var tint: Color {
        switch id {
        case "starter": return Theme.orange
        case "booster": return Theme.cyan
        default: return Theme.pink
        }
        
    }

    public static let presets: [CoffeeSupportTier] = [
        CoffeeSupportTier(id: "starter", title: NSLocalizedString("coffee.tier.americano", comment: ""), subtitle: NSLocalizedString("coffee.tier.americano.sub", comment: ""), amount: 3000, icon: "cup.and.saucer.fill"),
        CoffeeSupportTier(id: "booster", title: NSLocalizedString("coffee.tier.latte", comment: ""), subtitle: NSLocalizedString("coffee.tier.latte.sub", comment: ""), amount: 5000, icon: "mug.fill"),
        CoffeeSupportTier(id: "nightshift", title: NSLocalizedString("coffee.tier.nightshift", comment: ""), subtitle: NSLocalizedString("coffee.tier.nightshift.sub", comment: ""), amount: 10000, icon: "takeoutbag.and.cup.and.straw.fill")
    ]
}
