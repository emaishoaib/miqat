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
        let times = response.days
            .flatMap(\.times)
            .filter { $0.begins > now && NotificationSettings.isEnabled($0.prayer) }
            .prefix(limit)

        for time in times {
            try? await center.add(request(for: time))
        }
    }

    private static func request(for time: PrayerTime) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = time.prayer.name
        content.body = "Begins at \(time.begins.formatted(date: .omitted, time: .shortened))"
        content.sound = .default

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: time.begins)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let identifier = "\(time.prayer.rawValue)-\(Int(time.begins.timeIntervalSince1970))"
        return UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
    }
}
