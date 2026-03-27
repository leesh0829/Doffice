import SwiftUI
import DesignSystem

// ═══════════════════════════════════════════════════════
// MARK: - Prompt Favorites / Templates
// ═══════════════════════════════════════════════════════

public class PromptFavorites: ObservableObject {
    public static let shared = PromptFavorites()

    public struct Favorite: Codable, Identifiable, Equatable {
        public let id: UUID
        public var name: String        // e.g., "코드 리뷰"
        public var prompt: String      // The actual prompt text
        public var icon: String        // SF Symbol name
        public var shortcut: String?   // e.g., "review"
        public let createdAt: Date

        public init(id: UUID = UUID(), name: String, prompt: String, icon: String, shortcut: String? = nil, createdAt: Date = Date()) {
            self.id = id; self.name = name; self.prompt = prompt; self.icon = icon; self.shortcut = shortcut; self.createdAt = createdAt
        }
    }

    @Published public var favorites: [Favorite] = []

    private let storageKey = "promptFavorites_v1"

    private init() {
        load()
        if favorites.isEmpty { resetToDefaults() }
    }

    // MARK: - Default Templates

    public static let defaultTemplates: [Favorite] = [
        Favorite(name: "코드 리뷰", prompt: "이 코드를 리뷰해주세요. 버그, 성능, 보안 문제를 찾아주세요.", icon: "magnifyingglass.circle.fill", shortcut: "review"),
        Favorite(name: "리팩토링", prompt: "이 코드를 깔끔하게 리팩토링해주세요.", icon: "arrow.triangle.2.circlepath.circle.fill", shortcut: "refactor"),
        Favorite(name: "테스트 작성", prompt: "이 코드에 대한 유닛 테스트를 작성해주세요.", icon: "checkmark.shield.fill", shortcut: "test"),
        Favorite(name: "버그 수정", prompt: "이 에러를 분석하고 수정해주세요:", icon: "ladybug.fill", shortcut: "fix"),
        Favorite(name: "설명", prompt: "이 코드가 무엇을 하는지 설명해주세요.", icon: "text.bubble.fill", shortcut: "explain"),
    ]

    public func resetToDefaults() {
        favorites = Self.defaultTemplates
        save()
    }

    // MARK: - CRUD

    public func add(_ favorite: Favorite) {
        favorites.append(favorite)
        save()
    }

    public func add(name: String, prompt: String, icon: String = "star.fill", shortcut: String? = nil) {
        add(Favorite(name: name, prompt: prompt, icon: icon, shortcut: shortcut))
    }

    public func update(_ favorite: Favorite) {
        guard let idx = favorites.firstIndex(where: { $0.id == favorite.id }) else { return }
        favorites[idx] = favorite
        save()
    }

    public func delete(_ favorite: Favorite) {
        favorites.removeAll { $0.id == favorite.id }
        save()
    }

    public func delete(at offsets: IndexSet) {
        favorites.remove(atOffsets: offsets)
        save()
    }

    public func move(from source: IndexSet, to destination: Int) {
        favorites.move(fromOffsets: source, toOffset: destination)
        save()
    }

    public func find(byName name: String) -> Favorite? {
        let q = name.lowercased()
        return favorites.first { $0.name.lowercased() == q || $0.shortcut?.lowercased() == q }
    }

    public func find(byShortcut shortcut: String) -> Favorite? {
        let q = shortcut.lowercased()
        return favorites.first { $0.shortcut?.lowercased() == q }
    }

    // MARK: - Persistence

