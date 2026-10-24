import Foundation

public enum HijriDate {
    public static func formatted(_ date: Date, locale: Locale = .current) -> String {
        let style = Date.FormatStyle(
            date: .long,
            time: .omitted,
            locale: locale,
            calendar: Calendar(identifier: .islamicUmmAlQura)
        )
        return date.formatted(style)
    }
}
