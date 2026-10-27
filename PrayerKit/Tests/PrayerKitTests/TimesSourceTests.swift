import Foundation
import Testing
@testable import PrayerKit

struct TimesSourceTests {
    @Test func readsACitySavedBeforeItsMethodWasKnown() throws {
        let saved = Data(#"{"city":{"name":"Solihull"}}"#.utf8)

        #expect(try JSONDecoder().decode(TimesSource.self, from: saved) == .city(name: "Solihull"))
    }
}
