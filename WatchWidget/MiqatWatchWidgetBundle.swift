import SwiftUI
import WidgetKit

@main
struct MiqatWatchWidgetBundle: WidgetBundle {
    var body: some Widget {
        NextPrayerComplication()
    }
}

struct NextPrayerComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NextPrayerComplication", provider: PrayerTimelineProvider(updatesEveryMinute: true)) { entry in
            NextPrayerComplicationView(entry: entry)
                .containerBackground(for: .widget) {
                    Color.clear
                }
        }
        .configurationDisplayName("Next Prayer")
        .description("The next prayer and the Hijri date.")
        .supportedFamilies([.accessoryRectangular, .accessoryCorner, .accessoryInline])
    }
}
