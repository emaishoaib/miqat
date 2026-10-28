import PrayerKit
import SwiftUI
import WidgetKit

struct NextPrayerComplicationView: View {
    @Environment(\.widgetFamily) private var family

    let entry: PrayerEntry

    var body: some View {
        if let response = entry.response, let next = response.nextPrayer(after: entry.date) {
            switch family {
            case .accessoryRectangular:
                NextPrayerRectangularView(response: response, next: next, date: entry.date)
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

    static func shortTime(_ date: Date) -> String {
        date.formatted(.dateTime.hour(.defaultDigits(amPM: .omitted)).minute())
    }
}
