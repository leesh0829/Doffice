import SwiftUI

// MARK: - Character Definition

enum WorkerJob: String, Codable, CaseIterable, Identifiable {
    case developer
    case qa
    case reporter
    case boss
    case planner
    case reviewer
    case designer
    case sre

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .developer: return NSLocalizedString("job.developer", comment: "")
        case .qa: return NSLocalizedString("job.qa", comment: "")
        case .reporter: return NSLocalizedString("job.reporter", comment: "")
        case .boss: return NSLocalizedString("job.boss", comment: "")
        case .planner: return NSLocalizedString("job.planner", comment: "")
        case .reviewer: return NSLocalizedString("job.reviewer", comment: "")
        case .designer: return NSLocalizedString("job.designer", comment: "")
        case .sre: return NSLocalizedString("job.sre", comment: "")
        }
    }

    var shortLabel: String {
        switch self {
        case .developer: return "DEV"
        case .qa: return "QA"
        case .reporter: return "MD"
        case .boss: return "CEO"
        case .planner: return "PM"
        case .reviewer: return "REV"
        case .designer: return "DES"
        case .sre: return "SRE"
        }
    }

    var icon: String {
        switch self {
        case .developer: return "laptopcomputer"
        case .qa: return "checkmark.shield.fill"
        case .reporter: return "doc.text.fill"
        case .boss: return "crown.fill"
        case .planner: return "list.bullet.clipboard.fill"
        case .reviewer: return "checklist.checked"
        case .designer: return "paintpalette.fill"
        case .sre: return "server.rack"
        }
    }

    var description: String {
        switch self {
        case .developer:
            return NSLocalizedString("job.desc.developer", comment: "")
        case .qa:
            return NSLocalizedString("job.desc.qa", comment: "")
        case .reporter:
            return NSLocalizedString("job.desc.reporter", comment: "")
        case .boss:
            return NSLocalizedString("job.desc.boss", comment: "")
        case .planner:
            return NSLocalizedString("job.desc.planner", comment: "")
        case .reviewer:
            return NSLocalizedString("job.desc.reviewer", comment: "")
        case .designer:
            return NSLocalizedString("job.desc.designer", comment: "")
        case .sre:
            return NSLocalizedString("job.desc.sre", comment: "")
        }
    }

    var relationshipHint: String {
        switch self {
        case .developer:
            return NSLocalizedString("job.hint.developer", comment: "")
        case .qa:
            return NSLocalizedString("job.hint.qa", comment: "")
        case .reporter:
            return NSLocalizedString("job.hint.reporter", comment: "")
        case .boss:
            return NSLocalizedString("job.hint.boss", comment: "")
        case .planner:
            return NSLocalizedString("job.hint.planner", comment: "")
        case .reviewer:
            return NSLocalizedString("job.hint.reviewer", comment: "")
        case .designer:
            return NSLocalizedString("job.hint.designer", comment: "")
        case .sre:
            return NSLocalizedString("job.hint.sre", comment: "")
        }
    }

    var usesExtraTokensWarning: Bool {
        self != .developer
    }

    var participatesInAutoPipeline: Bool {
        self == .reviewer || self == .qa || self == .reporter
    }

    var takesManualCodingSessions: Bool {
        self == .developer
    }
}

struct WorkerCharacter: Identifiable, Codable, Equatable {
    let id: String
    var name: String
    var archetype: String
    let hairColor: String
    let skinTone: String
    let shirtColor: String
    let pantsColor: String
    let hatType: HatType
    let accessory: Accessory
    let species: Species
    var isHired: Bool = false
    var hiredAt: Date?
    var requiredAchievement: String?  // nil이면 자유 고용, 있으면 해당 업적 달성 필요
    var jobRole: WorkerJob = .developer
    var isOnVacation: Bool = false

    var localizedArchetype: String {
        let key = "archetype.\(id)"
        let localized = NSLocalizedString(key, comment: "")
        return localized == key ? archetype : localized
    }

    var isPluginCharacter: Bool { id.hasPrefix("plugin_") }
    var isFleaMarketHiddenCharacter: Bool { id.hasPrefix("plugin_flea-market-hidden-pack_") }

    enum HatType: String, Codable, CaseIterable {
        case none, beanie, cap, hardhat, wizard, crown, headphones, beret
    }

    enum Accessory: String, Codable, CaseIterable {
        case none, glasses, sunglasses, scarf, mask, earring
    }

    enum Species: String, Codable, CaseIterable {
        case human = "Human"
        case cat = "Cat"
        case dog = "Dog"
        case rabbit = "Rabbit"
        case bear = "Bear"
        case penguin = "Penguin"
        case fox = "Fox"
        case robot = "Robot"
        case claude = "Claude"
        case alien = "Alien"
        case ghost = "Ghost"
        case dragon = "Dragon"
        case chicken = "Chicken"
        case owl = "Owl"
        case frog = "Frog"
        case panda = "Panda"
        case unicorn = "Unicorn"
        case skeleton = "Skeleton"

        var localizationKey: String {
            switch self {
            case .human: return "species.human"
            case .cat: return "species.cat"
            case .dog: return "species.dog"
            case .rabbit: return "species.rabbit"
            case .bear: return "species.bear"
            case .penguin: return "species.penguin"
            case .fox: return "species.fox"
            case .robot: return "species.robot"
            case .claude: return "species.claude"
            case .alien: return "species.alien"
            case .ghost: return "species.ghost"
            case .dragon: return "species.dragon"
            case .chicken: return "species.chicken"
            case .owl: return "species.owl"
            case .frog: return "species.frog"
            case .panda: return "species.panda"
            case .unicorn: return "species.unicorn"
            case .skeleton: return "species.skeleton"
            }
        }
        var localizedName: String { NSLocalizedString(localizationKey, comment: "") }
    }

    init(
        id: String,
        name: String,
        archetype: String,
        hairColor: String,
        skinTone: String,
        shirtColor: String,
        pantsColor: String,
        hatType: HatType,
        accessory: Accessory,
        species: Species,
        isHired: Bool = false,
        hiredAt: Date? = nil,
        requiredAchievement: String? = nil,
        jobRole: WorkerJob = .developer,
        isOnVacation: Bool = false
    ) {
        self.id = id
        self.name = name
        self.archetype = archetype
        self.hairColor = hairColor
        self.skinTone = skinTone
        self.shirtColor = shirtColor
        self.pantsColor = pantsColor
        self.hatType = hatType
        self.accessory = accessory
        self.species = species
        self.isHired = isHired
        self.hiredAt = hiredAt
        self.requiredAchievement = requiredAchievement
        self.jobRole = jobRole
        self.isOnVacation = isOnVacation
    }

    enum CodingKeys: String, CodingKey {
        case id, name, archetype, hairColor, skinTone, shirtColor, pantsColor
        case hatType, accessory, species, isHired, hiredAt, requiredAchievement
        case jobRole, isOnVacation
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        archetype = try container.decode(String.self, forKey: .archetype)
        hairColor = try container.decode(String.self, forKey: .hairColor)
        skinTone = try container.decode(String.self, forKey: .skinTone)
        shirtColor = try container.decode(String.self, forKey: .shirtColor)
        pantsColor = try container.decode(String.self, forKey: .pantsColor)
        hatType = try container.decode(HatType.self, forKey: .hatType)
        accessory = try container.decode(Accessory.self, forKey: .accessory)
        species = try container.decode(Species.self, forKey: .species)
        isHired = try container.decodeIfPresent(Bool.self, forKey: .isHired) ?? false
        hiredAt = try container.decodeIfPresent(Date.self, forKey: .hiredAt)
        requiredAchievement = try container.decodeIfPresent(String.self, forKey: .requiredAchievement)
        jobRole = try container.decodeIfPresent(WorkerJob.self, forKey: .jobRole) ?? .developer
        isOnVacation = try container.decodeIfPresent(Bool.self, forKey: .isOnVacation) ?? false
    }
}

// MARK: - Character Registry (전체 캐릭터 목록)

class CharacterRegistry: ObservableObject {
    static let shared = CharacterRegistry()
    static let maxHiredCount = 12

    @Published var allCharacters: [WorkerCharacter] = []
    @Published private(set) var manuallyUnlockedCharacterIDs: Set<String> = []

    private let saveKey = "DofficeCharacters"
    private let manualUnlockKey = "DofficeCharacterManualUnlocks"
    private static let bossLineCount = 115

    private static let defaultBossLines: [String] = [
        "열심히 일해라. 내가 보고 있다.",
        "나는 돈이 제일 좋아",
        "자기전에 생각 많이 날거야",
        "매끈매끈하다 매끈매끈한 퉁퉁하다 뚱뚱한",
        "너 내가 봤는데 좀 밤티다.",
        "이런 샤갈!",
        "허거덩거덩스한 상황이군;;",
        "chill: 빠라바라빠바바",
        "오늘도 실적 좋게 때려 부순다",
        "보고서는 필요 없다. 결과만 있으면 된다",
        "일단 돌아가면 절반은 성공이다.",
        "주석은 거짓말할 수 있지만 로그는 못 한다.",
        "배포 전 심호흡, 배포 후 기도.",
        "오늘의 아재개그: 버그가 왜 울었나? 잡혔으니까.",
        "커피가 슬프면? 에스프레소.",
        "세상에서 가장 뜨거운 과일은? 천도복숭아.",
        "가장 야한 채소는? 오이.",
        "가장 억울한 도형은? 원통해.",
        "신이 화가 나면? 신경질.",
        "왕이 넘어지면? 킹콩.",
        "소가 웃으면? 우하하.",
        "소가 계단 오를 때 하는 말은? 소오름.",
        "세상에서 가장 쉬운 숫자는? 십구만. 쉽구만.",
        "가장 지저분한 집은? 돼지우리.",
        "가장 차가운 바다는? 썰렁해.",
        "바나나가 웃으면? 바나나킥.",
        "빵이 화나면? 빵빵.",
        "자동차가 놀라면? 카놀라유.",
        "사과가 웃으면? 풋사과.",
        "도둑이 가장 좋아하는 아이스크림은? 보석바.",
        "아기가 타는 차는? 유모차.",
        "말이 물에 빠지면? 허우적허우적.",
        "개가 사람을 가르치면? 개인지도.",
        "세상에서 가장 긴 음식은? 참기름.",
        "세상에서 가장 가난한 왕은? 최저임금.",
        "가장 무서운 비는? 사이비.",
        "추운 곳에서 하는 욕은? 동상 걸리겠다.",
        "가장 잘생긴 말은? 미남말.",
        "오리가 얼면? 언덕.",
        "신발이 화나면? 신발끈.",
        "눈이 오면 강아지가 하는 말은? 개추워.",
        "닭이 가장 싫어하는 야채는? 도라지. 돌아지.",
        "문이 화나면? 문짝.",
        "토끼가 쓰는 빗은? 래빗.",
        "세상에서 가장 뜨거운 전화는? 화상전화.",
        "가장 억울한 나무는? 원망무.",
        "달이 떴는데 반만 보이면? 반달가슴곰은 아니고 반갑다.",
        "펭귄이 다니는 중학교는? 냉방중.",
        "다리미가 좋아하는 음식은? 피자. 쭉 펴지니까.",
        "가장 조용한 음식은? 쉿빵.",
        "비가 자기소개하면? 나 비야.",
        "가장 답답한 절은? 좌절.",
        "세상에서 가장 착한 사자는? 자원봉사자.",
        "아재가 제일 좋아하는 과자는? 아재비누는 아니고 홈런볼.",
        "세상에서 가장 빠른 닭은? 후다닥.",
        "고양이가 지하철 타면? 야옹철.",
        "소금이 죽으면? 염.",
        "세상에서 가장 용감한 물고기는? 대담치.",
        "가장 얇은 종이는? 간지.",
        "학생들이 가장 싫어하는 피자는? 책피자.",
        "세상에서 가장 쉬운 일은? 숨 쉬운 일.",
        "돼지가 갑자기 열받으면? 돈까스.",
        "아재개그는 왜 위험하냐고? 분위기를 얼리니까.",
        "웃지 마라. 이제 시작이다.",
        "세상에서 가장 많이 맞는 사람은? 피부미인. 늘 스킨 맞음.",
        "개가 사람을 정말 잘 가르치면? 개명강사.",
        "세상에서 가장 뜨거운 복숭아는? 천도복숭아.",
        "왕이 헤어지자고 하면? 바이킹.",
        "왕이 궁에 가기 싫으면? 궁시렁궁시렁.",
        "세상에서 가장 쉬운 돈은? 식은 죽 먹기보다 쉬운 용돈.",
        "사람이 몸무게 재다 놀라면? 체중계엄.",
        "닭이 회의하면? 닭살회의.",
        "세상에서 가장 억울한 도형은? 원통해.",
        "신이 버럭 화내면? 신경질.",
        "빵이 목장 가면? 소보로.",
        "세상에서 가장 무서운 전화는? 무선전화. 선이 없어서.",
        "말이 정말 예쁘게 웃으면? 말끔.",
        "콩이 죽으면? 홍콩. 콩 gone.",
        "원숭이가 장난전화하면? 따르릉따르릉 원숭이.",
        "세상에서 가장 지루한 중학교는? 로딩중.",
        "바다가 화나면? 파도친다.",
        "가수가 차를 못 타면? 버스커.",
        "소가 시험 보면? 우수.",
        "소가 정말 열심히 공부하면? 우등생.",
        "아몬드가 죽으면? 다이아몬드.",
        "오리가 얼면? 언덕.",
        "문어가 지은 건물은? 문어발식.",
        "도둑이 가장 싫어하는 아이스크림은? 누가바.",
        "세상에서 가장 가벼운 숫자는? 오. 오~",
        "세상에서 가장 무서운 비는? 사이비.",
        "고양이가 좋아하는 차는? 카푸치노.",
        "곰이 목욕하면? 북극곰.",
        "돼지가 넘어지면? 돈사.",
        "돼지가 미안하면? 돈워리.",
        "세상에서 가장 긴 음식은? 참기름.",
        "세상에서 가장 뜨거운 전화는? 화상전화.",
        "달리기 제일 못하는 닭은? 헉헉대닭.",
        "닭이 은행 가면? 치킨계좌.",
        "세상에서 가장 잘생긴 말은? 미남말.",
        "토끼가 화장하면? 반할 토끼.",
        "오징어가 학교 가면? 문어체는 아니고 오답지.",
        "눈이 내리면 개가 하는 말은? 개추워.",
        "세상에서 가장 조용한 빵은? 쉿빵.",
        "가장 답답한 절은? 좌절.",
        "가장 뜨거운 바다는? 열받아.",
        "공이 웃으면? 풋볼.",
        "펭귄이 다니는 중학교는? 냉방중.",
        "차가 놀라면? 카톡.",
        "치과의사가 제일 좋아하는 아침은? 이쑤시개운.",
        "세상에서 가장 슬픈 새는? 우는새.",
        "수박이 박수치면? 수박수.",
        "세상에서 가장 시원한 말은? 썰렁.",
        "아재개그가 무서운 이유는? 안 웃어도 끝까지 한다.",
        "웃겼으면 인정, 안 웃겼으면 더 인정."
    ]

