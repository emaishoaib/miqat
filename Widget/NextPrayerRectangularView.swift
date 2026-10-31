import PrayerKit
import SwiftUI

struct NextPrayerRectangularView: View {
    let next: PrayerTime
    let hijriDate: Date

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 0) {
                Text(next.prayer.name)
                    .font(.headline)
                    .lineLimit(1)
                Text(next.begins.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(next.begins, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)

            Rectangle()
                .frame(width: 1)
                .opacity(0.4)
                .padding(.vertical, 6)

            VStack(spacing: 2) {
                Text(HijriDate.month(hijriDate))
                    .font(.caption.weight(.semibold))
                    .textCase(.uppercase)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .allowsTightening(true)
                Text(HijriDate.day(hijriDate))
                    .font(.headline.bold())
                    .monospacedDigit()
                    .lineLimit(1)
                Text(verbatim: "\(HijriDate.monthNumber(hijriDate)) · \(HijriDate.year(hijriDate))")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.vertical, 4)
            .frame(minWidth: 64, maxWidth: 64)
        }
    }
}
