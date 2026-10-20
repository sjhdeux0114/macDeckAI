import Foundation

/// Explicitly installed Epic-only routers. Steam binaries/maps are never modified.
struct EpicRendererSupport {
    static let hogwartsID = "fa4240e57a3c46b39f169041b7811293"
    let disk: LibraryDisk
    var prefix: URL { EpicClient(disk: disk).prefix }
    var marker: URL { prefix.appendingPathComponent("drive_c/ProgramData/MacDeck/epic-renderers.json") }
    var managed: Bool { FileManager.default.fileExists(atPath: marker.path) }
    static func executableRules(id: String, prefix: URL) throws -> String {
        let file = prefix.appendingPathComponent("drive_c/ProgramData/MacDeck/renderers.ini")
        let text = try String(contentsOf: file, encoding: .utf16)
        var section = "", rules: [String] = []
        for raw in text.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.hasPrefix("[") { section = line.lowercased(); continue }
            if ["[epic-paths]", "[epic-secondary-paths]"].contains(section), line.hasPrefix(id + "=") { rules.append(section + line) }
        }
        return rules.sorted().joined(separator: "\n")
    }
    static func map(games: [Game], profiles: [GameProfile], runtime: URL) throws -> String {
        var renderers = "", paths = "", secondary = ""
        func windows(_ path: String) -> String {
            "Z:" + URL(fileURLWithPath: path).resolvingSymlinksInPath().standardizedFileURL.path.replacingOccurrences(of: "/", with: "\\")
        }
        for game in games {
            guard game.epicAppID == hogwartsID,
                  profiles.contains(where: { $0.id == "epic:" + hogwartsID && $0.epicMetalFix == true }),
                  let location = game.installedLocation else { continue }
            for value in [game.path, location] {
                guard !value.contains("\n"), !value.contains("\r"), !value.contains("=") else { throw DeckError.message("Epic 실행 경로 형식을 확인하세요.") }
            }
            renderers += hogwartsID + "=metal\r\n"
            paths += hogwartsID + "=" + windows(game.path) + "\r\n"
            let shipping = URL(fileURLWithPath: location).appendingPathComponent("Phoenix/Binaries/Win64/HogwartsLegacy.exe")
            secondary += hogwartsID + "=" + windows(shipping.path) + "\r\n"
        }
        return "[runtime]\r\ndllDirectory=" + windows(runtime.appendingPathComponent("lib/wine/x86_64-windows").path)
            + "\r\n[renderers]\r\ndefault=dxmt\r\n0=dxmt\r\n" + renderers
            + "[epic-paths]\r\n" + paths + "[epic-secondary-paths]\r\n" + secondary
    }
    func configure(wine: String, environment: inout [String: String]) throws {
        guard managed, environment["WINEPREFIX"] == prefix.path else { return }
        let runtime = URL(fileURLWithPath: wine).deletingLastPathComponent().deletingLastPathComponent()
        let expected = try String(contentsOf: marker, encoding: .utf8)
        guard expected == runtime.path else { throw DeckError.message("Epic Metal 시험 런타임이 달라졌습니다. 기존 후보를 덮어쓰지 않고 실행을 중단했습니다.") }
        let modules = Set(SharedSteamRuntime.modules)
        var groups = environment["WINEDLLOVERRIDES", default: ""].split(separator: ";").compactMap { group -> String? in
            let pair = group.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard pair.count == 2 else { return String(group) }
            let names = pair[0].split(separator: ",").filter { !modules.contains(String($0)) }
            return names.isEmpty ? nil : names.joined(separator: ",") + "=" + pair[1]
        }
        groups.append("dxgi,d3d11,d3d12,d3d12core=n,b")
        environment["WINEDLLOVERRIDES"] = groups.joined(separator: ";")
        environment["DYLD_FALLBACK_LIBRARY_PATH", default: ""] += ":" + runtime.appendingPathComponent("lib/external").path
        environment["DYLD_FRAMEWORK_PATH"] = runtime.appendingPathComponent("lib/external").path
        environment["D3DMETAL_FRAMEWORK_PATH"] = runtime.appendingPathComponent("lib/external/D3DMetal.framework/D3DMetal").path
        environment["D3DM_MTL4"] = "0"
        environment["WINEMSYNC"] = "1"; environment["WINEESYNC"] = "0"
    }
    func prepare(wine: String, routers: URL) async throws {
        guard !managed else { throw DeckError.message("Epic 선택기가 이미 있습니다. 기존 파일을 자동 교체하지 않습니다.") }
        let runtime = URL(fileURLWithPath: wine).deletingLastPathComponent().deletingLastPathComponent()
        try await DependencyInstaller(disk: disk, prefix: prefix, wine: wine).assertIdlePrefix()
        for name in SharedSteamRuntime.modules {
            for file in [routers.appendingPathComponent(name + ".dll"), runtime.appendingPathComponent("lib/wine/x86_64-windows/macdeck_metal_" + name + ".dll"), runtime.appendingPathComponent("lib/wine/x86_64-windows/macdeck_dxmt_" + name + ".dll")] {
                // DXMT D3D12 uses VKD3D aliases instead.
                if file.lastPathComponent.hasPrefix("macdeck_dxmt_d3d12") { continue }
                guard FileManager.default.fileExists(atPath: file.path) else { throw DeckError.message("Epic Metal 후보 누락: " + file.lastPathComponent) }
            }
        }
        let backup = disk.root.appendingPathComponent("Compatibility/Repairs/epic-metal-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: backup, withIntermediateDirectories: true)
        let mapFile = prefix.appendingPathComponent("drive_c/ProgramData/MacDeck/renderers.ini")
        let targets = SharedSteamRuntime.modules.map { prefix.appendingPathComponent("drive_c/windows/system32/" + $0 + ".dll") } + [mapFile]
        let originals = try targets.map { FileManager.default.fileExists(atPath: $0.path) ? try Data(contentsOf: $0) : nil }
        for (index, bytes) in originals.enumerated() { if let bytes { try bytes.write(to: backup.appendingPathComponent(String(index) + "-" + targets[index].lastPathComponent)) } }
        try JSONEncoder().encode(targets.map(\.path)).write(to: backup.appendingPathComponent("targets.json"))
        do {
            for name in SharedSteamRuntime.modules { try Data(contentsOf: routers.appendingPathComponent(name + ".dll")).write(to: prefix.appendingPathComponent("drive_c/windows/system32/" + name + ".dll"), options: .atomic) }
            try FileManager.default.createDirectory(at: mapFile.deletingLastPathComponent(), withIntermediateDirectories: true)
            let content = try Self.map(games: EpicClient(disk: disk).installedGames(), profiles: GameProfileStore(disk: disk).load().games, runtime: runtime)
            try content.data(using: .utf16)!.write(to: mapFile, options: .atomic)
            try Data(runtime.path.utf8).write(to: marker, options: .atomic)
        } catch {
            for (index, bytes) in originals.enumerated() {
                if let bytes { try? bytes.write(to: targets[index], options: .atomic) }
                else { try? FileManager.default.removeItem(at: targets[index]) }
            }
            throw error
        }
    }
}
