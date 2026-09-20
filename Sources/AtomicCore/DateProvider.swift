import Foundation

/// Supplies "now".
///
/// Injected everywhere instead of calling `Date()` directly so that streaks, day
/// rollovers and time-based triggers can be tested deterministically.
public protocol DateProvider {
    func now() -> Date
}

public struct SystemDateProvider: DateProvider {
    public init() {}

    public func now() -> Date { Date() }
}

/// Canonical string keys used to index usage history.
public enum DayKey {
    /// `yyyy-MM-dd` in the device's current time zone.
    public static func day(from date: Date) -> String {
        format(date, as: "yyyy-MM-dd")
    }

    /// `HH:mm` in the device's current time zone, always zero padded.
    public static func minuteOfDay(from date: Date) -> String {
        format(date, as: "HH:mm")
    }

    private static func format(_ date: Date, as template: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = template
        return formatter.string(from: date)
    }
}
