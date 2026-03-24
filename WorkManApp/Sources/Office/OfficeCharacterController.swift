import SwiftUI

// ═══════════════════════════════════════════════════════
// MARK: - Office Character Controller
// ═══════════════════════════════════════════════════════

class OfficeCharacterController: ObservableObject {
    @Published var characters: [String: OfficeCharacter] = [:]
    let map: OfficeMap
    private let registry = CharacterRegistry.shared
    private var walkableTiles: [TileCoord] = []
    private var pantryAndMeetingTiles: [TileCoord] = []
    private var socialHotspotTiles: [TileCoord] = []
    private var blockedTiles: Set<String> = []
    private var seatAssignmentsByGroup: [String: String] = [:]
    private var socialEventCooldown: Double = 0
    private var socialScanCooldown: Double = 0

    init(map: OfficeMap) {
        self.map = map
        rebuildWalkableCache()
    }

    func refreshLayout(with tabs: [TerminalTab]) {
        map.rebuildWalkability()
        rebuildWalkableCache()

        for (id, var ch) in characters {
            guard let seatId = ch.seatId, let seat = map.seats.first(where: { $0.id == seatId }) else {
                characters[id] = ch
                continue
            }

            let workstationTile = workstationTile(for: ch, seat: seat)

            switch ch.state {
            case .walkingTo, .wandering:
                break
            default:
                let center = tileCenter(workstationTile)
                ch.pixelX = center.x
                ch.pixelY = center.y
                ch.tileCol = workstationTile.col
                ch.tileRow = workstationTile.row
                ch.dir = seat.facing
                ch.targetTile = workstationTile
                ch.destinationPurpose = .seat
            }

            characters[id] = ch
        }

        sync(with: tabs)
    }

    private func rebuildWalkableCache() {
        walkableTiles = []
        blockedTiles = Set()
        for row in 0..<map.rows {
            for col in 0..<map.cols {
                let coord = TileCoord(col: col, row: row)
                if map.isWalkable(coord) {
                    walkableTiles.append(coord)
                }
            }
        }
        pantryAndMeetingTiles = walkableTiles.filter { tile in
            guard let zone = map.zoneAt(tile) else { return false }
            return zone == .pantry || zone == .meetingRoom
        }

        var hotspots: Set<TileCoord> = []
        for furniture in map.furniture where [.coffeeMachine, .sofa, .roundTable, .waterCooler].contains(furniture.type) {
            for tile in interactionTiles(for: furniture) where map.isWalkable(tile) {
                hotspots.insert(tile)
            }
        }
        socialHotspotTiles = hotspots.isEmpty ? pantryAndMeetingTiles : Array(hotspots)

        for furniture in map.furniture {
            let walkable: Set<FurnitureType> = [.rug, .chair]
            if walkable.contains(furniture.type) { continue }
            for deltaRow in 0..<furniture.size.h {
                for deltaCol in 0..<furniture.size.w {
                    blockedTiles.insert("\(furniture.position.col + deltaCol),\(furniture.position.row + deltaRow)")
                }
            }
        }
    }

    // MARK: - Sync

