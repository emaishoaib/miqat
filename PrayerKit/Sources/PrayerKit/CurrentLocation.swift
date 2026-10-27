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
    static let timeout: Duration = .seconds(20)

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

        return try await withThrowingTaskGroup(of: Coordinate.self) { group in
            group.addTask { try await firstCoordinate() }
            group.addTask {
                try await Task.sleep(for: timeout)
                throw CurrentLocationError.unavailable
            }
            defer { group.cancelAll() }
            guard let coordinate = try await group.next() else {
                throw CurrentLocationError.unavailable
            }
            return coordinate
        }
    }

    private static func firstCoordinate() async throws -> Coordinate {
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
