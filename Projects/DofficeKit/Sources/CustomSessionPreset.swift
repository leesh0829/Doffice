import SwiftUI
import DesignSystem

public struct CustomSessionPreset: Codable, Identifiable, Hashable {
    public var id: String = UUID().uuidString
    public var name: String
    public var icon: String
    public var tint: String
    public var draft: NewSessionDraftSnapshot

    public static func == (lhs: CustomSessionPreset, rhs: CustomSessionPreset) -> Bool { lhs.id == rhs.id }
    public func hash(into hasher: inout Hasher) { hasher.combine(id) }

    public init(id: String = UUID().uuidString, name: String, icon: String, tint: String, draft: NewSessionDraftSnapshot) {
        self.id = id
        self.name = name
        self.icon = icon
        self.tint = tint
        self.draft = draft
    }
}

public final class CustomPresetStore: ObservableObject {
    public static let shared = CustomPresetStore()
    @Published public private(set) var presets: [CustomSessionPreset] = []
    private let key = "doffice.custom-session-presets"

    private init() { load() }

    public func save(_ preset: CustomSessionPreset) {
        if let idx = presets.firstIndex(where: { $0.id == preset.id }) {
            presets[idx] = preset
        } else {
            presets.insert(preset, at: 0)
        }
        persist()
    }

    public func delete(_ preset: CustomSessionPreset) {
        presets.removeAll { $0.id == preset.id }
        persist()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([CustomSessionPreset].self, from: data) else { return }
        presets = decoded
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(presets) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

public extension CustomSessionPreset {
    var tintColor: Color {
        switch tint {
        case "purple": return Theme.purple
        case "orange": return Theme.orange
        case "cyan": return Theme.cyan
        case "green": return Theme.green
        case "red": return Theme.red
        default: return Theme.accent
        }
    }
}
