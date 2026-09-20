import Foundation

/// What a daily check-in produced.
public struct DailySummary: Equatable, Sendable {
    public let day: String
    public let usage: [String: Int]
    public let streaks: [String: Int]
    public let pointsEarned: Int
    public let totalPoints: Int
    /// Every action is a vote — today's count.
    public let identityTally: VoteTally
    /// Habits that have now been missed two days running.
    public let missedTwice: [String]
    /// Limits the Goldilocks rule thinks are pitched wrong, and what to move them to.
    public let limitSuggestions: [String: Int]

    public init(
        day: String,
        usage: [String: Int],
        streaks: [String: Int],
        pointsEarned: Int,
        totalPoints: Int,
        identityTally: VoteTally,
        missedTwice: [String],
        limitSuggestions: [String: Int]
    ) {
        self.day = day
        self.usage = usage
        self.streaks = streaks
        self.pointsEarned = pointsEarned
        self.totalPoints = totalPoints
        self.identityTally = identityTally
        self.missedTwice = missedTwice
        self.limitSuggestions = limitSuggestions
    }
}

/// Owns the subsystems and the order they run in.
///
/// Nothing here touches UIKit, SwiftUI or CoreLocation, so the whole habit loop can
/// be exercised from tests and from the command line demo.
public final class AtomicBreakEngine {
    public let profile: UserProfile
    public let habitTracker: HabitTracker
    public let cueManager: CueManager
    public let rewardSystem: RewardSystem
    public let interventionSystem: InterventionSystem

    /// The user's configured tools, filed under the law each one serves.
    public let playbook: Playbook
    public let identity: IdentityTracker
    public let reviewLog: ReviewLog

    private let dateProvider: DateProvider
    private let notifier: Notifier

    public init(
        profile: UserProfile = .sample(),
        playbook: Playbook? = nil,
        identityStatement: String? = nil,
        usageSource: UsageDataSource = SampleUsageDataSource(),
        notifier: Notifier,
        dateProvider: DateProvider = SystemDateProvider()
    ) {
        let resolvedPlaybook = playbook ?? .sample(targetApps: profile.targetApps)

        self.profile = profile
        self.dateProvider = dateProvider
        self.playbook = resolvedPlaybook
        self.habitTracker = HabitTracker(usageSource: usageSource, dateProvider: dateProvider)
        self.cueManager = CueManager()
        self.rewardSystem = RewardSystem(notifier: notifier)
        self.interventionSystem = InterventionSystem(notifier: notifier)
        self.reviewLog = ReviewLog()
        self.notifier = notifier

        self.identity = IdentityTracker(
            statement: identityStatement
                ?? resolvedPlaybook.contract?.identityStatement
                ?? "I am someone who decides where their attention goes"
        )
    }

    /// One-time setup: learn the habits, arm the triggers, load today's numbers.
    public func setup() {
        habitTracker.identifyProblemApps()
        cueManager.analyzeUsagePatterns()
        // An implementation intention the user wrote is a better trigger than a
        // pattern we inferred, so both arm the same list.
        cueManager.addTriggerTimes(playbook.intentionTimes)
        rewardSystem.setupRewards()
        interventionSystem.setupInterventions()
        habitTracker.updateDailyStats(limits: profile.dailyTimeLimits)
    }

    /// Refreshes usage, scores the day, casts the day's identity votes and re-pitches
    /// any limit that has stopped being just manageable.
    @discardableResult
    public func dailyCheckIn() -> DailySummary {
        let usage = habitTracker.updateDailyStats(limits: profile.dailyTimeLimits)
        let day = habitTracker.today

        cueManager.adjustTriggers(usage: usage, limits: profile.dailyTimeLimits)

        let pointsEarned = rewardSystem.provideDailyRewards(
            limits: profile.dailyTimeLimits,
            usage: usage,
            streaks: habitTracker.streaks
        )

        // Every action is a vote for the type of person you wish to become.
        for (app, limit) in profile.dailyTimeLimits {
            identity.cast(day: day, habit: app, for: (usage[app] ?? 0) <= limit)
        }

        profile.recordProgress(for: day, usage: usage)

        return DailySummary(
            day: day,
            usage: usage,
            streaks: habitTracker.streaks,
            pointsEarned: pointsEarned,
            totalPoints: rewardSystem.points,
            identityTally: identity.tally(on: day),
            missedTwice: missedTwiceHabits(),
            limitSuggestions: limitSuggestions()
        )
    }

