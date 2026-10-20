import Foundation

struct EpicClient {
    let disk: LibraryDisk
    var prefix: URL { disk.bottles.appendingPathComponent("EpicGames", isDirectory: true) }

    var root: URL? {
        let candidates = [
            "drive_c/Program Files (x86)/Epic Games/Launcher/Portal/Binaries/Win64",
            "drive_c/Program Files/Epic Games/Launcher/Portal/Binaries/Win64",
            "drive_c/Program Files (x86)/Epic Games/Launcher/Engine/Binaries/Win64",
            "drive_c/Program Files/Epic Games/Launcher/Engine/Binaries/Win64"
        ]
        return candidates.map { prefix.appendingPathComponent($0) }
            .first { FileManager.default.fileExists(atPath: $0.appendingPathComponent("EpicGamesLauncher.exe").path) }
    }

    var executable: URL? { root?.appendingPathComponent("EpicGamesLauncher.exe") }

    func requiresDependencies(_ game: Game) -> Bool {
        guard disk.prefix(for: game).standardizedFileURL == prefix.standardizedFileURL else { return false }
        return game.epicAppID != nil || executable?.standardizedFileURL == URL(fileURLWithPath: game.path).standardizedFileURL
    }

    /// Essential parameters for running Epic Games Launcher under Wine/Metal:
    /// - -SkipBuildPatchPrereq: Prevents infinite loop re-installing DirectX / VC++ redists
    /// - -ForceDX11: Ensures reliable hardware acceleration via DXMT (Direct3D 11 to Metal)
    static let arguments = ["-SkipBuildPatchPrereq", "-ForceDX11"]

    var eosInstaller: URL? {
        let candidates = [
            "drive_c/Program Files/Epic Games/Launcher/Portal/Extras/EOS/EpicOnlineServicesInstaller.exe",
            "drive_c/Program Files (x86)/Epic Games/Launcher/Portal/Extras/EOS/EpicOnlineServicesInstaller.exe"
        ]
        return candidates.map { prefix.appendingPathComponent($0) }
            .first { FileManager.default.fileExists(atPath: $0.path) }
    }

    var eosUserHelper: URL {
        prefix.appendingPathComponent("drive_c/Program Files (x86)/Epic Games/Epic Online Services/EpicOnlineServicesUserHelper.exe")
    }

    var eosInstalled: Bool {
        FileManager.default.fileExists(atPath: eosUserHelper.path)
    }

    func entry() throws -> Game {
        guard let executable else { throw DeckError.message("Epic Games Launcher 설치를 먼저 완료해 주세요.") }
        var game = try Game.importing(executable)
        game.name = "Epic Games Launcher"
        game.prefix = prefix.path
        game.arguments = Self.arguments
        return game
    }

