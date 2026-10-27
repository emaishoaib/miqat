import PrayerKit
import SwiftUI

struct SourceLabel: View {
    let source: TimesSource

    var body: some View {
        switch source {
        case .mosque(let mosque, let distance):
            let measurement = Measurement(value: distance, unit: UnitLength.meters)
            Label {
                Text("\(mosque.name) · \(measurement.formatted(.measurement(width: .abbreviated, usage: .road)))")
            } icon: {
                Image(systemName: "building.columns")
            }
        case .city(let name, _, _):
            Label(name, systemImage: "mappin.and.ellipse")
        }
    }
}
