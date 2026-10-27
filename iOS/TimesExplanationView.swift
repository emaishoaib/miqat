import PrayerKit
import SwiftUI

struct TimesExplanationView: View {
    let source: TimesSource

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("How these times are worked out")
                    .font(.title2.bold())

                switch source {
                case .mosque(let mosque, let distance):
                    Paragraph(
                        title: "From \(mosque.name)'s timetable",
                        text: "These times are taken from the timetable the mosque makes public and added to Miqat as they are, without calculating anything. Miqat isn't connected with the mosque."
                    )
                    Paragraph(
                        title: "Why this mosque",
                        text: "It's the nearest mosque to you whose timetable is in Miqat, \(Measurement(value: distance, unit: UnitLength.meters).formatted(.measurement(width: .wide, usage: .road))) away. Miqat checks the 20 closest mosques within 50 km and uses the first one that has times."
                    )
                    Paragraph(
                        title: "Jamaat",
                        text: "Jamaat times show when the mosque holds the congregational prayer, wherever its timetable lists them."
                    )
                case .city(let name, let method, let asrSchool):
                    Paragraph(
                        title: "Calculated for \(name)",
                        text: "None of the mosques near you has a timetable in Miqat yet, so the times are calculated for your city from the position of the sun."
                    )
                    if let method, let asrSchool {
                        Paragraph(
                            title: "The method",
                            text: "The calculation follows the \(method) method, the one most used in your country. Asr follows the \(asrSchool) school, the most common there."
                        )
                    } else {
                        Paragraph(
                            title: "The method",
                            text: "The calculation follows the method most used in your country, and Asr follows the school of law most common there."
                        )
                    }
                }

                Paragraph(
                    title: "The Hijri date",
                    text: "The Hijri date follows the Umm al-Qura calendar."
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
        }
        .font(.body)
        .foregroundStyle(Palette.ink)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Palette.night)
    }
}

private struct Paragraph: View {
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
            Text(text)
                .foregroundStyle(Palette.ink.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