    func windowsPath(_ value: String) -> URL? {
        let path = value.replacingOccurrences(of: "\\", with: "/")
        guard path.count >= 2, path[path.index(after: path.startIndex)] == ":" else { return nil }
        let drive = String(path.prefix(1)).lowercased()
        let relative = String(path.dropFirst(2)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !relative.split(separator: "/").contains("..") else { return nil }
        let base: URL
        if drive == "c" {
            base = prefix.appendingPathComponent("drive_c")
        } else {
            let link = prefix.appendingPathComponent("dosdevices/" + drive + ":")
            if let dest = try? FileManager.default.destinationOfSymbolicLink(atPath: link.path) {
                base = URL(fileURLWithPath: dest)
            } else {
                base = link.resolvingSymlinksInPath()
            }
        }
        return relative.isEmpty ? URL(fileURLWithPath: base.path, isDirectory: false).standardizedFileURL : base.appendingPathComponent(relative, isDirectory: false).standardizedFileURL
    }

    struct ManifestItem: Decodable {
        let AppName: String
        let DisplayName: String
        let InstallLocation: String
        let LaunchExecutable: String
        let AppVersionString: String?
    }

    func installedGames() throws -> [Game] {
        let manifestsDir = prefix.appendingPathComponent("drive_c/ProgramData/Epic/EpicGamesLauncher/Data/Manifests")
        guard FileManager.default.fileExists(atPath: manifestsDir.path) else { return [] }
        let files = (try? FileManager.default.contentsOfDirectory(at: manifestsDir, includingPropertiesForKeys: nil)) ?? []
        var games: [String: Game] = [:]
        for file in files where file.pathExtension.lowercased() == "item" {
            guard let data = try? Data(contentsOf: file),
                  let item = try? JSONDecoder().decode(ManifestItem.self, from: data),
                  !item.AppName.isEmpty, !item.DisplayName.isEmpty,
                  let installFolder = windowsPath(item.InstallLocation) else { continue }
            let cleanExe = item.LaunchExecutable.replacingOccurrences(of: "\\", with: "/")
            let exeURL = installFolder.appendingPathComponent(cleanExe)
            guard FileManager.default.fileExists(atPath: exeURL.path) else { continue }
            var game = Game(name: item.DisplayName, path: exeURL.path, kind: .windows)
            game.prefix = prefix.path
            game.epicAppID = item.AppName
            game.installedLocation = installFolder.path
            games[item.AppName] = game
        }
        return games.values.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    static func runInstaller(_ plan: LaunchPlan, log: URL) async throws {
        try FileManager.default.createDirectory(at: log.deletingLastPathComponent(), withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: log.path, contents: nil)
        let output = try FileHandle(forWritingTo: log)
        defer { try? output.close() }
        let process = Process()
        process.executableURL = plan.executable; process.arguments = plan.arguments
        process.environment = plan.environment; process.currentDirectoryURL = plan.workingDirectory
        process.standardOutput = output; process.standardError = output
        try process.run()
        let deadline = Date().addingTimeInterval(360)
        while process.isRunning && Date() < deadline { try await Task.sleep(nanoseconds: 250_000_000) }
        if process.isRunning { process.terminate(); throw DeckError.message("Epic Games Launcher 설치가 지연되고 있습니다. 설치 로그를 확인해 주세요.") }
        guard process.terminationStatus == 0 else { throw DeckError.message("Epic Games Launcher 설치가 코드 \(process.terminationStatus)로 종료됐습니다. 설치 로그를 확인해 주세요.") }
    }

    func prepareEOSDirectories() throws {
        let fm = FileManager.default
        let dirs = [
            prefix.appendingPathComponent("drive_c/ProgramData/Epic/EpicOnlineServices/EOSInstaller/Logs"),
            prefix.appendingPathComponent("drive_c/Program Files (x86)/Epic Games/Epic Online Services"),
            prefix.appendingPathComponent("drive_c/Program Files/Epic Games/Epic Online Services")
        ]
        for dir in dirs {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }

    static func runEOSInstaller(wine: String, installer: URL, prefix: URL, log: URL) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: wine)
        process.arguments = [installer.path, "/install", "productId=4a0e9aa62e2341be9911ad38e0392a1d", "/quiet"]
        var env = ProcessInfo.processInfo.environment
        env["WINEPREFIX"] = prefix.path
        let lib = URL(fileURLWithPath: wine).resolvingSymlinksInPath()
            .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("lib").path
        env["DYLD_FALLBACK_LIBRARY_PATH"] = lib
        env["WINEMSYNC"] = "1"
        env["WINE_LARGE_ADDRESS_AWARE"] = "1"
        env["WINEDLLOVERRIDES"] = "winemenubuilder.exe=d;winedbg.exe=d;mshtml=;mscoree=b;"
            + "xinput1_1,xinput1_2,xinput1_3,xinput1_4,xinput9_1_0=b;"
            + "d3d9=b;d3d11,dxgi,d3d10core,d3d12,d3d12core,vulkan-1,winevulkan,winemetal=b"
        process.environment = env
        try FileManager.default.createDirectory(at: log.deletingLastPathComponent(), withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: log.path, contents: nil)
        let output = try FileHandle(forWritingTo: log)
        defer { try? output.close() }
        process.standardOutput = output; process.standardError = output
        try process.run()
        let deadline = Date().addingTimeInterval(120)
        while process.isRunning && Date() < deadline { try await Task.sleep(nanoseconds: 500_000_000) }
        if process.isRunning { process.terminate() }
    }

    /// Patches EpicGamesLauncher.exe to bypass the exFAT / POSIX mode 0700 Windows DACL check (Error Code: DP-07).
    /// On exFAT volumes (external NVMe/SSD), macOS fskit does not persist Windows ACLs, causing GetNamedSecurityInfoW
    /// to return DACLs without BuiltinUsers (S-1-5-32-545) or World (S-1-1-0) GENERIC_WRITE, triggering:
    /// 'DirectoryPreparation: Authorize success without gaining access' -> 'Error Code: DP-07'.
    /// This atomic patch replaces the conditional jump (jne) with an unconditional jump (jmp + nop),
    /// allowing seamless installation to external drives while preserving full process isolation.
    @discardableResult
    func applyDirectoryPreparationPatch() -> Bool {
        guard let executable, FileManager.default.fileExists(atPath: executable.path) else { return false }
        let bak = executable.deletingPathExtension().appendingPathExtension("exe.orig")
        guard let data = try? Data(contentsOf: executable) else { return false }

        let origPattern = Data([0x84, 0xc0, 0x0f, 0x85, 0x82, 0x00, 0x00, 0x00, 0x48, 0x8b, 0x0d, 0xba, 0xf7, 0xe8, 0x01, 0x48])
        let patchPattern = Data([0x84, 0xc0, 0xe9, 0x83, 0x00, 0x00, 0x00, 0x90, 0x48, 0x8b, 0x0d, 0xba, 0xf7, 0xe8, 0x01, 0x48])

        if let range = data.range(of: origPattern) {
            if !FileManager.default.fileExists(atPath: bak.path) {
                try? FileManager.default.copyItem(at: executable, to: bak)
            }
            var patched = data
            patched.replaceSubrange(range, with: patchPattern)
            try? patched.write(to: executable, options: .atomic)
            return true
        } else if data.range(of: patchPattern) != nil {
            return true
        }
        return false
    }
}
