import SwiftUI
import DesignSystem
import OrderedCollections

// ═══════════════════════════════════════════════════
// MARK: - Overlays (Speech Bubbles, Labels)
// ═══════════════════════════════════════════════════

extension OfficeSpriteRenderer {

    internal func drawParallelTaskBubble(
        _ ctx: GraphicsContext,
        tab: TerminalTab,
        anchorX: CGFloat,
        anchorY: CGFloat
    ) {
        let tasks = tab.officeParallelTasks
        guard !tasks.isEmpty else { return }
        let hasRunning = tasks.contains { $0.state == .running }
        let hasFailure = tasks.contains { $0.state == .failed }

        let visibleTasks = Array(tasks.prefix(3))
        let chipWidth: CGFloat = 18
        let gap: CGFloat = 4
        let extraCount = max(0, tasks.count - visibleTasks.count)
        let countWidth = extraCount > 0 ? 18 : 0
        let chipCount = CGFloat(visibleTasks.count)
        let gapCount = CGFloat(max(0, visibleTasks.count - 1))
        let chipsWidth = chipCount * chipWidth
        let gapsWidth = gapCount * gap
        let bubbleWidth = chipsWidth + gapsWidth + CGFloat(countWidth) + 18
        let bubbleHeight: CGFloat = 28
        let rect = CGRect(x: anchorX - bubbleWidth / 2, y: anchorY, width: bubbleWidth, height: bubbleHeight)
        let bubbleBG = dark ? Color(hex: "101624") : Color.white

        var tail = Path()
        tail.move(to: CGPoint(x: anchorX - 3, y: rect.maxY))
        tail.addLine(to: CGPoint(x: anchorX, y: rect.maxY + 4))
        tail.addLine(to: CGPoint(x: anchorX + 3, y: rect.maxY))
        ctx.fill(tail, with: .color(bubbleBG.opacity(0.96)))

        let bubblePath = Path(roundedRect: rect, cornerRadius: 5)
        ctx.fill(bubblePath, with: .color(bubbleBG.opacity(0.96)))
        ctx.stroke(bubblePath, with: .color(Theme.purple.opacity(0.4)), lineWidth: 0.7)

        ctx.draw(
            Text("PAR")
                .font(.system(size: 4.8, weight: .heavy, design: .monospaced))
                .foregroundColor(Theme.purple.opacity(0.95)),
            at: CGPoint(x: rect.minX + 10, y: rect.minY + 6.5)
        )

        if hasRunning {
            let pulseCenter = CGPoint(x: rect.maxX - 11, y: rect.minY + 6.5)
            let pulseRadius = CGFloat(1.8 + CGFloat((frame / 3) % 3))
            ctx.stroke(
                Path(ellipseIn: CGRect(
                    x: pulseCenter.x - pulseRadius,
                    y: pulseCenter.y - pulseRadius,
                    width: pulseRadius * 2,
                    height: pulseRadius * 2
                )),
                with: .color(Theme.cyan.opacity(0.7)),
                lineWidth: 0.5
            )
            ctx.fill(
                Path(ellipseIn: CGRect(x: pulseCenter.x - 1, y: pulseCenter.y - 1, width: 2, height: 2)),
                with: .color(Theme.cyan.opacity(0.95))
            )
        } else if hasFailure {
            ctx.draw(
                Text("!")
                    .font(.system(size: 5.2, weight: .heavy, design: .monospaced))
                    .foregroundColor(Theme.red.opacity(0.95)),
                at: CGPoint(x: rect.maxX - 11, y: rect.minY + 6.5)
            )
        } else {
            ctx.draw(
                Text("OK")
                    .font(.system(size: 4.8, weight: .heavy, design: .monospaced))
                    .foregroundColor(Theme.green.opacity(0.95)),
                at: CGPoint(x: rect.maxX - 12, y: rect.minY + 6.5)
            )
        }

        for (index, task) in visibleTasks.enumerated() {
            let chipX = rect.minX + 8 + CGFloat(index) * (chipWidth + gap)
            let chipRect = CGRect(x: chipX, y: rect.minY + 11, width: chipWidth, height: 13)
            drawParallelTaskChip(ctx, task: task, rect: chipRect)
        }

        if extraCount > 0 {
            let countX = rect.maxX - 11
            ctx.draw(
                Text("+\(extraCount)")
                    .font(.system(size: 4.8, weight: .heavy, design: .monospaced))
                    .foregroundColor(Theme.textDim),
                at: CGPoint(x: countX, y: rect.midY + 2)
            )
        }
    }

