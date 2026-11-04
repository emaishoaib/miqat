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

    @Test func readsADaySavedBeforeItHadASource() throws {
        let saved = Data(#"{"date":0,"times":[]}"#.utf8)

        let day = try JSONDecoder().decode(PrayerDay.self, from: saved)

        #expect(day.source == nil)
    }

    @Test func readsATimetableSavedBeforeItHadANearbyMosque() throws {
        let saved = Data(#"{"source":{"city":{"name":"Solihull"}},"days":[]}"#.utf8)

        let response = try JSONDecoder().decode(PrayerTimesResponse.self, from: saved)

        #expect(response.nearbyMosque == nil)
    }

    @Test func readsANearbyMosqueSavedBeforeItHadAnID() throws {
        let saved = Data(#"{"name":"Masjid Solihull","website":"https://example.org/"}"#.utf8)

        let nearby = try JSONDecoder().decode(NearbyMosque.self, from: saved)

        #expect(nearby.id == nil)
        #expect(nearby.website == URL(string: "https://example.org/"))
    }

    @Test func keepsTheNearbyMosqueWhenSaved() {
        let cache = TimetableCache(suiteName: suiteName)
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }
        let nearby = NearbyMosque(id: "masjid", name: "Masjid Solihull", website: URL(string: "https://example.org/")!)

        cache.save(PrayerTimesResponse(source: .city(name: "Solihull"), days: [], nearbyMosque: nearby))

        #expect(cache.load()?.nearbyMosque == nearby)
    }

    @Test func returnsTheLastSavedCoordinate() {
        let cache = TimetableCache(suiteName: suiteName)
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }
        let coordinate = Coordinate(latitude: 52.4128, longitude: -1.7781)

        cache.saveCoordinate(coordinate)

        #expect(cache.loadCoordinate() == coordinate)
    }
}
