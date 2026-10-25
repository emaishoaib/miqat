import PrayerKit
import SwiftUI

struct NextPrayerRectangularView: View {
    let next: PrayerTime
    let date: Date
    var isSymmetric = false

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: isSymmetric ? .center : .leading, spacing: isSymmetric ? 2 : 0) {
                Text(next.prayer.name)
                    .font(isSymmetric ? .caption.weight(.semibold) : .headline)
                    .lineLimit(1)
                Text(next.begins.formatted(date: .omitted, time: .shortened))
                    .font(isSymmetric ? .headline.bold() : .caption)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(next.begins, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(.vertical, isSymmetric ? 4 : 0)
            .multilineTextAlignment(isSymmetric ? .center : .leading)
            .frame(maxWidth: .infinity, alignment: isSymmetric ? .center : .leading)

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
            .frame(minWidth: 64, maxWidth: isSymmetric ? .infinity : 64)
        }
    }
}
