import Foundation

public protocol PrayerTimesProvider: Sendable {
    func prayerTimes(near coordinate: Coordinate, from start: Date, days: Int) async throws -> PrayerTimesResponse
}