    // MARK: - The practices behind the four laws

    /// Habits now missed two days running — the point where a slip becomes a habit.
    public func missedTwiceHabits() -> [String] {
        profile.targetApps.filter { habitTracker.chainStatus(for: $0).missedTwice }.sorted()
    }

    public func chainStatuses() -> [ChainStatus] {
        profile.targetApps.sorted().map { habitTracker.chainStatus(for: $0) }
    }

    /// Nudges the user when a chain is about to become a relapse.
    @discardableResult
    public func warnAboutBrokenChains() -> [NotifierMessage] {
        chainStatuses().filter(\.missedTwice).map { status in
            let message = NotifierMessage(title: "Never Miss Twice", body: status.advice)
            notifier.notify(message)
            return message
        }
    }

    /// Limits that have drifted out of the just-manageable band.
    public func limitSuggestions() -> [String: Int] {
        var suggestions: [String: Int] = [:]

        for (app, limit) in profile.dailyTimeLimits {
            let recent = habitTracker.recentUsage(for: app)
            let suggested = GoldilocksRule.suggestedLimit(current: limit, recentUsage: recent)
            if suggested != limit {
                suggestions[app] = suggested
            }
        }

        return suggestions
    }

    /// Applies a Goldilocks suggestion, which is the only way a limit moves.
    public func applyLimitSuggestion(for app: String) {
        guard let suggested = limitSuggestions()[app] else { return }
        profile.dailyTimeLimits[app] = suggested
    }

    public func recordReflection(wentWell: String, toImprove: String, identityRating: Int) {
        reviewLog.record(
            ReflectionEntry(
                day: habitTracker.today,
                wentWell: wentWell,
                toImprove: toImprove,
                identityRating: identityRating
            )
        )
    }

    public func integrityReport() -> IntegrityReport {
        reviewLog.report(identity: identity, bestChain: habitTracker.bestChain())
    }

    // MARK: - Interventions

    /// Fires a nudge if `date` lands on one of the armed windows.
    @discardableResult
    public func triggerTimeBasedInterventions(at date: Date? = nil) -> NotifierMessage? {
        let minute = DayKey.minuteOfDay(from: date ?? dateProvider.now())
        guard cueManager.shouldTrigger(at: minute) else { return nil }
        return interventionSystem.trigger(context: currentContext())
    }

    /// Fires a nudge if the user has arrived at one of their trigger locations.
    @discardableResult
    public func triggerLocationBasedInterventions(at coordinate: Coordinate) -> NotifierMessage? {
        guard cueManager.trigger(near: coordinate) != nil else { return nil }
        return interventionSystem.trigger(context: currentContext())
    }

    /// The app in the worst shape today, which is what the nudges talk about.
    public func currentContext() -> InterventionContext {
        let app = habitTracker.mostUsedApp(limits: profile.dailyTimeLimits)
            ?? profile.targetApps.first
            ?? "your phone"
        return context(for: app)
    }

    /// Hands the nudge every tool the user configured for this app.
    public func context(for app: String) -> InterventionContext {
        InterventionContext(
            app: app,
            minutesToday: habitTracker.usageMinutes(for: app),
            limit: profile.limit(for: app),
            streak: habitTracker.streaks[app],
            identityStatement: identity.statement,
            alternative: playbook.twoMinuteAlternative(),
            frictionStep: playbook.frictionStep(for: app),
            environmentStep: playbook.environmentRule(for: app)?.sentence,
            reframe: playbook.reframes.first?.sentence,
            temptationBundle: playbook.temptationBundles.first?.sentence,
            reward: playbook.reinforcement(for: app),
            partner: playbook.partners.first?.name
        )
    }
}
