import Foundation

/// Tracks daily usage and the streak of days spent under each app's limit.
public final class HabitTracker {
    private let usageSource: UsageDataSource
    private let dateProvider: DateProvider

    public private(set) var problemApps: [String: AppUsageSummary] = [:]
    public private(set) var usageData: [String: [String: Int]] = [:]
    public private(set) var streaks: [String: Int] = [:]
    public private(set) var bestStreaks: [String: Int] = [:]

    /// day -> app -> did the user stay under the limit. The record the habit tracker
    /// and the never-miss-twice rule both read from.
    public private(set) var results: [String: [String: Bool]] = [:]

    public init(
        usageSource: UsageDataSource = SampleUsageDataSource(),
        dateProvider: DateProvider = SystemDateProvider()
    ) {
        self.usageSource = usageSource
        self.dateProvider = dateProvider
    }

    public var today: String {
        DayKey.day(from: dateProvider.now())
    }

    /// Picks out the apps worth intervening on, based on long run averages.
    public func identifyProblemApps() {
        problemApps = usageSource.historicalSummaries()
    }

    /// Pulls today's usage from the data source and rolls the streaks forward.
    @discardableResult
    public func updateDailyStats(limits: [String: Int]) -> [String: Int] {
        let day = today
        let usage = usageSource.usageMinutes(on: day)
        usageData[day] = usage
        updateStreaks(limits: limits, on: day)
        return usage
    }

    public func todaysUsage() -> [String: Int] {
        usageData[today] ?? [:]
    }

    public func usageMinutes(for app: String) -> Int {
        todaysUsage()[app] ?? 0
    }

    /// The tracked app furthest over (or closest to) its limit today.
    public func mostUsedApp(limits: [String: Int]) -> String? {
        limits.keys.max { usageMinutes(for: $0) < usageMinutes(for: $1) }
    }

    /// A day under the limit extends the streak; a day over it resets to zero.
    ///
    /// Driven by the limits rather than by the usage report, so an app that was not
    /// opened at all still earns its streak day.
    private func updateStreaks(limits: [String: Int], on day: String) {
        let usage = usageData[day] ?? [:]
        for (app, limit) in limits {
            let minutes = usage[app] ?? 0
            let stayedUnder = minutes <= limit

            results[day, default: [:]][app] = stayedUnder
            streaks[app] = stayedUnder ? (streaks[app] ?? 0) + 1 : 0
            bestStreaks[app] = max(bestStreaks[app] ?? 0, streaks[app] ?? 0)
        }
    }

    /// The recorded days, oldest first. `yyyy-MM-dd` sorts chronologically.
    public var recordedDays: [String] {
        results.keys.sorted()
    }

    /// The last `days` days of usage for one app, oldest first — what the Goldilocks
    /// rule reads to decide whether a limit is pitched right.
    public func recentUsage(for app: String, days: Int = 7) -> [Int] {
        usageData.keys.sorted().suffix(days).map { usageData[$0]?[app] ?? 0 }
    }

    /// Missing once is an accident; missing twice starts a new habit.
    public func chainStatus(for app: String) -> ChainStatus {
        let recent = recordedDays.suffix(2).compactMap { results[$0]?[app] }
        let missedLastDay = recent.last == false
        let missedTwice = recent.count == 2 && recent.allSatisfy { $0 == false }

        return ChainStatus(
            habit: app,
            streak: streaks[app] ?? 0,
            missedLastDay: missedLastDay,
            missedTwice: missedTwice
        )
    }

    public func bestChain() -> Int {
        bestStreaks.values.max() ?? 0
    }
}
