import SwiftUI
import DesignSystem

// MARK: - Character Collection View

public struct CharacterCollectionView: View {
    @ObservedObject var registry = CharacterRegistry.shared
    @Environment(\.dismiss) var dismiss
    @State private var editingId: String?
    @State private var editName = ""
    @State private var selectedSpecies: WorkerCharacter.Species? = nil
    // grid only (list mode removed)

    @State private var showPipeline = false

    public init() {}

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

    public var body: some View {
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

public struct CharacterCard: View {
    let character: WorkerCharacter
    let isHired: Bool
    @Binding var editingId: String?
    @Binding var editName: String
    @ObservedObject var registry = CharacterRegistry.shared
    @State private var isHovered = false

    public init(character: WorkerCharacter, isHired: Bool, editingId: Binding<String?>, editName: Binding<String>) {
        self.character = character; self.isHired = isHired
        self._editingId = editingId; self._editName = editName
    }

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

    public var body: some View {
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

public struct LockedCharacterCard: View {
    let character: WorkerCharacter
    @ObservedObject var registry = CharacterRegistry.shared
    @State private var showAlert = false
    @State private var isHovered = false

    public init(character: WorkerCharacter) { self.character = character }

    public var body: some View {
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

public struct FlowLayout: Layout {
    public var spacing: CGFloat = 4

    public init(spacing: CGFloat = 4) { self.spacing = spacing }

    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var height: CGFloat = 0
        for (i, row) in rows.enumerated() {
            let rowHeight = row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
            height += rowHeight + (i > 0 ? spacing : 0)
        }
        return CGSize(width: proposal.width ?? 0, height: height)
    }

    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
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
