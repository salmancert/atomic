import Foundation

public struct NotifierMessage: Equatable, Sendable {
    public let title: String
    public let body: String

    public init(title: String, body: String) {
        self.title = title
        self.body = body
    }
}

/// Anything that can put a message in front of the user.
///
/// The core never imports `UserNotifications`; the app layer supplies an
/// implementation that schedules real local notifications.
public protocol Notifier: AnyObject {
    func notify(_ message: NotifierMessage)
}

public extension Notifier {
    func notify(title: String, body: String) {
        notify(NotifierMessage(title: title, body: body))
    }
}

/// Keeps messages in memory. Used by the tests and the command line demo.
public final class RecordingNotifier: Notifier {
    public private(set) var messages: [NotifierMessage] = []

    public init() {}

    public func notify(_ message: NotifierMessage) {
        messages.append(message)
    }
}
