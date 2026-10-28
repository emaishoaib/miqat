import Observation
import SwiftUI

@MainActor
@Observable
final class SettingsPage {
    static let shared = SettingsPage()

    var isShown = false
}

struct SettingsButton: View {
    var body: some View {
        Button {
            SettingsPage.shared.isShown = true
        } label: {
            Image(systemName: "gearshape")
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("Settings")
    }
}

struct SettingsView: View {
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Settings")
                    .font(.headline)
                Spacer()
                Button("Done") {
                    SettingsPage.shared.isShown = false
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            Form {
                Section {
                    AppearancePicker()
                }
                Section {
                    VersionRow()
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Palette.night)
        .font(.body)
        .foregroundStyle(Color.primary)
        .tint(nil)
        .environment(\.colorScheme, .dark)
    }
}
