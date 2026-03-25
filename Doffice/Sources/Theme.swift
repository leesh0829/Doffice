import SwiftUI
import UniformTypeIdentifiers

// ═══════════════════════════════════════════════════════
// MARK: - App Settings (전역 설정)
// ═══════════════════════════════════════════════════════

class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @AppStorage("isDarkMode") var isDarkMode: Bool = false {
        didSet { objectWillChange.send() }
    }
    @AppStorage("fontSizeScale") var fontSizeScale: Double = 1.5 {
        didSet { objectWillChange.send() }
    }

    // ── 오피스 뷰 모드 ──
    @AppStorage("officeViewMode") var officeViewMode: String = "grid" {
        didSet { objectWillChange.send() }
    }
    @AppStorage("officePreset") var officePreset: String = OfficePreset.cozy.rawValue {
        didSet { objectWillChange.send() }
    }

    // ── 배경 테마 ──
    @AppStorage("backgroundTheme") var backgroundTheme: String = "auto" {
        didSet { objectWillChange.send() }
    }

    // ── 자동화/성능 보호 설정 ──
    @AppStorage("reviewerMaxPasses") var reviewerMaxPasses: Int = 2 {
        didSet { objectWillChange.send() }
    }
    @AppStorage("qaMaxPasses") var qaMaxPasses: Int = 2 {
        didSet { objectWillChange.send() }
    }
    @AppStorage("automationRevisionLimit") var automationRevisionLimit: Int = 3 {
        didSet { objectWillChange.send() }
    }
    @AppStorage("allowParallelSubagents") var allowParallelSubagents: Bool = false {
        didSet { objectWillChange.send() }
    }
    @AppStorage("terminalSidebarLightweight") var terminalSidebarLightweight: Bool = true {
        didSet { objectWillChange.send() }
    }

    // ── 성능 모드 ──
    @AppStorage("performanceMode") var performanceMode: Bool = false {
        didSet { objectWillChange.send() }
    }
    @AppStorage("autoPerformanceMode") var autoPerformanceMode: Bool = true {
        didSet { objectWillChange.send() }
    }

    var effectivePerformanceMode: Bool {
        if performanceMode { return true }
        if autoPerformanceMode {
            // 10개 이상 세션이면 자동 성능 모드
            return SessionManager.shared.tabs.count >= 10
        }
        return false
    }

    // ── 언어 설정 ──
    // "auto" = 시스템 언어 따르기, "ko"/"en"/"ja" = 강제 지정
    @AppStorage("appLanguage") var appLanguage: String = "auto" {
        didSet {
            objectWillChange.send()
            applyLanguage()
        }
    }

    func applyLanguage() {
        if appLanguage == "auto" {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.set([appLanguage], forKey: "AppleLanguages")
        }
    }

    var currentLanguageLabel: String {
        switch appLanguage {
        case "ko": return NSLocalizedString("theme.lang.korean", comment: "")
        case "en": return "English"
        case "ja": return "日本語"
        default: return NSLocalizedString("settings.language.system", comment: "")
        }
    }

    // ── 터미널 모드 ──
    @AppStorage("rawTerminalMode") var rawTerminalMode: Bool = false {
        didSet { objectWillChange.send() }
    }

    // ── 자동 새로고침 ──
    @AppStorage("autoRefreshOnSettingsChange") var autoRefreshOnSettingsChange: Bool = true {
        didSet { objectWillChange.send() }
    }

    /// 설정 변경 후 새로고침 요청 (autoRefresh가 꺼져 있으면 알림만)
    @Published var pendingRefresh: Bool = false

    func requestRefreshIfNeeded() {
        if autoRefreshOnSettingsChange {
            NotificationCenter.default.post(name: .workmanRefresh, object: nil)
        } else {
            pendingRefresh = true
        }
    }

    // ── 휴게실 가구 설정 (UI 빈도 낮음 → didSet 불필요) ──
    @AppStorage("breakRoomShowSofa") var breakRoomShowSofa: Bool = true
    @AppStorage("breakRoomShowCoffeeMachine") var breakRoomShowCoffeeMachine: Bool = true
    @AppStorage("breakRoomShowPlant") var breakRoomShowPlant: Bool = true
    @AppStorage("breakRoomShowSideTable") var breakRoomShowSideTable: Bool = true
    @AppStorage("breakRoomShowClock") var breakRoomShowClock: Bool = true
    @AppStorage("breakRoomShowPicture") var breakRoomShowPicture: Bool = true
    @AppStorage("breakRoomShowNeonSign") var breakRoomShowNeonSign: Bool = true
    @AppStorage("breakRoomShowRug") var breakRoomShowRug: Bool = true
    // 새 악세서리
    @AppStorage("breakRoomShowBookshelf") var breakRoomShowBookshelf: Bool = false
    @AppStorage("breakRoomShowAquarium") var breakRoomShowAquarium: Bool = false
    @AppStorage("breakRoomShowArcade") var breakRoomShowArcade: Bool = false
    @AppStorage("breakRoomShowWhiteboard") var breakRoomShowWhiteboard: Bool = false
    @AppStorage("breakRoomShowLamp") var breakRoomShowLamp: Bool = false
    @AppStorage("breakRoomShowCat") var breakRoomShowCat: Bool = false
    @AppStorage("breakRoomShowTV") var breakRoomShowTV: Bool = false
    @AppStorage("breakRoomShowFan") var breakRoomShowFan: Bool = false
    @AppStorage("breakRoomShowCalendar") var breakRoomShowCalendar: Bool = false
    @AppStorage("breakRoomShowPoster") var breakRoomShowPoster: Bool = false
    @AppStorage("breakRoomShowTrashcan") var breakRoomShowTrashcan: Bool = false
    @AppStorage("breakRoomShowCushion") var breakRoomShowCushion: Bool = false

    // ── 가구 위치 (JSON) ──
    @AppStorage("furniturePositionsJSON") var furniturePositionsJSON: String = ""

    // ── 앱/회사 이름 ──
    @AppStorage("appDisplayName") var appDisplayName: String = "도피스" {
        didSet { objectWillChange.send() }
    }
    @AppStorage("companyName") var companyName: String = "" {
        didSet { objectWillChange.send() }
    }
    @AppStorage("coffeeSupportEnabled") var coffeeSupportEnabled: Bool = true {
        didSet { objectWillChange.send() }
    }
    @AppStorage("coffeeSupportButtonTitle") var coffeeSupportButtonTitle: String = "후원하기" {
        didSet { objectWillChange.send() }
    }
    @AppStorage("coffeeSupportMessage") var coffeeSupportMessage: String = "카카오뱅크 7777015832634로 커피 후원해주세요. 카카오뱅크나 토스를 열면 계좌가 먼저 복사됩니다." {
        didSet { objectWillChange.send() }
    }
    @AppStorage("coffeeSupportBankName") var coffeeSupportBankName: String = "카카오뱅크" {
        didSet { objectWillChange.send() }
    }
    @AppStorage("coffeeSupportAccountNumber") var coffeeSupportAccountNumber: String = "7777015832634" {
        didSet { objectWillChange.send() }
    }
    @AppStorage("coffeeSupportURL") var coffeeSupportURL: String = "" {
        didSet { objectWillChange.send() }
    }
    @AppStorage("coffeeSupportCopyValue") var coffeeSupportCopyValue: String = "" {
        didSet { objectWillChange.send() }
    }
    @AppStorage("coffeeSupportPresetVersion") private var coffeeSupportPresetVersion: Int = 0

    // ── 편집 모드 ──
    @Published var isEditMode: Bool = false

    // ── 보안 설정 ──
    @AppStorage("dailyCostLimit") var dailyCostLimit: Double = 0 {  // 0 = 무제한
        didSet { objectWillChange.send() }
    }
    @AppStorage("perSessionCostLimit") var perSessionCostLimit: Double = 0 {
        didSet { objectWillChange.send() }
    }
    @AppStorage("costWarningAt80") var costWarningAt80: Bool = true {
        didSet { objectWillChange.send() }
    }

    // ── 온보딩 ──
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false {
        didSet { objectWillChange.send() }
    }

    // ── 결제일 알림 ──
    @AppStorage("billingDay") var billingDay: Int = 0  // 0 = 미설정, 1~31
    @AppStorage("billingLastNotifiedMonth") var billingLastNotifiedMonth: String = ""

    // ── 세션 잠금 ──
    @AppStorage("lockPIN") var lockPIN: String = ""
    @AppStorage("autoLockMinutes") var autoLockMinutes: Int = 0  // 0 = 비활성
    @Published var isLocked: Bool = false

    var colorScheme: ColorScheme { isDarkMode ? .dark : .light }

    var coffeeSupportDisplayTitle: String {
        let trimmed = coffeeSupportButtonTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? NSLocalizedString("coffee.default.button", comment: "") : trimmed
    }

    var trimmedCoffeeSupportBankName: String {
        coffeeSupportBankName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedCoffeeSupportAccountNumber: String {
        coffeeSupportAccountNumber.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var coffeeSupportAccountDisplayText: String {
        let bank = trimmedCoffeeSupportBankName.isEmpty ? NSLocalizedString("coffee.default.bank", comment: "") : trimmedCoffeeSupportBankName
        let account = trimmedCoffeeSupportAccountNumber.isEmpty ? "7777015832634" : trimmedCoffeeSupportAccountNumber
        return "\(bank) \(account)"
    }

    var trimmedCoffeeSupportURL: String {
        coffeeSupportURL.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedCoffeeSupportCopyValue: String {
        coffeeSupportCopyValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var normalizedCoffeeSupportURL: URL? {
        Self.normalizedCoffeeSupportURL(from: trimmedCoffeeSupportURL)
    }

    var hasCoffeeSupportDestination: Bool {
        !trimmedCoffeeSupportAccountNumber.isEmpty || normalizedCoffeeSupportURL != nil || !trimmedCoffeeSupportCopyValue.isEmpty
    }

    // ── 가구 위치 헬퍼 ──
    func furniturePosition(for id: String) -> CGPoint? {
        guard !furniturePositionsJSON.isEmpty,
              let data = furniturePositionsJSON.data(using: .utf8),
              let dict = try? JSONDecoder().decode([String: [Double]].self, from: data),
              let arr = dict[id], arr.count == 2 else { return nil }
        return CGPoint(x: arr[0], y: arr[1])
    }

    func setFurniturePosition(_ pos: CGPoint, for id: String) {
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

    func resetFurniturePositions() {
        furniturePositionsJSON = ""
    }

    func ensureCoffeeSupportPreset() {
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

    func coffeeSupportURL(for tier: CoffeeSupportTier) -> URL? {
        Self.normalizedCoffeeSupportURL(from: renderCoffeeSupportTemplate(trimmedCoffeeSupportURL, tier: tier))
    }

    func coffeeSupportCopyText(for tier: CoffeeSupportTier) -> String {
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

    struct LayoutPreset: Codable, Identifiable {
        let id: String
        var name: String
        var viewModeRaw: Int
        var sidebarWidth: Double
        var isDarkMode: Bool
        var fontSizeScale: Double
    }

    @AppStorage("layoutPresets") var layoutPresetsData: Data = Data()

    var layoutPresets: [LayoutPreset] {
        get { (try? JSONDecoder().decode([LayoutPreset].self, from: layoutPresetsData)) ?? [] }
        set { layoutPresetsData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    func saveCurrentAsPreset(name: String, viewModeRaw: Int, sidebarWidth: Double) {
        var presets = layoutPresets
        let preset = LayoutPreset(
            id: UUID().uuidString, name: name,
            viewModeRaw: viewModeRaw, sidebarWidth: sidebarWidth,
            isDarkMode: isDarkMode, fontSizeScale: fontSizeScale
        )
        presets.append(preset)
        layoutPresets = presets
    }

    func applyPreset(_ preset: LayoutPreset) {
        isDarkMode = preset.isDarkMode
        fontSizeScale = preset.fontSizeScale
    }

    func deletePreset(_ id: String) {
        var presets = layoutPresets
        presets.removeAll { $0.id == id }
        layoutPresets = presets
    }
}

enum AutomationTemplateKind: String, CaseIterable, Identifiable {
    case planner
    case designer
    case developerExecution
    case developerRevision
    case reviewer
    case qa
    case reporter
    case sre

    var id: String { rawValue }

    var displayName: String {
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

    var shortLabel: String {
        switch self {
        case .developerExecution: return NSLocalizedString("template.pipeline.dev.exec.short", comment: "")
        case .developerRevision: return NSLocalizedString("template.pipeline.dev.revision.short", comment: "")
        default: return displayName
        }
    }

    var icon: String {
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

    var summary: String {
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

    var placeholderTokens: [String] {
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

    var pinnedLines: [String] {
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

    var defaultTemplate: String {
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

    var automationContract: String {
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

final class AutomationTemplateStore: ObservableObject {
    static let shared = AutomationTemplateStore()

    private let saveKey = "workman.automation.templates.v1"
    private let persistenceQueue = DispatchQueue(label: "workman.automation-template-store", qos: .utility)
    private var saveWorkItem: DispatchWorkItem?
    @Published private(set) var revision: Int = 0

    private var overrides: [String: String] = [:]

    private init() {
        load()
    }

    func template(for kind: AutomationTemplateKind) -> String {
        overrides[kind.rawValue] ?? kind.defaultTemplate
    }

    func binding(for kind: AutomationTemplateKind) -> Binding<String> {
        Binding(
            get: { self.template(for: kind) },
            set: { self.setTemplate($0, for: kind) }
        )
    }

    func isCustomized(_ kind: AutomationTemplateKind) -> Bool {
        overrides[kind.rawValue] != nil
    }

    func setTemplate(_ text: String, for kind: AutomationTemplateKind) {
        if text == kind.defaultTemplate {
            overrides.removeValue(forKey: kind.rawValue)
        } else {
            overrides[kind.rawValue] = text
        }
        revision &+= 1
        scheduleSave()
    }

    func reset(_ kind: AutomationTemplateKind) {
        overrides.removeValue(forKey: kind.rawValue)
        revision &+= 1
        scheduleSave()
    }

    func resetAll() {
        overrides.removeAll()
        revision &+= 1
        scheduleSave()
    }

    func render(_ kind: AutomationTemplateKind, context: [String: String]) -> String {
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

// ═══════════════════════════════════════════════════════
// MARK: - Background Theme
// ═══════════════════════════════════════════════════════

enum BackgroundTheme: String, CaseIterable, Identifiable {
    case auto, sunny, clearSky, sunset, goldenHour, dusk
    case moonlit, starryNight, aurora, milkyWay
    case storm, rain, snow, fog
    case cherryBlossom, autumn, forest
    case neonCity, ocean, desert, volcano

    var id: String { rawValue }

    var displayName: String {
        NSLocalizedString("weather.\(rawValue)", comment: "")
    }

    var icon: String {
        switch self {
        case .auto: return "sparkles"
        case .sunny: return "sun.max.fill"
        case .clearSky: return "cloud.sun.fill"
        case .sunset: return "sunset.fill"
        case .goldenHour: return "sun.haze.fill"
        case .dusk: return "sun.horizon.fill"
        case .moonlit: return "moon.fill"
        case .starryNight: return "star.fill"
        case .aurora: return "wand.and.stars"
        case .milkyWay: return "sparkles"
        case .storm: return "cloud.bolt.fill"
        case .rain: return "cloud.rain.fill"
        case .snow: return "cloud.snow.fill"
        case .fog: return "cloud.fog.fill"
        case .cherryBlossom: return "leaf.fill"
        case .autumn: return "leaf.fill"
        case .forest: return "tree.fill"
        case .neonCity: return "building.2.fill"
        case .ocean: return "water.waves"
        case .desert: return "sun.dust.fill"
        case .volcano: return "mountain.2.fill"
        }
    }

    var skyColors: (top: String, bottom: String) {
        switch self {
        case .auto: return ("0a0d18", "0a0d18")
        case .sunny: return ("4a90d9", "87ceeb")
        case .clearSky: return ("2070c0", "60b0e8")
        case .sunset: return ("1a1040", "e06030")
        case .goldenHour: return ("d08030", "f0c060")
        case .dusk: return ("1a1838", "4a3060")
        case .moonlit: return ("0a1020", "1a2040")
        case .starryNight: return ("050810", "0a1020")
        case .aurora: return ("051018", "0a2030")
        case .milkyWay: return ("030508", "0a0d18")
        case .storm: return ("1a1e28", "2a3040")
        case .rain: return ("2a3040", "3a4858")
        case .snow: return ("b0c0d0", "d0d8e0")
        case .fog: return ("8090a0", "a0a8b0")
        case .cherryBlossom: return ("e8b0c0", "f0d0d8")
        case .autumn: return ("c06030", "d09040")
        case .forest: return ("2a5030", "4a8050")
        case .neonCity: return ("0a0818", "1a1030")
        case .ocean: return ("1040a0", "2060c0")
        case .desert: return ("c09050", "e0c080")
        case .volcano: return ("200808", "401010")
        }
    }

    var floorColors: (base: String, dot: String) {
        switch self {
        case .snow: return ("e0e4e8", "c8ccd4")
        case .desert: return ("d0a860", "c09848")
        case .ocean: return ("1a3050", "1a2840")
        case .volcano: return ("2a1010", "3a1818")
        case .forest: return ("1a3020", "2a4030")
        case .neonCity: return ("0e0818", "1a1030")
        case .autumn: return ("6a4020", "5a3818")
        case .cherryBlossom: return ("d0c0c4", "c0b0b8")
        default: return ("", "")
        }
    }

    var requiredLevel: Int? {
        switch self {
        case .auto, .sunny, .clearSky, .sunset, .moonlit, .rain: return nil  // 기본
        case .goldenHour, .dusk: return 3
        case .starryNight, .fog: return 5
        case .snow, .cherryBlossom: return 8
        case .aurora: return 12
        case .milkyWay: return 15
        case .storm: return 10
        case .autumn, .forest: return 7
        case .neonCity: return 20
        case .ocean: return 10
        case .desert: return 18
        case .volcano: return 25
        }
    }

    var isUnlocked: Bool {
        if UserDefaults.standard.bool(forKey: "allContentUnlocked") { return true }
        guard let level = requiredLevel else { return true }
        return AchievementManager.shared.currentLevel.level >= level
    }

    var lockReason: String {
        guard let level = requiredLevel else { return "" }
        let currentLevel = AchievementManager.shared.currentLevel.level
        if currentLevel < level { return String(format: NSLocalizedString("settings.level.required", comment: ""), level) }
        return ""
    }

}

// ═══════════════════════════════════════════════════════
// MARK: - Furniture Item Model
// ═══════════════════════════════════════════════════════

struct FurnitureItem: Identifiable {
    let id: String
    let name: String
    let icon: String
    let defaultNormX: CGFloat  // 0-1 normalized within room
    let defaultNormY: CGFloat  // 0-1 normalized (0=top wall, 1=floor)
    let width: CGFloat
    let height: CGFloat
    let isWallItem: Bool       // constrained to upper wall zone
    let requiredLevel: Int?          // nil = 기본 해금
    let requiredAchievement: String? // nil = 레벨만 체크

    var isUnlocked: Bool {
        // 시크릿키로 전체 해금된 경우
        if UserDefaults.standard.bool(forKey: "allContentUnlocked") { return true }
        if let level = requiredLevel {
            let currentLevel = AchievementManager.shared.currentLevel.level
            if currentLevel < level { return false }
        }
        if let achievement = requiredAchievement {
            if !(AchievementManager.shared.achievements.first(where: { $0.id == achievement })?.unlocked ?? false) {
                return false
            }
        }
        return true
    }

    var lockReason: String {
        if let level = requiredLevel {
            let currentLevel = AchievementManager.shared.currentLevel.level
            if currentLevel < level { return String(format: NSLocalizedString("furn.level.required.current", comment: ""), level, currentLevel) }
        }
        if let achievement = requiredAchievement {
            if let ach = AchievementManager.shared.achievements.first(where: { $0.id == achievement }), !ach.unlocked {
                return String(format: NSLocalizedString("furn.achievement.required", comment: ""), ach.name)
            }
        }
        return ""
    }

    static let all: [FurnitureItem] = [
        // 기본 가구
        FurnitureItem(id: "sofa", name: NSLocalizedString("furn.sofa", comment: ""), icon: "sofa.fill", defaultNormX: 0.0, defaultNormY: 0.7, width: 49, height: 30, isWallItem: false, requiredLevel: nil, requiredAchievement: nil),
        FurnitureItem(id: "sideTable", name: NSLocalizedString("furn.sideTable", comment: ""), icon: "table.furniture.fill", defaultNormX: 0.45, defaultNormY: 0.75, width: 18, height: 14, isWallItem: false, requiredLevel: nil, requiredAchievement: nil),
        FurnitureItem(id: "coffeeMachine", name: NSLocalizedString("furn.coffeeMachine", comment: ""), icon: "cup.and.saucer.fill", defaultNormX: 0.45, defaultNormY: 0.5, width: 16, height: 28, isWallItem: false, requiredLevel: nil, requiredAchievement: nil),
        FurnitureItem(id: "plant", name: NSLocalizedString("furn.plant", comment: ""), icon: "leaf.fill", defaultNormX: 0.7, defaultNormY: 0.65, width: 14, height: 28, isWallItem: false, requiredLevel: nil, requiredAchievement: nil),
        FurnitureItem(id: "picture", name: NSLocalizedString("furn.picture", comment: ""), icon: "photo.artframe", defaultNormX: 0.55, defaultNormY: 0.1, width: 20, height: 16, isWallItem: true, requiredLevel: nil, requiredAchievement: nil),
        FurnitureItem(id: "neonSign", name: NSLocalizedString("furn.neonSign", comment: ""), icon: "lightbulb.fill", defaultNormX: 0.1, defaultNormY: 0.25, width: 64, height: 16, isWallItem: true, requiredLevel: nil, requiredAchievement: nil),
        FurnitureItem(id: "rug", name: NSLocalizedString("furn.rug", comment: ""), icon: "rectangle.fill", defaultNormX: 0.0, defaultNormY: 0.95, width: 100, height: 14, isWallItem: false, requiredLevel: nil, requiredAchievement: nil),
        // 추가 악세서리
        FurnitureItem(id: "bookshelf", name: NSLocalizedString("furn.bookshelf", comment: ""), icon: "books.vertical.fill", defaultNormX: 0.8, defaultNormY: 0.4, width: 20, height: 36, isWallItem: false, requiredLevel: 5, requiredAchievement: nil),
        FurnitureItem(id: "aquarium", name: NSLocalizedString("furn.aquarium", comment: ""), icon: "fish.fill", defaultNormX: 0.6, defaultNormY: 0.7, width: 22, height: 18, isWallItem: false, requiredLevel: 8, requiredAchievement: nil),
        FurnitureItem(id: "arcade", name: NSLocalizedString("furn.arcade", comment: ""), icon: "gamecontroller.fill", defaultNormX: 0.85, defaultNormY: 0.55, width: 16, height: 30, isWallItem: false, requiredLevel: 10, requiredAchievement: "complete_50"),
        FurnitureItem(id: "whiteboard", name: NSLocalizedString("furn.whiteboard", comment: ""), icon: "rectangle.and.pencil.and.ellipsis", defaultNormX: 0.35, defaultNormY: 0.08, width: 30, height: 22, isWallItem: true, requiredLevel: 7, requiredAchievement: nil),
        FurnitureItem(id: "lamp", name: NSLocalizedString("furn.lamp", comment: ""), icon: "lamp.floor.fill", defaultNormX: 0.9, defaultNormY: 0.6, width: 10, height: 30, isWallItem: false, requiredLevel: 3, requiredAchievement: nil),
        FurnitureItem(id: "cat", name: NSLocalizedString("furn.cat", comment: ""), icon: "cat.fill", defaultNormX: 0.3, defaultNormY: 0.85, width: 12, height: 10, isWallItem: false, requiredLevel: 15, requiredAchievement: "night_owl_10"),
        FurnitureItem(id: "tv", name: "TV", icon: "tv.fill", defaultNormX: 0.7, defaultNormY: 0.15, width: 28, height: 18, isWallItem: true, requiredLevel: 12, requiredAchievement: nil),
        FurnitureItem(id: "fan", name: NSLocalizedString("furn.fan", comment: ""), icon: "fan.fill", defaultNormX: 0.5, defaultNormY: 0.65, width: 12, height: 22, isWallItem: false, requiredLevel: 6, requiredAchievement: nil),
        FurnitureItem(id: "calendar", name: NSLocalizedString("furn.calendar", comment: ""), icon: "calendar", defaultNormX: 0.8, defaultNormY: 0.12, width: 14, height: 14, isWallItem: true, requiredLevel: 4, requiredAchievement: nil),
        FurnitureItem(id: "poster", name: NSLocalizedString("furn.poster", comment: ""), icon: "doc.richtext.fill", defaultNormX: 0.45, defaultNormY: 0.08, width: 16, height: 20, isWallItem: true, requiredLevel: 9, requiredAchievement: nil),
        FurnitureItem(id: "trashcan", name: NSLocalizedString("furn.trashcan", comment: ""), icon: "trash.fill", defaultNormX: 0.95, defaultNormY: 0.85, width: 10, height: 12, isWallItem: false, requiredLevel: 2, requiredAchievement: nil),
        FurnitureItem(id: "cushion", name: NSLocalizedString("furn.cushion", comment: ""), icon: "circle.fill", defaultNormX: 0.15, defaultNormY: 0.88, width: 12, height: 8, isWallItem: false, requiredLevel: nil, requiredAchievement: nil),
    ]
}

struct CoffeeSupportTier: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let amount: Int
    let icon: String

    private static let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }()

    var amountLabel: String {
        let number = NSNumber(value: amount)
        let formatted = Self.formatter.string(from: number) ?? "\(amount)"
        return "\(formatted)원"
    }

    var tint: Color {
        switch id {
        case "starter": return Theme.orange
        case "booster": return Theme.cyan
        default: return Theme.pink
        }
    }

    static let presets: [CoffeeSupportTier] = [
        CoffeeSupportTier(id: "starter", title: NSLocalizedString("coffee.tier.americano", comment: ""), subtitle: NSLocalizedString("coffee.tier.americano.sub", comment: ""), amount: 3000, icon: "cup.and.saucer.fill"),
        CoffeeSupportTier(id: "booster", title: NSLocalizedString("coffee.tier.latte", comment: ""), subtitle: NSLocalizedString("coffee.tier.latte.sub", comment: ""), amount: 5000, icon: "mug.fill"),
        CoffeeSupportTier(id: "nightshift", title: NSLocalizedString("coffee.tier.nightshift", comment: ""), subtitle: NSLocalizedString("coffee.tier.nightshift.sub", comment: ""), amount: 10000, icon: "takeoutbag.and.cup.and.straw.fill")
    ]
}

// ═══════════════════════════════════════════════════════
// MARK: - Theme (동적 테마)
// ═══════════════════════════════════════════════════════

enum Theme {
    private static var _cachedDark: Bool = false
    private static var _cacheValid: Bool = false

    private static var dark: Bool {
        if !_cacheValid {
            _cachedDark = AppSettings.shared.isDarkMode
            _cacheValid = true
            DispatchQueue.main.async { _cacheValid = false }
        }
        return _cachedDark
    }
    private static var scale: CGFloat { CGFloat(AppSettings.shared.fontSizeScale) }
    /// UI 크롬(툴바, 사이드바, 필터 등)용 완화된 스케일 — 콘텐츠보다 덜 커짐
    private static var chromeScale: CGFloat { 1 + (scale - 1) * 0.5 }

    // ═══════════════════════════════════════════════════════
    // 도피스 디자인 시스템 (Vercel Geist 재해석)
    //
    // 철학: 도피스의 세계관 + Vercel급 컴포넌트 정제도
    // - 순수 블랙/그레이스케일 surface 계층
    // - 얇은 1px border로 구조 표현, 그림자 없음
    // - 색상은 상태 표시에만 절제하여 사용
    // - UI는 산세리프, 코드/터미널만 monospaced
    // - 도트 캐릭터 영역은 그대로 보존
    // ═══════════════════════════════════════════════════════

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // 1. COLOR TOKENS
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    // ── Background Surfaces (4-layer depth system) ──
    // Layer 0: App background (deepest)
    static var bg: Color { dark ? Color(hex: "000000") : Color(hex: "fafafa") }
    // Layer 1: Card / elevated panel
    static var bgCard: Color { dark ? Color(hex: "0a0a0a") : Color(hex: "ffffff") }
    // Layer 2: Raised surface / nested element
    static var bgSurface: Color { dark ? Color(hex: "111111") : Color(hex: "f5f5f5") }
    // Layer 3: Tertiary surface (badges, code blocks)
    static var bgTertiary: Color { dark ? Color(hex: "1a1a1a") : Color(hex: "ebebeb") }

    // ── Functional backgrounds ──
    static var bgTerminal: Color { dark ? Color(hex: "0a0a0a") : Color(hex: "fafafa") }
    static var bgInput: Color { dark ? Color(hex: "000000") : Color(hex: "ffffff") }
    static var bgHover: Color { dark ? Color(hex: "1a1a1a") : Color(hex: "f0f0f0") }
    static var bgSelected: Color { dark ? Color(hex: "1a1a1a") : Color(hex: "eaeaea") }
    static var bgPressed: Color { dark ? Color(hex: "222222") : Color(hex: "e5e5e5") }
    static var bgDisabled: Color { dark ? Color(hex: "0a0a0a") : Color(hex: "f5f5f5") }
    static var bgOverlay: Color { dark ? Color(hex: "000000").opacity(0.7) : Color(hex: "000000").opacity(0.4) }

    // ── Borders (single-weight system: always 1px, vary opacity) ──
    static var border: Color { dark ? Color(hex: "282828") : Color(hex: "e5e5e5") }
    static var borderStrong: Color { dark ? Color(hex: "3e3e3e") : Color(hex: "d0d0d0") }
    static var borderActive: Color { dark ? Color(hex: "555555") : Color(hex: "999999") }
    static var borderSubtle: Color { dark ? Color(hex: "1e1e1e") : Color(hex: "eeeeee") }
    static var focusRing: Color { Color(hex: "0070f3").opacity(0.5) }

    // ── Text (5-step hierarchy) ──
    static var textPrimary: Color { dark ? Color(hex: "ededed") : Color(hex: "171717") }
    static var textSecondary: Color { dark ? Color(hex: "a1a1a1") : Color(hex: "636363") }
    static var textDim: Color { dark ? Color(hex: "707070") : Color(hex: "8f8f8f") }
    static var textMuted: Color { dark ? Color(hex: "484848") : Color(hex: "b0b0b0") }
    static var textTerminal: Color { dark ? Color(hex: "ededed") : Color(hex: "171717") }

    // ── System ──
    static var textOnAccent: Color { .white }
    static var overlay: Color { dark ? .white : .black }
    static var overlayBg: Color { dark ? .black : .white }

    // ── Semantic Accents ──
    static var accent: Color { dark ? Color(hex: "3291ff") : Color(hex: "0070f3") }
    static var green: Color { dark ? Color(hex: "3ecf8e") : Color(hex: "18a058") }
    static var red: Color { dark ? Color(hex: "f14c4c") : Color(hex: "e5484d") }
    static var yellow: Color { dark ? Color(hex: "f5a623") : Color(hex: "ca8a04") }
    static var purple: Color { dark ? Color(hex: "8e4ec6") : Color(hex: "6e56cf") }
    static var orange: Color { dark ? Color(hex: "f97316") : Color(hex: "e5560a") }
    static var cyan: Color { dark ? Color(hex: "06b6d4") : Color(hex: "0891b2") }
    static var pink: Color { dark ? Color(hex: "e54d9e") : Color(hex: "d23197") }

    // ── Semantic accent backgrounds (soft fills for badges/indicators) ──
    static func accentBg(_ color: Color) -> Color { color.opacity(dark ? 0.12 : 0.08) }
    static func accentBorder(_ color: Color) -> Color { color.opacity(dark ? 0.25 : 0.2) }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // 2. TYPOGRAPHY SYSTEM
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    //
    // UI text: system sans-serif (.default)
    // Code/terminal/git hash: monospaced (.monospaced)
    // Pixel world labels: monospaced bold (preserved)
    //
    // Scale hierarchy:
    //   display: 18   title: 14   heading: 12   body: 11
    //   small: 10     micro: 9    tiny: 8

    // Pre-scaled convenience fonts
    static var monoTiny: Font { .system(size: round(8 * scale), design: .monospaced) }
    static var monoSmall: Font { .system(size: round(10 * scale), design: .monospaced) }
    static var monoNormal: Font { .system(size: round(12 * scale), design: .monospaced) }
    static var monoBold: Font { .system(size: round(11 * scale), weight: .semibold, design: .monospaced) }
    static var pixel: Font { .system(size: round(8 * chromeScale), weight: .bold, design: .monospaced) }

    /// Primary UI text (Geist Sans equivalent — system san-serif)
    static func mono(_ baseSize: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: round(baseSize * scale), weight: weight, design: .default)
    }

    /// Code, terminal, git hashes, file paths
    static func code(_ baseSize: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: round(baseSize * scale), weight: weight, design: .monospaced)
    }

    /// General scaled font
    static func scaled(_ baseSize: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> Font {
        .system(size: round(baseSize * scale), weight: weight, design: design)
    }

    /// Chrome-only font (sidebar, toolbar — less aggressive scaling)
    static func chrome(_ baseSize: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: round(baseSize * chromeScale), weight: weight, design: .default)
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // 3. SPACING & SIZING
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    //
    // 4px base grid. All spacing in multiples of 4.
    //
    // Naming: sp1=4, sp2=8, sp3=12, sp4=16, sp5=20, sp6=24, sp8=32

    static let sp1: CGFloat = 4
    static let sp2: CGFloat = 8
    static let sp3: CGFloat = 12
    static let sp4: CGFloat = 16
    static let sp5: CGFloat = 20
    static let sp6: CGFloat = 24
    static let sp8: CGFloat = 32

    // Row heights
    static let rowCompact: CGFloat = 28     // dense list rows, sidebar items
    static let rowDefault: CGFloat = 36     // standard list rows, table rows
    static let rowComfortable: CGFloat = 44 // touch-friendly / spacious rows

    // Panel padding
    static let panelPadding: CGFloat = 16
    static let cardPadding: CGFloat = 12
    static let toolbarHeight: CGFloat = 36
    static let sidebarItemHeight: CGFloat = 30

    // Icon sizes
    static func iconSize(_ baseSize: CGFloat) -> CGFloat { round(baseSize * scale) }
    static func chromeIconSize(_ baseSize: CGFloat) -> CGFloat { round(baseSize * chromeScale) }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // 4. RADIUS / BORDER / SURFACE
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    //
    // Radius: tight and precise, never bubbly
    // Border: always 1px, full color (no opacity tricks)
    // Shadow: none (depth = border + surface color)

    static let cornerSmall: CGFloat = 5     // badges, tags, small chips
    static let cornerMedium: CGFloat = 6    // buttons, inputs, select
    static let cornerLarge: CGFloat = 8     // cards, panels, dialogs
    static let cornerXL: CGFloat = 12       // modals, sheets, large containers

    // Border defaults (for modifier compatibility)
    static let borderDefault: CGFloat = 1.0
    static let borderActiveOpacity: CGFloat = 1.0
    static let borderLight: CGFloat = 0.6

    // Interaction state opacities (consistent across all components)
    static let hoverOpacity: CGFloat = 0.08
    static let activeOpacity: CGFloat = 0.12
    static let strokeActiveOpacity: CGFloat = 0.25
    static let strokeInactiveOpacity: CGFloat = 0.15

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // 5. PRESERVED TOKENS (pixel world)
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    static var workerColors: [Color] {
        dark ? [
            Color(hex: "ee7878"), Color(hex: "68d498"), Color(hex: "eebb50"),
            Color(hex: "70b0ee"), Color(hex: "c08ce6"), Color(hex: "ee9858"),
            Color(hex: "58ccbb"), Color(hex: "ee78bb")
        ] : [
            Color(hex: "d04848"), Color(hex: "259248"), Color(hex: "b88000"),
            Color(hex: "2260d0"), Color(hex: "6a40d0"), Color(hex: "c86020"),
            Color(hex: "0a8888"), Color(hex: "c84080")
        ]
    }

    static var bgGradient: LinearGradient {
        dark ? LinearGradient(colors: [Color(hex: "000000"), Color(hex: "0a0a0a")], startPoint: .top, endPoint: .bottom)
             : LinearGradient(colors: [Color(hex: "ffffff"), Color(hex: "fafafa")], startPoint: .top, endPoint: .bottom)
    }
}

enum AppChromeTone: Equatable {
    case neutral
    case accent
    case green
    case red
    case yellow
    case purple
    case cyan
    case orange

    var color: Color {
        switch self {
        case .neutral: return Theme.textSecondary
        case .accent: return Theme.accent
        case .green: return Theme.green
        case .red: return Theme.red
        case .yellow: return Theme.yellow
        case .purple: return Theme.purple
        case .cyan: return Theme.cyan
        case .orange: return Theme.orange
        }
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 도피스 컴포넌트 시스템 (Vercel-grade)
//
// 원칙:
// - 그림자 없음. depth = surface color + border
// - 보더는 항상 1px, Theme.border 사용
// - 배경은 surface 계층으로만 표현
// - prominent 버튼만 채색, 나머지는 border-only
// - hover/selected/pressed는 bgHover/bgSelected/bgPressed 사용
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

// MARK: - Panel Modifier (카드, 섹션, 패널)

private struct AppPanelModifier: ViewModifier {
    let padding: CGFloat
    let radius: CGFloat
    let fill: Color
    let strokeOpacity: Double  // kept for API compat, border uses Theme.border
    let shadow: Bool           // ignored — no shadows in this system

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(RoundedRectangle(cornerRadius: radius).fill(fill))
            .overlay(RoundedRectangle(cornerRadius: radius).stroke(Theme.border, lineWidth: 1))
    }
}

// MARK: - Field Modifier (텍스트 입력, 셀렉트)

private struct AppFieldModifier: ViewModifier {
    let emphasized: Bool
    let radius: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, Theme.sp3)
            .padding(.vertical, Theme.sp2)
            .background(RoundedRectangle(cornerRadius: radius).fill(Theme.bgInput))
            .overlay(RoundedRectangle(cornerRadius: radius).stroke(emphasized ? Theme.accent : Theme.border, lineWidth: 1))
    }
}

// MARK: - Button Surface Modifier

private struct AppButtonSurfaceModifier: ViewModifier {
    let tone: AppChromeTone
    let prominent: Bool
    let compact: Bool

    func body(content: Content) -> some View {
        let tint = tone.color
        let r: CGFloat = Theme.cornerMedium

        content
            .foregroundColor(prominent ? Theme.textOnAccent : (tone == .neutral ? Theme.textSecondary : tint))
            .padding(.horizontal, compact ? Theme.sp2 : Theme.sp3)
            .padding(.vertical, compact ? Theme.sp1 + 1 : Theme.sp2 - 1)
            .background(
                RoundedRectangle(cornerRadius: r)
                    .fill(prominent ? tint : (tone == .neutral ? .clear : Theme.accentBg(tint)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: r)
                    .stroke(prominent ? tint.opacity(0.2) : Theme.border, lineWidth: 1)
            )
    }
}

// MARK: - View Extensions

extension View {
    func appPanelStyle(
        padding: CGFloat = Theme.panelPadding,
        radius: CGFloat = Theme.cornerLarge,
        fill: Color = Theme.bgCard,
        strokeOpacity: Double = Theme.borderDefault,
        shadow: Bool = false
    ) -> some View {
        modifier(AppPanelModifier(padding: padding, radius: radius, fill: fill, strokeOpacity: strokeOpacity, shadow: shadow))
    }

    func appFieldStyle(emphasized: Bool = false, radius: CGFloat = CGFloat(Theme.cornerMedium)) -> some View {
        modifier(AppFieldModifier(emphasized: emphasized, radius: radius))
    }

    func appButtonSurface(
        tone: AppChromeTone = .neutral,
        prominent: Bool = false,
        compact: Bool = false
    ) -> some View {
        modifier(AppButtonSurfaceModifier(tone: tone, prominent: prominent, compact: compact))
    }

    /// Vercel-style divider (subtle horizontal line)
    func appDivider() -> some View {
        self.overlay(alignment: .bottom) {
            Rectangle().fill(Theme.border).frame(height: 1)
        }
    }

    /// Sidebar hover highlight
    func sidebarRowStyle(isSelected: Bool = false, isHovered: Bool = false) -> some View {
        self
            .padding(.horizontal, Theme.sp2)
            .padding(.vertical, Theme.sp1 + 1)
            .background(
                RoundedRectangle(cornerRadius: Theme.cornerMedium)
                    .fill(isSelected ? Theme.bgSelected : (isHovered ? Theme.bgHover : .clear))
            )
    }
}

// MARK: - Status Badge (Vercel-style: tight, border-accented)

struct AppStatusBadge: View {
    let title: String
    let symbol: String
    let tint: Color
    var compact: Bool = true

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: symbol)
                .font(.system(size: compact ? Theme.chromeIconSize(8) : Theme.iconSize(9), weight: .medium))
            Text(title)
                .font(compact ? Theme.chrome(8, weight: .medium) : Theme.mono(9, weight: .medium))
                .lineLimit(1)
        }
        .foregroundColor(tint)
        .padding(.horizontal, compact ? Theme.sp1 + 2 : Theme.sp2)
        .padding(.vertical, compact ? 2 : 3)
        .background(
            RoundedRectangle(cornerRadius: Theme.cornerSmall)
                .fill(Theme.accentBg(tint))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerSmall)
                .stroke(Theme.accentBorder(tint), lineWidth: 1)
        )
    }
}

// MARK: - Status Dot (Vercel deployments style: tiny colored circle)

struct AppStatusDot: View {
    let color: Color
    var size: CGFloat = 6

    var body: some View {
        Circle().fill(color).frame(width: size, height: size)
    }
}

// MARK: - Section Header (Vercel panel headers)

struct AppSectionHeader: View {
    let title: String
    var count: Int? = nil
    var action: (() -> Void)? = nil
    var actionLabel: String = ""

    var body: some View {
        HStack(spacing: Theme.sp2) {
            Text(title.uppercased())
                .font(Theme.chrome(9, weight: .semibold))
                .foregroundColor(Theme.textDim)
                .tracking(0.5)
            if let count {
                Text("\(count)")
                    .font(Theme.chrome(8, weight: .bold))
                    .foregroundColor(Theme.textMuted)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(RoundedRectangle(cornerRadius: 3).fill(Theme.bgTertiary))
            }
            Spacer()
            if let action, !actionLabel.isEmpty {
                Button(action: action) {
                    Text(actionLabel)
                        .font(Theme.chrome(9, weight: .medium))
                        .foregroundColor(Theme.textDim)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Theme.sp3)
        .padding(.vertical, Theme.sp2)
    }
}

// MARK: - Empty State (Vercel: minimal, informative)

struct AppEmptyStateView: View {
    let title: String
    let message: String
    let symbol: String
    var tint: Color = Theme.textDim

    var body: some View {
        VStack(spacing: Theme.sp3) {
            Image(systemName: symbol)
                .font(.system(size: Theme.iconSize(20), weight: .light))
                .foregroundColor(tint.opacity(0.5))
            VStack(spacing: Theme.sp1) {
                Text(title)
                    .font(Theme.mono(11, weight: .medium))
                    .foregroundColor(Theme.textSecondary)
                Text(message)
                    .font(Theme.mono(9))
                    .foregroundColor(Theme.textDim)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.sp8)
        .padding(.horizontal, Theme.sp4)
    }
}

// MARK: - Key-Value Row (for stats, metadata display)

struct AppKeyValueRow: View {
    let key: String
    let value: String
    var valueColor: Color = Theme.textPrimary
    var mono: Bool = false

    var body: some View {
        HStack {
            Text(key)
                .font(Theme.mono(10))
                .foregroundColor(Theme.textDim)
            Spacer()
            Text(value)
                .font(mono ? Theme.code(10, weight: .medium) : Theme.mono(10, weight: .medium))
                .foregroundColor(valueColor)
        }
        .padding(.vertical, 3)
    }
}

// MARK: - Inline Code Block

struct AppInlineCode: View {
    let text: String

    var body: some View {
        Text(text)
            .font(Theme.code(10))
            .foregroundColor(Theme.textPrimary)
            .padding(.horizontal, Theme.sp1 + 1)
            .padding(.vertical, 1)
            .background(RoundedRectangle(cornerRadius: 3).fill(Theme.bgTertiary))
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Theme.borderSubtle, lineWidth: 1))
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - 통합 모달 시스템 (DSModal)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
//
// 모든 시트/모달이 동일한 구조를 따름:
// DSModalShell > DSModalHeader > Content > DSModalFooter
// 헤더: 아이콘 + 타이틀 + 서브타이틀 + 닫기 버튼
// 바디: ScrollView + 섹션들
// 푸터: 좌측 보조 액션 + 우측 주요 액션

/// 모달 전체 컨테이너
struct DSModalShell<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(Theme.bg)
    }
}

/// 통합 모달 헤더
struct DSModalHeader: View {
    let icon: String
    let iconColor: Color
    let title: String
    var subtitle: String = ""
    var trailing: AnyView? = nil
    var onClose: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: Theme.sp3) {
            // 아이콘
            ZStack {
                RoundedRectangle(cornerRadius: Theme.cornerMedium)
                    .fill(Theme.accentBg(iconColor))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: Theme.iconSize(14), weight: .medium))
                    .foregroundColor(iconColor)
            }

            // 타이틀 영역
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.mono(13, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(Theme.mono(10))
                        .foregroundColor(Theme.textDim)
                }
            }

            Spacer()

            // 트레일링 (카운터, 배지 등)
            if let trailing { trailing }

            // 닫기 버튼
            if let onClose {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Theme.textDim)
                        .frame(width: 24, height: 24)
                        .background(RoundedRectangle(cornerRadius: Theme.cornerSmall).fill(Theme.bgSurface))
                        .overlay(RoundedRectangle(cornerRadius: Theme.cornerSmall).stroke(Theme.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Theme.sp5)
        .padding(.vertical, Theme.sp4)
        .background(Theme.bgCard)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.border).frame(height: 1) }
    }
}

/// 모달 푸터 (액션 바)
struct DSModalFooter<Leading: View, Trailing: View>: View {
    let leading: Leading
    let trailing: Trailing

    init(@ViewBuilder leading: () -> Leading, @ViewBuilder trailing: () -> Trailing) {
        self.leading = leading()
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: Theme.sp2) {
            leading
            Spacer()
            trailing
        }
        .padding(.horizontal, Theme.sp5)
        .padding(.vertical, Theme.sp3)
        .background(Theme.bgCard)
        .overlay(alignment: .top) { Rectangle().fill(Theme.border).frame(height: 1) }
    }
}

/// 모달 내부 섹션 (통합 settingsSection 대체)
struct DSSection<Content: View>: View {
    let title: String
    var subtitle: String = ""
    let content: Content

    init(title: String, subtitle: String = "", @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.sp3) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.mono(11, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(Theme.mono(9))
                        .foregroundColor(Theme.textDim)
                }
            }
            content
        }
        .padding(Theme.sp4)
        .background(RoundedRectangle(cornerRadius: Theme.cornerLarge).fill(Theme.bgCard))
        .overlay(RoundedRectangle(cornerRadius: Theme.cornerLarge).stroke(Theme.border, lineWidth: 1))
    }
}

/// 탭 바 (설정, 필터 등에서 사용)
struct DSTabBar: View {
    let tabs: [(String, String)]  // (icon, label)
    @Binding var selectedIndex: Int

    var body: some View {
        HStack(spacing: 1) {
            ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                Button(action: { selectedIndex = index }) {
                    HStack(spacing: 4) {
                        Image(systemName: tab.0)
                            .font(.system(size: Theme.chromeIconSize(9), weight: .medium))
                        Text(tab.1)
                            .font(Theme.chrome(9, weight: index == selectedIndex ? .semibold : .regular))
                    }
                    .foregroundColor(index == selectedIndex ? Theme.textPrimary : Theme.textDim)
                    .padding(.horizontal, Theme.sp3)
                    .padding(.vertical, Theme.sp2)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.cornerMedium)
                            .fill(index == selectedIndex ? Theme.bgSurface : .clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.cornerMedium)
                            .stroke(index == selectedIndex ? Theme.border : .clear, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(RoundedRectangle(cornerRadius: Theme.cornerLarge).fill(Theme.bgCard))
        .overlay(RoundedRectangle(cornerRadius: Theme.cornerLarge).stroke(Theme.border, lineWidth: 1))
    }
}

/// 통합 필터 칩
struct DSFilterChip: View {
    let label: String
    let isSelected: Bool
    var count: Int? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(label)
                    .font(Theme.chrome(9, weight: isSelected ? .semibold : .regular))
                if let count {
                    Text("\(count)")
                        .font(Theme.chrome(8, weight: .bold))
                        .foregroundColor(Theme.textMuted)
                }
            }
            .foregroundColor(isSelected ? Theme.textPrimary : Theme.textDim)
            .padding(.horizontal, Theme.sp3)
            .padding(.vertical, Theme.sp1 + 2)
            .background(
                RoundedRectangle(cornerRadius: Theme.cornerMedium)
                    .fill(isSelected ? Theme.bgSurface : .clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerMedium)
                    .stroke(isSelected ? Theme.border : Theme.borderSubtle, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

/// 통합 리스트 행 컴포넌트
struct DSListRow<Leading: View, Trailing: View>: View {
    let leading: Leading
    let title: String
    var subtitle: String = ""
    let trailing: Trailing
    var isSelected: Bool = false

    init(title: String, subtitle: String = "", isSelected: Bool = false, @ViewBuilder leading: () -> Leading, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.subtitle = subtitle
        self.isSelected = isSelected
        self.leading = leading()
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: Theme.sp3) {
            leading
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(Theme.mono(10, weight: .medium))
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(1)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(Theme.mono(9))
                        .foregroundColor(Theme.textDim)
                        .lineLimit(1)
                }
            }
            Spacer()
            trailing
        }
        .padding(.horizontal, Theme.sp3)
        .padding(.vertical, Theme.sp2)
        .background(
            RoundedRectangle(cornerRadius: Theme.cornerMedium)
                .fill(isSelected ? Theme.bgSelected : .clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerMedium)
                .stroke(isSelected ? Theme.border : .clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
    }
}

/// 통합 stat/metric 카드
struct DSStatCard: View {
    let title: String
    let value: String
    var subtitle: String = ""
    var icon: String = ""
    var tint: Color = Theme.textPrimary

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.sp2) {
            HStack(spacing: Theme.sp1) {
                if !icon.isEmpty {
                    Image(systemName: icon)
                        .font(.system(size: Theme.iconSize(9)))
                        .foregroundColor(Theme.textDim)
                }
                Text(title)
                    .font(Theme.mono(9))
                    .foregroundColor(Theme.textDim)
            }
            Text(value)
                .font(Theme.mono(16, weight: .semibold))
                .foregroundColor(tint)
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(Theme.mono(9))
                    .foregroundColor(Theme.textDim)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.sp3)
        .background(RoundedRectangle(cornerRadius: Theme.cornerLarge).fill(Theme.bgCard))
        .overlay(RoundedRectangle(cornerRadius: Theme.cornerLarge).stroke(Theme.border, lineWidth: 1))
    }
}

/// 통합 프로그레스 바
struct DSProgressBar: View {
    let value: Double  // 0.0 ~ 1.0
    var tint: Color = Theme.accent
    var height: CGFloat = 4

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(Theme.bgSurface)
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(tint)
                    .frame(width: geo.size.width * min(max(value, 0), 1))
            }
        }
        .frame(height: height)
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - Settings View
// ═══════════════════════════════════════════════════════

struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    @Environment(\.dismiss) var dismiss

    @ObservedObject private var tokenTracker = TokenTracker.shared
    @ObservedObject private var templateStore = AutomationTemplateStore.shared
    @State private var editingAppName: String = ""
    @State private var editingCompanyName: String = ""

    @State private var selectedSettingsTab = 0
    @State private var selectedTemplateKind: AutomationTemplateKind = .planner
    @State private var cacheSize: String = NSLocalizedString("settings.calculating", comment: "")
    @State private var showClearConfirm = false
    @State private var clearAllMode = false
    @State private var showTokenResetConfirm = false
    @State private var showTemplateResetConfirm = false
    @State private var showLanguageRestartAlert = false
    @State private var pendingLanguage: String?

    private let settingsTabs: [(String, String)] = [
        ("slider.horizontal.3", NSLocalizedString("settings.general", comment: "")), ("paintbrush.fill", NSLocalizedString("settings.display", comment: "")), ("building.2.fill", NSLocalizedString("settings.office", comment: "")),
        ("bolt.fill", NSLocalizedString("settings.token", comment: "")), ("externaldrive.fill", NSLocalizedString("settings.data", comment: "")), ("doc.text.fill", NSLocalizedString("settings.template", comment: "")),
        ("cup.and.saucer.fill", NSLocalizedString("settings.support", comment: "")), ("lock.shield.fill", NSLocalizedString("settings.security", comment: ""))
    ]

    var body: some View {
        DSModalShell {
            DSModalHeader(
                icon: "gearshape.fill",
                iconColor: Theme.textSecondary,
                title: NSLocalizedString("settings.title", comment: ""),
                onClose: { dismiss() }
            )
            .keyboardShortcut(.escape)

            // 탭 바
            ScrollView(.horizontal, showsIndicators: false) {
                DSTabBar(tabs: settingsTabs, selectedIndex: $selectedSettingsTab)
            }
            .padding(.horizontal, Theme.sp4)
            .padding(.vertical, Theme.sp2)

            Rectangle().fill(Theme.border).frame(height: 1)

            // 탭 내용
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: Theme.sp4) {
                    switch selectedSettingsTab {
                    case 0: generalTab
                    case 1: displayTab
                    case 2: officeTab
                    case 3: tokenTab
                    case 4: dataTab
                    case 5: templateTab
                    case 6: supportTab
                    case 7: securityTab
                    default: generalTab
                    }
                }
                .padding(Theme.sp5)
            }
        }
        .frame(width: 580, height: 680)
        .background(Theme.bg)
        .onAppear {
            settings.ensureCoffeeSupportPreset()
            editingAppName = settings.appDisplayName
            editingCompanyName = settings.companyName
            calculateCacheSize()
        }
        .alert(clearAllMode ? NSLocalizedString("theme.alert.clear.all", comment: "") : NSLocalizedString("theme.alert.clear.old", comment: ""), isPresented: $showClearConfirm) {
            Button(NSLocalizedString("delete", comment: ""), role: .destructive) {
                if clearAllMode { clearAllData() } else { clearOldCache() }
            }
            Button(NSLocalizedString("cancel", comment: ""), role: .cancel) {}
        } message: {
            Text(clearAllMode
                 ? NSLocalizedString("theme.alert.clear.all.msg", comment: "")
                 : NSLocalizedString("theme.alert.clear.old.msg", comment: ""))
        }
        .alert(NSLocalizedString("theme.alert.token.reset", comment: ""), isPresented: $showTokenResetConfirm) {
            Button(NSLocalizedString("theme.alert.token.reset.btn", comment: ""), role: .destructive) {
                tokenTracker.clearAllEntries()
            }
            Button(NSLocalizedString("cancel", comment: ""), role: .cancel) {}
        } message: {
            Text(NSLocalizedString("theme.alert.token.reset.msg", comment: ""))
        }
        .alert(NSLocalizedString("theme.alert.template.reset", comment: ""), isPresented: $showTemplateResetConfirm) {
            Button(NSLocalizedString("theme.alert.template.reset.btn", comment: ""), role: .destructive) {
                templateStore.resetAll()
            }
            Button(NSLocalizedString("cancel", comment: ""), role: .cancel) {}
        } message: {
            Text(NSLocalizedString("theme.alert.template.reset.msg", comment: ""))
        }
        .alert(NSLocalizedString("theme.alert.language.change", comment: ""), isPresented: $showLanguageRestartAlert) {
            Button(NSLocalizedString("settings.restart", comment: ""), role: .destructive) {
                if let lang = pendingLanguage {
                    settings.appLanguage = lang
                    SessionManager.shared.saveSessions(immediately: true)
                    // 앱 재시작: 현재 앱 경로를 열고 종료
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        let appPath = Bundle.main.bundlePath
                        let task = Process()
                        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
                        task.arguments = ["-n", appPath]  // -n: new instance
                        try? task.run()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            NSApp.terminate(nil)
                        }
                    }
                }
            }
            Button(NSLocalizedString("cancel", comment: ""), role: .cancel) { pendingLanguage = nil }
        } message: {
            let langName: String = {
                switch pendingLanguage {
                case "ko": return NSLocalizedString("theme.lang.korean", comment: "")
                case "en": return "English"
                case "ja": return "日本語"
                default: return NSLocalizedString("settings.language.system", comment: "")
                }
            }()
            Text(String(format: NSLocalizedString("theme.alert.language.msg", comment: ""), langName))
        }
    }

    private func langButton(_ label: String, code: String) -> some View {
        let isActive = settings.appLanguage == code
        return Button(action: {
            guard code != settings.appLanguage else { return }
            pendingLanguage = code
            showLanguageRestartAlert = true
        }) {
            Text(label)
                .font(Theme.mono(9, weight: isActive ? .bold : .regular))
                .foregroundColor(isActive ? .white : Theme.textSecondary)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(RoundedRectangle(cornerRadius: 6).fill(isActive ? Theme.accent : Theme.bgSurface))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(isActive ? Theme.accent : Theme.border.opacity(0.3), lineWidth: 0.5))
        }.buttonStyle(.plain)
    }

    // MARK: - Tab Button

    private func settingsTabButton(_ title: String, icon: String, tab: Int) -> some View {
        let selected = selectedSettingsTab == tab
        return Button(action: { withAnimation(.easeInOut(duration: 0.15)) { selectedSettingsTab = tab } }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: Theme.iconSize(12), weight: .medium))
                Text(title)
                    .font(Theme.mono(8, weight: selected ? .bold : .medium))
            }
            .foregroundColor(selected ? Theme.accent : Theme.textDim)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: Theme.cornerSmall)
                    .fill(selected ? Theme.accent.opacity(0.08) : Theme.bgSurface.opacity(0.45))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerSmall)
                    .stroke(selected ? Theme.accent.opacity(0.18) : Theme.border.opacity(0.18), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 일반 탭

    private var generalTab: some View {
        VStack(spacing: 14) {
            settingsSection(title: NSLocalizedString("theme.section.profile", comment: ""), subtitle: NSLocalizedString("theme.section.profile.subtitle", comment: "")) {
                VStack(spacing: 10) {
                    securityRow(label: NSLocalizedString("theme.label.app.name", comment: "")) {
                        TextField(NSLocalizedString("theme.label.app.name", comment: ""), text: $editingAppName)
                            .font(Theme.mono(10)).textFieldStyle(.plain)
                            .padding(6)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Theme.bgSurface))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.border, lineWidth: 0.5))
                            .frame(maxWidth: 180)
                            .onSubmit { settings.appDisplayName = editingAppName; settings.requestRefreshIfNeeded() }
                    }
                    securityRow(label: NSLocalizedString("theme.label.company", comment: "")) {
                        TextField(NSLocalizedString("theme.label.company.placeholder", comment: ""), text: $editingCompanyName)
                            .font(Theme.mono(10)).textFieldStyle(.plain)
                            .padding(6)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Theme.bgSurface))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.border, lineWidth: 0.5))
                            .frame(maxWidth: 180)
                            .onSubmit { settings.companyName = editingCompanyName; settings.requestRefreshIfNeeded() }
                    }
                    securityRow(label: NSLocalizedString("theme.label.secret.key", comment: "")) {
                        HStack(spacing: 6) {
                            SecureField(NSLocalizedString("theme.label.secret.key.placeholder", comment: ""), text: $secretKeyInput)
                                .font(Theme.mono(10)).textFieldStyle(.plain)
                                .padding(6)
                                .background(RoundedRectangle(cornerRadius: 6).fill(Theme.bgSurface))
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(
                                    secretKeyResult == .wrong ? Theme.red : Theme.border, lineWidth: 0.5))
                                .frame(maxWidth: 140)
                                .onSubmit { applySecretKey() }
                            Button(NSLocalizedString("theme.label.apply", comment: "")) { applySecretKey() }
                                .font(Theme.mono(9, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(RoundedRectangle(cornerRadius: 6).fill(Theme.accent))
                                .buttonStyle(.plain)
                        }
                    }
                    if secretKeyResult == .success {
                        statusHint(icon: "checkmark.circle.fill", text: NSLocalizedString("theme.secret.unlocked", comment: ""), tint: Theme.green)
                    } else if secretKeyResult == .wrong {
                        statusHint(icon: "xmark.circle.fill", text: NSLocalizedString("theme.secret.invalid", comment: ""), tint: Theme.red)
                    }
                }
            }

            settingsSection(title: NSLocalizedString("theme.section.language", comment: ""), subtitle: settings.currentLanguageLabel) {
                VStack(spacing: 10) {
                    securityRow(label: NSLocalizedString("theme.label.app.language", comment: "")) {
                        HStack(spacing: 8) {
                            langButton(NSLocalizedString("theme.lang.system", comment: ""), code: "auto")
                            langButton(NSLocalizedString("theme.lang.korean", comment: ""), code: "ko")
                            langButton("English", code: "en")
                            langButton("日本語", code: "ja")
                        }
                    }
                }
            }

            settingsSection(title: NSLocalizedString("theme.section.terminal", comment: ""), subtitle: settings.rawTerminalMode ? NSLocalizedString("theme.terminal.raw", comment: "") : NSLocalizedString("theme.terminal.doffice", comment: "")) {
                VStack(spacing: 10) {
                    securityRow(label: NSLocalizedString("theme.label.raw.terminal", comment: "")) {
                        Toggle("", isOn: $settings.rawTerminalMode)
                            .toggleStyle(.switch).tint(Theme.green).labelsHidden()
                            .onChange(of: settings.rawTerminalMode) { _, _ in settings.requestRefreshIfNeeded() }
                    }
                    securityRow(label: NSLocalizedString("theme.label.auto.refresh", comment: "")) {
                        Toggle("", isOn: $settings.autoRefreshOnSettingsChange)
                            .toggleStyle(.switch).tint(Theme.accent).labelsHidden()
                    }
                    securityRow(label: NSLocalizedString("theme.label.tutorial.reset", comment: "")) {
                        Button(action: { settings.hasCompletedOnboarding = false; dismiss() }) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .bold)).foregroundColor(Theme.textDim)
                        }.buttonStyle(.plain)
                    }
                }
            }

            settingsSection(title: NSLocalizedString("settings.performance", comment: ""), subtitle: settings.performanceMode ? NSLocalizedString("settings.performance.manual", comment: "") : (settings.autoPerformanceMode ? NSLocalizedString("settings.performance.auto", comment: "") : NSLocalizedString("settings.performance.off", comment: ""))) {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle(NSLocalizedString("settings.performance.mode", comment: ""), isOn: $settings.performanceMode)
                        .font(Theme.mono(10, weight: .medium))
                    Toggle(NSLocalizedString("settings.performance.auto.mode", comment: ""), isOn: $settings.autoPerformanceMode)
                        .font(Theme.mono(10, weight: .medium))
                    Text(NSLocalizedString("settings.performance.desc", comment: ""))
                        .font(Theme.mono(8)).foregroundColor(Theme.textDim)
                }
            }

            settingsSection(title: NSLocalizedString("settings.appinfo", comment: ""), subtitle: "v\(UpdateChecker.shared.currentVersion)") {
                VStack(spacing: 10) {
                    securityRow(label: NSLocalizedString("settings.appinfo.version", comment: "")) {
                        Text("v\(UpdateChecker.shared.currentVersion)")
                            .font(Theme.mono(10, weight: .bold)).foregroundColor(Theme.textPrimary)
                    }
                    HStack(spacing: 8) {
                        Button(action: {
                            if let url = URL(string: "https://github.com/jjunhaa0211/MyWorkStudio") {
                                NSWorkspace.shared.open(url)
                            }
                        }) {
                            Text("GitHub").font(Theme.mono(9, weight: .bold))
                                .appButtonSurface(tone: .accent, compact: true)
                        }.buttonStyle(.plain)
                        Button(action: { UpdateChecker.shared.performUpdate() }) {
                            Text(NSLocalizedString("settings.appinfo.update", comment: "")).font(Theme.mono(9, weight: .bold))
                                .appButtonSurface(tone: .green, compact: true)
                        }.buttonStyle(.plain)
                        Spacer()
                    }
                }
            }
        }
    }

    // MARK: - 화면 탭

    private var displayTab: some View {
        VStack(spacing: 14) {
            settingsSection(title: NSLocalizedString("settings.theme", comment: ""), subtitle: NSLocalizedString("settings.theme.subtitle", comment: "")) {
                HStack(spacing: 10) {
                    themeButton(title: "Light", icon: "sun.max.fill", isDark: false)
                    themeButton(title: "Dark", icon: "moon.fill", isDark: true)
                }
            }

            settingsSection(title: NSLocalizedString("settings.backdrop", comment: ""), subtitle: currentTheme.displayName) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                    ForEach(quickBackgroundThemes, id: \.rawValue) { theme in
                        quickBackgroundButton(theme)
                    }
                }
            }

            settingsSection(title: NSLocalizedString("settings.fontsize", comment: ""), subtitle: fontSizeLabel) {
                VStack(spacing: 10) {
                    HStack(spacing: 6) {
                        ForEach(fontSizeOptions, id: \.value) { opt in
                            Button(action: { withAnimation(.easeInOut(duration: 0.15)) { settings.fontSizeScale = opt.value } }) {
                                VStack(spacing: 4) {
                                    Text("Aa")
                                        .font(.system(size: CGFloat(10 * opt.value), weight: .medium, design: .monospaced))
                                        .foregroundColor(isSelectedSize(opt.value) ? Theme.accent : Theme.textSecondary)
                                    Text(opt.label)
                                        .font(.system(size: 8, design: .monospaced))
                                        .foregroundColor(isSelectedSize(opt.value) ? Theme.accent : Theme.textDim)
                                }
                                .frame(maxWidth: .infinity).padding(.vertical, 8)
                                .background(RoundedRectangle(cornerRadius: 8).fill(isSelectedSize(opt.value) ? Theme.accent.opacity(0.11) : Theme.bgSurface))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(isSelectedSize(opt.value) ? Theme.accent.opacity(0.38) : Theme.border.opacity(0.4), lineWidth: 1))
                            }.buttonStyle(.plain)
                        }
                    }
                    settingPreviewCard
                }
            }
        }
    }

    // MARK: - 오피스 탭

    private var officeTab: some View {
        VStack(spacing: 14) {
            settingsSection(title: NSLocalizedString("settings.layout", comment: ""), subtitle: currentOfficePreset.displayName) {
                VStack(spacing: 8) {
                    ForEach(OfficePreset.allCases) { preset in
                        officePresetButton(preset)
                    }
                }
            }

            settingsSection(title: NSLocalizedString("settings.camera", comment: ""), subtitle: settings.officeViewMode == "side" ? NSLocalizedString("settings.camera.focus", comment: "") : NSLocalizedString("settings.camera.full", comment: "")) {
                HStack(spacing: 8) {
                    officeCameraButton(title: NSLocalizedString("settings.camera.full", comment: ""), icon: "rectangle.expand.vertical", mode: "grid")
                    officeCameraButton(title: NSLocalizedString("settings.camera.focus", comment: ""), icon: "scope", mode: "side")
                }
            }
        }
    }

    // MARK: - 토큰 탭

    private var tokenTab: some View {
        let protectionReason = tokenTracker.startBlockReason(isAutomation: false)
        return VStack(spacing: 14) {
            settingsSection(title: NSLocalizedString("settings.usage", comment: ""), subtitle: NSLocalizedString("settings.usage.subtitle", comment: "")) {
                VStack(spacing: 12) {
                    HStack(spacing: 10) {
                        usageMetricCard(
                            title: NSLocalizedString("settings.usage.today", comment: ""),
                            value: tokenTracker.formatTokens(tokenTracker.todayTokens),
                            secondary: "$" + String(format: "%.2f", tokenTracker.todayCost),
                            tint: Theme.accent,
                            progress: tokenTracker.dailyUsagePercent
                        )
                        usageMetricCard(
                            title: NSLocalizedString("settings.usage.week", comment: ""),
                            value: tokenTracker.formatTokens(tokenTracker.weekTokens),
                            secondary: "$" + String(format: "%.2f", tokenTracker.weekCost),
                            tint: Theme.cyan,
                            progress: tokenTracker.weeklyUsagePercent
                        )
                    }

                    HStack(spacing: 12) {
                        tokenLimitField(title: NSLocalizedString("settings.token.daily.limit", comment: ""), value: $tokenTracker.dailyTokenLimit)
                        tokenLimitField(title: NSLocalizedString("settings.token.weekly.limit", comment: ""), value: $tokenTracker.weeklyTokenLimit)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        if let protectionReason {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "lock.shield.fill")
                                    .font(.system(size: Theme.iconSize(11), weight: .bold))
                                    .foregroundColor(Theme.orange)
                                Text(protectionReason)
                                    .font(Theme.mono(8))
                                    .foregroundColor(Theme.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        } else {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.shield.fill")
                                    .font(.system(size: Theme.iconSize(11), weight: .bold))
                                    .foregroundColor(Theme.green)
                                Text(NSLocalizedString("settings.token.ok.desc", comment: ""))
                                    .font(Theme.mono(8))
                                    .foregroundColor(Theme.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }

                        HStack(spacing: 10) {
                            Button(action: {
                                tokenTracker.applyRecommendedMinimumLimits()
                            }) {
                                Text(NSLocalizedString("settings.token.apply.min", comment: ""))
                                    .font(Theme.mono(9, weight: .bold))
                                    .foregroundColor(Theme.cyan)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(RoundedRectangle(cornerRadius: 8).fill(Theme.cyan.opacity(0.1)))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Theme.cyan.opacity(0.25), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)

                            Button(action: {
                                showTokenResetConfirm = true
                            }) {
                                Text(NSLocalizedString("settings.token.reset", comment: ""))
                                    .font(Theme.mono(9, weight: .bold))
                                    .foregroundColor(Theme.orange)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(RoundedRectangle(cornerRadius: 8).fill(Theme.orange.opacity(0.1)))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Theme.orange.opacity(0.25), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Theme.bgSurface.opacity(0.85))
                    )
                }
            }

            settingsSection(title: NSLocalizedString("settings.automation", comment: ""), subtitle: NSLocalizedString("settings.automation.subtitle", comment: "")) {
                VStack(spacing: 10) {
                    settingsToggleRow(
                        title: NSLocalizedString("settings.automation.parallel", comment: ""),
                        subtitle: settings.allowParallelSubagents ? NSLocalizedString("settings.automation.allowed", comment: "") : NSLocalizedString("settings.automation.blocked", comment: ""),
                        isOn: Binding(
                            get: { settings.allowParallelSubagents },
                            set: { settings.allowParallelSubagents = $0 }
                        ),
                        tint: Theme.purple
                    )

                    settingsToggleRow(
                        title: NSLocalizedString("settings.automation.terminal.light", comment: ""),
                        subtitle: settings.terminalSidebarLightweight ? NSLocalizedString("settings.enabled", comment: "") : NSLocalizedString("settings.disabled", comment: ""),
                        isOn: Binding(
                            get: { settings.terminalSidebarLightweight },
                            set: { settings.terminalSidebarLightweight = $0 }
                        ),
                        tint: Theme.cyan
                    )

                    HStack(spacing: 10) {
                        limitStepperCard(
                            title: NSLocalizedString("settings.automation.review.max", comment: ""),
                            subtitle: NSLocalizedString("settings.automation.review.sub", comment: ""),
                            value: Binding(
                                get: { settings.reviewerMaxPasses },
                                set: { settings.reviewerMaxPasses = min(3, max(0, $0)) }
                            ),
                            range: 0...3,
                            tint: Theme.yellow
                        )
                        limitStepperCard(
                            title: "QA 최대",
                            subtitle: NSLocalizedString("settings.automation.qa.sub", comment: ""),
                            value: Binding(
                                get: { settings.qaMaxPasses },
                                set: { settings.qaMaxPasses = min(3, max(0, $0)) }
                            ),
                            range: 0...3,
                            tint: Theme.green
                        )
                    }

                    limitStepperCard(
                        title: NSLocalizedString("settings.automation.revision.max", comment: ""),
                        subtitle: NSLocalizedString("settings.automation.revision.sub", comment: ""),
                        value: Binding(
                            get: { settings.automationRevisionLimit },
                            set: { settings.automationRevisionLimit = min(5, max(1, $0)) }
                        ),
                        range: 1...5,
                        tint: Theme.accent
                    )

                    HStack(spacing: 8) {
                        Image(systemName: "person.3.sequence.fill")
                            .font(.system(size: Theme.iconSize(11), weight: .bold))
                            .foregroundColor(Theme.orange)
                        Text(NSLocalizedString("settings.automation.worker.limit", comment: ""))
                            .font(Theme.mono(8))
                            .foregroundColor(Theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Theme.orange.opacity(0.08))
                    )
                }
            }
        }
    }

    private var templateTab: some View {
        let selectedKind = selectedTemplateKind
        let templateBinding = templateStore.binding(for: selectedKind)

        return VStack(spacing: 14) {
            settingsSection(title: NSLocalizedString("settings.template.workflow", comment: ""), subtitle: selectedKind.displayName) {
                VStack(alignment: .leading, spacing: 10) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8) {
                        ForEach(AutomationTemplateKind.allCases) { kind in
                            templateKindButton(kind)
                        }
                    }

                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: selectedKind.icon)
                            .font(.system(size: Theme.iconSize(11), weight: .bold))
                            .foregroundColor(Theme.cyan)
                        Text(selectedKind.summary)
                            .font(Theme.mono(8))
                            .foregroundColor(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            settingsSection(title: NSLocalizedString("settings.template.editor", comment: ""), subtitle: NSLocalizedString("settings.template.autosave", comment: "")) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        statusHint(
                            icon: templateStore.isCustomized(selectedKind) ? "slider.horizontal.3" : "checkmark.circle.fill",
                            text: templateStore.isCustomized(selectedKind) ? NSLocalizedString("settings.template.custom", comment: "") : NSLocalizedString("settings.template.default", comment: ""),
                            tint: templateStore.isCustomized(selectedKind) ? Theme.orange : Theme.green
                        )
                        Spacer()
                        Button(action: {
                            templateStore.reset(selectedKind)
                        }) {
                            Text(NSLocalizedString("settings.template.reset.current", comment: ""))
                                .font(Theme.mono(9, weight: .bold))
                                .appButtonSurface(tone: .orange, compact: true)
                        }
                        .buttonStyle(.plain)

                        Button(action: {
                            showTemplateResetConfirm = true
                        }) {
                            Text(NSLocalizedString("settings.template.reset.all", comment: ""))
                                .font(Theme.mono(9, weight: .bold))
                                .appButtonSurface(tone: .red, compact: true)
                        }
                        .buttonStyle(.plain)
                    }

                    TextEditor(text: templateBinding)
                        .scrollContentBackground(.hidden)
                        .font(Theme.mono(10))
                        .foregroundColor(Theme.textPrimary)
                        .frame(minHeight: 260)
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Theme.bgSurface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Theme.border.opacity(0.35), lineWidth: 1)
                        )

                    VStack(alignment: .leading, spacing: 8) {
                        Text(NSLocalizedString("settings.template.placeholders", comment: ""))
                            .font(Theme.mono(9, weight: .bold))
                            .foregroundColor(Theme.textDim)

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 8)], spacing: 8) {
                            ForEach(selectedKind.placeholderTokens, id: \.self) { token in
                                templateTokenPill(token, tint: Theme.cyan)
                            }
                        }
                    }

                    if !selectedKind.pinnedLines.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(NSLocalizedString("settings.template.pinned", comment: ""))
                                .font(Theme.mono(9, weight: .bold))
                                .foregroundColor(Theme.textDim)
                            Text(NSLocalizedString("settings.template.pinned.desc", comment: ""))
                                .font(Theme.mono(8))
                                .foregroundColor(Theme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)

                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 8)], spacing: 8) {
                                ForEach(selectedKind.pinnedLines, id: \.self) { line in
                                    templateTokenPill(line, tint: Theme.purple)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var supportTab: some View {
        VStack(spacing: 14) {
            CoffeeSupportPopoverView(embedded: true)
        }
    }

    // MARK: - 보안 탭

    private var securityTab: some View {
        VStack(spacing: 14) {
            // 세션 잠금 + 결제일
            settingsSection(title: NSLocalizedString("settings.security.session", comment: ""), subtitle: settings.lockPIN.isEmpty ? NSLocalizedString("settings.security.lock.off", comment: "") : NSLocalizedString("settings.security.lock.on", comment: "")) {
                VStack(spacing: 10) {
                    securityRow(label: NSLocalizedString("settings.security.pin", comment: "")) {
                        SecureField(NSLocalizedString("settings.security.pin.placeholder", comment: ""), text: $settings.lockPIN)
                            .font(Theme.monoSmall).textFieldStyle(.plain)
                            .frame(width: 100).padding(6)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Theme.bgSurface))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.border, lineWidth: 0.5))
                    }
                    securityRow(label: NSLocalizedString("settings.security.autolock", comment: "")) {
                        Picker("", selection: $settings.autoLockMinutes) {
                            Text(NSLocalizedString("settings.none", comment: "")).tag(0)
                            Text(NSLocalizedString("settings.1min", comment: "")).tag(1); Text(NSLocalizedString("settings.3min", comment: "")).tag(3)
                            Text(NSLocalizedString("settings.5min", comment: "")).tag(5); Text(NSLocalizedString("settings.10min", comment: "")).tag(10)
                        }.frame(width: 120)
                    }
                    securityRow(label: NSLocalizedString("settings.security.billing", comment: "")) {
                        Picker("", selection: $settings.billingDay) {
                            Text(NSLocalizedString("settings.notset", comment: "")).tag(0)
                            ForEach(1...31, id: \.self) { day in Text(String(format: NSLocalizedString("settings.day.format", comment: ""), day)).tag(day) }
                        }.frame(width: 100)
                    }
                }
            }

            // 비용 제한
            settingsSection(title: NSLocalizedString("settings.security.cost", comment: ""), subtitle: settings.dailyCostLimit > 0 ? "$\(String(format: "%.0f", settings.dailyCostLimit))/" + NSLocalizedString("settings.day", comment: "") : NSLocalizedString("settings.unlimited", comment: "")) {
                VStack(spacing: 10) {
                    securityRow(label: NSLocalizedString("settings.security.cost.daily", comment: "")) {
                        TextField("0", value: $settings.dailyCostLimit, format: .number)
                            .font(Theme.monoSmall).textFieldStyle(.plain)
                            .frame(width: 80).padding(6)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Theme.bgSurface))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.border, lineWidth: 0.5))
                    }
                    securityRow(label: NSLocalizedString("settings.security.cost.session", comment: "")) {
                        TextField("0", value: $settings.perSessionCostLimit, format: .number)
                            .font(Theme.monoSmall).textFieldStyle(.plain)
                            .frame(width: 80).padding(6)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Theme.bgSurface))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.border, lineWidth: 0.5))
                    }
                    Toggle(NSLocalizedString("settings.security.cost.warn80", comment: ""), isOn: $settings.costWarningAt80)
                        .font(Theme.mono(10, weight: .medium))
                        .tint(Theme.accent)
                }
            }

            // 보호 기능 통합
            settingsSection(title: NSLocalizedString("settings.security.protection", comment: ""), subtitle: NSLocalizedString("settings.security.protection.subtitle", comment: "")) {
                VStack(spacing: 10) {
                    Toggle(NSLocalizedString("settings.security.danger.detect", comment: ""), isOn: Binding(
                        get: { DangerousCommandDetector.shared.enabled },
                        set: { DangerousCommandDetector.shared.enabled = $0 }
                    )).font(Theme.mono(10, weight: .medium)).tint(Theme.accent)

                    Toggle(NSLocalizedString("settings.security.sensitive.file", comment: ""), isOn: Binding(
                        get: { SensitiveFileShield.shared.enabled },
                        set: { SensitiveFileShield.shared.enabled = $0 }
                    )).font(Theme.mono(10, weight: .medium)).tint(Theme.accent)

                    Toggle(NSLocalizedString("settings.security.audit.log", comment: ""), isOn: Binding(
                        get: { AuditLog.shared.enabled },
                        set: { AuditLog.shared.enabled = $0 }
                    )).font(Theme.mono(10, weight: .medium)).tint(Theme.accent)

                    HStack(spacing: 8) {
                        Button(action: {
                            if let data = AuditLog.shared.exportJSON() {
                                let panel = NSSavePanel()
                                panel.nameFieldStringValue = "workman_audit_log.json"
                                panel.allowedContentTypes = [.json]
                                if panel.runModal() == .OK, let url = panel.url {
                                    try? data.write(to: url)
                                }
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.down.doc").font(.system(size: 10))
                                Text(NSLocalizedString("settings.security.log.export", comment: "")).font(Theme.mono(9, weight: .medium))
                            }
                            .foregroundColor(Theme.accent)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Theme.accent.opacity(0.08)))
                        }.buttonStyle(.plain)

                        Button(action: { AuditLog.shared.clear() }) {
                            HStack(spacing: 4) {
                                Image(systemName: "trash").font(.system(size: 10))
                                Text(NSLocalizedString("settings.security.log.delete", comment: "")).font(Theme.mono(9, weight: .medium))
                            }
                            .foregroundColor(Theme.red)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Theme.red.opacity(0.08)))
                        }.buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - 데이터 탭

    private var dataTab: some View {
        VStack(spacing: 14) {
            settingsSection(title: NSLocalizedString("settings.data.storage", comment: ""), subtitle: cacheSize) {
                VStack(alignment: .leading, spacing: 12) {
                    dataRow(icon: "doc.text.fill", title: NSLocalizedString("settings.data.sessions", comment: ""), detail: String(format: NSLocalizedString("settings.data.count", comment: ""), SessionStore.shared.sessionCount), tint: Theme.accent)
                    dataRow(icon: "bolt.fill", title: NSLocalizedString("settings.data.tokens", comment: ""), detail: tokenTracker.formatTokens(tokenTracker.weekTokens), tint: Theme.yellow)
                    dataRow(icon: "building.2.fill", title: NSLocalizedString("settings.data.office.layout", comment: ""), detail: "UserDefaults", tint: Theme.cyan)
                    dataRow(icon: "trophy.fill", title: NSLocalizedString("settings.data.achievements", comment: ""), detail: "UserDefaults", tint: Theme.purple)
                    dataRow(icon: "person.2.fill", title: NSLocalizedString("settings.data.characters", comment: ""), detail: "UserDefaults", tint: Theme.green)
                }
            }

            settingsSection(title: NSLocalizedString("settings.data.cache", comment: ""), subtitle: NSLocalizedString("settings.data.cache.subtitle", comment: "")) {
                VStack(spacing: 10) {
                    Button(action: {
                        clearAllMode = false
                        showClearConfirm = true
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "wind").font(.system(size: Theme.iconSize(11), weight: .bold))
                            Text(NSLocalizedString("settings.data.cache.old", comment: "")).font(Theme.mono(11, weight: .semibold))
                            Spacer()
                            Text(NSLocalizedString("settings.data.cache.old.desc", comment: ""))
                                .font(Theme.mono(8)).foregroundColor(Theme.textDim)
                        }
                        .foregroundColor(Theme.orange)
                        .appButtonSurface(tone: .orange)
                    }.buttonStyle(.plain)

                    Button(action: {
                        clearAllMode = true
                        showClearConfirm = true
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "trash.fill").font(.system(size: Theme.iconSize(11), weight: .bold))
                            Text(NSLocalizedString("settings.data.delete.all", comment: "")).font(Theme.mono(11, weight: .semibold))
                            Spacer()
                            Text(NSLocalizedString("settings.data.delete.all.desc", comment: ""))
                                .font(Theme.mono(8)).foregroundColor(Theme.textDim)
                        }
                        .foregroundColor(Theme.red)
                        .appButtonSurface(tone: .red)
                    }.buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Data Helpers

    private func dataRow(icon: String, title: String, detail: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: Theme.iconSize(10), weight: .bold)).foregroundColor(tint)
                .frame(width: 20)
            Text(title).font(Theme.mono(10, weight: .medium)).foregroundColor(Theme.textPrimary)
            Spacer()
            Text(detail).font(Theme.mono(9)).foregroundColor(Theme.textSecondary)
        }
    }

    private func calculateCacheSize() {
        var totalBytes: Int64 = 0
        // Application Support 디렉토리
        if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let workmanDir = appSupport.appendingPathComponent("WorkMan")
            if let enumerator = FileManager.default.enumerator(at: workmanDir, includingPropertiesForKeys: [.fileSizeKey]) {
                for case let url as URL in enumerator {
                    if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                        totalBytes += Int64(size)
                    }
                }
            }
        }
        // UserDefaults 추정 (대략적)
        let udKeys = ["WorkManTokenHistory", "WorkManCharacters", "WorkManCharacterManualUnlocks", "WorkManAchievements"]
        for key in udKeys {
            if let data = UserDefaults.standard.data(forKey: key) {
                totalBytes += Int64(data.count)
            } else if let dict = UserDefaults.standard.dictionary(forKey: key),
                      let data = try? JSONSerialization.data(withJSONObject: dict) {
                totalBytes += Int64(data.count)
            }
        }
        if totalBytes < 1024 {
            cacheSize = "\(totalBytes) B"
        } else if totalBytes < 1024 * 1024 {
            cacheSize = String(format: "%.1f KB", Double(totalBytes) / 1024.0)
        } else {
            cacheSize = String(format: "%.1f MB", Double(totalBytes) / (1024.0 * 1024.0))
        }
    }

    private func clearOldCache() {
        // 완료된 세션 기록만 삭제 (빈 리스트로 저장)
        SessionStore.shared.save(tabs: [])
        // 토큰 이력 중 오래된 것은 TokenTracker가 자동 관리하므로 수동 리셋
        TokenTracker.shared.clearOldEntries()
        calculateCacheSize()
    }

    private func clearAllData() {
        // 세션 기록 삭제
        SessionStore.shared.save(tabs: [])
        // 토큰 데이터 삭제
        TokenTracker.shared.clearAllEntries()
        // 업적 데이터 삭제
        UserDefaults.standard.removeObject(forKey: "WorkManAchievements")
        // 캐릭터 데이터 삭제
        UserDefaults.standard.removeObject(forKey: "WorkManCharacters")
        CharacterRegistry.shared.clearManualUnlocks()
        UserDefaults.standard.removeObject(forKey: "WorkManCharacterManualUnlocks")
        // 오피스 레이아웃 삭제
        for preset in OfficePreset.allCases {
            UserDefaults.standard.removeObject(forKey: "workman.office.layout.\(preset.rawValue).v1")
        }
        // 가구 위치 초기화
        settings.resetFurniturePositions()
        calculateCacheSize()
    }

    private var settingsHeroCard: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 18)
                .fill(
                    LinearGradient(
                        colors: [
                            Theme.accent.opacity(0.16),
                            Theme.purple.opacity(0.14),
                            Theme.bgCard
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Theme.border.opacity(0.35), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(NSLocalizedString("settings.title", comment: ""))
                            .font(Theme.mono(16, weight: .black))
                            .foregroundColor(Theme.textPrimary)
                        Text(NSLocalizedString("settings.subtitle", comment: ""))
                            .font(Theme.mono(10))
                            .foregroundColor(Theme.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: Theme.iconSize(15), weight: .bold))
                        .foregroundColor(Theme.accent)
                        .padding(10)
                        .background(Circle().fill(Theme.accent.opacity(0.12)))
                }

                HStack(spacing: 10) {
                    heroPill(title: settings.appDisplayName, subtitle: "Workspace", tint: Theme.accent)
                    heroPill(title: settings.isDarkMode ? "Dark" : "Light", subtitle: "Theme", tint: Theme.purple)
                    heroPill(title: currentTheme.displayName, subtitle: "Backdrop", tint: Theme.cyan)
                }
            }
            .padding(18)
        }
        .frame(height: 132)
    }

    private func settingsSection<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Theme.sp3) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.mono(11, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                Text(subtitle)
                    .font(Theme.mono(9))
                    .foregroundColor(Theme.textDim)
            }
            content()
        }
        .padding(Theme.sp4)
        .background(RoundedRectangle(cornerRadius: Theme.cornerLarge).fill(Theme.bgCard))
        .overlay(RoundedRectangle(cornerRadius: Theme.cornerLarge).stroke(Theme.border, lineWidth: 1))
    }

    private func securityRow<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(label).font(Theme.mono(10, weight: .medium)).foregroundColor(Theme.textPrimary)
            Spacer()
            content()
        }
    }

    private func labeledField(
        title: String,
        text: Binding<String>,
        placeholder: String,
        emphasized: Bool = false,
        onSubmit: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(Theme.mono(10, weight: .bold))
                .foregroundColor(Theme.textDim)

            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .font(Theme.mono(11, weight: emphasized ? .semibold : .regular))
                .foregroundColor(Theme.textPrimary)
                .appFieldStyle(emphasized: emphasized)
                .onSubmit { onSubmit() }
                .onChange(of: text.wrappedValue) { _, _ in onSubmit() }
        }
    }

    private var settingPreviewCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("settings.preview", comment: ""))
                .font(Theme.mono(9, weight: .bold))
                .foregroundColor(Theme.textDim)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Circle().fill(Theme.green).frame(width: 6, height: 6)
                    Text("EDIT")
                        .font(Theme.mono(10, weight: .bold))
                        .foregroundColor(Theme.green)
                    Text("(OfficeSceneView.swift)")
                        .font(Theme.mono(10))
                        .foregroundColor(Theme.textSecondary)
                }

                Text(NSLocalizedString("settings.preview.desc", comment: ""))
                    .font(Theme.monoNormal)
                    .foregroundColor(Theme.textPrimary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Theme.bgTerminal)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Theme.border.opacity(0.45), lineWidth: 1)
            )
        }
    }

    private func themeButton(title: String, icon: String, isDark: Bool) -> some View {
        let selected = settings.isDarkMode == isDark
        let tint = isDark ? Theme.yellow : Theme.orange
        return Button(action: { withAnimation(.easeInOut(duration: 0.2)) { settings.isDarkMode = isDark }; settings.requestRefreshIfNeeded() }) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: Theme.iconSize(14)))
                    .foregroundColor(selected ? tint : Theme.textDim)
                Text(title)
                    .font(Theme.mono(11, weight: selected ? .bold : .regular))
                    .foregroundColor(selected ? Theme.textPrimary : Theme.textSecondary)
                Spacer()
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: Theme.iconSize(12)))
                        .foregroundColor(tint)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: Theme.cornerMedium)
                    .fill(selected ? tint.opacity(0.1) : Theme.bgSurface.opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerMedium)
                    .stroke(selected ? tint.opacity(Theme.borderActiveOpacity) : Theme.border.opacity(Theme.borderLight), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    struct FontSizeOption {
        let value: Double
        let label: String
    }

    private var fontSizeOptions: [FontSizeOption] {
        [
            FontSizeOption(value: 1.2, label: "S"),
            FontSizeOption(value: 1.5, label: "M"),
            FontSizeOption(value: 1.8, label: "L"),
            FontSizeOption(value: 2.2, label: "XL"),
            FontSizeOption(value: 2.7, label: "XXL"),
        ]
    }

    private func isSelectedSize(_ v: Double) -> Bool {
        abs(settings.fontSizeScale - v) < 0.05
    }

    private var fontSizeLabel: String {
        fontSizeOptions.first(where: { isSelectedSize($0.value) })?.label ?? "\(Int(settings.fontSizeScale * 100))%"
    }

    private var currentTheme: BackgroundTheme {
        BackgroundTheme(rawValue: settings.backgroundTheme) ?? .auto
    }

    private var currentOfficePreset: OfficePreset {
        OfficePreset(rawValue: settings.officePreset) ?? .cozy
    }

    private var quickBackgroundThemes: [BackgroundTheme] {
        [.auto, .sunny, .goldenHour, .moonlit, .rain, .neonCity]
    }

    private func quickBackgroundButton(_ theme: BackgroundTheme) -> some View {
        let selected = currentTheme == theme
        let locked = !theme.isUnlocked
        return Button(action: {
            guard !locked else { return }
            withAnimation(.easeInOut(duration: 0.15)) {
                settings.backgroundTheme = theme.rawValue
            }
        }) {
            HStack(spacing: 6) {
                Image(systemName: locked ? "lock.fill" : theme.icon)
                    .font(.system(size: Theme.iconSize(10), weight: .bold))
                Text(theme.displayName)
                    .font(Theme.mono(9, weight: selected ? .bold : .medium))
                    .lineLimit(1)
                Spacer(minLength: 0)
                if locked {
                    Text(theme.lockReason)
                        .font(Theme.mono(7))
                        .foregroundColor(Theme.textDim.opacity(0.6))
                        .lineLimit(1)
                }
            }
            .foregroundColor(locked ? Theme.textDim.opacity(0.5) : (selected ? Theme.purple : Theme.textSecondary))
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(selected && !locked ? Theme.purple.opacity(0.12) : Theme.bgSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(locked ? Theme.border.opacity(0.15) : (selected ? Theme.purple.opacity(0.35) : Theme.border.opacity(0.3)), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func officePresetButton(_ preset: OfficePreset) -> some View {
        let selected = currentOfficePreset == preset
        let tint = Theme.cyan
        return Button(action: {
            withAnimation(.easeInOut(duration: 0.15)) {
                settings.officePreset = preset.rawValue
            }
        }) {
            HStack(spacing: 10) {
                Image(systemName: preset.icon)
                    .font(.system(size: Theme.iconSize(12), weight: .bold))
                    .foregroundColor(selected ? tint : Theme.textDim)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 3) {
                    Text(preset.displayName)
                        .font(Theme.mono(10, weight: .bold))
                        .foregroundColor(selected ? Theme.textPrimary : Theme.textSecondary)
                    Text(preset.subtitle)
                        .font(Theme.mono(8))
                        .foregroundColor(Theme.textDim)
                        .lineLimit(2)
                }

                Spacer()

                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: Theme.iconSize(12)))
                        .foregroundColor(tint)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: Theme.cornerMedium)
                    .fill(selected ? tint.opacity(0.1) : Theme.bgSurface.opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerMedium)
                    .stroke(selected ? tint.opacity(Theme.borderActiveOpacity) : Theme.border.opacity(Theme.borderLight), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func officeCameraButton(title: String, icon: String, mode: String) -> some View {
        let selected = settings.officeViewMode == mode
        let tint = Theme.purple
        return Button(action: {
            withAnimation(.easeInOut(duration: 0.15)) {
                settings.officeViewMode = mode
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: Theme.iconSize(11), weight: .bold))
                Text(title)
                    .font(Theme.mono(10, weight: .bold))
                Spacer()
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: Theme.iconSize(12)))
                        .foregroundColor(tint)
                }
            }
            .foregroundColor(selected ? tint : Theme.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: Theme.cornerMedium)
                    .fill(selected ? tint.opacity(0.1) : Theme.bgSurface.opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerMedium)
                    .stroke(selected ? tint.opacity(Theme.borderActiveOpacity) : Theme.border.opacity(Theme.borderLight), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func templateKindButton(_ kind: AutomationTemplateKind) -> some View {
        let selected = selectedTemplateKind == kind
        let tint = Theme.cyan
        return Button(action: {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedTemplateKind = kind
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: kind.icon)
                    .font(.system(size: Theme.iconSize(11), weight: .bold))
                    .foregroundColor(selected ? tint : Theme.textDim)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 2) {
                    Text(kind.shortLabel)
                        .font(Theme.mono(9, weight: .bold))
                        .foregroundColor(selected ? Theme.textPrimary : Theme.textSecondary)
                    Text(kind.summary)
                        .font(Theme.mono(7))
                        .foregroundColor(Theme.textDim)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: Theme.iconSize(12)))
                        .foregroundColor(tint)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: Theme.cornerMedium)
                    .fill(selected ? tint.opacity(0.1) : Theme.bgSurface.opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerMedium)
                    .stroke(selected ? tint.opacity(Theme.borderActiveOpacity) : Theme.border.opacity(Theme.borderLight), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func templateTokenPill(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(Theme.mono(8, weight: .semibold))
            .foregroundColor(tint)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 9)
                    .fill(tint.opacity(0.09))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9)
                    .stroke(tint.opacity(0.22), lineWidth: 1)
            )
    }

    private func heroPill(title: String, subtitle: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(subtitle)
                .font(Theme.mono(7, weight: .bold))
                .foregroundColor(tint.opacity(0.75))
            Text(title)
                .font(Theme.mono(10, weight: .bold))
                .foregroundColor(Theme.textPrimary)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Theme.bgSurface.opacity(0.9))
        )
    }

    private func usageMetricCard(
        title: String,
        value: String,
        secondary: String,
        tint: Color,
        progress: Double
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(Theme.mono(8, weight: .bold))
                .foregroundColor(Theme.textDim)
            Text(value)
                .font(Theme.mono(13, weight: .black))
                .foregroundColor(tint)
            Text(secondary)
                .font(Theme.mono(8))
                .foregroundColor(Theme.textSecondary)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.bgSurface)
                    Capsule()
                        .fill(tint.opacity(0.88))
                        .frame(width: max(8, geo.size.width * CGFloat(min(progress, 1.0))))
                }
            }
            .frame(height: 6)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Theme.bgSurface.opacity(0.85))
        )
    }

    private func tokenLimitField(title: String, value: Binding<Int>) -> some View {
        let safeBinding = Binding<Int>(
            get: { value.wrappedValue },
            set: { value.wrappedValue = max(1, $0) }
        )
        return VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(Theme.mono(9, weight: .bold))
                .foregroundColor(Theme.textDim)
            HStack(spacing: 6) {
                TextField("", value: safeBinding, format: .number)
                    .textFieldStyle(.plain)
                    .font(Theme.mono(11, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Theme.bgSurface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Theme.border.opacity(0.35), lineWidth: 1)
                    )
                Text("tokens")
                    .font(Theme.mono(8))
                    .foregroundColor(Theme.textDim)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func statusHint(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: Theme.iconSize(10), weight: .bold))
            Text(text)
                .font(Theme.mono(9, weight: .medium))
        }
        .foregroundColor(tint)
    }

    // ── Secret Key ──
    @State private var secretKeyInput = ""
    @State private var secretKeyResult: SecretKeyResult = .none
    enum SecretKeyResult { case none, success, wrong }

    private static let normalizedSecretKey = "i dont like snatch"

    private static func normalizeSecretKey(_ value: String) -> String {
        let folded = value.folding(options: [.diacriticInsensitive, .widthInsensitive], locale: .current).lowercased()
        let allowed = CharacterSet.alphanumerics.union(.whitespacesAndNewlines)
        let stripped = String(folded.unicodeScalars.filter { allowed.contains($0) })
        return stripped
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private func applySecretKey() {
        let key = Self.normalizeSecretKey(secretKeyInput)
        if key == Self.normalizedSecretKey {
            _ = CharacterRegistry.shared.unlockAllCharacters()
            UserDefaults.standard.set(true, forKey: "allContentUnlocked")
            withAnimation(.easeInOut(duration: 0.3)) { secretKeyResult = .success }
            secretKeyInput = ""
        } else {
            withAnimation(.easeInOut(duration: 0.3)) { secretKeyResult = .wrong }
        }
        // 3초 후 결과 메시지 숨기기
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation { secretKeyResult = .none }
        }
    }
}

