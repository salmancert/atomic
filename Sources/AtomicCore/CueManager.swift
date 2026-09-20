import Foundation

public struct LocationTrigger: Equatable, Sendable {
    public let name: String
    public let coordinate: Coordinate

    public init(name: String, coordinate: Coordinate) {
        self.name = name
        self.coordinate = coordinate
    }
}

public struct EmotionTrigger: Equatable, Sendable {
    public let emotion: String
    public let replacement: String

    public init(emotion: String, replacement: String) {
        self.emotion = emotion
        self.replacement = replacement
    }
}

public struct UsagePatterns: Equatable, Sendable {
    public var peakTimes: [String]
    public var frequentLocations: [String]
    public var emotionalStates: [String]

    public init(peakTimes: [String] = [], frequentLocations: [String] = [], emotionalStates: [String] = []) {
        self.peakTimes = peakTimes
        self.frequentLocations = frequentLocations
        self.emotionalStates = emotionalStates
    }

    public static let empty = UsagePatterns()
}

/// Works out *when* and *where* the user reaches for a problem app, and turns that
/// into the triggers the intervention system fires on.
public final class CueManager {
    public private(set) var usagePatterns: UsagePatterns = .empty
    public private(set) var triggerTimes: [String] = []
    public private(set) var locationTriggers: [LocationTrigger] = []
    public private(set) var emotionTriggers: [EmotionTrigger] = []

    /// Every peak window, kept so `adjustTriggers` can widen back out again.
    private var allTriggerTimes: [String] = []

    public init() {}

    public func analyzeUsagePatterns() {
        usagePatterns = UsagePatterns(
            peakTimes: ["07:00-08:00", "12:00-13:00", "21:00-23:00"],
            frequentLocations: ["Home", "Work", "Commute"],
            emotionalStates: ["Bored", "Stressed", "Tired"]
        )
        createInterventionTriggers()
    }

    public func createInterventionTriggers() {
        // The start of each peak window, as a zero padded "HH:mm" so it can be
        // compared directly against `DayKey.minuteOfDay`.
        allTriggerTimes = usagePatterns.peakTimes.compactMap { window in
            window.split(separator: "-").first.map(String.init)
        }
        triggerTimes = allTriggerTimes

        locationTriggers = [
            LocationTrigger(name: "Home", coordinate: Coordinate(latitude: 40.7128, longitude: -74.0060)),
            LocationTrigger(name: "Work", coordinate: Coordinate(latitude: 40.7112, longitude: -74.0055))
        ]

        emotionTriggers = [
            EmotionTrigger(emotion: "Bored", replacement: "Try reading for 10 minutes"),
            EmotionTrigger(emotion: "Stressed", replacement: "Try 5 minutes of deep breathing")
        ]
    }

    /// Arms extra times — the ones the user wrote into their implementation
    /// intentions. A plan the user made beats a pattern we inferred.
    public func addTriggerTimes(_ times: [String]) {
        for time in times where !allTriggerTimes.contains(time) {
            allTriggerTimes.append(time)
        }
        allTriggerTimes.sort()
        triggerTimes = allTriggerTimes
    }

    public func shouldTrigger(at minuteOfDay: String) -> Bool {
        triggerTimes.contains(minuteOfDay)
    }

    public func trigger(near coordinate: Coordinate, within metres: Double = 100) -> LocationTrigger? {
        locationTriggers.first { $0.coordinate.isNear(coordinate, within: metres) }
    }

    public func replacement(for emotion: String) -> String? {
        emotionTriggers.first { $0.emotion == emotion }?.replacement
    }

    /// Backs off when the user is winning.
    ///
    /// A day spent entirely inside the limits leaves only the single highest risk
    /// window armed; going over anywhere re-arms all of them. Nagging someone who is
    /// already on track is the fastest way to get the app deleted.
    public func adjustTriggers(usage: [String: Int], limits: [String: Int]) {
        guard !allTriggerTimes.isEmpty else { return }

        let stayedUnderLimits = limits.allSatisfy { app, limit in (usage[app] ?? 0) <= limit }
        triggerTimes = stayedUnderLimits ? Array(allTriggerTimes.suffix(1)) : allTriggerTimes
    }
}
