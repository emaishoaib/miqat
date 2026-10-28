import SwiftUI
import WidgetKit

struct PrayerTimesWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PrayerTimes", provider: PrayerTimelineProvider(updatesEveryMinute: true)) { entry in
            PrayerTimesWidgetView(entry: entry)
        }
        .configurationDisplayName("Prayer Times")
        .description("The sun's path, today's prayers and the date.")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}
