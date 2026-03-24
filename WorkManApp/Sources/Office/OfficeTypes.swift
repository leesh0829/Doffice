import SwiftUI

// ═══════════════════════════════════════════════════════
// MARK: - Office Types (공유 타입 정의)
// ═══════════════════════════════════════════════════════

// MARK: - Tile Coordinate

struct TileCoord: Hashable, Codable, Equatable {
    let col: Int
    let row: Int

    func distance(to other: TileCoord) -> Int {
        abs(col - other.col) + abs(row - other.row)
    }

    static func + (lhs: TileCoord, rhs: TileCoord) -> TileCoord {
        TileCoord(col: lhs.col + rhs.col, row: lhs.row + rhs.row)
    }
}

// MARK: - Direction (4방향)

enum Direction: Int, Codable, CaseIterable {
    case down = 0, left = 1, right = 2, up = 3

    var delta: TileCoord {
        switch self {
        case .up: return TileCoord(col: 0, row: -1)
        case .down: return TileCoord(col: 0, row: 1)
        case .left: return TileCoord(col: -1, row: 0)
        case .right: return TileCoord(col: 1, row: 0)
        }
    }
}

// MARK: - Sprite Data (픽셀 아트 핵심)

/// 2D 배열: 각 셀은 hex 색상 문자열. "" = 투명
typealias SpriteData = [[String]]

/// 캐릭터 스프라이트 세트: 방향별 프레임 배열
struct CharacterSpriteSet {
    /// walk[direction] = [frame0, frame1, frame2, frame3]
    var walk: [Direction: [SpriteData]]
    /// type[direction] = [frame0, frame1]
    var typing: [Direction: [SpriteData]]
    /// idle: 정면 1프레임
    var idle: [Direction: SpriteData]
}

// MARK: - Tile Type

enum TileType: Int, Codable {
    case void = 0
    case wall = 1
    case floor1 = 2       // 기본 회색 타일
    case floor2 = 3       // 밝은 타일 (팬트리)
    case floor3 = 4       // 나무 바닥
    case carpet = 5       // 카펫 (미팅룸)
    case door = 6

    var isWalkable: Bool {
        switch self {
        case .void, .wall: return false
        default: return true
        }
    }
}

// MARK: - Office Preset

enum OfficePreset: String, Codable, CaseIterable, Identifiable {
    case cozy
    case collaboration
    case focus

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .cozy: return "Cozy"
        case .collaboration: return "Collab"
        case .focus: return "Focus"
        }
    }

    var subtitle: String {
        switch self {
        case .cozy: return "라운지와 장식이 살아있는 기본 사무실"
        case .collaboration: return "회의와 화이트보드 중심의 협업형 배치"
        case .focus: return "집중 좌석과 조용한 흐름에 맞춘 배치"
        }
    }

    var icon: String {
        switch self {
        case .cozy: return "house.fill"
        case .collaboration: return "person.3.fill"
        case .focus: return "scope"
        }
    }
}

// MARK: - Office Zone

enum OfficeZone: String, Codable, CaseIterable {
    case mainOffice = "OFFICE"
    case pantry = "PANTRY"
    case meetingRoom = "MEETING"
    case hallway = "HALL"
}

// MARK: - Furniture

enum FurnitureType: String, Codable, CaseIterable {
    case desk, chair, monitor, bookshelf, plant, coffeeMachine
    case sofa, roundTable, whiteboard, waterCooler, printer
    case trashBin, lamp, rug, pictureFrame, clock
}

struct TileSize: Codable, Hashable {
    let w: Int
    let h: Int
}

struct FurniturePlacement: Identifiable, Codable, Hashable {
    let id: String
    let type: FurnitureType
    var position: TileCoord
    let size: TileSize
    var zone: OfficeZone
    var mirrored: Bool = false

    /// Z-sort용 하단 Y값 (픽셀)
    var zY: CGFloat {
        let flatTypes: Set<FurnitureType> = [.rug]
        let wallMountedTypes: Set<FurnitureType> = [.pictureFrame, .clock, .whiteboard]

        if flatTypes.contains(type) {
            return CGFloat(position.row) * OfficeConstants.tileSize + 1
        }
        if wallMountedTypes.contains(type) {
            return CGFloat(position.row) * OfficeConstants.tileSize + 2
        }
        return CGFloat(position.row + size.h) * OfficeConstants.tileSize
    }

