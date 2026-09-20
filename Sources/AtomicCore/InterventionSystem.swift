import Foundation

/// One nudge, tagged with the stage of the loop it acts on and the tool it applies.
public struct Intervention: Equatable, Sendable, Identifiable {
    public let stage: HabitStage
    public let tool: ToolKind
    public let name: String
    public let action: String

    public var id: String { name }

    /// The law this nudge is inverting.
    public var law: String { stage.breakingLaw }

    public init(stage: HabitStage, tool: ToolKind, name: String, action: String) {
        self.stage = stage
        self.tool = tool
        self.name = name
        self.action = action
    }
}

/// Everything a nudge needs in order to speak about this user, today.
public struct InterventionContext: Equatable, Sendable {
    public var app: String
    public var minutesToday: Int
    public var limit: Int?
    public var streak: Int?
    public var identityStatement: String?
    /// The two-minute version of whatever should happen instead.
    public var alternative: String?
    public var frictionStep: String?
    public var environmentStep: String?
    public var reframe: String?
    public var temptationBundle: String?
    public var reward: String?
    public var partner: String?

    public init(
        app: String,
        minutesToday: Int,
        limit: Int? = nil,
        streak: Int? = nil,
        identityStatement: String? = nil,
        alternative: String? = nil,
        frictionStep: String? = nil,
        environmentStep: String? = nil,
        reframe: String? = nil,
        temptationBundle: String? = nil,
        reward: String? = nil,
        partner: String? = nil
    ) {
        self.app = app
        self.minutesToday = minutesToday
        self.limit = limit
        self.streak = streak
        self.identityStatement = identityStatement
        self.alternative = alternative
        self.frictionStep = frictionStep
        self.environmentStep = environmentStep
        self.reframe = reframe
        self.temptationBundle = temptationBundle
        self.reward = reward
        self.partner = partner
    }
}

/// Picks a nudge and writes it from the user's own plan.
///
/// One intervention per law, each one handing back a tool the user configured rather
/// than generic advice.
public final class InterventionSystem {
    public private(set) var interventions: [Intervention] = []
    public private(set) var triggeredCounts: [String: Int] = [:]

    private let notifier: Notifier
    private let chooser: ([Intervention]) -> Intervention?

    /// - Parameter chooser: injected so tests get a deterministic pick.
    public init(notifier: Notifier, chooser: @escaping ([Intervention]) -> Intervention? = { $0.randomElement() }) {
        self.notifier = notifier
        self.chooser = chooser
    }

    public func setupInterventions() {
        interventions = [
            Intervention(
                stage: .cue,
                tool: .pointingAndCalling,
                name: "Name It Out Loud",
                action: "Say the app, the minutes and the identity before opening it"
            ),
            Intervention(
                stage: .craving,
                tool: .reframing,
                name: "Reframe The Craving",
                action: "Put the cost of the scroll next to what it buys"
            ),
            Intervention(
                stage: .response,
                tool: .frictionAdjustment,
                name: "Add Friction",
                action: "Stall the opening and offer the two-minute alternative"
            ),
            Intervention(
                stage: .reward,
                tool: .neverMissTwice,
                name: "Make It Cost",
                action: "Show the chain and the vote this is about to cast"
            )
        ]
    }

    public func intervention(for stage: HabitStage) -> Intervention? {
        interventions.first { $0.stage == stage }
    }

    public func selectIntervention() -> Intervention? {
        chooser(interventions)
    }

    /// Selects a nudge and delivers it. `nil` when no interventions are configured.
    @discardableResult
    public func trigger(context: InterventionContext) -> NotifierMessage? {
        guard let intervention = selectIntervention() else { return nil }
        return apply(intervention, context: context)
    }

    @discardableResult
    public func apply(_ intervention: Intervention, context: InterventionContext) -> NotifierMessage {
        triggeredCounts[intervention.name, default: 0] += 1

        let message = message(for: intervention, context: context)
        notifier.notify(message)
        return message
    }

    /// Every line is built from the user's own numbers and their own plan — a nudge
    /// quoting someone else's usage is the fastest way to lose their trust.
    public func message(for intervention: Intervention, context: InterventionContext) -> NotifierMessage {
        switch intervention.stage {
        case .cue:
            // 1st law inverted: make it invisible, and drag the reach out of autopilot.
            var body = PointingAndCalling.script(
                app: context.app,
                minutesToday: context.minutesToday,
                limit: context.limit,
                identity: context.identityStatement
            )
            if let step = context.environmentStep {
                body += " \(step)"
            }
            return NotifierMessage(title: "Say It Out Loud", body: body)

        case .craving:
            // 2nd law inverted: make it unattractive.
            let pages = max(1, context.minutesToday) // roughly a page a minute
            var body = "\(context.minutesToday) minutes on \(context.app) is about \(pages) pages of a book."
            if let reframe = context.reframe {
                body += " \(reframe)"
            } else if let bundle = context.temptationBundle {
                body += " \(bundle)"
            }
            return NotifierMessage(title: "Worth It?", body: body)

        case .response:
            // 3rd law inverted: make it difficult.
            let seconds = FrictionDelay.seconds(minutesToday: context.minutesToday, limit: context.limit)
            var body = "Waiting \(seconds) seconds before \(context.app) opens."
            if let alternative = context.alternative {
                body += " Two-minute version instead: \(alternative)."
            }
            if let step = context.frictionStep {
                body += " Standing rule: \(step)."
            }
            return NotifierMessage(title: "Taking A Pause", body: body)

        case .reward:
            // 4th law inverted: make it unsatisfying.
            var body: String
            if let streak = context.streak, streak > 0 {
                body = "Opening \(context.app) now ends a \(streak) day chain."
            } else {
                body = "\(context.app) is already past its limit today. Never miss twice."
            }
            if let identity = context.identityStatement {
                body += " That is a vote against \"\(identity)\"."
            }
            if let partner = context.partner {
                body += " \(partner) sees the weekly number."
            } else if let reward = context.reward {
                body += " Stay under and \(reward)."
            }
            return NotifierMessage(title: "What It Costs", body: body)
        }
    }
}
