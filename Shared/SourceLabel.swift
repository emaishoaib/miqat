import PrayerKit
import SwiftUI

struct SourceLabel: View {
    #if os(macOS)
    private static let mosqueIconLift: CGFloat = 1
    private static let cityIconLift: CGFloat = 0.73
    #else
    private static let mosqueIconLift: CGFloat = 1.03
    private static let cityIconLift: CGFloat = 0.76
    #endif

    let source: TimesSource

    @ScaledMetric(relativeTo: .subheadline) private var iconSize: CGFloat = 16

    var body: some View {
        switch source {
        case .mosque(let mosque, let distance):
            let measurement = Measurement(value: distance, unit: UnitLength.meters)
            Label {
                Text("\(mosque.name) · \(measurement.formatted(.measurement(width: .abbreviated, usage: .road)))")
            } icon: {
                icon(named: "MosqueIcon")
                    .offset(y: -Self.mosqueIconLift)
            }
        case .city(let name, _, _):
            Label {
                Text(name)
            } icon: {
                icon(named: "CityIcon")
                    .offset(y: -Self.cityIconLift)
            }
        }
    }

    private func icon(named name: String) -> some View {
        Image(name)
            .resizable()
            .scaledToFit()
            .frame(width: iconSize, height: iconSize)
    }
}