enum CoffeeSupportProvider: String, CaseIterable, Identifiable {
    case kakaoBank
    case toss

    var id: String { rawValue }

    var title: String {
        switch self {
        case .kakaoBank: return NSLocalizedString("coffee.bank.kakao", comment: "")
        case .toss: return NSLocalizedString("coffee.bank.toss", comment: "")
        }
    }

    var icon: String {
        switch self {
        case .kakaoBank: return "building.columns.fill"
        case .toss: return "paperplane.fill"
        }
    }

    var tint: Color {
        switch self {
        case .kakaoBank: return Theme.yellow
        case .toss: return Theme.cyan
        }
    }

    var appURL: URL? {
        switch self {
        case .kakaoBank:
            return URL(string: "kakaobank://")
        case .toss:
            return URL(string: "supertoss://toss/pay")
        }
    }

    var fallbackURL: URL? {
        switch self {
        case .kakaoBank:
            return URL(string: "https://www.kakaobank.com/view/main")
        case .toss:
            return URL(string: "https://toss.im")
        }
    }

    var subtitle: String {
        switch self {
        case .kakaoBank: return NSLocalizedString("coffee.bank.kakao.subtitle", comment: "")
        case .toss: return NSLocalizedString("coffee.bank.toss.subtitle", comment: "")
        }
    }
}

