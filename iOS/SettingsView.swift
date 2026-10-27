import AVFoundation
import PrayerKit
import SwiftUI

enum Appearance: String, CaseIterable {
    static let key = "appearance"

    case sun
    case system
    case day
    case night

    var name: String {
        switch self {
        case .sun: "Follow the sun"
        case .system: "Match the system"
        case .day: "Always day"
        case .night: "Always night"
        }
    }
}

enum NotificationSettings {
    static let reminderKey = "reminderMinutes"
    static let reminderOptions = [0, 5, 10, 15, 20, 30]

    static let soundKey = "sound"

    static var reminderMinutes: Int {
        UserDefaults.standard.integer(forKey: reminderKey)
    }

    static var sound: NotificationSound {
        UserDefaults.standard.string(forKey: soundKey).flatMap(NotificationSound.init) ?? .standard
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
                    SoundPicker()
                }
                Section {
                    AppearancePicker()
                }
                Section {
                    LabeledContent("Version", value: "\(Self.info("CFBundleShortVersionString")) (\(Self.info("CFBundleVersion")))")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .font(.body)
            .foregroundStyle(.primary)
            .tint(nil)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private static func info(_ key: String) -> String {
        Bundle.main.object(forInfoDictionaryKey: key) as? String ?? ""
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

private struct SoundPicker: View {
    @AppStorage(NotificationSettings.soundKey) private var sound = NotificationSound.standard
    @State private var player: AVAudioPlayer?

    var body: some View {
        Picker("Sound", selection: $sound) {
            ForEach(NotificationSound.allCases, id: \.self) { option in
                Text(option.name)
                    .tag(option)
            }
        }
        .onChange(of: sound) {
            play(sound)
            Task {
                await PrayerNotifications.reschedule()
            }
        }
    }

    private func play(_ sound: NotificationSound) {
        player = sound.fileName
            .flatMap { Bundle.main.url(forResource: $0, withExtension: nil) }
            .flatMap { try? AVAudioPlayer(contentsOf: $0) }
        player?.play()
    }
}

private struct AppearancePicker: View {
    @AppStorage(Appearance.key) private var appearance = Appearance.sun

    var body: some View {
        Picker("Appearance", selection: $appearance) {
            ForEach(Appearance.allCases, id: \.self) { option in
                Text(option.name)
                    .tag(option)
            }
        }
    }
}
