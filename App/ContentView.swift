import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayView()
                .tabItem { Label("Today", systemImage: "chart.bar") }
                .tag(0)

            ScorecardView()
                .tabItem { Label("Scorecard", systemImage: "checklist") }
                .tag(1)

            PlanView()
                .tabItem { Label("Plan", systemImage: "list.bullet.rectangle") }
                .tag(2)

            ReviewView()
                .tabItem { Label("Review", systemImage: "arrow.triangle.2.circlepath") }
                .tag(3)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gear") }
                .tag(4)
        }
    }
}

// MARK: - Today

struct TodayView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(model.identityStatement)
                        .font(.headline)
                    IdentityVotesRow()
                } header: {
                    Text("Identity")
                } footer: {
                    Text("Every action is a vote for the type of person you wish to become.")
                }

                Section("Today's app usage") {
                    ForEach(model.targetApps, id: \.self) { app in
                        UsageRow(app: app)
                    }
                }

                Section {
                    ForEach(model.chains, id: \.habit) { chain in
                        ChainRow(chain: chain)
                    }
                } header: {
                    Text("The chain")
                } footer: {
                    Text("Missing once is an accident. Missing twice is the start of a new habit.")
                }

                Section("Reinforcement") {
                    LabeledRow(title: "Points", value: "\(model.points)")

                    ForEach(model.entries(for: .reinforcement)) { entry in
                        Text(entry.sentence).font(.subheadline)
                    }

                    ForEach(model.unlockedRewards, id: \.self) { reward in
                        Label(reward, systemImage: "rosette")
                    }
                }
            }
            .navigationTitle("AtomicBreak")
            .refreshable { model.refresh() }
        }
    }
}

struct IdentityVotesRow: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Today's votes")
                Spacer()
                Text("\(model.identityTally.votesFor) for · \(model.identityTally.votesAgainst) against")
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }

            ProgressView(value: model.identityTally.share)
                .tint(model.identityTally.share >= 0.5 ? .green : .orange)
        }
        .padding(.vertical, 4)
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

            if let suggested = model.limitSuggestions[app] {
                Button("Goldilocks: move the limit to \(suggested) min") {
                    model.applyLimitSuggestion(for: app)
                }
                .font(.caption)
            }
        }
        .padding(.vertical, 4)
    }
}

struct ChainRow: View {
    let chain: ChainStatus

    private var icon: String {
        if chain.missedTwice { return "exclamationmark.triangle.fill" }
        if chain.missedLastDay { return "arrow.counterclockwise" }
        return "link"
    }

    private var tint: Color {
        if chain.missedTwice { return .red }
        if chain.missedLastDay { return .orange }
        return .green
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(tint)
            Text(chain.advice)
                .font(.subheadline)
        }
        .padding(.vertical, 2)
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

// MARK: - Scorecard

struct ScorecardView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(model.playbook.scorecard.entries) { entry in
                        HStack(alignment: .top, spacing: 12) {
                            Text(entry.verdict.rawValue)
                                .font(.title3.bold())
                                .foregroundColor(color(for: entry.verdict))
                                .frame(width: 20)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.habit)
                                if let note = entry.note {
                                    Text(note)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                } header: {
                    Text("Habits Scorecard")
                } footer: {
                    Text(ToolKind.habitsScorecard.summary)
                }
            }
            .navigationTitle("Scorecard")
        }
    }

    private func color(for verdict: ScorecardEntry.Verdict) -> Color {
        switch verdict {
        case .good: return .green
        case .neutral: return .secondary
        case .bad: return .red
        }
    }
}

// MARK: - Plan

struct PlanView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationStack {
            List {
                ForEach(ToolSection.all) { section in
                    Section {
                        ForEach(section.tools, id: \.self) { tool in
                            NavigationLink {
                                ToolDetailView(tool: tool)
                            } label: {
                                ToolRow(tool: tool)
                            }
                        }

                        if let stage = section.stage {
                            Button("Try this nudge") {
                                model.previewIntervention(stage)
                            }
                            .font(.footnote)
                        }
                    } header: {
                        Text(section.title)
                    } footer: {
                        Text(section.subtitle)
                    }
                }

                if let message = model.lastMessage {
                    Section("Last nudge") {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(message.title).font(.headline)
                            Text(message.body).font(.subheadline).foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("The Plan")
        }
    }
}

struct ToolRow: View {
    @EnvironmentObject private var model: AppModel
    let tool: ToolKind

