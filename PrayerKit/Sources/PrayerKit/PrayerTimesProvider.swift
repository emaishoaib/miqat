import Foundation

public protocol PrayerTimesProvider: Sendable {
    func prayerTimes(near coordinate: Coordinate) async throws -> PrayerTimesResponse
}
