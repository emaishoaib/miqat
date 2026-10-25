import Foundation
import Testing
@testable import PrayerKit

struct MockPrayerTimesProviderTests {
    let london = TimeZone(identifier: "Europe/London")!
    let solihull = Coordinate(latitude: 52.4128, longitude: -1.7781)

    @Test func returnsOneTimetablePerRequestedDay() async throws {
        let provider = MockPrayerTimesProvider(timeZone: london)
        let response = provider.response(near: solihull, from: .now, days: 3)

        #expect(response.days.count == 3)
    }

    @Test func listsEveryPrayerInOrderWithinItsDay() async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = london
        let provider = MockPrayerTimesProvider(timeZone: london)
        let response = provider.response(near: solihull, from: .now, days: 2)

        for day in response.days {
            #expect(day.times.map(\.prayer) == Prayer.allCases)
            #expect(day.times.map(\.begins) == day.times.map(\.begins).sorted())
            #expect(day.times.allSatisfy { calendar.isDate($0.begins, inSameDayAs: day.date) })
        }
    }

    @Test func reportsTheSampleMosqueWithItsDistance() async throws {
        let provider = MockPrayerTimesProvider(timeZone: london)
        let response = provider.response(near: solihull, from: .now, days: 1)

        guard case let .mosque(mosque, distance) = response.source else {
            Issue.record("Expected a mosque source")
            return
        }
        #expect(mosque == MockPrayerTimesProvider.sampleMosque)
        #expect(distance > 0 && distance < 1_000)
    }
}
