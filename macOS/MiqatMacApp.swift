import AppKit
import Sparkle
import SwiftUI

@main
struct MiqatMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    #if DEBUG
    private static let startsUpdater = false
    #else
    private static let startsUpdater = true
    #endif

    private var statusItem: StatusItemController?
    private let updaterController = SPUStandardUpdaterController(
        startingUpdater: AppDelegate.startsUpdater,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = StatusItemController()
    }
}
