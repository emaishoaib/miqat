import Foundation
import Observation
import Sparkle

@MainActor
@Observable
final class AppUpdater {
    static let shared = AppUpdater()

    private(set) var canCheck = false

    @ObservationIgnored private let controller = SPUStandardUpdaterController(
        startingUpdater: false,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )
    @ObservationIgnored private var observation: NSKeyValueObservation?

    func start() {
        observation = controller.updater.observe(\.canCheckForUpdates, options: [.initial, .new]) { [weak self] updater, _ in
            let canCheck = updater.canCheckForUpdates
            MainActor.assumeIsolated {
                self?.canCheck = canCheck
            }
        }
        #if !DEBUG
        controller.startUpdater()
        #endif
    }

    func check() {
        controller.checkForUpdates(nil)
    }
}
