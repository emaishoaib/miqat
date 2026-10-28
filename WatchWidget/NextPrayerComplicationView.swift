import PrayerKit
import SwiftUI
import WidgetKit

struct NextPrayerComplicationView: View {
    @Environment(\.widgetFamily) private var family

    let entry: PrayerEntry

    var body: some View {
        if let next = entry.response?.nextPrayer(after: entry.date) {
            switch family {
            case .accessoryRectangular:
                NextPrayerRectangularView(next: next, date: entry.date, isSymmetric: true)
            case .accessoryCorner:
                Text(Self.shortTime(next.begins))
                    .monospacedDigit()
                    .widgetLabel { Text(next.prayer.name) }
            default:
                Text("\(next.prayer.name) \(next.begins.formatted(date: .omitted, time: .shortened))")
            }
        } else {
            Image(systemName: "moon.stars")
        }
    }

    private static func shortTime(_ date: Date) -> String {
        date.formatted(.dateTime.hour(.defaultDigits(amPM: .omitted)).minute())
    }
}
