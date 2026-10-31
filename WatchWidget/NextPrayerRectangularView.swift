import PrayerKit
import SwiftUI

struct NextPrayerRectangularView: View {
    let response: PrayerTimesResponse
    let next: PrayerTime
    let date: Date

    var body: some View {
        let hijriDate = response.day(containing: next.begins)?.hijriDate(at: date) ?? date

        HStack(spacing: 6) {
            if let path = response.sunPath(on: date), let today = response.day(containing: date) {
                SunPathDial(day: today, path: path, next: next, now: date, usesDayColours: false, launch: 1, ripple: 1, rippleAt: nil, showsText: false, weight: 2)
                    .frame(width: 62)
            }
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    Text(next.prayer.name)
                        .fontWeight(.semibold)
                    Text(NextPrayerComplicationView.shortTime(next.begins))
                }
                Text(SunPathDial.timeLeft(to: next.begins, from: date))
                    .opacity(0.7)
                Text(HijriDate.formatted(hijriDate))
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 0)
        }
        .font(.system(size: 15))
        .foregroundStyle(Palette.ink)
        .lineLimit(1)
    }
}
