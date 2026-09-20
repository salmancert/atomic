import Foundation

/// A latitude/longitude pair.
///
/// Deliberately not `CLLocation`: keeping the core free of CoreLocation means the
/// habit logic builds and runs on any platform, including CI without an iOS SDK.
public struct Coordinate: Equatable, Sendable {
    public var latitude: Double
    public var longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    /// Great-circle distance in metres.
    public func distance(to other: Coordinate) -> Double {
        let earthRadius = 6_372_797.6
        let lat1 = latitude * .pi / 180
        let lat2 = other.latitude * .pi / 180
        let deltaLat = (other.latitude - latitude) * .pi / 180
        let deltaLong = (other.longitude - longitude) * .pi / 180

        let a = sin(deltaLat / 2) * sin(deltaLat / 2)
            + cos(lat1) * cos(lat2) * sin(deltaLong / 2) * sin(deltaLong / 2)
        return 2 * earthRadius * atan2(sqrt(a), sqrt(1 - a))
    }

    public func isNear(_ other: Coordinate, within metres: Double = 100) -> Bool {
        distance(to: other) < metres
    }
}
