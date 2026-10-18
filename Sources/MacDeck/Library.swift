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
    var installedLocation: String? = nil
    var graphicsBackend: GraphicsBackend? = nil

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

    static func syncGameDirectory(_ root: URL, mode: GraphicsBackend) {
        guard FileManager.default.fileExists(atPath: root.path) else { return }
        let dirs = executableDirectories(in: root)
        for dir in dirs {
            let deployedDXGI = dir.appendingPathComponent("dxgi.dll")
            if isManagedDXGI(deployedDXGI) {
                try? FileManager.default.removeItem(at: deployedDXGI)
            }
            guard let items = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else { continue }
            for item in items where item.pathExtension.lowercased() == "ini" {
                guard let content = try? String(contentsOf: item, encoding: .utf8) else { continue }
                var updated = content
                if mode == .dxmt {
                    updated = updated
                        .replacingOccurrences(of: "Capability=DirectX12", with: "Capability=DirectX11")
                        .replacingOccurrences(of: "TargetPlatform=DirectX12", with: "TargetPlatform=DirectX11")
                } else {
                    updated = updated
                        .replacingOccurrences(of: "Capability=DirectX11", with: "Capability=DirectX12")
                        .replacingOccurrences(of: "TargetPlatform=DirectX11", with: "TargetPlatform=DirectX12")
                }
                if updated != content {
                    try? updated.write(to: item, atomically: true, encoding: .utf8)
                }
            }
        }
    }

    static func syncPrefix(_ prefix: URL, mode: GraphicsBackend, runtimeRoot: URL?) {
        let sysReg = prefix.appendingPathComponent("system.reg")
        if let regText = try? String(contentsOf: sysReg, encoding: .utf8),
           regText.contains("[Software\\\\Microsoft\\\\Windows NT\\\\CurrentVersion\\\\AeDebug]") && regText.contains("\"Auto\"=\"0\"") {
            let fixed = regText.replacingOccurrences(of: "\"Auto\"=\"0\"", with: "\"Auto\"=\"1\"")
            if fixed != regText {
                try? fixed.write(to: sysReg, atomically: true, encoding: .utf8)
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
        if let bottleDirs = try? FileManager.default.contentsOfDirectory(at: disk.bottles, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) {
            for bottle in bottleDirs {
                let path = bottle.standardizedFileURL.path
                if syncedPrefixes.insert(path).inserted {
                    syncPrefix(bottle, mode: mode, runtimeRoot: root)
                }
            }
        }
        for game in games {
            if game.kind == .windows {
                let prefix = disk.prefix(for: game)
                let path = prefix.standardizedFileURL.path
                if syncedPrefixes.insert(path).inserted {
                    syncPrefix(prefix, mode: mode, runtimeRoot: root)
                }
            }
            if let dir = targetDirectory(for: game) {
                syncGameDirectory(dir, mode: mode)
            }
        }
        return mode
    }

    static func dllOverrides(for mode: GraphicsBackend) -> String {
        let common = "winemenubuilder.exe=d;winedbg.exe=d;mscoree,mshtml=;"
            + "UnityCrashHandler32.exe=d;UnityCrashHandler64.exe=d;"
            + "CrashReportClient.exe=d;CrashReportClientEditor.exe=d;"
            + "easyanticheat_x64=d;EasyAntiCheat=d;"
            + "xinput1_1,xinput1_2,xinput1_3,xinput1_4,xinput9_1_0=b;"
            + "dinput=b;dinput8=b;"
            + "d3dcompiler_43,d3dcompiler_47=b;"
            + "xaudio2_0,xaudio2_1,xaudio2_2,xaudio2_3,xaudio2_4,xaudio2_5,xaudio2_6,xaudio2_7,xaudio2_8,xaudio2_9,x3daudio1_0,x3daudio1_1,x3daudio1_2,x3daudio1_3,x3daudio1_4,x3daudio1_5,x3daudio1_6,x3daudio1_7=b;dsound=b;"
            + "mfplat,mfreadwrite,mf,mfmediaengine,winegstreamer=b;quartz,amstream=b;"
            + "nvapi,nvapi64,nvngx=_nvngx=d;"
            + "d3d9=n,b;"
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

    static func make(game: Game, wine: String?, disk: LibraryDisk) throws -> LaunchPlan {
        guard FileManager.default.fileExists(atPath: game.path) else { throw DeckError.message("게임 파일이 이동되었거나 삭제되었습니다. 편집에서 경로를 다시 선택해 주세요.") }
        var environment = ProcessInfo.processInfo.environment
        let executable: URL
        var arguments = game.arguments
        if game.kind == .windows {
            guard let wine, FileManager.default.isExecutableFile(atPath: wine) else { throw DeckError.message("런타임 탭에서 macOS용 Wine 실행 파일을 선택해 주세요.") }
            let loaded = try? disk.load()
            let mode = loaded?.graphicsBackend ?? game.graphicsBackend ?? .dxmt
            DirectX12Support.applyGlobal(mode: mode, wine: wine, games: (loaded?.games ?? []) + [game], disk: disk)
            executable = URL(fileURLWithPath: wine)
            arguments.insert(game.path, at: 0)
            environment["WINEPREFIX"] = disk.prefix(for: game).path
            environment["WINEDEBUG"] = "-all,warn+vkd3d,err+vkd3d,warn+vulkan,err+vulkan"
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
            environment["WINEMSYNC"] = "1"
            environment["WINEESYNC"] = "1"
            environment["WINEMSYNC_QLIMIT"] = "512"
            environment["WINE_LARGE_ADDRESS_AWARE"] = "1"
            environment["DXMT_LOG_LEVEL"] = "info"
            environment["DXMT_LOG_PATH"] = disk.logs.path
            environment["DXMT_CONFIG"] = "d3d11.ignoreMapFlagNoWait=True;dxgi.handleAltTab=True;d3d11.maxTessFactor=64"
            environment["DXVK_LOG_LEVEL"] = "none"
            environment["DXVK_LOG_PATH"] = disk.logs.path
            let hudEnabled = loaded?.showMetalHUD ?? true
            environment["MTL_HUD_ENABLED"] = hudEnabled ? "1" : "0"
            environment["SDL_RENDER_DRIVER"] = "direct3d11"
            environment["SDL_VIDEO_MINIMIZE_ON_FOCUS_LOSS"] = "0"
            if hudEnabled {
                let launchctl = Process()
                launchctl.executableURL = URL(fileURLWithPath: "/bin/launchctl")
                launchctl.arguments = ["setenv", "MTL_HUD_ENABLED", "1"]
                try? launchctl.run()
            }
            if mode == .d3d12 {
                // Surface device loss to the game. Continuing after a GPU timeout
                // left RE3 submitting invalid work and hanging on a black screen.
                environment["MVK_CONFIG_RESUME_LOST_DEVICE"] = "0"
                environment["MVK_CONFIG_USE_METAL_ARGUMENT_BUFFERS"] = "1"
                environment["MVK_CONFIG_PREFILL_METAL_COMMAND_BUFFERS"] = "3"
                environment["VKD3D_FEATURE_LEVEL"] = "12_1"
                environment["VKD3D_CONFIG"] = "no_upload_hlist,virtual_heaps"
            }
        } else if game.kind == .executable {
            executable = URL(fileURLWithPath: game.path)
        } else {
            throw DeckError.message("macOS 앱 번들은 Launch Services로 실행해야 합니다.")
        }
        return LaunchPlan(executable: executable, arguments: arguments, environment: environment,
                          workingDirectory: URL(fileURLWithPath: game.path).deletingLastPathComponent())
    }
}
