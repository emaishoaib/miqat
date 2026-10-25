import PrayerKit
import WidgetKit

struct PrayerEntry: TimelineEntry {
    let date: Date
    let response: PrayerTimesResponse?
}

struct PrayerTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> PrayerEntry {
        PrayerEntry(date: .now, response: Self.sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (PrayerEntry) -> Void) {
        let response = TimetableCache.shared.load() ?? (context.isPreview ? Self.sample : nil)
        completion(PrayerEntry(date: .now, response: response))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PrayerEntry>) -> Void) {
        let now = Date.now
        let response = TimetableCache.shared.load()
        let prayerStarts = response?.days.flatMap(\.times).filter(\.prayer.isPrayer).map(\.begins) ?? []
        let dayStarts = response?.days.map(\.date) ?? []
        let changes = Set(prayerStarts + dayStarts).filter { $0 > now }.sorted()

        let entries = ([now] + changes).map { PrayerEntry(date: $0, response: response) }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private static var sample: PrayerTimesResponse {
        MockPrayerTimesProvider().response(near: MockPrayerTimesProvider.sampleMosque.coordinate, from: .now, days: 2)
    }
}
