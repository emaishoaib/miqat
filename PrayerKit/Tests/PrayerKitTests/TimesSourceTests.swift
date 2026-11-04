import Foundation
import Testing
@testable import PrayerKit

struct TimesSourceTests {
    @Test func readsACitySavedBeforeItsMethodWasKnown() throws {
        let saved = Data(#"{"city":{"name":"Solihull"}}"#.utf8)

        #expect(try JSONDecoder().decode(TimesSource.self, from: saved) == .city(name: "Solihull"))
    }

    @Test func checksTheMosqueTheTimesComeFrom() {
        let website = URL(string: "https://example.org/")!
        let mosque = Mosque(id: "masjid", name: "Masjid Solihull", address: "1 High Street, Solihull", website: website, coordinate: Coordinate(latitude: 52.4118, longitude: -1.7776))

        let source = TimesSource.mosque(mosque, distanceInMeters: 400)

        #expect(source.mosqueToCheck(nearby: nil) == NearbyMosque(id: "masjid", name: "Masjid Solihull", website: website))
    }

    @Test func checksNoMosqueWhenTheTimesComeFromOneWithoutAWebsite() {
        let source = TimesSource.mosque(MockPrayerTimesProvider.sampleMosque, distanceInMeters: 400)

        #expect(MockPrayerTimesProvider.sampleMosque.website == nil)
        #expect(source.mosqueToCheck(nearby: nil) == nil)
    }

    @Test func checksTheNearbyMosqueWithCityTimes() {
        let nearby = NearbyMosque(id: "masjid", name: "Masjid Solihull", website: URL(string: "https://example.org/")!)

        #expect(TimesSource.city(name: "Solihull").mosqueToCheck(nearby: nearby) == nearby)
    }
}
