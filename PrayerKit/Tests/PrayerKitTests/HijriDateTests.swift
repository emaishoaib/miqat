import Foundation
import Testing
@testable import PrayerKit

struct HijriDateTests {
    let locale = Locale(identifier: "en_US")
    let date = ISO8601DateFormatter().date(from: "2026-10-24T12:00:00Z")!

    @Test func dayIsTheDayOfTheHijriMonth() {
        #expect(HijriDate.day(date, locale: locale) == "13")
    }

    @Test func monthIsTheHijriMonthName() {
        #expect(HijriDate.month(date, locale: locale) == "Jumada I")
    }

    @Test func monthNumberCountsFromMuharram() {
        #expect(HijriDate.monthNumber(date) == 5)
    }

    @Test func yearIsTheHijriYear() {
        #expect(HijriDate.year(date) == 1448)
    }

    @Test func formattedReadsDayThenMonthThenYear() {
        #expect(HijriDate.formatted(date, locale: locale) == "13 Jumada I 1448")
    }

    var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    func time(_ text: String) -> Date {
        ISO8601DateFormatter().date(from: text)!
    }

    var day: PrayerDay {
        PrayerDay(date: time("2026-10-24T00:00:00Z"), times: [
            PrayerTime(prayer: .fajr, begins: time("2026-10-24T05:30:00Z")),
            PrayerTime(prayer: .maghrib, begins: time("2026-10-24T17:50:00Z")),
            PrayerTime(prayer: .isha, begins: time("2026-10-24T19:20:00Z")),
        ])
    }

    @Test func beforeMaghribTheHijriDateFollowsTheDay() {
        #expect(day.hijriDate(at: time("2026-10-24T17:49:00Z"), calendar: utc) == time("2026-10-24T00:00:00Z"))
    }

    @Test func fromMaghribTheHijriDateMovesToTheNextDay() {
        #expect(day.hijriDate(at: time("2026-10-24T17:50:00Z"), calendar: utc) == time("2026-10-25T00:00:00Z"))
        #expect(day.hijriDate(at: time("2026-10-24T23:59:00Z"), calendar: utc) == time("2026-10-25T00:00:00Z"))
    }

    @Test func anotherDayKeepsItsOwnHijriDate() {
        #expect(day.hijriDate(at: time("2026-10-25T20:00:00Z"), calendar: utc) == time("2026-10-24T00:00:00Z"))
    }
}
