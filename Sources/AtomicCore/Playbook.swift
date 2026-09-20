import Foundation

/// One configured tool, flattened for display.
public struct PlaybookEntry: Equatable, Sendable, Identifiable {
    public let tool: ToolKind
    public let sentence: String

    public var id: String { "\(tool.rawValue)|\(sentence)" }

    public init(tool: ToolKind, sentence: String) {
        self.tool = tool
        self.sentence = sentence
    }
}

/// Everything the user has set up, filed under the law it serves.
///
/// The engine reads from here when it builds a nudge, so an intervention delivers
/// the user's own plan back to them rather than generic advice.
public final class Playbook {
    // 1st law — the cue
    public let scorecard: HabitsScorecard
    public var implementationIntentions: [ImplementationIntention]
    public var habitStacks: [HabitStack]
    public var environmentRules: [EnvironmentRule]

    // 2nd law — the craving
    public var temptationBundles: [TemptationBundle]
    public var motivationRituals: [MotivationRitual]
    public var reframes: [Reframe]
    public var socialGroups: [SocialGroup]

    // 3rd law — the response
    public var gatewayHabits: [GatewayHabit]
    public var frictionAdjustments: [FrictionAdjustment]
    public var commitmentDevices: [CommitmentDevice]

    // 4th law — the reward
    public var reinforcements: [Reinforcement]
    public var partners: [AccountabilityPartner]
    public var contract: HabitContract?

    public init(
        scorecard: HabitsScorecard = HabitsScorecard(),
        implementationIntentions: [ImplementationIntention] = [],
        habitStacks: [HabitStack] = [],
        environmentRules: [EnvironmentRule] = [],
        temptationBundles: [TemptationBundle] = [],
        motivationRituals: [MotivationRitual] = [],
        reframes: [Reframe] = [],
        socialGroups: [SocialGroup] = [],
        gatewayHabits: [GatewayHabit] = [],
        frictionAdjustments: [FrictionAdjustment] = [],
        commitmentDevices: [CommitmentDevice] = [],
        reinforcements: [Reinforcement] = [],
        partners: [AccountabilityPartner] = [],
        contract: HabitContract? = nil
    ) {
        self.scorecard = scorecard
        self.implementationIntentions = implementationIntentions
        self.habitStacks = habitStacks
        self.environmentRules = environmentRules
        self.temptationBundles = temptationBundles
        self.motivationRituals = motivationRituals
        self.reframes = reframes
        self.socialGroups = socialGroups
        self.gatewayHabits = gatewayHabits
        self.frictionAdjustments = frictionAdjustments
        self.commitmentDevices = commitmentDevices
        self.reinforcements = reinforcements
        self.partners = partners
        self.contract = contract
    }

    // MARK: - Lookups the interventions use

    /// The friction to put in front of a specific app, falling back to any general rule.
    public func frictionStep(for app: String) -> String? {
        let added = frictionAdjustments.filter { $0.direction == .add }
        let match = added.first { $0.habit.lowercased().contains(app.lowercased()) }
        return (match ?? added.first)?.step
    }

    public func environmentRule(for app: String) -> EnvironmentRule? {
        let hidden = environmentRules.filter { $0.intent == .hideTheCue }
        return hidden.first { $0.cue.lowercased().contains(app.lowercased()) } ?? hidden.first
    }

    /// The two-minute version of whatever should happen instead.
    public func twoMinuteAlternative() -> String? {
        gatewayHabits.first?.twoMinuteVersion
    }

    public func reinforcement(for app: String) -> String? {
        let match = reinforcements.first { $0.habit.lowercased().contains(app.lowercased()) }
        return (match ?? reinforcements.first)?.immediateReward
    }

    /// Times pulled from the implementation intentions, so a plan the user wrote
    /// becomes a trigger the app fires on.
    public var intentionTimes: [String] {
        implementationIntentions.map(\.time)
    }

    // MARK: - Display

    public func entries(for tool: ToolKind) -> [PlaybookEntry] {
        switch tool {
        case .habitsScorecard:
            return scorecard.entries.map { PlaybookEntry(tool: tool, sentence: $0.sentence) }
        case .implementationIntention:
            return implementationIntentions.map { PlaybookEntry(tool: tool, sentence: $0.sentence) }
        case .habitStacking:
            return habitStacks.map { PlaybookEntry(tool: tool, sentence: $0.sentence) }
        case .environmentDesign:
            return environmentRules.map { PlaybookEntry(tool: tool, sentence: $0.sentence) }
        case .pointingAndCalling:
            return [PlaybookEntry(tool: tool, sentence: "Name the app, the minutes and the identity out loud before opening it.")]
        case .temptationBundling:
            return temptationBundles.map { PlaybookEntry(tool: tool, sentence: $0.sentence) }
        case .motivationRitual:
            return motivationRituals.map { PlaybookEntry(tool: tool, sentence: $0.sentence) }
        case .reframing:
            return reframes.map { PlaybookEntry(tool: tool, sentence: $0.sentence) }
        case .socialCircle:
            return socialGroups.map { PlaybookEntry(tool: tool, sentence: "\($0.kind.title) — \($0.sentence)") }
        case .twoMinuteRule:
            return gatewayHabits.map { PlaybookEntry(tool: tool, sentence: $0.sentence) }
        case .frictionAdjustment:
            return frictionAdjustments.map { PlaybookEntry(tool: tool, sentence: $0.sentence) }
        case .commitmentDevice:
            return commitmentDevices.filter { !$0.isOneTimeAction }.map { PlaybookEntry(tool: tool, sentence: $0.sentence) }
        case .oneTimeAction:
            return commitmentDevices.filter(\.isOneTimeAction).map { PlaybookEntry(tool: tool, sentence: $0.sentence) }
        case .reinforcement:
            return reinforcements.map { PlaybookEntry(tool: tool, sentence: $0.sentence) }
        case .accountabilityPartner:
            return partners.map { PlaybookEntry(tool: tool, sentence: $0.sentence) }
        case .habitContract:
            guard let contract else { return [] }
            return [PlaybookEntry(tool: tool, sentence: contract.text)]
        case .habitTracker, .neverMissTwice, .identityVoting, .goldilocksRule, .reflectionAndReview:
            // Run by the engine from live data rather than configured up front.
            return []
        }
    }

