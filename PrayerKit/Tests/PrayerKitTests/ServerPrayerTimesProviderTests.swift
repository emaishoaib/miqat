import Foundation
import Testing
@testable import PrayerKit

struct ServerPrayerTimesProviderTests {
    let body = Data("""
    {
      "version": "masjid:3",
      "mosque": {
        "id": "masjid",
        "name": "Masjid Solihull",
        "address": "1 High Street, Solihull",
        "latitude": 52.4118,
        "longitude": -1.7776,
        "distance_meters": 120.5
      },
      "time_zone": "Europe/London",
      "days": [
        {
          "date": "2027-06-01",
          "times": [
            {"prayer": "fajr", "begins": "2027-06-01T03:00:00+01:00", "jamaat": "2027-06-01T03:30:00+01:00"},
            {"prayer": "sunrise", "begins": "2027-06-01T04:50:00+01:00", "jamaat": null}
          ]
        }
      ]
    }
    """.utf8)

    @Test func readsTheMosqueAndItsDistance() throws {
        let response = try ServerPrayerTimesProvider.response(from: body, statusCode: 200)

        guard case let .mosque(mosque, distance) = response.source else {
            Issue.record("Expected a mosque source")
            return
        }
        #expect(mosque.id == "masjid")
        #expect(mosque.name == "Masjid Solihull")
        #expect(distance == 120.5)
    }

    @Test func readsEachDayStartingAtLocalMidnight() throws {
        let response = try ServerPrayerTimesProvider.response(from: body, statusCode: 200)
        let day = try #require(response.days.first)

        #expect(day.date == ISO8601DateFormatter().date(from: "2027-05-31T23:00:00Z"))
        #expect(day.times.map(\.prayer) == [.fajr, .sunrise])
        #expect(day.times[0].begins == ISO8601DateFormatter().date(from: "2027-06-01T02:00:00Z"))
        #expect(day.times[1].jamaat == nil)
    }

    @Test func reportsNoNearbyMosqueWhenTheServerFindsNone() {
        #expect(throws: PrayerTimesError.noNearbyMosque) {
            try ServerPrayerTimesProvider.response(from: Data(), statusCode: 404)
        }
    }

    @Test func reportsOtherServerFailures() {
        #expect(throws: PrayerTimesError.server(statusCode: 500)) {
            try ServerPrayerTimesProvider.response(from: Data(), statusCode: 500)
        }
    }
}
