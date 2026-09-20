import Foundation

// MARK: - Reinforcement

/// An immediate reward attached to a habit whose real payoff is months away.
///
/// What is immediately rewarded gets repeated; what is immediately punished gets
/// avoided. The delay is the whole problem, so the reward has to be moved forward.
public struct Reinforcement: Equatable, Sendable, Identifiable {
    public let habit: String
    public let immediateReward: String

    public var id: String { habit }

    public var sentence: String {
        "Stay under on \(habit) → \(immediateReward)."
    }

    public init(habit: String, immediateReward: String) {
        self.habit = habit
        self.immediateReward = immediateReward
    }
}

// MARK: - Never Miss Twice

/// The state of a chain of days for one habit.
public struct ChainStatus: Equatable, Sendable {
    public let habit: String
    public let streak: Int
    public let missedLastDay: Bool
    /// Two misses in a row: the point where a slip turns into a new habit.
    public let missedTwice: Bool

    public init(habit: String, streak: Int, missedLastDay: Bool, missedTwice: Bool) {
        self.habit = habit
        self.streak = streak
        self.missedLastDay = missedLastDay
        self.missedTwice = missedTwice
    }

    public var advice: String {
        if missedTwice {
            return "Two in a row on \(habit). Do the two-minute version today, however badly."
        }
        if missedLastDay {
            return "Missed \(habit) yesterday. Missing once is an accident — today is the one that counts."
        }
        return "\(streak) day chain on \(habit). Don't break it."
    }
}

// MARK: - Accountability

public struct AccountabilityPartner: Equatable, Sendable, Identifiable {
    public let name: String
    public let watches: String

    public var id: String { name }

    public var sentence: String {
        "\(name) sees \(watches)."
    }

    public init(name: String, watches: String) {
        self.name = name
        self.watches = watches
    }
}

/// The commitment, the cost of breaking it, and who witnessed it.
public struct HabitContract: Equatable, Sendable {
    public let identityStatement: String
    public let commitments: [String]
    public let penalty: String
    public let partners: [AccountabilityPartner]
    public var signedOn: String?

    public init(
        identityStatement: String,
        commitments: [String],
        penalty: String,
        partners: [AccountabilityPartner] = [],
        signedOn: String? = nil
    ) {
        self.identityStatement = identityStatement
        self.commitments = commitments
        self.penalty = penalty
        self.partners = partners
        self.signedOn = signedOn
    }

    public var text: String {
        var lines = ["\(identityStatement)."]

        if !commitments.isEmpty {
            lines.append("")
            lines.append("To hold that up, I will:")
            lines.append(contentsOf: commitments.map { "• \($0)" })
        }

        lines.append("")
        lines.append("If I fall short: \(penalty).")

        if !partners.isEmpty {
            lines.append("Witnessed by \(partners.map(\.name).joined(separator: ", ")).")
        }

        if let signedOn {
            lines.append("Signed \(signedOn).")
        }

        return lines.joined(separator: "\n")
    }

    public var isSigned: Bool { signedOn != nil }

    public func signed(on day: String) -> HabitContract {
        var copy = self
        copy.signedOn = day
        return copy
    }
}