struct CoffeeSupportPopoverView: View {
    @ObservedObject private var settings = AppSettings.shared
    var onRequestSettings: (() -> Void)? = nil
    var embedded: Bool = false

    @State private var feedback: Feedback?
    @State private var copied = false

    private struct Feedback {
        let icon: String
        let text: String
        let tint: Color
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 헤더
            HStack(spacing: 12) {
                Text(settings.coffeeSupportDisplayTitle)
                    .font(Theme.mono(14, weight: .black))
                    .foregroundColor(Theme.textPrimary)
                Spacer()
            }

            // 안내 메시지
            Text(settings.coffeeSupportMessage)
                .font(Theme.mono(9))
                .foregroundColor(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if settings.hasCoffeeSupportDestination {
                // 계좌 카드
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(settings.trimmedCoffeeSupportBankName.isEmpty ? NSLocalizedString("coffee.bank.kakao", comment: "") : settings.trimmedCoffeeSupportBankName)
                                .font(Theme.mono(9, weight: .semibold))
                                .foregroundColor(Theme.textDim)
                            Text(settings.trimmedCoffeeSupportAccountNumber.isEmpty ? "7777015832634" : settings.trimmedCoffeeSupportAccountNumber)
                                .font(Theme.mono(15, weight: .black))
                                .foregroundColor(Theme.textPrimary)
                        }
                        Spacer()
                        Button(action: {
                            copySupportAccount(showFeedback: true)
                            withAnimation(.easeInOut(duration: 0.2)) { copied = true }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                withAnimation { copied = false }
                            }
                        }) {
                            HStack(spacing: 5) {
                                Image(systemName: copied ? "checkmark" : "doc.on.doc.fill")
                                    .font(.system(size: Theme.iconSize(10), weight: .bold))
                                Text(copied ? NSLocalizedString("coffee.copied", comment: "") : NSLocalizedString("coffee.copy", comment: ""))
                                    .font(Theme.mono(9, weight: .bold))
                            }
                            .foregroundColor(copied ? Theme.green : Theme.orange)
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(Capsule().fill((copied ? Theme.green : Theme.orange).opacity(0.12)))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Theme.bgSurface.opacity(0.7))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Theme.border.opacity(0.25), lineWidth: 1)
                    )
                }

                // 송금 버튼들
                VStack(spacing: 6) {
                    ForEach(CoffeeSupportProvider.allCases) { provider in
                        providerButton(provider)
                    }
                }

                // 안내
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.system(size: Theme.iconSize(9)))
                        .foregroundColor(Theme.textDim)
                    Text(NSLocalizedString("coffee.fallback.info", comment: ""))
                        .font(Theme.mono(8))
                        .foregroundColor(Theme.textDim)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                // 계좌 미설정 상태
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.system(size: Theme.iconSize(11), weight: .bold))
                            .foregroundColor(Theme.orange)
                        Text(NSLocalizedString("coffee.setup.hint", comment: ""))
                            .font(Theme.mono(9))
                            .foregroundColor(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let onRequestSettings {
                        Button(action: onRequestSettings) {
                            Text(NSLocalizedString("coffee.open.settings", comment: ""))
                                .font(Theme.mono(9, weight: .bold))
                                .foregroundColor(Theme.orange)
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .background(RoundedRectangle(cornerRadius: 8).fill(Theme.orange.opacity(0.1)))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.bgSurface.opacity(0.5)))
            }

            if let feedback {
                HStack(spacing: 6) {
                    Image(systemName: feedback.icon)
                        .font(.system(size: Theme.iconSize(10), weight: .bold))
                    Text(feedback.text)
                        .font(Theme.mono(8, weight: .medium))
                }
                .foregroundColor(feedback.tint)
                .transition(.opacity)
            }
        }
        .padding(embedded ? 0 : 16)
        .frame(maxWidth: embedded ? .infinity : 320, alignment: .leading)
        .background(embedded ? AnyShapeStyle(.clear) : AnyShapeStyle(Theme.bgCard))
        .clipShape(RoundedRectangle(cornerRadius: embedded ? 0 : 16))
        .overlay(
            RoundedRectangle(cornerRadius: embedded ? 0 : 16)
                .stroke(embedded ? .clear : Theme.border.opacity(0.35), lineWidth: embedded ? 0 : 1)
        )
        .onAppear {
            settings.ensureCoffeeSupportPreset()
        }
    }

    private func providerButton(_ provider: CoffeeSupportProvider) -> some View {
        Button(action: { openProvider(provider) }) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(provider.tint.opacity(0.12))
                        .frame(width: 38, height: 38)
                    Image(systemName: provider.icon)
                        .font(.system(size: Theme.iconSize(14), weight: .bold))
                        .foregroundColor(provider.tint)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(provider.title)
                        .font(Theme.mono(10, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                    Text(provider.subtitle)
                        .font(Theme.mono(8))
                        .foregroundColor(Theme.textSecondary)
                }

                Spacer(minLength: 0)

                Text(NSLocalizedString("coffee.open", comment: ""))
                    .font(Theme.mono(8, weight: .bold))
                    .foregroundColor(provider.tint)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(provider.tint.opacity(0.1))
                    )
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Theme.bgSurface.opacity(0.65))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(provider.tint.opacity(0.18), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func openProvider(_ provider: CoffeeSupportProvider) {
        guard copySupportAccount(showFeedback: false) else {
            feedback = Feedback(icon: "exclamationmark.triangle.fill", text: NSLocalizedString("coffee.account.empty", comment: ""), tint: Theme.orange)
            return
        }

        if let appURL = provider.appURL, NSWorkspace.shared.open(appURL) {
            feedback = Feedback(icon: "arrow.up.right.square.fill", text: String(format: NSLocalizedString("coffee.opened", comment: ""), provider.title), tint: provider.tint)
            return
        }

        if let fallbackURL = provider.fallbackURL, NSWorkspace.shared.open(fallbackURL) {
            feedback = Feedback(icon: "safari.fill", text: String(format: NSLocalizedString("coffee.fallback.opened", comment: ""), provider.title), tint: provider.tint)
            return
        }

        feedback = Feedback(icon: "doc.on.doc.fill", text: String(format: NSLocalizedString("coffee.copy.only", comment: ""), provider.title), tint: provider.tint)
    }

    @discardableResult
    private func copySupportAccount(showFeedback: Bool) -> Bool {
        let accountText = settings.coffeeSupportAccountDisplayText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !accountText.isEmpty else { return false }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(accountText, forType: .string)

        if showFeedback {
            feedback = Feedback(icon: "doc.on.doc.fill", text: NSLocalizedString("coffee.account.copied", comment: ""), tint: Theme.orange)
        }
        return true
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - Accessory View (휴게실 배치 & 가구 설정)
// ═══════════════════════════════════════════════════════

struct AccessoryView: View {
    @ObservedObject var settings = AppSettings.shared
    @Environment(\.dismiss) var dismiss
    @State private var selectedTab = 0  // 0=악세서리, 1=배경

    private let accessoryTabs: [(String, String)] = [("sofa.fill", NSLocalizedString("accessory.tab.furniture", comment: "")), ("photo.fill", NSLocalizedString("accessory.tab.background", comment: ""))]

    var body: some View {
        VStack(spacing: 0) {
            DSModalHeader(
                icon: "paintpalette.fill",
                iconColor: Theme.purple,
                title: NSLocalizedString("accessory.title", comment: ""),
                subtitle: NSLocalizedString("accessory.subtitle", comment: ""),
                onClose: { dismiss() }
            )

            // 탭 선택
            DSTabBar(tabs: accessoryTabs, selectedIndex: $selectedTab)
                .padding(.horizontal, Theme.sp4)
                .padding(.vertical, Theme.sp2)

            Rectangle().fill(Theme.border).frame(height: 1)

            // 탭 내용
            if selectedTab == 0 {
                accessoryTabContent
            } else {
                backgroundTabContent
            }
        }
        .padding(24)
        .background(Theme.bgCard)
    }

    private func tabButton(_ title: String, icon: String, tab: Int) -> some View {
        Button(action: { withAnimation(.easeInOut(duration: 0.15)) { selectedTab = tab } }) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: Theme.iconSize(10)))
                Text(title).font(Theme.mono(11, weight: selectedTab == tab ? .bold : .medium))
            }
            .foregroundColor(selectedTab == tab ? Theme.purple : Theme.textDim)
            .frame(maxWidth: .infinity).padding(.vertical, 8)
            .background(selectedTab == tab ? Theme.purple.opacity(0.1) : .clear)
            .cornerRadius(6)
        }.buttonStyle(.plain)
    }

    // MARK: - 악세서리 탭

    private var accessoryTabContent: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 16) {
                // 가구 목록 (미리보기 카드 형식)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                    ForEach(FurnitureItem.all) { item in
                        furnitureCard(item)
                    }
                }

                // ── 가구 배치 ──
                VStack(alignment: .leading, spacing: 10) {
                    Text(NSLocalizedString("accessory.placement", comment: "")).font(Theme.pixel).foregroundColor(Theme.textDim).tracking(1.5)

                    Button(action: { settings.isEditMode = true; dismiss() }) {
                        HStack(spacing: 8) {
                            Image(systemName: "hand.draw.fill").font(.system(size: Theme.iconSize(12))).foregroundColor(Theme.textOnAccent)
                            Text(NSLocalizedString("accessory.drag.hint", comment: "")).font(Theme.mono(11, weight: .bold)).foregroundColor(Theme.textOnAccent)
                            Spacer()
                            Image(systemName: "arrow.right.circle.fill").font(.system(size: Theme.iconSize(14))).foregroundColor(Theme.textOnAccent.opacity(0.7))
                        }
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 10).fill(
                            LinearGradient(colors: [Theme.purple, Theme.accent], startPoint: .leading, endPoint: .trailing)))
                    }.buttonStyle(.plain)

                    Button(action: { settings.resetFurniturePositions() }) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.counterclockwise").font(.system(size: Theme.iconSize(10))).foregroundColor(Theme.textDim)
                            Text(NSLocalizedString("accessory.reset.placement", comment: "")).font(Theme.mono(10)).foregroundColor(Theme.textSecondary)
                        }
                        .padding(.vertical, 8).padding(.horizontal, 12)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Theme.bgSurface)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border.opacity(0.3), lineWidth: 0.5)))
                    }.buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - 배경 탭

    private var backgroundTabContent: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 12) {
                HStack {
                    Text(NSLocalizedString("accessory.bg.theme", comment: "")).font(Theme.pixel).foregroundColor(Theme.textDim).tracking(1.5)
                    Spacer()
                    Text(currentTheme.displayName).font(Theme.mono(9, weight: .bold)).foregroundColor(Theme.purple)
                }

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
                    ForEach(BackgroundTheme.allCases) { theme in
                        bgThemeButton(theme)
                    }
                }
            }
        }
    }

    // MARK: - 가구 카드 (미리보기 포함)

    private func furnitureCard(_ item: FurnitureItem) -> some View {
        let isOn = isFurnitureOn(item.id)
        let locked = !item.isUnlocked
        return Button(action: { guard !locked else { return }; withAnimation(.easeInOut(duration: 0.15)) { toggleFurniture(item.id) } }) {
            VStack(spacing: 6) {
                // 미리보기 영역
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(locked ? Theme.bgSurface.opacity(0.5) : (isOn ? Theme.purple.opacity(0.08) : Theme.bgSurface))
                        .frame(height: 50)

                    // 픽셀 아트 미리보기 (Canvas)
                    Canvas { context, size in
                        let cx = size.width / 2 - item.width / 2
                        let cy = size.height / 2 - item.height / 2 + 2
                        drawFurniturePreview(context: context, item: item, at: CGPoint(x: cx, y: cy))
                    }
                    .frame(height: 50)
                    .opacity(locked ? 0.15 : (isOn ? 1.0 : 0.4))

                    // 잠금 오버레이
                    if locked {
                        VStack(spacing: 2) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: Theme.iconSize(14)))
                                .foregroundColor(Theme.textDim)
                            Text(item.lockReason)
                                .font(Theme.mono(6, weight: .medium))
                                .foregroundColor(Theme.textDim)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                        }
                    }
                }

                // 이름 + 체크
                HStack(spacing: 3) {
                    Image(systemName: locked ? "lock.fill" : item.icon)
                        .font(.system(size: Theme.iconSize(8)))
                        .foregroundColor(locked ? Theme.textDim.opacity(0.5) : (isOn ? Theme.purple : Theme.textDim))
                    Text(item.name)
                        .font(Theme.mono(8, weight: isOn ? .bold : .medium))
                        .foregroundColor(locked ? Theme.textDim.opacity(0.5) : (isOn ? Theme.textPrimary : Theme.textDim))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Image(systemName: locked ? "lock.fill" : (isOn ? "checkmark.circle.fill" : "circle"))
                        .font(.system(size: Theme.iconSize(9)))
                        .foregroundColor(locked ? Theme.textDim.opacity(0.3) : (isOn ? Theme.green : Theme.textDim.opacity(0.4)))
                }
            }
            .padding(6)
            .background(RoundedRectangle(cornerRadius: 8)
                .stroke(locked ? Theme.border.opacity(0.1) : (isOn ? Theme.purple.opacity(0.4) : Theme.border.opacity(0.2)), lineWidth: isOn && !locked ? 1.5 : 0.5))
        }.buttonStyle(.plain)
    }

    // 미리보기 그리기 (간소화된 버전)
    private func drawFurniturePreview(context: GraphicsContext, item: FurnitureItem, at pos: CGPoint) {
        let dark = settings.isDarkMode
        let theme = resolvedAccessoryPreviewTheme(settings)
        let previewRect = CGRect(x: pos.x - 8, y: pos.y - 6, width: max(item.width + 16, 52), height: max(item.height + 12, 34))
        drawAccessoryPreviewRoom(context: context, item: item, rect: previewRect, theme: theme, dark: dark, frame: 18)
        drawAccessoryPixelFurniture(context: context, itemId: item.id, at: pos, dark: dark, frame: 18)
    }

    // MARK: - Helpers

    private var currentTheme: BackgroundTheme {
        BackgroundTheme(rawValue: settings.backgroundTheme) ?? .auto
    }

    private func isFurnitureOn(_ id: String) -> Bool {
        switch id {
        case "sofa": return settings.breakRoomShowSofa
        case "coffeeMachine": return settings.breakRoomShowCoffeeMachine
        case "plant": return settings.breakRoomShowPlant
        case "sideTable": return settings.breakRoomShowSideTable
        case "picture": return settings.breakRoomShowPicture
        case "neonSign": return settings.breakRoomShowNeonSign
        case "rug": return settings.breakRoomShowRug
        case "bookshelf": return settings.breakRoomShowBookshelf
        case "aquarium": return settings.breakRoomShowAquarium
        case "arcade": return settings.breakRoomShowArcade
        case "whiteboard": return settings.breakRoomShowWhiteboard
        case "lamp": return settings.breakRoomShowLamp
        case "cat": return settings.breakRoomShowCat
        case "tv": return settings.breakRoomShowTV
        case "fan": return settings.breakRoomShowFan
        case "calendar": return settings.breakRoomShowCalendar
        case "poster": return settings.breakRoomShowPoster
        case "trashcan": return settings.breakRoomShowTrashcan
        case "cushion": return settings.breakRoomShowCushion
        default: return false
        }
    }

    private func toggleFurniture(_ id: String) {
        switch id {
        case "sofa": settings.breakRoomShowSofa.toggle()
        case "coffeeMachine": settings.breakRoomShowCoffeeMachine.toggle()
        case "plant": settings.breakRoomShowPlant.toggle()
        case "sideTable": settings.breakRoomShowSideTable.toggle()
        case "picture": settings.breakRoomShowPicture.toggle()
        case "neonSign": settings.breakRoomShowNeonSign.toggle()
        case "rug": settings.breakRoomShowRug.toggle()
        case "bookshelf": settings.breakRoomShowBookshelf.toggle()
        case "aquarium": settings.breakRoomShowAquarium.toggle()
        case "arcade": settings.breakRoomShowArcade.toggle()
        case "whiteboard": settings.breakRoomShowWhiteboard.toggle()
        case "lamp": settings.breakRoomShowLamp.toggle()
        case "cat": settings.breakRoomShowCat.toggle()
        case "tv": settings.breakRoomShowTV.toggle()
        case "fan": settings.breakRoomShowFan.toggle()
        case "calendar": settings.breakRoomShowCalendar.toggle()
        case "poster": settings.breakRoomShowPoster.toggle()
        case "trashcan": settings.breakRoomShowTrashcan.toggle()
        case "cushion": settings.breakRoomShowCushion.toggle()
        default: break
        }
    }

    private func bgThemeButton(_ theme: BackgroundTheme) -> some View {
        let selected = settings.backgroundTheme == theme.rawValue
        let locked = !theme.isUnlocked
        return Button(action: { guard !locked else { return }; withAnimation(.easeInOut(duration: 0.15)) { settings.backgroundTheme = theme.rawValue } }) {
            VStack(spacing: 4) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(LinearGradient(
                            colors: [Color(hex: theme.skyColors.top), Color(hex: theme.skyColors.bottom)],
                            startPoint: .top, endPoint: .bottom))
                        .frame(height: 28)
                        .opacity(locked ? 0.3 : 1.0)
                    if locked {
                        VStack(spacing: 1) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: Theme.iconSize(9)))
                                .foregroundColor(.white.opacity(0.7))
                            Text(theme.lockReason)
                                .font(Theme.mono(5, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                                .lineLimit(1)
                        }
                    } else {
                        Image(systemName: theme.icon)
                            .font(.system(size: Theme.iconSize(10)))
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
                Text(theme.displayName)
                    .font(Theme.mono(7, weight: selected ? .bold : .medium))
                    .foregroundColor(locked ? Theme.textDim.opacity(0.5) : (selected ? Theme.purple : Theme.textDim))
                    .lineLimit(1)
            }
            .padding(4)
            .background(RoundedRectangle(cornerRadius: 8)
                .fill(selected && !locked ? Theme.purple.opacity(0.1) : .clear)
                .overlay(RoundedRectangle(cornerRadius: 8)
                    .stroke(locked ? Theme.border.opacity(0.1) : (selected ? Theme.purple.opacity(0.5) : Theme.border.opacity(0.2)), lineWidth: selected && !locked ? 1.5 : 0.5)))
        }.buttonStyle(.plain)
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - Accessory Preview Backgrounds
// ═══════════════════════════════════════════════════════

