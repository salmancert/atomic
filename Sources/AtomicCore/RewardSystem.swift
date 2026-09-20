import Foundation

public struct Reward: Equatable, Sendable {
    public let name: String
    public let cost: Int

    public init(name: String, cost: Int) {
        self.name = name
        self.cost = cost
    }
}

/// Points, streak milestones and the rewards they buy.
public final class RewardSystem {
    public private(set) var rewards: [Reward] = []
    public private(set) var milestones: [Int: String] = [:]
    public private(set) var points: Int = 0
    public private(set) var unlockedRewards: [String] = []

    private let notifier: Notifier

    public init(notifier: Notifier) {
        self.notifier = notifier
    }

    public func setupRewards() {
        rewards = [
            Reward(name: "Digital Badge", cost: 100),
            Reward(name: "Achievement Unlock", cost: 250),
            Reward(name: "Custom Reward", cost: 500)
        ]

        milestones = [
            7: "One week streak",
            30: "One month streak",
            90: "Three month streak"
        ]
    }

    /// Scores the day and redeems anything the user can now afford.
    /// - Returns: the points earned today.
    @discardableResult
    public func provideDailyRewards(limits: [String: Int], usage: [String: Int], streaks: [String: Int]) -> Int {
        var pointsEarned = 0

        for (app, limit) in limits {
            let minutes = usage[app] ?? 0
            guard minutes <= limit else { continue }

            pointsEarned += 20
            if minutes <= limit / 2 {
                pointsEarned += 20 // bonus for coming in well under
            }
        }

        for (app, streak) in streaks where streak > 0 {
            pointsEarned += min(streak * 5, 50) // capped so long streaks do not run away

            if let milestone = milestones[streak] {
                awardMilestone(app: app, milestone: milestone)
            }
        }

        points += pointsEarned
        redeemAffordableRewards()
        return pointsEarned
    }

    private func awardMilestone(app: String, milestone: String) {
        notifier.notify(
            title: "Milestone Achieved",
            body: "Congratulations! You've achieved \(milestone) for \(app)!"
        )
    }

    /// Spends points on the most expensive reward the balance covers first, so a big
    /// balance does not get nibbled away by the cheap ones.
    private func redeemAffordableRewards() {
        let byValue = rewards.filter { $0.cost > 0 }.sorted { $0.cost > $1.cost }

        for reward in byValue where points >= reward.cost {
            points -= reward.cost
            unlockedRewards.append(reward.name)
            notifier.notify(title: "Reward Earned", body: "You've earned the \(reward.name)!")
        }
    }
}
