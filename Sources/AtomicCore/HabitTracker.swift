import Foundation

/// Tracks daily usage and the streak of days spent under each app's limit.
public final class HabitTracker {
    private let usageSource: UsageDataSource
    private let dateProvider: DateProvider

    public private(set) var problemApps: [String: AppUsageSummary] = [:]
    public private(set) var usageData: [String: [String: Int]] = [:]
    public private(set) var streaks: [String: Int] = [:]

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
            streaks[app] = minutes <= limit ? (streaks[app] ?? 0) + 1 : 0
        }
    }
}
