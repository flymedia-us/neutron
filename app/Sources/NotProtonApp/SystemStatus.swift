// Logic behind Status view

import AppKit
import Foundation
import Observation
import UniformTypeIdentifiers

enum AppVersion {
    static let fallback = "0.1.0-dev"

    static var bundled: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? fallback
    }
}

struct StatusSnapshot: Sendable {
    var steam: SteamDeployment
    var steamRunning: Bool
    var updateBlocked: Bool
    var runner: RunnerState
    var payload: PayloadState
    var installedRunners: [RunnerBuild] = []
    var orphanedRunners: [String] = []
    var damagedRunners: [String] = []
    var installContent: DeploymentContent.Status = .unchecked
    var highball: [HighballEngine] = []
    var defaultToolRequest: String?
    var steamDefaultTool: String?
    var rosettaInstalled = true

    static func capture(bundledVersion: String) -> StatusSnapshot {
        let runner = RunnerStore.state()
        let installed = RunnerStore.installedBuilds()

        return StatusSnapshot(
            steam: SteamBundle.deployment(bundledVersion: bundledVersion),
            steamRunning: SteamBundle.isRunning,
            updateBlocked: UpdateBlock.isPresent(),
            runner: runner,
            payload: PayloadInspector.inspect(builds: installed),
            installedRunners: installed,
            orphanedRunners: RunnerStore.orphanedClones(),
            damagedRunners: RunnerStore.damagedClones(),
            installContent: DeploymentContent.current(version: bundledVersion),
            highball: HighballSource.discover(),
            defaultToolRequest: DefaultTool.request(),
            steamDefaultTool: DefaultTool.steamDefault(),
            rosettaInstalled: (try? Shell.run("/usr/bin/arch", ["-x86_64", "/usr/bin/true"]).status) == 0
        )
    }
}

@MainActor
@Observable
final class SystemStatus {

    var snapshot: StatusSnapshot?
    var isRefreshing = false
    var activity: String?
    var outcome: String?
    private(set) var failure: String?
    private(set) var failureRemedy: Remedy?

    private var runInFlight = false
    // Tests replace the refresh so a run does not modify the real Steam/support folders
    // if run on an actual user's machine.
    @ObservationIgnored var refreshAfterRun: @MainActor (SystemStatus) async -> Void = { await $0.refresh() }

    private(set) var isSettingUp = false
    var setupRequested = false
    var isBusy: Bool { activity != nil || runInFlight || isSettingUp }
    var isIdle: Bool { !isBusy && !isRefreshing }
    var canInstall: Bool { isIdle && snapshot?.installContent.blocksInstallation != true }

    enum Confirmation: Identifiable, Hashable {
        case replaceSteam
        case blockUpdates
        case removeBuild
        case removeEverything

        var id: Self { self }
    }

    var pendingConfirmation: Confirmation?
    var generation = 0

    func beginRun(_ label: String) -> Int {
        activity = label
        AppLog.note("run begin: \(label)")
        return generation
    }

    func report(_ run: Int, _ label: String) {
        guard run == generation else { return }
        activity = label
        AppLog.note("run step: \(label)")
    }

    func endRun() {
        generation += 1
        activity = nil
        AppLog.note("run end\(failure == nil ? "" : " (failed)")")
    }

    private func record(_ error: Error) {
        setFailure(error)
        if let refusal = error as? WriteRefused {
            AppLog.note("run failed: cannot write \(refusal.path)")
        } else {
            AppLog.note("run failed: \(error.localizedDescription)")
        }
    }

    func setFailure(_ message: String) {
        failure = message
        failureRemedy = nil
    }

    func setFailure(_ error: Error) {
        let report = FailureReport([error])
        failure = report?.message
        failureRemedy = report?.remedy
    }

    func clearFailure() {
        failure = nil
        failureRemedy = nil
    }

    func requestInstall() async {
        guard canInstall else { return }
        await installIntoSteam()
    }

    func requestHighballCompatibilityTool() async {
        guard let engine = HighballSource.discover().first(where: \.isUsable) else {
            setFailure(String(localized: "Download the Highball engine using Set Up Neutron first."))
            return
        }
        await setUpHighball(engine)
    }

