import Foundation
import Testing

@testable import NotProtonApp

@Suite("Steam's default tool")
struct DefaultToolTests {

    @Test("A request file reads as its first line; no file is no request")
    func requestParsing() throws {
        let work = try scratchDirectory("default-tool")
        defer { try? FileManager.default.removeItem(at: work) }
        let file = work.appending(path: "default-tool")
        #expect(DefaultTool.request(at: file) == nil)
        try DefaultTool.set("neutron-proton-highball-x64-crossover26.3-r19", at: file)
        #expect(DefaultTool.request(at: file) == "neutron-proton-highball-x64-crossover26.3-r19")
        try DefaultTool.clear(at: file)
        #expect(DefaultTool.request(at: file) == "")
    }

    @Test("Steam's recorded default distinguishes none from not yet known")
    func steamDefault() throws {
        let work = try scratchDirectory("steam-default")
        defer { try? FileManager.default.removeItem(at: work) }
        let file = work.appending(path: "steam-default-tool")
        #expect(DefaultTool.steamDefault(at: file) == nil)
        try Data("\n".utf8).write(to: file)
        #expect(DefaultTool.steamDefault(at: file) == "")
        try Data("proton_9\n".utf8).write(to: file)
        #expect(DefaultTool.steamDefault(at: file) == "proton_9")
    }

    @Test("Highball is adopted as the default only when Steam has none and nothing was asked yet",
          arguments: [
            (nil, "", true), (nil, "proton_9", false), (nil, nil, false),
            ("", "", false), ("neutron-proton-highball-x64-crossover26.3-r19", "", false),
          ] as [(String?, String?, Bool)])
    func adoption(request: String?, steamDefault: String?, adopt: Bool) {
        #expect(DefaultTool.shouldAdopt(request: request, steamDefault: steamDefault) == adopt)
    }

    @Test("The Highball tool name comes from the installed Highball build")
    func highballTool() {
        let builds = SupportedRunners.all.filter { $0.runtime == .highball }
        #expect(DefaultTool.highballTool(installed: builds) == "neutron-proton-highball-x64-crossover26.3-r19")
        #expect(DefaultTool.highballTool(installed: []) == nil)
    }

    @Test("Alpha-5 Highball requests and recorded defaults migrate without changing off or foreign choices")
    func legacyHighballRequest() throws {
        let work = try scratchDirectory("cloud-default-migration")
        defer { try? FileManager.default.removeItem(at: work) }
        let file = work.appending(path: "default-tool")
        try Data("neutron-highball-x64-crossover26.3-r19\n".utf8).write(to: file)
        let current = "neutron-proton-highball-x64-crossover26.3-r19"
        #expect(DefaultTool.request(at: file) == current)
        #expect(DefaultTool.steamDefault(at: file) == current)
        for choice in ["", "proton_9", "neutron-highball-other"] {
            #expect(SupportedRunners.migratedToolName(choice) == choice)
        }
    }

    @Test("Only Neutron's own tools count as ours")
    func ours() {
        #expect(DefaultTool.isOurs("neutron-26.3"))
        #expect(!DefaultTool.isOurs("proton_9"))
    }
}
