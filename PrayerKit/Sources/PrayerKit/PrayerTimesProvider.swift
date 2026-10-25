import Foundation

public protocol PrayerTimesProvider: Sendable {
    func prayerTimes(near coordinate: Coordinate, ifChangedSince version: String?) async throws -> PrayerTimesResponse?
}