    func sync(with tabs: [TerminalTab]) {
        func effectiveOfficeActivity(for tab: TerminalTab) -> ClaudeActivity {
            if tab.isProcessing {
                return tab.claudeActivity
            }
            if tab.officeSeatLockReason != nil {
                return .writing
            }
            return tab.claudeActivity
        }

        let hiredRoster = orderedHiredRoster()
        let occupiedCharacterIds = Set(tabs.compactMap(\.characterId))
        let rosterOnlyCharacters = hiredRoster.filter { !occupiedCharacterIds.contains($0.id) }

        let groupedTabs = Dictionary(grouping: tabs, by: seatGroupKey(for:))
        let activeGroupKeys = Set(groupedTabs.keys).union(rosterOnlyCharacters.map { seatGroupKey(forRosterCharacter: $0) })
        let activeCharacterKeys = Set(tabs.map(officeCharacterKey(for:)))
        let rosterCharacterKeys = Set(rosterOnlyCharacters.map(\.id))

        for groupKey in seatAssignmentsByGroup.keys where !activeGroupKeys.contains(groupKey) {
            releaseSeat(forGroupKey: groupKey)
        }

        for id in characters.keys where !activeCharacterKeys.contains(id) && !rosterCharacterKeys.contains(id) {
            characters.removeValue(forKey: id)
        }

        for (_, tabsInSeatGroup) in groupedTabs {
            let orderedTabs = orderedTabsForSeatGroup(tabsInSeatGroup)
            guard let leaderTab = orderedTabs.first else { continue }
            let groupKey = seatGroupKey(for: leaderTab)
            let representativeTabId = monitorRepresentativeTabId(for: orderedTabs)

            let assignedSeat = assignSeat(forGroupKey: groupKey, representativeTabId: representativeTabId)
            let sharedWorkstationTiles = assignedSeat.map { workstationTiles(for: $0, groupSize: orderedTabs.count) } ?? []

            for (index, tab) in orderedTabs.enumerated() {
                let characterKey = officeCharacterKey(for: tab)
                let usesSeatPose = index == 0
                let rosterCharacter = registry.character(with: tab.characterId)
                let accentHex = rosterCharacter.map { normalizedHex($0.shirtColor) } ?? colorToHex(tab.workerColor)

                if characters[characterKey] == nil {
                    if let seat = assignedSeat {
                        let startTile = tileForSeatGroupMember(index: index, from: sharedWorkstationTiles, fallbackSeat: seat)
                        let center = tileCenter(startTile)
                        characters[characterKey] = OfficeCharacter(
                            tabId: tab.id,
                            rosterCharacterId: rosterCharacter?.id ?? tab.characterId,
                            displayName: tab.workerName,
                            accentColorHex: accentHex,
                            jobRole: tab.workerJob,
                            isRosterOnly: false,
                            seatGroupKey: groupKey,
                            groupId: tab.groupId,
                            groupIndex: index,
                            groupSize: orderedTabs.count,
                            usesSeatPose: usesSeatPose,
                            pixelX: center.x,
                            pixelY: center.y,
                            tileCol: startTile.col,
                            tileRow: startTile.row,
                            targetTile: startTile,
                            state: .typing,
                            dir: seat.facing,
                            seatId: seat.id,
                            isActive: true,
                            activity: tab.claudeActivity,
                            destinationPurpose: .seat
                        )
                    } else {
                        let startTile = fallbackSpawnTile(for: index)
                        let center = tileCenter(startTile)
                        characters[characterKey] = OfficeCharacter(
                            tabId: tab.id,
                            rosterCharacterId: rosterCharacter?.id ?? tab.characterId,
                            displayName: tab.workerName,
                            accentColorHex: accentHex,
                            jobRole: tab.workerJob,
                            isRosterOnly: false,
                            seatGroupKey: groupKey,
                            groupId: tab.groupId,
                            groupIndex: index,
                            groupSize: orderedTabs.count,
                            usesSeatPose: usesSeatPose,
                            pixelX: center.x,
                            pixelY: center.y,
                            tileCol: startTile.col,
                            tileRow: startTile.row,
                            state: .sittingIdle,
                            dir: .down,
                            isActive: true,
                            activity: tab.claudeActivity,
                            destinationPurpose: .seat
                        )
                    }
                }

                guard var character = characters[characterKey] else { continue }
                let previousGroupKey = character.seatGroupKey
                let effectiveActivity = effectiveOfficeActivity(for: tab)

                character.tabId = tab.id
                character.rosterCharacterId = rosterCharacter?.id ?? tab.characterId
                character.displayName = tab.workerName
                character.accentColorHex = accentHex
                character.jobRole = tab.workerJob
                character.isRosterOnly = false
                character.seatGroupKey = groupKey
                character.groupId = tab.groupId
                character.groupIndex = index
                character.groupSize = orderedTabs.count
                character.usesSeatPose = usesSeatPose
                character.seatId = assignedSeat?.id

                if previousGroupKey != groupKey {
                    character.path.removeAll()
                    character.targetTile = nil
                    character.moveProgress = 0
                }

                if let seat = assignedSeat {
                    let groupTile = tileForSeatGroupMember(index: index, from: sharedWorkstationTiles, fallbackSeat: seat)
                    if previousGroupKey != groupKey,
                       character.destinationPurpose == .seat,
                       !character.isActive {
                        let center = tileCenter(groupTile)
                        character.pixelX = center.x
                        character.pixelY = center.y
                        character.tileCol = groupTile.col
                        character.tileRow = groupTile.row
                        character.targetTile = groupTile
                    }
                }

                let wasActive = character.isActive
                character.isActive = tab.officeSeatLockReason != nil || tab.claudeActivity != .idle || tab.isProcessing

                if character.isActive && !wasActive {
                    onBecameActive(&character)
                } else if !character.isActive && wasActive {
                    onBecameInactive(&character)
                }

                if character.isActive {
                    character.activity = effectiveActivity
                    updateActiveState(&character, activity: effectiveActivity)
                } else {
                    character.activity = .idle
                }

                characters[characterKey] = character
            }
        }

        for (index, hiredCharacter) in rosterOnlyCharacters.enumerated() {
            let characterKey = hiredCharacter.id
            let groupKey = seatGroupKey(forRosterCharacter: hiredCharacter)
            let assignedSeat = assignSeat(forGroupKey: groupKey, representativeTabId: "__idle__\(hiredCharacter.id)")

            if characters[characterKey] == nil {
                let startTile = assignedSeat?.position ?? idleRosterFallbackTile(for: index)
                let center = tileCenter(startTile)
                characters[characterKey] = OfficeCharacter(
                    tabId: nil,
                    rosterCharacterId: hiredCharacter.id,
                    displayName: hiredCharacter.name,
                    accentColorHex: normalizedHex(hiredCharacter.shirtColor),
                    jobRole: hiredCharacter.jobRole,
                    isRosterOnly: true,
                    seatGroupKey: groupKey,
                    groupId: nil,
                    groupIndex: 0,
                    groupSize: 1,
                    usesSeatPose: assignedSeat != nil,
                    pixelX: center.x,
                    pixelY: center.y,
                    tileCol: startTile.col,
                    tileRow: startTile.row,
                    targetTile: startTile,
                    state: hiredCharacter.isOnVacation ? .onBreak : .seatRest,
                    dir: assignedSeat?.facing ?? .down,
                    seatId: assignedSeat?.id,
                    isActive: false,
                    activity: .idle,
                    destinationPurpose: .seat,
                    seatTimer: seatRestDuration()
                )
            }

            guard var character = characters[characterKey] else { continue }
            let previousGroupKey = character.seatGroupKey

            character.tabId = nil
            character.rosterCharacterId = hiredCharacter.id
            character.displayName = hiredCharacter.name
            character.accentColorHex = normalizedHex(hiredCharacter.shirtColor)
            character.jobRole = hiredCharacter.jobRole
            character.isRosterOnly = true
            character.seatGroupKey = groupKey
            character.groupId = nil
            character.groupIndex = 0
            character.groupSize = 1
            character.usesSeatPose = assignedSeat != nil
            character.seatId = assignedSeat?.id
            character.isActive = false
            character.activity = .idle

            if previousGroupKey != groupKey {
                character.path.removeAll()
                character.targetTile = nil
                character.moveProgress = 0
            }

            if let assignedSeat {
                let workstationTile = assignedSeat.position
                let center = tileCenter(workstationTile)
                character.pixelX = center.x
                character.pixelY = center.y
                character.tileCol = workstationTile.col
                character.tileRow = workstationTile.row
                character.targetTile = workstationTile
                character.dir = assignedSeat.facing
                character.destinationPurpose = .seat
                if !hiredCharacter.isOnVacation {
                    character.state = .seatRest
                    character.seatTimer = seatRestDuration()
                }
            } else {
                let fallback = idleRosterFallbackTile(for: index)
                let center = tileCenter(fallback)
                character.pixelX = center.x
                character.pixelY = center.y
                character.tileCol = fallback.col
                character.tileRow = fallback.row
                character.targetTile = fallback
                character.dir = .down
                character.destinationPurpose = .breakSpot
                character.state = .wanderPause
                character.wanderTimer = wanderPauseDuration()
            }

            if hiredCharacter.isOnVacation {
                if let breakTarget = stagedTarget(for: .breakSpot, from: character.tileCoord) {
                    if character.tileCoord == breakTarget {
                        character.state = .onBreak
                        character.targetTile = breakTarget
                        character.destinationPurpose = .breakSpot
                    } else if !isHeading(to: breakTarget, purpose: .breakSpot, character: character) {
                        _ = beginMovement(&character, to: breakTarget, purpose: .breakSpot)
                    }
                } else {
                    character.state = .onBreak
                }
            }

            characters[characterKey] = character
        }
    }

