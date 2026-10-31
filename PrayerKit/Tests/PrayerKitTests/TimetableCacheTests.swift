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

    @Test func readsAMosqueSavedBeforeItHadAWebsite() throws {
        let saved = Data("""
        {
          "id": "masjid",
          "name": "Masjid Solihull",
          "address": "1 High Street, Solihull",
          "coordinate": {"latitude": 52.4118, "longitude": -1.7776}
        }
        """.utf8)

        let mosque = try JSONDecoder().decode(Mosque.self, from: saved)

        #expect(mosque.id == "masjid")
        #expect(mosque.website == nil)
    }

    @Test func returnsTheLastSavedCoordinate() {
        let cache = TimetableCache(suiteName: suiteName)
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }
        let coordinate = Coordinate(latitude: 52.4128, longitude: -1.7781)

        cache.saveCoordinate(coordinate)

        #expect(cache.loadCoordinate() == coordinate)
    }
}
