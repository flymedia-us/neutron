import AppKit

@MainActor
final class AppUpdater {
    func check() {
        NSWorkspace.shared.open(URL(string: "https://github.com/flymedia-us/neutron/releases")!)
    }
}
