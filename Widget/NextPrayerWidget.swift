import SwiftUI
import WidgetKit

struct NextPrayerWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NextPrayer", provider: PrayerTimelineProvider()) { entry in
            NextPrayerWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Next Prayer")
        .description("The next prayer and the Hijri date.")
        .supportedFamilies([.accessoryRectangular, .accessoryInline])
    }
}
