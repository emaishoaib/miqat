import Foundation

public struct SunPath: Hashable, Sendable {
    public let previousMaghrib: Date
    public let sunrise: Date
    public let maghrib: Date
    public let nextSunrise: Date

    public init(previousMaghrib: Date, sunrise: Date, maghrib: Date, nextSunrise: Date) {
        self.previousMaghrib = previousMaghrib
        self.sunrise = sunrise
        self.maghrib = maghrib
        self.nextSunrise = nextSunrise
    }

    public func angle(at date: Date) -> Double {
        if date < sunrise {
            return -180 * Self.fraction(of: date, from: previousMaghrib, to: sunrise)
        }
        if date <= maghrib {
            return 180 - 180 * Self.fraction(of: date, from: sunrise, to: maghrib)
        }
        return -180 * Self.fraction(of: date, from: maghrib, to: nextSunrise)
    }

    private static func fraction(of date: Date, from start: Date, to end: Date) -> Double {
        min(max(date.timeIntervalSince(start) / end.timeIntervalSince(start), 0), 1)
    }
}

extension PrayerTimesResponse {
    public func sunPath(on date: Date, calendar: Calendar = .current) -> SunPath? {
        guard let today = day(containing: date, calendar: calendar),
              let sunrise = today.time(for: .sunrise)?.begins,
              let maghrib = today.time(for: .maghrib)?.begins else {
            return nil
        }

        return SunPath(
            previousMaghrib: time(of: .maghrib, daysFrom: date, by: -1, calendar: calendar) ?? maghrib.addingTimeInterval(-Self.day),
            sunrise: sunrise,
            maghrib: maghrib,
            nextSunrise: time(of: .sunrise, daysFrom: date, by: 1, calendar: calendar) ?? sunrise.addingTimeInterval(Self.day)
        )
    }

    private static let day: TimeInterval = 24 * 60 * 60

    private func time(of prayer: Prayer, daysFrom date: Date, by offset: Int, calendar: Calendar) -> Date? {
        calendar.date(byAdding: .day, value: offset, to: date)
            .flatMap { day(containing: $0, calendar: calendar) }
            .flatMap { $0.time(for: prayer)?.begins }
    }
}
