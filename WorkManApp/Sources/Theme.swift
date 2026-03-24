import SwiftUI

// ═══════════════════════════════════════════════════════
// MARK: - App Settings (전역 설정)
// ═══════════════════════════════════════════════════════

class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @AppStorage("isDarkMode") var isDarkMode: Bool = false {
        didSet { objectWillChange.send() }
    }
    @AppStorage("fontSizeScale") var fontSizeScale: Double = 1.2 {
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
    @AppStorage("appDisplayName") var appDisplayName: String = "My World" {
        didSet { objectWillChange.send() }
    }
    @AppStorage("companyName") var companyName: String = "" {
        didSet { objectWillChange.send() }
    }

    // ── 편집 모드 ──
    @Published var isEditMode: Bool = false

    var colorScheme: ColorScheme { isDarkMode ? .dark : .light }

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
        case .planner: return "기획자"
        case .designer: return "디자이너"
        case .developerExecution: return "개발자 구현"
        case .developerRevision: return "개발자 재작업"
        case .reviewer: return "코드 리뷰어"
        case .qa: return "QA"
        case .reporter: return "보고자"
        case .sre: return "SRE"
        }
    }

    var shortLabel: String {
        switch self {
        case .developerExecution: return "구현"
        case .developerRevision: return "재작업"
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
        case .planner: return "사용자 요구사항을 개발 가능한 실행 계획으로 정리합니다."
        case .designer: return "UI/UX 흐름과 상호작용 메모를 정리합니다."
        case .developerExecution: return "개발자가 처음 구현할 때 받는 지시문입니다."
        case .developerRevision: return "리뷰/QA 피드백을 반영할 때 쓰는 재작업 지시문입니다."
        case .reviewer: return "변경 파일과 리스크를 검토하는 리뷰 양식입니다."
        case .qa: return "실행/테스트 관점에서 검증하는 QA 양식입니다."
        case .reporter: return "최종 Markdown 보고서 구조와 작성 지침입니다."
        case .sre: return "배포/운영 안정성 점검 양식입니다."
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
당신은 WorkMan의 기획자입니다.
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
당신은 WorkMan의 디자이너입니다.
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
당신은 WorkMan의 코드 리뷰어입니다.
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
당신은 WorkMan의 QA 담당자입니다.
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
당신은 WorkMan의 보고자입니다.
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

보고서 기본 구조:
# 작업 보고서
## 요구사항
## 구현 결과
## QA 검증 결과
## 변경 파일
## 남은 리스크 및 다음 단계
"""
        case .sre:
            return """
당신은 WorkMan의 SRE입니다.
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
        switch self {
        case .auto: return "자동"
        case .sunny: return "맑은 낮"
        case .clearSky: return "파란 하늘"
        case .sunset: return "노을"
        case .goldenHour: return "골든아워"
        case .dusk: return "황혼"
        case .moonlit: return "달빛"
        case .starryNight: return "별밤"
        case .aurora: return "오로라"
        case .milkyWay: return "은하수"
        case .storm: return "먹구름"
        case .rain: return "비"
        case .snow: return "눈"
        case .fog: return "안개"
        case .cherryBlossom: return "벚꽃"
        case .autumn: return "단풍"
        case .forest: return "숲"
        case .neonCity: return "네온시티"
        case .ocean: return "바다"
        case .desert: return "사막"
        case .volcano: return "화산"
        }
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

    static let all: [FurnitureItem] = [
        // 기본 가구
        FurnitureItem(id: "sofa", name: "소파", icon: "sofa.fill", defaultNormX: 0.0, defaultNormY: 0.7, width: 49, height: 30, isWallItem: false),
        FurnitureItem(id: "sideTable", name: "사이드테이블", icon: "table.furniture.fill", defaultNormX: 0.45, defaultNormY: 0.75, width: 18, height: 14, isWallItem: false),
        FurnitureItem(id: "coffeeMachine", name: "커피머신", icon: "cup.and.saucer.fill", defaultNormX: 0.45, defaultNormY: 0.5, width: 16, height: 28, isWallItem: false),
        FurnitureItem(id: "plant", name: "화분", icon: "leaf.fill", defaultNormX: 0.7, defaultNormY: 0.65, width: 14, height: 28, isWallItem: false),
        FurnitureItem(id: "picture", name: "액자", icon: "photo.artframe", defaultNormX: 0.55, defaultNormY: 0.1, width: 20, height: 16, isWallItem: true),
        FurnitureItem(id: "neonSign", name: "네온간판", icon: "lightbulb.fill", defaultNormX: 0.1, defaultNormY: 0.25, width: 64, height: 16, isWallItem: true),
        FurnitureItem(id: "rug", name: "러그", icon: "rectangle.fill", defaultNormX: 0.0, defaultNormY: 0.95, width: 100, height: 14, isWallItem: false),
        // 추가 악세서리
        FurnitureItem(id: "bookshelf", name: "책장", icon: "books.vertical.fill", defaultNormX: 0.8, defaultNormY: 0.4, width: 20, height: 36, isWallItem: false),
        FurnitureItem(id: "aquarium", name: "어항", icon: "fish.fill", defaultNormX: 0.6, defaultNormY: 0.7, width: 22, height: 18, isWallItem: false),
        FurnitureItem(id: "arcade", name: "오락기", icon: "gamecontroller.fill", defaultNormX: 0.85, defaultNormY: 0.55, width: 16, height: 30, isWallItem: false),
        FurnitureItem(id: "whiteboard", name: "화이트보드", icon: "rectangle.and.pencil.and.ellipsis", defaultNormX: 0.35, defaultNormY: 0.08, width: 30, height: 22, isWallItem: true),
        FurnitureItem(id: "lamp", name: "스탠드 조명", icon: "lamp.floor.fill", defaultNormX: 0.9, defaultNormY: 0.6, width: 10, height: 30, isWallItem: false),
        FurnitureItem(id: "cat", name: "고양이", icon: "cat.fill", defaultNormX: 0.3, defaultNormY: 0.85, width: 12, height: 10, isWallItem: false),
        FurnitureItem(id: "tv", name: "TV", icon: "tv.fill", defaultNormX: 0.7, defaultNormY: 0.15, width: 28, height: 18, isWallItem: true),
        FurnitureItem(id: "fan", name: "선풍기", icon: "fan.fill", defaultNormX: 0.5, defaultNormY: 0.65, width: 12, height: 22, isWallItem: false),
        FurnitureItem(id: "calendar", name: "달력", icon: "calendar", defaultNormX: 0.8, defaultNormY: 0.12, width: 14, height: 14, isWallItem: true),
        FurnitureItem(id: "poster", name: "포스터", icon: "doc.richtext.fill", defaultNormX: 0.45, defaultNormY: 0.08, width: 16, height: 20, isWallItem: true),
        FurnitureItem(id: "trashcan", name: "휴지통", icon: "trash.fill", defaultNormX: 0.95, defaultNormY: 0.85, width: 10, height: 12, isWallItem: false),
        FurnitureItem(id: "cushion", name: "쿠션", icon: "circle.fill", defaultNormX: 0.15, defaultNormY: 0.88, width: 12, height: 8, isWallItem: false),
    ]
}

// ═══════════════════════════════════════════════════════
// MARK: - Theme (동적 테마)
// ═══════════════════════════════════════════════════════

enum Theme {
    private static var dark: Bool { AppSettings.shared.isDarkMode }
    private static var scale: CGFloat { CGFloat(AppSettings.shared.fontSizeScale) }

    // Backgrounds
    static var bg: Color { dark ? Color(hex: "0b0d12") : Color(hex: "f2f3f5") }
    static var bgCard: Color { dark ? Color(hex: "12151c") : Color(hex: "ffffff") }
    static var bgSurface: Color { dark ? Color(hex: "181c26") : Color(hex: "ecedf0") }
    static var bgTerminal: Color { dark ? Color(hex: "0b0d12") : Color(hex: "fafbfc") }
    static var bgInput: Color { dark ? Color(hex: "131720") : Color(hex: "f5f6f8") }
    static var bgHover: Color { dark ? Color(hex: "1a1f2e") : Color(hex: "e4e5ea") }
    static var bgSelected: Color { dark ? Color(hex: "182038") : Color(hex: "dae6f5") }

    // Borders
    static var border: Color { dark ? Color(hex: "242a36") : Color(hex: "cdd0d8") }
    static var borderActive: Color { Color(hex: "4a90d9") }

    // Text
    static var textPrimary: Color { dark ? Color(hex: "e6eaf2") : Color(hex: "161624") }
    static var textSecondary: Color { dark ? Color(hex: "8690a4") : Color(hex: "4a5060") }
    static var textDim: Color { dark ? Color(hex: "485068") : Color(hex: "8a8ea0") }
    static var textTerminal: Color { dark ? Color(hex: "cdd6e6") : Color(hex: "222838") }

    // Accents
    static var accent: Color { dark ? Color(hex: "5a9af4") : Color(hex: "2868e0") }
    static var green: Color { dark ? Color(hex: "50d878") : Color(hex: "28964a") }
    static var red: Color { dark ? Color(hex: "f06868") : Color(hex: "d83838") }
    static var yellow: Color { dark ? Color(hex: "e6b444") : Color(hex: "c08800") }
    static var purple: Color { dark ? Color(hex: "ae7ce6") : Color(hex: "7c4ee0") }
    static var orange: Color { dark ? Color(hex: "e69454") : Color(hex: "d46c28") }
    static var cyan: Color { dark ? Color(hex: "4ac6ae") : Color(hex: "0c9494") }
    static var pink: Color { dark ? Color(hex: "e686aa") : Color(hex: "d44888") }

    // Fonts (scaled)
    static var monoTiny: Font { .system(size: round(9 * scale), design: .monospaced) }
    static var monoSmall: Font { .system(size: round(10 * scale), design: .monospaced) }
    static var monoNormal: Font { .system(size: round(12 * scale), design: .monospaced) }
    static var monoBold: Font { .system(size: round(11 * scale), weight: .semibold, design: .monospaced) }
    static var pixel: Font { .system(size: round(8 * scale), weight: .bold, design: .monospaced) }

    // Scaled font helper
    static func mono(_ baseSize: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: round(baseSize * scale), weight: weight, design: .monospaced)
    }

    // 일반 시스템 폰트도 스케일 적용
    static func scaled(_ baseSize: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> Font {
        .system(size: round(baseSize * scale), weight: weight, design: design)
    }

    // 아이콘 크기 스케일
    static func iconSize(_ baseSize: CGFloat) -> CGFloat {
        round(baseSize * scale)
    }

    // Worker colors
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

    // Gradients
    static var bgGradient: LinearGradient {
        dark ? LinearGradient(colors: [Color(hex: "0c0e14"), Color(hex: "101420")], startPoint: .top, endPoint: .bottom)
             : LinearGradient(colors: [Color(hex: "f5f5f7"), Color(hex: "eeeef2")], startPoint: .top, endPoint: .bottom)
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
    @State private var cacheSize: String = "계산 중..."
    @State private var showClearConfirm = false
    @State private var clearAllMode = false
    @State private var showTokenResetConfirm = false
    @State private var showTemplateResetConfirm = false

    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            HStack {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Theme.accent)
                Text("설정")
                    .font(Theme.mono(15, weight: .black))
                    .foregroundColor(Theme.textPrimary)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Theme.textDim)
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(Theme.bgSurface))
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape)
            }
            .padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 12)

            // 탭 바
            HStack(spacing: 0) {
                settingsTabButton("일반", icon: "slider.horizontal.3", tab: 0)
                settingsTabButton("화면", icon: "paintbrush.fill", tab: 1)
                settingsTabButton("오피스", icon: "building.2.fill", tab: 2)
                settingsTabButton("토큰", icon: "bolt.fill", tab: 3)
                settingsTabButton("데이터", icon: "externaldrive.fill", tab: 4)
                settingsTabButton("양식", icon: "doc.text.fill", tab: 5)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)

            Rectangle().fill(Theme.border.opacity(0.5)).frame(height: 1)

            // 탭 내용
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 14) {
                    switch selectedSettingsTab {
                    case 0: generalTab
                    case 1: displayTab
                    case 2: officeTab
                    case 3: tokenTab
                    case 4: dataTab
                    case 5: templateTab
                    default: generalTab
                    }
                }
                .padding(18)
            }
        }
        .frame(width: 560, height: 660)
        .background(Theme.bg)
        .onAppear {
            editingAppName = settings.appDisplayName
            editingCompanyName = settings.companyName
            calculateCacheSize()
        }
        .alert(clearAllMode ? "전체 데이터 삭제" : "오래된 캐시 삭제", isPresented: $showClearConfirm) {
            Button("삭제", role: .destructive) {
                if clearAllMode { clearAllData() } else { clearOldCache() }
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text(clearAllMode
                 ? "모든 세션 기록, 토큰 사용 이력, 오피스 레이아웃, 업적 데이터가 삭제됩니다. 이 작업은 되돌릴 수 없습니다."
                 : "완료된 세션 기록과 오래된 토큰 이력을 삭제합니다. 현재 진행 중인 세션과 설정은 유지됩니다.")
        }
        .alert("토큰 이력 초기화", isPresented: $showTokenResetConfirm) {
            Button("초기화", role: .destructive) {
                tokenTracker.clearAllEntries()
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("오늘/주간 토큰 사용량 기록을 바로 비웁니다. 보호 모드가 잘못 걸렸을 때 즉시 다시 입력할 수 있습니다.")
        }
        .alert("양식 전체 초기화", isPresented: $showTemplateResetConfirm) {
            Button("초기화", role: .destructive) {
                templateStore.resetAll()
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("사용자가 수정한 기획자/디자이너/리뷰어/QA/보고자/SRE 양식을 모두 기본값으로 되돌립니다.")
        }
    }

    // MARK: - Tab Button

    private func settingsTabButton(_ title: String, icon: String, tab: Int) -> some View {
        let selected = selectedSettingsTab == tab
        return Button(action: { withAnimation(.easeInOut(duration: 0.15)) { selectedSettingsTab = tab } }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .medium))
                Text(title)
                    .font(Theme.mono(9, weight: selected ? .bold : .medium))
            }
            .foregroundColor(selected ? Theme.accent : Theme.textDim)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(selected ? Theme.accent.opacity(0.1) : .clear)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 일반 탭

    private var generalTab: some View {
        VStack(spacing: 14) {
            settingsSection(title: "프로필", subtitle: "앱 이름과 회사 정보") {
                VStack(spacing: 10) {
                    labeledField(title: "앱 이름", text: $editingAppName, placeholder: "앱 이름", emphasized: true) {
                        settings.appDisplayName = editingAppName
                    }
                    labeledField(title: "회사", text: $editingCompanyName, placeholder: "회사 이름 (선택)") {
                        settings.companyName = editingCompanyName
                    }
                }
            }

            settingsSection(title: "시크릿 키", subtitle: "캐릭터 잠금 해제") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        SecureField("시크릿 키 입력", text: $secretKeyInput)
                            .textFieldStyle(.plain)
                            .font(Theme.mono(11))
                            .foregroundColor(Theme.textPrimary)
                            .padding(.horizontal, 10).padding(.vertical, 8)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Theme.bgSurface))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border.opacity(0.45), lineWidth: 1))
                            .onSubmit { applySecretKey() }

                        Button(action: { applySecretKey() }) {
                            Text("적용").font(Theme.mono(10, weight: .bold)).foregroundColor(.white)
                                .padding(.horizontal, 14).padding(.vertical, 8)
                                .background(RoundedRectangle(cornerRadius: 8).fill(Theme.accent))
                        }.buttonStyle(.plain)
                    }

                    if secretKeyResult == .success {
                        statusHint(icon: "checkmark.circle.fill", text: "전체 캐릭터가 해금되었습니다!", tint: Theme.green)
                    } else if secretKeyResult == .wrong {
                        statusHint(icon: "xmark.circle.fill", text: "올바르지 않은 키입니다.", tint: Theme.red)
                    }
                }
            }
        }
    }

    // MARK: - 화면 탭

    private var displayTab: some View {
        VStack(spacing: 14) {
            settingsSection(title: "테마", subtitle: "라이트 / 다크 모드") {
                HStack(spacing: 10) {
                    themeButton(title: "Light", icon: "sun.max.fill", isDark: false)
                    themeButton(title: "Dark", icon: "moon.fill", isDark: true)
                }
            }

            settingsSection(title: "배경 무드", subtitle: currentTheme.displayName) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                    ForEach(quickBackgroundThemes, id: \.rawValue) { theme in
                        quickBackgroundButton(theme)
                    }
                }
            }

            settingsSection(title: "글자 크기", subtitle: fontSizeLabel) {
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
            settingsSection(title: "레이아웃", subtitle: currentOfficePreset.displayName) {
                VStack(spacing: 8) {
                    ForEach(OfficePreset.allCases) { preset in
                        officePresetButton(preset)
                    }
                }
            }

            settingsSection(title: "카메라 시점", subtitle: settings.officeViewMode == "side" ? "포커스" : "전체") {
                HStack(spacing: 8) {
                    officeCameraButton(title: "전체", icon: "rectangle.expand.vertical", mode: "grid")
                    officeCameraButton(title: "포커스", icon: "scope", mode: "side")
                }
            }
        }
    }

    // MARK: - 토큰 탭

    private var tokenTab: some View {
        let protectionReason = tokenTracker.startBlockReason(isAutomation: false)
        return VStack(spacing: 14) {
            settingsSection(title: "사용량", subtitle: "오늘 / 이번 주") {
                VStack(spacing: 12) {
                    HStack(spacing: 10) {
                        usageMetricCard(
                            title: "오늘",
                            value: tokenTracker.formatTokens(tokenTracker.todayTokens),
                            secondary: "$" + String(format: "%.2f", tokenTracker.todayCost),
                            tint: Theme.accent,
                            progress: tokenTracker.dailyUsagePercent
                        )
                        usageMetricCard(
                            title: "이번 주",
                            value: tokenTracker.formatTokens(tokenTracker.weekTokens),
                            secondary: "$" + String(format: "%.2f", tokenTracker.weekCost),
                            tint: Theme.cyan,
                            progress: tokenTracker.weeklyUsagePercent
                        )
                    }

                    HStack(spacing: 12) {
                        tokenLimitField(title: "일간 한도", value: $tokenTracker.dailyTokenLimit)
                        tokenLimitField(title: "주간 한도", value: $tokenTracker.weeklyTokenLimit)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        if let protectionReason {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "lock.shield.fill")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(Theme.orange)
                                Text(protectionReason)
                                    .font(Theme.mono(8))
                                    .foregroundColor(Theme.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        } else {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.shield.fill")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(Theme.green)
                                Text("현재는 새 입력이 가능한 상태입니다. 한도를 너무 낮게 잡아도 즉시 막히지 않도록 보호선을 사용자 한도에 맞춰 계산합니다.")
                                    .font(Theme.mono(8))
                                    .foregroundColor(Theme.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }

                        HStack(spacing: 10) {
                            Button(action: {
                                tokenTracker.applyRecommendedMinimumLimits()
                            }) {
                                Text("권장 하한 적용")
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
                                Text("토큰 이력 초기화")
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

            settingsSection(title: "자동화 보호", subtitle: "토큰/재시도 상한") {
                VStack(spacing: 10) {
                    settingsToggleRow(
                        title: "AI 병렬 서브에이전트 허용",
                        subtitle: settings.allowParallelSubagents ? "허용" : "기본 차단",
                        isOn: Binding(
                            get: { settings.allowParallelSubagents },
                            set: { settings.allowParallelSubagents = $0 }
                        ),
                        tint: Theme.purple
                    )

                    settingsToggleRow(
                        title: "터미널 전용 모드 경량 사이드바",
                        subtitle: settings.terminalSidebarLightweight ? "활성" : "비활성",
                        isOn: Binding(
                            get: { settings.terminalSidebarLightweight },
                            set: { settings.terminalSidebarLightweight = $0 }
                        ),
                        tint: Theme.cyan
                    )

                    HStack(spacing: 10) {
                        limitStepperCard(
                            title: "리뷰 최대",
                            subtitle: "자동 재검토",
                            value: Binding(
                                get: { settings.reviewerMaxPasses },
                                set: { settings.reviewerMaxPasses = min(3, max(0, $0)) }
                            ),
                            range: 0...3,
                            tint: Theme.yellow
                        )
                        limitStepperCard(
                            title: "QA 최대",
                            subtitle: "자동 재테스트",
                            value: Binding(
                                get: { settings.qaMaxPasses },
                                set: { settings.qaMaxPasses = min(3, max(0, $0)) }
                            ),
                            range: 0...3,
                            tint: Theme.green
                        )
                    }

                    limitStepperCard(
                        title: "개발 재작업 최대",
                        subtitle: "자동 피드백 반영",
                        value: Binding(
                            get: { settings.automationRevisionLimit },
                            set: { settings.automationRevisionLimit = min(5, max(1, $0)) }
                        ),
                        range: 1...5,
                        tint: Theme.accent
                    )

                    HStack(spacing: 8) {
                        Image(systemName: "person.3.sequence.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Theme.orange)
                        Text("직원은 최대 13명까지 권장합니다. 그 이상은 세션 수와 메모리 사용량이 급격히 늘 수 있어 수동 추가도 막습니다.")
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
            settingsSection(title: "워크플로 양식", subtitle: selectedKind.displayName) {
                VStack(alignment: .leading, spacing: 10) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8) {
                        ForEach(AutomationTemplateKind.allCases) { kind in
                            templateKindButton(kind)
                        }
                    }

                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: selectedKind.icon)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Theme.cyan)
                        Text(selectedKind.summary)
                            .font(Theme.mono(8))
                            .foregroundColor(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            settingsSection(title: "편집기", subtitle: "바로 저장") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        statusHint(
                            icon: templateStore.isCustomized(selectedKind) ? "slider.horizontal.3" : "checkmark.circle.fill",
                            text: templateStore.isCustomized(selectedKind) ? "사용자 수정본 사용 중" : "기본 양식 사용 중",
                            tint: templateStore.isCustomized(selectedKind) ? Theme.orange : Theme.green
                        )
                        Spacer()
                        Button(action: {
                            templateStore.reset(selectedKind)
                        }) {
                            Text("현재 양식 초기화")
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

                        Button(action: {
                            showTemplateResetConfirm = true
                        }) {
                            Text("전체 초기화")
                                .font(Theme.mono(9, weight: .bold))
                                .foregroundColor(Theme.red)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(RoundedRectangle(cornerRadius: 8).fill(Theme.red.opacity(0.1)))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Theme.red.opacity(0.25), lineWidth: 1)
                                )
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
                        Text("사용 가능한 플레이스홀더")
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
                            Text("고정 자동화 상태 줄")
                                .font(Theme.mono(9, weight: .bold))
                                .foregroundColor(Theme.textDim)
                            Text("아래 줄은 워크플로우가 끊기지 않도록 앱이 뒤에서 자동으로 덧붙입니다. 본문 양식은 자유롭게 바꾸셔도 됩니다.")
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

    // MARK: - 데이터 탭

    private var dataTab: some View {
        VStack(spacing: 14) {
            settingsSection(title: "저장 공간", subtitle: cacheSize) {
                VStack(alignment: .leading, spacing: 12) {
                    dataRow(icon: "doc.text.fill", title: "세션 기록", detail: "\(SessionStore.shared.sessionCount)개", tint: Theme.accent)
                    dataRow(icon: "bolt.fill", title: "토큰 이력", detail: tokenTracker.formatTokens(tokenTracker.weekTokens), tint: Theme.yellow)
                    dataRow(icon: "building.2.fill", title: "오피스 레이아웃", detail: "UserDefaults", tint: Theme.cyan)
                    dataRow(icon: "trophy.fill", title: "업적 데이터", detail: "UserDefaults", tint: Theme.purple)
                    dataRow(icon: "person.2.fill", title: "캐릭터 데이터", detail: "UserDefaults", tint: Theme.green)
                }
            }

            settingsSection(title: "캐시 관리", subtitle: "불필요한 데이터를 정리합니다") {
                VStack(spacing: 10) {
                    Button(action: {
                        clearAllMode = false
                        showClearConfirm = true
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "wind").font(.system(size: 11, weight: .bold))
                            Text("오래된 캐시 삭제").font(Theme.mono(11, weight: .semibold))
                            Spacer()
                            Text("완료된 세션, 지난 토큰 이력")
                                .font(Theme.mono(8)).foregroundColor(Theme.textDim)
                        }
                        .foregroundColor(Theme.orange)
                        .padding(.horizontal, 12).padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.orange.opacity(0.08)))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.orange.opacity(0.25), lineWidth: 1))
                    }.buttonStyle(.plain)

                    Button(action: {
                        clearAllMode = true
                        showClearConfirm = true
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "trash.fill").font(.system(size: 11, weight: .bold))
                            Text("전체 데이터 삭제").font(Theme.mono(11, weight: .semibold))
                            Spacer()
                            Text("모든 데이터 초기화")
                                .font(Theme.mono(8)).foregroundColor(Theme.textDim)
                        }
                        .foregroundColor(Theme.red)
                        .padding(.horizontal, 12).padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.red.opacity(0.08)))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.red.opacity(0.25), lineWidth: 1))
                    }.buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Data Helpers

    private func dataRow(icon: String, title: String, detail: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 10, weight: .bold)).foregroundColor(tint)
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
        let udKeys = ["WorkManTokenHistory", "WorkManCharacters", "WorkManAchievements"]
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
                        Text("설정")
                            .font(Theme.mono(16, weight: .black))
                            .foregroundColor(Theme.textPrimary)
                        Text("작업 공간의 톤과 리듬을 한 번에 다듬습니다.")
                            .font(Theme.mono(10))
                            .foregroundColor(Theme.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 15, weight: .bold))
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
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(Theme.mono(12, weight: .black))
                    .foregroundColor(Theme.textPrimary)
                Text(subtitle)
                    .font(Theme.mono(9))
                    .foregroundColor(Theme.textDim)
            }

            content()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.bgCard.opacity(0.98))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Theme.border.opacity(0.35), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(settings.isDarkMode ? 0.16 : 0.05), radius: 10, y: 4)
    }

    private func labeledField(
        title: String,
        text: Binding<String>,
        placeholder: String,
        emphasized: Bool = false,
        onSubmit: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(Theme.mono(10, weight: .bold))
                .foregroundColor(Theme.textDim)
                .frame(width: 56, alignment: .leading)

            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .font(Theme.mono(11, weight: emphasized ? .semibold : .regular))
                .foregroundColor(Theme.textPrimary)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Theme.bgSurface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke((emphasized ? Theme.accent : Theme.border).opacity(0.35), lineWidth: 1)
                )
                .onSubmit { onSubmit() }
                .onChange(of: text.wrappedValue) { _, _ in onSubmit() }
        }
    }

    private var settingPreviewCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("미리보기")
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

                Text("이 설정으로 오피스와 터미널이 이렇게 보입니다.")
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
        return Button(action: { withAnimation(.easeInOut(duration: 0.2)) { settings.isDarkMode = isDark } }) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(selected ? (isDark ? Theme.yellow : Theme.orange) : Theme.textDim)
                Text(title)
                    .font(Theme.mono(11, weight: selected ? .bold : .regular))
                    .foregroundColor(selected ? Theme.textPrimary : Theme.textSecondary)
                Spacer()
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12)).foregroundColor(Theme.accent)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 8)
                .fill(selected ? Theme.bgSelected : Theme.bgSurface)
                .overlay(RoundedRectangle(cornerRadius: 8)
                    .stroke(selected ? Theme.accent.opacity(0.3) : Theme.border.opacity(0.5), lineWidth: 1)))
        }.buttonStyle(.plain)
    }

    struct FontSizeOption {
        let value: Double
        let label: String
    }

    private var fontSizeOptions: [FontSizeOption] {
        [
            FontSizeOption(value: 0.85, label: "S"),
            FontSizeOption(value: 1.0, label: "M"),
            FontSizeOption(value: 1.2, label: "L"),
            FontSizeOption(value: 1.4, label: "XL"),
            FontSizeOption(value: 1.7, label: "XXL"),
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
        return Button(action: {
            withAnimation(.easeInOut(duration: 0.15)) {
                settings.backgroundTheme = theme.rawValue
            }
        }) {
            HStack(spacing: 6) {
                Image(systemName: theme.icon)
                    .font(.system(size: 10, weight: .bold))
                Text(theme.displayName)
                    .font(Theme.mono(9, weight: selected ? .bold : .medium))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .foregroundColor(selected ? Theme.purple : Theme.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(selected ? Theme.purple.opacity(0.12) : Theme.bgSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(selected ? Theme.purple.opacity(0.35) : Theme.border.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func officePresetButton(_ preset: OfficePreset) -> some View {
        let selected = currentOfficePreset == preset
        return Button(action: {
            withAnimation(.easeInOut(duration: 0.15)) {
                settings.officePreset = preset.rawValue
            }
        }) {
            HStack(spacing: 10) {
                Image(systemName: preset.icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(selected ? Theme.cyan : Theme.textDim)
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
                        .font(.system(size: 12))
                        .foregroundColor(Theme.cyan)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(selected ? Theme.cyan.opacity(0.1) : Theme.bgSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(selected ? Theme.cyan.opacity(0.34) : Theme.border.opacity(0.28), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func officeCameraButton(title: String, icon: String, mode: String) -> some View {
        let selected = settings.officeViewMode == mode
        return Button(action: {
            withAnimation(.easeInOut(duration: 0.15)) {
                settings.officeViewMode = mode
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                Text(title)
                    .font(Theme.mono(10, weight: .bold))
                Spacer()
            }
            .foregroundColor(selected ? Theme.purple : Theme.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(selected ? Theme.purple.opacity(0.12) : Theme.bgSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(selected ? Theme.purple.opacity(0.34) : Theme.border.opacity(0.28), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func templateKindButton(_ kind: AutomationTemplateKind) -> some View {
        let selected = selectedTemplateKind == kind
        return Button(action: {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedTemplateKind = kind
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: kind.icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(selected ? Theme.cyan : Theme.textDim)
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
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(selected ? Theme.cyan.opacity(0.12) : Theme.bgSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(selected ? Theme.cyan.opacity(0.34) : Theme.border.opacity(0.28), lineWidth: 1)
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
                .font(.system(size: 10, weight: .bold))
            Text(text)
                .font(Theme.mono(9, weight: .medium))
        }
        .foregroundColor(tint)
    }

    // ── Secret Key ──
    @State private var secretKeyInput = ""
    @State private var secretKeyResult: SecretKeyResult = .none
    enum SecretKeyResult { case none, success, wrong }

    private static let validKeys: Set<String> = [
        "I don't like Snatch",
        "I don't like snatch",
        "i don't like snatch",
    ]

    private func applySecretKey() {
        let key = secretKeyInput.trimmingCharacters(in: .whitespaces)
        if Self.validKeys.contains(key) {
            CharacterRegistry.shared.hireAll()
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

// ═══════════════════════════════════════════════════════
// MARK: - Accessory View (휴게실 배치 & 가구 설정)
// ═══════════════════════════════════════════════════════

struct AccessoryView: View {
    @ObservedObject var settings = AppSettings.shared
    @Environment(\.dismiss) var dismiss
    @State private var selectedTab = 0  // 0=악세서리, 1=배경

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("🛋️").font(.system(size: Theme.iconSize(16)))
                Text("꾸미기").font(Theme.mono(14, weight: .bold)).foregroundColor(Theme.textPrimary)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill").font(.system(size: Theme.iconSize(16))).foregroundColor(Theme.textDim)
                }.buttonStyle(.plain)
            }.padding(.bottom, 12)

            // 탭 선택
            HStack(spacing: 0) {
                tabButton("악세서리", icon: "sofa.fill", tab: 0)
                tabButton("배경", icon: "photo.fill", tab: 1)
            }
            .background(Theme.bgSurface)
            .cornerRadius(8)
            .padding(.bottom, 12)

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
                    Text("배치").font(Theme.pixel).foregroundColor(Theme.textDim).tracking(1.5)

                    Button(action: { settings.isEditMode = true; dismiss() }) {
                        HStack(spacing: 8) {
                            Image(systemName: "hand.draw.fill").font(.system(size: Theme.iconSize(12))).foregroundColor(.white)
                            Text("드래그로 가구 배치하기").font(Theme.mono(11, weight: .bold)).foregroundColor(.white)
                            Spacer()
                            Image(systemName: "arrow.right.circle.fill").font(.system(size: Theme.iconSize(14))).foregroundColor(.white.opacity(0.7))
                        }
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 10).fill(
                            LinearGradient(colors: [Theme.purple, Theme.accent], startPoint: .leading, endPoint: .trailing)))
                    }.buttonStyle(.plain)

                    Button(action: { settings.resetFurniturePositions() }) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.counterclockwise").font(.system(size: Theme.iconSize(10))).foregroundColor(Theme.textDim)
                            Text("기본 배치로 초기화").font(Theme.mono(10)).foregroundColor(Theme.textSecondary)
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
                    Text("배경 테마").font(Theme.pixel).foregroundColor(Theme.textDim).tracking(1.5)
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
        return Button(action: { withAnimation(.easeInOut(duration: 0.15)) { toggleFurniture(item.id) } }) {
            VStack(spacing: 6) {
                // 미리보기 영역
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isOn ? Theme.purple.opacity(0.08) : Theme.bgSurface)
                        .frame(height: 50)

                    // 픽셀 아트 미리보기 (Canvas)
                    Canvas { context, size in
                        let cx = size.width / 2 - item.width / 2
                        let cy = size.height / 2 - item.height / 2 + 2
                        drawFurniturePreview(context: context, item: item, at: CGPoint(x: cx, y: cy))
                    }
                    .frame(height: 50)
                    .opacity(isOn ? 1.0 : 0.4)
                }

                // 이름 + 체크
                HStack(spacing: 3) {
                    Image(systemName: item.icon)
                        .font(.system(size: Theme.iconSize(8)))
                        .foregroundColor(isOn ? Theme.purple : Theme.textDim)
                    Text(item.name)
                        .font(Theme.mono(8, weight: isOn ? .bold : .medium))
                        .foregroundColor(isOn ? Theme.textPrimary : Theme.textDim)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: Theme.iconSize(9)))
                        .foregroundColor(isOn ? Theme.green : Theme.textDim.opacity(0.4))
                }
            }
            .padding(6)
            .background(RoundedRectangle(cornerRadius: 8)
                .stroke(isOn ? Theme.purple.opacity(0.4) : Theme.border.opacity(0.2), lineWidth: isOn ? 1.5 : 0.5))
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
        return Button(action: { withAnimation(.easeInOut(duration: 0.15)) { settings.backgroundTheme = theme.rawValue } }) {
            VStack(spacing: 4) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(LinearGradient(
                            colors: [Color(hex: theme.skyColors.top), Color(hex: theme.skyColors.bottom)],
                            startPoint: .top, endPoint: .bottom))
                        .frame(height: 28)
                    Image(systemName: theme.icon)
                        .font(.system(size: Theme.iconSize(10)))
                        .foregroundColor(.white.opacity(0.9))
                }
                Text(theme.displayName)
                    .font(Theme.mono(7, weight: selected ? .bold : .medium))
                    .foregroundColor(selected ? Theme.purple : Theme.textDim)
                    .lineLimit(1)
            }
            .padding(4)
            .background(RoundedRectangle(cornerRadius: 8)
                .fill(selected ? Theme.purple.opacity(0.1) : .clear)
                .overlay(RoundedRectangle(cornerRadius: 8)
                    .stroke(selected ? Theme.purple.opacity(0.5) : Theme.border.opacity(0.2), lineWidth: selected ? 1.5 : 0.5)))
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
                    .font(Theme.mono(10, weight: .semibold))
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
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
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
                        .font(Theme.mono(10, weight: .semibold))
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
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
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
        px(x + 3, y + 2, 2, 2, Color.white, 0.18)
        context.draw(
            Text("23").font(.system(size: 6, weight: .bold, design: .monospaced)).foregroundColor(Color.black.opacity(0.55)),
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
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6: (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default: (r, g, b) = (0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
    }
}