    var bossLines: [String] {
        (0..<Self.bossLineCount).map { i in
            let key = "boss.line.\(i + 1)"
            let localized = NSLocalizedString(key, comment: "")
            if localized != key { return localized }
            return i < Self.defaultBossLines.count ? Self.defaultBossLines[i] : Self.defaultBossLines[i % Self.defaultBossLines.count]
        }
    }

    init() {
        loadOrCreate()
    }

    private func loadOrCreate() {
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let saved = try? JSONDecoder().decode([WorkerCharacter].self, from: data) {
            allCharacters = saved
            let defaultMap = Dictionary(uniqueKeysWithValues: Self.defaultCharacters.map { ($0.id, $0) })
            // 새 캐릭터가 추가됐으면 머지
            let existing = Set(saved.map { $0.id })
            for char in Self.defaultCharacters where !existing.contains(char.id) {
                allCharacters.append(char)
            }
            // 기존 캐릭터의 requiredAchievement를 최신 default와 동기화
            for i in allCharacters.indices {
                if let def = defaultMap[allCharacters[i].id] {
                    allCharacters[i].requiredAchievement = def.requiredAchievement
                }
            }
        } else {
            allCharacters = Self.defaultCharacters
        }
        loadManualUnlocks()
        // 플러그인 캐릭터 로드
        removeInactivePluginCharacters()
        loadPluginCharacters()
    }

    func save() {
        if let data = try? JSONEncoder().encode(allCharacters) {
            UserDefaults.standard.set(data, forKey: saveKey)
        }
    }

    func hire(_ id: String) {
        guard let idx = allCharacters.firstIndex(where: { $0.id == id }) else { return }
        // 도전과제 잠금 체크
        if let req = allCharacters[idx].requiredAchievement {
            guard AchievementManager.shared.achievements.first(where: { $0.id == req })?.unlocked == true else { return }
        }
        guard allCharacters[idx].isHired || canHire(id) else {
            notifyHiringCapReached()
            return
        }
        allCharacters[idx].isHired = true
        allCharacters[idx].hiredAt = Date()
        allCharacters[idx].archetype = Self.personalities.randomElement() ?? NSLocalizedString("char.newbie", comment: "")
        PluginHost.shared.fireEvent(.onCharacterHire)
        save()
    }

    /// 해당 캐릭터의 도전과제 잠금이 해제되었는지 확인
    func isUnlocked(_ character: WorkerCharacter) -> Bool {
        if manuallyUnlockedCharacterIDs.contains(character.id) {
            return true
        }
        guard let req = character.requiredAchievement else { return true }
        return AchievementManager.shared.achievements.first(where: { $0.id == req })?.unlocked == true
    }

    /// 필요한 도전과제 이름 반환
    func requiredAchievementName(_ character: WorkerCharacter) -> String? {
        guard let req = character.requiredAchievement else { return nil }
        return AchievementManager.shared.achievements.first(where: { $0.id == req })?.name
    }

    func hireAll() {
        for i in allCharacters.indices {
            if !allCharacters[i].isHired && hiredCharacters.count >= Self.maxHiredCount {
                break
            }
            allCharacters[i].isHired = true
            if allCharacters[i].hiredAt == nil { allCharacters[i].hiredAt = Date() }
            if allCharacters[i].archetype.isEmpty || allCharacters[i].archetype == "신입" || allCharacters[i].archetype == NSLocalizedString("char.newbie", comment: "") {
                allCharacters[i].archetype = Self.personalities.randomElement() ?? NSLocalizedString("char.newbie", comment: "")
            }
        }
        save()
    }

    @discardableResult
    func unlockAllCharacters() -> Int {
        let unlockableIDs = Set(allCharacters.compactMap { character in
            character.requiredAchievement == nil ? nil : character.id
        })
        let newlyUnlocked = unlockableIDs.subtracting(manuallyUnlockedCharacterIDs)
        guard !newlyUnlocked.isEmpty else { return 0 }
        manuallyUnlockedCharacterIDs = manuallyUnlockedCharacterIDs.union(newlyUnlocked)
        saveManualUnlocks()
        return newlyUnlocked.count
    }

    func clearManualUnlocks() {
        manuallyUnlockedCharacterIDs = []
        saveManualUnlocks()
    }

    func fire(_ id: String) {
        if let idx = allCharacters.firstIndex(where: { $0.id == id }) {
            allCharacters[idx].isHired = false
            allCharacters[idx].hiredAt = nil
            allCharacters[idx].isOnVacation = false
            save()
        }
    }

    func rename(_ id: String, to newName: String) {
        if let idx = allCharacters.firstIndex(where: { $0.id == id }) {
            allCharacters[idx].name = newName
            save()
        }
    }

    func setJobRole(_ role: WorkerJob, for id: String) {
        guard let idx = allCharacters.firstIndex(where: { $0.id == id }) else { return }
        let previous = allCharacters[idx].jobRole
        allCharacters[idx].jobRole = role
        save()

        guard previous != role else { return }
        if role.usesExtraTokensWarning {
            NotificationCenter.default.post(
                name: .dofficeRoleNotice,
                object: nil,
                userInfo: [
                    "title": String(format: NSLocalizedString("char.job.warning.title", comment: ""), role.displayName),
                    "message": NSLocalizedString("char.job.warning.message", comment: "")
                ]
            )
        }
        if role == .boss {
            NotificationCenter.default.post(
                name: .dofficeRoleNotice,
                object: nil,
                userInfo: [
                    "title": "사장 직업 안내",
                    "message": "사장은 딱히 일은 하지 않습니다."
                ]
            )
        }
    }

    func setVacation(_ isOnVacation: Bool, for id: String) {
        guard let idx = allCharacters.firstIndex(where: { $0.id == id }) else { return }
        allCharacters[idx].isOnVacation = isOnVacation
        save()
    }

    func character(with id: String?) -> WorkerCharacter? {
        guard let id else { return nil }
        return allCharacters.first(where: { $0.id == id })
    }

    var hiredCharacters: [WorkerCharacter] {
        allCharacters.filter { $0.isHired }
    }

    var canHireMore: Bool {
        hiredCharacters.count < Self.maxHiredCount
    }

    func canHire(_ id: String) -> Bool {
        guard let character = character(with: id) else { return false }
        return character.isHired || canHireMore
    }

    func hiredCharacters(for role: WorkerJob, allowVacation: Bool = false) -> [WorkerCharacter] {
        hiredCharacters.filter {
            $0.jobRole == role && (allowVacation || !$0.isOnVacation)
        }
    }

    var activeBossCharacter: WorkerCharacter? {
        hiredCharacters(for: .boss).first
    }

    func bossLine(frame: Int) -> String {
        guard !bossLines.isEmpty else { return NSLocalizedString("boss.fallback", comment: "") }
        let step = max(0, frame / Int(OfficeConstants.fps * 5))
        return bossLines[step % bossLines.count]
    }

    var availableCharacters: [WorkerCharacter] {
        allCharacters.filter { !$0.isHired }
    }

    func nextAvailable() -> WorkerCharacter? {
        availableCharacters.first
    }

    private func notifyHiringCapReached() {
        NotificationCenter.default.post(
            name: .dofficeRoleNotice,
            object: nil,
            userInfo: [
                "title": "직원 수 제한",
                "message": "직원은 최대 \(Self.maxHiredCount)명까지 권장합니다. 이 이상은 세션 증가와 메모리 사용량 문제를 만들 수 있어 막아두었습니다."
            ]
        )
    }

    private func loadManualUnlocks() {
        guard let data = UserDefaults.standard.data(forKey: manualUnlockKey),
              let decoded = try? JSONDecoder().decode([String].self, from: data) else {
            manuallyUnlockedCharacterIDs = []
            return
        }
        manuallyUnlockedCharacterIDs = Set(decoded)
    }

    private func saveManualUnlocks() {
        if manuallyUnlockedCharacterIDs.isEmpty {
            UserDefaults.standard.removeObject(forKey: manualUnlockKey)
            return
        }
        let sortedIDs = manuallyUnlockedCharacterIDs.sorted()
        if let data = try? JSONEncoder().encode(sortedIDs) {
            UserDefaults.standard.set(data, forKey: manualUnlockKey)
        }
    }

    // MARK: - Default Characters (20개)

    // 고용 시 랜덤 배정되는 성격
    static let personalities: [String] = [
        "커피머신 ☕", "일 안하는 대리", "야근 마스터", "회의실 점거범",
        "버그 제조기", "핫픽스 장인", "깃 충돌 유발자", "코드 예술가",
        "월급루팡", "Ctrl+Z 중독자", "새벽 커밋러", "점심 2시간",
        "무한 리팩토링", "TODO 수집가", "에러 친구", "빌드 깨는 자",
        "Stack Overflow 의존", "복붙 달인", "주석 없는 자", "PR 무시맨",
        "배포 두려움", "롤백 전문가", "슬랙 답장 안함", "일단 머지",
        "테스트 뭐하는거?", "의욕 만랩", "조용한 천재", "소리없는 강자",
        "에너지 드링크", "자리 이탈 중", "코딩하다 잠든 자", "런치 히어로",
    ]

