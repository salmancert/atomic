import AtomicCore
import Foundation

// A terminal walkthrough of one day in the habit loop, and of the toolkit behind it.
// The iOS app runs exactly the same engine; this exists so the logic can be
// exercised without a Mac or a device.

let notifier = RecordingNotifier()
let engine = AtomicBreakEngine(notifier: notifier)
engine.setup()

let summary = engine.dailyCheckIn()

func rule() { print(String(repeating: "-", count: 64)) }

print("AtomicBreak — \(summary.day)")
print(engine.identity.statement)
rule()

for app in engine.profile.targetApps.sorted() {
    let minutes = summary.usage[app] ?? 0
    let limit = engine.profile.limit(for: app) ?? 0
    let state = minutes <= limit ? "under" : "OVER"
    let streak = summary.streaks[app] ?? 0
    print("\(app.padding(toLength: 12, withPad: " ", startingAt: 0)) \(minutes)/\(limit) min  \(state)  chain \(streak)")
}

rule()
print("Votes today:     \(summary.identityTally.votesFor) for, \(summary.identityTally.votesAgainst) against")
print("Points earned:   \(summary.pointsEarned)")
print("Points balance:  \(summary.totalPoints)")

if !summary.limitSuggestions.isEmpty {
    let moves = summary.limitSuggestions
        .sorted { $0.key < $1.key }
        .map { "\($0.key) → \($0.value) min" }
        .joined(separator: ", ")
    print("Goldilocks:      \(moves)")
}

if !summary.missedTwice.isEmpty {
    print("Missed twice:    \(summary.missedTwice.joined(separator: ", "))")
}

// The toolkit, filed under the law each tool serves.
for section in ToolSection.all {
    rule()
    print(section.title.uppercased())
    print(section.subtitle)
    print("")

    for tool in section.tools {
        let entries = engine.playbook.entries(for: tool)
        print("  \(tool.displayName)")
        if entries.isEmpty {
            print("    (run from live data)")
        }
        for entry in entries.prefix(3) {
            for (index, line) in entry.sentence.split(separator: "\n").enumerated() {
                print("    \(index == 0 ? "·" : " ") \(line)")
            }
        }
    }
}

// One nudge per law, each written from the plan above.
rule()
print("THE FOUR NUDGES")
for stage in HabitStage.allCases {
    guard let intervention = engine.interventionSystem.intervention(for: stage) else { continue }
    let message = engine.interventionSystem.message(for: intervention, context: engine.currentContext())
    print("\n  \(stage.lawNumber). \(stage.breakingLaw) — \(message.title)")
    print("     \(message.body)")
}

rule()
print("Notifications queued: \(notifier.messages.count)")
