import PrayerKit
import SwiftUI

struct TimetableView: View {
    let response: PrayerTimesResponse
    let now: Date

    var body: some View {
        let next = response.nextPrayer(after: now)

        List {
            Section {
                DateHeader(now: now, source: response.source)
            }

            if let next {
                Section {
                    NextPrayerCard(time: next)
                }
            }

            if let today = response.day(containing: now) {
                Section {
                    ForEach(today.times, id: \.prayer) { time in
                        PrayerRow(time: time, isNext: time == next)
                    }
                } header: {
                    HStack {
                        Text("Prayer")
                        Spacer()
                        Text("Begins").frame(width: PrayerRow.columnWidth, alignment: .trailing)
                        Text("Jamaat").frame(width: PrayerRow.columnWidth, alignment: .trailing)
                    }
                }
            }
        }
    }
}

private struct DateHeader: View {
    let now: Date
    let source: TimesSource

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                .font(.title2.bold())
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
        case .area(let name):
            Label(name, systemImage: "mappin.and.ellipse")
        }
    }
}

private struct NextPrayerCard: View {
    let time: PrayerTime

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Next prayer")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline) {
                Text(time.prayer.name)
                    .font(.largeTitle.bold())
                Spacer()
                Text(time.begins, style: .relative)
                    .font(.headline)
                    .monospacedDigit()
            }
            if let jamaat = time.jamaat {
                Text("Jamaat at \(jamaat.formatted(date: .omitted, time: .shortened))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct PrayerRow: View {
    static let columnWidth: CGFloat = 76

    let time: PrayerTime
    let isNext: Bool

    var body: some View {
        HStack {
            Text(time.prayer.name)
                .fontWeight(isNext ? .semibold : .regular)
            Spacer()
            Text(time.begins.formatted(date: .omitted, time: .shortened))
                .frame(width: Self.columnWidth, alignment: .trailing)
            Text(time.jamaat?.formatted(date: .omitted, time: .shortened) ?? "")
                .frame(width: Self.columnWidth, alignment: .trailing)
        }
        .monospacedDigit()
        .foregroundStyle(time.prayer.isPrayer ? .primary : .secondary)
        .listRowBackground(isNext ? Color.accentColor.opacity(0.15) : nil)
    }
}
