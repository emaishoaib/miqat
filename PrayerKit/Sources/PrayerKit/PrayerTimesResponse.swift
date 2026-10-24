import Foundation

public struct PrayerTimesResponse: Codable, Hashable, Sendable {
    public let source: TimesSource
    public let days: [PrayerDay]

    public init(source: TimesSource, days: [PrayerDay]) {
        self.source = source
        self.days = days
    }

    public func day(containing date: Date, calendar: Calendar = .current) -> PrayerDay? {
        days.first { calendar.isDate($0.date, inSameDayAs: date) }
    }

    public func nextPrayer(after date: Date) -> PrayerTime? {
        days.lazy.flatMap(\.times).first { $0.prayer.isPrayer && $0.begins > date }
    }
}
