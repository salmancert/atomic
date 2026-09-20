import Foundation

/// What a daily check-in produced.
public struct DailySummary: Equatable, Sendable {
    public let day: String
    public let usage: [String: Int]
    public let streaks: [String: Int]
    public let pointsEarned: Int
    public let totalPoints: Int

    public init(day: String, usage: [String: Int], streaks: [String: Int], pointsEarned: Int, totalPoints: Int) {
        self.day = day
        self.usage = usage
        self.streaks = streaks
        self.pointsEarned = pointsEarned
        self.totalPoints = totalPoints
    }
}

/// Owns the five subsystems and the order they run in.
///
/// Nothing here touches UIKit, SwiftUI or CoreLocation, so the whole habit loop can
/// be exercised from tests and from the command line demo.
public final class AtomicBreakEngine {
    public let profile: UserProfile
    public let habitTracker: HabitTracker
    public let cueManager: CueManager
    public let rewardSystem: RewardSystem
    public let interventionSystem: InterventionSystem

    private let dateProvider: DateProvider

    public init(
        profile: UserProfile = .sample(),
        usageSource: UsageDataSource = SampleUsageDataSource(),
        notifier: Notifier,
        dateProvider: DateProvider = SystemDateProvider()
    ) {
        self.profile = profile
        self.dateProvider = dateProvider
        self.habitTracker = HabitTracker(usageSource: usageSource, dateProvider: dateProvider)
        self.cueManager = CueManager()
        self.rewardSystem = RewardSystem(notifier: notifier)
        self.interventionSystem = InterventionSystem(notifier: notifier)
    }

    /// One-time setup: learn the habits, arm the triggers, load today's numbers.
    public func setup() {
        habitTracker.identifyProblemApps()
        cueManager.analyzeUsagePatterns()
        rewardSystem.setupRewards()
        interventionSystem.setupInterventions()
        habitTracker.updateDailyStats(limits: profile.dailyTimeLimits)
    }

    /// Refreshes usage, scores the day and records progress.
    @discardableResult
    public func dailyCheckIn() -> DailySummary {
        let usage = habitTracker.updateDailyStats(limits: profile.dailyTimeLimits)

        cueManager.adjustTriggers(usage: usage, limits: profile.dailyTimeLimits)

        let pointsEarned = rewardSystem.provideDailyRewards(
            limits: profile.dailyTimeLimits,
            usage: usage,
            streaks: habitTracker.streaks
        )

        let day = habitTracker.today
        profile.recordProgress(for: day, usage: usage)

        return DailySummary(
            day: day,
            usage: usage,
            streaks: habitTracker.streaks,
            pointsEarned: pointsEarned,
            totalPoints: rewardSystem.points
        )
    }

    /// Fires a nudge if `date` lands on one of the armed peak windows.
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

        return InterventionContext(
            app: app,
            minutesToday: habitTracker.usageMinutes(for: app),
            limit: profile.limit(for: app)
        )
    }
}
