import Foundation
import Testing
@testable import PrayerKit

struct TimetableCacheTests {
    let suiteName = "miqat-tests-\(UUID().uuidString)"

    @Test func returnsNothingBeforeAnythingIsSaved() {
        let cache = TimetableCache(suiteName: suiteName)
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }

        #expect(cache.load() == nil)
    }

    @Test func returnsWhatWasSaved() {
        let cache = TimetableCache(suiteName: suiteName)
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }
        let response = MockPrayerTimesProvider().response(near: MockPrayerTimesProvider.sampleMosque.coordinate, from: .now, days: 7)

        cache.save(response)

        #expect(cache.load() == response)
    }
}
