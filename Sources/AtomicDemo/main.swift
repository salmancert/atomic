import AtomicCore
import Foundation

// A terminal walkthrough of one day in the habit loop. The iOS app runs exactly the
// same engine; this exists so the logic can be exercised without a Mac or a device.

let notifier = RecordingNotifier()
let engine = AtomicBreakEngine(notifier: notifier)
engine.setup()

let summary = engine.dailyCheckIn()

print("AtomicBreak — \(summary.day)")
print(String(repeating: "-", count: 32))

for app in engine.profile.targetApps.sorted() {
    let minutes = summary.usage[app] ?? 0
    let limit = engine.profile.limit(for: app) ?? 0
    let state = minutes <= limit ? "under" : "OVER"
    let streak = summary.streaks[app] ?? 0
    print("\(app.padding(toLength: 12, withPad: " ", startingAt: 0)) \(minutes)/\(limit) min  \(state)  streak \(streak)")
}

print(String(repeating: "-", count: 32))
print("Points earned today: \(summary.pointsEarned)")
print("Points balance:      \(summary.totalPoints)")
print("Rewards unlocked:    \(engine.rewardSystem.unlockedRewards.joined(separator: ", "))")

if let message = engine.interventionSystem.trigger(context: engine.currentContext()) {
    print("\nSample intervention → \(message.title): \(message.body)")
}

if !notifier.messages.isEmpty {
    print("\nNotifications queued:")
    for message in notifier.messages {
        print("  • \(message.title): \(message.body)")
    }
}
