import PrayerKit
import SwiftUI

struct NextPrayerRectangularView: View {
    let next: PrayerTime
    let hijriDate: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Text(next.prayer.name)
                    .fontWeight(.semibold)
                Text(next.begins.formatted(date: .omitted, time: .shortened))
            }
            Text(next.begins, style: .relative)
                .foregroundStyle(.secondary)
            Text(verbatim: "\(HijriDate.day(hijriDate)) \(HijriDate.month(hijriDate)) \(HijriDate.year(hijriDate))")
        }
        .font(.body)
        .lineLimit(1)
        .minimumScaleFactor(0.9)
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
