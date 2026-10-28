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
                Section("Menu bar") {
                    MenuBarSizePicker()
                    MenuBarDatePicker()
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

private struct MenuBarDatePicker: View {
    @AppStorage(MenuBarDate.showsKey) private var showsDate = false
    @AppStorage(MenuBarDate.calendarKey) private var calendar = MenuBarDate.gregorian

    var body: some View {
        Toggle("Show the date", isOn: $showsDate)
        Picker("Calendar", selection: $calendar) {
            ForEach(MenuBarDate.allCases, id: \.self) { option in
                Text(option.name)
                    .tag(option)
            }
        }
        .pickerStyle(.radioGroup)
        .disabled(!showsDate)
    }
}

private struct MenuBarSizePicker: View {
    @AppStorage(MenuBarSize.key) private var size = MenuBarSize.compact

    var body: some View {
        Picker("Size", selection: $size) {
            ForEach(MenuBarSize.allCases, id: \.self) { option in
                Text(option.name)
                    .tag(option)
            }
        }
        .pickerStyle(.radioGroup)
    }
}