private enum AccessoryPreviewBackdropKind {
    case brightOffice
    case sunsetOffice
    case nightOffice
    case weather
    case blossom
    case forest
    case neon
    case ocean
    case desert
    case volcano
}

private struct AccessoryPreviewPalette {
    let wallTop: String
    let wallBottom: String
    let trim: String
    let baseboard: String
    let floorA: String
    let floorB: String
    let floorShadow: String
    let windowFrame: String
    let windowTop: String
    let windowBottom: String
    let windowGlow: String
    let reflection: String
    let sill: String
}

private func resolvedAccessoryPreviewTheme(_ settings: AppSettings) -> BackgroundTheme {
    let selected = BackgroundTheme(rawValue: settings.backgroundTheme) ?? .auto
    guard selected == .auto else { return selected }

    let hour = Calendar.current.component(.hour, from: Date())
    switch hour {
    case 6..<11: return .sunny
    case 11..<17: return .clearSky
    case 17..<19: return .goldenHour
    case 19..<21: return .dusk
    default: return settings.isDarkMode ? .moonlit : .sunny
    }
}

private func accessoryPreviewBackdropKind(for theme: BackgroundTheme) -> AccessoryPreviewBackdropKind {
    switch theme {
    case .sunny, .clearSky:
        return .brightOffice
    case .sunset, .goldenHour, .dusk, .autumn:
        return .sunsetOffice
    case .moonlit, .starryNight, .milkyWay, .aurora:
        return .nightOffice
    case .storm, .rain, .snow, .fog:
        return .weather
    case .cherryBlossom:
        return .blossom
    case .forest:
        return .forest
    case .neonCity:
        return .neon
    case .ocean:
        return .ocean
    case .desert:
        return .desert
    case .volcano:
        return .volcano
    case .auto:
        return .brightOffice
    }
}

