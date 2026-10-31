import PrayerKit
import SwiftUI

struct NextPrayerRectangularView: View {
    let next: PrayerTime
    let hijriDate: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(HijriDate.formatted(hijriDate))
            HStack(spacing: 6) {
                Text(next.prayer.name)
                    .fontWeight(.semibold)
                Text(next.begins.formatted(date: .omitted, time: .shortened))
            }
            Text(next.begins, style: .relative)
                .foregroundStyle(.secondary)
        }
        .font(.body)
        .lineLimit(1)
        .minimumScaleFactor(0.9)
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
