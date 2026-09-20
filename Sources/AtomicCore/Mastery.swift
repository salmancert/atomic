import Foundation

// MARK: - Identity

/// One action, counted as one vote for or against the person you are trying to be.
public struct IdentityVote: Equatable, Sendable {
    public let day: String
    public let habit: String
    public let cast: Bool

    public init(day: String, habit: String, cast: Bool) {
        self.day = day
        self.habit = habit
        self.cast = cast
    }
}

public struct VoteTally: Equatable, Sendable {
    public let votesFor: Int
    public let votesAgainst: Int

    public init(votesFor: Int, votesAgainst: Int) {
        self.votesFor = votesFor
        self.votesAgainst = votesAgainst
    }

    public var total: Int { votesFor + votesAgainst }

    /// 0...1. No votes yet reads as zero rather than dividing by nothing.
    public var share: Double {
        total == 0 ? 0 : Double(votesFor) / Double(total)
    }
}

/// Identity-based habits: the goal is not to use the phone less, it is to become
/// someone who does. Every action is a vote.
public final class IdentityTracker {
    public var statement: String
    public private(set) var votes: [IdentityVote] = []

    public init(statement: String) {
        self.statement = statement
    }

    public func cast(day: String, habit: String, for identity: Bool) {
        votes.removeAll { $0.day == day && $0.habit == habit }
        votes.append(IdentityVote(day: day, habit: habit, cast: identity))
    }

    public func tally(on day: String? = nil) -> VoteTally {
        let scope = day.map { target in votes.filter { $0.day == target } } ?? votes
        return VoteTally(
            votesFor: scope.filter(\.cast).count,
            votesAgainst: scope.filter { !$0.cast }.count
        )
    }

    /// The habit casting the most votes against the identity.
    public func biggestLeak() -> String? {
        var against: [String: Int] = [:]
        for vote in votes where !vote.cast {
            against[vote.habit, default: 0] += 1
        }
        return against.max { $0.value < $1.value }?.key
    }
}

// MARK: - Goldilocks Rule

/// Keeps a target at just manageable difficulty.
///
/// A limit that is never missed stops doing any work; one that is missed every day
/// stops being believed. Both ends kill the habit, so the bar moves.
public enum GoldilocksRule {
    public static let minimumLimit = 5

    /// - Parameters:
    ///   - current: today's limit, in minutes.
    ///   - recentUsage: the last few days of actual usage, in minutes.
    public static func suggestedLimit(current: Int, recentUsage: [Int]) -> Int {
        guard !recentUsage.isEmpty, current > 0 else { return current }

        let average = Double(recentUsage.reduce(0, +)) / Double(recentUsage.count)

        // Too easy: cleared every day with room to spare, so tighten.
        if recentUsage.allSatisfy({ $0 <= current }), average <= Double(current) * 0.6 {
            return max(minimumLimit, Int((Double(current) * 0.9).rounded()))
        }

        // Too hard: missed every day, so move the bar to just under what actually happens.
        if recentUsage.allSatisfy({ $0 > current }) {
            return max(current, Int((average * 0.9).rounded()))
        }

        return current
    }

    public static func verdict(current: Int, recentUsage: [Int]) -> String {
        let suggested = suggestedLimit(current: current, recentUsage: recentUsage)

        if suggested < current { return "Too easy — try \(suggested) min." }
        if suggested > current { return "Too hard — \(suggested) min is a real stretch you can hit." }
        return "Just manageable."
    }
}

// MARK: - Reflection and Review

public struct ReflectionEntry: Equatable, Sendable, Identifiable {
    public let day: String
    public let wentWell: String
    public let toImprove: String
    /// 1...5, how much today looked like the person you are trying to be.
    public let identityRating: Int

    public var id: String { day }

    public init(day: String, wentWell: String, toImprove: String, identityRating: Int) {
        self.day = day
        self.wentWell = wentWell
        self.toImprove = toImprove
        self.identityRating = min(5, max(1, identityRating))
    }
}

/// The periodic honest reading: what the record actually says.
public struct IntegrityReport: Equatable, Sendable {
    public let identity: String
    public let daysReviewed: Int
    public let tally: VoteTally
    public let bestChain: Int
    public let biggestLeak: String?
    public let averageRating: Double

    public init(
        identity: String,
        daysReviewed: Int,
        tally: VoteTally,
        bestChain: Int,
        biggestLeak: String?,
        averageRating: Double
    ) {
        self.identity = identity
        self.daysReviewed = daysReviewed
        self.tally = tally
        self.bestChain = bestChain
        self.biggestLeak = biggestLeak
        self.averageRating = averageRating
    }

    public var verdict: String {
        switch tally.share {
        case 0.8...: return "The evidence backs the identity."
        case 0.5..<0.8: return "More votes for than against. The identity is forming."
        case 0..<0.5 where tally.total > 0: return "The record disagrees with the statement. Shrink the habit until it is true."
        default: return "Not enough days yet."
        }
    }
}

public final class ReviewLog {
    public private(set) var entries: [ReflectionEntry] = []

    public init(entries: [ReflectionEntry] = []) {
        self.entries = entries
    }

    public func record(_ entry: ReflectionEntry) {
        entries.removeAll { $0.day == entry.day }
        entries.append(entry)
        entries.sort { $0.day < $1.day }
    }

    public func report(identity: IdentityTracker, bestChain: Int) -> IntegrityReport {
        let ratings = entries.map { Double($0.identityRating) }
        let average = ratings.isEmpty ? 0 : ratings.reduce(0, +) / Double(ratings.count)

        return IntegrityReport(
            identity: identity.statement,
            daysReviewed: entries.count,
            tally: identity.tally(),
            bestChain: bestChain,
            biggestLeak: identity.biggestLeak(),
            averageRating: average
        )
    }
}