    // MARK: - State Transitions

    private func onBecameActive(_ ch: inout OfficeCharacter) {
        guard let seat = seat(for: ch) else {
            ch.state = .typing
            ch.destinationPurpose = .seat
            return
        }

        let workstationTile = workstationTile(for: ch, seat: seat)

        if ch.tileCoord == workstationTile {
            ch.state = .typing
            ch.dir = seat.facing
            ch.moveProgress = 0
            ch.frame = 0
            ch.destinationPurpose = .seat
            ch.targetTile = workstationTile
        } else if !beginMovement(&ch, to: workstationTile, purpose: .seat) {
            snapToSeat(&ch, seat: seat)
        }
    }

    private func onBecameInactive(_ ch: inout OfficeCharacter) {
        ch.stateHoldTimer = 0
        clearSocialState(&ch, resumeMotion: false)
        ch.seatTimer = seatRestDuration()
        ch.state = .seatRest
        ch.frame = 0
        ch.moveProgress = 0
        ch.destinationPurpose = .seat
        ch.path.removeAll()
    }

    private func updateActiveState(_ ch: inout OfficeCharacter, activity: ClaudeActivity) {
        let purpose = destinationPurpose(for: activity)

        if purpose == .seat {
            routeToSeatIfNeeded(&ch, activity: activity)
            return
        }

        if let target = stagedTarget(for: purpose, from: ch.tileCoord) {
            if ch.tileCoord == target {
                ch.path.removeAll()
                ch.targetTile = target
                ch.destinationPurpose = purpose
                ch.state = state(for: activity)
                ch.dir = facingForPurpose(purpose, from: target)
                ch.frame = 0
                ch.moveProgress = 0
            } else if !isHeading(to: target, purpose: purpose, character: ch) {
                _ = beginMovement(&ch, to: target, purpose: purpose)
            }
        } else {
            routeToSeatIfNeeded(&ch, activity: activity)
        }
    }

    private func routeToSeatIfNeeded(_ ch: inout OfficeCharacter, activity: ClaudeActivity) {
        guard let seat = seat(for: ch) else {
            ch.state = state(for: activity)
            ch.destinationPurpose = .seat
            return
        }

        let workstationTile = workstationTile(for: ch, seat: seat)

        ch.targetTile = workstationTile
        ch.destinationPurpose = .seat

        if ch.tileCoord == workstationTile {
            ch.state = state(for: activity)
            ch.dir = seat.facing
            ch.path.removeAll()
            ch.moveProgress = 0
            if activity == .done {
                ch.stateHoldTimer = 1.5
            }
        } else if !isHeading(to: workstationTile, purpose: .seat, character: ch) {
            _ = beginMovement(&ch, to: workstationTile, purpose: .seat)
        }
    }

    // MARK: - Tick

    func tick(deltaTime: Double) {
        socialEventCooldown = max(0, socialEventCooldown - deltaTime)
        socialScanCooldown = max(0, socialScanCooldown - deltaTime)

        for (id, var ch) in characters {
            ch.frameTimer += deltaTime
            if ch.stateHoldTimer > 0 {
                ch.stateHoldTimer = max(0, ch.stateHoldTimer - deltaTime)
            }
            advanceAmbientPresence(id: id, character: &ch, dt: deltaTime)

            switch ch.state {
            case .typing, .reading, .searching:
                if ch.frameTimer >= OfficeConstants.typeFrameDuration {
                    ch.frameTimer -= OfficeConstants.typeFrameDuration
                    ch.frame = (ch.frame + 1) % 2
                }

            case .celebrating:
                if ch.frameTimer >= OfficeConstants.typeFrameDuration {
                    ch.frameTimer -= OfficeConstants.typeFrameDuration
                    ch.frame = (ch.frame + 1) % 2
                }

            case .walkingTo(let target):
                advanceWalking(&ch, target: target, dt: deltaTime)

            case .wandering:
                advanceWalking(&ch, target: ch.targetTile ?? ch.tileCoord, dt: deltaTime)

            case .wanderPause:
                if ch.socialTimer > 0 {
                    characters[id] = ch
                    continue
                }
                ch.wanderTimer -= deltaTime
                if ch.wanderTimer <= 0 {
                    if ch.wanderCount >= ch.wanderLimit {
                        returnToSeat(&ch)
                    } else {
                        startWander(&ch)
                    }
                }

            case .seatRest:
                if ch.socialTimer > 0 {
                    characters[id] = ch
                    continue
                }
                ch.seatTimer -= deltaTime
                if ch.seatTimer <= 0 {
                    ch.state = .wanderPause
                    ch.wanderTimer = wanderPauseDuration()
                    ch.wanderCount = 0
                    ch.wanderLimit = wanderMoveLimit()
                }

            default:
                break
            }

            characters[id] = ch
        }

        if socialScanCooldown <= 0 {
            updateAmbientInteractions()
            socialScanCooldown = OfficeConstants.socialScanInterval
        }
    }

    // MARK: - Walking

    private func snapPixel(_ value: CGFloat) -> CGFloat {
        value.rounded(.toNearestOrAwayFromZero)
    }