    // MARK: - 플러그인 캐릭터 로드

    /// 플러그인에서 characters.json 읽어서 캐릭터 추가
    func loadPluginCharacters() {
        let pluginPaths = PluginManager.shared.activePluginPaths
        var newCharacters: [WorkerCharacter] = []
        var didChange = false

        for pluginPath in pluginPaths {
            let jsonURL = URL(fileURLWithPath: pluginPath).appendingPathComponent("characters.json")
            guard FileManager.default.fileExists(atPath: jsonURL.path),
                  let data = try? Data(contentsOf: jsonURL),
                  let chars = try? JSONDecoder().decode([WorkerCharacter].self, from: data) else {
                continue
            }
            // ID 충돌 방지: "plugin_" 접두사 추가
            let pluginName = URL(fileURLWithPath: pluginPath).lastPathComponent
            for var char in chars {
                let originalID = char.id
                let prefixedId = "plugin_\(pluginName)_\(char.id)"
                let existingIndex = allCharacters.firstIndex(where: { $0.id == prefixedId })
                let existingCharacter = existingIndex.flatMap { allCharacters[$0] }
                char = WorkerCharacter(
                    id: prefixedId,
                    name: Self.syncedPluginCharacterName(
                        pluginName: pluginName,
                        originalID: originalID,
                        bundledName: char.name,
                        existingName: existingCharacter?.name
                    ),
                    archetype: char.archetype,
                    hairColor: char.hairColor,
                    skinTone: char.skinTone,
                    shirtColor: char.shirtColor,
                    pantsColor: char.pantsColor,
                    hatType: char.hatType,
                    accessory: char.accessory,
                    species: char.species,
                    isHired: existingCharacter?.isHired ?? true, // 플러그인 캐릭터는 기본 고용 상태
                    hiredAt: existingCharacter?.hiredAt,
                    requiredAchievement: char.requiredAchievement,
                    jobRole: existingCharacter?.jobRole ?? char.jobRole,
                    isOnVacation: existingCharacter?.isOnVacation ?? false
                )
                if let existingIndex {
                    if allCharacters[existingIndex] != char {
                        allCharacters[existingIndex] = char
                        didChange = true
                    }
                } else {
                    newCharacters.append(char)
                    didChange = true
                }
            }
        }

        if !newCharacters.isEmpty {
            allCharacters.append(contentsOf: newCharacters)
        }
        if didChange { save() }
    }

    /// 비활성 플러그인의 캐릭터 제거
    func removeInactivePluginCharacters() {
        let activePaths = Set(PluginManager.shared.activePluginPaths.map {
            URL(fileURLWithPath: $0).lastPathComponent
        })
        let before = allCharacters.count
        allCharacters.removeAll { char in
            guard char.id.hasPrefix("plugin_") else { return false }
            // "plugin_<pluginName>_<originalId>" → pluginName 추출
            let parts = char.id.dropFirst("plugin_".count)
            guard let underscoreIdx = parts.firstIndex(of: "_") else { return true }
            let pluginName = String(parts[parts.startIndex..<underscoreIdx])
            return !activePaths.contains(pluginName)
        }
        if allCharacters.count != before { save() }
    }

    static func syncedPluginCharacterName(
        pluginName: String,
        originalID: String,
        bundledName: String,
        existingName: String?
    ) -> String {
        let trimmedExisting = existingName?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard pluginName == "flea-market-hidden-pack" else {
            if let trimmedExisting, !trimmedExisting.isEmpty {
                return trimmedExisting
            }
            return bundledName
        }

        let preferredName = preferredFleaMarketHiddenCharacterName(for: originalID, fallback: bundledName)
        guard let trimmedExisting, !trimmedExisting.isEmpty else { return preferredName }
        let legacyNames = legacyFleaMarketHiddenCharacterNames(for: originalID)
        if legacyNames.contains(trimmedExisting) || trimmedExisting == bundledName {
            return preferredName
        }
        return trimmedExisting
    }

    private static func preferredFleaMarketHiddenCharacterName(for originalID: String, fallback: String) -> String {
        switch originalID {
        case "night_vendor": return "히든 야시장"
        case "lucky_tag": return "히든 럭키태그"
        case "ghost_dealer": return "히든 고스트딜러"
        default: return fallback
        }
    }

    private static func legacyFleaMarketHiddenCharacterNames(for originalID: String) -> Set<String> {
        switch originalID {
        case "night_vendor": return ["야시장", "히든 야시장"]
        case "lucky_tag": return ["럭키태그", "히든 럭키태그"]
        case "ghost_dealer": return ["고스트딜러", "히든 고스트딜러"]
        default: return []
        }
    }

