import CoreLocation
import Foundation

public enum CurrentLocationError: LocalizedError {
    case denied
    case unavailable

    public var errorDescription: String? {
        switch self {
        case .denied: "Miqat needs your location to find the nearest mosque. Allow location access in Settings."
        case .unavailable: "Your location couldn't be found."
        }
    }
}

public enum CurrentLocation {
    @MainActor
    public static func coordinate() async throws -> Coordinate {
        #if os(macOS)
        let manager = CLLocationManager()
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
        defer { withExtendedLifetime(manager) {} }
        #else
        let session = CLServiceSession(authorization: .whenInUse)
        defer { session.invalidate() }
        #endif

        for try await update in CLLocationUpdate.liveUpdates() {
            if let location = update.location {
                return Coordinate(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
            }
            if update.authorizationDenied || update.authorizationDeniedGlobally || update.authorizationRestricted {
                throw CurrentLocationError.denied
            }
        }
        throw CurrentLocationError.unavailable
    }
}
