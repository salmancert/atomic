import Foundation

/// The user's goals: which apps to cut back on, by how much, and what to do instead.
public final class UserProfile {
    public var name: String
    public var targetApps: [String]
    public var dailyTimeLimits: [String: Int]
    public var replacementActivities: [String]
    public var implementationIntentions: [String]
    public private(set) var progressHistory: [String: [String: Int]] = [:]

    public init(
        name: String = "",
        targetApps: [String] = [],
        dailyTimeLimits: [String: Int] = [:],
        replacementActivities: [String] = [],
        implementationIntentions: [String] = []
    ) {
        self.name = name
        self.targetApps = targetApps
        self.dailyTimeLimits = dailyTimeLimits
        self.replacementActivities = replacementActivities
        self.implementationIntentions = implementationIntentions
    }

    /// The starter profile used until the onboarding flow exists.
    public static func sample() -> UserProfile {
        UserProfile(
            name: "User",
            targetApps: ["Instagram", "Facebook", "TikTok"],
            dailyTimeLimits: ["Instagram": 30, "Facebook": 20, "TikTok": 15],
            replacementActivities: ["Reading", "Walking", "Meditation"],
            implementationIntentions: [
                "When I feel bored, I will read instead of opening Instagram",
                "After lunch, I will take a 10-minute walk instead of checking Facebook"
            ]
        )
    }

    /// Records a day's usage, keeping only the apps the user is actually tracking.
    public func recordProgress(for day: String, usage: [String: Int]) {
        progressHistory[day] = usage.filter { targetApps.contains($0.key) }
    }

    public func limit(for app: String) -> Int? {
        dailyTimeLimits[app]
    }
}
