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

    @Test func nextPrayerIsSunriseDuringFajr() async throws {
        let response = try await response(from: .now)

        #expect(response.nextPrayer(after: date(hour: 6, minute: 0))?.prayer == .sunrise)
    }

    @Test func nextPrayerIsDhuhrWhenTheDayHasNoSunrise() {
        let day = PrayerDay(date: date(hour: 0, minute: 0), times: [
            PrayerTime(prayer: .fajr, begins: date(hour: 5, minute: 52)),
            PrayerTime(prayer: .dhuhr, begins: date(hour: 12, minute: 49)),
        ])
        let response = PrayerTimesResponse(source: .city(name: "Solihull"), days: [day])

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

    @Test func coveredTimeLeavesATimeInsideTheDaysAlone() async throws {
        let response = try await response(from: .now)
        let noon = date(hour: 12, minute: 0)

        #expect(response.closestCoveredTime(to: noon, calendar: calendar) == noon)
    }

    @Test func coveredTimeStopsAtTheStartOfTheFirstDay() async throws {
        let response = try await response(from: .now)

        #expect(response.closestCoveredTime(to: date(hour: 12, minute: 0, dayOffset: -1), calendar: calendar) == date(hour: 0, minute: 0))
    }

    @Test func coveredTimeStopsWhileTheLastPrayerIsStillToBegin() async throws {
        let response = try await response(from: .now)
        let time = response.closestCoveredTime(to: date(hour: 12, minute: 0, dayOffset: 5), calendar: calendar)

        #expect(response.nextPrayer(after: time) == response.days.last?.times.last)
    }
}
