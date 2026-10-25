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
}