private func accessoryPreviewPalette(for theme: BackgroundTheme, dark: Bool) -> AccessoryPreviewPalette {
    let baseFloor = theme.floorColors.base
    let baseDot = theme.floorColors.dot
    let kind = accessoryPreviewBackdropKind(for: theme)

    switch kind {
    case .brightOffice:
        return AccessoryPreviewPalette(
            wallTop: dark ? "C6D2DA" : "E3EDF3",
            wallBottom: dark ? "9DB1BF" : "C8D9E2",
            trim: dark ? "8E6A45" : "C59056",
            baseboard: dark ? "6E4B2F" : "A06E3D",
            floorA: baseFloor.isEmpty ? (dark ? "BB8A54" : "D9A76A") : baseFloor,
            floorB: baseDot.isEmpty ? (dark ? "A57446" : "C78F55") : baseDot,
            floorShadow: dark ? "6A4528" : "966234",
            windowFrame: dark ? "C7D5E2" : "F8FBFF",
            windowTop: "6AB0E9",
            windowBottom: "D7F0FF",
            windowGlow: dark ? "D8F3FF" : "FFFFFF",
            reflection: dark ? "6F8292" : "A9BACA",
            sill: dark ? "A97140" : "D29559"
        )
    case .sunsetOffice:
        return AccessoryPreviewPalette(
            wallTop: dark ? "DAB88D" : "F2D0A5",
            wallBottom: dark ? "B9926A" : "E7BF92",
            trim: dark ? "91603A" : "B87543",
            baseboard: dark ? "70462A" : "8E5632",
            floorA: baseFloor.isEmpty ? "B9824C" : baseFloor,
            floorB: baseDot.isEmpty ? "A16B39" : baseDot,
            floorShadow: "7A4C27",
            windowFrame: dark ? "D9B48D" : "FCE2BF",
            windowTop: "8F4A68",
            windowBottom: "F0A24A",
            windowGlow: "FFF2D0",
            reflection: dark ? "8D6B5C" : "C89A80",
            sill: dark ? "A2683A" : "D88D4D"
        )
    case .nightOffice:
        return AccessoryPreviewPalette(
            wallTop: dark ? "55627C" : "6F7E9D",
            wallBottom: dark ? "394762" : "55637E",
            trim: dark ? "8FA5C6" : "A9C0DD",
            baseboard: dark ? "283444" : "40526B",
            floorA: baseFloor.isEmpty ? (dark ? "4A5970" : "5E718C") : baseFloor,
            floorB: baseDot.isEmpty ? (dark ? "38465A" : "4A5971") : baseDot,
            floorShadow: dark ? "263243" : "3B4A5E",
            windowFrame: dark ? "CBD7EA" : "F2F7FF",
            windowTop: "0A1631",
            windowBottom: "233F6C",
            windowGlow: dark ? "D4E8FF" : "F3FAFF",
            reflection: dark ? "677A97" : "8799B6",
            sill: dark ? "4A5C75" : "6F86A4"
        )
    case .weather:
        return AccessoryPreviewPalette(
            wallTop: dark ? "ACB5BE" : "D7DEE4",
            wallBottom: dark ? "8E98A3" : "BCC8D0",
            trim: dark ? "6A7581" : "8E9BA6",
            baseboard: dark ? "59636D" : "76828C",
            floorA: baseFloor.isEmpty ? (dark ? "7B866D" : "CBD3C0") : baseFloor,
            floorB: baseDot.isEmpty ? (dark ? "687354" : "B3BEA8") : baseDot,
            floorShadow: dark ? "4E5844" : "8C947E",
            windowFrame: dark ? "D9E3EA" : "F6FAFC",
            windowTop: theme.skyColors.top,
            windowBottom: theme.skyColors.bottom,
            windowGlow: dark ? "DCE8EF" : "FFFFFF",
            reflection: dark ? "7C8A94" : "ABB8C1",
            sill: dark ? "858E95" : "A4AEB6"
        )
    case .blossom:
        return AccessoryPreviewPalette(
            wallTop: dark ? "E5C7D3" : "F7DEE7",
            wallBottom: dark ? "CBA8B4" : "EBC6D3",
            trim: dark ? "A37584" : "C68FA0",
            baseboard: dark ? "875866" : "B17384",
            floorA: baseFloor.isEmpty ? "D9CEC8" : baseFloor,
            floorB: baseDot.isEmpty ? "C7B8B2" : baseDot,
            floorShadow: "A7938E",
            windowFrame: dark ? "F0DCE5" : "FFF6FA",
            windowTop: "E8B5C4",
            windowBottom: "F6E3EE",
            windowGlow: "FFFFFF",
            reflection: dark ? "A68893" : "CCAFB8",
            sill: dark ? "C28E9F" : "E8AFC0"
        )
    case .forest:
        return AccessoryPreviewPalette(
            wallTop: dark ? "B4C6B0" : "D5E1D2",
            wallBottom: dark ? "8EA08A" : "B6C7B2",
            trim: dark ? "6B7C58" : "8AA06F",
            baseboard: dark ? "506040" : "71875A",
            floorA: baseFloor.isEmpty ? "9C7B54" : baseFloor,
            floorB: baseDot.isEmpty ? "846544" : baseDot,
            floorShadow: "654C33",
            windowFrame: dark ? "D8E6D6" : "F5FCF3",
            windowTop: "4D875A",
            windowBottom: "99C882",
            windowGlow: "EAF9E8",
            reflection: dark ? "778B74" : "A3B69F",
            sill: dark ? "7C9163" : "A4BB7E"
        )
    case .neon:
        return AccessoryPreviewPalette(
            wallTop: dark ? "483B66" : "6B5B8C",
            wallBottom: dark ? "30284A" : "43375E",
            trim: dark ? "9F7BE0" : "C09CFF",
            baseboard: dark ? "211B35" : "32284A",
            floorA: baseFloor.isEmpty ? (dark ? "1C1631" : "2D2247") : baseFloor,
            floorB: baseDot.isEmpty ? (dark ? "2D1F4F" : "45316D") : baseDot,
            floorShadow: dark ? "120E20" : "241933",
            windowFrame: dark ? "D8D0FF" : "F5F0FF",
            windowTop: "120B2A",
            windowBottom: "2E1854",
            windowGlow: "FF7BE7",
            reflection: dark ? "8A73B5" : "A28BD0",
            sill: dark ? "7B58C8" : "A57BFF"
        )
    case .ocean:
        return AccessoryPreviewPalette(
            wallTop: dark ? "B7D7E6" : "D8EEF7",
            wallBottom: dark ? "93C0D3" : "B9DDE9",
            trim: dark ? "4F7FA4" : "6AA8D2",
            baseboard: dark ? "345874" : "497898",
            floorA: baseFloor.isEmpty ? "93B4C8" : baseFloor,
            floorB: baseDot.isEmpty ? "7399AF" : baseDot,
            floorShadow: "54758B",
            windowFrame: dark ? "ECF8FF" : "FFFFFF",
            windowTop: "2B86CF",
            windowBottom: "8BE2F5",
            windowGlow: "F4FFFF",
            reflection: dark ? "6EA1B8" : "92BED0",
            sill: dark ? "5D99B1" : "86BED1"
        )
    case .desert:
        return AccessoryPreviewPalette(
            wallTop: dark ? "E4CC9E" : "F4DFB1",
            wallBottom: dark ? "C9AE7A" : "E5C78A",
            trim: dark ? "A97842" : "C88F4E",
            baseboard: dark ? "7D582F" : "9F6D38",
            floorA: baseFloor.isEmpty ? "C99B59" : baseFloor,
            floorB: baseDot.isEmpty ? "B48547" : baseDot,
            floorShadow: "916734",
            windowFrame: dark ? "F3E7C6" : "FFF7DE",
            windowTop: "E3A85D",
            windowBottom: "F3D38C",
            windowGlow: "FFF8DA",
            reflection: dark ? "A98A67" : "C9A47B",
            sill: dark ? "C18D4A" : "E5A95D"
        )
    case .volcano:
        return AccessoryPreviewPalette(
            wallTop: dark ? "7C5E5E" : "A27D7D",
            wallBottom: dark ? "583E3E" : "6D4E4E",
            trim: dark ? "A46A55" : "CC8467",
            baseboard: dark ? "3B2727" : "503636",
            floorA: baseFloor.isEmpty ? (dark ? "2C1616" : "3D2222") : baseFloor,
            floorB: baseDot.isEmpty ? (dark ? "431F1F" : "5A2C2C") : baseDot,
            floorShadow: dark ? "180C0C" : "2A1414",
            windowFrame: dark ? "E6D4D4" : "FAEAEA",
            windowTop: "3C0F15",
            windowBottom: "A52A1F",
            windowGlow: "FFC388",
            reflection: dark ? "8A6262" : "A98181",
            sill: dark ? "793A30" : "AA5344"
            )
        }
    }

    private func settingsToggleRow(title: String, subtitle: String, isOn: Binding<Bool>, tint: Color) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.mono(10, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                Text(subtitle)
                    .font(Theme.mono(8))
                    .foregroundColor(Theme.textDim)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(tint)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: Theme.cornerMedium)
                .fill(Theme.bgSurface.opacity(0.45))
        )
    }

    private func limitStepperCard(
        title: String,
        subtitle: String,
        value: Binding<Int>,
        range: ClosedRange<Int>,
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Theme.mono(10, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                    Text(subtitle)
                        .font(Theme.mono(8))
                        .foregroundColor(Theme.textDim)
                }
                Spacer()
                Text("\(value.wrappedValue)회")
                    .font(Theme.mono(10, weight: .bold))
                    .foregroundColor(tint)
            }

            Stepper("", value: value, in: range)
                .labelsHidden()
                .tint(tint)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.cornerMedium)
                .fill(Theme.bgSurface.opacity(0.45))
        )
    }

