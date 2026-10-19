import AppKit
import Observation
import Sparkle

@MainActor
@Observable
final class AppUpdater {
    private let channelDelegate = ReleaseChannelDelegate()
    private let controller: SPUStandardUpdaterController
    private(set) var canCheckForUpdates = false
    private var observation: NSKeyValueObservation?

    init() {
        // Source builds without a release key can still run, but must never
        // accept an unauthenticated update or start background feed requests.
        let key = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String
        let configured = key.flatMap { Data(base64Encoded: $0) }?.count == 32
        controller = SPUStandardUpdaterController(
            startingUpdater: false, updaterDelegate: channelDelegate, userDriverDelegate: nil)
        if configured {
            do { try controller.updater.start() }
            catch { AppLog.note("Automatic updater could not start: \(error.localizedDescription)") }
            observation = controller.updater.observe(\.canCheckForUpdates, options: [.initial, .new]) { [weak self] _, _ in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.canCheckForUpdates = self.controller.updater.canCheckForUpdates
                }
            }
        }
    }

    func check() {
        controller.checkForUpdates(nil)
    }
}

@MainActor
private final class ReleaseChannelDelegate: NSObject, SPUUpdaterDelegate {
    func allowedChannels(for updater: SPUUpdater) -> Set<String> {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        return version.contains("-") ? ["preview"] : []
    }

}