    internal func drawParallelTaskChip(
        _ ctx: GraphicsContext,
        task: ParallelTaskRecord,
        rect: CGRect
    ) {
        let border = task.state.tint.opacity(0.55)
        let background = (dark ? Color(hex: "171E2D") : Color(hex: "F8F9FD")).opacity(0.95)
        let chipPath = Path(roundedRect: rect, cornerRadius: 3)
        ctx.fill(chipPath, with: .color(background))
        ctx.stroke(chipPath, with: .color(border), lineWidth: 0.6)

        let rosterCharacter = CharacterRegistry.shared.character(with: task.assigneeCharacterId)
        let workerColor = rosterCharacter.map { Color(hex: Self.normalizedHex($0.shirtColor)) } ?? task.state.tint
        let roleLabel = rosterCharacter?.jobRole.shortLabel ?? String(task.label.prefix(2)).uppercased()
        let avatarRect = CGRect(x: rect.minX + 2.2, y: rect.minY + 2.4, width: rect.width - 6, height: 7.2)
        let avatarPath = Path(roundedRect: avatarRect, cornerRadius: 2)
        ctx.fill(avatarPath, with: .color(workerColor.opacity(dark ? 0.24 : 0.18)))
        ctx.stroke(avatarPath, with: .color(workerColor.opacity(0.5)), lineWidth: 0.5)
        ctx.draw(
            Text(roleLabel)
                .font(.system(size: 4.4, weight: .heavy, design: .monospaced))
                .foregroundColor(workerColor.opacity(0.96)),
            at: CGPoint(x: avatarRect.midX, y: avatarRect.midY)
        )

        let statusRect = CGRect(x: rect.minX + 2, y: rect.maxY - 2.3, width: rect.width - 4, height: 1.5)
        ctx.fill(Path(roundedRect: statusRect, cornerRadius: 1),
                 with: .color(task.state.tint.opacity(task.state == .running ? 0.88 : 0.74)))

        let iconOrigin = CGPoint(x: rect.maxX - 4, y: rect.minY + 3)
        switch task.state {
        case .completed:
            var check = Path()
            check.move(to: CGPoint(x: iconOrigin.x - 2.5, y: iconOrigin.y + 0.8))
            check.addLine(to: CGPoint(x: iconOrigin.x - 1.2, y: iconOrigin.y + 2.2))
            check.addLine(to: CGPoint(x: iconOrigin.x + 1.6, y: iconOrigin.y - 0.9))
            ctx.stroke(check, with: .color(Theme.green.opacity(0.92)), lineWidth: 0.7)
        case .failed:
            var crossA = Path()
            crossA.move(to: CGPoint(x: iconOrigin.x - 2, y: iconOrigin.y - 1.5))
            crossA.addLine(to: CGPoint(x: iconOrigin.x + 1.6, y: iconOrigin.y + 1.6))
            var crossB = Path()
            crossB.move(to: CGPoint(x: iconOrigin.x + 1.6, y: iconOrigin.y - 1.5))
            crossB.addLine(to: CGPoint(x: iconOrigin.x - 2, y: iconOrigin.y + 1.6))
            ctx.stroke(crossA, with: .color(Theme.red.opacity(0.92)), lineWidth: 0.65)
            ctx.stroke(crossB, with: .color(Theme.red.opacity(0.92)), lineWidth: 0.65)
        case .running:
            let dotBaseX = rect.maxX - 5.8
            let dotY = rect.minY + 2.2
            for index in 0..<3 {
                let activeIndex = (frame / 4) % 3
                let opacity = activeIndex == index ? 0.95 : 0.35
                ctx.fill(
                    Path(ellipseIn: CGRect(x: dotBaseX + CGFloat(index) * 1.6, y: dotY, width: 0.9, height: 0.9)),
                    with: .color(Theme.cyan.opacity(opacity))
                )
            }
        }
    }