private func drawAccessoryPreviewRoom(
    context: GraphicsContext,
    item: FurnitureItem,
    rect: CGRect,
    theme: BackgroundTheme,
    dark: Bool,
    frame: Int
) {
    let palette = accessoryPreviewPalette(for: theme, dark: dark)
    let kind = accessoryPreviewBackdropKind(for: theme)

    func px(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ hex: String, _ opacity: Double = 1) {
        context.fill(Path(CGRect(x: x, y: y, width: w, height: h)), with: .color(Color(hex: hex).opacity(opacity)))
    }

    let floorHeight: CGFloat = item.isWallItem ? 8 : 11
    let wallHeight = rect.height - floorHeight
    let windowWidth = min(item.isWallItem ? rect.width * 0.42 : rect.width * 0.34, 22)
    let windowHeight = max(12, wallHeight - 9)
    let windowX = item.isWallItem ? rect.midX - windowWidth / 2 : rect.maxX - windowWidth - 6
    let windowY = rect.minY + 4
    let reflectionPulse = (sin(Double(frame) * 0.18) + 1) * 0.5

    px(rect.minX, rect.minY, rect.width, wallHeight, palette.wallBottom)
    px(rect.minX, rect.minY, rect.width, wallHeight * 0.48, palette.wallTop)
    px(rect.minX, rect.minY, rect.width, 1, palette.windowGlow, 0.4)
    px(rect.minX, rect.minY, 1, wallHeight, palette.windowGlow, 0.12)
    px(rect.maxX - 1, rect.minY, 1, wallHeight, palette.baseboard, 0.22)
    px(rect.minX, rect.minY + wallHeight - 3, rect.width, 3, palette.trim, 0.65)
    px(rect.minX, rect.minY + wallHeight - 1, rect.width, 1, palette.baseboard, 0.9)

    let shelfY = rect.minY + wallHeight - 9
    if !item.isWallItem {
        px(rect.minX + 4, shelfY, 9, 2, palette.baseboard, 0.55)
        px(rect.minX + 5, shelfY - 4, 2, 4, palette.reflection, 0.20)
        px(rect.minX + 8, shelfY - 3, 3, 3, palette.reflection, 0.18)
    }

    px(windowX, windowY, windowWidth, windowHeight, palette.windowFrame, 0.95)
    px(windowX + 1, windowY + 1, windowWidth - 2, windowHeight - 2, palette.windowBottom)
    px(windowX + 1, windowY + 1, windowWidth - 2, (windowHeight - 2) * 0.46, palette.windowTop)

    switch kind {
    case .brightOffice:
        px(windowX + 3, windowY + 3, 7, 2, "F9FFFF", 0.55)
        px(windowX + 9, windowY + 5, 5, 2, "F9FFFF", 0.40)
        px(windowX + 2, windowY + windowHeight - 4, windowWidth - 4, 2, "8EB27B", 0.75)
        px(windowX + 4, windowY + windowHeight - 7, 3, 3, "A1C490", 0.55)
        px(windowX + 12, windowY + windowHeight - 8, 4, 4, "8CA2B5", 0.5)
    case .sunsetOffice:
        px(windowX + 2, windowY + 2, windowWidth - 4, 1, "FFD58E", 0.40)
        px(windowX + windowWidth - 7, windowY + 3, 4, 4, "FFF0B2", 0.55)
        px(windowX + 2, windowY + windowHeight - 5, windowWidth - 4, 2, "70475A", 0.55)
        px(windowX + 4, windowY + windowHeight - 8, 5, 3, "8E5A4C", 0.35)
        px(windowX + 11, windowY + windowHeight - 7, 4, 2, "9F6A51", 0.3)
    case .nightOffice:
        px(windowX + windowWidth - 6, windowY + 3, 3, 3, "F7E89B", 0.65)
        px(windowX + 4, windowY + 4, 1, 1, "F7F8FF", 0.8)
        px(windowX + 9, windowY + 6, 1, 1, "F7F8FF", 0.55)
        px(windowX + 3, windowY + windowHeight - 5, windowWidth - 6, 2, "263247", 0.85)
        px(windowX + 4, windowY + windowHeight - 7, 2, 2, "F5D36B", 0.5)
        px(windowX + 9, windowY + windowHeight - 7, 2, 2, "8BC1FF", 0.35)
    case .weather:
        if theme == .snow {
            for i in 0..<4 {
                px(windowX + 3 + CGFloat(i * 3), windowY + 4 + CGFloat((i * 5) % 6), 1, 1, "FFFFFF", 0.7)
            }
        } else if theme == .fog {
            px(windowX + 2, windowY + 4, windowWidth - 4, 3, "F4F7FB", 0.22)
            px(windowX + 3, windowY + 8, windowWidth - 6, 2, "E7EDF2", 0.18)
        } else {
            for i in 0..<4 {
                px(windowX + 4 + CGFloat(i * 4), windowY + 3, 1, windowHeight - 6, "D9EAF4", theme == .storm ? 0.26 : 0.18)
            }
        }
        px(windowX + 2, windowY + windowHeight - 4, windowWidth - 4, 2, "75838D", 0.45)
    case .blossom:
        px(windowX + 2, windowY + windowHeight - 4, windowWidth - 4, 2, "809F73", 0.58)
        px(windowX + 3, windowY + 4, 6, 4, "F3BCD0", 0.80)
        px(windowX + 8, windowY + 3, 6, 5, "F8D4E2", 0.74)
        px(windowX + 7, windowY + 10, 1, 1, "FFFFFF", 0.55)
        px(windowX + 12, windowY + 8, 1, 1, "FFFFFF", 0.55)
    case .forest:
        px(windowX + 2, windowY + windowHeight - 4, windowWidth - 4, 2, "456A42", 0.78)
        px(windowX + 4, windowY + 4, 3, windowHeight - 8, "57764A", 0.72)
        px(windowX + 9, windowY + 5, 3, windowHeight - 9, "3E5C37", 0.78)
        px(windowX + 2, windowY + 4, 5, 4, "86AF78", 0.45)
        px(windowX + 10, windowY + 3, 6, 5, "A2CA7F", 0.36)
    case .neon:
        px(windowX + 3, windowY + windowHeight - 5, windowWidth - 6, 2, "1B1838", 0.9)
        px(windowX + 4, windowY + windowHeight - 8, 3, 3, "FF4CD2", 0.65)
        px(windowX + 10, windowY + windowHeight - 9, 4, 4, "54D7FF", 0.50)
        px(windowX + 5, windowY + 3, 1, windowHeight - 8, "FFF4FF", 0.18)
    case .ocean:
        px(windowX + 1, windowY + windowHeight - 5, windowWidth - 2, 1, "DDF6FF", 0.55)
        px(windowX + 2, windowY + windowHeight - 4, windowWidth - 4, 2, "2E8DC1", 0.60)
        px(windowX + 4, windowY + windowHeight - 7, 4, 1, "F7FFFF", 0.45)
        px(windowX + 11, windowY + windowHeight - 8, 5, 1, "B7F3FF", 0.40)
    case .desert:
        px(windowX + 2, windowY + windowHeight - 4, windowWidth - 4, 2, "D8B16B", 0.75)
        px(windowX + 5, windowY + windowHeight - 8, 6, 3, "C28A4A", 0.45)
        px(windowX + 12, windowY + windowHeight - 9, 1, 5, "63844D", 0.35)
        px(windowX + 11, windowY + windowHeight - 7, 3, 1, "86A66E", 0.30)
    case .volcano:
        px(windowX + 2, windowY + windowHeight - 4, windowWidth - 4, 2, "311315", 0.90)
        px(windowX + 7, windowY + windowHeight - 9, 5, 4, "4B1819", 0.55)
        px(windowX + 10, windowY + 4, 2, 6, "FFB261", 0.25)
        px(windowX + 11, windowY + 4, 1, 5, "FFD78A", 0.18)
    }

    px(windowX + 2, windowY + 1, 1, windowHeight - 2, palette.windowGlow, 0.16 + reflectionPulse * 0.08)
    px(windowX + windowWidth * 0.55, windowY + 1, 1, windowHeight - 2, palette.windowGlow, 0.10)
    px(windowX + 2, windowY + windowHeight - 6, windowWidth - 4, 1, palette.reflection, 0.26)
    px(windowX + 4, windowY + windowHeight - 5, 4, 2, palette.reflection, 0.20)
    px(windowX + windowWidth - 8, windowY + windowHeight - 7, 3, 3, palette.reflection, 0.12)
    px(windowX - 1, windowY + windowHeight, windowWidth + 2, 2, palette.sill, 0.95)

    let floorTop = rect.maxY - floorHeight
    px(rect.minX, floorTop, rect.width, floorHeight, palette.floorA)
    for row in stride(from: floorTop, to: rect.maxY, by: 4) {
        px(rect.minX, row, rect.width, 1, palette.floorShadow, 0.18)
    }
    if kind == .neon || kind == .ocean || kind == .weather {
        for col in stride(from: rect.minX, to: rect.maxX, by: 6) {
            px(col, floorTop, 1, floorHeight, palette.floorB, 0.22)
        }
    } else {
        for col in stride(from: rect.minX, to: rect.maxX, by: 8) {
            px(col, floorTop, 1, floorHeight, palette.floorB, 0.26)
        }
    }
    px(rect.minX, floorTop, rect.width, 1, palette.windowGlow, 0.16)
    px(rect.minX, rect.maxY - 1, rect.width, 1, palette.floorShadow, 0.34)
}