    func setUpNeutron(acceptD3DMetal: Bool) async {
        guard canInstall else { return }
        isSettingUp = true
        defer { isSettingUp = false }
        // Check the actual prerequisite again before touching Steam.
        let rosetta = await Task.detached(priority: .utility) {
            (try? Shell.run("/usr/bin/arch", ["-x86_64", "/usr/bin/true"]).status) == 0
        }.value
        guard rosetta else {
            setFailure(String(localized: "Install Rosetta to run Windows games, then try setup again."))
            return
        }
        await installIntoSteam()
        guard failure == nil else { return }
        if let engine = HighballSource.discover().first(where: \.isUsable) {
            if acceptD3DMetal && !engine.d3dmetalAccepted {
                await enableD3DMetal(engine)
                guard failure == nil else { return }
            }
            await setUpHighball(engine)
        } else {
            await downloadHighballEngine(acceptD3DMetal: acceptD3DMetal)
        }
        guard failure == nil else { return }
        await perform(from: String(localized: "Finishing setup")) { _ in
            // Guided setup explicitly promises a Windows-game default. Unlike automatic
            // adoption, this must work before patched Steam has ever been opened.
            try DefaultTool.configureGuidedDefault(installed: RunnerStore.installedBuilds())
            return String(localized: "Setup complete. Open Steam and choose a Windows game to play.")
        }
    }

    func openSteam() {
        guard isIdle, snapshot?.readyToPlay == true else { return }
        let configuration = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.openApplication(at: SupportPaths.Steam.app, configuration: configuration) { _, error in
            if let error {
                Task { @MainActor in self.setFailure(error) }
            }
        }
    }

    private(set) var pendingRemoval: String?

    func requestBuildRemoval(_ build: String) {
        guard canInstall else { return }
        pendingRemoval = build
        pendingConfirmation = .removeBuild
    }

    func cancelBuildRemoval() {
        pendingRemoval = nil
    }

    func removePendingBuild() async {
        guard let build = pendingRemoval else { return }
        pendingRemoval = nil
        await perform(from: RunnerInstaller.removeStep) { _ in
            let lock = try DeploymentContent.acquireInstallationLock()
            defer { lock.release() }
            try await requireUnblockedContent()
            let changed = try await Task.detached(priority: .userInitiated) {
                try RunnerInstaller.removeClone(forBuild: build)
            }.value
            let removed = String(localized: "Removed build \(SupportedRunners.displayVersion(forID: build)).")
            return changed && SteamBundle.isRunning ? "\(removed) \(Self.toolsRestartHint)" : removed
        }
    }

    func chooseSteam() async {
        let current = SupportPaths.Steam.app
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.application]
        panel.prompt = String(localized: "Choose")
        panel.message = String(localized: "Select your copy of Steam.")
        panel.directoryURL = current.deletingLastPathComponent()

        guard panel.runModal() == .OK, let url = panel.url else { return }
        let picked = URL(filePath: url.path)

        clearFailure()
        outcome = nil

