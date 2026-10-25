import Foundation

public enum HijriDate {
    private static let calendar = Calendar(identifier: .islamicUmmAlQura)

    public static func formatted(_ date: Date, locale: Locale = .current) -> String {
        date.formatted(Date.FormatStyle(date: .long, time: .omitted, locale: locale, calendar: calendar))
    }

    public static func day(_ date: Date, locale: Locale = .current) -> String {
        date.formatted(Date.FormatStyle(locale: locale, calendar: calendar).day())
    }

    public static func month(_ date: Date, locale: Locale = .current) -> String {
        date.formatted(Date.FormatStyle(locale: locale, calendar: calendar).month(.wide))
    }

    public static func monthNumber(_ date: Date, timeZone: TimeZone = .current) -> Int {
        calendar(in: timeZone).component(.month, from: date)
    }

    public static func year(_ date: Date, timeZone: TimeZone = .current) -> Int {
        calendar(in: timeZone).component(.year, from: date)
    }

    private static func calendar(in timeZone: TimeZone) -> Calendar {
        var calendar = calendar
        calendar.timeZone = timeZone
        return calendar
    }
}
