import Foundation

public struct PrayerTimesResponse: Codable, Hashable, Sendable {
    public let source: TimesSource
    public let days: [PrayerDay]
    public let version: String?
    public let nearbyMosque: NearbyMosque?

    public init(source: TimesSource, days: [PrayerDay], version: String? = nil, nearbyMosque: NearbyMosque? = nil) {
        self.source = source
        self.days = days
        self.version = version
        self.nearbyMosque = nearbyMosque
    }

    public func day(containing date: Date, calendar: Calendar = .current) -> PrayerDay? {
        days.first { calendar.isDate($0.date, inSameDayAs: date) }
    }

    public func nextPrayer(after date: Date) -> PrayerTime? {
        days.lazy.flatMap(\.times).first { $0.begins > date }
    }

    public func closestCoveredTime(to date: Date, calendar: Calendar = .current) -> Date {
        guard let first = days.first?.date, let last = days.last?.times.last?.begins else { return date }
        return min(max(date, calendar.startOfDay(for: first)), last.addingTimeInterval(-1))
    }
}
