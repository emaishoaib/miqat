import PrayerKit
import SwiftUI

struct WatchTimetableView: View {
    let response: PrayerTimesResponse
    let now: Date
    let isRefreshing: Bool
    let refresh: () async -> Void

    var body: some View {
        let next = response.nextPrayer(after: now)

        List {
            if let next {
                NextPrayerHeader(time: next)
                    .listRowBackground(Color.clear)
            }

            if let today = response.day(containing: now) {
                Section {
                    ForEach(today.times, id: \.prayer) { time in
                        HStack {
                            Text(time.prayer.name)
                            Spacer()
                            Text(time.begins.formatted(date: .omitted, time: .shortened))
                                .monospacedDigit()
                        }
                        .fontWeight(time == next ? .semibold : .regular)
                        .foregroundStyle(time == next ? AnyShapeStyle(Color.blue) : time.prayer.isPrayer ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
                    }
                } header: {
                    Text(HijriDate.formatted(now))
                }
            }

            Button {
                Task { await refresh() }
            } label: {
                HStack {
                    Text("Refresh")
                    Spacer()
                    if isRefreshing {
                        ProgressView()
                            .frame(width: 20)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .disabled(isRefreshing)
        }
    }
}

private struct NextPrayerHeader: View {
    let time: PrayerTime

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Next prayer")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(time.prayer.name)
                .font(.title2.bold())
            Text(time.begins.formatted(date: .omitted, time: .shortened))
                .font(.headline)
            Text(time.begins, style: .relative)
                .font(.caption)
                .foregroundStyle(.secondary)
            if let jamaat = time.jamaat {
                Text("Jamaat \(jamaat.formatted(date: .omitted, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