    /// Which tools the user has actually put to work.
    public func configuredTools() -> Set<ToolKind> {
        Set(ToolKind.allCases.filter { !entries(for: $0).isEmpty })
    }
}

public extension Playbook {
    /// A worked example of the whole toolkit aimed at phone use, used until the
    /// onboarding flow exists.
    static func sample(targetApps: [String] = ["Instagram", "Facebook", "TikTok"]) -> Playbook {
        let worstApp = targetApps.first ?? "social media"

        let scorecard = HabitsScorecard(entries: [
            ScorecardEntry(habit: "Check the phone before getting out of bed", verdict: .bad, note: "sets the tone for the whole morning"),
            ScorecardEntry(habit: "Open \(worstApp) while waiting for anything", verdict: .bad, note: "the queue, the kettle, the lift"),
            ScorecardEntry(habit: "Scroll in bed", verdict: .bad, note: "costs an hour of sleep"),
            ScorecardEntry(habit: "Morning coffee", verdict: .neutral),
            ScorecardEntry(habit: "Walk after lunch", verdict: .good, note: "the best replacement I have")
        ])

        return Playbook(
            scorecard: scorecard,
            implementationIntentions: [
                ImplementationIntention(behavior: "read one page", time: "07:00", location: "the kitchen"),
                ImplementationIntention(behavior: "walk for ten minutes", time: "12:00", location: "the block"),
                ImplementationIntention(behavior: "leave the phone charging outside the bedroom", time: "21:00", location: "the hallway")
            ],
            habitStacks: [
                HabitStack(anchor: "I pour my coffee", newHabit: "read one page"),
                HabitStack(anchor: "I finish lunch", newHabit: "walk once round the block"),
                HabitStack(anchor: "I plug the phone in for the night", newHabit: "write one line in the review")
            ],
            environmentRules: [
                EnvironmentRule(cue: targetApps.joined(separator: ", "), space: "the home screen", intent: .hideTheCue),
                EnvironmentRule(cue: "the phone", space: "the bedroom", intent: .hideTheCue),
                EnvironmentRule(cue: "a book", space: "the bedside table", intent: .showTheCue)
            ],
            temptationBundles: [
                TemptationBundle(need: "I finish a block of work", want: "listen to a podcast on a walk"),
                TemptationBundle(need: "I log the day's usage", want: "watch one episode")
            ],
            motivationRituals: [
                MotivationRitual(ritual: "Put on the same playlist", habit: "start the ten-minute walk")
            ],
            reframes: [
                Reframe(from: "I have to stay off my phone", to: "I get my evening back"),
                Reframe(from: "I am missing out", to: "I am opting out of an argument I never joined")
            ],
            socialGroups: [
                SocialGroup(kind: .theClose, name: "Household", norm: "phones stay out of the bedroom"),
                SocialGroup(kind: .theMany, name: "Tuesday running group", norm: "nobody is on their phone for an hour"),
                SocialGroup(kind: .thePowerful, name: "People whose attention I admire", norm: "they read more than they scroll")
            ],
            gatewayHabits: [
                GatewayHabit(fullHabit: "Read for thirty minutes", twoMinuteVersion: "Read one page"),
                GatewayHabit(fullHabit: "Walk for an hour", twoMinuteVersion: "Put your shoes on and step outside"),
                GatewayHabit(fullHabit: "Meditate for twenty minutes", twoMinuteVersion: "Take three slow breaths")
            ],
            frictionAdjustments: [
                FrictionAdjustment(habit: worstApp, direction: .add, step: "log out after every use, so the password is the price of entry"),
                FrictionAdjustment(habit: "social media", direction: .add, step: "move the apps into a folder on the last page"),
                FrictionAdjustment(habit: "reading", direction: .remove, step: "leave the book open on the arm of the chair")
            ],
            commitmentDevices: [
                CommitmentDevice(name: "Screen Time limit set by someone else", locksIn: "a daily cap you cannot quietly raise"),
                CommitmentDevice(name: "Greyscale after 21:00", locksIn: "a duller phone at the hour it costs most"),
                CommitmentDevice(name: "Delete the apps from the phone", locksIn: "browser-only access", isOneTimeAction: true),
                CommitmentDevice(name: "Turn off every non-human notification", locksIn: "no manufactured cues", isOneTimeAction: true),
                CommitmentDevice(name: "Buy an alarm clock", locksIn: "no reason for the phone to be by the bed", isOneTimeAction: true)
            ],
            reinforcements: [
                Reinforcement(habit: worstApp, immediateReward: "move the saved minutes into the reading jar"),
                Reinforcement(habit: "a clean day", immediateReward: "tick the chain and see it grow")
            ],
            partners: [
                AccountabilityPartner(name: "Sam", watches: "the weekly screen time screenshot")
            ],
            contract: HabitContract(
                identityStatement: "I am someone who decides where their attention goes",
                commitments: [
                    "keep \(worstApp) under its daily limit",
                    "leave the phone outside the bedroom overnight",
                    "never miss twice"
                ],
                penalty: "I send Sam the screenshot anyway, and £20 to a cause I dislike",
                partners: [AccountabilityPartner(name: "Sam", watches: "the weekly screen time screenshot")]
            )
        )
    }
}
