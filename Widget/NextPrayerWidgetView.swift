import PrayerKit
import SwiftUI
import WidgetKit

struct NextPrayerWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: PrayerEntry

    var body: some View {
        if let response = entry.response, let next = response.nextPrayer(after: entry.date) {
            switch family {
            case .systemMedium:
                MediumView(next: next, day: response.day(containing: entry.date), date: entry.date)
            case .accessoryRectangular:
                RectangularView(next: next, date: entry.date)
            case .accessoryInline:
                Text("\(next.prayer.name) \(next.begins.formatted(date: .omitted, time: .shortened))")
            default:
                NextPrayerSummary(next: next, date: entry.date)
            }
        } else {
            Text("Open Miqat to load prayer times")
                .font(.caption)
                .multilineTextAlignment(.center)
        }
    }
}

private struct NextPrayerSummary: View {
    let next: PrayerTime
    let date: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Next")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(next.prayer.name)
                .font(.title.bold())
            Text(next.begins.formatted(date: .omitted, time: .shortened))
                .font(.headline)
            Text(next.begins, style: .relative)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Text(HijriDate.formatted(date))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

private struct MediumView: View {
    let next: PrayerTime
    let day: PrayerDay?
    let date: Date

    var body: some View {
        HStack(spacing: 16) {
            NextPrayerSummary(next: next, date: date)
            if let day {
                VStack(spacing: 3) {
                    ForEach(day.times.filter(\.prayer.isPrayer), id: \.prayer) { time in
                        HStack {
                            Text(time.prayer.name)
                            Spacer()
                            Text(time.begins.formatted(date: .omitted, time: .shortened))
                                .monospacedDigit()
                        }
                        .font(.subheadline)
                        .fontWeight(time == next ? .bold : .regular)
                        .foregroundStyle(time == next ? Color.accentColor : .primary)
                    }
                }
            }
        }
    }
}

private struct RectangularView: View {
    let next: PrayerTime
    let date: Date

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 0) {
                Text(next.prayer.name)
                    .font(.headline)
                Text(next.begins.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                Text(next.begins, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Rectangle()
                .frame(width: 1)
                .opacity(0.4)
                .padding(.vertical, 6)

            VStack(spacing: 2) {
                Text(HijriDate.month(date))
                    .font(.caption.weight(.semibold))
                    .textCase(.uppercase)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .allowsTightening(true)
                Text(HijriDate.day(date))
                    .font(.headline.bold())
                    .monospacedDigit()
                    .lineLimit(1)
                Text(verbatim: "\(HijriDate.monthNumber(date)) · \(HijriDate.year(date))")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.vertical, 4)
            .frame(width: 64)
        }
    }
}
