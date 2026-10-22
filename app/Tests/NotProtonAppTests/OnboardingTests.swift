import Foundation
import Testing
@testable import NotProtonApp

@Suite("Guided setup")
struct OnboardingTests {
    @Test("A stock first setup configures the Windows default before Steam has recorded one")
    func firstDefaultAndPreservedChoices() throws {
        let root = try scratchDirectory("guided-default")
        defer { try? FileManager.default.removeItem(at: root) }
        let request = root.appending(path: "default-tool")
        let builds = SupportedRunners.all.filter { $0.runtime == .highball }
        try DefaultTool.configureGuidedDefault(installed: builds, at: request)
        #expect(DefaultTool.isOurs(try #require(DefaultTool.request(at: request))))
        try DefaultTool.clear(at: request)
        try DefaultTool.configureGuidedDefault(installed: builds, at: request)
        #expect(DefaultTool.request(at: request) == "")
        try DefaultTool.set("another-explicit-choice", at: request)
        try DefaultTool.configureGuidedDefault(installed: builds, at: request)
        #expect(DefaultTool.request(at: request) == "another-explicit-choice")
    }

    @Test("Missing engine and unwritable requests fail rather than claiming setup completed")
    func defaultFailures() throws {
        let root = try scratchDirectory("guided-failure")
        defer { try? FileManager.default.removeItem(at: root) }
        #expect(throws: (any Error).self) {
            try DefaultTool.configureGuidedDefault(installed: [], at: root.appending(path: "request"))
        }
        let file = root.appending(path: "file")
        try Data().write(to: file)
        #expect(throws: (any Error).self) {
            try DefaultTool.configureGuidedDefault(installed: SupportedRunners.all,
                                                   at: file.appending(path: "request"))
        }
    }


}

@Suite("Setup readiness")
struct SetupReadinessTests {
    private func readySnapshot() -> StatusSnapshot {
        let builds = SupportedRunners.all.filter { $0.runtime == .highball }
        return StatusSnapshot(
            steam: .installed(version: "test"), steamRunning: false, updateBlocked: false,
            runner: .ready(builds: builds.map(\.id)),
            payload: PayloadState(expected: 0, present: 0, missing: [], overlayShimPresent: true,
                                  iconmakerPresent: true, appinfoPresent: true, highballEnvPresent: true,
                                  highballDBPresent: true, signatureDatabase: "test", legacyCompatPresent: 0,
                                  legacyCompatExpected: 0),
            installedRunners: builds, installContent: .current,
            defaultToolRequest: "neutron-proton-highball-x64-crossover26.3-r19")
    }

    @Test("Readiness follows real files, tool health and prerequisites, including after setup")
    func readiness() {
        var snapshot = readySnapshot()
        #expect(snapshot.readyToPlay)
        snapshot.defaultToolRequest = nil
        #expect(!snapshot.readyToPlay)
        snapshot.defaultToolRequest = "" // Deliberately choosing per-game tools is supported.
        #expect(snapshot.readyToPlay)
        snapshot.rosettaInstalled = false
        #expect(!snapshot.readyToPlay)
        #expect(snapshot.setupBlocked)
        snapshot = readySnapshot()
        snapshot.steam = .notInstalled
        #expect(!snapshot.readyToPlay)
        snapshot = readySnapshot()
        snapshot.payload.highballEnvPresent = false
        #expect(!snapshot.readyToPlay)
        snapshot = readySnapshot()
        snapshot.runner = .unpatched(builds: snapshot.installedRunners.map(\.id), problems: ["missing"])
        #expect(!snapshot.readyToPlay)
        snapshot = readySnapshot()
        snapshot.installContent = .newerInstalled
        #expect(!snapshot.readyToPlay)
        #expect(snapshot.setupBlocked)
        snapshot = readySnapshot()
        snapshot.steam = .foreign(insert: "/old/integration.dylib")
        #expect(snapshot.setupBlocked)
    }
}
