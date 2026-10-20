import Foundation

enum GameKind: String, Codable {
    case windows, macApp, executable
    var label: String {
        switch self { case .windows: return "WINDOWS"; case .macApp, .executable: return "MACOS" }
    }
}

enum GraphicsBackend: String, Codable, CaseIterable {
    case dxmt, d3d12

    var shortLabel: String {
        switch self {
        case .dxmt: return "DX11 Mode"
        case .d3d12: return "DX12 Mode"
        }
    }

    var label: String {
        switch self {
        case .dxmt: return "DX11 Mode (DXMT → Metal · 기본 권장)"
        case .d3d12: return "DX12 Mode (VKD3D · MoltenVK → Metal · 실험적)"
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = (try? container.decode(String.self)) ?? "dxmt"
        switch raw {
        case "d3d12", "dx12": self = .d3d12
        default: self = .dxmt
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

struct Game: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String
    var path: String
    var kind: GameKind
    var arguments: [String] = []
    var prefix: String? = nil
    var lastPlayed: Date? = nil
    var added: Date = Date()
    var steamAppID: String? = nil
    var epicAppID: String? = nil
    var installedLocation: String? = nil
    var graphicsBackend: GraphicsBackend? = nil
    var runtimePath: String? = nil
    var trialAppID: String? = nil

    static func importing(_ url: URL) throws -> Game {
        let path = url.standardizedFileURL.path
        guard FileManager.default.fileExists(atPath: path) else { throw DeckError.message("파일을 찾을 수 없습니다.") }
        let kind: GameKind
        if url.pathExtension.lowercased() == "app" {
            guard Bundle(url: url)?.executableURL != nil else { throw DeckError.message("실행 가능한 macOS 앱 번들이 아닙니다.") }
            kind = .macApp
        } else if url.pathExtension.lowercased() == "exe" {
            let file = try FileHandle(forReadingFrom: url)
            defer { try? file.close() }
            guard try file.read(upToCount: 2) == Data([0x4d, 0x5a]) else { throw DeckError.message("Windows 실행 파일의 MZ 헤더가 없습니다.") }
            kind = .windows
        } else {
            guard FileManager.default.isExecutableFile(atPath: path) else { throw DeckError.message(".app, .exe 또는 실행 권한이 있는 파일을 선택해 주세요.") }
            kind = .executable
        }
        return Game(name: url.deletingPathExtension().lastPathComponent, path: path, kind: kind)
    }
}

enum DirectX12Support {
    static let wineNativeMarker = Data("Wine native  DLL".utf8)
    static let wineBuiltinMarker = Data("Wine builtin DLL".utf8)
    private static let excludedFolders: Set<String> = ["_commonredist", "redist", "directx", "installers", "vc", "vcredist", "support", "crashreporter"]

    static func runtimeRoot(forWine winePath: String?) -> URL? {
        if let winePath, !winePath.isEmpty {
            let root = URL(fileURLWithPath: winePath).resolvingSymlinksInPath()
                .deletingLastPathComponent().deletingLastPathComponent()
            if FileManager.default.fileExists(atPath: root.appendingPathComponent("lib/wine").path) {
                return root
            }
        }
        if let resources = Bundle.main.resourceURL {
            let bundled = resources.appendingPathComponent("Runtime")
            if FileManager.default.fileExists(atPath: bundled.appendingPathComponent("lib/wine").path) {
                return bundled
            }
        }
        return nil
    }

    static func targetDirectory(for game: Game) -> URL? {
        guard game.kind == .windows else { return nil }
        if let installed = game.installedLocation, !installed.isEmpty {
            return URL(fileURLWithPath: installed, isDirectory: true)
        }
        let exeURL = URL(fileURLWithPath: game.path)
        let name = exeURL.lastPathComponent.lowercased()
        if name == "steam.exe" || name == "control.exe" || name == "steamsetup.exe" { return nil }
        return exeURL.deletingLastPathComponent()
    }

    static func is32BitWindowsBinary(at url: URL) -> Bool {
        guard let file = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? file.close() }
        guard let mz = try? file.read(upToCount: 0x40), mz.count >= 0x40, mz.prefix(2) == Data([0x4d, 0x5a]) else { return false }
        let peOffset = Int(mz[0x3c]) | (Int(mz[0x3d]) << 8) | (Int(mz[0x3e]) << 16) | (Int(mz[0x3f]) << 24)
        guard peOffset >= 0x40 && peOffset < 0x10000 else { return false }
        try? file.seek(toOffset: UInt64(peOffset))
        guard let peHeader = try? file.read(upToCount: 6), peHeader.count >= 6, peHeader.prefix(4) == Data([0x50, 0x45, 0x00, 0x00]) else { return false }
        let machine = UInt16(peHeader[4]) | (UInt16(peHeader[5]) << 8)
        return machine == 0x014c // IMAGE_FILE_MACHINE_I386
    }

    static func executableDirectories(in root: URL) -> [URL] {
        guard FileManager.default.fileExists(atPath: root.path) else { return [] }
        var result: [URL] = [root.standardizedFileURL]
        func scan(_ folder: URL, depth: Int) {
            guard depth <= 3, let items = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else { return }
            var hasExe = false
            for item in items {
                let ext = item.pathExtension.lowercased()
                if ext == "exe" { hasExe = true }
                else if (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true,
                        !excludedFolders.contains(item.lastPathComponent.lowercased()) {
                    scan(item, depth: depth + 1)
                }
            }
            let std = folder.standardizedFileURL
            if hasExe && !result.contains(std) { result.append(std) }
        }
        scan(root, depth: 0)
        return result
    }

    static func isManagedDXGI(_ url: URL) -> Bool {
        guard FileManager.default.fileExists(atPath: url.path),
              let handle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? handle.close() }
        guard let header = try? handle.read(upToCount: 512) else { return false }
        return header.range(of: wineNativeMarker) != nil || header.range(of: wineBuiltinMarker) != nil
    }

    static func syncPrefix(_ prefix: URL, mode: GraphicsBackend, runtimeRoot: URL?) {
        if FileManager.default.fileExists(atPath: prefix.appendingPathComponent("drive_c/ProgramData/MacDeck/epic-renderers.json").path) { return }
        if let root = runtimeRoot, SharedSteamRuntime.isRuntime(root.appendingPathComponent("bin/wine").path) { return }
        let sysReg = prefix.appendingPathComponent("system.reg")
        if let regText = try? String(contentsOf: sysReg, encoding: .utf8) {
            var fixed = regText
            if fixed.contains("[Software\\\\Microsoft\\\\Windows NT\\\\CurrentVersion\\\\AeDebug]") && fixed.contains("\"Auto\"=\"0\"") {
                fixed = fixed.replacingOccurrences(of: "\"Auto\"=\"0\"", with: "\"Auto\"=\"1\"")
            }
            if fixed != regText {
                try? fixed.write(to: sysReg, atomically: true, encoding: .utf8)
            }
        }
        let userReg = prefix.appendingPathComponent("user.reg")
        if let regText = try? String(contentsOf: userReg, encoding: .utf8) {
            var updated = regText
            if !updated.contains("\"VideoMemorySize\"") {
                updated += "\n[Software\\\\Wine\\\\Direct3D]\n\"VideoMemorySize\"=\"2048\"\n"
            }
            if !updated.contains("\"EnableGameOverlay\"") {
                updated += "\n[Software\\\\Valve\\\\Steam]\n\"EnableGameOverlay\"=dword:00000000\n"
            }
            if !updated.contains("\"gameoverlayrenderer\"") {
                updated += "\n[Software\\\\Wine\\\\DllOverrides]\n\"gameoverlayrenderer\"=\"\"\n\"gameoverlayrenderer64\"=\"\"\n"
            }
            if updated != regText {
                try? updated.write(to: userReg, atomically: true, encoding: .utf8)
            }
        }
        guard let root = runtimeRoot else { return }
        let sourceFolder = mode == .d3d12 ? "dxgi-d3d12" : "dxgi-dxmt"
        let mappings: [(arch: String, winSubdir: String)] = [
            ("x86_64-windows", "drive_c/windows/system32"),
            ("i386-windows", "drive_c/windows/syswow64")
        ]
        for item in mappings {
            let winDir = prefix.appendingPathComponent(item.winSubdir, isDirectory: true)
            guard FileManager.default.fileExists(atPath: winDir.path) else { continue }
            let dxgiSource = root.appendingPathComponent("lib/wine/\(sourceFolder)/\(item.arch)/dxgi.dll")
            let fallbackDXGI = root.appendingPathComponent("lib/wine/\(item.arch)/dxgi.dll")
            let chosenDXGI = FileManager.default.fileExists(atPath: dxgiSource.path) ? dxgiSource : fallbackDXGI
            let targetDXGI = winDir.appendingPathComponent("dxgi.dll")
            if FileManager.default.fileExists(atPath: chosenDXGI.path),
               let bytes = try? Data(contentsOf: chosenDXGI),
               (try? Data(contentsOf: targetDXGI)) != bytes {
                try? bytes.write(to: targetDXGI, options: .atomic)
            }
            for dll in ["d3d9.dll", "d3d11.dll", "d3d10core.dll", "d3d12.dll", "d3d12core.dll", "winemetal.dll"] {
                let targetDLL = winDir.appendingPathComponent(dll)
                let srcDLL = root.appendingPathComponent("lib/wine/\(item.arch)/\(dll)")
                if FileManager.default.fileExists(atPath: srcDLL.path),
                   let bytes = try? Data(contentsOf: srcDLL),
                   (try? Data(contentsOf: targetDLL)) != bytes {
                    try? bytes.write(to: targetDLL, options: .atomic)
                }
            }
        }
    }

    @discardableResult
    static func applyGlobal(mode: GraphicsBackend, wine: String?, games: [Game] = [], disk: LibraryDisk = .standard) -> GraphicsBackend {
        if SharedSteamRuntime.isRuntime(wine) { return mode }
        let root = runtimeRoot(forWine: wine)
        if let root {
            let sourceFolder = mode == .d3d12 ? "dxgi-d3d12" : "dxgi-dxmt"
            for arch in ["x86_64-windows", "i386-windows"] {
                let source = root.appendingPathComponent("lib/wine/\(sourceFolder)/\(arch)/dxgi.dll")
                let target = root.appendingPathComponent("lib/wine/\(arch)/dxgi.dll")
                if FileManager.default.fileExists(atPath: source.path),
                   let bytes = try? Data(contentsOf: source),
                   (try? Data(contentsOf: target)) != bytes {
                    try? FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
                    try? bytes.write(to: target, options: .atomic)
                }
            }
        }
        var syncedPrefixes: Set<String> = []
        for game in games {
            if game.kind == .windows {
                let prefix = disk.prefix(for: game)
                let path = prefix.standardizedFileURL.path
                if syncedPrefixes.insert(path).inserted {
                    syncPrefix(prefix, mode: mode, runtimeRoot: root)
                }
            }

        }
        return mode
    }

    static func dllOverrides(for mode: GraphicsBackend) -> String {
        let d3d9Override = "d3d9=b;"
        let common = "winemenubuilder.exe=d;winedbg.exe=d;mshtml=;gameoverlayrenderer,gameoverlayrenderer64=d;"
            + "xinput1_1,xinput1_2,xinput1_3,xinput1_4,xinput9_1_0=b;"
            + "xaudio2_0,xaudio2_1,xaudio2_2,xaudio2_3,xaudio2_4,xaudio2_5,xaudio2_6,xaudio2_7,xaudio2_8,xaudio2_9,x3daudio1_0,x3daudio1_1,x3daudio1_2,x3daudio1_3,x3daudio1_4,x3daudio1_5,x3daudio1_6,x3daudio1_7=b;dsound=b;"
            + "mfplat,mfreadwrite,mf,mfmediaengine,winegstreamer=b;quartz,amstream=b;"
            + d3d9Override
        switch mode {
        case .dxmt:
            return common + "d3d11,dxgi,d3d10core,d3d12,d3d12core,vulkan-1,winevulkan,winemetal=b"
        case .d3d12:
            return common + "dxgi,d3d12,d3d12core,vulkan-1,winevulkan,d3d11,d3d10core,winemetal=b"
        }
    }
}

struct LibraryData: Codable {
    var version = 1
    var games: [Game] = []
    var winePath = ""
    var startSteamOnLaunch: Bool? = nil
    var steamGPUAcceleration: Bool? = nil
    var showMetalHUD: Bool? = nil
    var sharedSteamRenderer: Bool? = nil
    var externalLibraries: [ExternalLibrary]? = nil
    var graphicsBackend: GraphicsBackend? = nil
    var autoUpdateRuntime: Bool? = nil
}

enum DeckError: LocalizedError {
    case message(String)
    var errorDescription: String? { switch self { case .message(let text): return text } }
}

struct LibraryDisk {
    let root: URL
    var file: URL { root.appendingPathComponent("library.json") }
    var logs: URL { root.appendingPathComponent("Logs", isDirectory: true) }
    var bottles: URL { root.appendingPathComponent("Bottles", isDirectory: true) }

    static var standard: LibraryDisk {
        if let override = ProcessInfo.processInfo.environment["MACDECK_DATA_DIR"] {
            return LibraryDisk(root: URL(fileURLWithPath: override, isDirectory: true))
        }
        return LibraryDisk(root: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("MacDeck", isDirectory: true))
    }

    func load() throws -> LibraryData {
        guard FileManager.default.fileExists(atPath: file.path) else { return LibraryData() }
        let library = try JSONDecoder().decode(LibraryData.self, from: Data(contentsOf: file))
        guard library.version == 1 else { throw DeckError.message("이 라이브러리는 더 새로운 버전의 MacDeck에서 만들었습니다.") }
        guard Set(library.games.map(\.id)).count == library.games.count else { throw DeckError.message("라이브러리에 중복된 게임 ID가 있습니다.") }
        return library
    }

    func save(_ value: LibraryData) throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(value).write(to: file, options: .atomic)
    }

    func prefix(for game: Game) -> URL {
        if let path = game.prefix, !path.isEmpty { return URL(fileURLWithPath: path, isDirectory: true) }
        return bottles.appendingPathComponent(game.id.uuidString, isDirectory: true)
    }

    func preparePrefix(for game: Game) throws {
        let prefix = prefix(for: game)
        let fresh = !FileManager.default.fileExists(atPath: prefix.appendingPathComponent("system.reg").path)
        try FileManager.default.createDirectory(at: prefix, withIntermediateDirectories: true)
        if fresh {
            let user = prefix.appendingPathComponent("drive_c/users/" + NSUserName(), isDirectory: true)
            for name in ["Desktop", "Documents", "Downloads", "Music", "Pictures", "Videos"] {
                let folder = user.appendingPathComponent(name, isDirectory: true)
                if !FileManager.default.fileExists(atPath: folder.path) {
                    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                }
            }
        }
    }
}

struct LaunchPlan {
    var executable: URL
    var arguments: [String]
    var environment: [String: String]
    var workingDirectory: URL