    private func advanceWalking(_ ch: inout OfficeCharacter, target: TileCoord, dt: Double) {
        guard !ch.path.isEmpty else {
            arriveAtDestination(&ch, target: target)
            return
        }

        let next = ch.path[0]
        let tx = CGFloat(next.col) * OfficeConstants.tileSize + OfficeConstants.tileSize / 2
        let ty = CGFloat(next.row) * OfficeConstants.tileSize + OfficeConstants.tileSize / 2
        let dx = tx - ch.pixelX
        let dy = ty - ch.pixelY
        let dist = sqrt(dx * dx + dy * dy)
        let rawStep = OfficeConstants.walkSpeed * CGFloat(dt)
        let step = max(1, rawStep.rounded(.down))
        let previousX = ch.pixelX
        let previousY = ch.pixelY

        if dist <= step {
            ch.pixelX = tx
            ch.pixelY = ty
            ch.tileCol = next.col
            ch.tileRow = next.row
            ch.path.removeFirst()
        } else {
            ch.pixelX = snapPixel(ch.pixelX + dx / dist * step)
            ch.pixelY = snapPixel(ch.pixelY + dy / dist * step)
        }

        let movedDistance = hypot(ch.pixelX - previousX, ch.pixelY - previousY)
        ch.moveProgress += movedDistance / OfficeConstants.tileSize
        if ch.moveProgress > 64 {
            ch.moveProgress.formTruncatingRemainder(dividingBy: 4)
        }
        ch.frame = Int((ch.moveProgress * 4).rounded(.down)) % 4

        if abs(dx) > abs(dy) {
            ch.dir = dx > 0 ? .right : .left
        } else {
            ch.dir = dy > 0 ? .down : .up
        }
    }

    private func arriveAtDestination(_ ch: inout OfficeCharacter, target: TileCoord) {
        ch.moveProgress = 0
        ch.frame = 0
        ch.path.removeAll()
        ch.targetTile = target

        switch ch.destinationPurpose {
        case .seat:
            if let seat = seat(for: ch) {
                ch.dir = seat.facing
                if ch.isActive {
                    ch.state = state(for: ch.activity)
                } else {
                    ch.state = .seatRest
                    ch.seatTimer = seatRestDuration()
                    ch.wanderCount = 0
                }
            } else {
                ch.state = .sittingIdle
            }
        case .thinking:
            ch.state = .thinking
            ch.dir = facingForPurpose(.thinking, from: target)
        case .searching:
            ch.state = .searching
            ch.dir = facingForPurpose(.searching, from: target)
        case .reading:
            ch.state = .reading
            ch.dir = facingForPurpose(.reading, from: target)
        case .error:
            ch.state = .error
            ch.dir = facingForPurpose(.error, from: target)
        case .breakSpot:
            rememberBreakTarget(target, for: &ch)
            ch.state = .onBreak
        }
    }

    private func startWander(_ ch: inout OfficeCharacter) {
        guard !walkableTiles.isEmpty else { return }

        guard let target = bestBreakTarget(for: ch) else {
            ch.wanderTimer = wanderPauseDuration()
            return
        }
        let path = map.findPath(from: ch.tileCoord, to: target)
        if !path.isEmpty {
            ch.path = path
            ch.targetTile = target
            ch.state = .wandering
            ch.frame = 0
            ch.frameTimer = 0
            ch.moveProgress = 0
            ch.destinationPurpose = .breakSpot
        } else {
            ch.wanderTimer = wanderPauseDuration()
        }
    }

    private func returnToSeat(_ ch: inout OfficeCharacter) {
        guard let seat = seat(for: ch) else {
            ch.state = .wanderPause
            ch.wanderTimer = 3.0
            return
        }
        if !beginMovement(&ch, to: workstationTile(for: ch, seat: seat), purpose: .seat) {
            ch.state = .sittingIdle
        }
    }

    private func beginMovement(_ ch: inout OfficeCharacter, to target: TileCoord, purpose: OfficeDestinationPurpose) -> Bool {
        let path = map.findPath(from: ch.tileCoord, to: target)
        guard !path.isEmpty else { return false }
        ch.path = path
        ch.targetTile = target
        ch.state = .walkingTo(target)
        ch.frame = 0
        ch.frameTimer = 0
        ch.moveProgress = 0
        ch.destinationPurpose = purpose
        return true
    }

    private func isHeading(to target: TileCoord, purpose: OfficeDestinationPurpose, character: OfficeCharacter) -> Bool {
        if case .walkingTo(let currentTarget) = character.state {
            return currentTarget == target && character.destinationPurpose == purpose
        }
        return false
    }

    // MARK: - Activity Routing

    private func destinationPurpose(for activity: ClaudeActivity) -> OfficeDestinationPurpose {
        switch activity {
        case .thinking:
            return .thinking
        case .searching:
            return .searching
        case .reading:
            return .reading
        case .error:
            return .error
        case .idle, .writing, .running, .done:
            return .seat
        }
    }

    private func state(for activity: ClaudeActivity) -> OfficeCharacterState {
        switch activity {
        case .thinking:
            return .thinking
        case .reading:
            return .reading
        case .searching:
            return .searching
        case .error:
            return .error
        case .done:
            return .celebrating
        case .idle:
            return .sittingIdle
        case .writing, .running:
            return .typing
        }
    }

    private func stagedTarget(for purpose: OfficeDestinationPurpose, from origin: TileCoord) -> TileCoord? {
        switch purpose {
        case .thinking:
            return bestInteractionTile(for: [.whiteboard, .roundTable], from: origin)
        case .searching:
            return bestInteractionTile(for: [.bookshelf, .printer], from: origin)
        case .reading:
            return bestInteractionTile(for: [.bookshelf, .roundTable], from: origin)
        case .error:
            return bestInteractionTile(for: [.whiteboard, .printer], from: origin)
        case .breakSpot:
            return bestInteractionTile(for: [.coffeeMachine, .sofa, .roundTable], from: origin)
        case .seat:
            return nil
        }
    }

