import SwiftUI

// ═══════════════════════════════════════════════════════
// MARK: - Office Layout Persistence
// ═══════════════════════════════════════════════════════

struct OfficeLayoutSnapshot: Codable {
    let cols: Int
    let rows: Int
    var tiles: [[TileType]]
    var zones: [[OfficeZone?]]
    var furniture: [FurniturePlacement]
    var seats: [Seat]
}

final class OfficeLayoutStore {
    static let shared = OfficeLayoutStore()

    private let keyPrefix = "workman.office.layout"
    private let defaults = UserDefaults.standard

    private func key(for preset: OfficePreset) -> String {
        "\(keyPrefix).\(preset.rawValue).v1"
    }

    func applyStoredLayout(to map: OfficeMap, preset: OfficePreset) {
        guard
            let data = defaults.data(forKey: key(for: preset)),
            let snapshot = try? JSONDecoder().decode(OfficeLayoutSnapshot.self, from: data)
        else {
            return
        }
        map.applyLayoutSnapshot(snapshot)
    }

    func saveLayout(from map: OfficeMap, preset: OfficePreset) {
        guard let data = try? JSONEncoder().encode(map.layoutSnapshot()) else { return }
        defaults.set(data, forKey: key(for: preset))
    }

    func resetSavedLayout(preset: OfficePreset) {
        defaults.removeObject(forKey: key(for: preset))
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - Office Map Layout Editing
// ═══════════════════════════════════════════════════════

extension OfficeMap {
    func layoutSnapshot() -> OfficeLayoutSnapshot {
        OfficeLayoutSnapshot(
            cols: cols,
            rows: rows,
            tiles: tiles,
            zones: zones,
            furniture: furniture,
            seats: seats.map {
                Seat(
                    id: $0.id,
                    position: $0.position,
                    deskId: $0.deskId,
                    facing: $0.facing,
                    assignedTabId: nil
                )
            }
        )
    }

    func applyLayoutSnapshot(_ snapshot: OfficeLayoutSnapshot) {
        guard snapshot.cols == cols, snapshot.rows == rows else { return }
        tiles = snapshot.tiles
        zones = snapshot.zones
        furniture = snapshot.furniture
        seats = snapshot.seats.map {
            Seat(
                id: $0.id,
                position: $0.position,
                deskId: $0.deskId,
                facing: $0.facing,
                assignedTabId: nil
            )
        }
        rebuildWalkability()
    }

    func selectedFurniture(at coord: TileCoord) -> FurniturePlacement? {
        furniture
            .sorted { $0.zY < $1.zY }
            .reversed()
            .first { placement in
                coord.col >= placement.position.col &&
                coord.col < placement.position.col + placement.size.w &&
                coord.row >= placement.position.row &&
                coord.row < placement.position.row + placement.size.h
            }
    }

    func movableAnchorId(for furnitureId: String) -> String {
        if furnitureId.hasPrefix("desk_") { return furnitureId }
        if furnitureId.hasPrefix("mon_") || furnitureId.hasPrefix("chair_") || furnitureId.hasPrefix("seat_") {
            let suffix = furnitureId.split(separator: "_").last.map(String.init) ?? ""
            return "desk_\(suffix)"
        }
        return furnitureId
    }

    func placeFurnitureGroup(anchorId: String, at newPosition: TileCoord) -> Bool {
        guard let anchor = furniture.first(where: { $0.id == anchorId }) else { return false }

        let groupIds = groupedFurnitureIds(for: anchorId)
        let ignored = Set(groupIds)
        let delta = TileCoord(col: newPosition.col - anchor.position.col, row: newPosition.row - anchor.position.row)

        var proposedFurniture: [String: TileCoord] = [:]
        for item in furniture where ignored.contains(item.id) {
            proposedFurniture[item.id] = TileCoord(col: item.position.col + delta.col, row: item.position.row + delta.row)
        }

        var proposedSeats: [String: TileCoord] = [:]
        for seat in seats where seat.deskId == anchorId {
            proposedSeats[seat.id] = TileCoord(col: seat.position.col + delta.col, row: seat.position.row + delta.row)
        }

        for item in furniture where ignored.contains(item.id) {
            guard let position = proposedFurniture[item.id] else { return false }
            guard isPlacementValid(item, at: position, ignoring: ignored) else { return false }
        }

        for seat in seats where seat.deskId == anchorId {
            guard let position = proposedSeats[seat.id] else { return false }
            guard isSeatValid(at: position, ignoring: ignored) else { return false }
        }

        for index in furniture.indices where ignored.contains(furniture[index].id) {
            if let position = proposedFurniture[furniture[index].id] {
                furniture[index].position = position
            }
        }

        for index in seats.indices where seats[index].deskId == anchorId {
            if let position = proposedSeats[seats[index].id] {
                seats[index] = Seat(
                    id: seats[index].id,
                    position: position,
                    deskId: seats[index].deskId,
                    facing: seats[index].facing,
                    assignedTabId: seats[index].assignedTabId
                )
            }
        }

        rebuildWalkability()
        return true
    }

    private func groupedFurnitureIds(for anchorId: String) -> [String] {
        guard anchorId.hasPrefix("desk_"),
              let suffix = anchorId.split(separator: "_").last
        else {
            return [anchorId]
        }

        return [
            anchorId,
            "mon_\(suffix)",
            "chair_\(suffix)"
        ]
    }

    private func isPlacementValid(_ item: FurniturePlacement, at position: TileCoord, ignoring ignoredIds: Set<String>) -> Bool {
        for row in 0..<item.size.h {
            for col in 0..<item.size.w {
                let coord = TileCoord(col: position.col + col, row: position.row + row)
                guard isInBounds(coord) else { return false }

                let tile = tileAt(coord)
                if OfficeLayoutCollision.isWallMounted(item.type) {
                    guard tile == .wall else { return false }
                } else {
                    guard tile.isWalkable, tile != .door else { return false }
                }
            }
        }

        for other in furniture where !ignoredIds.contains(other.id) {
            if OfficeLayoutCollision.canOverlap(item.type, with: other.type) { continue }
            if OfficeLayoutCollision.rectsIntersect(
                lhsPosition: position,
                lhsSize: item.size,
                rhsPosition: other.position,
                rhsSize: other.size
            ) {
                return false
            }
        }

        return true
    }

    private func isSeatValid(at position: TileCoord, ignoring ignoredIds: Set<String>) -> Bool {
        guard isInBounds(position) else { return false }
        let tile = tileAt(position)
        guard tile.isWalkable, tile != .door else { return false }

        for other in furniture where !ignoredIds.contains(other.id) {
            if OfficeLayoutCollision.isWallMounted(other.type) || other.type == .chair || other.type == .rug {
                continue
            }
            if OfficeLayoutCollision.rectContains(position, topLeft: other.position, size: other.size) {
                return false
            }
        }

        return true
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - Furniture Add / Remove
// ═══════════════════════════════════════════════════════

extension OfficeMap {
    /// 가구 제거 (책상이면 연관된 모니터, 의자, 좌석도 함께 제거)
    func removeFurniture(id: String) -> Bool {
        let anchorId = movableAnchorId(for: id)

        // 책상인 경우 그룹 전체 제거
        if anchorId.hasPrefix("desk_") {
            let suffix = anchorId.split(separator: "_").last.map(String.init) ?? ""
            let groupIds: Set<String> = ["desk_\(suffix)", "mon_\(suffix)", "chair_\(suffix)"]
            furniture.removeAll { groupIds.contains($0.id) }
            seats.removeAll { $0.deskId == anchorId }
        } else {
            furniture.removeAll { $0.id == id }
        }

        rebuildWalkability()
        return true
    }

    /// 가구 추가 (위치 유효성 검증 포함)
    func addFurniture(_ type: FurnitureType, at position: TileCoord, zone: OfficeZone, size: TileSize? = nil) -> FurniturePlacement? {
        let furnitureSize = size ?? defaultSize(for: type)
        let newId = "\(type.rawValue)_\(UUID().uuidString.prefix(6))"

        let placement = FurniturePlacement(
            id: newId,
            type: type,
            position: position,
            size: furnitureSize,
            zone: zone
        )

        // 유효성 검증
        for row in 0..<furnitureSize.h {
            for col in 0..<furnitureSize.w {
                let coord = TileCoord(col: position.col + col, row: position.row + row)
                guard isInBounds(coord) else { return nil }
                let tile = tileAt(coord)
                if OfficeLayoutCollision.isWallMounted(type) {
                    guard tile == .wall else { return nil }
                } else {
                    guard tile.isWalkable, tile != .door else { return nil }
                }
            }
        }

        // 충돌 검사 (rug은 겹침 허용)
        for other in furniture {
            if OfficeLayoutCollision.canOverlap(type, with: other.type) { continue }
            if OfficeLayoutCollision.rectsIntersect(
                lhsPosition: position, lhsSize: furnitureSize,
                rhsPosition: other.position, rhsSize: other.size
            ) { return nil }
        }

        furniture.append(placement)
        rebuildWalkability()
        return placement
    }

    /// 책상+모니터+의자+좌석 세트를 한 번에 추가
    func addDeskSet(at position: TileCoord, zone: OfficeZone) -> Bool {
        let existingDeskCount = furniture.filter { $0.id.hasPrefix("desk_") }.count
        guard existingDeskCount < 12 else { return false }  // 최대 12석

        let idx = existingDeskCount
        let deskId = "desk_\(idx)"

        // 유효성: 3x1 책상 + 1x1 의자 (아래)
        let deskSize = TileSize(w: 3, h: 1)
        for col in 0..<3 {
            let coord = TileCoord(col: position.col + col, row: position.row)
            guard isInBounds(coord), tileAt(coord).isWalkable, tileAt(coord) != .door else { return false }
        }
        let chairCoord = TileCoord(col: position.col + 1, row: position.row + 1)
        guard isInBounds(chairCoord), tileAt(chairCoord).isWalkable else { return false }

        // 충돌 검사
        for other in furniture {
            if other.type == .rug || other.type == .chair { continue }
            if OfficeLayoutCollision.rectsIntersect(
                lhsPosition: position, lhsSize: deskSize,
                rhsPosition: other.position, rhsSize: other.size
            ) { return false }
        }

        furniture.append(FurniturePlacement(id: deskId, type: .desk, position: position, size: deskSize, zone: zone))
        furniture.append(FurniturePlacement(id: "mon_\(idx)", type: .monitor, position: TileCoord(col: position.col + 1, row: position.row), size: TileSize(w: 1, h: 1), zone: zone))
        furniture.append(FurniturePlacement(id: "chair_\(idx)", type: .chair, position: chairCoord, size: TileSize(w: 1, h: 1), zone: zone))
        seats.append(Seat(id: "seat_\(idx)", position: chairCoord, deskId: deskId, facing: .up))

        rebuildWalkability()
        return true
    }

    private func defaultSize(for type: FurnitureType) -> TileSize {
        switch type {
        case .desk: return TileSize(w: 3, h: 1)
        case .sofa: return TileSize(w: 3, h: 2)
        case .roundTable: return TileSize(w: 2, h: 2)
        case .bookshelf: return TileSize(w: 2, h: 1)
        case .whiteboard: return TileSize(w: 4, h: 1)
        case .rug: return TileSize(w: 5, h: 3)
        case .pictureFrame: return TileSize(w: 3, h: 1)
        default: return TileSize(w: 1, h: 1)
        }
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - Room Wall Adjustment
// ═══════════════════════════════════════════════════════

extension OfficeMap {
    /// 내부 세로 벽 (오피스 | 팬트리+미팅) 위치 조절
    /// 제약: 최소 col 20 ~ 최대 col 35 (양쪽 공간 확보)
    func moveVerticalWall(to newCol: Int) -> Bool {
        guard newCol >= 20, newCol <= 35 else { return false }

        // 기존 세로 벽 제거 (현재 col 찾기)
        let currentWallCol = (0..<cols).first { c in
            (2..<rows-1).allSatisfy { r in tiles[r][c] == .wall } &&
            c > 1 && c < cols - 1
        } ?? 28

        if currentWallCol == newCol { return true }

        // 기존 벽 → 바닥으로
        for r in 2..<rows-1 {
            if tiles[r][currentWallCol] == .wall || tiles[r][currentWallCol] == .door {
                tiles[r][currentWallCol] = .floor1
                zones[r][currentWallCol] = .mainOffice
            }
        }

        // 새 벽 그리기
        for r in 0..<rows {
            tiles[r][newCol] = .wall
        }

        // 문 복원
        tiles[6][newCol] = .door
        tiles[7][newCol] = .door
        tiles[14][newCol] = .door
        tiles[15][newCol] = .door

        // 존 재할당
        for r in 2..<rows-1 {
            for c in 1..<newCol {
                if tiles[r][c] != .wall && tiles[r][c] != .door {
                    tiles[r][c] = .floor1
                    zones[r][c] = .mainOffice
                }
            }
            for c in (newCol+1)..<cols-1 {
                if tiles[r][c] != .wall && tiles[r][c] != .door {
                    let horizontalWallRow = (2..<rows-1).first { hr in
                        tiles[hr][c] == .wall && hr > 2 && hr < rows - 1
                    }
                    if let hr = horizontalWallRow, r < hr {
                        tiles[r][c] = .floor2
                        zones[r][c] = .pantry
                    } else if let hr = horizontalWallRow, r > hr {
                        tiles[r][c] = .carpet
                        zones[r][c] = .meetingRoom
                    } else {
                        tiles[r][c] = .floor2
                        zones[r][c] = .pantry
                    }
                }
            }
        }

        // 벽 밖으로 나간 가구 제거
        furniture.removeAll { f in
            for dr in 0..<f.size.h {
                for dc in 0..<f.size.w {
                    let r = f.position.row + dr
                    let c = f.position.col + dc
                    if r >= 0 && r < rows && c >= 0 && c < cols {
                        if tiles[r][c] == .wall && !OfficeLayoutCollision.isWallMounted(f.type) {
                            return true
                        }
                    }
                }
            }
            return false
        }

        rebuildWalkability()
        return true
    }

    /// 내부 가로 벽 (팬트리 | 미팅룸) 위치 조절
    /// 제약: 최소 row 5 ~ 최대 row 16
    func moveHorizontalWall(to newRow: Int) -> Bool {
        guard newRow >= 5, newRow <= 16 else { return false }

        let verticalWallCol: Int = {
            for c in 0..<cols {
                guard c > 1, c < cols - 1 else { continue }
                let isWallColumn = (2..<rows-1).allSatisfy { r in
                    tiles[r][c] == .wall || tiles[r][c] == .door
                }
                if isWallColumn { return c }
            }
            return 28
        }()

        // 기존 가로 벽 제거
        let currentWallRow: Int = {
            for r in 2..<rows-1 {
                let isWallRow = ((verticalWallCol+1)..<cols-1).allSatisfy { c in
                    tiles[r][c] == .wall
                }
                if isWallRow { return r }
            }
            return 11
        }()

        if currentWallRow == newRow { return true }

        // 기존 벽 → 바닥
        for c in (verticalWallCol+1)..<cols-1 {
            if tiles[currentWallRow][c] == .wall {
                tiles[currentWallRow][c] = .floor2
                zones[currentWallRow][c] = .pantry
            }
        }

        // 새 가로 벽
        for c in (verticalWallCol+1)..<cols-1 {
            tiles[newRow][c] = .wall
        }

        // 존 재할당 (팬트리 위, 미팅룸 아래)
        for r in 2..<newRow {
            for c in (verticalWallCol+1)..<cols-1 {
                if tiles[r][c] != .wall && tiles[r][c] != .door {
                    tiles[r][c] = .floor2
                    zones[r][c] = .pantry
                }
            }
        }
        for r in (newRow+1)..<rows-1 {
            for c in (verticalWallCol+1)..<cols-1 {
                if tiles[r][c] != .wall && tiles[r][c] != .door {
                    tiles[r][c] = .carpet
                    zones[r][c] = .meetingRoom
                }
            }
        }

        // 벽에 걸린 가구 제거
        furniture.removeAll { f in
            for dr in 0..<f.size.h {
                for dc in 0..<f.size.w {
                    let r = f.position.row + dr
                    let c = f.position.col + dc
                    if r >= 0 && r < rows && c >= 0 && c < cols {
                        if tiles[r][c] == .wall && !OfficeLayoutCollision.isWallMounted(f.type) {
                            return true
                        }
                    }
                }
            }
            return false
        }

        rebuildWalkability()
        return true
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - Furniture Interaction Events
// ═══════════════════════════════════════════════════════

enum FurnitureEvent: String, CaseIterable {
    case drinkCoffee     // coffeeMachine 근처
    case drinkWater      // waterCooler 근처
    case readBook        // bookshelf 근처
    case relaxOnSofa     // sofa 근처
    case checkWhiteboard // whiteboard 근처
    case usePrinter      // printer 근처
    case throwTrash      // trashBin 근처
    case waterPlant      // plant 근처

    var duration: TimeInterval {
        switch self {
        case .drinkCoffee, .drinkWater: return 3.0
        case .readBook: return 5.0
        case .relaxOnSofa: return 6.0
        case .checkWhiteboard: return 4.0
        case .usePrinter: return 2.5
        case .throwTrash: return 1.5
        case .waterPlant: return 2.0
        }
    }

    static func events(for furnitureType: FurnitureType) -> [FurnitureEvent] {
        switch furnitureType {
        case .coffeeMachine: return [.drinkCoffee]
        case .waterCooler: return [.drinkWater]
        case .bookshelf: return [.readBook]
        case .sofa: return [.relaxOnSofa]
        case .whiteboard: return [.checkWhiteboard]
        case .printer: return [.usePrinter]
        case .trashBin: return [.throwTrash]
        case .plant: return [.waterPlant]
        default: return []
        }
    }
}

extension OfficeMap {
    /// 가구 근처의 빈 타일을 찾아 이벤트 목적지로 반환
    func interactionTile(for furniture: FurniturePlacement) -> TileCoord? {
        // 가구 주변 4방향에서 걸을 수 있는 타일 찾기
        let candidates = [
            TileCoord(col: furniture.position.col - 1, row: furniture.position.row),
            TileCoord(col: furniture.position.col + furniture.size.w, row: furniture.position.row),
            TileCoord(col: furniture.position.col, row: furniture.position.row - 1),
            TileCoord(col: furniture.position.col, row: furniture.position.row + furniture.size.h),
        ]
        return candidates.first { isWalkable($0) }
    }

    /// 이벤트가 가능한 가구 목록 (이벤트 종류와 함께)
    func availableInteractions() -> [(FurniturePlacement, FurnitureEvent)] {
        var results: [(FurniturePlacement, FurnitureEvent)] = []
        for f in furniture {
            let events = FurnitureEvent.events(for: f.type)
            for event in events {
                if interactionTile(for: f) != nil {
                    results.append((f, event))
                }
            }
        }
        return results
    }
}

private enum OfficeLayoutCollision {
    static func isWallMounted(_ type: FurnitureType) -> Bool {
        [.pictureFrame, .clock, .whiteboard].contains(type)
    }

    static func canOverlap(_ lhs: FurnitureType, with rhs: FurnitureType) -> Bool {
        if lhs == .rug || rhs == .rug { return true }
        let lhsWall = isWallMounted(lhs)
        let rhsWall = isWallMounted(rhs)
        return lhsWall != rhsWall
    }

    static func rectContains(_ coord: TileCoord, topLeft: TileCoord, size: TileSize) -> Bool {
        coord.col >= topLeft.col &&
        coord.col < topLeft.col + size.w &&
        coord.row >= topLeft.row &&
        coord.row < topLeft.row + size.h
    }

    static func rectsIntersect(lhsPosition: TileCoord, lhsSize: TileSize, rhsPosition: TileCoord, rhsSize: TileSize) -> Bool {
        let lhsRight = lhsPosition.col + lhsSize.w
        let lhsBottom = lhsPosition.row + lhsSize.h
        let rhsRight = rhsPosition.col + rhsSize.w
        let rhsBottom = rhsPosition.row + rhsSize.h

        return lhsPosition.col < rhsRight &&
        lhsRight > rhsPosition.col &&
        lhsPosition.row < rhsBottom &&
        lhsBottom > rhsPosition.row
    }
}
