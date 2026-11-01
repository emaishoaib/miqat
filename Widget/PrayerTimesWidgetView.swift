import PrayerKit
import SwiftUI
import WidgetKit

struct PrayerTimesWidgetView: View {
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage(Appearance.key, store: Appearance.store) private var appearance = Appearance.sun

    let entry: PrayerEntry

    var body: some View {
        let now = entry.date
        let path = entry.response?.sunPath(on: now)
        let sunIsUp = path.map { now >= $0.sunrise && now < $0.maghrib } ?? true
        let isDay = appearance.usesDayColours(sunIsUp: sunIsUp, systemIsDark: colorScheme == .dark)

        Group {
            if let response = entry.response,
               let path,
               let next = response.nextPrayer(after: now),
               let today = response.day(containing: now) {
                let listed = response.day(containing: next.begins) ?? today
                VStack(spacing: 0) {
                    HijriDateLine(date: listed.hijriDate(at: now))
                    Spacer(minLength: 0)
                    SunPathDial(day: today, path: path, next: next, now: now, usesDayColours: isDay, launch: 1, ripple: 1, rippleAt: nil, isCompact: true, weight: 1.15, compactTextScale: 1.15, showsCountdownPrefix: false)
                        .frame(width: 104)
                        .offset(y: -1)
                    Spacer(minLength: 0)
                    PrayerGrid(day: listed, next: next, now: now)
                }
                .padding(.horizontal, 12)
                .padding(.top, 6)
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

private struct HijriDateLine: View {
    let date: Date

    var body: some View {
        HStack(spacing: 4) {
            Text("\(HijriDate.day(date)) \(HijriDate.month(date))")
                .fontWeight(.medium)
            Text(String(HijriDate.year(date)))
                .opacity(0.5)
        }
        .font(.system(size: 12))
        .lineLimit(1)
        .minimumScaleFactor(0.8)
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