    private func bestInteractionTile(for types: [FurnitureType], from origin: TileCoord, avoiding recentTiles: [TileCoord] = []) -> TileCoord? {
        var bestScores: [TileCoord: Int] = [:]
        for (priority, type) in types.enumerated() {
            for furniture in map.furniture where furniture.type == type {
                for tile in interactionTiles(for: furniture) where map.isWalkable(tile) {
                    let score = interactionScore(
                        for: tile,
                        from: origin,
                        priority: priority,
                        recentTiles: recentTiles
                    )
                    bestScores[tile] = min(bestScores[tile] ?? score, score)
                }
            }
        }

        let candidates = bestScores
            .map { (tile: $0.key, score: $0.value) }
            .sorted { lhs, rhs in
                if lhs.score != rhs.score { return lhs.score < rhs.score }
                return lhs.tile.distance(to: origin) < rhs.tile.distance(to: origin)
            }

        for candidate in candidates {
            if candidate.tile == origin { return candidate.tile }
            let path = map.findPath(from: origin, to: candidate.tile)
            if !path.isEmpty { return candidate.tile }
        }
        return nil
    }

    private func interactionTiles(for furniture: FurniturePlacement) -> [TileCoord] {
        let left = TileCoord(col: furniture.position.col - 1, row: furniture.position.row + max(0, furniture.size.h / 2))
        let right = TileCoord(col: furniture.position.col + furniture.size.w, row: furniture.position.row + max(0, furniture.size.h / 2))
        let top = TileCoord(col: furniture.position.col + max(0, furniture.size.w / 2), row: furniture.position.row - 1)
        let bottom = TileCoord(col: furniture.position.col + max(0, furniture.size.w / 2), row: furniture.position.row + furniture.size.h)
        let bottomLeft = TileCoord(col: furniture.position.col, row: furniture.position.row + furniture.size.h)
        let bottomRight = TileCoord(col: furniture.position.col + furniture.size.w - 1, row: furniture.position.row + furniture.size.h)

        switch furniture.type {
        case .whiteboard, .pictureFrame, .clock:
            return [bottom, bottomLeft, bottomRight]
        case .bookshelf:
            return [bottom, left, right]
        case .roundTable:
            return [top, bottom, left, right]
        case .printer, .waterCooler, .coffeeMachine:
            return [left, right, bottom]
        case .sofa:
            return [bottom, left, right]
        default:
            return [top, bottom, left, right]
        }
    }

    private func facingForPurpose(_ purpose: OfficeDestinationPurpose, from coord: TileCoord) -> Direction {
        let watchedTypes: [FurnitureType]
        switch purpose {
        case .thinking, .error:
            watchedTypes = [.whiteboard, .printer]
        case .searching, .reading:
            watchedTypes = [.bookshelf, .roundTable]
        case .breakSpot:
            watchedTypes = [.coffeeMachine, .sofa, .roundTable]
        case .seat:
            watchedTypes = []
        }

        guard
            let furniture = map.furniture
                .lazy
                .filter({ watchedTypes.contains($0.type) })
                .min(by: { center(of: $0).distance(to: coord) < center(of: $1).distance(to: coord) })
        else {
            return .down
        }

        let fc = center(of: furniture)
        let dx = fc.col - coord.col
        let dy = fc.row - coord.row
        if abs(dx) > abs(dy) {
            return dx > 0 ? .right : .left
        }
        return dy > 0 ? .down : .up
    }

    private func center(of furniture: FurniturePlacement) -> TileCoord {
        TileCoord(
            col: furniture.position.col + max(0, furniture.size.w / 2),
            row: furniture.position.row + max(0, furniture.size.h / 2)
        )
    }

    // MARK: - Seat Management

    func assignSeat(forGroupKey groupKey: String, representativeTabId: String) -> Seat? {
        if let seatId = seatAssignmentsByGroup[groupKey] {
            if let index = map.seats.firstIndex(where: { $0.id == seatId }) {
                map.seats[index].assignedTabId = representativeTabId
                return map.seats[index]
            }
            seatAssignmentsByGroup.removeValue(forKey: groupKey)
        }

        for index in 0..<map.seats.count {
            if map.seats[index].assignedTabId == nil {
                map.seats[index].assignedTabId = representativeTabId
                seatAssignmentsByGroup[groupKey] = map.seats[index].id
                return map.seats[index]
            }
        }
        return nil
    }

    func releaseSeat(forGroupKey groupKey: String) {
        guard let seatId = seatAssignmentsByGroup.removeValue(forKey: groupKey),
              let index = map.seats.firstIndex(where: { $0.id == seatId }) else { return }
        map.seats[index].assignedTabId = nil
    }

    private func seatGroupKey(for tab: TerminalTab) -> String {
        if let groupId = tab.groupId, !groupId.isEmpty {
            return "group:\(groupId)"
        }
        return "solo:\(tab.id)"
    }

    private func seatGroupKey(forRosterCharacter character: WorkerCharacter) -> String {
        "idle:\(character.id)"
    }

    private func officeCharacterKey(for tab: TerminalTab) -> String {
        tab.characterId ?? tab.id
    }

    private func orderedTabsForSeatGroup(_ tabs: [TerminalTab]) -> [TerminalTab] {
        tabs.sorted { lhs, rhs in
            let lhsRank = characters[officeCharacterKey(for: lhs)]?.groupIndex ?? Int.max
            let rhsRank = characters[officeCharacterKey(for: rhs)]?.groupIndex ?? Int.max
            if lhsRank != rhsRank { return lhsRank < rhsRank }

            let lhsActivity = activityPriority(for: lhs)
            let rhsActivity = activityPriority(for: rhs)
            if lhsActivity != rhsActivity { return lhsActivity < rhsActivity }

            return lhs.workerName.localizedCaseInsensitiveCompare(rhs.workerName) == .orderedAscending
        }
    }

    private func activityPriority(for tab: TerminalTab) -> Int {
        if tab.isProcessing { return 0 }
        if tab.claudeActivity != .idle { return 1 }
        return 2
    }

