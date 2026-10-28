import Foundation

enum MenuBarDate: String, CaseIterable {
    static let showsKey = "menuBarShowsDate"
    static let calendarKey = "menuBarDateCalendar"

    case gregorian
    case hijri

    var name: String {
        switch self {
        case .gregorian: "Gregorian"
        case .hijri: "Hijri"
        }
    }

    func lines(for date: Date) -> (weekday: String, day: String) {
        var style = Date.FormatStyle()
        if self == .hijri {
            style.calendar = Calendar(identifier: .islamicUmmAlQura)
        }
        return (
            date.formatted(style.weekday(.abbreviated)),
            date.formatted(style.month(.abbreviated).day())
        )
    }
}