    static let defaultCharacters: [WorkerCharacter] = [
        // 🧑 사람
        WorkerCharacter(id: "pixel", name: "Pixel", archetype: "커피머신 ☕", hairColor: "4a3728", skinTone: "ffd5b8", shirtColor: "f08080", pantsColor: "3a4050", hatType: .none, accessory: .glasses, species: .human, isHired: true),
        WorkerCharacter(id: "byte", name: "Byte", archetype: "야근 마스터", hairColor: "2c1810", skinTone: "ffd5b8", shirtColor: "72d6a0", pantsColor: "3a4050", hatType: .beanie, accessory: .none, species: .human, isHired: true),
        WorkerCharacter(id: "code", name: "Code", archetype: "Ctrl+Z 중독자", hairColor: "d4a574", skinTone: "e8c4a0", shirtColor: "f0c05a", pantsColor: "3a4050", hatType: .none, accessory: .none, species: .human, isHired: true),
        WorkerCharacter(id: "bug", name: "Bug", archetype: "버그 제조기", hairColor: "8b4513", skinTone: "ffd5b8", shirtColor: "78b4f0", pantsColor: "3a4050", hatType: .cap, accessory: .none, species: .human, isHired: true),
        WorkerCharacter(id: "chip", name: "Chip", archetype: "슬랙 답장 안함", hairColor: "1a1a30", skinTone: "c8a882", shirtColor: "c490e8", pantsColor: "3a4050", hatType: .none, accessory: .sunglasses, species: .human),
        WorkerCharacter(id: "kit", name: "Kit", archetype: "코드 예술가", hairColor: "e06060", skinTone: "ffd5b8", shirtColor: "f0a060", pantsColor: "3a4050", hatType: .beret, accessory: .none, species: .human),
        WorkerCharacter(id: "dot", name: "Dot", archetype: "TODO 수집가", hairColor: "4040a0", skinTone: "e8c4a0", shirtColor: "60d0c0", pantsColor: "3a4050", hatType: .none, accessory: .glasses, species: .human),
        WorkerCharacter(id: "rex", name: "Rex", archetype: "일단 머지", hairColor: "c4a474", skinTone: "ffd5b8", shirtColor: "f080c0", pantsColor: "3a4050", hatType: .headphones, accessory: .none, species: .human),

        WorkerCharacter(id: "nova", name: "Nova", archetype: "조용한 천재", hairColor: "e0e0ff", skinTone: "ffd5b8", shirtColor: "8080f0", pantsColor: "2a3040", hatType: .none, accessory: .glasses, species: .human, requiredAchievement: "session_streak_7"),
        WorkerCharacter(id: "dash", name: "Dash", archetype: "에너지 드링크", hairColor: "ff6060", skinTone: "e8c4a0", shirtColor: "40c0e0", pantsColor: "3a4050", hatType: .cap, accessory: .none, species: .human, requiredAchievement: "session_streak_3"),
        WorkerCharacter(id: "root", name: "Root", archetype: "소리없는 강자", hairColor: "606060", skinTone: "c8a882", shirtColor: "404040", pantsColor: "2a2a2a", hatType: .none, accessory: .sunglasses, species: .human, requiredAchievement: "centurion"),
        WorkerCharacter(id: "flux", name: "Flux", archetype: "무한 리팩토링", hairColor: "50b050", skinTone: "ffd5b8", shirtColor: "e0e0e0", pantsColor: "3a4050", hatType: .wizard, accessory: .none, species: .human, requiredAchievement: "marathon"),
        WorkerCharacter(id: "sage", name: "Sage", archetype: "회의실 점거범", hairColor: "b0b0b0", skinTone: "e8c4a0", shirtColor: "6080a0", pantsColor: "3a4050", hatType: .none, accessory: .glasses, species: .human, requiredAchievement: "complete_50"),
        WorkerCharacter(id: "bolt", name: "Bolt", archetype: "핫픽스 장인", hairColor: "f0c020", skinTone: "ffd5b8", shirtColor: "f0a020", pantsColor: "3a4050", hatType: .hardhat, accessory: .none, species: .human, requiredAchievement: "speed_demon"),
        WorkerCharacter(id: "pip", name: "Pip", archetype: "의욕 만랩", hairColor: "f0a060", skinTone: "ffd5b8", shirtColor: "60a0f0", pantsColor: "4050a0", hatType: .beanie, accessory: .none, species: .human),

        // 🐱 고양이
        WorkerCharacter(id: "mochi", name: "모찌", archetype: "자리 이탈 중", hairColor: "f0e0d0", skinTone: "f5e6d0", shirtColor: "f08080", pantsColor: "3a4050", hatType: .none, accessory: .none, species: .cat),
        WorkerCharacter(id: "nabi", name: "나비", archetype: "키보드 위의 고양이", hairColor: "404040", skinTone: "505050", shirtColor: "ffd369", pantsColor: "3a4050", hatType: .none, accessory: .glasses, species: .cat, requiredAchievement: "night_owl"),
        WorkerCharacter(id: "cheese", name: "치즈", archetype: "점심 2시간", hairColor: "f0a030", skinTone: "f0b040", shirtColor: "60c060", pantsColor: "3a4050", hatType: .none, accessory: .none, species: .cat),

        // 🐶 강아지
        WorkerCharacter(id: "bori", name: "보리", archetype: "런치 히어로", hairColor: "c09060", skinTone: "d0a070", shirtColor: "4090d0", pantsColor: "3a4050", hatType: .cap, accessory: .none, species: .dog),
        WorkerCharacter(id: "coco", name: "코코", archetype: "배포 두려움", hairColor: "f0f0f0", skinTone: "f0e8e0", shirtColor: "e06060", pantsColor: "3a4050", hatType: .none, accessory: .scarf, species: .dog),

        // 🐰 토끼
        WorkerCharacter(id: "ddu", name: "뚜", archetype: "새벽 커밋러", hairColor: "f0e0e0", skinTone: "f5e8e8", shirtColor: "f090c0", pantsColor: "3a4050", hatType: .none, accessory: .none, species: .rabbit),
        WorkerCharacter(id: "toki", name: "토키", archetype: "복붙 달인", hairColor: "e0d0c0", skinTone: "e8dcd0", shirtColor: "90c0f0", pantsColor: "3a4050", hatType: .beanie, accessory: .none, species: .rabbit, requiredAchievement: "bug_squasher"),

        // 🐻 곰
        WorkerCharacter(id: "gomi", name: "고미", archetype: "코딩하다 잠든 자", hairColor: "8b6040", skinTone: "a07050", shirtColor: "40a060", pantsColor: "3a4050", hatType: .hardhat, accessory: .none, species: .bear, requiredAchievement: "ultra_marathon"),

        // 🐧 펭귄
        WorkerCharacter(id: "pengu", name: "펭구", archetype: "월급루팡", hairColor: "2a2a3a", skinTone: "3a3a4a", shirtColor: "f0f0f0", pantsColor: "2a2a3a", hatType: .none, accessory: .sunglasses, species: .penguin, requiredAchievement: "token_whale"),

        // 🦊 여우
        WorkerCharacter(id: "yuri", name: "유리", archetype: "깃 충돌 유발자", hairColor: "e07030", skinTone: "e08040", shirtColor: "f0c060", pantsColor: "3a4050", hatType: .none, accessory: .glasses, species: .fox, requiredAchievement: "git_master"),

        // 🤖 로봇
        WorkerCharacter(id: "zero", name: "Zero", archetype: "Stack Overflow 의존", hairColor: "8090a0", skinTone: "a0b0c0", shirtColor: "6080a0", pantsColor: "506070", hatType: .none, accessory: .none, species: .robot, requiredAchievement: "level_5"),
        WorkerCharacter(id: "ai01", name: "AI-01", archetype: "주석 없는 자", hairColor: "60f0a0", skinTone: "90a0b0", shirtColor: "304050", pantsColor: "203040", hatType: .headphones, accessory: .none, species: .robot, requiredAchievement: "command_500"),

        // ✨ Claude
        WorkerCharacter(id: "claude_opus", name: "Claude", archetype: "Opus", hairColor: "d97757", skinTone: "f5e6d0", shirtColor: "d97757", pantsColor: "2a2a3a", hatType: .none, accessory: .none, species: .claude, isHired: true),
        WorkerCharacter(id: "claude_sonnet", name: "Sonnet", archetype: "Sonnet", hairColor: "5b9cf6", skinTone: "f5e6d0", shirtColor: "5b9cf6", pantsColor: "2a2a3a", hatType: .none, accessory: .none, species: .claude, requiredAchievement: "three_models"),
        WorkerCharacter(id: "claude_haiku", name: "Haiku", archetype: "Haiku", hairColor: "56d97e", skinTone: "f5e6d0", shirtColor: "56d97e", pantsColor: "2a2a3a", hatType: .none, accessory: .none, species: .claude, requiredAchievement: "haiku_user"),

        // 👽 외계인
        WorkerCharacter(id: "zyx", name: "Zyx", archetype: "차원 여행자", hairColor: "40f080", skinTone: "80f0a0", shirtColor: "206040", pantsColor: "103020", hatType: .none, accessory: .none, species: .alien),
        WorkerCharacter(id: "nova_x", name: "Nova-X", archetype: "텔레파시 코더", hairColor: "a060ff", skinTone: "c0a0f0", shirtColor: "6030a0", pantsColor: "301860", hatType: .none, accessory: .glasses, species: .alien, requiredAchievement: "token_whale"),
        WorkerCharacter(id: "blip", name: "Blip", archetype: "0과 1의 존재", hairColor: "60f0f0", skinTone: "80e0e0", shirtColor: "206060", pantsColor: "104040", hatType: .headphones, accessory: .none, species: .alien, requiredAchievement: "level_8"),
        WorkerCharacter(id: "mars", name: "Mars", archetype: "화성에서 온 PM", hairColor: "f06040", skinTone: "e0a080", shirtColor: "c04020", pantsColor: "602010", hatType: .none, accessory: .sunglasses, species: .alien),

        // 👻 유령
        WorkerCharacter(id: "boo", name: "Boo", archetype: "보이지 않는 버그", hairColor: "d0d8e0", skinTone: "e8ecf4", shirtColor: "c0c8d8", pantsColor: "a0a8b8", hatType: .none, accessory: .none, species: .ghost),
        WorkerCharacter(id: "shade", name: "Shade", archetype: "야간 배포 전문", hairColor: "8088a0", skinTone: "b0b8d0", shirtColor: "606880", pantsColor: "404860", hatType: .none, accessory: .glasses, species: .ghost, requiredAchievement: "night_owl"),
        WorkerCharacter(id: "wisp", name: "Wisp", archetype: "사라진 커밋", hairColor: "a0e0ff", skinTone: "d0f0ff", shirtColor: "80c0e0", pantsColor: "60a0c0", hatType: .none, accessory: .none, species: .ghost, requiredAchievement: "night_marathon"),

        // 🐉 드래곤
        WorkerCharacter(id: "drako", name: "Drako", archetype: "서버 불지르는 자", hairColor: "e04020", skinTone: "c06040", shirtColor: "a02010", pantsColor: "601008", hatType: .none, accessory: .none, species: .dragon, requiredAchievement: "error_10"),
        WorkerCharacter(id: "azure", name: "Azure", archetype: "클라우드 날다", hairColor: "4090e0", skinTone: "80b0e0", shirtColor: "3070c0", pantsColor: "204080", hatType: .none, accessory: .none, species: .dragon, requiredAchievement: "cost_10"),
        WorkerCharacter(id: "ember", name: "Ember", archetype: "핫픽스 화염구", hairColor: "f0a030", skinTone: "e0a060", shirtColor: "d08020", pantsColor: "a06010", hatType: .crown, accessory: .none, species: .dragon, requiredAchievement: "level_10"),

        // 🐔 닭
        WorkerCharacter(id: "kko", name: "꼬", archetype: "새벽 알람", hairColor: "e0c080", skinTone: "f0e0c0", shirtColor: "f0f0e0", pantsColor: "d0c0a0", hatType: .none, accessory: .none, species: .chicken),
        WorkerCharacter(id: "dak", name: "닥", archetype: "치킨 타이머", hairColor: "c0a060", skinTone: "e0d0b0", shirtColor: "d0a040", pantsColor: "a08030", hatType: .cap, accessory: .none, species: .chicken, requiredAchievement: "early_bird"),

        // 🦉 부엉이
        WorkerCharacter(id: "hoot", name: "Hoot", archetype: "코드 리뷰의 눈", hairColor: "8b6040", skinTone: "a08060", shirtColor: "705030", pantsColor: "503820", hatType: .none, accessory: .glasses, species: .owl, requiredAchievement: "night_complete"),
        WorkerCharacter(id: "luna", name: "Luna", archetype: "밤의 파수꾼", hairColor: "404060", skinTone: "606080", shirtColor: "303050", pantsColor: "202040", hatType: .wizard, accessory: .none, species: .owl, requiredAchievement: "night_marathon"),

        // 🐸 개구리
        WorkerCharacter(id: "gae", name: "개굴", archetype: "점프 디버거", hairColor: "40a040", skinTone: "60c060", shirtColor: "308030", pantsColor: "206020", hatType: .none, accessory: .none, species: .frog),
        WorkerCharacter(id: "ribbit", name: "Ribbit", archetype: "워터폴 개발자", hairColor: "30b070", skinTone: "50d090", shirtColor: "208050", pantsColor: "106030", hatType: .beanie, accessory: .sunglasses, species: .frog, requiredAchievement: "focus_30"),

        // 🐼 판다
        WorkerCharacter(id: "bao", name: "바오", archetype: "대나무 먹방 중", hairColor: "202020", skinTone: "f0f0f0", shirtColor: "1a1a1a", pantsColor: "101010", hatType: .none, accessory: .none, species: .panda),
        WorkerCharacter(id: "mei", name: "메이", archetype: "느긋한 아키텍트", hairColor: "303030", skinTone: "e8e8e8", shirtColor: "f08080", pantsColor: "303030", hatType: .none, accessory: .glasses, species: .panda, requiredAchievement: "complete_25"),

        // 🦄 유니콘
        WorkerCharacter(id: "stella", name: "Stella", archetype: "유니콘 스타트업", hairColor: "ff80c0", skinTone: "fff0f8", shirtColor: "c060a0", pantsColor: "803868", hatType: .crown, accessory: .none, species: .unicorn, requiredAchievement: "level_5"),
        WorkerCharacter(id: "rainbow", name: "Rainbow", archetype: "무지개 빌더", hairColor: "f06080", skinTone: "f8e8f0", shirtColor: "80a0f0", pantsColor: "5070c0", hatType: .none, accessory: .none, species: .unicorn, requiredAchievement: "complete_100"),

        // 💀 해골
        WorkerCharacter(id: "bones", name: "Bones", archetype: "레거시 코드", hairColor: "e0e0e0", skinTone: "f0f0e8", shirtColor: "404040", pantsColor: "2a2a2a", hatType: .none, accessory: .none, species: .skeleton, requiredAchievement: "centurion"),
        WorkerCharacter(id: "skull", name: "Skull", archetype: "데드코드 수집가", hairColor: "d0d0c8", skinTone: "e8e8e0", shirtColor: "202020", pantsColor: "101010", hatType: .headphones, accessory: .sunglasses, species: .skeleton, requiredAchievement: "command_1000"),

        // 🧑 추가 사람
        WorkerCharacter(id: "ace", name: "Ace", archetype: "PR 무시맨", hairColor: "303040", skinTone: "c8a882", shirtColor: "e04040", pantsColor: "3a4050", hatType: .cap, accessory: .none, species: .human),
        WorkerCharacter(id: "ivy", name: "Ivy", archetype: "테스트 뭐하는거?", hairColor: "205020", skinTone: "ffd5b8", shirtColor: "40a060", pantsColor: "3a4050", hatType: .none, accessory: .glasses, species: .human),
        WorkerCharacter(id: "max", name: "Max", archetype: "에러 친구", hairColor: "a08040", skinTone: "e8c4a0", shirtColor: "d06030", pantsColor: "3a4050", hatType: .hardhat, accessory: .none, species: .human, requiredAchievement: "error_5"),
        WorkerCharacter(id: "sky", name: "Sky", archetype: "배포 두려움 극복", hairColor: "80b0e0", skinTone: "ffd5b8", shirtColor: "4080c0", pantsColor: "3a4050", hatType: .none, accessory: .none, species: .human, requiredAchievement: "complete_10"),
        WorkerCharacter(id: "zen", name: "Zen", archetype: "롤백 전문가", hairColor: "808080", skinTone: "e8c4a0", shirtColor: "b0b0b0", pantsColor: "3a4050", hatType: .none, accessory: .glasses, species: .human, requiredAchievement: "marathon"),

        // 🤖 추가 로봇
        WorkerCharacter(id: "bit", name: "Bit", archetype: "바이너리 토커", hairColor: "50e050", skinTone: "80a090", shirtColor: "206030", pantsColor: "103020", hatType: .none, accessory: .none, species: .robot),
        WorkerCharacter(id: "cpu", name: "CPU", archetype: "오버클럭 중", hairColor: "f06060", skinTone: "a0b0c0", shirtColor: "804040", pantsColor: "503030", hatType: .headphones, accessory: .none, species: .robot, requiredAchievement: "speed_2min"),

        // 🐱 추가 고양이
        WorkerCharacter(id: "tuna", name: "참치", archetype: "간식 협상가", hairColor: "808080", skinTone: "a0a0a0", shirtColor: "5080a0", pantsColor: "3a4050", hatType: .none, accessory: .none, species: .cat, requiredAchievement: "lunch_coder"),

        // 🐶 추가 강아지
        WorkerCharacter(id: "maru", name: "마루", archetype: "꼬리 흔드는 QA", hairColor: "e0c080", skinTone: "f0d8b0", shirtColor: "e08040", pantsColor: "3a4050", hatType: .none, accessory: .scarf, species: .dog, requiredAchievement: "complete_5"),

        // ════════════ 추가 20캐릭터 ════════════

        // 👽 외계인 추가
        WorkerCharacter(id: "nebula", name: "Nebula", archetype: "우주 디버거", hairColor: "8040c0", skinTone: "a070e0", shirtColor: "5020a0", pantsColor: "301060", hatType: .none, accessory: .glasses, species: .alien, requiredAchievement: "token_10k_total"),

        // 👻 유령 추가
        WorkerCharacter(id: "phantom", name: "Phantom", archetype: "404 Not Found", hairColor: "6070a0", skinTone: "90a0c0", shirtColor: "4050a0", pantsColor: "303080", hatType: .none, accessory: .mask, species: .ghost, requiredAchievement: "complete_50"),

        // 🐉 드래곤 추가
        WorkerCharacter(id: "frost", name: "Frost", archetype: "서버 냉각기", hairColor: "80c0f0", skinTone: "a0d0f0", shirtColor: "4080c0", pantsColor: "205080", hatType: .crown, accessory: .none, species: .dragon, requiredAchievement: "session_streak_7"),

        // 🐔 닭 추가
        WorkerCharacter(id: "egg", name: "알", archetype: NSLocalizedString("char.egg.archetype", comment: ""), hairColor: "f0e8d0", skinTone: "f8f0e0", shirtColor: "f0e0c0", pantsColor: "e0d0b0", hatType: .none, accessory: .none, species: .chicken),

        // 🦉 부엉이 추가
        WorkerCharacter(id: "wise", name: "Wise", archetype: "시니어 코드 리뷰어", hairColor: "c0b0a0", skinTone: "d0c0b0", shirtColor: "605040", pantsColor: "403020", hatType: .wizard, accessory: .glasses, species: .owl, requiredAchievement: "git_master_25"),

        // 🐸 개구리 추가
        WorkerCharacter(id: "lily", name: "Lily", archetype: "연잎 위의 리모트워커", hairColor: "30c050", skinTone: "50e070", shirtColor: "f0a0c0", pantsColor: "c07090", hatType: .beret, accessory: .none, species: .frog, requiredAchievement: "weekend_warrior"),

        // 🐼 판다 추가
        WorkerCharacter(id: "yin", name: "Yin", archetype: "야근조", hairColor: "1a1a1a", skinTone: "f0f0f0", shirtColor: "303030", pantsColor: "1a1a1a", hatType: .headphones, accessory: .none, species: .panda, requiredAchievement: "night_owl"),

        // 🦄 유니콘 추가
        WorkerCharacter(id: "prism", name: "Prism", archetype: "프리즘 리팩토러", hairColor: "40d0f0", skinTone: "f0f0ff", shirtColor: "f080f0", pantsColor: "a050a0", hatType: .none, accessory: .sunglasses, species: .unicorn, requiredAchievement: "three_models"),

        // 💀 해골 추가
        WorkerCharacter(id: "grim", name: "Grim", archetype: "rm -rf /", hairColor: "c0c0b0", skinTone: "e0e0d8", shirtColor: "101010", pantsColor: "080808", hatType: .none, accessory: .none, species: .skeleton, requiredAchievement: "command_5000"),

        // 🐰 토끼 추가
        WorkerCharacter(id: "snow", name: "Snow", archetype: "화이트박스 테스터", hairColor: "f0f0f0", skinTone: "f8f0f0", shirtColor: "f0c0d0", pantsColor: "d0a0b0", hatType: .none, accessory: .none, species: .rabbit),
        WorkerCharacter(id: "choco", name: "Choco", archetype: "초콜릿 빌더", hairColor: "6a4030", skinTone: "8b6040", shirtColor: "c08060", pantsColor: "805040", hatType: .beanie, accessory: .none, species: .rabbit, requiredAchievement: "session_10"),

        // 🐻 곰 추가
        WorkerCharacter(id: "polar", name: "Polar", archetype: "북극곰 SRE", hairColor: "e8e8f0", skinTone: "f0f0f8", shirtColor: "80a0c0", pantsColor: "506080", hatType: .none, accessory: .scarf, species: .bear, requiredAchievement: "snow"),

        // 🐧 펭귄 추가
        WorkerCharacter(id: "tux", name: "Tux", archetype: "리눅스 커널 해커", hairColor: "1a1a2a", skinTone: "2a2a3a", shirtColor: "f8f8f8", pantsColor: "1a1a2a", hatType: .headphones, accessory: .none, species: .penguin, requiredAchievement: "opus_user"),

        // 🦊 여우 추가
        WorkerCharacter(id: "firefox", name: "Firefox", archetype: "브라우저 전쟁 생존자", hairColor: "f04020", skinTone: "f06030", shirtColor: "e08020", pantsColor: "a05010", hatType: .none, accessory: .sunglasses, species: .fox, requiredAchievement: "speed_demon"),

        // 🧑 사람 추가
        WorkerCharacter(id: "luna_h", name: "루나", archetype: "달빛 코더", hairColor: "c0b8d0", skinTone: "ffd5b8", shirtColor: "6060a0", pantsColor: "3a3a60", hatType: .none, accessory: .earring, species: .human, requiredAchievement: "night_complete"),
        WorkerCharacter(id: "sol", name: "Sol", archetype: "일출 배포", hairColor: "f0c040", skinTone: "e8c4a0", shirtColor: "f08030", pantsColor: "a05020", hatType: .cap, accessory: .none, species: .human, requiredAchievement: "morning_complete"),
        WorkerCharacter(id: "storm_h", name: "Storm", archetype: "핫픽스 폭풍", hairColor: "404060", skinTone: "ffd5b8", shirtColor: "3050a0", pantsColor: "202848", hatType: .none, accessory: .none, species: .human, requiredAchievement: "speed_2min"),
        WorkerCharacter(id: "jade", name: "Jade", archetype: "그린필드 개척자", hairColor: "1a3020", skinTone: "c8a882", shirtColor: "40a060", pantsColor: "205030", hatType: .hardhat, accessory: .glasses, species: .human),
        WorkerCharacter(id: "ruby", name: "Ruby", archetype: "레드팀 리더", hairColor: "a02020", skinTone: "ffd5b8", shirtColor: "c03030", pantsColor: "801818", hatType: .none, accessory: .none, species: .human, requiredAchievement: "error_10"),
        WorkerCharacter(id: "indigo", name: "Indigo", archetype: "딥워크 마스터", hairColor: "3030a0", skinTone: "e8c4a0", shirtColor: "4040c0", pantsColor: "2a2a80", hatType: .beret, accessory: .glasses, species: .human, requiredAchievement: "ultra_marathon"),
    ]
}