// ═══════════════════════════════════════════════════════
// MARK: - Shared Pixel Furniture Renderer
// ═══════════════════════════════════════════════════════

func drawAccessoryPixelFurniture(context: GraphicsContext, itemId: String, at pos: CGPoint, dark: Bool, frame: Int = 0) {
    let x = pos.x
    let y = pos.y

    func px(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ color: Color, _ opacity: Double = 1) {
        context.fill(Path(CGRect(x: x, y: y, width: w, height: h)), with: .color(color.opacity(opacity)))
    }

    switch itemId {
    case "sofa":
        let base = dark ? Color(hex: "70508E") : Color(hex: "8E6AB0")
        let shade = dark ? Color(hex: "533A6C") : Color(hex: "73588F")
        let light = dark ? Color(hex: "8A6BA7") : Color(hex: "AF8BCB")
        px(x + 1, y + 15, 43, 3, .black, dark ? 0.22 : 0.12)
        px(x - 2, y - 9, 49, 10, shade)
        px(x, y, 45, 13, base)
        px(x + 3, y + 2, 18, 8, light, 0.55)
        px(x + 24, y + 2, 18, 8, light, 0.55)
        px(x + 22, y + 2, 1, 8, shade, 0.7)
        px(x - 4, y - 8, 7, 22, base)
        px(x + 42, y - 8, 7, 22, base)
        px(x + 1, y - 8, 1, 20, Color.white, 0.08)
        px(x + 4, y + 13, 4, 7, shade)
        px(x + 37, y + 13, 4, 7, shade)

    case "sideTable":
        let wood = dark ? Color(hex: "7A5631") : Color(hex: "B8824A")
        let woodLight = dark ? Color(hex: "9E7248") : Color(hex: "E1AA6E")
        let woodDark = dark ? Color(hex: "5A3A1F") : Color(hex: "8B5A2D")
        px(x + 1, y + 11, 16, 2, .black, dark ? 0.20 : 0.10)
        px(x, y + 1, 18, 3, woodLight)
        px(x, y + 4, 18, 2, wood)
        px(x + 2, y + 6, 14, 7, wood)
        px(x + 8, y + 4, 2, 10, woodDark)
        px(x + 3, y + 8, 2, 2, Color(hex: "D7D0C5"))
        px(x + 6, y + 7, 5, 1, Color(hex: "5F7FB0"))
        px(x + 12, y + 3, 3, 3, Color(hex: "F2E7D7"))
        px(x + 14, y + 4, 1, 2, Color(hex: "F2E7D7"))
        px(x + 2, y + 13, 2, 6, woodDark)
        px(x + 14, y + 13, 2, 6, woodDark)

    case "coffeeMachine":
        let body = dark ? Color(hex: "59626E") : Color(hex: "7F8895")
        let top = dark ? Color(hex: "7A8591") : Color(hex: "A5B0BA")
        let slot = dark ? Color(hex: "2E3740") : Color(hex: "505A65")
        px(x + 2, y + 15, 12, 2, .black, dark ? 0.22 : 0.12)
        px(x + 1, y, 14, 16, body)
        px(x, y - 1, 16, 3, top)
        px(x + 3, y + 3, 10, 6, top, 0.9)
        px(x + 4, y + 4, 4, 1, Theme.green, 0.8)
        px(x + 3, y + 11, 10, 5, slot)
        px(x + 5, y + 13, 6, 5, Color(hex: "F7F3EE"))
        px(x + 11, y + 14, 2, 3, Color(hex: "F7F3EE"), 0.8)
        px(x + 6, y + 12, 4, 1, Color(hex: "7A4B35"), 0.65)
        let steam = sin(Double(frame) * 0.12)
        px(x + 6 + CGFloat(steam * 1.5), y + 9, 1, 2, .white, 0.25)
        px(x + 8 - CGFloat(steam), y + 7, 1, 2, .white, 0.18)

    case "plant":
        let pot = dark ? Color(hex: "A96A45") : Color(hex: "C98958")
        let potShade = dark ? Color(hex: "7C4B2E") : Color(hex: "955B33")
        let leaf = dark ? Color(hex: "3E7A38") : Color(hex: "5BAF4E")
        let leafLight = dark ? Color(hex: "5CA351") : Color(hex: "7ED16B")
        px(x + 1, y + 17, 12, 2, .black, dark ? 0.18 : 0.09)
        px(x, y + 12, 12, 6, pot)
        px(x - 1, y + 10, 14, 3, Color(hex: dark ? "BC7E57" : "E4A772"))
        px(x + 1, y + 10, 10, 2, potShade, 0.45)
        px(x + 5, y + 4, 2, 8, Color(hex: "497A35"))
        px(x - 1, y + 3, 8, 8, leaf)
        px(x + 4, y, 9, 9, leafLight, 0.95)
        px(x + 1, y - 3, 7, 7, leaf, 0.9)
        px(x + 4, y - 4, 4, 4, Color(hex: "F0B4B8"), 0.75)
        px(x + 5, y - 3, 2, 2, Color(hex: "F7E08A"), 0.8)

    case "clock":
        let rim = dark ? Color(hex: "CCD3DA") : Color(hex: "F5F6F8")
        let face = dark ? Color(hex: "F3EEE4") : Color(hex: "FFFDF8")
        let hand = dark ? Color(hex: "243040") : Color(hex: "3B4652")
        let cx = x + 7
        let cy = y + 7
        px(x, y, 14, 14, Color(hex: dark ? "8792A0" : "BEC8D1"), 0.8)
        px(x + 1, y + 1, 12, 12, rim)
        px(x + 2, y + 2, 10, 10, face)
        let minuteAngle = Double(frame % 120) / 120.0 * .pi * 2 - .pi / 2
        var minute = Path()
        minute.move(to: CGPoint(x: cx, y: cy))
        minute.addLine(to: CGPoint(x: cx + cos(minuteAngle) * 4, y: cy + sin(minuteAngle) * 4))
        context.stroke(minute, with: .color(hand.opacity(0.8)), lineWidth: 0.8)
        var hour = Path()
        hour.move(to: CGPoint(x: cx, y: cy))
        hour.addLine(to: CGPoint(x: cx + 1.6, y: cy - 2.6))
        context.stroke(hour, with: .color(hand), lineWidth: 0.9)
        px(cx - 1, cy - 1, 2, 2, Theme.red, 0.7)

    case "picture":
        let frame = dark ? Color(hex: "7C5B3C") : Color(hex: "B2895A")
        let frameLight = dark ? Color(hex: "9D734D") : Color(hex: "D7AB78")
        px(x, y, 20, 16, frame)
        px(x + 1, y, 18, 1, frameLight, 0.6)
        px(x + 2, y + 2, 16, 12, Color(hex: dark ? "CAE0F0" : "D9EEF8"))
        px(x + 2, y + 9, 16, 5, Color(hex: dark ? "527749" : "79B06C"), 0.75)
        var mountain = Path()
        mountain.move(to: CGPoint(x: x + 4, y: y + 13))
        mountain.addLine(to: CGPoint(x: x + 9, y: y + 6))
        mountain.addLine(to: CGPoint(x: x + 13, y: y + 10))
        mountain.addLine(to: CGPoint(x: x + 17, y: y + 5))
        mountain.addLine(to: CGPoint(x: x + 18, y: y + 13))
        mountain.closeSubpath()
        context.fill(mountain, with: .color(Color(hex: dark ? "5C7AA2" : "8AB7DE").opacity(0.8)))
        px(x + 13, y + 4, 3, 3, Color(hex: "F6E28D"), 0.85)

    case "neonSign":
        px(x, y, 64, 16, Color(hex: dark ? "0E1118" : "252B36"))
        px(x - 1, y - 1, 66, 18, Theme.yellow, dark ? 0.08 : 0.12)
        px(x + 3, y + 3, 12, 2, Theme.yellow, 0.7)
        px(x + 17, y + 3, 8, 2, Theme.yellow, 0.7)
        px(x + 27, y + 3, 11, 2, Theme.yellow, 0.7)
        px(x + 40, y + 3, 10, 2, Theme.yellow, 0.7)
        px(x + 52, y + 3, 8, 2, Theme.yellow, 0.7)
        context.draw(
            Text("BREAK").font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundColor(Theme.yellow.opacity(0.9)),
            at: CGPoint(x: x + 23, y: y + 8)
        )
        context.draw(
            Text("ROOM").font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundColor(Theme.cyan.opacity(0.85)),
            at: CGPoint(x: x + 47, y: y + 8)
        )

    case "rug":
        let rug = dark ? Color(hex: "91A582") : Color(hex: "B4C89C")
        let border = dark ? Color(hex: "617255") : Color(hex: "7E926A")
        px(x, y, 100, 14, rug, 0.82)
        px(x + 2, y + 2, 96, 10, border, 0.18)
        px(x + 4, y + 4, 92, 6, Color(hex: dark ? "D8E8BB" : "EFF7D8"), 0.12)
        for stripe in stride(from: CGFloat(6), to: 94, by: 8) {
            px(x + stripe, y + 6, 3, 1, border, 0.45)
        }

    case "bookshelf":
        let wood = dark ? Color(hex: "765132") : Color(hex: "A97444")
        let woodShade = dark ? Color(hex: "5A3A22") : Color(hex: "85572E")
        let woodHi = dark ? Color(hex: "976A46") : Color(hex: "D39A66")
        let bookColors = [
            Color(hex: "D85A4F"), Color(hex: "4F7FDE"), Color(hex: "59B569"),
            Color(hex: "E5B04E"), Color(hex: "A26BDA"), Color(hex: "42B7C6")
        ]
        px(x, y, 20, 36, wood)
        px(x + 1, y, 18, 1, woodHi, 0.55)
        for row in 0..<3 {
            let shelfY = y + CGFloat(row) * 12 + 11
            px(x, shelfY, 20, 2, woodShade)
            let startY = y + CGFloat(row) * 12 + 2
            for b in 0..<4 {
                let bx = x + 2 + CGFloat(b) * 4
                let color = bookColors[(row * 4 + b) % bookColors.count]
                px(bx, startY + CGFloat(b % 2), 3, 8 - CGFloat(b % 2), color, 0.85)
                px(bx + 1, startY + 1 + CGFloat(b % 2), 1, 5, .white, 0.18)
            }
        }

    case "aquarium":
        let glass = Color(hex: dark ? "7AA9C6" : "A8D9F1")
        let water = Color(hex: dark ? "2D6A9D" : "5FB5E4")
        let stand = dark ? Color(hex: "55626F") : Color(hex: "8696A4")
        px(x + 1, y + 18, 20, 2, .black, dark ? 0.18 : 0.10)
        px(x, y, 22, 18, glass, 0.35)
        px(x + 1, y + 3, 20, 14, water, 0.55)
        px(x + 2, y + 2, 18, 1, .white, 0.18)
        px(x + 2, y + 14, 18, 2, Color(hex: "CFB078"), 0.65)
        let fishX = x + 5 + sin(Double(frame) * 0.06) * 5
        px(CGFloat(fishX), y + 8, 5, 3, Color(hex: "F48E47"), 0.85)
        px(CGFloat(fishX) + 4, y + 9, 2, 1, Color(hex: "F48E47"), 0.85)
        let fish2X = x + 12 + sin(Double(frame) * 0.04 + 2) * 4
        px(CGFloat(fish2X), y + 12, 4, 2, Color(hex: "63D4E6"), 0.8)
        px(CGFloat(fish2X) + 3, y + 12, 1, 1, Color(hex: "63D4E6"), 0.8)
        let bubbleY = y + 7 - sin(Double(frame) * 0.08) * 3
        px(x + 15, CGFloat(bubbleY), 2, 2, .white, 0.28)
        px(x + 13, CGFloat(bubbleY) + 4, 1.5, 1.5, .white, 0.22)
        px(x - 1, y + 17, 24, 2, stand)

    case "arcade":
        let body = dark ? Color(hex: "4B2A80") : Color(hex: "6B43B8")
        let bodyDark = dark ? Color(hex: "33195B") : Color(hex: "4B2D83")
        px(x + 1, y + 28, 14, 2, .black, dark ? 0.24 : 0.13)
        px(x, y + 2, 16, 28, body)
        px(x + 2, y, 12, 5, Color(hex: dark ? "6B4DAD" : "8F6CDB"))
        px(x + 2, y + 4, 12, 9, Color(hex: dark ? "12202E" : "1B2C38"))
        px(x + 4, y + 6, 8, 5, Theme.green, 0.35)
        px(x + 5, y + 16, 2, 2, Theme.red, 0.82)
        px(x + 10, y + 17, 2, 2, Color(hex: "F1D05A"), 0.7)
        px(x + 2, y + 27, 3, 4, bodyDark)
        px(x + 11, y + 27, 3, 4, bodyDark)
        px(x + 6, y + 1, 4, 1, Color.white, 0.2)

    case "whiteboard":
        let frameColor = dark ? Color(hex: "9BA5B3") : Color(hex: "C2C8D0")
        let board = dark ? Color(hex: "EEF2F6") : Color(hex: "F9FBFD")
        px(x + 1, y + 20, 28, 2, .black, dark ? 0.14 : 0.08)
        px(x, y, 30, 22, frameColor)
        px(x + 1.5, y + 1.5, 27, 19, board)
        px(x + 3, y + 4, 12, 1, Theme.red, 0.45)
        px(x + 3, y + 7, 18, 1, Theme.accent, 0.35)
        px(x + 3, y + 10, 10, 1, Theme.green, 0.35)
        px(x + 18, y + 6, 6, 4, Color(hex: "EACB93"), 0.35)
        px(x + 8, y + 20, 14, 2, Color(hex: dark ? "7D8793" : "9AA4AE"))

    case "lamp":
        let pole = dark ? Color(hex: "556270") : Color(hex: "90A0AE")
        let shade = dark ? Color(hex: "E7C76B") : Color(hex: "F4DB8B")
        let glow = 0.08 + sin(Double(frame) * 0.04) * 0.03
        px(x + 4, y + 8, 2, 22, pole)
        px(x + 1, y + 28, 8, 2, pole)
        px(x, y, 10, 8, shade, 0.8)
        px(x + 1, y + 1, 8, 2, .white, 0.12)
        context.fill(Path(ellipseIn: CGRect(x: x - 5, y: y + 5, width: 20, height: 22)), with: .color(shade.opacity(glow)))

    case "cat":
        let fur = dark ? Color(hex: "CE9B58") : Color(hex: "D3A05E")
        let furLight = dark ? Color(hex: "E0BD7D") : Color(hex: "E9C889")
        px(x + 1, y + 10, 10, 2, .black, dark ? 0.14 : 0.08)
        px(x + 1, y + 3, 8, 6, fur)
        px(x + 7, y, 5, 5, fur)
        px(x + 7, y - 1, 2, 2, furLight)
        px(x + 10, y - 1, 2, 2, furLight)
        px(x + 8, y + 2, 1, 1, Theme.green, 0.85)
        px(x + 10, y + 2, 1, 1, Theme.green, 0.85)
        let tailWave = sin(Double(frame) * 0.08) * 2
        px(x - 1, y + 4 + CGFloat(tailWave), 3, 1, fur)

    case "tv":
        let body = dark ? Color(hex: "1A1E28") : Color(hex: "2A2E38")
        let screen = dark ? Color(hex: "0E2436") : Color(hex: "16364A")
        let cabinet = dark ? Color(hex: "765031") : Color(hex: "A16F44")
        px(x + 1, y + 16, 26, 2, .black, dark ? 0.20 : 0.10)
        px(x, y, 28, 18, body)
        px(x + 2, y + 2, 24, 13, screen)
        px(x + 4, y + 4, 20, 9, Theme.accent, 0.25)
        px(x + 11, y + 16, 6, 2, body)
        px(x + 4, y + 19, 20, 3, cabinet)
        px(x + 7, y + 20, 4, 1, Color(hex: "F0C25A"), 0.55)

    case "fan":
        let body = dark ? Color(hex: "5B6772") : Color(hex: "94A1AC")
        px(x + 5, y + 10, 2, 12, body)
        px(x + 2, y + 20, 8, 3, body)
        let fanAngle = Double(frame) * 0.3
        for blade in 0..<3 {
            let angle = fanAngle + Double(blade) * 2.094
            let bx = x + 6 + cos(angle) * 5
            let by = y + 6 + sin(angle) * 5
            context.fill(Path(ellipseIn: CGRect(x: CGFloat(bx) - 2, y: CGFloat(by) - 1, width: 4, height: 3)),
                         with: .color(body.opacity(0.6)))
        }
        px(x + 4, y + 4, 4, 4, body)

    case "calendar":
        let paper = dark ? Color(hex: "EDF0F5") : Color(hex: "FFFDF8")
        px(x, y, 14, 14, paper, 0.95)
        px(x, y, 14, 4, Theme.red, 0.82)
        px(x + 3, y + 2, 2, 2, Theme.overlayBg, 0.18)
        context.draw(
            Text("23").font(.system(size: 6, weight: .bold, design: .monospaced)).foregroundColor(Theme.overlay.opacity(0.55)),
            at: CGPoint(x: x + 7, y: y + 10)
        )

    case "poster":
        px(x, y, 16, 20, Color(hex: dark ? "2D4D72" : "4178C2"), 0.92)
        px(x + 2, y + 2, 12, 16, Color(hex: dark ? "3B658F" : "5E90D7"), 0.45)
        px(x + 5, y + 4, 6, 6, Color(hex: "F6D96E"), 0.55)
        px(x + 3, y + 13, 10, 1, .white, 0.32)
        px(x + 4, y + 16, 8, 1, .white, 0.24)

    case "trashcan":
        let bin = dark ? Color(hex: "69737E") : Color(hex: "88929D")
        let lid = dark ? Color(hex: "85909B") : Color(hex: "A0A9B3")
        px(x + 1, y + 10, 8, 2, .black, dark ? 0.16 : 0.08)
        px(x + 1, y + 2, 8, 10, bin)
        px(x, y, 10, 3, lid)
        px(x + 4, y - 1, 2, 2, lid)
        px(x + 2, y + 4, 1, 5, .white, 0.10)

    case "cushion":
        let base = dark ? Color(hex: "A76B86") : Color(hex: "DD95B6")
        let light = dark ? Color(hex: "C288A1") : Color(hex: "F5B5CE")
        context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 12, height: 8)), with: .color(base.opacity(0.85)))
        context.fill(Path(ellipseIn: CGRect(x: x + 2, y: y + 1, width: 8, height: 5)), with: .color(light.opacity(0.45)))
        px(x + 5.5, y + 2, 1, 3, Color(hex: dark ? "8B536C" : "C27A98"), 0.45)

    default:
        break
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - Color hex init
// ═══════════════════════════════════════════════════════

extension Color {
    init(hex: String) {
        var hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        // Expand 3-character shorthand (e.g. "fff" -> "ffffff")
        if hex.count == 3 {
            hex = hex.map { "\($0)\($0)" }.joined()
        }
        var int: UInt64 = 0
        guard Scanner(string: hex).scanHexInt64(&int), hex.count == 6 else {
            // Fallback to magenta for debug visibility on invalid hex
            self.init(.sRGB, red: 1, green: 0, blue: 1)
            return
        }
        let r = int >> 16
        let g = int >> 8 & 0xFF
        let b = int & 0xFF
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
    }
}
