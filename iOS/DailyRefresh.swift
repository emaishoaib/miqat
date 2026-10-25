import BackgroundTasks

enum DailyRefresh {
    static let identifier = "com.mashoaib.miqat.daily-refresh"

    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = TimetableModel.nextDailyRefresh
        try? BGTaskScheduler.shared.submit(request)
    }
}