// MARK: - Character Collection View

struct CharacterCollectionView: View {
    @ObservedObject var registry = CharacterRegistry.shared
    @Environment(\.dismiss) var dismiss
    @State private var editingId: String?
    @State private var editName = ""
    @State private var selectedSpecies: WorkerCharacter.Species? = nil
    // grid only (list mode removed)

    @State private var showPipeline = false

    let columns = [
        GridItem(.adaptive(minimum: 240, maximum: 320), spacing: 12, alignment: .top)
    ]

    private var filteredHired: [WorkerCharacter] {
        let chars = registry.hiredCharacters
        guard let sp = selectedSpecies else { return sortedCharacters(chars) }
        return sortedCharacters(chars.filter { $0.species == sp })
    }

    private var filteredAvailable: [WorkerCharacter] {
        let chars = registry.availableCharacters.filter { registry.isUnlocked($0) }
        guard let sp = selectedSpecies else { return sortedCharacters(chars) }
        return sortedCharacters(chars.filter { $0.species == sp })
    }

    private var filteredLocked: [WorkerCharacter] {
        let chars = registry.availableCharacters.filter { !registry.isUnlocked($0) }
        guard let sp = selectedSpecies else { return sortedCharacters(chars) }
        return sortedCharacters(chars.filter { $0.species == sp })
    }

    var body: some View {
        VStack(spacing: 0) {
            DSModalHeader(
                icon: "person.3.fill",
                iconColor: Theme.accent,
                title: NSLocalizedString("char.title", comment: ""),
                subtitle: String(format: NSLocalizedString("char.subtitle", comment: ""), registry.hiredCharacters.count, registry.allCharacters.count),
                onClose: { dismiss() }
            )

            // Species filter row – compact wrapping grid
            let allSpecies = WorkerCharacter.Species.allCases
            let speciesWithCount: [(sp: WorkerCharacter.Species?, label: String, count: Int)] =
                [(nil, "All", registry.allCharacters.count)] +
                allSpecies.map { sp in (sp as WorkerCharacter.Species?, speciesFilterEmoji(sp), registry.allCharacters.filter { $0.species == sp }.count) }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(Array(speciesWithCount.enumerated()), id: \.offset) { _, item in
                        speciesChip(species: item.sp, emoji: item.label, count: item.count)
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
            }
            .background(Theme.bgSurface.opacity(0.3))

            Rectangle().fill(Theme.border).frame(height: 1)

            // Compact info bar: stats + pipeline toggle
            HStack(spacing: 12) {
                // Inline stats
                HStack(spacing: 10) {
                    statBadge("\(registry.hiredCharacters.count)/\(CharacterRegistry.maxHiredCount)", icon: "person.2.fill", tint: Theme.accent)
                    statBadge("\(registry.hiredCharacters(for: .developer, allowVacation: true).count)", icon: "laptopcomputer", tint: Theme.accent)
                    statBadge("\(registry.hiredCharacters(for: .qa, allowVacation: true).count)", icon: "checkmark.shield.fill", tint: Theme.green)
                    statBadge("\(registry.hiredCharacters(for: .reporter, allowVacation: true).count)", icon: "doc.text.fill", tint: Theme.purple)
                }

                Spacer()

                Button(action: { withAnimation(.easeInOut(duration: 0.2)) { showPipeline.toggle() } }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.swap").font(.system(size: 9, weight: .bold))
                        Text(NSLocalizedString("char.pipeline", comment: "")).font(Theme.mono(8, weight: .medium))
                        Image(systemName: showPipeline ? "chevron.up" : "chevron.down").font(.system(size: 7, weight: .bold))
                    }
                    .foregroundColor(Theme.textDim)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Theme.bgSurface))
                }.buttonStyle(.plain)
            }
            .padding(.horizontal, 18).padding(.vertical, 8)

            if showPipeline {
                VStack(alignment: .leading, spacing: 8) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 0) {
                            pipelineStep(icon: "list.bullet.rectangle.portrait.fill", label: NSLocalizedString("char.pipeline.plan", comment: ""), color: Theme.cyan, isFirst: true)
                            pipelineArrow()
                            pipelineStep(icon: "paintbrush.pointed.fill", label: NSLocalizedString("char.pipeline.design", comment: ""), color: Theme.pink)
                            pipelineArrow()
                            pipelineStep(icon: "hammer.fill", label: NSLocalizedString("char.pipeline.dev", comment: ""), color: Theme.accent, highlight: true)
                            pipelineArrow()
                            pipelineStep(icon: "checklist.checked", label: NSLocalizedString("char.pipeline.review", comment: ""), color: Theme.orange)
                            pipelineArrow()
                            pipelineStep(icon: "checkmark.seal.fill", label: NSLocalizedString("char.pipeline.qa", comment: ""), color: Theme.green)
                            pipelineArrow()
                            pipelineStep(icon: "doc.text.fill", label: NSLocalizedString("char.pipeline.report", comment: ""), color: Theme.purple)
                            Text("·").font(Theme.mono(10)).foregroundColor(Theme.textDim).padding(.horizontal, 4)
                            pipelineStep(icon: "server.rack", label: NSLocalizedString("char.pipeline.sre", comment: ""), color: Theme.red, isLast: true)
                        }
                    }
                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Image(systemName: "forward.fill").font(.system(size: 7)).foregroundColor(Theme.green)
                            Text(NSLocalizedString("char.pipeline.skip", comment: "")).font(Theme.mono(7)).foregroundColor(Theme.textDim)
                        }
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 7)).foregroundColor(Theme.yellow)
                            Text(NSLocalizedString("char.pipeline.extra.tokens", comment: "")).font(Theme.mono(7, weight: .medium)).foregroundColor(Theme.yellow)
                        }
                    }
                }
                .padding(.horizontal, 18).padding(.bottom, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 고용 중
                    if !filteredHired.isEmpty {
                        sectionHeader(NSLocalizedString("char.section.hired", comment: ""), count: filteredHired.count, color: Theme.green, icon: "person.fill.checkmark")
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(filteredHired) { char in
                                CharacterCard(character: char, isHired: true, editingId: $editingId, editName: $editName)
                            }
                        }
                    }

                    if !filteredHired.isEmpty && !filteredAvailable.isEmpty {
                        HStack(spacing: 8) {
                            Rectangle().fill(Theme.border).frame(height: 1)
                            Text("AVAILABLE").font(Theme.mono(7, weight: .bold)).foregroundColor(Theme.textDim).tracking(1.5)
                            Rectangle().fill(Theme.border).frame(height: 1)
                        }.padding(.vertical, 6)
                    }

                    // 대기 중 (잠금 해제된 것만)
                    if !filteredAvailable.isEmpty {
                        sectionHeader(NSLocalizedString("char.section.available", comment: ""), count: filteredAvailable.count, color: Theme.textSecondary, icon: "person.fill.questionmark")
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(filteredAvailable) { char in
                                CharacterCard(character: char, isHired: false, editingId: $editingId, editName: $editName)
                            }
                        }
                    }

                    // 잠금 캐릭터
                    if !filteredLocked.isEmpty {
                        if !filteredHired.isEmpty || !filteredAvailable.isEmpty {
                            HStack(spacing: 8) {
                                Rectangle().fill(Theme.yellow.opacity(0.2)).frame(height: 1)
                                HStack(spacing: 4) {
                                    Image(systemName: "lock.fill").font(.system(size: Theme.iconSize(7))).foregroundColor(Theme.yellow.opacity(0.5))
                                    Text("LOCKED").font(Theme.mono(7, weight: .bold)).foregroundColor(Theme.yellow.opacity(0.5)).tracking(1.5)
                                }
                                Rectangle().fill(Theme.yellow.opacity(0.2)).frame(height: 1)
                            }.padding(.vertical, 6)
                        }

                        sectionHeader(NSLocalizedString("char.section.locked", comment: ""), count: filteredLocked.count, color: Theme.yellow.opacity(0.6), icon: "lock.fill")
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(filteredLocked) { char in
                                LockedCharacterCard(character: char)
                            }
                        }
                    }
                }
                .padding(.horizontal, 18).padding(.vertical, 16)
            }
        }
        .background(Theme.bg)
        .frame(minWidth: 920, minHeight: 720)
    }

    private func speciesChip(species: WorkerCharacter.Species?, emoji: String, count: Int) -> some View {
        let active = selectedSpecies == species
        return Button(action: { withAnimation(.easeInOut(duration: 0.15)) { selectedSpecies = species } }) {
            HStack(spacing: 3) {
                Text(emoji)
                    .font(species == nil ? Theme.mono(8, weight: active ? .bold : .medium) : .system(size: 13))
                Text("\(count)")
                    .font(Theme.mono(8, weight: .bold))
                    .foregroundColor(active ? Theme.accent : Theme.textDim.opacity(0.6))
            }
            .padding(.horizontal, 7).padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(active ? Theme.accent.opacity(0.12) : Theme.bgCard.opacity(0.5))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(active ? Theme.accent.opacity(0.4) : Theme.border.opacity(0.15), lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
        .help(species?.localizedName ?? NSLocalizedString("status.all", comment: ""))
    }

    private func speciesFilterEmoji(_ sp: WorkerCharacter.Species) -> String {
        switch sp {
        case .human: return "👤"; case .cat: return "🐱"; case .dog: return "🐶"
        case .rabbit: return "🐰"; case .bear: return "🐻"; case .penguin: return "🐧"
        case .fox: return "🦊"; case .robot: return "🤖"; case .claude: return "✨"
        case .alien: return "👽"; case .ghost: return "👻"; case .dragon: return "🐉"
        case .chicken: return "🐔"; case .owl: return "🦉"; case .frog: return "🐸"
        case .panda: return "🐼"; case .unicorn: return "🦄"; case .skeleton: return "💀"
        }
    }

    private func sortedCharacters(_ characters: [WorkerCharacter]) -> [WorkerCharacter] {
        characters.sorted { lhs, rhs in
            let lhsPriority = characterSortPriority(lhs)
            let rhsPriority = characterSortPriority(rhs)
            if lhsPriority != rhsPriority { return lhsPriority < rhsPriority }

            let nameOrder = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
            if nameOrder != .orderedSame {
                return nameOrder == .orderedAscending
            }
            return lhs.id < rhs.id
        }
    }

    private func characterSortPriority(_ character: WorkerCharacter) -> Int {
        if character.isFleaMarketHiddenCharacter { return 0 }
        if character.isPluginCharacter { return 1 }
        return 2
    }

    private func sectionHeader(_ title: String, count: Int, color: Color, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(Theme.monoSmall).foregroundColor(color)
            Text(title.uppercased()).font(Theme.mono(9, weight: .bold)).foregroundColor(color).tracking(1.5)
            Text("\(count)").font(Theme.mono(8, weight: .bold)).foregroundColor(color)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(color.opacity(0.1)).cornerRadius(4)
            Spacer()
        }
    }

    private func staffStatCard(title: String, value: String, subtitle: String, tint: Color, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: Theme.iconSize(9), weight: .semibold))
                    .foregroundColor(tint)
                Text(title)
                    .font(Theme.mono(8, weight: .bold))
                    .foregroundColor(Theme.textSecondary)
            }
            Text(value)
                .font(Theme.mono(11, weight: .heavy))
                .foregroundColor(Theme.textPrimary)
            Text(subtitle)
                .font(Theme.mono(7))
                .foregroundColor(Theme.textDim)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Theme.bgSurface.opacity(0.42))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(tint.opacity(0.18), lineWidth: 0.8)
                )
        )
    }

    private func statBadge(_ value: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 8, weight: .semibold)).foregroundColor(tint)
            Text(value).font(Theme.mono(9, weight: .bold)).foregroundColor(Theme.textPrimary)
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 6).fill(Theme.bgSurface.opacity(0.6)))
    }

    private func pipelineStep(icon: String, label: String, color: Color, highlight: Bool = false, isFirst: Bool = false, isLast: Bool = false) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: Theme.iconSize(10), weight: .bold))
                .foregroundColor(color)
                .frame(width: 28, height: 28)
                .background(
                    Circle().fill(color.opacity(highlight ? 0.2 : 0.1))
                        .overlay(Circle().stroke(color.opacity(highlight ? 0.5 : 0.2), lineWidth: highlight ? 1.5 : 0.5))
                )
            Text(label)
                .font(Theme.mono(7, weight: highlight ? .bold : .medium))
                .foregroundColor(highlight ? color : Theme.textSecondary)
        }
    }

    private func pipelineArrow() -> some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 7, weight: .bold))
            .foregroundColor(Theme.textDim.opacity(0.4))
            .padding(.horizontal, 3)
    }
}

