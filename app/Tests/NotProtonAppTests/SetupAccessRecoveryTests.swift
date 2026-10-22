import Foundation
import Testing

@testable import NotProtonApp

@MainActor
@Suite("App Management setup recovery")
struct SetupAccessRecoveryTests {
    @Test("The macOS App Management prompt explains why Neutron needs access")
    func nativePermissionPurpose() throws {
        let app = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let info = try #require(PropertyListSerialization.propertyList(from: Data(contentsOf: app.appending(path: "Info.plist")), format: nil) as? [String: Any])
        let purpose = try #require(info["NSAppBundlesUsageDescription"] as? String)
        #expect(purpose.contains("Steam"))
        #expect(!purpose.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    private func fixture() throws -> (URL, SetupAccessRecovery, SetupAccessRecovery.Request, WriteRefused) {
        let work = try scratchDirectory("setup-access")
        let steam = work.appending(path: "Steam.app")
        try FileManager.default.createDirectory(at: steam.appending(path: "Contents/MacOS"), withIntermediateDirectories: true)
        try Data().write(to: steam.appending(path: "Contents/Info.plist"))
        let recovery = SetupAccessRecovery(file: work.appending(path: "support/pending.json"))
        return (work, recovery, .init(.setup(acceptD3DMetal: true), steam: steam),
                WriteRefused(path: steam.appending(path: "Contents/MacOS").path(percentEncoded: false)))
    }

    private func status(_ recovery: SetupAccessRecovery) -> SystemStatus {
        let status = SystemStatus(accessRecovery: recovery)
        status.refreshAfterRun = { _ in }
        return status
    }

    @Test("The first denial prompts for access and stops setup without reporting failure")
    func firstDenialPauses() async throws {
        let (work, recovery, request, refusal) = try fixture()
        defer { try? FileManager.default.removeItem(at: work) }
        let status = status(recovery)
        await status.perform(from: "Install", accessRequest: request) { _ in throw refusal }
        #expect(status.failure == nil)
        #expect(status.outcome == nil)
        #expect(status.accessNeeded == request)
        #expect(status.pendingConfirmation == .appManagement)
        #expect(status.isIdle)
        #expect(try recovery.take() == request)
    }

    @Test("A fresh process resumes the exact setup and acceptance choice once", arguments: [false, true])
    func resumesOnce(accepted: Bool) async throws {
        let (work, recovery, original, _) = try fixture()
        defer { try? FileManager.default.removeItem(at: work) }
        let request = SetupAccessRecovery.Request(.setup(acceptD3DMetal: accepted), steam: URL(filePath: original.steamPath))
        try recovery.save(request)
        let fresh = status(recovery)
        var requests: [SetupAccessRecovery.Request] = []
        let steam = URL(filePath: request.steamPath)
        await fresh.resumeSetupAfterRelaunch(steam: steam) { requests.append($0) }
        await fresh.resumeSetupAfterRelaunch(steam: steam) { requests.append($0) }
        #expect(requests == [request])
        #expect(try recovery.take() == nil)
    }

    @Test("Only a permission denial after relaunch becomes a failure, without another prompt loop")
    func retryStillDenied() async throws {
        let (work, recovery, request, refusal) = try fixture()
        defer { try? FileManager.default.removeItem(at: work) }
        try recovery.save(request)
        let fresh = status(recovery)
        await fresh.resumeSetupAfterRelaunch(steam: URL(filePath: request.steamPath)) { resumed in
            await fresh.perform(from: "Install", accessRequest: resumed) { _ in throw refusal }
        }
        #expect(fresh.failure?.contains("App Management") == true)
        #expect(fresh.failureRemedy == .appManagement)
        #expect(fresh.accessNeeded == nil)
        #expect(fresh.pendingConfirmation == nil)
        #expect(try recovery.take() == nil)
    }

    @Test("A granted retry completes and clears the pending request")
    func grantedRetryFinishes() async throws {
        let (work, recovery, request, _) = try fixture()
        defer { try? FileManager.default.removeItem(at: work) }
        try recovery.save(request)
        let fresh = status(recovery)
        await fresh.resumeSetupAfterRelaunch(steam: URL(filePath: request.steamPath)) { resumed in
            await fresh.perform(from: "Install", accessRequest: resumed) { _ in "Installed" }
        }
        #expect(fresh.failure == nil)
        #expect(fresh.outcome == "Installed")
        #expect(fresh.accessNeeded == nil)
        #expect(try recovery.take() == nil)
    }

    @Test("Unrelated errors and folder ownership problems are not hidden as permission requests")
    func unrelatedFailuresRemainVisible() async throws {
        let (work, recovery, request, _) = try fixture()
        defer { try? FileManager.default.removeItem(at: work) }
        let status = status(recovery)
        await status.perform(from: "Install", accessRequest: request) { _ in
            throw WriteRefused(path: work.path(percentEncoded: false))
        }
        #expect(status.failureRemedy == .ownership)
        #expect(status.accessNeeded == nil)
        #expect(try recovery.take() == nil)
        await status.perform(from: "Install", accessRequest: request) { _ in
            throw StepFailure(step: "Verify download", detail: "Hash mismatch")
        }
        #expect(status.failure?.contains("Hash mismatch") == true)
        #expect(status.accessNeeded == nil)
    }

    @Test("A resumed operation never changes a newly selected Steam installation")
    func changedTargetIsRejected() async throws {
        let (work, recovery, request, _) = try fixture()
        defer { try? FileManager.default.removeItem(at: work) }
        try recovery.save(request)
        let fresh = status(recovery)
        var ran = false
        await fresh.resumeSetupAfterRelaunch(steam: work.appending(path: "Different.app")) { _ in ran = true }
        #expect(!ran)
        #expect(fresh.failure?.contains("location changed") == true)
        #expect(try recovery.take() == nil)
    }

    @Test("Standalone installation requests also survive relaunch without becoming guided setup")
    func standaloneInstallRoundTrip() throws {
        let (work, recovery, setup, _) = try fixture()
        defer { try? FileManager.default.removeItem(at: work) }
        let request = SetupAccessRecovery.Request(.install, steam: URL(filePath: setup.steamPath))
        try recovery.save(request)
        #expect(try recovery.take() == request)
        #expect(try recovery.take() == nil)
    }

    @Test("A successful manual retry clears the prompt and does not leave setup queued for the next launch")
    func manualRetryClearsRecovery() async throws {
        let (work, recovery, request, refusal) = try fixture()
        defer { try? FileManager.default.removeItem(at: work) }
        let status = status(recovery)
        await status.perform(from: "Install", accessRequest: request) { _ in throw refusal }
        await status.perform(from: "Install", accessRequest: request) { _ in "Installed" }
        #expect(status.failure == nil)
        #expect(status.accessNeeded == nil)
        #expect(status.pendingConfirmation == nil)
        #expect(try recovery.take() == nil)
    }

    @Test("An unrelated error on a manual retry cancels the saved permission retry")
    func unrelatedRetryErrorDoesNotQueueSetup() async throws {
        let (work, recovery, request, refusal) = try fixture()
        defer { try? FileManager.default.removeItem(at: work) }
        let status = status(recovery)
        await status.perform(from: "Install", accessRequest: request) { _ in throw refusal }
        await status.perform(from: "Install", accessRequest: request) { _ in
            throw StepFailure(step: "Verify payload", detail: "Invalid payload")
        }
        #expect(status.failure?.contains("Invalid payload") == true)
        #expect(status.accessNeeded == nil)
        #expect(try recovery.take() == nil)
    }
}
