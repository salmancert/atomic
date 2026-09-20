import Foundation

// MARK: - Habits Scorecard

/// One line of the scorecard: something you already do, and whether it serves you.
public struct ScorecardEntry: Equatable, Sendable, Identifiable {
    public enum Verdict: String, CaseIterable, Sendable {
        case good = "+"
        case neutral = "="
        case bad = "-"

        public var label: String {
            switch self {
            case .good: return "Serves me"
            case .neutral: return "Neutral"
            case .bad: return "Costs me"
            }
        }
    }

    public let habit: String
    public var verdict: Verdict
    public var note: String?

    public var id: String { habit }

    public init(habit: String, verdict: Verdict, note: String? = nil) {
        self.habit = habit
        self.verdict = verdict
        self.note = note
    }

    public var sentence: String {
        note.map { "\(verdict.rawValue) \(habit) — \($0)" } ?? "\(verdict.rawValue) \(habit)"
    }
}

/// Awareness before change: you cannot alter a habit you have not noticed.
public final class HabitsScorecard {
    public private(set) var entries: [ScorecardEntry] = []

    public init(entries: [ScorecardEntry] = []) {
        self.entries = entries
    }

    public func record(_ entry: ScorecardEntry) {
        if let index = entries.firstIndex(where: { $0.habit == entry.habit }) {
            entries[index] = entry
        } else {
            entries.append(entry)
        }
    }

    public func remove(habit: String) {
        entries.removeAll { $0.habit == habit }
    }

    public func entries(marked verdict: ScorecardEntry.Verdict) -> [ScorecardEntry] {
        entries.filter { $0.verdict == verdict }
    }

    /// The habits worth aiming the four laws at.
    public var costlyHabits: [String] {
        entries(marked: .bad).map(\.habit)
    }

    public func tally() -> [ScorecardEntry.Verdict: Int] {
        var counts: [ScorecardEntry.Verdict: Int] = [:]
        for entry in entries {
            counts[entry.verdict, default: 0] += 1
        }
        return counts
    }
}

// MARK: - Implementation Intentions

/// "I will [behaviour] at [time] in [location]."
///
/// A time and a place turn an intention into a plan, and the time doubles as a
/// trigger the app can actually fire on.
public struct ImplementationIntention: Equatable, Sendable, Identifiable {
    public let behavior: String
    /// Zero padded `HH:mm`, so it can be compared against the clock directly.
    public let time: String
    public let location: String

    public var id: String { "\(time)|\(behavior)|\(location)" }

    public var sentence: String {
        "I will \(behavior) at \(time) in \(location)."
    }

    public init(behavior: String, time: String, location: String) {
        self.behavior = behavior
        self.time = time
        self.location = location
    }
}

// MARK: - Habit Stacking

/// "After [current habit], I will [new habit]."
///
/// The anchor is something already automatic, so it carries the new behaviour.
public struct HabitStack: Equatable, Sendable, Identifiable {
    public let anchor: String
    public let newHabit: String

    public var id: String { "\(anchor)|\(newHabit)" }

    public var sentence: String {
        "After \(anchor), I will \(newHabit)."
    }

    public init(anchor: String, newHabit: String) {
        self.anchor = anchor
        self.newHabit = newHabit
    }

    /// Chains a run of habits so each one becomes the cue for the next.
    ///
    /// - Parameter actions: bare actions — "wake up", "make coffee" — since each one
    ///   is read twice: once as the thing you will do, and once, with "I" in front of
    ///   it, as the anchor for what follows.
    public static func chain(_ actions: [String]) -> [HabitStack] {
        guard actions.count > 1 else { return [] }
        return zip(actions, actions.dropFirst()).map { previous, next in
            HabitStack(anchor: "I \(previous)", newHabit: next)
        }
    }
}

// MARK: - Environment Design

/// Context is the cue. Hide what you are breaking; surface what replaces it.
public struct EnvironmentRule: Equatable, Sendable, Identifiable {
    public enum Intent: String, CaseIterable, Sendable {
        case hideTheCue
        case showTheCue
    }

    public let cue: String
    public let space: String
    public let intent: Intent

    public var id: String { "\(space)|\(cue)" }

    public var sentence: String {
        switch intent {
        case .hideTheCue: return "In \(space): keep \(cue) out of sight."
        case .showTheCue: return "In \(space): keep \(cue) in plain sight."
        }
    }

    public init(cue: String, space: String, intent: Intent) {
        self.cue = cue
        self.space = space
        self.intent = intent
    }
}

// MARK: - Pointing and Calling

/// Say the action out loud before taking it.
///
/// Borrowed from the Japanese rail system: naming what you are about to do pulls a
/// habit out of autopilot and back under deliberate control.
public enum PointingAndCalling {
    public static func script(
        app: String,
        minutesToday: Int,
        limit: Int? = nil,
        identity: String? = nil
    ) -> String {
        var parts = ["I am about to open \(app).", "That is \(minutesToday) minutes today."]

        if let limit, minutesToday > limit {
            parts.append("My limit was \(limit).")
        }
        if let identity {
            parts.append("\(identity).")
        }

        return parts.joined(separator: " ")
    }
}
