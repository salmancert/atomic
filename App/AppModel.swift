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

    private let engine: AtomicBreakEngine

    init(engine: AtomicBreakEngine = AtomicBreakEngine(notifier: UserNotificationsNotifier())) {
        self.engine = engine
    }

    var profile: UserProfile { engine.profile }
    var targetApps: [String] { engine.profile.targetApps.sorted() }
    var limits: [String: Int] { engine.profile.dailyTimeLimits }
    var implementationIntentions: [String] { engine.profile.implementationIntentions }
    var replacementActivities: [String] { engine.profile.replacementActivities }

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
        unlockedRewards = engine.rewardSystem.unlockedRewards
    }

    func minutes(for app: String) -> Int { usage[app] ?? 0 }

    func limit(for app: String) -> Int { limits[app] ?? 0 }

    func streak(for app: String) -> Int { streaks[app] ?? 0 }

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

    func handleLocationUpdate(_ coordinate: Coordinate) {
        lastMessage = engine.triggerLocationBasedInterventions(at: coordinate)
    }

    func handleScheduledCheck(at date: Date = Date()) {
        lastMessage = engine.triggerTimeBasedInterventions(at: date)
    }

    /// Fires a nudge on demand, so the four laws can be tried out from Settings.
    func previewIntervention(_ law: Intervention.Law) {
        guard let intervention = engine.interventionSystem.interventions.first(where: { $0.law == law }) else { return }
        lastMessage = engine.interventionSystem.apply(intervention, context: engine.currentContext())
    }
}
