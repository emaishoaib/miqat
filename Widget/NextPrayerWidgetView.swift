import PrayerKit
import SwiftUI
import WidgetKit

struct NextPrayerWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: PrayerEntry

    var body: some View {
        if let response = entry.response, let next = response.nextPrayer(after: entry.date) {
            switch family {
            case .accessoryRectangular:
                NextPrayerRectangularView(
                    next: next,
                    hijriDate: response.day(containing: next.begins)?.hijriDate(at: entry.date) ?? entry.date
                )
            default:
                Text("\(next.prayer.name) \(next.begins.formatted(date: .omitted, time: .shortened))")
            }
        } else {
            Text("Open Miqat to load prayer times")
                .font(.caption)
                .multilineTextAlignment(.center)
        }
    }
}
