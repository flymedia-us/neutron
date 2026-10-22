import Foundation

// A denied App Management request is a setup prerequisite, not an installation
// failure. Remember only the requested action and target so a fresh process can
// retry once with the permission macOS has just granted.
struct SetupAccessRecovery {
    struct Request: Codable, Equatable, Sendable {
        enum Action: Codable, Equatable, Sendable {
            case setup(acceptD3DMetal: Bool)
            case install
        }

        let action: Action
        let steamPath: String

        init(_ action: Action, steam: URL = SupportPaths.Steam.app) {
            self.action = action
            steamPath = steam.standardizedFileURL.path(percentEncoded: false)
        }
    }

    let file: URL

    init(file: URL = SupportPaths.support.appending(path: "setup-access-recovery.json")) {
        self.file = file
    }

    func save(_ request: Request) throws {
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(request).write(to: file, options: .atomic)
    }

    func take() throws -> Request? {
        guard FileManager.default.fileExists(atPath: file.path(percentEncoded: false)) else { return nil }
        let request = try JSONDecoder().decode(Request.self, from: Data(contentsOf: file))
        try FileManager.default.removeItem(at: file)
        return request
    }

    func clear() throws {
        guard FileManager.default.fileExists(atPath: file.path(percentEncoded: false)) else { return }
        try FileManager.default.removeItem(at: file)
    }
}