// MARK: - Character Card

struct CharacterCard: View {
    let character: WorkerCharacter
    let isHired: Bool
    @Binding var editingId: String?
    @Binding var editName: String
    @ObservedObject var registry = CharacterRegistry.shared
    @State private var isHovered = false

    private var shirtColor: Color { Color(hex: character.shirtColor) }
    private var roleTint: Color {
        switch character.jobRole {
        case .developer: return Theme.accent
        case .qa: return Theme.green
        case .reporter: return Theme.purple
        case .boss: return Theme.orange
        case .planner: return Theme.cyan
        case .reviewer: return Theme.yellow
        case .designer: return Theme.pink
        case .sre: return Theme.red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Top: Avatar + Name + Role
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(shirtColor.opacity(isHired ? 0.12 : 0.06))
                    Canvas { context, size in
                        drawCharacter(context: context, size: size)
                    }
                    .frame(width: 40, height: 50)
                }
                .frame(width: 52, height: 60)

                VStack(alignment: .leading, spacing: 3) {
                    if editingId == character.id {
                        TextField(NSLocalizedString("character.name.placeholder", comment: ""), text: $editName)
                            .textFieldStyle(.plain)
                            .font(Theme.mono(11, weight: .bold))
                            .foregroundColor(shirtColor)
                            .onSubmit {
                                if !editName.trimmingCharacters(in: .whitespaces).isEmpty {
                                    registry.rename(character.id, to: editName)
                                }
                                editingId = nil
                            }
                    } else {
                        HStack(spacing: 4) {
                            Text(character.name)
                                .font(Theme.mono(12, weight: .black))
                                .foregroundColor(shirtColor)
                                .lineLimit(1)

                            if character.isFleaMarketHiddenCharacter {
                                Text("히든")
                                    .font(Theme.mono(7, weight: .bold))
                                    .foregroundColor(Theme.yellow)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                                    .background(Theme.yellow.opacity(0.12))
                                    .cornerRadius(4)
                            }
                        }
                        .onTapGesture(count: 2) {
                            editName = character.name
                            editingId = character.id
                        }
                    }

                    Text(character.localizedArchetype)
                        .font(Theme.mono(7)).foregroundColor(Theme.textDim).lineLimit(2).fixedSize(horizontal: false, vertical: true)

                    // Role badge - full width with no truncation
                    Menu {
                        ForEach(WorkerJob.allCases) { role in
                            Button { registry.setJobRole(role, for: character.id) } label: {
                                Label(role.displayName, systemImage: role.icon)
                            }
                        }
                    } label: {
                        Label(character.jobRole.displayName, systemImage: character.jobRole.icon)
                            .font(Theme.mono(8, weight: .bold))
                            .foregroundColor(roleTint)
                            .padding(.horizontal, 6).padding(.vertical, 3)
                            .background(roleTint.opacity(0.1)).cornerRadius(5)
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }

                Spacer(minLength: 0)

                // Status indicators (compact, right-aligned)
                VStack(alignment: .trailing, spacing: 4) {
                    if character.isOnVacation {
                        Text(NSLocalizedString("char.vacation", comment: "")).font(Theme.mono(7, weight: .bold)).foregroundColor(Theme.orange)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Theme.orange.opacity(0.1)).cornerRadius(4)
                    }
                    if character.jobRole.usesExtraTokensWarning {
                        Image(systemName: "bolt.fill").font(.system(size: 8)).foregroundColor(Theme.yellow.opacity(0.6))
                    }
                }
            }

