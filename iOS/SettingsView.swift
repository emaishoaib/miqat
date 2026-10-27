import PrayerKit
import SwiftUI

enum NotificationSettings {
    static let reminderKey = "reminderMinutes"
    static let reminderOptions = [0, 5, 10, 15, 20, 30]

    static var reminderMinutes: Int {
        UserDefaults.standard.integer(forKey: reminderKey)
    }

    static func key(for prayer: Prayer) -> String {
        "notifies.\(prayer.rawValue)"
    }

    static func isEnabled(_ prayer: Prayer) -> Bool {
        UserDefaults.standard.bool(forKey: key(for: prayer))
    }
}

struct SettingsButton: View {
    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented = true
        } label: {
            Image(systemName: "gearshape")
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("Settings")
        .sheet(isPresented: $isPresented) {
            SettingsView()
        }
    }
}

private struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Notifications") {
                    ForEach(Prayer.allCases, id: \.self) { prayer in
                        PrayerToggle(prayer: prayer)
                    }
                }
                Section {
                    ReminderPicker()
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct PrayerToggle: View {
    let prayer: Prayer

    @AppStorage private var isOn: Bool

    init(prayer: Prayer) {
        self.prayer = prayer
        _isOn = AppStorage(wrappedValue: false, NotificationSettings.key(for: prayer))
    }

    var body: some View {
        Toggle(prayer.name, isOn: $isOn)
            .onChange(of: isOn) { _, isOn in
                Task {
                    if isOn {
                        await PrayerNotifications.requestPermission()
                    }
                    await PrayerNotifications.reschedule()
                }
            }
    }
}

private struct ReminderPicker: View {
    @AppStorage(NotificationSettings.reminderKey) private var minutes = 0

    var body: some View {
        Picker("Early reminder", selection: $minutes) {
            ForEach(NotificationSettings.reminderOptions, id: \.self) { option in
                Text(option == 0 ? "Off" : "\(option) minutes before")
                    .tag(option)
            }
        }
        .onChange(of: minutes) {
            Task {
                await PrayerNotifications.reschedule()
            }
        }
    }
}
