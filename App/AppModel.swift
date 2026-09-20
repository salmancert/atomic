import Foundation
import SwiftUI

/// The bridge between the engine and SwiftUI.
///
/// Main actor isolated because every property here drives the UI; the delegates that
/// call in from CoreLocation hop onto the main actor first.
@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var usage: [String: Int] = [:]
    @Published private(set) var streaks: [String: Int] = [:]
    @Published private(set) var points: Int = 0
    @Published private(set) var unlockedRewards: [String] = []
    @Published private(set) var lastMessage: NotifierMessage?

    @Published private(set) var chains: [ChainStatus] = []
    @Published private(set) var identityTally = VoteTally(votesFor: 0, votesAgainst: 0)
    @Published private(set) var limitSuggestions: [String: Int] = [:]
    @Published private(set) var report: IntegrityReport?

    private let engine: AtomicBreakEngine

    init(engine: AtomicBreakEngine = AtomicBreakEngine(notifier: UserNotificationsNotifier())) {
        self.engine = engine
    }

    // MARK: - Plan

    var profile: UserProfile { engine.profile }
    var playbook: Playbook { engine.playbook }
    var targetApps: [String] { engine.profile.targetApps.sorted() }
    var limits: [String: Int] { engine.profile.dailyTimeLimits }
    var replacementActivities: [String] { engine.profile.replacementActivities }
    var identityStatement: String { engine.identity.statement }
    var contract: HabitContract? { engine.playbook.contract }
    var reflections: [ReflectionEntry] { engine.reviewLog.entries }

    /// The configured tools for one section of the plan.
    func entries(for tool: ToolKind) -> [PlaybookEntry] {
        engine.playbook.entries(for: tool)
    }

    /// Tools the engine runs from live data have no configured entries but are
    /// still in use, so they count as set up.
    func isConfigured(_ tool: ToolKind) -> Bool {
        switch tool {
        case .habitTracker, .neverMissTwice, .identityVoting, .goldilocksRule, .reflectionAndReview:
            return true
        default:
            return !engine.playbook.entries(for: tool).isEmpty
        }
    }

    // MARK: - Lifecycle

    func start() {
        engine.setup()
        refresh()
    }

    /// Runs a check-in and republishes everything the views read.
    func refresh() {
        let summary = engine.dailyCheckIn()
        usage = summary.usage
        streaks = summary.streaks
        points = summary.totalPoints
        identityTally = summary.identityTally
        limitSuggestions = summary.limitSuggestions
        unlockedRewards = engine.rewardSystem.unlockedRewards
        chains = engine.chainStatuses()
        report = engine.integrityReport()

        // Missing once is an accident; missing twice is a new habit forming.
        if let message = engine.warnAboutBrokenChains().first {
            lastMessage = message
        }
    }

    // MARK: - Today

    func minutes(for app: String) -> Int { usage[app] ?? 0 }

    func limit(for app: String) -> Int { limits[app] ?? 0 }

    func streak(for app: String) -> Int { streaks[app] ?? 0 }

    func chain(for app: String) -> ChainStatus? {
        chains.first { $0.habit == app }
    }

    /// 0...1, clamped, so the progress bars never overflow on a heavy day.
    func progress(for app: String) -> Double {
        let limit = limit(for: app)
        guard limit > 0 else { return 0 }
        return min(Double(minutes(for: app)) / Double(limit), 1)
    }

    func color(for app: String) -> Color {
        let limit = limit(for: app)
        let minutes = minutes(for: app)
        guard limit > 0 else { return .green }

        if minutes > limit { return .red }
        if Double(minutes) > Double(limit) * 0.8 { return .orange }
        return .green
    }

    // MARK: - Actions

    func handleLocationUpdate(_ coordinate: Coordinate) {
        lastMessage = engine.triggerLocationBasedInterventions(at: coordinate)
    }

    func handleScheduledCheck(at date: Date = Date()) {
        lastMessage = engine.triggerTimeBasedInterventions(at: date)
    }

    /// Fires the nudge for one law on demand, so each can be tried from the plan.
    func previewIntervention(_ stage: HabitStage) {
        guard let intervention = engine.interventionSystem.intervention(for: stage) else { return }
        lastMessage = engine.interventionSystem.apply(intervention, context: engine.currentContext())
    }

    /// Moves a limit back into the just-manageable band.
    func applyLimitSuggestion(for app: String) {
        engine.applyLimitSuggestion(for: app)
        refresh()
    }

    func recordReflection(wentWell: String, toImprove: String, rating: Int) {
        engine.recordReflection(wentWell: wentWell, toImprove: toImprove, identityRating: rating)
        report = engine.integrityReport()
        objectWillChange.send()
    }
}
