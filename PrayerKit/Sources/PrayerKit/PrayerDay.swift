import Foundation

public struct PrayerDay: Codable, Hashable, Sendable {
    public let date: Date
    public let times: [PrayerTime]

    public init(date: Date, times: [PrayerTime]) {
        self.date = date
        self.times = times
    }

    public func time(for prayer: Prayer) -> PrayerTime? {
        times.first { $0.prayer == prayer }
    }
}