        func same(_ a: URL, _ b: URL) -> Bool {
            a.standardizedFileURL.path(percentEncoded: false) == b.standardizedFileURL.path(percentEncoded: false)
        }
        guard !same(picked, current) else { return }
        if SupportPaths.Steam.isUnreachable(current) {
            let alert = NSAlert()
            alert.messageText = String(localized: "Steam at \(current.path(percentEncoded: false)) isn't connected.")
            alert.informativeText = String(localized: "If Neutron is installed there, it will stay installed. Continue anyway?")
            alert.addButton(withTitle: String(localized: "Continue Anyway"))
            alert.addButton(withTitle: String(localized: "Cancel"))
            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }
        do {
            let lock = try DeploymentContent.acquireInstallationLock()
            defer { lock.release() }
            if let refusal = Self.steamChoiceRefusal(picked, current: current) {
                setFailure(refusal)
                AppLog.note("steam choice refused: \(picked.path(percentEncoded: false))")
                return
            }

            if same(picked, SupportPaths.Steam.defaultApp) {
                UserDefaults.standard.removeObject(forKey: SupportPaths.Steam.appPathKey)
            } else {
                UserDefaults.standard.set(picked.path(percentEncoded: false), forKey: SupportPaths.Steam.appPathKey)
            }
        } catch {
            setFailure(error)
            return
        }
        AppLog.note("steam chosen: \(picked.path(percentEncoded: false))")
        await refresh()
    }

    static func steamChoiceRefusal(
        _ picked: URL, current: URL, insert: String? = SteamBundle.currentInsert()
    ) -> String? {
        guard Bundle(url: picked)?.bundleIdentifier == SteamRepair.valveIdentifier else {
            return String(localized: "\(picked.lastPathComponent) is not Steam.")
        }
        guard !picked.path(percentEncoded: false).contains(":") else {
            return String(localized: "Neutron cannot use Steam from a folder with a colon in its name.")
        }
        let deployed = SupportPaths.Steam.deployedDylib(inBundle: current).path(percentEncoded: false)
        if let insert, insert.split(separator: ":").contains(Substring(deployed)) {
            return String(localized: "Neutron is installed in \(current.path(percentEncoded: false)). Use Repair Steam to remove it before choosing another copy of Steam.")
        }
        return nil
    }

    private static let toolsRestartHint = String(localized: "Restart Steam to update its list of compatibility tools.")

    private func runnerOutcome(_ result: RunnerSetup.Outcome) -> String {
        if result.stagedNothing { return String(localized: "Compatibility tool is already set up.") }
        guard result.toolsChanged, SteamBundle.isRunning else { return String(localized: "Compatibility tool ready.") }
        return String(localized: "Compatibility tool ready. \(Self.toolsRestartHint)")
    }

    func perform(
        from first: String,
        _ body: (_ progress: @escaping @Sendable (String) -> Void) async throws -> String?
    ) async {
        guard !runInFlight else {
            AppLog.note("run refused: '\(first)' overlaps a run already in flight")
            return
        }
        runInFlight = true
        defer { runInFlight = false }

        clearFailure()
        outcome = nil
        let run = beginRun(first)
        defer { endRun() }

        do {
            outcome = try await body { label in
                Task { @MainActor in self.report(run, label) }
            }
        } catch {
            record(error)
        }

        await refreshAfterRun(self)
    }

    func setUpHighball(_ engine: HighballEngine, replacingExisting: Bool = false) async {
        await perform(from: RunnerSetup.Phase.cloning.label) { progress in
            let lock = try DeploymentContent.acquireInstallationLock()
            defer { lock.release() }
            try await requireInstallableContent()
            let result = try await Task.detached(priority: .userInitiated) {
                try RunnerSetup.run(from: engine, replacingExisting: replacingExisting) {
                    progress($0.label)
                }
            }.value

            return runnerOutcome(result) + adoptHighballAsDefault()
        }
    }

    // Option C: Highball becomes Steam's default for Windows games only when Steam has no default
    private func adoptHighballAsDefault() -> String {
        guard DefaultTool.shouldAdopt(request: DefaultTool.request(), steamDefault: DefaultTool.steamDefault()),
              let tool = DefaultTool.highballTool(installed: RunnerStore.installedBuilds()),
              (try? DefaultTool.set(tool)) != nil else { return "" }
        return " " + String(localized: "Highball is now Steam's default for Windows games.")
    }

    func setDefaultTool(on wanted: Bool) async {
        await perform(from: DefaultTool.step) { _ in
            if wanted {
                guard let tool = DefaultTool.highballTool(installed: RunnerStore.installedBuilds()) else {
                    throw StepFailure(step: DefaultTool.step, detail: String(localized: "Set up the Highball engine first."))
                }
                try DefaultTool.set(tool)
                return String(localized: "Highball is Steam's default for Windows games from the next Steam start.")
            }
            try DefaultTool.clear()
            return String(localized: "Steam's default tool is cleared at the next Steam start.")
        }
    }

    // Downloads the engine with Highball's own code, then sets it up like a found engine
    func downloadHighballEngine(acceptD3DMetal: Bool) async {
        await perform(from: HighballInstaller.step) { progress in
            guard let build = HighballInstaller.build else {
                throw StepFailure(step: HighballInstaller.step,
                                  detail: String(localized: "This build of Neutron supports no Highball engine."))
            }
            let payload = try InstallPayload.locate()
            try await HighballInstaller.run(
                helper: payload.highballEnv,
                arguments: HighballInstaller.arguments(manifest: HighballInstaller.manifest(in: payload, build: build),
                                                       acceptD3DMetal: acceptD3DMetal),
                progress: progress)
            guard let engine = HighballSource.discover().first(where: { $0.id == build.bundleVersion && $0.isUsable }) else {
                throw StepFailure(step: HighballInstaller.step,
                                  detail: String(localized: "The engine downloaded, but Neutron cannot use it. Open Neutron's log for details."))
            }
            let lock = try DeploymentContent.acquireInstallationLock()
            defer { lock.release() }
            do {
                try await requireInstallableContent()
            } catch {
                return String(localized: "Highball engine downloaded. Click Install, then Set Up next to the engine.")
            }
            let result = try await Task.detached(priority: .userInitiated) {
                try RunnerSetup.run(from: engine) { progress($0.label) }
            }.value
            return runnerOutcome(result) + adoptHighballAsDefault()
        }
    }

    func enableD3DMetal(_ engine: HighballEngine) async {
        await perform(from: String(localized: "Enable D3DMetal")) { progress in
            let payload = try InstallPayload.locate()
            try await HighballInstaller.run(helper: payload.highballEnv,
                                            arguments: ["accept", "--engine", engine.id], progress: progress)
            do { try RendererList.sync() } catch { AppLog.note("renderer list not written: \(error)") }
            return String(localized: "D3DMetal is enabled for \(engine.displayName).")
        }
    }

    enum HighballCopy: Sendable, Equatable { case notSetUp, ready, needsRepair }

    nonisolated static func highballCopy(_ build: String, installed: [RunnerBuild], runner: RunnerState) -> HighballCopy {
        guard installed.contains(where: { $0.id == build }) else { return .notSetUp }
        if case .unpatched(let builds, _) = runner, builds.contains(build) { return .needsRepair }
        return .ready
    }

    // Copies left behind when their build is no longer supported, so they can still be removed
    nonisolated static func highballOrphans(_ orphaned: [String], runners: URL = SupportPaths.runners) -> [String] {
        orphaned.filter { SupportPaths.runtime(forBuild: $0, runners: runners) == .highball }
    }

    // What the Highball section says when no engine can be set up
    nonisolated static func highballNotice(engines: [HighballEngine]) -> String? {
        guard !engines.isEmpty, !engines.contains(where: \.isUsable) else { return nil }
        if let newer = engines.first(where: { $0.id.hasPrefix("x64-crossover") }) {
            return String(localized: "Highball engine \(newer.displayName) isn't supported yet.")
        }
        return String(localized: "Neutron needs Highball's Wine 11 engine. Switch an environment to Wine 11 in its settings in Highball.")
    }

    func fetchValveBinaries() async {
        guard canInstall else { return }
        await perform(from: ValveFetcher.Phase.verifying.label) { progress in
            let lock = try DeploymentContent.acquireInstallationLock()
            defer { lock.release() }
            try await requireInstallableContent()
            let result = try await ValveFetcher.run { progress($0.label) }
            return result.wroteNothing ? nil : String(localized: "Downloaded missing components.")
        }
    }

    private static let restartHint = String(localized: "Steam was stopped, so start it again.")

    private func requireInstallableContent() async throws {
        try await requireUnblockedContent()
        let running = await Task.detached(priority: .utility) {
            RunnerStore.clonedBuilds().contains {
                RunnerInstaller.isRunning(from: SupportPaths.runnerRoot(forBuild: $0))
            }
        }.value
        guard !running else {
            throw StepFailure(step: SteamInstaller.step, detail: String(localized: "A game or Wine tool is running. Quit it before updating Neutron."))
        }
    }

    private func requireUnblockedContent() async throws {
        let version = AppVersion.bundled
        let content = await Task.detached(priority: .utility) {
            DeploymentContent.current(version: version)
        }.value
        snapshot?.installContent = content
        guard !content.blocksInstallation else {
            throw StepFailure(step: SteamInstaller.step,
                              detail: String(localized: "Installation is blocked. Refresh Status and use the Neutron app that installed this build."))
        }
    }

    func installIntoSteam() async {
        await perform(from: InstallPhase.checkingPayload.label) { progress in
            let lock = try DeploymentContent.acquireInstallationLock()
            defer { lock.release() }
            let result = try await Task.detached(priority: .userInitiated) {
                try SteamInstaller.run(holdingInstallationLock: true, report: { progress($0.label) })
            }.value

            var parts = [String(localized: "Neutron successfully installed.")]
            if result.stoppedClient { parts.append(Self.restartHint) }
            // Fetch binaries from Valve
            let valve = try ValvePackageManifest.bundled()
            let needsValve = await Task.detached(priority: .utility) {
                valve.files.contains { Digest.sha256IfPresent(SupportPaths.bridge.appending(path: $0.bridgePath)) != $0.sha256 }
            }.value
            if needsValve {
                progress(String(localized: "Downloading missing components"))
                _ = try await ValveFetcher.run { progress($0.label) }
            }

            try await Task.detached(priority: .userInitiated) {
                try SteamInstaller.finish(result)
            }.value

            return parts.joined(separator: " ")
        }
    }

    func setUpdateBlock(_ blocked: Bool) async {
        await perform(from: blocked ? String(localized: "Blocking Steam client updates")
                                    : String(localized: "Allowing Steam client updates")) { _ in
            if blocked {
                try UpdateBlock.write()
                return String(localized: "Steam client updates are blocked.")
            }

            try UpdateBlock.remove()
            return String(localized: "Steam client updates are allowed.")
        }
    }

    func repairSteam() async {
        await perform(from: RepairPhase.checking.label) { progress in
            let lock = try DeploymentContent.acquireInstallationLock()
            defer { lock.release() }
            let result = try await SteamRepair.run(report: { progress($0.label) })

            var parts = [String(localized: "Steam restored to its original state.")]
            if result.stoppedClient { parts.append(Self.restartHint) }
            return parts.joined(separator: " ")
        }
    }

    func resetControllerPermission() async {
        await perform(from: String(localized: "Resetting Steam's controller permission")) { _ in
            let failed = SteamInstaller.failedInputAccessResets()
            guard failed.isEmpty else {
                throw StepFailure(
                    step: String(localized: "Reset controller permission"),
                    detail: String(localized: "macOS did not reset \(failed.joined(separator: ", ")) for Steam.")
                )
            }
            return SteamBundle.isRunning
                ? String(localized: "Controller permission reset. Restart Steam so macOS asks again.")
                : String(localized: "Controller permission reset. macOS asks again when Steam starts.")
        }
    }

    func removeEverything() async {
        await perform(from: UninstallPhase.stoppingClient.label) { progress in
            let result = try await Uninstall.run { progress($0.label) }

            if let partial = result.partialRemoval { return partial }
            return result.steamNeedsRedownload
                ? String(localized: "Neutron has been removed. Steam could not be restored. Reinstall Steam from steampowered.com before using it again.")
                : String(localized: "Neutron has been removed.")
        }
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        let version = AppVersion.bundled
        let captured = await Task.detached(priority: .userInitiated) {
            StatusSnapshot.capture(bundledVersion: version)
        }.value
        snapshot = captured
        AppLog.note(captured)
        await refreshRunnerStorage(cleanTemplates: !captured.installContent.blocksInstallation)
    }

    private(set) var runnerSizes: [String: Int64] = [:]
    private(set) var templateSizes: [String: [CompatTool.Flavor: Int64]] = [:]
    private(set) var templateCleanupFailure: String?
    private(set) var bridgeCopyBytes: Int64 = 0

    func refreshRunnerStorage(
        runners: URL = SupportPaths.runners, libraries: [SteamLibrary] = PrefixStore.libraries(),
        cleanTemplates: Bool = true,
        acquireInstallationLock: @escaping @Sendable () throws -> DeploymentContent.InstallationLock = {
            try DeploymentContent.acquireInstallationLock()
        }
    ) async {
        let known = runnerSizes
        let measured = await Task.detached(priority: .utility) {
            let failures: [StepFailure]
            if cleanTemplates, let lock = try? acquireInstallationLock() {
                defer { lock.release() }
                RunnerInstaller.removeLeftoverRemovals(runners: runners)
                failures = RunnerInstaller.removeStalePrefixTemplates(
                    runners: runners, libraries: libraries, reportBusy: false)
            } else {
                failures = []
            }
            var sizes: [String: Int64] = [:]
            var templates: [String: [CompatTool.Flavor: Int64]] = [:]
            let bridgeCopies = libraries.reduce(Int64(0)) { total, library in
                let folder = library.compatdata.appending(path: SupportPaths.prefixTemplateFolder)
                var info = stat()
                guard lstat(folder.path(percentEncoded: false), &info) == 0,
                    info.st_mode & S_IFMT == S_IFDIR else { return total }
                return total + PrefixStore.directoryBytes(
                    folder.appending(path: SupportPaths.bridgeCacheFolder), metric: .allocated)
            }
            for build in RunnerStore.clonedBuilds(in: runners) {
                sizes[build] = known[build] ?? RunnerStore.cloneSize(forBuild: build, runners: runners)
                templates[build] = libraries.reduce(into: [:]) { totals, library in
                    let folder = library.compatdata.appending(path: SupportPaths.prefixTemplateFolder)
                    var info = stat()
                    guard lstat(folder.path(percentEncoded: false), &info) == 0,
                        info.st_mode & S_IFMT == S_IFDIR else { return }
                    for flavor in CompatTool.Flavor.allCases {
                        let template = SupportPaths.prefixTemplate(forBuild: build, flavor: flavor, in: library)
                        totals[flavor, default: 0] += PrefixStore.directoryBytes(template, metric: .allocated)
                    }
                }
            }
            return (sizes, templates, failures, bridgeCopies)
        }.value
        runnerSizes = measured.0
        templateSizes = measured.1
        templateCleanupFailure = measured.2.isEmpty ? nil : measured.2.map(\.detail).joined(separator: "\n")
        bridgeCopyBytes = measured.3
    }
}
