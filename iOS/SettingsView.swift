import PrayerKit
import SwiftUI

enum NotificationSettings {
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
