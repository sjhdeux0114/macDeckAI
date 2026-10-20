import Foundation

/// One Steam prefix and one Big Picture client; graphics selection happens in
/// the child process by exact numeric Steam App ID. No Steam account files read.
struct SharedSteamRuntime {
    struct State: Codable {
        var originalWine: String
        var savedFiles: [String: Bool] = [:]
    }
    static let modules = ["dxgi", "d3d11", "d3d12", "d3d12core"]
    struct RegistryValue: Codable { var key: String; var name: String; var value: String? }
    let disk: LibraryDisk
    var folder: URL { disk.root.appendingPathComponent("SharedSteamRenderer") }
    var runtime: URL { folder.appendingPathComponent("Runtime") }
    var wine: URL { runtime.appendingPathComponent("bin/wine") }
    var stateFile: URL { folder.appendingPathComponent("state.json") }
    var available: Bool { FileManager.default.isExecutableFile(atPath: wine.path) && FileManager.default.fileExists(atPath: stateFile.path) }
    static func isRuntime(_ wine: String?) -> Bool {
        guard let wine else { return false }
        return FileManager.default.fileExists(atPath: URL(fileURLWithPath: wine).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("macdeck-shared-renderer.marker").path)
    }
    func prepare(source: URL, routers: URL) async throws {
        let fm = FileManager.default
        guard !fm.fileExists(atPath: folder.path) else { throw DeckError.message("공통 렌더러 환경이 이미 있습니다. 원본을 덮어쓰지 않습니다.") }
        for name in Self.modules {
            guard fm.fileExists(atPath: routers.appendingPathComponent(name + ".dll").path) else { throw DeckError.message("공통 렌더러 선택기 누락: " + name) }
        }
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        let process = Process(); process.executableURL = URL(fileURLWithPath: "/bin/cp")
        process.arguments = ["-cR", source.path, runtime.path]; process.standardOutput = FileHandle.nullDevice; process.standardError = FileHandle.nullDevice
        try process.run()
        while process.isRunning { try await Task.sleep(nanoseconds: 100_000_000) }
        guard process.terminationStatus == 0 else { throw DeckError.message("공통 런타임 복제 실패") }
        let targets = runtime.appendingPathComponent("Renderers")
        try fm.createDirectory(at: targets, withIntermediateDirectories: true)
        for name in Self.modules { try fm.copyItem(at: routers.appendingPathComponent(name + ".dll"), to: targets.appendingPathComponent(name + ".dll")) }
        try Data(SteamClient(disk: disk).prefix.standardizedFileURL.path.utf8).write(to: runtime.appendingPathComponent("macdeck-shared-renderer.marker"))
        let state = State(originalWine: try disk.load().winePath)
        try JSONEncoder().encode(state).write(to: stateFile, options: .atomic)
    }
    func writeMap() throws {
        let root = SteamClient(disk: disk).prefix.appendingPathComponent("drive_c/ProgramData/MacDeck")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let directory = "Z:" + runtime.appendingPathComponent("lib/wine/x86_64-windows").path.replacingOccurrences(of: "/", with: "\\")
        let directory32 = "Z:" + runtime.appendingPathComponent("lib/wine/i386-windows").path.replacingOccurrences(of: "/", with: "\\")
        var content = "[runtime]\r\ndllDirectory=" + directory + "\r\ndllDirectory32=" + directory32 + "\r\n[renderers]\r\ndefault=metal\r\n0=dxmt\r\n"
        for profile in try GameProfileStore(disk: disk).load().games where profile.id.hasPrefix("steam:") && !profile.id.hasSuffix(":trial") {
            let id = String(profile.id.dropFirst(6))
            guard id.allSatisfy({ $0.isNumber }), let renderer = profile.steamRenderer else { continue }
            content += id + "=" + renderer.rawValue + "\r\n"
        }
        content += "[patches]\r\n"
        if try GameProfileStore(disk: disk).load().games.contains(where: { $0.id == "steam:601150" && $0.steamRenderer == .dxmt && $0.dxmtMarshalFix == true }) { content += "601150=gs-ts-v1\r\n" }
        if let dmc = try GameProfileStore(disk: disk).load().games.first(where: { $0.id == "steam:220440" && $0.dmcMetalFix == true }) { content += "220440=" + (dmc.dmcQueryYieldFix == true ? "dxmt-smooth-v5" : (dmc.dmcSrgbFix == true ? "dxmt-srgb-v4" : (dmc.dmcClearFix == true ? "dxmt-bind-v3" : "dxmt-v1"))) + "\r\n" }
        if let hmh = try GameProfileStore(disk: disk).load().games.first(where: { $0.id == "steam:214830" && $0.hmhMetalFix == true }) { content += "214830=" + (hmh.hmhClearFix == true ? "dxmt-clear-v2" : "dxmt-v1") + "\r\n" }
        content += "[yield]\r\n"
        for profile in try GameProfileStore(disk: disk).load().games where profile.id.hasPrefix("steam:") && !profile.id.hasSuffix(":trial") {
            let id = String(profile.id.dropFirst(6))
            guard id.allSatisfy({ $0.isNumber }), profile.d3d9YieldFix == true else { continue }
            content += id + "=true\r\n"
        }
        var bytes = Data([0xff, 0xfe]); bytes.append(content.data(using: .utf16LittleEndian)!)
        try bytes.write(to: root.appendingPathComponent("renderers.ini"), options: .atomic)
    }
    static func selection(appID: String?, prefix: URL) throws -> String {
        guard let id = appID else { return "dxmt" }
        let text = try String(contentsOf: prefix.appendingPathComponent("drive_c/ProgramData/MacDeck/renderers.ini"), encoding: .utf16)
        var selected: String?, fallback = "metal", inSection = false
        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("[") { inSection = trimmed.lowercased() == "[renderers]"; continue }
            guard inSection else { continue }
            let pair = trimmed.split(separator: "=", maxSplits: 1).map(String.init)
            guard pair.count == 2 else { continue }
            if pair[0] == "default" { fallback = pair[1] }
            if pair[0] == id { selected = pair[1] }
        }
        let result = selected ?? fallback
        guard SteamRenderer(rawValue: result) != nil else { throw DeckError.message("Steam 렌더러 맵의 선택값을 확인하세요.") }
        return result
    }
    static func dmcMetalPatch(prefix: URL) throws -> String? {
        let text = try String(contentsOf: prefix.appendingPathComponent("drive_c/ProgramData/MacDeck/renderers.ini"), encoding: .utf16)
        var patches = false
        for raw in text.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.hasPrefix("[") { patches = line.lowercased() == "[patches]" }
            else if patches && ["220440=dxmt-v1", "220440=dxmt-clear-v2", "220440=dxmt-bind-v3", "220440=dxmt-srgb-v4", "220440=dxmt-smooth-v5"].contains(line) { return String(line.dropFirst(7)) }
        }
        return nil
    }
    static func dmcMetalEnabled(prefix: URL) throws -> Bool { try dmcMetalPatch(prefix: prefix) != nil }
    static func hmhMetalPatch(prefix: URL) throws -> String? {
        let text = try String(contentsOf: prefix.appendingPathComponent("drive_c/ProgramData/MacDeck/renderers.ini"), encoding: .utf16)
        var patches = false
        for raw in text.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.hasPrefix("[") { patches = line.lowercased() == "[patches]" }
            else if patches && ["214830=dxmt-v1", "214830=dxmt-clear-v2"].contains(line) { return String(line.dropFirst(7)) }
        }
        return nil
    }
    static func hmhMetalEnabled(prefix: URL) throws -> Bool { try hmhMetalPatch(prefix: prefix) != nil }
    static func dmcClearEnabled(prefix: URL) throws -> Bool {
        try ["dxmt-clear-v2", "dxmt-bind-v3", "dxmt-srgb-v4", "dxmt-smooth-v5"].contains(dmcMetalPatch(prefix: prefix) ?? "")
    }
    static func d3d9YieldEnabled(prefix: URL, appID: String) throws -> Bool {
        let file = prefix.appendingPathComponent("drive_c/ProgramData/MacDeck/renderers.ini")
        guard FileManager.default.fileExists(atPath: file.path) else { return false }
        let text = try String(contentsOf: file, encoding: .utf16)
        var yieldSection = false
        for raw in text.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.hasPrefix("[") { yieldSection = line.lowercased() == "[yield]" }
            else if yieldSection && line == "\(appID)=true" { return true }
        }
        return false
    }
    static func component(appID: String?, module: String, prefix: URL, renderer: String) throws -> String {
        if appID == "601150", module == "d3d11", renderer == "dxmt" {
            let text = try String(contentsOf: prefix.appendingPathComponent("drive_c/ProgramData/MacDeck/renderers.ini"), encoding: .utf16)
            var patches = false
            for line in text.components(separatedBy: .newlines) {
                let line = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if line.hasPrefix("[") { patches = line.lowercased() == "[patches]" }
                else if patches && line == "601150=gs-ts-v1" { return "macdeck_dxmt_gsts_v1_d3d11.dll" }
            }
        }
        return "macdeck_" + renderer + "_" + module + ".dll"
    }
    func setEnabled(_ enabled: Bool) async throws {
        guard available else { throw DeckError.message("먼저 공통 렌더러 환경을 준비하세요.") }
        let storage = SteamStorage(client: SteamClient(disk: disk))
        guard !(try await storage.isRunning(wine: wine.path)) else { throw DeckError.message("게임과 Steam을 종료한 뒤 렌더러를 전환하세요. 강제 종료 후 자동 재실행하지 않습니다.") }
        let fm = FileManager.default, prefix = SteamClient(disk: disk).prefix
        var state = try JSONDecoder().decode(State.self, from: Data(contentsOf: stateFile))
        var library = try disk.load()
        let originalLibrary = library
        let targets = Self.modules.map { prefix.appendingPathComponent("drive_c/windows/system32/" + $0 + ".dll") }
            + [prefix.appendingPathComponent("drive_c/ProgramData/MacDeck/renderers.ini")]
        var snapshots: [URL: (Data?, String?)] = [:]
        for target in targets {
            snapshots[target] = (try? Data(contentsOf: target), try? fm.destinationOfSymbolicLink(atPath: target.path))
        }
        var complete = false
        defer {
            if !complete {
                for (target, original) in snapshots {
                    try? fm.removeItem(at: target)
                    if let link = original.1 { try? fm.createSymbolicLink(atPath: target.path, withDestinationPath: link) }
                    else if let bytes = original.0 { try? bytes.write(to: target, options: .atomic) }
                }
                try? disk.save(originalLibrary)
            }
        }
        if enabled {
            let backup = folder.appendingPathComponent("OriginalPrefixDLLs")
            try fm.createDirectory(at: backup, withIntermediateDirectories: true)
            for name in Self.modules {
                let file = name + ".dll", target = prefix.appendingPathComponent("drive_c/windows/system32/" + name + ".dll")
                if state.savedFiles[file] == nil {
                    state.savedFiles[file] = fm.fileExists(atPath: target.path)
                    if fm.fileExists(atPath: target.path) { try fm.copyItem(at: target, to: backup.appendingPathComponent(file)) }
                }
            }
            try JSONEncoder().encode(state).write(to: stateFile, options: .atomic)
            for name in Self.modules {
                let target = prefix.appendingPathComponent("drive_c/windows/system32/" + name + ".dll")
                if fm.fileExists(atPath: target.path) || (try? fm.destinationOfSymbolicLink(atPath: target.path)) != nil { try fm.removeItem(at: target) }
                try fm.copyItem(at: runtime.appendingPathComponent("Renderers/" + name + ".dll"), to: target)
            }
            try writeMap()
            library.winePath = wine.path
        } else {
            for (file, existed) in state.savedFiles {
                let target = prefix.appendingPathComponent("drive_c/windows/system32/" + file)
                if fm.fileExists(atPath: target.path) { try fm.removeItem(at: target) }
                if existed { try fm.copyItem(at: folder.appendingPathComponent("OriginalPrefixDLLs/" + file), to: target) }
            }
            library.winePath = state.originalWine
        }
        library.sharedSteamRenderer = enabled
        try disk.save(library)
        do { try await configureRegistry(enabled) }
        catch { if enabled { try? await configureRegistry(false) }; throw error }
        complete = true
    }
    private func registryCommand(_ arguments: [String], capture: Bool = false) async throws -> (Int32, String) {
        let process = Process(), pipe = Pipe()
        process.executableURL = wine; process.arguments = ["reg"] + arguments
        var env = ProcessInfo.processInfo.environment
        env["WINEPREFIX"] = SteamClient(disk: disk).prefix.path
        env["WINEDEBUG"] = "-all"; env["WINEMSYNC"] = "1"; env["WINEESYNC"] = "0"
        env["DYLD_FALLBACK_LIBRARY_PATH"] = runtime.appendingPathComponent("lib").path
        env["WINEDLLOVERRIDES"] = "winemenubuilder.exe=d;winedbg.exe=d"
        process.environment = env; process.standardError = FileHandle.nullDevice
        process.standardOutput = capture ? pipe.fileHandleForWriting : FileHandle.nullDevice
        try process.run()
        let deadline = Date().addingTimeInterval(20)
        while process.isRunning && Date() < deadline { try await Task.sleep(nanoseconds: 100_000_000) }
        guard !process.isRunning else { process.terminate(); throw DeckError.message("그래픽 레지스트리 처리 시간이 초과되었습니다.") }
        if capture {
            try? pipe.fileHandleForWriting.close()
            let bytes = try pipe.fileHandleForReading.read(upToCount: 65536) ?? Data()
            return (process.terminationStatus, String(decoding: bytes, as: UTF8.self))
        }
        return (process.terminationStatus, "")
    }
    private func configureRegistry(_ enabled: Bool) async throws {
        let backup = folder.appendingPathComponent("registry-backup.json")
        let global = "HKEY_CURRENT_USER\\Software\\Wine\\DllOverrides"
        let paths = [global, "HKEY_CURRENT_USER\\Software\\Wine\\AppDefaults\\steam.exe\\DllOverrides", "HKEY_CURRENT_USER\\Software\\Wine\\AppDefaults\\steamwebhelper.exe\\DllOverrides"]
        if enabled && !FileManager.default.fileExists(atPath: backup.path) {
            var values: [RegistryValue] = []
            for key in paths { for name in Self.modules {
                let result = try await registryCommand(["query", key, "/v", name], capture: true)
                let line = result.1.components(separatedBy: .newlines).first { $0.trimmingCharacters(in: .whitespaces).hasPrefix(name + " ") && $0.contains("REG_SZ") }
                let value = line.flatMap { $0.components(separatedBy: "REG_SZ").last?.trimmingCharacters(in: .whitespacesAndNewlines) }
                if result.0 == 0 && value == nil { throw DeckError.message("기존 DLL 설정 형식을 보존할 수 없습니다: " + name) }
                values.append(RegistryValue(key: key, name: name, value: value))
            } }
            try JSONEncoder().encode(values).write(to: backup, options: .atomic)
        }
        if enabled {
            for key in paths { for name in Self.modules {
                let result = try await registryCommand(["add", key, "/v", name, "/t", "REG_SZ", "/d", key == global ? "n,b" : "b", "/f"])
                guard result.0 == 0 else { throw DeckError.message("공통 그래픽 설정을 저장하지 못했습니다.") }
            } }
        } else if FileManager.default.fileExists(atPath: backup.path) {
            for entry in try JSONDecoder().decode([RegistryValue].self, from: Data(contentsOf: backup)) {
                let arguments = entry.value.map { ["add",entry.key,"/v",entry.name,"/t","REG_SZ","/d",$0,"/f"] } ?? ["delete",entry.key,"/v",entry.name,"/f"]
                let result = try await registryCommand(arguments)
                if entry.value != nil && result.0 != 0 { throw DeckError.message("원래 DLL 레지스트리 복구를 확인하세요.") }
            }
        }
    }
    static func configure(wine: String, environment: inout [String: String]) throws {
        guard isRuntime(wine) else { return }
        let root = URL(fileURLWithPath: wine).deletingLastPathComponent().deletingLastPathComponent()
        let expected = try String(contentsOf: root.appendingPathComponent("macdeck-shared-renderer.marker"), encoding: .utf8)
        guard environment["WINEPREFIX"] == expected else { return }
        guard FileManager.default.fileExists(atPath: URL(fileURLWithPath: expected).appendingPathComponent("drive_c/ProgramData/MacDeck/renderers.ini").path) else { throw DeckError.message("Steam 통합 렌더러 맵이 없습니다. 비교 모드를 다시 준비하세요.") }
        let graphics = Set(Self.modules)
        environment["WINEDLLOVERRIDES"] = DirectX12Support.dllOverrides(for: .dxmt).split(separator: ";").compactMap { group -> String? in
            let pair = group.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard pair.count == 2 else { return nil }
            let names = pair[0].split(separator: ",").map(String.init).filter { !graphics.contains($0) }
            return names.isEmpty ? nil : names.joined(separator: ",") + "=" + pair[1]
        }.joined(separator: ";")
        environment["WINE_LARGE_ADDRESS_AWARE"] = "1"
        environment["WINEMSYNC"] = "1"; environment["WINEESYNC"] = "0"
        environment["WINEMSYNC_QLIMIT"] = "512"; environment["D3DM_MTL4"] = "0"
        environment["DYLD_FALLBACK_LIBRARY_PATH", default: ""] += ":" + root.appendingPathComponent("lib/external").path
        environment["DYLD_FRAMEWORK_PATH"] = root.appendingPathComponent("lib/external").path
        environment["D3DMETAL_FRAMEWORK_PATH"] = root.appendingPathComponent("lib/external/D3DMetal.framework/D3DMetal").path
    }
}
