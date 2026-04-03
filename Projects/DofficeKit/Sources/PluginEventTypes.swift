import Foundation

// ═══════════════════════════════════════════════════════
// MARK: - Plugin Event / Effect Types
// ═══════════════════════════════════════════════════════

public enum PluginEventType: String, Codable {
    case onPromptKeyPress
    case onPromptSubmit
    case onSessionComplete
    case onSessionError
    case onAchievementUnlock
    case onCharacterHire
    case onLevelUp
}

public enum PluginEffectType: String, Codable {
    case comboCounter = "combo-counter"
    case particleBurst = "particle-burst"
    case screenShake = "screen-shake"
    case flash
    case sound
    case toast
    case confetti
    // v2 이펙트
    case typewriter                        // 타자기 텍스트 애니메이션
    case progressBar = "progress-bar"      // 프로그레스 바 표시
    case glow                              // 테두리 글로우 이펙트
}

/// JSON config 값 (String / Int / Double / Bool / [String])
public enum EffectValue: Codable, Equatable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case stringArray([String])

    public var stringValue: String? { if case .string(let v) = self { return v }; return nil }
    public var intValue: Int? { if case .int(let v) = self { return v }; return nil }
    public var doubleValue: Double? {
        switch self { case .double(let v): return v; case .int(let v): return Double(v); default: return nil }
    }
    public var boolValue: Bool? { if case .bool(let v) = self { return v }; return nil }
    public var stringArrayValue: [String]? { if case .stringArray(let v) = self { return v }; return nil }

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let v = try? c.decode(Bool.self) { self = .bool(v) }
        else if let v = try? c.decode(Int.self) { self = .int(v) }
        else if let v = try? c.decode(Double.self) { self = .double(v) }
        else if let v = try? c.decode([String].self) { self = .stringArray(v) }
        else { self = .string(try c.decode(String.self)) }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let v): try c.encode(v)
        case .int(let v): try c.encode(v)
        case .double(let v): try c.encode(v)
        case .bool(let v): try c.encode(v)
        case .stringArray(let v): try c.encode(v)
        }
    }
}
