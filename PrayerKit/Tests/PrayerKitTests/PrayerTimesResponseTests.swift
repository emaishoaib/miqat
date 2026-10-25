import Foundation
import Testing
@testable import PrayerKit

struct PrayerTimesResponseTests {
    let london = TimeZone(identifier: "Europe/London")!
    let solihull = Coordinate(latitude: 52.4128, longitude: -1.7781)

    var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = london
        return calendar
    }

    func response(from start: Date) async throws -> PrayerTimesResponse {
        MockPrayerTimesProvider(timeZone: london).response(near: solihull, from: start, days: 2)
    }

    func date(hour: Int, minute: Int, dayOffset: Int = 0) -> Date {
        let today = calendar.startOfDay(for: .now)
        let day = calendar.date(byAdding: .day, value: dayOffset, to: today)!
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)!
    }

    @Test func nextPrayerIsTheFirstOneStillToBegin() async throws {
        let response = try await response(from: .now)

        #expect(response.nextPrayer(after: date(hour: 13, minute: 0))?.prayer == .asr)
    }

    @Test func nextPrayerSkipsSunrise() async throws {
        let response = try await response(from: .now)

        #expect(response.nextPrayer(after: date(hour: 6, minute: 0))?.prayer == .dhuhr)
    }

    @Test func nextPrayerAfterIshaIsTomorrowsFajr() async throws {
        let response = try await response(from: .now)
        let next = try #require(response.nextPrayer(after: date(hour: 21, minute: 0)))

        #expect(next.prayer == .fajr)
        #expect(calendar.isDate(next.begins, inSameDayAs: date(hour: 0, minute: 0, dayOffset: 1)))
    }

    @Test func dayContainingFindsTheMatchingTimetable() async throws {
        let response = try await response(from: .now)
        let tomorrow = date(hour: 12, minute: 0, dayOffset: 1)

        #expect(response.day(containing: tomorrow, calendar: calendar) == response.days.last)
    }
}
