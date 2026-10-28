import PrayerKit
import SwiftUI

struct WatchTimetableView: View {
    let response: PrayerTimesResponse
    let now: Date
    let isRefreshing: Bool
    let refresh: () async -> Void

    var body: some View {
        let next = response.nextPrayer(after: now)
        let today = response.day(containing: now)
        let path = response.sunPath(on: now)
        let listed = next.flatMap { response.day(containing: $0.begins) } ?? today
        let isDay = path.map { now >= $0.sunrise && now < $0.maghrib } ?? true

        ScrollView {
            VStack(spacing: 12) {
                ZStack(alignment: .topLeading) {
                    if let next, let today, let path {
                        VStack(spacing: 2) {
                            SunPathDial(day: today, path: path, next: next, now: now, usesDayColours: isDay, launch: 1, ripple: 1, rippleAt: nil, isCompact: true)
                            if let jamaat = next.jamaat {
                                Text("Jamaat \(jamaat.formatted(date: .omitted, time: .shortened))")
                                    .font(.footnote)
                                    .foregroundStyle(Palette.ink.opacity(0.7))
                            }
                        }
                    }
                    RefreshButton(isRefreshing: isRefreshing, refresh: refresh)
                        .padding(.leading, 8)
                        .padding(.top, 5)
                }

                if let listed {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(HijriDate.formatted(listed.hijriDate(at: now)))
                            .font(.footnote)
                            .foregroundStyle(Palette.ink.opacity(0.6))
                            .padding(.bottom, 4)
                        ForEach(listed.times, id: \.prayer) { time in
                            let isNext = time == next
                            Rectangle()
                                .fill(Palette.ink.opacity(0.15))
                                .frame(height: 0.5)
                            HStack {
                                Text(time.prayer.name)
                                Spacer()
                                Text(time.begins.formatted(date: .omitted, time: .shortened))
                            }
                            .monospacedDigit()
                            .fontWeight(isNext ? .semibold : .regular)
                            .foregroundStyle(isNext ? Palette.gold : Palette.ink)
                            .opacity(time.begins <= now && !isNext ? 0.45 : 1)
                            .padding(.vertical, 6)
                        }
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 12)
        }
        .ignoresSafeArea(.container, edges: .top)
        .foregroundStyle(Palette.ink)
        .background {
            (isDay ? Palette.day : Palette.night)
                .ignoresSafeArea()
        }
    }
}

private struct RefreshButton: View {
    let isRefreshing: Bool
    let refresh: () async -> Void

    var body: some View {
        Button {
            Task { await refresh() }
        } label: {
            Group {
                if isRefreshing {
                    ProgressView()
                } else {
                    Image(systemName: "arrow.clockwise")
                }
            }
            .frame(width: 20, height: 20)
        }
        .buttonStyle(.plain)
        .disabled(isRefreshing)
        .accessibilityLabel("Refresh prayer times")
    }
}
