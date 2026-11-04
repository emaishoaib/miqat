import Foundation
import Testing
@testable import PrayerKit

struct NearbyMosqueTests {
    @Test func marksTheWebsiteWithThePlace() {
        let mosque = NearbyMosque(id: "ChIJ123abc", name: "Masjid Solihull", website: URL(string: "https://example.org/")!)

        #expect(mosque.websiteMarkedWithPlace == URL(string: "https://example.org/#miqat-place=ChIJ123abc"))
    }

    @Test func keepsThePathAndQueryOfTheWebsite() {
        let mosque = NearbyMosque(id: "ChIJ123abc", name: "Masjid Solihull", website: URL(string: "https://example.org/times?month=11")!)

        #expect(mosque.websiteMarkedWithPlace == URL(string: "https://example.org/times?month=11#miqat-place=ChIJ123abc"))
    }

    @Test func leavesTheWebsiteAloneWithoutAPlace() {
        let mosque = NearbyMosque(id: nil, name: "Masjid Solihull", website: URL(string: "https://example.org/")!)

        #expect(mosque.websiteMarkedWithPlace == URL(string: "https://example.org/"))
    }

    @Test func leavesAWebsiteThatAlreadyHasAFragmentAlone() {
        let mosque = NearbyMosque(id: "ChIJ123abc", name: "Masjid Solihull", website: URL(string: "https://example.org/#/times")!)

        #expect(mosque.websiteMarkedWithPlace == URL(string: "https://example.org/#/times"))
    }
}
