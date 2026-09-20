import Foundation

// MARK: - Temptation Bundling

/// "After [what I need to do], I will [what I want to do]."
///
/// Premack's principle: the wanted behaviour pays for the needed one.
public struct TemptationBundle: Equatable, Sendable, Identifiable {
    public let need: String
    public let want: String

    public var id: String { "\(need)|\(want)" }

    public var sentence: String {
        "After \(need), I will \(want)."
    }

    public init(need: String, want: String) {
        self.need = need
        self.want = want
    }
}

// MARK: - Motivation Ritual

/// Something enjoyable done immediately before a hard habit, repeated until the
/// ritual itself starts the craving.
public struct MotivationRitual: Equatable, Sendable, Identifiable {
    public let ritual: String
    public let habit: String

    public var id: String { "\(ritual)|\(habit)" }

    public var sentence: String {
        "\(ritual), then \(habit)."
    }

    public init(ritual: String, habit: String) {
        self.ritual = ritual
        self.habit = habit
    }
}

// MARK: - Reframing

/// The behaviour does not change; the story about it does.
public struct Reframe: Equatable, Sendable, Identifiable {
    public let from: String
    public let to: String

    public var id: String { from }

    public var sentence: String {
        "Not \"\(from)\" — \"\(to)\"."
    }

    public init(from: String, to: String) {
        self.from = from
        self.to = to
    }
}

// MARK: - Social Circle

/// Nothing sustains a habit like belonging to a group where it is already normal.
public struct SocialGroup: Equatable, Sendable, Identifiable {
    /// The three groups whose behaviour we imitate.
    public enum Kind: String, CaseIterable, Sendable {
        case theClose
        case theMany
        case thePowerful

        public var title: String {
            switch self {
            case .theClose: return "The close"
            case .theMany: return "The many"
            case .thePowerful: return "The powerful"
            }
        }

        public var explanation: String {
            switch self {
            case .theClose: return "Family and friends — the habits nearest to you are the ones you pick up."
            case .theMany: return "The tribe — behaviour that is normal in your group feels normal to you."
            case .thePowerful: return "Those with status — we imitate people we want to be like."
            }
        }
    }

    public let kind: Kind
    public let name: String
    public let norm: String

    public var id: String { "\(kind.rawValue)|\(name)" }

    public var sentence: String {
        "\(name): \(norm)."
    }

    public init(kind: Kind, name: String, norm: String) {
        self.kind = kind
        self.name = name
        self.norm = norm
    }
}
