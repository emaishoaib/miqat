import PrayerKit
import SwiftUI
import WidgetKit

struct PrayerTimesWidgetView: View {
    let entry: PrayerEntry

    var body: some View {
        let now = entry.date
        let path = entry.response?.sunPath(on: now)
        let isDay = path.map { now >= $0.sunrise && now < $0.maghrib } ?? true

        Group {
            if let response = entry.response,
               let path,
               let next = response.nextPrayer(after: now),
               let today = response.day(containing: now) {
                let listed = response.day(containing: next.begins) ?? today
                ZStack(alignment: .top) {
                    VStack(spacing: 2) {
                        Spacer(minLength: 0)
                        SunPathDial(day: today, path: path, next: next, now: now, usesDayColours: isDay, launch: 1, pulse: 0, ripple: 1, rippleAt: nil, isCompact: true)
                            .frame(width: 118)
                        PrayerGrid(day: listed, next: next, now: now)
                    }
                    HStack(alignment: .top) {
                        DateCorner(
                            day: listed.date.formatted(.dateTime.day()),
                            month: listed.date.formatted(.dateTime.month(.abbreviated)),
                            year: listed.date.formatted(.dateTime.year()),
                            alignment: .leading
                        )
                        Spacer()
                        DateCorner(
                            day: HijriDate.day(listed.date),
                            month: HijriDate.shortMonth(listed.date),
                            year: String(HijriDate.year(listed.date)),
                            alignment: .trailing
                        )
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 9)
                .padding(.bottom, 8)
            } else {
                Text("Open Miqat to load prayer times")
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .padding()
            }
        }
        .foregroundStyle(Palette.ink)
        .containerBackground(for: .widget) {
            isDay ? Palette.day : Palette.night
        }
    }
}

private struct DateCorner: View {
    let day: String
    let month: String
    let year: String
    let alignment: HorizontalAlignment

    var body: some View {
        VStack(alignment: alignment, spacing: 0) {
            Text(day)
                .font(.system(size: 15, weight: .semibold))
            Text(month)
                .font(.system(size: 11))
                .opacity(0.75)
            Text(year)
                .font(.system(size: 11))
                .opacity(0.5)
        }
        .lineLimit(1)
    }
}

private struct PrayerGrid: View {
    let day: PrayerDay
    let next: PrayerTime
    let now: Date

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 3), spacing: 1) {
            ForEach(day.times, id: \.prayer) { time in
                let isNext = time == next
                VStack(spacing: 0) {
                    Text(time.prayer.name)
                    Text(time.begins.formatted(.dateTime.hour(.defaultDigits(amPM: .omitted)).minute()))
                        .monospacedDigit()
                }
                .font(.system(size: 11, weight: isNext ? .semibold : .regular))
                .foregroundStyle(isNext ? Palette.gold : Palette.ink)
                .opacity(time.begins <= now && !isNext ? 0.45 : 1)
                .lineLimit(1)
            }
        }
    }
}
