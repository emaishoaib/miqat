import PrayerKit
import SwiftUI

struct NextPrayerRectangularView: View {
    let response: PrayerTimesResponse
    let next: PrayerTime
    let date: Date

    var body: some View {
        let listed = response.day(containing: next.begins)?.date ?? date

        HStack(spacing: 6) {
            if let path = response.sunPath(on: date), let today = response.day(containing: date) {
                SunPathDial(day: today, path: path, next: next, now: date, usesDayColours: false, launch: 1, ripple: 1, rippleAt: nil, showsText: false, weight: 2)
                    .frame(width: 54)
            }
            VStack(alignment: .leading, spacing: 0) {
                Text(next.prayer.name)
                    .font(.system(size: 15, weight: .semibold))
                Text(SunPathDial.countdown(to: next.begins, from: date))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(SunPathDial.countdownColor(to: next.begins, from: date, usesDayColours: false))
                Text("at \(NextPrayerComplicationView.shortTime(next.begins))")
                    .font(.system(size: 13))
                    .opacity(0.7)
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 0) {
                Text(HijriDate.day(listed))
                    .font(.system(size: 15, weight: .semibold))
                Text(HijriDate.shortMonth(listed))
                    .font(.system(size: 13))
                    .opacity(0.75)
                Text(String(HijriDate.year(listed)))
                    .font(.system(size: 13))
                    .opacity(0.5)
            }
        }
        .foregroundStyle(Palette.ink)
        .lineLimit(1)
    }
}