            // Actions (compact)
            if isHired {
                HStack(spacing: 6) {
                    Button(action: { registry.setVacation(!character.isOnVacation, for: character.id) }) {
                        Text(character.isOnVacation ? NSLocalizedString("char.return.to.work", comment: "") : NSLocalizedString("char.vacation", comment: ""))
                            .font(Theme.mono(9, weight: .bold))
                            .foregroundColor(character.isOnVacation ? Theme.green : Theme.orange)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 7)
                            .background(
                                RoundedRectangle(cornerRadius: 7)
                                    .fill((character.isOnVacation ? Theme.green : Theme.orange).opacity(0.08))
                            )
                    }.buttonStyle(.plain)

                    Button(action: { registry.fire(character.id) }) {
                        Text(NSLocalizedString("char.fire", comment: ""))
                            .font(Theme.mono(9, weight: .bold))
                            .foregroundColor(Theme.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 7)
                            .background(
                                RoundedRectangle(cornerRadius: 7)
                                    .fill(Theme.red.opacity(0.08))
                            )
                    }.buttonStyle(.plain)
                }
            } else {
                Button(action: { registry.hire(character.id) }) {
                    Text(NSLocalizedString("char.hire", comment: ""))
                        .font(Theme.mono(9, weight: .bold))
                        .foregroundColor(Theme.green)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(RoundedRectangle(cornerRadius: 7).fill(Theme.green.opacity(0.08)))
                }
                .buttonStyle(.plain)
                .disabled(!registry.canHire(character.id))
                .opacity(registry.canHire(character.id) ? 1 : 0.4)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10).fill(Theme.bgCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isHired ? shirtColor.opacity(isHovered ? 0.35 : 0.15) : Theme.border.opacity(isHovered ? 0.3 : 0.1), lineWidth: isHired ? 1 : 0.5)
                )
        )
        .opacity(isHired ? 1 : 0.7)
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeOut(duration: 0.12), value: isHovered)
        .onHover { isHovered = $0 }
    }

    private func badgeText(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(Theme.mono(7, weight: .bold))
            .foregroundColor(tint)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(tint.opacity(0.1))
            .cornerRadius(5)
    }

    // MARK: - Draw Character

    private func drawCharacter(context: GraphicsContext, size: CGSize) {
        let s: CGFloat = 2.5
        let x: CGFloat = (size.width - 16 * s) / 2
        let y: CGFloat = (size.height - 22 * s) / 2 + 2

        let fur = Color(hex: character.skinTone)
        let hair = Color(hex: character.hairColor)
        let shirt = Color(hex: character.shirtColor)
        let pants = Color(hex: character.pantsColor)

        func px(_ px: CGFloat, _ py: CGFloat, _ w: CGFloat, _ h: CGFloat, _ c: Color) {
            context.fill(Path(CGRect(x: x + px * s, y: y + py * s, width: w * s, height: h * s)), with: .color(c))
        }

        switch character.species {
        case .cat:
            // 귀 (삼각형)
            px(3, -2, 3, 3, fur); px(10, -2, 3, 3, fur)
            px(4, -1, 1, 1, Color(hex: "f0a0a0")); px(11, -1, 1, 1, Color(hex: "f0a0a0")) // 귀 안쪽
            // 머리
            px(4, 1, 8, 6, fur)
            // 눈 (고양이 눈 - 세로 동공)
            px(5, 3, 2, 2, Color(hex: "60c060")); px(6, 3, 1, 2, Color(hex: "1a1a1a"))
            px(9, 3, 2, 2, Color(hex: "60c060")); px(10, 3, 1, 2, Color(hex: "1a1a1a"))
            // 코 + 입
            px(7, 5, 2, 1, Color(hex: "f08080"))
            // 수염
            px(2, 5, 2, 1, Color(hex: "ddd")); px(12, 5, 2, 1, Color(hex: "ddd"))
            // 몸
            px(4, 7, 8, 7, shirt)
            // 앞발
            px(3, 12, 3, 2, fur); px(10, 12, 3, 2, fur)
            // 뒷발
            px(4, 14, 3, 3, fur); px(9, 14, 3, 3, fur)
            // 꼬리
            px(13, 10, 2, 2, fur); px(14, 8, 2, 3, fur)

        case .dog:
            // 귀 (늘어진)
            px(2, 1, 3, 5, hair); px(11, 1, 3, 5, hair)
            // 머리
            px(4, 0, 8, 7, fur)
            // 눈
            px(5, 3, 2, 2, .white); px(6, 4, 1, 1, Color(hex: "333"))
            px(9, 3, 2, 2, .white); px(10, 4, 1, 1, Color(hex: "333"))
            // 코
            px(7, 5, 2, 1, Color(hex: "333"))
            // 혀
            px(7, 6, 2, 1, Color(hex: "f06060"))
            // 몸
            px(4, 7, 8, 7, shirt)
            px(3, 12, 3, 2, fur); px(10, 12, 3, 2, fur)
            px(4, 14, 3, 3, fur); px(9, 14, 3, 3, fur)
            // 꼬리 (위로)
            px(13, 5, 2, 2, fur); px(14, 3, 2, 3, fur)

        case .rabbit:
            // 긴 귀
            px(5, -5, 2, 6, fur); px(9, -5, 2, 6, fur)
            px(5, -4, 1, 4, Color(hex: "f0a0a0")); px(10, -4, 1, 4, Color(hex: "f0a0a0"))
            // 머리 (둥근)
            px(4, 1, 8, 6, fur)
            // 눈 (크고 둥근)
            px(5, 3, 2, 2, Color(hex: "d04060")); px(6, 3, 1, 1, Color(hex: "1a1a1a"))
            px(9, 3, 2, 2, Color(hex: "d04060")); px(10, 3, 1, 1, Color(hex: "1a1a1a"))
            // 코
            px(7, 5, 2, 1, Color(hex: "f0a0a0"))
            // 몸
            px(4, 7, 8, 7, shirt)
            px(3, 12, 3, 2, fur); px(10, 12, 3, 2, fur)
            px(5, 14, 3, 3, fur); px(8, 14, 3, 3, fur)
            // 솜뭉치 꼬리
            px(13, 11, 3, 3, .white)

        case .bear:
            // 둥근 귀
            px(3, -1, 3, 3, fur); px(10, -1, 3, 3, fur)
            px(4, 0, 1, 1, Color(hex: "c09060")); px(11, 0, 1, 1, Color(hex: "c09060"))
            // 머리
            px(4, 1, 8, 7, fur)
            // 주둥이
            px(6, 5, 4, 3, Color(hex: "d0b090"))
            // 눈
            px(5, 3, 2, 2, Color(hex: "1a1a1a"))
            px(9, 3, 2, 2, Color(hex: "1a1a1a"))
            // 코
            px(7, 5, 2, 1, Color(hex: "333"))
            // 몸 (통통)
            px(3, 8, 10, 7, shirt)
            px(2, 10, 3, 3, fur); px(11, 10, 3, 3, fur)
            px(4, 15, 4, 3, fur); px(8, 15, 4, 3, fur)

        case .penguin:
            // 머리 (검정)
            px(4, 0, 8, 5, Color(hex: "2a2a3a"))
            // 흰 얼굴
            px(5, 2, 6, 4, .white)
            // 눈
            px(6, 3, 1, 1, Color(hex: "1a1a1a")); px(9, 3, 1, 1, Color(hex: "1a1a1a"))
            // 부리
            px(7, 5, 2, 1, Theme.yellow)
            // 몸 (검정 + 흰 배)
            px(3, 6, 10, 8, Color(hex: "2a2a3a"))
            px(5, 7, 6, 6, .white)
            // 날개
            px(2, 8, 2, 5, Color(hex: "2a2a3a")); px(12, 8, 2, 5, Color(hex: "2a2a3a"))
            // 발
            px(5, 14, 3, 2, Theme.yellow); px(8, 14, 3, 2, Theme.yellow)

        case .fox:
            // 귀 (뾰족)
            px(3, -2, 3, 4, Color(hex: "e07030")); px(10, -2, 3, 4, Color(hex: "e07030"))
            px(4, -1, 1, 2, .white); px(11, -1, 1, 2, .white)
            // 머리
            px(4, 1, 8, 6, fur)
            // 흰 뺨
            px(4, 4, 3, 3, .white); px(9, 4, 3, 3, .white)
            // 눈 (날카로운)
            px(5, 3, 2, 1, Color(hex: "f0c020")); px(6, 3, 1, 1, Color(hex: "1a1a1a"))
            px(9, 3, 2, 1, Color(hex: "f0c020")); px(10, 3, 1, 1, Color(hex: "1a1a1a"))
            // 코
            px(7, 5, 2, 1, Color(hex: "333"))
            // 몸
            px(4, 7, 8, 7, shirt)
            px(3, 12, 3, 2, fur); px(10, 12, 3, 2, fur)
            px(4, 14, 3, 3, fur); px(9, 14, 3, 3, fur)
            // 큰 꼬리
            px(12, 9, 3, 2, fur); px(13, 7, 3, 4, fur); px(14, 11, 2, 1, .white)

        case .robot:
            // 안테나
            px(7, -3, 2, 3, Color(hex: "8090a0"))
            px(6, -4, 4, 1, Color(hex: "60f0a0"))
            // 머리 (사각)
            px(3, 0, 10, 7, Color(hex: "a0b0c0"))
            px(4, 1, 8, 5, Color(hex: "8090a0"))
            // 눈 (LED)
            px(5, 3, 2, 2, Color(hex: "60f0a0")); px(9, 3, 2, 2, Color(hex: "60f0a0"))
            // 입 (격자)
            px(6, 5, 4, 1, Color(hex: "506070"))
            // 몸
            px(3, 7, 10, 8, shirt)
            // 관절
            px(3, 7, 10, 1, Color(hex: "8090a0"))
            // 팔
            px(1, 9, 2, 5, Color(hex: "8090a0")); px(13, 9, 2, 5, Color(hex: "8090a0"))
            // 다리
            px(4, 15, 3, 3, Color(hex: "708090")); px(9, 15, 3, 3, Color(hex: "708090"))

        case .claude:
            // Claude 마스코트 — 게/외계생물 미니멀 픽셀
            // 넓적 블록 몸통 + 양옆 집게 + 세로눈 2개 + 다리 4개 + 입 없음
            let c = Color(hex: character.shirtColor)
            let eye = Color(hex: "2a1810")

            // 몸통 상단 (약간 좁게 시작)
            px(4, 1, 8, 1, c)

            // 몸통 메인 (넓적한 블록)
            px(3, 2, 10, 7, c)

            // 양옆 집게팔 (수평 돌출, 게 느낌)
            px(1, 3, 2, 2, c)
            px(0, 4, 1, 1, c)
            px(13, 3, 2, 2, c)
            px(15, 4, 1, 1, c)

            // 눈 (세로 직사각형, 넓은 간격, 무표정)
            px(5, 4, 1, 2, eye)
            px(10, 4, 1, 2, eye)

            // 다리 4개 (짧고 균등 간격)
            px(4, 9, 1, 3, c)
            px(6, 9, 1, 3, c)
            px(9, 9, 1, 3, c)
            px(11, 9, 1, 3, c)

        case .alien:
            // 큰 머리 + 큰 눈 + 가는 몸
            px(3, -1, 10, 2, fur) // 이마
            px(2, 1, 12, 6, fur)  // 큰 머리
            px(4, 3, 3, 3, Color(hex: "101010")) // 왼쪽 큰 눈
            px(9, 3, 3, 3, Color(hex: "101010"))
            px(5, 4, 1, 1, Color(hex: "40ff80")) // 동공
            px(10, 4, 1, 1, Color(hex: "40ff80"))
            px(5, 7, 6, 5, shirt) // 가느다란 몸
            px(3, 8, 2, 4, shirt); px(11, 8, 2, 4, shirt) // 팔
            px(5, 12, 2, 4, fur); px(9, 12, 2, 4, fur) // 다리
            // 안테나
            px(7, -3, 2, 2, Color(hex: "40ff80")); px(8, -4, 1, 1, Color(hex: "80ffa0"))

        case .ghost:
            // 둥근 머리 + 물결 아래
            px(4, 0, 8, 3, fur)
            px(3, 3, 10, 6, fur)
            px(5, 4, 2, 2, Color(hex: "303040")) // 큰 눈
            px(9, 4, 2, 2, Color(hex: "303040"))
            px(6, 7, 4, 1, Color(hex: "404050")) // 입
            // 물결치는 아랫부분
            px(3, 9, 3, 3, fur); px(6, 10, 4, 2, fur); px(10, 9, 3, 3, fur)
            px(4, 12, 2, 1, fur); px(8, 12, 2, 1, fur); px(12, 12, 1, 1, fur)

        case .dragon:
            // 뿔 + 비늘 몸 + 꼬리 + 작은 날개
            px(4, -2, 2, 2, Color(hex: "f0c030")) // 왼쪽 뿔
            px(10, -2, 2, 2, Color(hex: "f0c030")) // 오른쪽 뿔
            px(4, 0, 8, 6, fur) // 머리
            px(5, 2, 2, 2, Color(hex: "ff4020")) // 눈
            px(9, 2, 2, 2, Color(hex: "ff4020"))
            px(6, 5, 4, 1, Color(hex: "f06030")) // 입
            px(3, 6, 10, 6, shirt) // 몸
            px(0, 5, 3, 5, shirt.opacity(0.6)) // 왼 날개
            px(13, 5, 3, 5, shirt.opacity(0.6)) // 오른 날개
            px(4, 12, 3, 4, fur); px(9, 12, 3, 4, fur) // 다리
            px(13, 10, 3, 2, shirt); px(14, 12, 2, 1, shirt) // 꼬리

        case .chicken:
            // 볏 + 둥근 몸 + 부리 + 다리
            px(6, -2, 4, 2, Color(hex: "e03020")) // 볏
            px(5, 0, 6, 5, fur) // 머리
            px(6, 2, 2, 2, Color(hex: "101010")) // 눈
            px(11, 3, 2, 1, Color(hex: "f0a020")) // 부리
            px(6, 5, 1, 2, Color(hex: "f03020")) // 턱수염
            px(4, 5, 8, 7, shirt) // 둥근 몸
            px(2, 6, 2, 4, shirt.opacity(0.7)) // 왼 날개
            px(12, 6, 2, 4, shirt.opacity(0.7))
            px(5, 12, 2, 4, Color(hex: "f0a020")) // 왼 다리
            px(9, 12, 2, 4, Color(hex: "f0a020"))

        case .owl:
            // 큰 둥근 눈 + 귀 깃 + 날개
            px(3, -1, 3, 3, hair) // 왼 귀깃
            px(10, -1, 3, 3, hair)
            px(4, 1, 8, 6, fur) // 머리
            px(4, 3, 3, 3, Color(hex: "f0e0a0")) // 눈 테두리 왼
            px(9, 3, 3, 3, Color(hex: "f0e0a0"))
            px(5, 4, 2, 2, Color(hex: "202020")) // 동공
            px(10, 4, 2, 2, Color(hex: "202020"))
            px(7, 6, 2, 1, Color(hex: "d09030")) // 부리
            px(3, 7, 10, 6, shirt)
            px(1, 8, 2, 4, hair); px(13, 8, 2, 4, hair) // 날개
            px(5, 13, 2, 3, fur); px(9, 13, 2, 3, fur)

        case .frog:
            // 튀어나온 눈 + 넓은 입 + 초록
            px(3, 0, 4, 3, fur); px(9, 0, 4, 3, fur) // 튀어나온 눈
            px(4, 1, 2, 2, Color(hex: "101010")); px(10, 1, 2, 2, Color(hex: "101010"))
            px(3, 3, 10, 5, fur) // 머리
            px(4, 6, 8, 1, Color(hex: "f06060")) // 넓은 입
            px(3, 8, 10, 5, shirt)
            px(1, 9, 2, 4, shirt); px(13, 9, 2, 4, shirt)
            px(4, 13, 3, 3, fur); px(9, 13, 3, 3, fur)

        case .panda:
            // 둥근 귀 + 눈 패치
            px(2, -1, 4, 3, Color(hex: "1a1a1a")) // 왼 귀
            px(10, -1, 4, 3, Color(hex: "1a1a1a"))
            px(4, 1, 8, 6, fur) // 흰 머리
            px(4, 3, 3, 3, Color(hex: "1a1a1a")) // 눈 패치 왼
            px(9, 3, 3, 3, Color(hex: "1a1a1a"))
            px(5, 4, 1, 1, .white); px(10, 4, 1, 1, .white) // 동공
            px(7, 5, 2, 1, Color(hex: "1a1a1a")) // 코
            px(3, 7, 10, 6, shirt)
            px(1, 8, 2, 5, Color(hex: "1a1a1a")); px(13, 8, 2, 5, Color(hex: "1a1a1a"))
            px(4, 13, 3, 3, Color(hex: "1a1a1a")); px(9, 13, 3, 3, Color(hex: "1a1a1a"))

        case .unicorn:
            // 뿔 + 갈기 + 말 형태
            px(7, -4, 2, 1, Color(hex: "f0d040")) // 뿔 끝
            px(7, -3, 2, 1, Color(hex: "f0c040"))
            px(7, -2, 2, 2, Color(hex: "f0b040"))
            px(4, 0, 8, 6, fur) // 머리
            px(2, 0, 2, 5, hair) // 갈기
            px(5, 2, 2, 2, .white); px(6, 3, 1, 1, Color(hex: "c060c0")) // 눈
            px(9, 2, 2, 2, .white); px(10, 3, 1, 1, Color(hex: "c060c0"))
            px(3, 6, 10, 7, shirt)
            px(1, 7, 2, 4, shirt); px(13, 7, 2, 4, shirt)
            px(4, 13, 3, 3, fur); px(9, 13, 3, 3, fur)

        case .skeleton:
            // 두개골 + 갈비뼈 + 뼈 팔다리
            let bone = Color(hex: "f0f0e0")
            px(4, 0, 8, 6, bone) // 두개골
            px(5, 2, 2, 2, Color(hex: "1a1a1a")) // 눈구멍
            px(9, 2, 2, 2, Color(hex: "1a1a1a"))
            px(6, 4, 1, 1, Color(hex: "1a1a1a")) // 코
            px(5, 5, 6, 1, Color(hex: "1a1a1a")) // 이빨줄
            px(5, 5, 1, 1, bone); px(7, 5, 1, 1, bone); px(9, 5, 1, 1, bone) // 이빨
            px(5, 6, 6, 6, Color(hex: "404040")) // 몸 (어두운 옷)
            px(6, 7, 4, 1, bone); px(6, 9, 4, 1, bone) // 갈비뼈
            px(3, 7, 2, 5, Color(hex: "404040")); px(11, 7, 2, 5, Color(hex: "404040"))
            px(5, 12, 2, 4, bone); px(9, 12, 2, 4, bone) // 다리뼈

        case .human:
            // 기존 사람 그리기
            // Hat
            switch character.hatType {
            case .beanie: px(3, -2, 10, 3, Color(hex: "4040a0"))
            case .cap: px(2, -1, 12, 2, Color(hex: "c04040")); px(1, 0, 4, 1, Color(hex: "a03030"))
            case .hardhat: px(3, -2, 10, 3, Theme.yellow); px(2, -1, 12, 1, Theme.yellow)
            case .wizard: px(5, -5, 6, 2, Color(hex: "6040a0")); px(4, -3, 8, 2, Color(hex: "6040a0")); px(3, -1, 10, 2, Color(hex: "6040a0"))
            case .crown: px(4, -2, 8, 1, Theme.yellow); px(4, -3, 2, 1, Theme.yellow); px(7, -3, 2, 1, Theme.yellow); px(10, -3, 2, 1, Theme.yellow)
            case .headphones: px(2, 2, 2, 4, Color(hex: "404040")); px(12, 2, 2, 4, Color(hex: "404040")); px(3, 0, 10, 1, Color(hex: "505050"))
            case .beret: px(3, -1, 11, 2, Color(hex: "c04040")); px(3, -2, 8, 1, Color(hex: "c04040"))
            case .none: break
            }
            px(4, 0, 8, 3, hair); px(3, 1, 1, 2, hair); px(12, 1, 1, 2, hair)
            px(4, 3, 8, 5, fur)
            px(5, 4, 2, 2, .white); px(6, 5, 1, 1, Color(hex: "333"))
            px(9, 4, 2, 2, .white); px(10, 5, 1, 1, Color(hex: "333"))

            switch character.accessory {
            case .glasses: px(4, 4, 3, 1, Color(hex: "4060a0")); px(7, 4, 1, 1, Color(hex: "4060a0")); px(8, 4, 3, 1, Color(hex: "4060a0"))
            case .sunglasses: px(4, 4, 3, 2, Color(hex: "1a1a1a")); px(7, 4, 1, 1, Color(hex: "1a1a1a")); px(8, 4, 3, 2, Color(hex: "1a1a1a"))
            case .scarf: px(3, 7, 10, 2, Color(hex: "c04040"))
            case .mask: px(4, 5, 8, 3, Color(hex: "2a2a2a"))
            case .earring: px(13, 4, 1, 2, Theme.yellow)
            case .none: break
            }

            px(3, 8, 10, 6, shirt)
            px(1, 9, 2, 5, shirt); px(13, 9, 2, 5, shirt)
            px(0, 13, 2, 2, fur); px(14, 13, 2, 2, fur)
            px(4, 14, 4, 4, pants); px(8, 14, 4, 4, pants)
            px(4, 18, 3, 2, pants); px(9, 18, 3, 2, pants)
            px(3, 19, 4, 2, Color(hex: "4a5060")); px(9, 19, 4, 2, Color(hex: "4a5060"))
        } // end switch species
    }

    private func hatEmoji(_ hat: WorkerCharacter.HatType) -> String {
        switch hat {
        case .beanie: return "🧢"
        case .cap: return "🧢"
        case .hardhat: return "⛑"
        case .wizard: return "🧙"
        case .crown: return "👑"
        case .headphones: return "🎧"
        case .beret: return "🎨"
        case .none: return ""
        }
    }

    private func accessoryEmoji(_ acc: WorkerCharacter.Accessory) -> String {
        switch acc {
        case .glasses: return "👓"
        case .sunglasses: return "🕶"
        case .scarf: return "🧣"
        case .mask: return "😷"
        case .earring: return "💎"
        case .none: return ""
        }
    }

    private func speciesEmoji(_ species: WorkerCharacter.Species) -> String {
        switch species {
        case .human: return "🧑"
        case .cat: return "🐱"
        case .dog: return "🐶"
        case .rabbit: return "🐰"
        case .bear: return "🐻"
        case .penguin: return "🐧"
        case .fox: return "🦊"
        case .robot: return "🤖"
        case .claude: return "✦"
        case .alien: return "👽"
        case .ghost: return "👻"
        case .dragon: return "🐉"
        case .chicken: return "🐔"
        case .owl: return "🦉"
        case .frog: return "🐸"
        case .panda: return "🐼"
        case .unicorn: return "🦄"
        case .skeleton: return "💀"
        }
    }
}

