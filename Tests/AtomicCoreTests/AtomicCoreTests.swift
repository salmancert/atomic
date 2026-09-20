import XCTest
@testable import AtomicCore

private struct FixedDateProvider: DateProvider {
    var date: Date
    func now() -> Date { date }
}

private struct StubUsageDataSource: UsageDataSource {
    var minutes: [String: Int]
    var summaries: [String: AppUsageSummary] = [:]

    func historicalSummaries() -> [String: AppUsageSummary] { summaries }
    func usageMinutes(on day: String) -> [String: Int] { minutes }
}

private func fixedDate(_ iso: String) -> Date {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd HH:mm"
    return formatter.date(from: iso)!
}

final class HabitTrackerTests: XCTestCase {
    func testStreakGrowsWhileUnderTheLimit() {
        let tracker = HabitTracker(
            usageSource: StubUsageDataSource(minutes: ["Instagram": 10]),
            dateProvider: FixedDateProvider(date: fixedDate("2026-01-01 09:00"))
        )

        tracker.updateDailyStats(limits: ["Instagram": 30])
        XCTAssertEqual(tracker.streaks["Instagram"], 1)

        tracker.updateDailyStats(limits: ["Instagram": 30])
        XCTAssertEqual(tracker.streaks["Instagram"], 2)
    }

    func testStreakResetsWhenTheLimitIsBlown() {
        let tracker = HabitTracker(
            usageSource: StubUsageDataSource(minutes: ["Instagram": 65]),
            dateProvider: FixedDateProvider(date: fixedDate("2026-01-01 09:00"))
        )

        tracker.updateDailyStats(limits: ["Instagram": 30])
        XCTAssertEqual(tracker.streaks["Instagram"], 0)
    }

    func testUntouchedAppStillEarnsItsStreakDay() {
        // The old implementation walked the usage report, so an app that was never
        // opened got no credit at all.
        let tracker = HabitTracker(
            usageSource: StubUsageDataSource(minutes: [:]),
            dateProvider: FixedDateProvider(date: fixedDate("2026-01-01 09:00"))
        )

        tracker.updateDailyStats(limits: ["TikTok": 15])
        XCTAssertEqual(tracker.streaks["TikTok"], 1)
    }
}

final class RewardSystemTests: XCTestCase {
    func testPointsAreAwardedForStayingUnderTheLimit() {
        let system = RewardSystem(notifier: RecordingNotifier())
        system.setupRewards()

        // 20 for being under, plus 20 for being at or under half.
        let earned = system.provideDailyRewards(limits: ["Instagram": 30], usage: ["Instagram": 10], streaks: [:])
        XCTAssertEqual(earned, 40)
        XCTAssertEqual(system.points, 40)
    }

    func testNoPointsWhenOverTheLimit() {
        let system = RewardSystem(notifier: RecordingNotifier())
        system.setupRewards()

        let earned = system.provideDailyRewards(limits: ["Instagram": 30], usage: ["Instagram": 31], streaks: [:])
        XCTAssertEqual(earned, 0)
    }

    func testStreakBonusIsCapped() {
        let system = RewardSystem(notifier: RecordingNotifier())
        system.setupRewards()

        let earned = system.provideDailyRewards(limits: [:], usage: [:], streaks: ["Instagram": 100])
        XCTAssertEqual(earned, 50)
    }

    func testMilestoneNotifies() {
        let notifier = RecordingNotifier()
        let system = RewardSystem(notifier: notifier)
        system.setupRewards()

        system.provideDailyRewards(limits: [:], usage: [:], streaks: ["Instagram": 7])

        XCTAssertTrue(notifier.messages.contains { $0.body.contains("One week streak") })
    }

    func testRewardsAreRedeemedMostExpensiveFirst() {
        let notifier = RecordingNotifier()
        let system = RewardSystem(notifier: notifier)
        system.setupRewards()

        // 350 points buys the 250 reward, leaving 100 for the badge.
        system.provideDailyRewards(limits: [:], usage: [:], streaks: (1...7).reduce(into: [String: Int]()) { result, index in
            result["App\(index)"] = 10 // 7 apps * 50 capped points = 350
        })

        XCTAssertEqual(system.unlockedRewards, ["Achievement Unlock", "Digital Badge"])
        XCTAssertEqual(system.points, 0)
    }
}

final class CueManagerTests: XCTestCase {
    func testTriggerTimesAreZeroPaddedSoTheyCanMatchTheClock() {
        let manager = CueManager()
        manager.analyzeUsagePatterns()

        // The original used "7:00", which could never equal a formatted "07:00".
        XCTAssertEqual(manager.triggerTimes, ["07:00", "12:00", "21:00"])
        XCTAssertTrue(manager.shouldTrigger(at: "07:00"))
        XCTAssertFalse(manager.shouldTrigger(at: "07:01"))
    }

    func testTriggersBackOffAfterACleanDay() {
        let manager = CueManager()
        manager.analyzeUsagePatterns()

        manager.adjustTriggers(usage: ["Instagram": 10], limits: ["Instagram": 30])
        XCTAssertEqual(manager.triggerTimes, ["21:00"])

        manager.adjustTriggers(usage: ["Instagram": 90], limits: ["Instagram": 30])
        XCTAssertEqual(manager.triggerTimes.count, 3)
    }

