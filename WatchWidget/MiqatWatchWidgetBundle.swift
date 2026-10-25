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
        StaticConfiguration(kind: "NextPrayerComplication", provider: PrayerTimelineProvider()) { entry in
            NextPrayerComplicationView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Next Prayer")
        .description("The next prayer and the Hijri date.")
        .supportedFamilies([.accessoryRectangular, .accessoryCircular, .accessoryCorner, .accessoryInline])
    }
}
