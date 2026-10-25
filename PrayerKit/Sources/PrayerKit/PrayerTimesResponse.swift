import Foundation

public struct PrayerTimesResponse: Codable, Hashable, Sendable {
    public let source: TimesSource
    public let days: [PrayerDay]
    public let version: String?

    public init(source: TimesSource, days: [PrayerDay], version: String? = nil) {
        self.source = source
        self.days = days
        self.version = version
    }

    public func day(containing date: Date, calendar: Calendar = .current) -> PrayerDay? {
        days.first { calendar.isDate($0.date, inSameDayAs: date) }
    }

    public func nextPrayer(after date: Date) -> PrayerTime? {
        days.lazy.flatMap(\.times).first { $0.prayer.isPrayer && $0.begins > date }
    }
}