    func testNearbyLocationMatches() {
        let manager = CueManager()
        manager.analyzeUsagePatterns()

        let nextDoor = Coordinate(latitude: 40.7128, longitude: -74.0061)
        XCTAssertEqual(manager.trigger(near: nextDoor)?.name, "Home")

        let farAway = Coordinate(latitude: 34.0522, longitude: -118.2437)
        XCTAssertNil(manager.trigger(near: farAway))
    }
}

final class InterventionSystemTests: XCTestCase {
    func testSelectingFromAnEmptyListDoesNotCrash() {
        // The original fell back to `interventions[0]`, which traps when empty.
        let system = InterventionSystem(notifier: RecordingNotifier())
        XCTAssertNil(system.selectIntervention())
        XCTAssertNil(system.trigger(context: InterventionContext(app: "Instagram", minutesToday: 0)))
    }

    func testMessagesQuoteTheUsersOwnNumbers() {
        let notifier = RecordingNotifier()
        let system = InterventionSystem(notifier: notifier, chooser: { $0.first })
        system.setupInterventions()

        let message = system.trigger(context: InterventionContext(app: "TikTok", minutesToday: 42, limit: 15))

        XCTAssertEqual(message?.title, "Usage Alert")
        XCTAssertEqual(message?.body, "You've spent 42 minutes on TikTok today, 27 over your 15 minute limit.")
        XCTAssertEqual(notifier.messages.count, 1)
    }

    func testMessageReportsRemainingTimeWhenUnderTheLimit() {
        let system = InterventionSystem(notifier: RecordingNotifier(), chooser: { $0.first })
        system.setupInterventions()

        let message = system.trigger(context: InterventionContext(app: "TikTok", minutesToday: 5, limit: 15))
        XCTAssertEqual(message?.body, "You've spent 5 minutes on TikTok today, 10 minutes left of your 15 minute limit.")
    }
}

final class EngineTests: XCTestCase {
    private func makeEngine(minutes: [String: Int], at date: Date) -> (AtomicBreakEngine, RecordingNotifier) {
        let notifier = RecordingNotifier()
        let engine = AtomicBreakEngine(
            profile: .sample(),
            usageSource: StubUsageDataSource(minutes: minutes),
            notifier: notifier,
            dateProvider: FixedDateProvider(date: date)
        )
        engine.setup()
        return (engine, notifier)
    }

    func testDailyCheckInRecordsProgressAndScoresTheDay() {
        let (engine, _) = makeEngine(minutes: ["Instagram": 10, "Facebook": 5, "TikTok": 5], at: fixedDate("2026-03-04 09:00"))

        let summary = engine.dailyCheckIn()

        XCTAssertEqual(summary.day, "2026-03-04")
        XCTAssertEqual(summary.usage["Instagram"], 10)
        XCTAssertGreaterThan(summary.pointsEarned, 0)
        XCTAssertEqual(engine.profile.progressHistory["2026-03-04"]?["Instagram"], 10)
    }

    func testProgressHistoryIgnoresAppsTheUserIsNotTracking() {
        let (engine, _) = makeEngine(minutes: ["Instagram": 10, "Xcode": 300], at: fixedDate("2026-03-04 09:00"))

        engine.dailyCheckIn()

        XCTAssertNil(engine.profile.progressHistory["2026-03-04"]?["Xcode"])
    }

    func testTimeBasedInterventionOnlyFiresInsideAPeakWindow() {
        let (engine, notifier) = makeEngine(minutes: ["Instagram": 65], at: fixedDate("2026-03-04 09:00"))

        XCTAssertNil(engine.triggerTimeBasedInterventions(at: fixedDate("2026-03-04 09:37")))
        XCTAssertTrue(notifier.messages.isEmpty)

        XCTAssertNotNil(engine.triggerTimeBasedInterventions(at: fixedDate("2026-03-04 07:00")))
        XCTAssertEqual(notifier.messages.count, 1)
    }

    func testLocationInterventionFiresOnlyNearATrigger() {
        let (engine, _) = makeEngine(minutes: ["Instagram": 65], at: fixedDate("2026-03-04 09:00"))

        XCTAssertNil(engine.triggerLocationBasedInterventions(at: Coordinate(latitude: 51.5072, longitude: -0.1276)))
        XCTAssertNotNil(engine.triggerLocationBasedInterventions(at: Coordinate(latitude: 40.7128, longitude: -74.0060)))
    }

    func testContextPicksTheWorstOffender() {
        let (engine, _) = makeEngine(minutes: ["Instagram": 65, "Facebook": 40, "TikTok": 30], at: fixedDate("2026-03-04 09:00"))

        let context = engine.currentContext()
        XCTAssertEqual(context.app, "Instagram")
        XCTAssertEqual(context.minutesToday, 65)
        XCTAssertEqual(context.limit, 30)
    }
}

final class GeoTests: XCTestCase {
    func testDistanceBetweenKnownPoints() {
        let newYork = Coordinate(latitude: 40.7128, longitude: -74.0060)
        let losAngeles = Coordinate(latitude: 34.0522, longitude: -118.2437)

        // ~3,936 km; allow a few km of slack for the spherical approximation.
        XCTAssertEqual(newYork.distance(to: losAngeles), 3_936_000, accuracy: 10_000)
        XCTAssertTrue(newYork.isNear(newYork))
        XCTAssertFalse(newYork.isNear(losAngeles))
    }
}
