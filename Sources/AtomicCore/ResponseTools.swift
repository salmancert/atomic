import Foundation

// MARK: - Two-Minute Rule

/// Scale the replacement down until it takes two minutes.
///
/// A habit has to exist before it can be improved, and two minutes is small enough
/// that it never gets skipped.
public struct GatewayHabit: Equatable, Sendable, Identifiable {
    public let fullHabit: String
    public let twoMinuteVersion: String

    public var id: String { fullHabit }

    public var sentence: String {
        "\(fullHabit) becomes: \(twoMinuteVersion)."
    }

    public init(fullHabit: String, twoMinuteVersion: String) {
        self.fullHabit = fullHabit
        self.twoMinuteVersion = twoMinuteVersion
    }
}

// MARK: - Law of Least Effort

/// Friction is the lever: add steps in front of the habit you are breaking, remove
/// them from the one replacing it.
public struct FrictionAdjustment: Equatable, Sendable, Identifiable {
    public enum Direction: String, CaseIterable, Sendable {
        case add
        case remove
    }

    public let habit: String
    public let direction: Direction
    public let step: String

    public var id: String { "\(habit)|\(step)" }

    public var sentence: String {
        switch direction {
        case .add: return "Before \(habit): \(step)."
        case .remove: return "To make \(habit) easier: \(step)."
        }
    }

    public init(habit: String, direction: Direction, step: String) {
        self.habit = habit
        self.direction = direction
        self.step = step
    }
}

/// How long to stall before a problem app opens.
///
/// Twenty seconds is the default because it is long enough to break the reach and
/// short enough not to feel punitive. It escalates as the day's overage grows.
public enum FrictionDelay {
    public static let base = 20

    public static func seconds(minutesToday: Int, limit: Int?) -> Int {
        guard let limit, limit > 0, minutesToday > limit else { return base }

        let overageRatio = Double(minutesToday - limit) / Double(limit)
        let scaled = Double(base) * (1 + min(overageRatio, 3))
        return Int(scaled.rounded())
    }
}

// MARK: - Commitment Devices

/// A choice made now that constrains the choice made later, when willpower is gone.
public struct CommitmentDevice: Equatable, Sendable, Identifiable {
    public let name: String
    public let locksIn: String
    /// One-time actions keep paying without any further decision.
    public let isOneTimeAction: Bool

    public var id: String { name }

    public var sentence: String {
        isOneTimeAction ? "\(name) — done once, locks in \(locksIn)." : "\(name) — locks in \(locksIn)."
    }

    public init(name: String, locksIn: String, isOneTimeAction: Bool = false) {
        self.name = name
        self.locksIn = locksIn
        self.isOneTimeAction = isOneTimeAction
    }
}
