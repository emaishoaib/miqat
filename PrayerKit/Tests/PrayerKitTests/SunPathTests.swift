import Foundation
import Testing
@testable import PrayerKit

struct SunPathTests {
    let london = TimeZone(identifier: "Europe/London")!
    let solihull = Coordinate(latitude: 52.4128, longitude: -1.7781)

    var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = london
        return calendar
    }

    let path = SunPath(
        previousMaghrib: Date(timeIntervalSince1970: 0),
        sunrise: Date(timeIntervalSince1970: 14 * 3600),
        maghrib: Date(timeIntervalSince1970: 24 * 3600),
        nextSunrise: Date(timeIntervalSince1970: 38 * 3600)
    )

    func hours(_ hours: Double) -> Date {
        Date(timeIntervalSince1970: hours * 3600)
    }

    func date(hour: Int, minute: Int, dayOffset: Int = 0) -> Date {
        let today = calendar.startOfDay(for: .now)
        let day = calendar.date(byAdding: .day, value: dayOffset, to: today)!
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)!
    }

    @Test func sunriseSitsOnTheLeftOfTheHorizon() {
        #expect(path.angle(at: hours(14)) == 180)
    }

    @Test func maghribSitsOnTheRightOfTheHorizon() {
        #expect(path.angle(at: hours(24)) == 0)
    }

    @Test func middleOfTheDaySitsAtTheTop() {
        #expect(path.angle(at: hours(19)) == 90)
    }

    @Test func middleOfTheNightSitsAtTheBottom() {
        #expect(path.angle(at: hours(31)) == -90)
        #expect(path.angle(at: hours(7)) == -90)
    }

    @Test func nextSunriseCompletesTheCircle() {
        #expect(path.angle(at: hours(38)) == -180)
    }

    @Test func timesOutsideThePathStayOnItsEnds() {
        #expect(path.angle(at: hours(-5)) == 0)
        #expect(path.angle(at: hours(45)) == -180)
    }

    @Test func responseBuildsThePathFromNeighbouringDays() throws {
        let response = MockPrayerTimesProvider(timeZone: london).response(near: solihull, from: date(hour: 0, minute: 0, dayOffset: -1), days: 3)
        let path = try #require(response.sunPath(on: date(hour: 12, minute: 0), calendar: calendar))

        #expect(path.previousMaghrib == date(hour: 17, minute: 50, dayOffset: -1))
        #expect(path.sunrise == date(hour: 7, minute: 48))
        #expect(path.maghrib == date(hour: 17, minute: 50))
        #expect(path.nextSunrise == date(hour: 7, minute: 48, dayOffset: 1))
    }

    @Test func responseEstimatesMissingNeighbouringDays() throws {
        let response = MockPrayerTimesProvider(timeZone: london).response(near: solihull, from: .now, days: 1)
        let path = try #require(response.sunPath(on: date(hour: 12, minute: 0), calendar: calendar))

        #expect(path.previousMaghrib == path.maghrib.addingTimeInterval(-24 * 3600))
        #expect(path.nextSunrise == path.sunrise.addingTimeInterval(24 * 3600))
    }

    @Test func dhuhrHalfwayThroughTheDaySitsAtTheTop() throws {
        let response = MockPrayerTimesProvider(timeZone: london).response(near: solihull, from: .now, days: 1)
        let path = try #require(response.sunPath(on: date(hour: 12, minute: 0), calendar: calendar))

        #expect(path.angle(at: date(hour: 12, minute: 49)) == 90)
    }
}
