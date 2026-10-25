import WatchKit

enum WatchDailyRefresh {
    @MainActor
    static func schedule() {
        WKApplication.shared().scheduleBackgroundRefresh(withPreferredDate: TimetableModel.nextDailyRefresh, userInfo: nil) { _ in }
    }
}
