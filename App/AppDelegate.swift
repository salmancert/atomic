import UIKit
import UserNotifications

@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate {
    let model = AppModel()

    private let notificationPresenter = ForegroundNotificationPresenter()
    private var locationMonitor: LocationMonitor?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        model.start()

        setupNotifications()
        setupLocationServices()
        scheduleDailyCheckIn()

        return true
    }

    private func setupNotifications() {
        let center = UNUserNotificationCenter.current()
        center.delegate = notificationPresenter
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error {
                NSLog("AtomicBreak: notification authorization failed — %@", error.localizedDescription)
            } else {
                NSLog("AtomicBreak: notification permission %@", granted ? "granted" : "denied")
            }
        }
    }

    private func setupLocationServices() {
        let model = self.model
        let monitor = LocationMonitor { coordinate in
            model.handleLocationUpdate(coordinate)
        }
        monitor.start()
        locationMonitor = monitor
    }

    /// A repeating local notification just after midnight, so the user is prompted to
    /// review the day even if they never open the app.
    private func scheduleDailyCheckIn() {
        var dateComponents = DateComponents()
        dateComponents.hour = 0
        dateComponents.minute = 1

        let content = UNMutableNotificationContent()
        content.title = "Daily Check-In"
        content.body = "Time to review your progress!"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "dailyCheckIn",
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        )

        UNUserNotificationCenter.current().add(request)
    }
}
