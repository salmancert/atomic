import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem { Label("Dashboard", systemImage: "chart.bar") }
                .tag(0)

            HabitsView()
                .tabItem { Label("Habits", systemImage: "list.bullet") }
                .tag(1)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gear") }
                .tag(2)
        }
    }
}

struct DashboardView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationStack {
            List {
                Section("Today's app usage") {
                    ForEach(model.targetApps, id: \.self) { app in
                        UsageRow(app: app)
                    }
                }

                Section("Progress") {
                    LabeledRow(title: "Points", value: "\(model.points)")

                    ForEach(model.targetApps, id: \.self) { app in
                        LabeledRow(title: "\(app) streak", value: "\(model.streak(for: app)) days")
                    }
                }

                if !model.unlockedRewards.isEmpty {
                    Section("Rewards unlocked") {
                        ForEach(model.unlockedRewards, id: \.self) { reward in
                            Label(reward, systemImage: "rosette")
                        }
                    }
                }
            }
            .navigationTitle("AtomicBreak")
            .refreshable { model.refresh() }
        }
    }
}

struct UsageRow: View {
    @EnvironmentObject private var model: AppModel
    let app: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(app)
                Spacer()
                Text("\(model.minutes(for: app)) / \(model.limit(for: app)) min")
                    .foregroundColor(model.color(for: app))
                    .monospacedDigit()
            }

            ProgressView(value: model.progress(for: app))
                .tint(model.color(for: app))
        }
        .padding(.vertical, 4)
    }
}

struct LabeledRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
                .monospacedDigit()
        }
    }
}

struct HabitsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationStack {
            List {
                Section("My implementation intentions") {
                    ForEach(model.implementationIntentions, id: \.self) { intention in
                        Text(intention)
                    }
                }

                Section("Replacement activities") {
                    ForEach(model.replacementActivities, id: \.self) { activity in
                        Label(activity, systemImage: "arrow.turn.up.right")
                    }
                }
            }
            .navigationTitle("Habit Builder")
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationStack {
            List {
                Section("Daily time limits") {
                    ForEach(model.targetApps, id: \.self) { app in
                        LabeledRow(title: app, value: "\(model.limit(for: app)) min")
                    }
                }

                Section {
                    ForEach(Intervention.Law.allCases, id: \.self) { law in
                        Button(law.rawValue.capitalized) {
                            model.previewIntervention(law)
                        }
                    }
                } header: {
                    Text("Try an intervention")
                } footer: {
                    Text("Each one inverts one of the four laws of behaviour change.")
                }

                if let message = model.lastMessage {
                    Section("Last nudge") {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(message.title).font(.headline)
                            Text(message.body).font(.subheadline).foregroundColor(.secondary)
                        }
                    }
                }

                Section {
                    Text("Usage figures come from a built-in sample data source. Real Screen Time numbers need Apple's Family Controls entitlement.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#if DEBUG
@MainActor
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        let model = AppModel(engine: AtomicBreakEngine(notifier: RecordingNotifier()))
        model.start()
        return ContentView().environmentObject(model)
    }
}
#endif