    private func monitorRepresentativeTabId(for tabs: [TerminalTab]) -> String {
        tabs.sorted { lhs, rhs in
            let lhsPriority = activityPriority(for: lhs)
            let rhsPriority = activityPriority(for: rhs)
            if lhsPriority != rhsPriority { return lhsPriority < rhsPriority }
            let lhsRank = characters[officeCharacterKey(for: lhs)]?.groupIndex ?? Int.max
            let rhsRank = characters[officeCharacterKey(for: rhs)]?.groupIndex ?? Int.max
            if lhsRank != rhsRank { return lhsRank < rhsRank }
            return lhs.workerName.localizedCaseInsensitiveCompare(rhs.workerName) == .orderedAscending
        }
        .first?.id ?? tabs.first?.id ?? ""
    }

    private func workstationTile(for character: OfficeCharacter, seat: Seat) -> TileCoord {
        let tiles = workstationTiles(for: seat, groupSize: max(character.groupSize, 1))
        return tileForSeatGroupMember(index: character.groupIndex, from: tiles, fallbackSeat: seat)
    }

    private func workstationTiles(for seat: Seat, groupSize: Int) -> [TileCoord] {
        guard groupSize > 1 else { return [seat.position] }

        var tiles: [TileCoord] = [seat.position]
        var seen: Set<TileCoord> = [seat.position]
        let reservedSeatTiles = Set(map.seats.map(\.position)).subtracting([seat.position])

        for offset in relativeCompanionOffsets {
            let candidate = seat.position + rotate(offset: offset, for: seat.facing)
            guard isInBounds(candidate), map.isWalkable(candidate) else { continue }
            if reservedSeatTiles.contains(candidate) { continue }
            if seen.insert(candidate).inserted {
                tiles.append(candidate)
            }
            if tiles.count >= groupSize {
                return tiles
            }
        }

        return tiles
    }

    private func tileForSeatGroupMember(index: Int, from tiles: [TileCoord], fallbackSeat: Seat) -> TileCoord {
        guard !tiles.isEmpty else { return fallbackSeat.position }
        let clamped = min(max(index, 0), tiles.count - 1)
        return tiles[clamped]
    }

    private var relativeCompanionOffsets: [TileCoord] {
        [
            TileCoord(col: -1, row: 0),
            TileCoord(col: 1, row: 0),
            TileCoord(col: -1, row: 1),
            TileCoord(col: 1, row: 1),
            TileCoord(col: 0, row: 1),
            TileCoord(col: -2, row: 0),
            TileCoord(col: 2, row: 0),
            TileCoord(col: -2, row: 1),
            TileCoord(col: 2, row: 1),
            TileCoord(col: 0, row: 2),
            TileCoord(col: -1, row: 2),
            TileCoord(col: 1, row: 2)
        ]
    }

    private func rotate(offset: TileCoord, for direction: Direction) -> TileCoord {
        switch direction {
        case .up:
            return offset
        case .right:
            return TileCoord(col: -offset.row, row: offset.col)
        case .down:
            return TileCoord(col: -offset.col, row: -offset.row)
        case .left:
            return TileCoord(col: offset.row, row: -offset.col)
        }
    }

    private func isInBounds(_ coord: TileCoord) -> Bool {
        coord.col >= 0 && coord.col < map.cols && coord.row >= 0 && coord.row < map.rows
    }

    private func fallbackSpawnTile(for index: Int) -> TileCoord {
        let base = TileCoord(col: 14, row: 17)
        if index == 0 { return base }
        let offset = relativeCompanionOffsets[min(index - 1, relativeCompanionOffsets.count - 1)]
        let candidate = base + offset
        return isInBounds(candidate) ? candidate : base
    }

    private func idleRosterFallbackTile(for index: Int) -> TileCoord {
        let preferredTiles = mergedTiles(socialHotspotTiles, pantryAndMeetingTiles, walkableTiles)
        guard !preferredTiles.isEmpty else { return fallbackSpawnTile(for: index) }
        let stride = max(3, preferredTiles.count / 4)
        return preferredTiles[(index * stride) % preferredTiles.count]
    }

