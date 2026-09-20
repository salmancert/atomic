import Foundation

/// The four stages of the habit loop.
///
/// Each stage is governed by one law, stated one way to build a habit and inverted
/// to break one. Everything in this module hangs off these four.
public enum HabitStage: String, CaseIterable, Sendable {
    case cue
    case craving
    case response
    case reward

    public var lawNumber: Int {
        switch self {
        case .cue: return 1
        case .craving: return 2
        case .response: return 3
        case .reward: return 4
        }
    }

    public var title: String {
        rawValue.capitalized
    }

    /// The law as stated for building a habit.
    public var buildingLaw: String {
        switch self {
        case .cue: return "Make it obvious"
        case .craving: return "Make it attractive"
        case .response: return "Make it easy"
        case .reward: return "Make it satisfying"
        }
    }

    /// The same law inverted, which is how a habit is broken.
    public var breakingLaw: String {
        switch self {
        case .cue: return "Make it invisible"
        case .craving: return "Make it unattractive"
        case .response: return "Make it difficult"
        case .reward: return "Make it unsatisfying"
        }
    }

    public func law(for direction: HabitDirection) -> String {
        switch direction {
        case .build: return buildingLaw
        case .quit: return breakingLaw
        }
    }
}

/// Whether a law is being used to build a habit or to break one.
public enum HabitDirection: String, CaseIterable, Sendable {
    case build
    case quit
}

/// Every tool in the toolkit, and where it sits in the loop.
public enum ToolKind: String, CaseIterable, Sendable {
    // 1st law — the cue
    case habitsScorecard
    case implementationIntention
    case habitStacking
    case environmentDesign
    case pointingAndCalling

    // 2nd law — the craving
    case temptationBundling
    case motivationRitual
    case reframing
    case socialCircle

    // 3rd law — the response
    case twoMinuteRule
    case frictionAdjustment
    case commitmentDevice
    case oneTimeAction

    // 4th law — the reward
    case habitTracker
    case neverMissTwice
    case reinforcement
    case habitContract
    case accountabilityPartner

    // Practices that sit behind all four
    case identityVoting
    case goldilocksRule
    case reflectionAndReview

    /// `nil` for the practices that sit behind all four laws rather than inside one.
    public var stage: HabitStage? {
        switch self {
        case .habitsScorecard, .implementationIntention, .habitStacking,
             .environmentDesign, .pointingAndCalling:
            return .cue
        case .temptationBundling, .motivationRitual, .reframing, .socialCircle:
            return .craving
        case .twoMinuteRule, .frictionAdjustment, .commitmentDevice, .oneTimeAction:
            return .response
        case .habitTracker, .neverMissTwice, .reinforcement, .habitContract, .accountabilityPartner:
            return .reward
        case .identityVoting, .goldilocksRule, .reflectionAndReview:
            return nil
        }
    }

    public var displayName: String {
        switch self {
        case .habitsScorecard: return "Habits Scorecard"
        case .implementationIntention: return "Implementation Intention"
        case .habitStacking: return "Habit Stacking"
        case .environmentDesign: return "Environment Design"
        case .pointingAndCalling: return "Pointing and Calling"
        case .temptationBundling: return "Temptation Bundling"
        case .motivationRitual: return "Motivation Ritual"
        case .reframing: return "Reframing"
        case .socialCircle: return "Social Circle"
        case .twoMinuteRule: return "Two-Minute Rule"
        case .frictionAdjustment: return "Law of Least Effort"
        case .commitmentDevice: return "Commitment Device"
        case .oneTimeAction: return "One-Time Action"
        case .habitTracker: return "Habit Tracker"
        case .neverMissTwice: return "Never Miss Twice"
        case .reinforcement: return "Reinforcement"
        case .habitContract: return "Habit Contract"
        case .accountabilityPartner: return "Accountability Partner"
        case .identityVoting: return "Identity Votes"
        case .goldilocksRule: return "Goldilocks Rule"
        case .reflectionAndReview: return "Reflection and Review"
        }
    }

    public var summary: String {
        switch self {
        case .habitsScorecard:
            return "List what you already do each day and mark it +, = or −. You cannot change a habit you have not noticed."
        case .implementationIntention:
            return "I will [behaviour] at [time] in [location]. A plan beats an intention."
        case .habitStacking:
            return "After [current habit], I will [new habit]. Let a habit you already have carry the new one."
        case .environmentDesign:
            return "Context is the cue. Hide the cues of the habit you are breaking; leave the cues of its replacement in plain sight."
        case .pointingAndCalling:
            return "Say the action out loud before you take it. Naming it drags an automatic habit back into the light."
        case .temptationBundling:
            return "After [what I need to do], I will [what I want to do]. Pair the necessary with the wanted."
        case .motivationRitual:
            return "Do something you enjoy immediately before a hard habit, until the ritual itself pulls you in."
        case .reframing:
            return "Swap \"I have to\" for \"I get to\". The behaviour is the same; the craving is not."
        case .socialCircle:
            return "Join a group where the behaviour you want is already normal — the close, the many, and the powerful."
        case .twoMinuteRule:
            return "Scale the replacement down until it takes two minutes. A habit must be established before it can be improved."
        case .frictionAdjustment:
            return "Add steps in front of the bad habit and take them away from the good one."
        case .commitmentDevice:
            return "A choice made now that locks in better behaviour later, when willpower is gone."
        case .oneTimeAction:
            return "Do it once and it keeps paying: delete the app, unsubscribe, turn the notification off."
        case .habitTracker:
            return "Mark the day. Don't break the chain — the streak becomes its own reward."
        case .neverMissTwice:
            return "Missing once is an accident. Missing twice is the start of a new habit."
        case .reinforcement:
            return "Give yourself an immediate reward for a habit whose real payoff is far away."
        case .habitContract:
            return "Write down the commitment and the cost of breaking it, and have someone sign it."
        case .accountabilityPartner:
            return "Someone who will notice. Knowing you will be watched is its own deterrent."
        case .identityVoting:
            return "Every action is a vote for the type of person you wish to become."
        case .goldilocksRule:
            return "Keep the target just manageable — hard enough to hold your attention, easy enough to hit."
        case .reflectionAndReview:
            return "Look back on purpose. Improvement needs a record and an honest reading of it."
        }
    }
}

/// Tools grouped for display: the four stages in order, then the practices that sit
/// outside them.
public struct ToolSection: Equatable, Sendable, Identifiable {
    public let stage: HabitStage?
    public let tools: [ToolKind]

    public var id: String { stage?.rawValue ?? "mastery" }

    public var title: String {
        guard let stage else { return "Beyond the four laws" }
        return "\(stage.lawNumber). \(stage.breakingLaw)"
    }

    public var subtitle: String {
        guard let stage else { return "The practices behind all four" }
        return "\(stage.title) — to build instead: \(stage.buildingLaw.lowercased())"
    }

    public static var all: [ToolSection] {
        let staged = HabitStage.allCases.map { stage in
            ToolSection(stage: stage, tools: ToolKind.allCases.filter { $0.stage == stage })
        }
        return staged + [ToolSection(stage: nil, tools: ToolKind.allCases.filter { $0.stage == nil })]
    }

    public init(stage: HabitStage?, tools: [ToolKind]) {
        self.stage = stage
        self.tools = tools
    }
}
