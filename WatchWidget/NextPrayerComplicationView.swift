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
            case .accessoryCircular:
                VStack(spacing: 0) {
                    Text(next.prayer.name)
                        .font(.system(size: 11, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(Self.shortTime(next.begins))
                        .font(.system(size: 15, weight: .bold))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .padding(4)
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
