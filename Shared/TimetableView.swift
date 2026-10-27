import PrayerKit
import SwiftUI

struct TimetableView: View {
    let response: PrayerTimesResponse
    let now: Date
    let isRefreshing: Bool
    let refresh: () async -> Void

    var body: some View {
        let next = response.nextPrayer(after: now)

        List {
            Section {
                DateHeader(now: now, source: response.source, isRefreshing: isRefreshing, refresh: refresh)
            }

            if let next {
                Section {
                    NextPrayerCard(time: next)
                }
            }

            if let today = response.day(containing: now) {
                let showsJamaat = today.times.contains { $0.jamaat != nil }
                Section {
                    ForEach(today.times, id: \.prayer) { time in
                        PrayerRow(time: time, isNext: time == next, showsJamaat: showsJamaat)
                    }
                } header: {
                    HStack {
                        Text("Prayer")
                        Spacer()
                        Text("Begins").frame(width: PrayerRow.columnWidth, alignment: .trailing)
                        if showsJamaat {
                            Text("Jamaat").frame(width: PrayerRow.columnWidth, alignment: .trailing)
                        }
                    }
                }
            }
        }
        #if os(iOS)
        .pullToRefresh { await refresh() }
        #else
        .refreshable { await refresh() }
        #endif
    }
}

private struct DateHeader: View {
    let now: Date
    let source: TimesSource
    let isRefreshing: Bool
    let refresh: () async -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                    .font(.title2.bold())
                Spacer()
                Button {
                    Task { await refresh() }
                } label: {
                    if isRefreshing {
                        ProgressView()
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .buttonStyle(.borderless)
                .disabled(isRefreshing)
                .accessibilityLabel("Refresh prayer times")
                #if os(iOS)
                SettingsButton()
                #endif
            }
            Text(HijriDate.formatted(now))
                .foregroundStyle(.secondary)
            sourceLabel
                .font(.subheadline)
                .padding(.top, 4)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var sourceLabel: some View {
        switch source {
        case .mosque(let mosque, let distance):
            let measurement = Measurement(value: distance, unit: UnitLength.meters)
            Label {
                Text("\(mosque.name) · \(measurement.formatted(.measurement(width: .abbreviated, usage: .road)))")
            } icon: {
                Image(systemName: "building.columns")
            }
        case .city(let name):
            Label(name, systemImage: "mappin.and.ellipse")
        }
    }
}

private struct NextPrayerCard: View {
    let time: PrayerTime

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Next prayer")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(time.prayer.name)
                    .font(.largeTitle.bold())
                Text("Begins at \(time.begins.formatted(date: .omitted, time: .shortened))")
                    .font(.subheadline)
                if let jamaat = time.jamaat {
                    Text("Jamaat at \(jamaat.formatted(date: .omitted, time: .shortened))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            CountdownDial(target: time.begins)
        }
        .padding(.vertical, 4)
    }
}

private struct PrayerRow: View {
    static let columnWidth: CGFloat = 76

    let time: PrayerTime
    let isNext: Bool
    let showsJamaat: Bool

    var body: some View {
        HStack {
            Text(time.prayer.name)
                .fontWeight(isNext ? .semibold : .regular)
            Spacer()
            Text(time.begins.formatted(date: .omitted, time: .shortened))
                .frame(width: Self.columnWidth, alignment: .trailing)
            if showsJamaat {
                Text(time.jamaat?.formatted(date: .omitted, time: .shortened) ?? "")
                    .frame(width: Self.columnWidth, alignment: .trailing)
            }
        }
        .monospacedDigit()
        .foregroundStyle(time.prayer.isPrayer ? .primary : .secondary)
        .listRowBackground(isNext ? Color.accentColor.opacity(0.15) : nil)
    }
}
