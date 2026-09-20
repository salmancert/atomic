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

    func testThereIsOneInterventionPerLaw() {
        let system = InterventionSystem(notifier: RecordingNotifier())
        system.setupInterventions()

        for stage in HabitStage.allCases {
            XCTAssertNotNil(system.intervention(for: stage), "no nudge for law \(stage.lawNumber)")
        }
        XCTAssertEqual(system.interventions.count, HabitStage.allCases.count)
    }

    func testFirstLawNamesTheAppTheMinutesAndTheIdentity() {
        let notifier = RecordingNotifier()
        let system = InterventionSystem(notifier: notifier, chooser: { $0.first })
        system.setupInterventions()

        let message = system.trigger(context: InterventionContext(
            app: "TikTok",
            minutesToday: 42,
            limit: 15,
            identityStatement: "I am someone who decides where their attention goes",
            environmentStep: "In the home screen: keep TikTok out of sight."
        ))

        XCTAssertEqual(message?.title, "Say It Out Loud")
        XCTAssertEqual(
            message?.body,
            "I am about to open TikTok. That is 42 minutes today. My limit was 15. "
                + "I am someone who decides where their attention goes. "
                + "In the home screen: keep TikTok out of sight."
        )
        XCTAssertEqual(notifier.messages.count, 1)
    }

    func testThirdLawOffersTheTwoMinuteVersionBehindTheDelay() {
        let system = InterventionSystem(notifier: RecordingNotifier())
        system.setupInterventions()

        let intervention = system.intervention(for: .response)!
        let message = system.message(for: intervention, context: InterventionContext(
            app: "Instagram",
            minutesToday: 60,
            limit: 30,
            alternative: "Read one page",
            frictionStep: "log out after every use"
        ))

        // 60 minutes against a 30 minute limit is 100% over, so the delay doubles.
        XCTAssertEqual(message.body, "Waiting 40 seconds before Instagram opens. "
            + "Two-minute version instead: Read one page. "
            + "Standing rule: log out after every use.")
    }

    func testFourthLawPricesTheChainAndTheVote() {
        let system = InterventionSystem(notifier: RecordingNotifier())
        system.setupInterventions()

        let intervention = system.intervention(for: .reward)!
        let message = system.message(for: intervention, context: InterventionContext(
            app: "Instagram",
            minutesToday: 60,
            limit: 30,
            streak: 6,
            identityStatement: "I am someone who reads",
            partner: "Sam"
        ))

        XCTAssertEqual(message.body, "Opening Instagram now ends a 6 day chain. "
            + "That is a vote against \"I am someone who reads\". Sam sees the weekly number.")
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

    func testEveryActionIsAVote() {
        let (engine, _) = makeEngine(minutes: ["Instagram": 10, "Facebook": 5, "TikTok": 90], at: fixedDate("2026-03-04 09:00"))

        let summary = engine.dailyCheckIn()

        XCTAssertEqual(summary.identityTally.votesFor, 2)
        XCTAssertEqual(summary.identityTally.votesAgainst, 1)
        XCTAssertEqual(engine.identity.biggestLeak(), "TikTok")
    }

    func testAnImplementationIntentionArmsItsOwnTrigger() {
        let notifier = RecordingNotifier()
        let playbook = Playbook(implementationIntentions: [
            ImplementationIntention(behavior: "read one page", time: "06:15", location: "the kitchen")
        ])
        let engine = AtomicBreakEngine(
            profile: .sample(),
            playbook: playbook,
            usageSource: StubUsageDataSource(minutes: ["Instagram": 65]),
            notifier: notifier,
            dateProvider: FixedDateProvider(date: fixedDate("2026-03-04 09:00"))
        )
        engine.setup()

        // 06:15 is not one of the inferred peaks; it is there because the user wrote it.
        XCTAssertTrue(engine.cueManager.triggerTimes.contains("06:15"))
        XCTAssertNotNil(engine.triggerTimeBasedInterventions(at: fixedDate("2026-03-04 06:15")))
    }

    func testTheNudgeCarriesTheUsersOwnTools() {
        let (engine, _) = makeEngine(minutes: ["Instagram": 65], at: fixedDate("2026-03-04 09:00"))

        let context = engine.context(for: "Instagram")

        XCTAssertEqual(context.app, "Instagram")
        XCTAssertNotNil(context.frictionStep, "the friction rule should reach the nudge")
        XCTAssertNotNil(context.alternative, "the two-minute version should reach the nudge")
        XCTAssertNotNil(context.environmentStep)
        XCTAssertNotNil(context.reframe)
        XCTAssertEqual(context.identityStatement, engine.identity.statement)
    }

    func testGoldilocksSuggestsATighterLimitWhenTheDaysAreEasy() {
        let (engine, _) = makeEngine(minutes: ["Instagram": 5, "Facebook": 2, "TikTok": 2], at: fixedDate("2026-03-04 09:00"))

        engine.dailyCheckIn()

        XCTAssertEqual(engine.limitSuggestions()["Instagram"], 27)

        engine.applyLimitSuggestion(for: "Instagram")
        XCTAssertEqual(engine.profile.limit(for: "Instagram"), 27)
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

// MARK: - The toolkit

private final class MovableDateProvider: DateProvider {
    var date: Date
    init(date: Date) { self.date = date }
    func now() -> Date { date }
}

private final class ScriptedUsageDataSource: UsageDataSource {
    var minutesByDay: [String: [String: Int]]

    init(_ minutesByDay: [String: [String: Int]]) {
        self.minutesByDay = minutesByDay
    }

    func historicalSummaries() -> [String: AppUsageSummary] { [:] }
    func usageMinutes(on day: String) -> [String: Int] { minutesByDay[day] ?? [:] }
}

final class FourLawsTests: XCTestCase {
    func testTheFourLawsInvert() {
        XCTAssertEqual(HabitStage.allCases.map(\.lawNumber), [1, 2, 3, 4])
        XCTAssertEqual(HabitStage.cue.buildingLaw, "Make it obvious")
        XCTAssertEqual(HabitStage.cue.breakingLaw, "Make it invisible")
        XCTAssertEqual(HabitStage.response.law(for: .build), "Make it easy")
        XCTAssertEqual(HabitStage.response.law(for: .quit), "Make it difficult")
    }

    func testEveryToolIsFiledUnderExactlyOneSection() {
        let filed = ToolSection.all.flatMap(\.tools)

        XCTAssertEqual(filed.count, ToolKind.allCases.count)
        XCTAssertEqual(Set(filed), Set(ToolKind.allCases))
        XCTAssertEqual(ToolSection.all.count, HabitStage.allCases.count + 1)
    }

    func testEveryToolCarriesItsOwnExplanation() {
        for tool in ToolKind.allCases {
            XCTAssertFalse(tool.displayName.isEmpty, "\(tool) has no name")
            XCTAssertFalse(tool.summary.isEmpty, "\(tool) has no summary")
        }
    }
}

final class CueToolTests: XCTestCase {
    func testScorecardSurfacesWhatCosts() {
        let scorecard = HabitsScorecard(entries: [
            ScorecardEntry(habit: "Scroll in bed", verdict: .bad, note: "costs an hour"),
            ScorecardEntry(habit: "Morning walk", verdict: .good)
        ])

        XCTAssertEqual(scorecard.costlyHabits, ["Scroll in bed"])
        XCTAssertEqual(scorecard.tally()[.good], 1)
        XCTAssertEqual(scorecard.entries.first?.sentence, "- Scroll in bed — costs an hour")
    }

    func testRecordingTheSameHabitTwiceUpdatesRatherThanDuplicates() {
        let scorecard = HabitsScorecard()
        scorecard.record(ScorecardEntry(habit: "Scroll in bed", verdict: .neutral))
        scorecard.record(ScorecardEntry(habit: "Scroll in bed", verdict: .bad))

        XCTAssertEqual(scorecard.entries.count, 1)
        XCTAssertEqual(scorecard.entries.first?.verdict, .bad)
    }

    func testTheSentencesReadLikeTheBook() {
        XCTAssertEqual(
            ImplementationIntention(behavior: "read one page", time: "07:00", location: "the kitchen").sentence,
            "I will read one page at 07:00 in the kitchen."
        )
        XCTAssertEqual(
            HabitStack(anchor: "I pour my coffee", newHabit: "read one page").sentence,
            "After I pour my coffee, I will read one page."
        )
        XCTAssertEqual(
            TemptationBundle(need: "I finish a block of work", want: "listen to a podcast").sentence,
            "After I finish a block of work, I will listen to a podcast."
        )
        XCTAssertEqual(
            EnvironmentRule(cue: "the phone", space: "the bedroom", intent: .hideTheCue).sentence,
            "In the bedroom: keep the phone out of sight."
        )
    }

    func testStackingChainsEachHabitOntoTheLast() {
        // Bare actions in; each one reads as the deed once and as the anchor once.
        let stacks = HabitStack.chain(["wake up", "make coffee", "read one page"])

        XCTAssertEqual(stacks.count, 2)
        XCTAssertEqual(stacks.first?.sentence, "After I wake up, I will make coffee.")
        XCTAssertEqual(stacks.last?.sentence, "After I make coffee, I will read one page.")
        XCTAssertEqual(stacks.last?.anchor, "I make coffee")
        XCTAssertTrue(HabitStack.chain(["Only one"]).isEmpty)
    }

    func testPointingAndCallingLeavesOutWhatItDoesNotKnow() {
        let bare = PointingAndCalling.script(app: "TikTok", minutesToday: 12)
        XCTAssertEqual(bare, "I am about to open TikTok. That is 12 minutes today.")

        // The limit is only mentioned once it has actually been passed.
        let under = PointingAndCalling.script(app: "TikTok", minutesToday: 12, limit: 15)
        XCTAssertEqual(under, bare)
    }
}

final class ResponseToolTests: XCTestCase {
    func testFrictionGrowsWithTheOverage() {
        XCTAssertEqual(FrictionDelay.seconds(minutesToday: 10, limit: 30), 20)
        XCTAssertEqual(FrictionDelay.seconds(minutesToday: 45, limit: 30), 30)
        XCTAssertEqual(FrictionDelay.seconds(minutesToday: 60, limit: 30), 40)

        // Capped, so a bad day does not turn into a four minute wait.
        XCTAssertEqual(FrictionDelay.seconds(minutesToday: 600, limit: 30), 80)
        XCTAssertEqual(FrictionDelay.seconds(minutesToday: 60, limit: nil), 20)
    }

    func testTwoMinuteRuleScalesTheHabitDown() {
        let gateway = GatewayHabit(fullHabit: "Read for thirty minutes", twoMinuteVersion: "Read one page")
        XCTAssertEqual(gateway.sentence, "Read for thirty minutes becomes: Read one page.")
    }
}

final class RewardToolTests: XCTestCase {
    func testNeverMissTwiceFiresOnlyOnTheSecondMiss() {
        let clock = MovableDateProvider(date: fixedDate("2026-03-01 09:00"))
        let source = ScriptedUsageDataSource([
            "2026-03-01": ["Instagram": 65],
            "2026-03-02": ["Instagram": 70],
            "2026-03-03": ["Instagram": 10]
        ])
        let tracker = HabitTracker(usageSource: source, dateProvider: clock)
        let limits = ["Instagram": 30]

        tracker.updateDailyStats(limits: limits)
        var status = tracker.chainStatus(for: "Instagram")
        XCTAssertTrue(status.missedLastDay)
        XCTAssertFalse(status.missedTwice)
        XCTAssertTrue(status.advice.contains("Missing once is an accident"))

        clock.date = fixedDate("2026-03-02 09:00")
        tracker.updateDailyStats(limits: limits)
        status = tracker.chainStatus(for: "Instagram")
        XCTAssertTrue(status.missedTwice)
        XCTAssertTrue(status.advice.contains("two-minute version"))

        clock.date = fixedDate("2026-03-03 09:00")
        tracker.updateDailyStats(limits: limits)
        status = tracker.chainStatus(for: "Instagram")
        XCTAssertFalse(status.missedTwice)
        XCTAssertEqual(status.streak, 1)
    }

    func testRecentUsageIsOrderedOldestFirst() {
        let clock = MovableDateProvider(date: fixedDate("2026-03-01 09:00"))
        let source = ScriptedUsageDataSource([
            "2026-03-01": ["Instagram": 10],
            "2026-03-02": ["Instagram": 20]
        ])
        let tracker = HabitTracker(usageSource: source, dateProvider: clock)

        tracker.updateDailyStats(limits: ["Instagram": 30])
        clock.date = fixedDate("2026-03-02 09:00")
        tracker.updateDailyStats(limits: ["Instagram": 30])

        XCTAssertEqual(tracker.recentUsage(for: "Instagram"), [10, 20])
        XCTAssertEqual(tracker.bestChain(), 2)
    }

    func testTheContractReadsAsOneDocument() {
        let contract = HabitContract(
            identityStatement: "I am someone who decides where their attention goes",
            commitments: ["keep Instagram under 30 minutes"],
            penalty: "£20 to a cause I dislike",
            partners: [AccountabilityPartner(name: "Sam", watches: "the weekly screenshot")]
        ).signed(on: "2026-03-04")

        XCTAssertTrue(contract.isSigned)
        XCTAssertTrue(contract.text.contains("• keep Instagram under 30 minutes"))
        XCTAssertTrue(contract.text.contains("If I fall short: £20 to a cause I dislike."))
        XCTAssertTrue(contract.text.contains("Witnessed by Sam."))
        XCTAssertTrue(contract.text.contains("Signed 2026-03-04."))
    }
}

final class MasteryTests: XCTestCase {
    func testGoldilocksHoldsTheLimitInTheManageableBand() {
        // Cleared every day with room to spare → tighten by a tenth.
        XCTAssertEqual(GoldilocksRule.suggestedLimit(current: 30, recentUsage: [10, 12, 8]), 27)

        // Missed every day → move the bar to just under what actually happens.
        XCTAssertEqual(GoldilocksRule.suggestedLimit(current: 30, recentUsage: [65, 70, 60]), 59)

        // A real contest → leave it alone.
        XCTAssertEqual(GoldilocksRule.suggestedLimit(current: 30, recentUsage: [25, 35, 28]), 30)

        XCTAssertEqual(GoldilocksRule.suggestedLimit(current: 30, recentUsage: []), 30)
        XCTAssertEqual(GoldilocksRule.suggestedLimit(current: 5, recentUsage: [0, 0, 0]), 5)
    }

    func testGoldilocksExplainsItself() {
        XCTAssertTrue(GoldilocksRule.verdict(current: 30, recentUsage: [10, 12, 8]).hasPrefix("Too easy"))
        XCTAssertTrue(GoldilocksRule.verdict(current: 30, recentUsage: [65, 70, 60]).hasPrefix("Too hard"))
        XCTAssertEqual(GoldilocksRule.verdict(current: 30, recentUsage: [25, 35, 28]), "Just manageable.")
    }

    func testRecastingAVoteReplacesTheOldOne() {
        let identity = IdentityTracker(statement: "I am someone who reads")
        identity.cast(day: "2026-03-04", habit: "Instagram", for: false)
        identity.cast(day: "2026-03-04", habit: "Instagram", for: true)

        XCTAssertEqual(identity.votes.count, 1)
        XCTAssertEqual(identity.tally().votesFor, 1)
        XCTAssertEqual(identity.tally().share, 1)
    }

    func testAnEmptyTallyDoesNotDivideByNothing() {
        XCTAssertEqual(VoteTally(votesFor: 0, votesAgainst: 0).share, 0)
    }

    func testTheIntegrityReportReadsTheRecordHonestly() {
        let identity = IdentityTracker(statement: "I am someone who reads")
        identity.cast(day: "2026-03-01", habit: "Instagram", for: false)
        identity.cast(day: "2026-03-02", habit: "Instagram", for: false)
        identity.cast(day: "2026-03-03", habit: "TikTok", for: true)

        let log = ReviewLog()
        log.record(ReflectionEntry(day: "2026-03-02", wentWell: "walked", toImprove: "evenings", identityRating: 3))
        log.record(ReflectionEntry(day: "2026-03-01", wentWell: "read", toImprove: "mornings", identityRating: 5))

        let report = log.report(identity: identity, bestChain: 4)

        // Recorded out of order, kept in order.
        XCTAssertEqual(log.entries.map(\.day), ["2026-03-01", "2026-03-02"])
        XCTAssertEqual(report.daysReviewed, 2)
        XCTAssertEqual(report.averageRating, 4)
        XCTAssertEqual(report.biggestLeak, "Instagram")
        XCTAssertEqual(report.bestChain, 4)
        XCTAssertTrue(report.verdict.contains("record disagrees"))
    }

    func testRatingsAreClampedToTheScale() {
        XCTAssertEqual(ReflectionEntry(day: "d", wentWell: "", toImprove: "", identityRating: 9).identityRating, 5)
        XCTAssertEqual(ReflectionEntry(day: "d", wentWell: "", toImprove: "", identityRating: 0).identityRating, 1)
    }
}

final class PlaybookTests: XCTestCase {
    func testTheSamplePlaybookFillsInEveryConfigurableTool() {
        // The five left out are run by the engine from live data, not a stored list.
        let liveTools: Set<ToolKind> = [.habitTracker, .neverMissTwice, .identityVoting, .goldilocksRule, .reflectionAndReview]
        let configurable = Set(ToolKind.allCases).subtracting(liveTools)

        XCTAssertEqual(Playbook.sample().configuredTools(), configurable)
    }

    func testOneTimeActionsAreSeparatedFromStandingDevices() {
        let playbook = Playbook.sample()

        let oneTime = playbook.entries(for: .oneTimeAction)
        let standing = playbook.entries(for: .commitmentDevice)

        XCTAssertFalse(oneTime.isEmpty)
        XCTAssertFalse(standing.isEmpty)
        XCTAssertTrue(oneTime.allSatisfy { $0.sentence.contains("done once") })
        XCTAssertTrue(standing.allSatisfy { !$0.sentence.contains("done once") })
    }

    func testLookupsPreferTheRuleWrittenForThatApp() {
        let playbook = Playbook(frictionAdjustments: [
            FrictionAdjustment(habit: "social media", direction: .add, step: "last page folder"),
            FrictionAdjustment(habit: "TikTok", direction: .add, step: "log out"),
            FrictionAdjustment(habit: "reading", direction: .remove, step: "book on the chair")
        ])

        XCTAssertEqual(playbook.frictionStep(for: "TikTok"), "log out")
        // No rule naming this app, so the general one stands in.
        XCTAssertEqual(playbook.frictionStep(for: "Reddit"), "last page folder")
        // Friction being removed is never offered as friction to add.
        XCTAssertNotEqual(playbook.frictionStep(for: "reading"), "book on the chair")
    }
}