    static func make(game: Game, wine: String?, disk: LibraryDisk, verifyProfile: Bool = true) throws -> LaunchPlan {
        let wine = game.runtimePath ?? wine
        guard FileManager.default.fileExists(atPath: game.path) else { throw DeckError.message("게임 파일이 이동되었거나 삭제되었습니다. 편집에서 경로를 다시 선택해 주세요.") }
        var environment = ProcessInfo.processInfo.environment
        let executable: URL
        var arguments = game.arguments
        if game.kind == .windows {
            guard let wine, FileManager.default.isExecutableFile(atPath: wine) else { throw DeckError.message("런타임 탭에서 macOS용 Wine 실행 파일을 선택해 주세요.") }
            let loaded = try? disk.load()
            let mode = game.graphicsBackend ?? loaded?.graphicsBackend ?? .dxmt
            // A prepared Apple trial owns its complete DLL/Unix bridge set.
            // Generic DXMT/DXGI switching would replace Apple's DXGI after import.
            let appleTrial = game.trialAppID == "1245620" && (try? GameTrial.load(id: "1245620", disk: disk)?.backend) == "Apple-D3DMetal"
            if !appleTrial { DirectX12Support.applyGlobal(mode: mode, wine: wine, games: [game], disk: disk) }
            executable = URL(fileURLWithPath: wine)
            if game.path.lowercased().hasSuffix(".msi") {
                arguments = ["msiexec", "/i", game.path] + game.arguments
            } else {
                arguments.insert(game.path, at: 0)
            }
            environment["WINEPREFIX"] = disk.prefix(for: game).path
            if let id = game.steamAppID, URL(fileURLWithPath: game.path).lastPathComponent.lowercased() != "steam.exe" {
                environment["SteamAppId"] = id; environment["SteamGameId"] = id
            }
            environment["WINEDEBUG"] = "-all,err+seh,warn+vkd3d,err+vkd3d,warn+vulkan,err+vulkan,warn+d3d,err+d3d,warn+d3d9,err+d3d9"
            if environment["MACDECK_TRACE_EXCEPTIONS"] == "1" {
                environment["WINEDEBUG", default: ""] += ",trace+seh,warn+mfplat,err+mfplat,warn+mfreadwrite,err+mfreadwrite,warn+mf,err+mf,warn+winegstreamer,err+winegstreamer,trace+mfreadwrite"
                environment["GST_DEBUG"] = "2"
                environment["GST_DEBUG_NO_COLOR"] = "1"
            }
            environment["WINEDLLOVERRIDES"] = DirectX12Support.dllOverrides(for: mode)
            environment["DYLD_FALLBACK_LIBRARY_PATH"] = URL(fileURLWithPath: wine).resolvingSymlinksInPath()
                .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("lib").path
            let media = URL(fileURLWithPath: wine).resolvingSymlinksInPath()
                .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Media")
            if FileManager.default.fileExists(atPath: media.appendingPathComponent("lib/libgstreamer-1.0.0.dylib").path) {
                environment["DYLD_FALLBACK_LIBRARY_PATH", default: ""] += ":" + media.appendingPathComponent("lib").path
                environment["GST_PLUGIN_SYSTEM_PATH_1_0"] = media.appendingPathComponent("lib/gstreamer-1.0").path
                environment["GST_PLUGIN_PATH_1_0"] = ""
                environment["GST_PLUGIN_SCANNER_1_0"] = media.appendingPathComponent("libexec/gstreamer-1.0/gst-plugin-scanner").path
                let userRegistry = disk.logs.appendingPathComponent("gst-registry-x86_64.bin")
                let bundledRegistry = media.appendingPathComponent("gst-registry.bin")
                if !FileManager.default.fileExists(atPath: userRegistry.path), FileManager.default.fileExists(atPath: bundledRegistry.path) {
                    try? FileManager.default.copyItem(at: bundledRegistry, to: userRegistry)
                }
                environment["GST_REGISTRY_1_0"] = userRegistry.path
            }
            // 32-bit WoW64 binaries require server waits to prevent sync crashes.
            // 64-bit binaries (including 64-bit Steam Big Picture and steamwebhelper)
            // utilize Mach-message MSync for high-performance multithreading and fluid UI.
            var is32Bit = DirectX12Support.is32BitWindowsBinary(at: URL(fileURLWithPath: game.path))
            if !is32Bit, let location = game.installedLocation {
                let dir = URL(fileURLWithPath: location)
                let executables = DirectX12Support.executableDirectories(in: dir)
                for exeDir in executables {
                    if let items = try? FileManager.default.contentsOfDirectory(at: exeDir, includingPropertiesForKeys: nil) {
                        for item in items where item.pathExtension.lowercased() == "exe" {
                            if DirectX12Support.is32BitWindowsBinary(at: item) {
                                is32Bit = true
                                break
                            }
                        }
                    }
                    if is32Bit { break }
                }
            }
            if is32Bit {
                environment["WINEMSYNC"] = "0"
                environment.removeValue(forKey: "WINEMSYNC_QLIMIT")
                environment["WINE_LARGE_ADDRESS_AWARE"] = "0"
            } else {
                environment["WINEMSYNC"] = "1"
                environment["WINEMSYNC_QLIMIT"] = "512"
                if game.path.lowercased().hasSuffix("steam.exe") && game.steamAppID == nil {
                    environment.removeValue(forKey: "WINE_LARGE_ADDRESS_AWARE")
                } else {
                    environment["WINE_LARGE_ADDRESS_AWARE"] = "1"
                }
            }
            // ESync caused spinning device-service threads in the local x86 trial.
            // Use Wine server waits when MSync is off; retain MSync for direct x64.
            environment["WINEESYNC"] = "0"
            environment["DXMT_LOG_LEVEL"] = "info"
            environment["DXMT_LOG_PATH"] = disk.logs.path
            environment["DXVK_LOG_PATH"] = disk.logs.path
            environment["DXVK_LOG_LEVEL"] = environment["DXVK_LOG_LEVEL"] ?? "info"
            // DO_NOT_WAIT workarounds are game-specific; preserve normal map semantics.
            environment["DXMT_CONFIG"] = environment["DXMT_CONFIG"] ?? "dxgi.handleAltTab=True"
            environment["WINE_D3D_CONFIG"] = "renderer=vulkan"
            let hudEnabled = loaded?.showMetalHUD ?? true
            environment["MTL_HUD_ENABLED"] = hudEnabled ? "1" : "0"
            environment["SDL_RENDER_DRIVER"] = "direct3d11"
            environment["SDL_VIDEO_MINIMIZE_ON_FOCUS_LOSS"] = "0"
            if mode == .d3d12 {
                // Surface device loss to the game. Continuing after a GPU timeout
                // left RE3 submitting invalid work and hanging on a black screen.
                environment["MVK_CONFIG_RESUME_LOST_DEVICE"] = "0"
                environment["MVK_CONFIG_USE_METAL_ARGUMENT_BUFFERS"] = "1"
                // Prefill requires application-side assumptions and conflicts with
                // update-after-bind. Do not fabricate feature levels or mix Wine
                // VKD3D and vkd3d-proton-specific workarounds globally.
                environment["MVK_CONFIG_PREFILL_METAL_COMMAND_BUFFERS"] = "0"
            }
        } else if game.kind == .executable {
            executable = URL(fileURLWithPath: game.path)
        } else {
            throw DeckError.message("macOS 앱 번들은 Launch Services로 실행해야 합니다.")
        }
        try GameTrial.configure(game: game, disk: disk, environment: &environment)
        try SharedSteamRuntime.configure(wine: wine ?? "", environment: &environment)
        try EpicRendererSupport(disk: disk).configure(wine: wine ?? "", environment: &environment)
        if let prefix = environment["WINEPREFIX"] { try DependencyInstaller.applyCLRPolicy(prefix: URL(fileURLWithPath: prefix), environment: &environment) }
        let profiles = GameProfileStore(disk: disk)
        try profiles.apply(game, environment: &environment)
        let plan = LaunchPlan(executable: executable, arguments: arguments, environment: environment,
                          workingDirectory: URL(fileURLWithPath: game.path).deletingLastPathComponent())
        if verifyProfile { try profiles.verify(game, plan: plan) }
        return plan
    }
}
