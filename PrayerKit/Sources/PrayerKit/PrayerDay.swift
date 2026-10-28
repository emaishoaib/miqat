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

    public func hijriDate(at now: Date, calendar: Calendar = .current) -> Date {
        guard calendar.isDate(date, inSameDayAs: now),
              let maghrib = time(for: .maghrib)?.begins,
              now >= maghrib else {
            return date
        }
        return calendar.date(byAdding: .day, value: 1, to: date) ?? date
    }
}