// MARK: - Locked Character Card (블러 + 잠금)

struct LockedCharacterCard: View {
    let character: WorkerCharacter
    @ObservedObject var registry = CharacterRegistry.shared
    @State private var showAlert = false
    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 8) {
            // 블러 처리된 캐릭터 실루엣
            ZStack {
                Canvas { context, size in
                    let s: CGFloat = 2.5
                    let x: CGFloat = (size.width - 16 * s) / 2
                    let y: CGFloat = (size.height - 22 * s) / 2 + 2
                    let c = Color.gray.opacity(0.4)
                    func px(_ px: CGFloat, _ py: CGFloat, _ w: CGFloat, _ h: CGFloat) {
                        context.fill(Path(CGRect(x: x + px * s, y: y + py * s, width: w * s, height: h * s)), with: .color(c))
                    }
                    px(5, 0, 6, 6); px(4, 6, 8, 8)
                    px(3, 10, 3, 4); px(10, 10, 3, 4)
                    px(5, 14, 3, 4); px(8, 14, 3, 4)
                }
                .frame(width: 48, height: 64)
                .blur(radius: 4)
                .opacity(0.35)

                // 자물쇠
                ZStack {
                    Circle().fill(Theme.bgCard.opacity(0.8)).frame(width: 30, height: 30)
                    Circle().stroke(Theme.yellow.opacity(0.3), lineWidth: 1).frame(width: 30, height: 30)
                    Image(systemName: "lock.fill").font(.system(size: Theme.iconSize(12))).foregroundColor(Theme.yellow.opacity(0.6))
                }
            }
            .frame(width: 52, height: 68)

            Text(character.isFleaMarketHiddenCharacter ? "히든" : "???")
                .font(Theme.mono(10, weight: .bold))
                .foregroundColor(Theme.textDim.opacity(0.4))
            Text(character.species.localizedName).font(Theme.mono(7)).foregroundColor(Theme.textDim.opacity(0.3))

            Spacer(minLength: 0).frame(height: 12)

            // 필요 업적 힌트
            VStack(spacing: 2) {
                Image(systemName: "trophy.fill").font(.system(size: Theme.iconSize(8))).foregroundColor(Theme.yellow.opacity(0.35))
                if let name = registry.requiredAchievementName(character) {
                    Text(name).font(Theme.mono(6, weight: .medium)).foregroundColor(Theme.yellow.opacity(0.3)).lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity).padding(.vertical, 4)
        }
        .padding(10)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(Theme.bgSurface.opacity(0.15))
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Theme.yellow.opacity(isHovered ? 0.2 : 0.08), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }
        )
        .frame(maxWidth: .infinity, minHeight: 180, maxHeight: 180, alignment: .top)
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeOut(duration: 0.12), value: isHovered)
        .onHover { isHovered = $0 }
        .onTapGesture { showAlert = true }
        .alert(NSLocalizedString("character.unlock.required", comment: ""), isPresented: $showAlert) {
            Button(NSLocalizedString("confirm", comment: ""), role: .cancel) {}
        } message: {
            if let name = registry.requiredAchievementName(character) {
                Text(String(format: NSLocalizedString("character.unlock.achievement", comment: ""), name))
            } else {
                Text(NSLocalizedString("character.unlock.generic", comment: ""))
            }
        }
    }
}

// MARK: - FlowLayout (wrapping HStack)

struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var height: CGFloat = 0
        for (i, row) in rows.enumerated() {
            let rowHeight = row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
            height += rowHeight + (i > 0 ? spacing : 0)
        }
        return CGSize(width: proposal.width ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            let rowHeight = row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
            var x = bounds.minX
            for view in row {
                let size = view.sizeThatFits(.unspecified)
                view.place(at: CGPoint(x: x, y: y + (rowHeight - size.height) / 2), proposal: .unspecified)
                x += size.width + spacing
            }
            y += rowHeight + spacing
        }
    }

    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [[LayoutSubviews.Element]] {
        let maxWidth = proposal.width ?? .infinity
        var rows: [[LayoutSubviews.Element]] = [[]]
        var currentWidth: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if currentWidth + size.width > maxWidth && !rows[rows.count - 1].isEmpty {
                rows.append([])
                currentWidth = 0
            }
            rows[rows.count - 1].append(view)
            currentWidth += size.width + spacing
        }
        return rows
    }
}
