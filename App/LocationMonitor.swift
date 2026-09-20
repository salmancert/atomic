import CoreLocation
import Foundation

/// Watches for arrival at the user's trigger locations.
///
/// Deliberately separate from `AppDelegate`: `CLLocationManagerDelegate` callbacks are
/// not main actor isolated, so the conversion to `Coordinate` happens here and only a
/// `Sendable` value crosses onto the main actor.
final class LocationMonitor: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private let onLocation: @MainActor (Coordinate) -> Void

    init(onLocation: @escaping @MainActor (Coordinate) -> Void) {
        self.onLocation = onLocation
        super.init()
        manager.delegate = self
    }

    func start() {
        manager.requestAlwaysAuthorization()
        // Significant change monitoring rather than continuous updates: this app only
        // needs to know "you just arrived somewhere", and it costs almost no battery.
        manager.startMonitoringSignificantLocationChanges()
    }

    func stop() {
        manager.stopMonitoringSignificantLocationChanges()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        let coordinate = Coordinate(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )

        Task { @MainActor in
            self.onLocation(coordinate)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // A location fix failing is routine (airplane mode, no signal); the next
        // significant change will come through.
        NSLog("AtomicBreak: location update failed — %@", error.localizedDescription)
    }
}
