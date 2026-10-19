import Foundation

extension StatusSnapshot {
    var integrationReady: Bool {
        guard case .installed = steam, payload.isComplete else { return false }
        return installContent == .current
    }

    var engineReady: Bool {
        installedRunners.contains { build in
            build.runtime == .highball
                && SystemStatus.highballCopy(build.id, installed: installedRunners, runner: runner) == .ready
        }
    }

    var readyToPlay: Bool {
        integrationReady && engineReady && rosettaInstalled
            && (defaultToolRequest != nil || DefaultTool.isOurs(steamDefaultTool ?? ""))
    }

    var setupBlocked: Bool {
        if installContent.blocksInstallation { return true }
        switch steam {
        case .steamMissing, .foreign: return true
        default: return !rosettaInstalled
        }
    }
}
