import Foundation

public struct AppUsageSummary: Equatable, Sendable {
    public var averageDailyMinutes: Int
    public var averageOpenCount: Int

    public init(averageDailyMinutes: Int, averageOpenCount: Int) {
        self.averageDailyMinutes = averageDailyMinutes
        self.averageOpenCount = averageOpenCount
    }
}

/// Where per-app screen time comes from.
///
/// Reading real numbers requires `FamilyControls` / `DeviceActivity`, which only work
/// once Apple grants the Family Controls entitlement to the bundle identifier. Until
/// then the app runs on `SampleUsageDataSource` and every other part of the system —
/// streaks, rewards, interventions — is already wired to the protocol, so swapping in
/// the real source is a one line change in `AtomicBreakEngine`.
public protocol UsageDataSource {
    /// Long run averages used during onboarding to pick the apps worth limiting.
    func historicalSummaries() -> [String: AppUsageSummary]

    /// Minutes spent per app on the given `yyyy-MM-dd` day.
    func usageMinutes(on day: String) -> [String: Int]
}

public struct SampleUsageDataSource: UsageDataSource {
    public init() {}

    public func historicalSummaries() -> [String: AppUsageSummary] {
        [
            "Instagram": AppUsageSummary(averageDailyMinutes: 120, averageOpenCount: 45),
            "Facebook": AppUsageSummary(averageDailyMinutes: 90, averageOpenCount: 30),
            "TikTok": AppUsageSummary(averageDailyMinutes: 60, averageOpenCount: 25)
        ]
    }

    public func usageMinutes(on day: String) -> [String: Int] {
        ["Instagram": 65, "Facebook": 40, "TikTok": 30]
    }
}
