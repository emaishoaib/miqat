import Foundation
import Testing
@testable import PrayerKit

struct PrayerUrgencyTests {
    @Test(arguments: [
        (31.0, PrayerUrgency.normal),
        (30.0, PrayerUrgency.soon),
        (16.0, PrayerUrgency.soon),
        (15.0, PrayerUrgency.imminent),
        (1.0, PrayerUrgency.imminent),
    ])
    func urgencyFollowsMinutesLeft(minutesLeft: Double, expected: PrayerUrgency) {
        #expect(PrayerUrgency(timeUntilNext: minutesLeft * 60) == expected)
    }
}
