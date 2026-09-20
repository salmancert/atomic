import Foundation

/// One nudge, tagged with the law of behaviour change it inverts.
public struct Intervention: Equatable, Sendable {
    /// Atomic Habits inverts the four laws to break a habit: make it invisible,
    /// unattractive, difficult and unsatisfying.
    public enum Law: String, CaseIterable, Sendable {
        case obvious
        case unattractive
        case difficult
        case unsatisfying
    }

    public let law: Law
    public let name: String
    public let action: String

    public init(law: Law, name: String, action: String) {
        self.law = law
        self.name = name
        self.action = action
    }
}

/// What the nudge should talk about: the app in the worst shape right now.
public struct InterventionContext: Equatable, Sendable {
    public var app: String
    public var minutesToday: Int
    public var limit: Int?

    public init(app: String, minutesToday: Int, limit: Int? = nil) {
        self.app = app
        self.minutesToday = minutesToday
        self.limit = limit
    }
}

/// Picks a nudge and turns it into a message grounded in the user's real numbers.
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
                law: .obvious,
                name: "Usage Alert",
                action: "Show the running total for the day when the app opens"
            ),
            Intervention(
                law: .unattractive,
                name: "Distraction Reminder",
                action: "Show what this time could buy instead"
            ),
            Intervention(
                law: .difficult,
                name: "Friction Builder",
                action: "Add a 20 second pause before the app opens"
            ),
            Intervention(
                law: .unsatisfying,
                name: "Goal Reminder",
                action: "Show the time lost against a personal goal"
            )
        ]
    }

    public func selectIntervention() -> Intervention? {
        chooser(interventions)
    }

    /// Selects a nudge and delivers it. Returns what was sent, or `nil` if no
    /// interventions are configured.
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

    /// Every line is built from the user's own numbers — a nudge quoting someone
    /// else's usage is the fastest way to lose their trust.
    public func message(for intervention: Intervention, context: InterventionContext) -> NotifierMessage {
        switch intervention.law {
        case .obvious:
            return NotifierMessage(
                title: "Usage Alert",
                body: "You've spent \(context.minutesToday) minutes on \(context.app) today\(limitSuffix(context))."
            )

        case .unattractive:
            let pages = max(1, context.minutesToday) // roughly a page a minute
            return NotifierMessage(
                title: "Time Well Spent?",
                body: "Today's \(context.minutesToday) minutes on \(context.app) is about \(pages) pages of a book."
            )

        case .difficult:
            return NotifierMessage(
                title: "Taking a Pause",
                body: "Let's wait 20 seconds before opening \(context.app)."
            )

        case .unsatisfying:
            return NotifierMessage(
                title: "Goal Reminder",
                body: "\(context.minutesToday) minutes on \(context.app) is \(context.minutesToday) minutes not spent on your goals."
            )
        }
    }

    private func limitSuffix(_ context: InterventionContext) -> String {
        guard let limit = context.limit else { return "" }
        return context.minutesToday > limit
            ? ", \(context.minutesToday - limit) over your \(limit) minute limit"
            : ", \(limit - context.minutesToday) minutes left of your \(limit) minute limit"
    }
}
