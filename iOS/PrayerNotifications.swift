import Foundation
import PrayerKit
import UserNotifications

enum PrayerNotifications {
    static let limit = 64

    static func requestPermission() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
    }

    static func reschedule(cache: TimetableCache = .shared, now: Date = .now) async {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        guard let response = cache.load() else { return }
        let reminder = NotificationSettings.reminderMinutes
        let alerts = response.days
            .flatMap(\.times)
            .filter { NotificationSettings.isEnabled($0.prayer) }
            .flatMap { time in
                Set([0, reminder]).map { Alert(time: time, minutesBefore: $0) }
            }
            .filter { $0.date > now }
            .sorted { $0.date < $1.date }
            .prefix(limit)

        for alert in alerts {
            try? await center.add(alert.request)
        }
    }
}

enum NotificationSound: String, CaseIterable {
    case standard
    case water
    case birds
    case nightingale
    case tasbih

    var name: String {
        switch self {
        case .standard: "Default"
        case .water: "Water"
        case .birds: "Birds"
        case .nightingale: "Nightingale"
        case .tasbih: "Tasbih"
        }
    }

    var fileName: String? {
        self == .standard ? nil : "\(rawValue).caf"
    }

    var notificationSound: UNNotificationSound {
        fileName.map { UNNotificationSound(named: UNNotificationSoundName($0)) } ?? .default
    }
}

private struct Alert {
    let time: PrayerTime
    let minutesBefore: Int

    var date: Date {
        time.begins.addingTimeInterval(-Double(minutesBefore) * 60)
    }

    var request: UNNotificationRequest {
        let begins = time.begins.formatted(date: .omitted, time: .shortened)
        let content = UNMutableNotificationContent()
        content.title = time.prayer.name
        content.body = minutesBefore == 0 ? "Begins at \(begins)" : "Begins in \(minutesBefore) minutes, at \(begins)"
        content.sound = NotificationSettings.sound.notificationSound

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let identifier = "\(time.prayer.rawValue)-\(Int(time.begins.timeIntervalSince1970))-\(minutesBefore)"
        return UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
    }
}