    private func orderedHiredRoster() -> [WorkerCharacter] {
        registry.hiredCharacters.sorted { lhs, rhs in
            let lhsDate = lhs.hiredAt ?? .distantPast
            let rhsDate = rhs.hiredAt ?? .distantPast
            if lhsDate != rhsDate { return lhsDate < rhsDate }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    private func normalizedHex(_ hex: String) -> String {
        hex.replacingOccurrences(of: "#", with: "").uppercased()
    }

    private func colorToHex(_ color: Color) -> String {
        guard let converted = NSColor(color).usingColorSpace(.sRGB) else { return "5B9CF6" }
        return String(
            format: "%02X%02X%02X",
            Int(converted.redComponent * 255),
            Int(converted.greenComponent * 255),
            Int(converted.blueComponent * 255)
        )
    }

    // MARK: - Helpers

    private func seat(for character: OfficeCharacter) -> Seat? {
        guard let seatId = character.seatId else { return nil }
        return map.seats.first(where: { $0.id == seatId })
    }

    private func snapToSeat(_ ch: inout OfficeCharacter, seat: Seat) {
        let seatTile = workstationTile(for: ch, seat: seat)
        let center = tileCenter(seatTile)
        ch.pixelX = center.x
        ch.pixelY = center.y
        ch.tileCol = seatTile.col
        ch.tileRow = seatTile.row
        ch.state = .typing
        ch.dir = seat.facing
        ch.destinationPurpose = .seat
        ch.targetTile = seatTile
        ch.moveProgress = 0
        ch.frame = 0
    }

    private func tileCenter(_ coord: TileCoord) -> (x: CGFloat, y: CGFloat) {
        (
            CGFloat(coord.col) * OfficeConstants.tileSize + OfficeConstants.tileSize / 2,
            CGFloat(coord.row) * OfficeConstants.tileSize + OfficeConstants.tileSize / 2
        )
    }

    private func seatRestDuration() -> Double {
        Double.random(in: OfficeConstants.relaxedSeatRestMin...OfficeConstants.relaxedSeatRestMax)
    }

    private func wanderPauseDuration() -> Double {
        Double.random(in: OfficeConstants.relaxedWanderPauseMin...OfficeConstants.relaxedWanderPauseMax)
    }

    private func wanderMoveLimit() -> Int {
        Int.random(in: OfficeConstants.relaxedWanderMovesMin...OfficeConstants.relaxedWanderMovesMax)
    }

    private func socialInteractionDuration() -> Double {
        Double.random(in: OfficeConstants.socialInteractionMin...OfficeConstants.socialInteractionMax)
    }

    private func socialCooldownDuration() -> Double {
        Double.random(in: OfficeConstants.socialCooldownMin...OfficeConstants.socialCooldownMax)
    }

    private func advanceAmbientPresence(id: String, character ch: inout OfficeCharacter, dt: Double) {
        if ch.socialCooldown > 0 {
            ch.socialCooldown = max(0, ch.socialCooldown - dt)
        }

        guard ch.socialTimer > 0 else { return }

        if ch.isActive || isWalkingState(ch.state) {
            clearSocialState(&ch)
            return
        }

        guard let partnerKey = ch.socialPartnerKey,
              let partner = characters[partnerKey],
              partner.socialPartnerKey == id,
              partner.socialTimer > 0,
              !partner.isActive,
              !isWalkingState(partner.state),
              ch.tileCoord.distance(to: partner.tileCoord) <= 4 else {
            clearSocialState(&ch)
            return
        }

        ch.socialTimer = max(0, ch.socialTimer - dt)
        if let focusTile = ch.socialFocusTile {
            face(&ch, toward: focusTile)
        } else {
            face(&ch, toward: partner.tileCoord)
        }
        if ch.socialTimer <= 0 {
            clearSocialState(&ch)
        }
    }

    private func updateAmbientInteractions() {
        guard socialEventCooldown <= 0 else { return }

        let activeSocialParticipants = characters.values.filter { $0.socialTimer > 0 }.count
        guard activeSocialParticipants < 4 else { return }

        let candidates = characters
            .filter { canStartSocialInteraction($0.value) }
            .map { (id: $0.key, character: $0.value) }

        guard candidates.count >= 2 else { return }

        var bestPair: (lhs: String, rhs: String, score: Int)?

        for lhsIndex in 0..<(candidates.count - 1) {
            let lhs = candidates[lhsIndex]
            for rhsIndex in (lhsIndex + 1)..<candidates.count {
                let rhs = candidates[rhsIndex]
                let distance = lhs.character.tileCoord.distance(to: rhs.character.tileCoord)
                guard distance > 0 && distance <= 4 else { continue }

                let lhsZone = map.zoneAt(lhs.character.tileCoord)
                let rhsZone = map.zoneAt(rhs.character.tileCoord)
                guard lhsZone == rhsZone || distance <= 2 else { continue }

                var score = distance
                if lhsZone == .meetingRoom { score -= 3 }
                if lhsZone == .pantry { score -= 2 }
                if lhs.character.state == .onBreak || rhs.character.state == .onBreak { score -= 1 }

                if let currentBest = bestPair, currentBest.score <= score {
                    continue
                }
                bestPair = (lhs.id, rhs.id, score)
            }
        }

        guard let bestPair else { return }
        startSocialInteraction(between: bestPair.lhs, and: bestPair.rhs)
    }

    private func canStartSocialInteraction(_ character: OfficeCharacter) -> Bool {
        guard !character.isActive,
              character.socialTimer <= 0,
              character.socialCooldown <= 0,
              !isWalkingState(character.state) else { return false }

        let zone = map.zoneAt(character.tileCoord)
        if character.state == .onBreak || character.state == .wanderPause {
            return true
        }
        return zone == .pantry || zone == .meetingRoom || zone == .hallway
    }

    private func startSocialInteraction(between lhsId: String, and rhsId: String) {
        guard var lhs = characters[lhsId], var rhs = characters[rhsId] else { return }

        let scenario = socialScenario(for: lhs, rhs)
        let duration = socialInteractionDuration()

        applySocialInteraction(&lhs, partnerId: rhsId, role: 0, mode: scenario.mode, duration: duration, focusTile: scenario.focusTile)
        applySocialInteraction(&rhs, partnerId: lhsId, role: 1, mode: scenario.mode, duration: duration, focusTile: scenario.focusTile)

        if let focusTile = scenario.focusTile {
            face(&lhs, toward: focusTile)
            face(&rhs, toward: focusTile)
        } else {
            face(&lhs, toward: rhs.tileCoord)
            face(&rhs, toward: lhs.tileCoord)
        }

        characters[lhsId] = lhs
        characters[rhsId] = rhs
        socialEventCooldown = Double.random(in: OfficeConstants.socialEventCooldownMin...OfficeConstants.socialEventCooldownMax)
    }

    private func applySocialInteraction(_ ch: inout OfficeCharacter,
                                        partnerId: String,
                                        role: Int,
                                        mode: OfficeSocialMode,
                                        duration: Double,
                                        focusTile: TileCoord?) {
        ch.socialMode = mode
        ch.socialRole = role
        ch.socialTimer = duration
        ch.socialPartnerKey = partnerId
        ch.socialFocusTile = focusTile
        if let focusTile {
            rememberBreakTarget(focusTile, for: &ch)
        }
        if ch.state != .onBreak {
            ch.state = .wanderPause
            ch.wanderTimer = duration
        }
    }

    private func socialScenario(for lhs: OfficeCharacter, _ rhs: OfficeCharacter) -> (mode: OfficeSocialMode, focusTile: TileCoord?) {
        let zone = map.zoneAt(lhs.tileCoord) ?? map.zoneAt(rhs.tileCoord)
        let recentTiles = lhs.recentBreakTargets + rhs.recentBreakTargets

        if zone == .pantry,
           let focusTile = bestInteractionTile(for: [.coffeeMachine, .waterCooler], from: lhs.tileCoord, avoiding: recentTiles),
           max(lhs.tileCoord.distance(to: focusTile), rhs.tileCoord.distance(to: focusTile)) <= 5 {
            return (.coffee, focusTile)
        }

        if zone == .meetingRoom,
           let focusTile = bestInteractionTile(for: [.roundTable, .whiteboard], from: lhs.tileCoord, avoiding: recentTiles),
           max(lhs.tileCoord.distance(to: focusTile), rhs.tileCoord.distance(to: focusTile)) <= 5 {
            return (.brainstorming, focusTile)
        }

        if lhs.tileCoord.distance(to: rhs.tileCoord) <= 1, Int.random(in: 0..<100) < 35 {
            return (.highFive, nil)
        }

        let options: [OfficeSocialMode]
        switch zone {
        case .pantry:
            options = [.chatting, .greeting, .highFive]
        case .meetingRoom:
            options = [.brainstorming, .chatting, .greeting]
        default:
            options = [.greeting, .chatting, .highFive]
        }
        return (options.randomElement() ?? .chatting, nil)
    }

    private func clearSocialState(_ ch: inout OfficeCharacter, resumeMotion: Bool = true) {
        let hadSocialState = ch.socialMode != nil || ch.socialTimer > 0 || ch.socialPartnerKey != nil || ch.socialFocusTile != nil
        ch.socialMode = nil
        ch.socialRole = 0
        ch.socialTimer = 0
        ch.socialPartnerKey = nil
        ch.socialFocusTile = nil

        guard hadSocialState else { return }

        ch.socialCooldown = max(ch.socialCooldown, socialCooldownDuration())
        guard resumeMotion else { return }

        if let seat = seat(for: ch),
           ch.usesSeatPose,
           ch.destinationPurpose == .seat,
           ch.tileCoord == workstationTile(for: ch, seat: seat) {
            ch.state = .seatRest
            ch.seatTimer = seatRestDuration()
            ch.dir = seat.facing
        } else {
            ch.state = .wanderPause
            ch.wanderTimer = wanderPauseDuration()
        }
    }

    private func face(_ ch: inout OfficeCharacter, toward target: TileCoord) {
        let dx = target.col - ch.tileCol
        let dy = target.row - ch.tileRow
        if abs(dx) > abs(dy) {
            ch.dir = dx > 0 ? .right : .left
        } else if dy != 0 {
            ch.dir = dy > 0 ? .down : .up
        }
    }

    private func isWalkingState(_ state: OfficeCharacterState) -> Bool {
        switch state {
        case .walkingTo, .wandering:
            return true
        default:
            return false
        }
    }

    private func bestBreakTarget(for character: OfficeCharacter) -> TileCoord? {
        let preferredTiles: [TileCoord]
        if !character.isActive {
            preferredTiles = mergedTiles(socialHotspotTiles, pantryAndMeetingTiles, walkableTiles)
        } else if !pantryAndMeetingTiles.isEmpty {
            preferredTiles = mergedTiles(pantryAndMeetingTiles, walkableTiles)
        } else {
            preferredTiles = walkableTiles
        }

        let candidates = preferredTiles
            .filter { $0 != character.tileCoord }
            .map { tile in
                (
                    tile: tile,
                    score: breakTargetScore(for: tile, character: character)
                )
            }
            .sorted { lhs, rhs in
                if lhs.score != rhs.score { return lhs.score < rhs.score }
                return lhs.tile.distance(to: character.tileCoord) < rhs.tile.distance(to: character.tileCoord)
            }

        for candidate in candidates {
            let path = map.findPath(from: character.tileCoord, to: candidate.tile)
            if !path.isEmpty {
                return candidate.tile
            }
        }
        return nil
    }

    private func breakTargetScore(for tile: TileCoord, character: OfficeCharacter) -> Int {
        let distance = character.tileCoord.distance(to: tile)
        let congestionPenalty = tileCongestion(at: tile) * 24
        let recentPenalty = recentTilePenalty(for: tile, recentTiles: character.recentBreakTargets)
        let zoneBonus = preferredBreakZoneBonus(for: tile)
        let hotspotBonus = socialHotspotTiles.contains(tile) ? -4 : 0
        let jitter = Int.random(in: 0...9)
        return distance * 2 + congestionPenalty + recentPenalty + zoneBonus + hotspotBonus + jitter
    }

    private func interactionScore(for tile: TileCoord,
                                  from origin: TileCoord,
                                  priority: Int,
                                  recentTiles: [TileCoord]) -> Int {
        let distance = origin.distance(to: tile)
        let congestionPenalty = tileCongestion(at: tile) * 18
        let recentPenalty = recentTilePenalty(for: tile, recentTiles: recentTiles)
        let jitter = Int.random(in: 0...4)
        return priority * 100 + distance * 3 + congestionPenalty + recentPenalty + jitter
    }

    private func preferredBreakZoneBonus(for tile: TileCoord) -> Int {
        guard let zone = map.zoneAt(tile) else { return 0 }
        switch zone {
        case .pantry:
            return -8
        case .meetingRoom:
            return -6
        case .hallway:
            return -2
        case .mainOffice:
            return 0
        }
    }

    private func recentTilePenalty(for tile: TileCoord, recentTiles: [TileCoord]) -> Int {
        guard let index = recentTiles.lastIndex(of: tile) else { return 0 }
        let recency = recentTiles.count - index
        return recency * 22
    }

    private func tileCongestion(at tile: TileCoord) -> Int {
        characters.values.reduce(into: 0) { partial, character in
            if character.tileCoord == tile {
                partial += 1
            }
            if character.targetTile == tile, character.tileCoord != tile {
                partial += 1
            }
            if character.socialFocusTile == tile {
                partial += 1
            }
        }
    }

    private func rememberBreakTarget(_ tile: TileCoord, for ch: inout OfficeCharacter) {
        ch.recentBreakTargets.removeAll { $0 == tile }
        ch.recentBreakTargets.append(tile)
        if ch.recentBreakTargets.count > OfficeConstants.recentBreakTargetLimit {
            ch.recentBreakTargets.removeFirst(ch.recentBreakTargets.count - OfficeConstants.recentBreakTargetLimit)
        }
    }

    private func mergedTiles(_ groups: [TileCoord]...) -> [TileCoord] {
        var seen: Set<TileCoord> = []
        var merged: [TileCoord] = []
        for group in groups {
            for tile in group where seen.insert(tile).inserted {
                merged.append(tile)
            }
        }
        return merged
    }
}