    static func == (lhs: FurniturePlacement, rhs: FurniturePlacement) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - Seat

struct Seat: Identifiable, Codable {
    let id: String
    let position: TileCoord
    let deskId: String
    let facing: Direction
    var assignedTabId: String?
}

// MARK: - Character State

enum OfficeCharacterState: Equatable {
    case sittingIdle
    case typing
    case thinking
    case searching
    case reading
    case celebrating
    case error
    case walkingTo(TileCoord)
    case wandering           // 비활성 시 돌아다니기
    case wanderPause         // 돌아다니다 멈춤
    case onBreak             // 팬트리에서 쉬기
    case seatRest            // 자리에서 쉬기
}

enum OfficeSocialMode: Equatable {
    case greeting
    case chatting
    case brainstorming
    case coffee
    case highFive
}

enum OfficeDestinationPurpose: Equatable {
    case seat
    case thinking
    case searching
    case reading
    case error
    case breakSpot
}

// MARK: - Office Character (런타임)

struct OfficeCharacter {
    var tabId: String? = nil
    var rosterCharacterId: String? = nil
    var displayName: String = ""
    var accentColorHex: String = "5B9CF6"
    var jobRole: WorkerJob = .developer
    var isRosterOnly: Bool = false
    var seatGroupKey: String
    var groupId: String?
    var groupIndex: Int = 0
    var groupSize: Int = 1
    var usesSeatPose: Bool = true
    var pixelX: CGFloat
    var pixelY: CGFloat
    var tileCol: Int
    var tileRow: Int
    var targetTile: TileCoord?
    var path: [TileCoord] = []
    var state: OfficeCharacterState = .sittingIdle
    var dir: Direction = .down
    var frame: Int = 0
    var frameTimer: Double = 0
    var seatId: String?
    var moveProgress: CGFloat = 0
    var isActive: Bool = true
    var activity: ClaudeActivity = .idle
    var destinationPurpose: OfficeDestinationPurpose = .seat
    var stateHoldTimer: Double = 0

    // Wander 행동
    var wanderTimer: Double = 0
    var wanderCount: Int = 0
    var wanderLimit: Int = 3
    var seatTimer: Double = 0
    var socialMode: OfficeSocialMode? = nil
    var socialRole: Int = 0
    var socialTimer: Double = 0
    var socialCooldown: Double = 0
    var socialPartnerKey: String? = nil
    var socialFocusTile: TileCoord? = nil
    var recentBreakTargets: [TileCoord] = []

    var tileCoord: TileCoord { TileCoord(col: tileCol, row: tileRow) }

    /// Z-sort용 Y (하단 기준)
    var zY: CGFloat { pixelY + OfficeConstants.tileSize / 2 }
}

// MARK: - Z-Sortable Drawable

struct ZDrawable {
    let zY: CGFloat
    let draw: (GraphicsContext) -> Void
}

// MARK: - Constants

enum OfficeConstants {
    static let tileSize: CGFloat = 16
    static let walkSpeed: CGFloat = 48           // px/sec
    static let walkFrameDuration: Double = 0.15  // 초당 프레임 전환
    static let typeFrameDuration: Double = 0.3
    static let wanderPauseMin: Double = 2.0
    static let wanderPauseMax: Double = 5.0
    static let wanderMovesMin: Int = 2
    static let wanderMovesMax: Int = 5
    static let seatRestMin: Double = 3.0
    static let seatRestMax: Double = 8.0
    static let relaxedWanderPauseMin: Double = 0.8
    static let relaxedWanderPauseMax: Double = 2.2
    static let relaxedWanderMovesMin: Int = 3
    static let relaxedWanderMovesMax: Int = 7
    static let relaxedSeatRestMin: Double = 1.5
    static let relaxedSeatRestMax: Double = 4.0
    static let socialInteractionMin: Double = 2.5
    static let socialInteractionMax: Double = 5.5
    static let socialCooldownMin: Double = 4.0
    static let socialCooldownMax: Double = 8.5
    static let socialEventCooldownMin: Double = 1.4
    static let socialEventCooldownMax: Double = 3.2
    static let socialScanInterval: Double = 0.75
    static let recentBreakTargetLimit: Int = 3
    static let fps: Double = 8.0
    static let charSittingOffset: CGFloat = 3    // 앉을 때 Y 오프셋
}