    private func save() {
        guard let data = try? JSONEncoder().encode(favorites) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([Favorite].self, from: data) else { return }
        favorites = decoded
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - Favorites Panel View
// ═══════════════════════════════════════════════════════

public struct FavoritesPanelView: View {
    @ObservedObject private var store = PromptFavorites.shared
    public let onSelect: (PromptFavorites.Favorite) -> Void
    public let onDismiss: () -> Void

    @State private var editingFavorite: PromptFavorites.Favorite?
    @State private var showAddSheet = false

    private let columns = [GridItem(.adaptive(minimum: 140), spacing: 8)]

    public init(onSelect: @escaping (PromptFavorites.Favorite) -> Void, onDismiss: @escaping () -> Void) {
        self.onSelect = onSelect
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            Rectangle().fill(Theme.border).frame(height: 1)
            HStack(spacing: 6) {
                Image(systemName: "star.fill").font(.system(size: Theme.iconSize(9), weight: .bold)).foregroundColor(Theme.yellow)
                Text(NSLocalizedString("fav.title", comment: "")).font(Theme.chrome(9, weight: .bold)).foregroundColor(Theme.textPrimary)
                Spacer()
                Text(NSLocalizedString("fav.toggle.hint", comment: "")).font(Theme.chrome(7)).foregroundColor(Theme.textDim)
                Button(action: { showAddSheet = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: Theme.iconSize(12)))
                        .foregroundStyle(Theme.accentBackground)
                }.buttonStyle(.plain).help(NSLocalizedString("fav.add.help", comment: ""))
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: Theme.iconSize(10)))
                        .foregroundColor(Theme.textDim)
                }.buttonStyle(.plain)
            }
            .padding(.horizontal, 12).padding(.vertical, 6)

            // Grid
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(store.favorites) { fav in
                        favoriteCard(fav)
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
            }
            .frame(maxHeight: 80)

            Rectangle().fill(Theme.border).frame(height: 1)
        }
        .background(Theme.bgSurface.opacity(0.95))
        .sheet(isPresented: $showAddSheet) {
            FavoriteEditSheet(favorite: nil) { newFav in
                store.add(newFav)
            }
            .dofficeSheetPresentation()
        }
        .sheet(item: $editingFavorite) { fav in
            FavoriteEditSheet(favorite: fav) { updated in
                store.update(updated)
            }
            .dofficeSheetPresentation()
        }
    }

    private func favoriteCard(_ fav: PromptFavorites.Favorite) -> some View {
        Button(action: { onSelect(fav) }) {
            VStack(spacing: 4) {
                Image(systemName: fav.icon)
                    .font(.system(size: Theme.iconSize(16), weight: .medium))
                    .foregroundStyle(Theme.accentBackground)
                Text(fav.name)
                    .font(Theme.chrome(9, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(1)
                if let shortcut = fav.shortcut {
                    Text("/fav \(shortcut)")
                        .font(Theme.chrome(7))
                        .foregroundColor(Theme.textDim)
                }
            }
            .frame(width: 100, height: 56)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Theme.bgCard)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border, lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(action: { editingFavorite = fav }) {
                Label(NSLocalizedString("fav.edit", comment: ""), systemImage: "pencil")
            }
            Button(role: .destructive, action: { store.delete(fav) }) {
                Label(NSLocalizedString("delete", comment: ""), systemImage: "trash")
            }
        }
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - Favorite Edit Sheet
// ═══════════════════════════════════════════════════════

public struct FavoriteEditSheet: View {
    public let favorite: PromptFavorites.Favorite?
    public let onSave: (PromptFavorites.Favorite) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var prompt: String = ""
    @State private var icon: String = "star.fill"
    @State private var shortcut: String = ""

    public init(favorite: PromptFavorites.Favorite?, onSave: @escaping (PromptFavorites.Favorite) -> Void) {
        self.favorite = favorite
        self.onSave = onSave
    }

    private let iconOptions = [
        "star.fill", "magnifyingglass.circle.fill", "arrow.triangle.2.circlepath.circle.fill",
        "checkmark.shield.fill", "ladybug.fill", "text.bubble.fill",
        "bolt.fill", "hammer.fill", "wrench.fill", "doc.text.fill",
        "cpu.fill", "terminal.fill", "chevron.left.forwardslash.chevron.right",
        "lightbulb.fill", "book.fill", "flag.fill",
    ]

    public var body: some View {
        VStack(spacing: 16) {
            Text(favorite == nil ? NSLocalizedString("fav.new", comment: "") : NSLocalizedString("fav.edit.title", comment: ""))
                .font(Theme.chrome(13, weight: .bold)).foregroundColor(Theme.textPrimary)

            VStack(alignment: .leading, spacing: 8) {
                fieldLabel(NSLocalizedString("fav.field.name", comment: ""))
                TextField(NSLocalizedString("fav.field.name.placeholder", comment: ""), text: $name)
                    .textFieldStyle(.roundedBorder)
                    .font(Theme.mono(11))

                fieldLabel(NSLocalizedString("fav.field.prompt", comment: ""))
                TextEditor(text: $prompt)
                    .font(Theme.mono(11))
                    .frame(minHeight: 60, maxHeight: 120)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.border, lineWidth: 1))

                fieldLabel(NSLocalizedString("fav.field.shortcut", comment: ""))
                TextField(NSLocalizedString("fav.field.shortcut.placeholder", comment: ""), text: $shortcut)
                    .textFieldStyle(.roundedBorder)
                    .font(Theme.mono(11))

                fieldLabel(NSLocalizedString("fav.field.icon", comment: ""))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(iconOptions, id: \.self) { ic in
                            Button(action: { icon = ic }) {
                                Image(systemName: ic)
                                    .font(.system(size: Theme.iconSize(14)))
                                    .foregroundColor(icon == ic ? Theme.accent : Theme.textDim)
                                    .frame(width: 28, height: 28)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(icon == ic ? Theme.accent.opacity(0.15) : Theme.bgSurface)
                                    )
                            }.buttonStyle(.plain)
                        }
                    }
                }
            }

            HStack {
                Button(NSLocalizedString("cancel", comment: "")) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(NSLocalizedString("action.save", comment: "")) {
                    let result = PromptFavorites.Favorite(
                        id: favorite?.id ?? UUID(),
                        name: name,
                        prompt: prompt,
                        icon: icon,
                        shortcut: shortcut.isEmpty ? nil : shortcut,
                        createdAt: favorite?.createdAt ?? Date()
                    )
                    onSave(result)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty || prompt.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 400)
        .background(Theme.bgCard)
        .onAppear {
            if let f = favorite {
                name = f.name; prompt = f.prompt; icon = f.icon; shortcut = f.shortcut ?? ""
            }
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text).font(Theme.chrome(9, weight: .semibold)).foregroundColor(Theme.textSecondary)
    }
}