    var body: some View {
        HStack {
            Image(systemName: model.isConfigured(tool) ? "checkmark.circle.fill" : "circle")
                .foregroundColor(model.isConfigured(tool) ? .green : .secondary)
            Text(tool.displayName)
        }
    }
}

struct ToolDetailView: View {
    @EnvironmentObject private var model: AppModel
    let tool: ToolKind

    var body: some View {
        List {
            Section {
                Text(tool.summary)
                    .font(.subheadline)
            } header: {
                Text(law)
            }

            let entries = model.entries(for: tool)
            if entries.isEmpty {
                Section("In use") {
                    Text(liveDescription)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            } else {
                Section("Mine") {
                    ForEach(entries) { entry in
                        Text(entry.sentence)
                            .font(.subheadline)
                    }
                }
            }
        }
        .navigationTitle(tool.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var law: String {
        guard let stage = tool.stage else { return "Beyond the four laws" }
        return "\(stage.lawNumber). \(stage.breakingLaw)"
    }

    /// The tools the engine runs from live data rather than a stored list.
    private var liveDescription: String {
        switch tool {
        case .habitTracker:
            return "Running on today's chain — see the Today tab."
        case .neverMissTwice:
            return "Watching every tracked app; a second miss in a row raises an alert."
        case .identityVoting:
            return "Each app under its limit casts a vote for \"\(model.identityStatement)\"."
        case .goldilocksRule:
            return "Checking each limit against the last seven days and offering a new one when it drifts."
        case .reflectionAndReview:
            return "Kept in the Review tab."
        default:
            return "Not set up yet."
        }
    }
}

// MARK: - Review

struct ReviewView: View {
    @EnvironmentObject private var model: AppModel
    @State private var wentWell = ""
    @State private var toImprove = ""
    @State private var rating = 3

    var body: some View {
        NavigationStack {
            List {
                if let report = model.report {
                    Section {
                        Text(report.identity).font(.headline)
                        Text(report.verdict).font(.subheadline).foregroundColor(.secondary)
                        LabeledRow(title: "Votes for", value: "\(report.tally.votesFor)")
                        LabeledRow(title: "Votes against", value: "\(report.tally.votesAgainst)")
                        LabeledRow(title: "Best chain", value: "\(report.bestChain) days")
                        if let leak = report.biggestLeak {
                            LabeledRow(title: "Biggest leak", value: leak)
                        }
                    } header: {
                        Text("Integrity report")
                    } footer: {
                        Text(ToolKind.reflectionAndReview.summary)
                    }
                }

                Section("Today's reflection") {
                    TextField("What went well", text: $wentWell, axis: .vertical)
                    TextField("What to improve", text: $toImprove, axis: .vertical)

                    Stepper("Identity rating: \(rating)/5", value: $rating, in: 1...5)

                    Button("Save reflection") {
                        model.recordReflection(wentWell: wentWell, toImprove: toImprove, rating: rating)
                        wentWell = ""
                        toImprove = ""
                    }
                    .disabled(wentWell.isEmpty && toImprove.isEmpty)
                }

                if !model.reflections.isEmpty {
                    Section("Past reflections") {
                        ForEach(model.reflections.reversed()) { entry in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.day).font(.caption).foregroundColor(.secondary)
                                if !entry.wentWell.isEmpty {
                                    Text("+ \(entry.wentWell)").font(.subheadline)
                                }
                                if !entry.toImprove.isEmpty {
                                    Text("→ \(entry.toImprove)").font(.subheadline)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
            .navigationTitle("Review")
        }
    }
}

// MARK: - Settings

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

                if let contract = model.contract {
                    Section {
                        Text(contract.text)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    } header: {
                        Text("Habit contract")
                    } footer: {
                        Text(contract.isSigned ? "Signed \(contract.signedOn ?? "")." : "Unsigned. A contract nobody witnessed is a wish.")
                    }
                }

                Section("Replacement activities") {
                    ForEach(model.replacementActivities, id: \.self) { activity in
                        Label(activity, systemImage: "arrow.turn.up.right")
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