    func drawOverlays(_ ctx: GraphicsContext, viewScale: CGFloat = 1.0) {
        // 축소 시 라벨 간소화: scale 기준으로 단계적 숨김
        let showNameLabels = viewScale >= 2.2
        let showFileLabels = viewScale >= 2.2
        let showToolBadges = viewScale >= 1.6
        func hasPrimaryBubble(for state: OfficeCharacterState) -> Bool {
            switch state {
            case .thinking, .typing, .reading, .searching, .celebrating, .error, .onBreak:
                return true
            default:
                return false
            }
        }

        func socialBubble(for char: OfficeCharacter) -> (text: String, color: Color)? {
            guard let mode = char.socialMode, char.socialTimer > 0 else { return nil }
            let phase = (frame / 10) % 4  // 4 phases for more variety
            let role = char.socialRole

            let texts: [String]
            let color: Color

            switch mode {
            case .greeting:
                color = Color(hex: "5AF078")
                texts = role == 0 ? Self.greetTexts0 : Self.greetTexts1
            case .chatting:
                color = Color(hex: "78C8F0")
                texts = role == 0 ? Self.chatTexts0 : Self.chatTexts1
            case .brainstorming:
                color = Color(hex: "C88AF0")
                texts = role == 0 ? Self.brainTexts0 : Self.brainTexts1
            case .coffee:
                color = Color(hex: "E8A850")
                texts = role == 0 ? Self.coffeeTexts0 : Self.coffeeTexts1
            case .highFive:
                color = Color(hex: "F0D850")
                texts = role == 0 ? Self.highFiveTexts0 : Self.highFiveTexts1
            }

            let text = texts[phase % texts.count]
            return (text, color)
        }

        func activityReaction(for char: OfficeCharacter) -> (text: String, color: Color)? {
            // Only show occasionally (every ~3 seconds, visible for 1.5 seconds)
            let cycle = frame % Int(OfficeConstants.fps * 6)
            guard cycle < Int(OfficeConstants.fps * 1.5) else { return nil }

            // Don't show during social interactions
            guard char.socialMode == nil else { return nil }

            switch char.state {
            case .typing:
                return (Self.typingReactions[frame / 18 % Self.typingReactions.count], Color(hex: "5AF078"))
            case .reading:
                return (Self.readingReactions[frame / 18 % Self.readingReactions.count], Color(hex: "78C8F0"))
            case .searching:
                return (Self.searchingReactions[frame / 18 % Self.searchingReactions.count], Color(hex: "C88AF0"))
            case .error:
                return (Self.errorReactions[frame / 12 % Self.errorReactions.count], Color(hex: "F06868"))
            case .thinking:
                return (Self.thinkingReactions[frame / 24 % Self.thinkingReactions.count], Color(hex: "E8A850"))
            case .celebrating:
                return (Self.celebratingReactions[frame / 12 % Self.celebratingReactions.count], Color(hex: "F0D850"))
            case .sittingIdle:
                // Only idle characters sometimes show reactions (rarely)
                guard (frame / 36 + char.tileCol * 7) % 20 == 0 else { return nil }
                return (Self.idleReactions[(frame / 36 + char.tileCol) % Self.idleReactions.count], Color(hex: "8690a4"))
            default:
                return nil
            }
        }

        func drawHighFiveSparkIfNeeded(for char: OfficeCharacter) {
            guard char.socialMode == .highFive,
                  char.socialRole == 0,
                  char.socialTimer > 0,
                  let partnerKey = char.socialPartnerKey,
                  let partner = characters[partnerKey],
                  partner.socialMode == .highFive,
                  partner.socialTimer > 0 else { return }

            let sparkCenter = CGPoint(
                x: (char.pixelX + partner.pixelX) / 2,
                y: min(char.pixelY, partner.pixelY) - 18
            )
            let bgRect = CGRect(x: sparkCenter.x - 5.5, y: sparkCenter.y - 5.5, width: 11, height: 11)
            ctx.fill(
                Path(ellipseIn: bgRect),
                with: .color(Theme.yellow.opacity(dark ? 0.22 : 0.15))
            )
            ctx.draw(
                Text("*")
                    .font(.system(size: 7, weight: .black))
                    .foregroundColor(Theme.yellow.opacity(0.98)),
                at: sparkCenter
            )
        }

        func overlayBaseY(for char: OfficeCharacter) -> CGFloat {
            max(8, char.pixelY - 40)
        }

        func projectBadgeY(for char: OfficeCharacter, tab: TerminalTab, hasBubbleText: Bool) -> CGFloat {
            let baseY = overlayBaseY(for: char)
            if !tab.officeParallelTasks.isEmpty {
                return max(4, parallelBubbleAnchorY(for: char, hasBubbleText: hasBubbleText) - 12)
            }
            if hasBubbleText {
                return max(4, baseY - 14)
            }
            return max(4, baseY - 6)
        }

        func parallelBubbleAnchorY(for char: OfficeCharacter, hasBubbleText: Bool) -> CGFloat {
            let baseY = overlayBaseY(for: char)
            return max(4, hasBubbleText ? baseY - 46 : baseY - 32)
        }

        let projectLeads = characters.values
            .filter { $0.usesSeatPose }
            .sorted { $0.pixelY < $1.pixelY }

        for char in projectLeads {
            guard let tabId = char.tabId,
                  let tab = tabLookup[tabId] else { continue }
            guard tab.automationSourceTabId == nil else { continue }
            let hasBubbleText = socialBubble(for: char) != nil || hasPrimaryBubble(for: char.state)
            let label = String(tab.projectName.prefix(10))
            let badgeWidth = max(26, CGFloat(label.count) * 4.5 + 10)
            let badgeRect = CGRect(
                x: char.pixelX - badgeWidth / 2,
                y: projectBadgeY(for: char, tab: tab, hasBubbleText: hasBubbleText),
                width: badgeWidth,
                height: 8.5
            )
            let tint = projectTint(for: tab)
            ctx.fill(
                Path(roundedRect: badgeRect, cornerRadius: 2.5),
                with: .color((dark ? Color(hex: "0F1421") : Color.white).opacity(0.82))
            )
            ctx.stroke(
                Path(roundedRect: badgeRect, cornerRadius: 2.5),
                with: .color(tint.opacity(0.34)),
                lineWidth: 0.55
            )
            ctx.draw(
                Text(label)
                    .font(.system(size: 4.8, weight: .bold, design: .monospaced))
                    .foregroundColor(tint.opacity(0.95)),
                at: CGPoint(x: badgeRect.midX, y: badgeRect.midY)
            )
        }

        if let selectedFurnitureId,
           let furniture = map.furniture.first(where: { $0.id == selectedFurnitureId }) {
            let rect = CGRect(
                x: CGFloat(furniture.position.col) * 16 - 1,
                y: CGFloat(furniture.position.row) * 16 - 1,
                width: CGFloat(furniture.size.w) * 16 + 2,
                height: CGFloat(furniture.size.h) * 16 + 2
            )
            ctx.stroke(
                Path(roundedRect: rect, cornerRadius: 2),
                with: .color(Theme.yellow.opacity(0.9)),
                style: StrokeStyle(lineWidth: 1.2, dash: [2, 2])
            )
            ctx.fill(
                Path(roundedRect: rect.insetBy(dx: 1, dy: 1), cornerRadius: 2),
                with: .color(Theme.yellow.opacity(0.06))
            )
        }

        for (_, char) in characters {
            guard let tabId = char.tabId,
                  let tab = tabLookup[tabId] else {
                if !char.displayName.isEmpty {
                    let idleColor = Color(hex: Self.normalizedHex(char.accentColorHex))
                    ctx.draw(
                        Text(char.displayName)
                            .font(.system(size: 5, weight: .semibold, design: .monospaced))
                            .foregroundColor(idleColor.opacity(0.72)),
                        at: CGPoint(x: char.pixelX, y: char.pixelY + 6)
                    )
                    let roleLabel = char.jobRole.shortLabel
                    let roleWidth = max(16, CGFloat(roleLabel.count) * 4.2 + 6)
                    let roleRect = CGRect(x: char.pixelX - roleWidth / 2, y: max(4, overlayBaseY(for: char) - 3), width: roleWidth, height: 8)
                    ctx.fill(
                        Path(roundedRect: roleRect, cornerRadius: 2),
                        with: .color((dark ? Color(hex: "111625") : Color.white).opacity(0.82))
                    )
                    ctx.stroke(
                        Path(roundedRect: roleRect, cornerRadius: 2),
                        with: .color(idleColor.opacity(0.22)),
                        lineWidth: 0.45
                    )
                    ctx.draw(
                        Text(roleLabel)
                            .font(.system(size: 4.6, weight: .bold, design: .monospaced))
                            .foregroundColor(idleColor.opacity(0.82)),
                        at: CGPoint(x: roleRect.midX, y: roleRect.midY)
                    )
                }
                continue
            }
            let bx = char.pixelX
            let by = overlayBaseY(for: char)

            let bubbleText: String?
            let iconColor: Color
            let isSelected = selectedTabId == char.tabId
            let socialOverlay = socialBubble(for: char) ?? activityReaction(for: char)

            if let socialOverlay {
                bubbleText = socialOverlay.text
                iconColor = socialOverlay.color
            } else {
                switch char.state {
                case .thinking: bubbleText = String(repeating: ".", count: (frame/8%3)+1); iconColor = Theme.purple
                case .typing: bubbleText = ">"; iconColor = Theme.green
                case .reading: bubbleText = "R"; iconColor = Theme.accent
                case .searching: bubbleText = "?"; iconColor = Theme.cyan
                case .celebrating: bubbleText = "ok"; iconColor = Theme.green
                case .error: bubbleText = "!"; iconColor = Theme.red
                case .onBreak:
                    let z = String(repeating: "z", count: (frame/12%3)+1)
                    ctx.draw(Text(z).font(.system(size: 5, weight: .bold)).foregroundColor(Theme.textDim.opacity(0.4)),
                             at: CGPoint(x: bx + 8, y: by + sin(Double(frame)*0.1)*2))
                    bubbleText = nil; iconColor = .clear
                default: bubbleText = nil; iconColor = .clear
                }
            }

            if isSelected {
                ctx.fill(
                    Path(ellipseIn: CGRect(x: bx - 8, y: char.pixelY - 3.5, width: 16, height: 6)),
                    with: .color(tab.workerColor.opacity(dark ? 0.24 : 0.18))
                )
                ctx.stroke(
                    Path(ellipseIn: CGRect(x: bx - 9, y: char.pixelY - 4, width: 18, height: 7)),
                    with: .color(tab.workerColor.opacity(0.85)),
                    lineWidth: 1
                )
            }

            if let text = bubbleText {
                let bg = dark ? Color(hex: "1A2030") : Color.white
                let charWidths: CGFloat = text.unicodeScalars.reduce(0) { sum, scalar in
                    let v = scalar.value
                    if v > 0x2600 { return sum + 10 }
                    if v > 0x1100 { return sum + 8.5 }
                    return sum + 6
                }
                let bw: CGFloat = max(20, charWidths + 10)
                let bbx = bx - bw/2
                var tail = Path()
                tail.move(to: CGPoint(x: bx-2, y: by+13)); tail.addLine(to: CGPoint(x: bx, y: by+16)); tail.addLine(to: CGPoint(x: bx+2, y: by+13))
                ctx.fill(tail, with: .color(bg))
                ctx.fill(Path(roundedRect: CGRect(x: bbx, y: by, width: bw, height: 13), cornerRadius: 3), with: .color(bg))
                ctx.stroke(Path(roundedRect: CGRect(x: bbx, y: by, width: bw, height: 13), cornerRadius: 3), with: .color(iconColor.opacity(0.3)), lineWidth: 0.5)
                ctx.draw(Text(text).font(.system(size: 6, weight: .bold, design: .monospaced)).foregroundColor(iconColor),
                         at: CGPoint(x: bx, y: by+6.5))
            }

            drawHighFiveSparkIfNeeded(for: char)

            if !tab.officeParallelTasks.isEmpty {
                drawParallelTaskBubble(
                    ctx,
                    tab: tab,
                    anchorX: bx,
                    anchorY: parallelBubbleAnchorY(for: char, hasBubbleText: bubbleText != nil)
                )
            }

            if showToolBadges, let badge = tab.officeLatestToolBadge,
               !(badge.label == "DONE" && !tab.officeParallelTasks.isEmpty) {
                let badgeWidth = max(18, CGFloat(badge.label.count) * 4.4 + 8)
                let hasTopProjectBadge = tab.automationSourceTabId == nil && char.usesSeatPose
                let badgeY: CGFloat = (bubbleText != nil || hasTopProjectBadge || !tab.officeParallelTasks.isEmpty) ? by + 15 : by + 2
                let badgeX: CGFloat = (bubbleText != nil || hasTopProjectBadge || !tab.officeParallelTasks.isEmpty) ? bx - badgeWidth / 2 : bx + 9
                let badgeRect = CGRect(x: badgeX, y: badgeY, width: badgeWidth, height: 9)
                ctx.fill(Path(roundedRect: badgeRect, cornerRadius: 2.5),
                         with: .color((dark ? Color(hex: "111625") : Color.white).opacity(0.96)))
                ctx.stroke(Path(roundedRect: badgeRect, cornerRadius: 2.5),
                           with: .color(badge.tint.opacity(0.6)),
                           lineWidth: 0.6)
                ctx.draw(
                    Text(badge.label)
                        .font(.system(size: 5.4, weight: .heavy, design: .monospaced))
                        .foregroundColor(badge.tint),
                    at: CGPoint(x: badgeRect.midX, y: badgeRect.midY)
                )
            }

            if showFileLabels, let fileName = tab.officeLatestFileName,
               (isSelected || tab.claudeActivity == .writing) {
                let fileLabel = fileName.prefix(10)
                let fileWidth = max(24, CGFloat(fileLabel.count) * 4.1 + 8)
                let fileRect = CGRect(x: bx - fileWidth / 2, y: char.pixelY + 8, width: fileWidth, height: 8.5)
                ctx.fill(Path(roundedRect: fileRect, cornerRadius: 2),
                         with: .color((dark ? Color(hex: "0F1421") : Color.white).opacity(0.86)))
                ctx.stroke(Path(roundedRect: fileRect, cornerRadius: 2),
                           with: .color(Theme.green.opacity(0.26)),
                           lineWidth: 0.45)
                ctx.draw(
                    Text(String(fileLabel))
                        .font(.system(size: 4.8, weight: .bold, design: .monospaced))
                        .foregroundColor(Theme.green.opacity(0.92)),
                    at: CGPoint(x: fileRect.midX, y: fileRect.midY)
                )
            }

            if showNameLabels, tab.claudeActivity != .idle || tab.isProcessing || char.state == .onBreak || char.socialTimer > 0 || isSelected {
                ctx.draw(Text(tab.workerName).font(.system(size: 5, weight: .semibold, design: .monospaced))
                    .foregroundColor(tab.workerColor.opacity(isSelected ? 1 : 0.8)), at: CGPoint(x: bx, y: char.pixelY+6))
            }
        }

        // Zone labels removed for cleaner look
    }

    internal func projectTint(for tab: TerminalTab) -> Color {
        let colors: [Color] = [Theme.accent, Theme.cyan, Theme.green, Theme.orange, Theme.purple, Theme.pink]
        let index = Int(UInt(bitPattern: tab.projectPath.hashValue) % UInt(max(colors.count, 1)))
        return colors[index]
    }
}
