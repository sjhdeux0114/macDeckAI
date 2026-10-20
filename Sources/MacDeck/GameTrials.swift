import Foundation
import CryptoKit

struct GameTrial: Codable {
    var schema = 1
    var steamAppID: String
    var name: String
    var sourceGame: String
    var executable: String
    var executableSHA256: String
    var runtimeSource: String
    var candidateSHA256: String?
    var backend: String
    var status: String
    var created = Date()

    static let supported: Set<String> = ["1245620"]
    static func root(id: String, disk: LibraryDisk) throws -> URL {
        guard supported.contains(id) else { throw DeckError.message("시험 프로필이 없는 게임입니다.") }
        return disk.root.appendingPathComponent("GameTrials/" + id, isDirectory: true)
    }
    static func load(id: String, disk: LibraryDisk) throws -> GameTrial? {
        let file = try root(id: id, disk: disk).appendingPathComponent("trial.json")
        guard FileManager.default.fileExists(atPath: file.path) else { return nil }
        let value = try JSONDecoder().decode(Self.self, from: Data(contentsOf: file))
        guard value.schema == 1, value.steamAppID == id else { throw DeckError.message("게임 시험 환경 기록이 일치하지 않습니다.") }
        return value
    }
    func save(disk: LibraryDisk) throws {
        let file = try Self.root(id: steamAppID, disk: disk).appendingPathComponent("trial.json")
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(self).write(to: file, options: .atomic)
    }
    static func prepare(game: Game, wine: String, disk: LibraryDisk) async throws -> GameTrial {
        guard let id = game.steamAppID, supported.contains(id), let location = game.installedLocation else { throw DeckError.message("설치된 Steam 시험 게임을 선택하세요.") }
        if let existing = try load(id: id, disk: disk) { return existing }
        let base = try root(id: id, disk: disk)
        let fileManager = FileManager.default
        guard !fileManager.fileExists(atPath: base.path) else { throw DeckError.message("완료되지 않은 시험 폴더가 있습니다. 기존 데이터를 보존하므로 별도 확인이 필요합니다: " + base.path) }
        guard let runtime = DirectX12Support.runtimeRoot(forWine: wine) else { throw DeckError.message("복제할 Wine 런타임을 찾지 못했습니다.") }
        let source = URL(fileURLWithPath: location, isDirectory: true)
        let gameFolder = source.appendingPathComponent("Game", isDirectory: true)
        let executableName = "eldenring.exe"
        let original = gameFolder.appendingPathComponent(executableName)
        guard fileManager.fileExists(atPath: original.path) else { throw DeckError.message("원본 게임 실행 파일을 찾지 못했습니다: " + original.path) }
        try fileManager.createDirectory(at: base, withIntermediateDirectories: true)
        // APFS clones have independent write semantics, sharing unchanged blocks.
        // No hard links, Steam account/config copying, or game installation copying.
        let clone = Process()
        clone.executableURL = URL(fileURLWithPath: "/bin/cp")
        clone.arguments = ["-cR", runtime.path, base.appendingPathComponent("Runtime").path]
        clone.standardOutput = FileHandle.nullDevice; clone.standardError = FileHandle.nullDevice
        try clone.run()
        while clone.isRunning { try await Task.sleep(nanoseconds: 100_000_000) }
        guard clone.terminationStatus == 0 else { throw DeckError.message("런타임 APFS 복제에 실패했습니다. 원본은 변경하지 않았습니다.") }
        let stage = base.appendingPathComponent("Game", isDirectory: true)
        try fileManager.createDirectory(at: stage, withIntermediateDirectories: true)
        let excluded: Set<String> = ["d3d9.dll", "dxgi.dll", "d3d11.dll", "d3d12.dll", "dxvk.conf", "steam_appid.txt", "start_protected_game.exe", "start_protected_game.exe.original", "easyanticheat"]
        for item in try fileManager.contentsOfDirectory(at: gameFolder, includingPropertiesForKeys: [.isSymbolicLinkKey], options: [.skipsHiddenFiles]) {
            let name = item.lastPathComponent
            guard !excluded.contains(name.lowercased()), item.pathExtension.lowercased() != "log", item.pathExtension.lowercased() != "dmp" else { continue }
            let destination = stage.appendingPathComponent(name)
            if name == executableName { try fileManager.copyItem(at: item, to: destination) }
            else { try fileManager.createSymbolicLink(at: destination, withDestinationURL: item) }
        }
        let value = GameTrial(steamAppID: id, name: game.name, sourceGame: location, executable: executableName,
            executableSHA256: try sha(original), runtimeSource: runtime.path, candidateSHA256: nil,
            backend: "D3DMetal-required", status: "prepared-needs-steam-install")
        try value.save(disk: disk)
        return value
    }
    func installSteam(disk: LibraryDisk) async throws -> GameTrial {
        let base = try Self.root(id: steamAppID, disk: disk)
        let trialDisk = LibraryDisk(root: base)
        let wine = base.appendingPathComponent("Runtime/bin/wine")
        if SteamClient(disk: trialDisk).executable != nil {
            var updated = self; updated.status = "steam-installed-needs-user-login"; try updated.save(disk: disk); return updated
        }
        let destination = base.appendingPathComponent("SteamSetup.exe")
        if !FileManager.default.fileExists(atPath: destination.path) {
            let source = URL(string: "https://cdn.akamai.steamstatic.com/client/installer/SteamSetup.exe")!
            let (bytes, response) = try await URLSession.shared.data(from: source)
            guard (response as? HTTPURLResponse)?.statusCode == 200, bytes.starts(with: [0x4d, 0x5a]) else { throw DeckError.message("공식 Steam 설치 프로그램 다운로드에 실패했습니다.") }
            try bytes.write(to: destination, options: .atomic)
        }
        var installer = Game(name: "게임 전용 Steam 설치", path: destination.path, kind: .windows)
        installer.graphicsBackend = .d3d12
        installer.prefix = SteamClient(disk: trialDisk).prefix.path; installer.arguments = ["/S"]
        try trialDisk.preparePrefix(for: installer)
        var plan = try LaunchPlan.make(game: installer, wine: wine.path, disk: trialDisk)
        plan.environment["WINEMSYNC"] = "1"
        plan.environment["WINEESYNC"] = "0"
        plan.environment["WINE_LARGE_ADDRESS_AWARE"] = "1"
        if backend == "Apple-D3DMetal" {
            plan.environment["WINEDLLOVERRIDES"] = Self.nativeAppleOverrides(plan.environment["WINEDLLOVERRIDES"] ?? "")
            plan.environment["DYLD_FALLBACK_LIBRARY_PATH", default: ""] += ":" + base.appendingPathComponent("Runtime/lib/external").path
        }
        let process = Process(); process.executableURL = plan.executable; process.arguments = plan.arguments
        process.environment = plan.environment; process.currentDirectoryURL = plan.workingDirectory
        process.standardOutput = FileHandle.nullDevice; process.standardError = FileHandle.nullDevice
        try process.run()
        let deadline = Date().addingTimeInterval(150)
        while process.isRunning && Date() < deadline { try await Task.sleep(nanoseconds: 200_000_000) }
        if process.isRunning { process.terminate(); throw DeckError.message("시험용 Steam 설치 대기가 끝났습니다. 원본 Steam은 변경하지 않았습니다.") }
        guard process.terminationStatus == 0, SteamClient(disk: trialDisk).executable != nil else { throw DeckError.message("시험용 Steam 설치를 완료하지 못했습니다.") }
        var updated = self; updated.status = "steam-installed-needs-user-login"; try updated.save(disk: disk); return updated
    }
    func game(_ original: Game, disk: LibraryDisk) throws -> Game {
        let base = try Self.root(id: steamAppID, disk: disk)
        var game = original
        game.name += " · 격리 시험"
        game.path = base.appendingPathComponent("Game/" + executable).path
        game.installedLocation = base.appendingPathComponent("Game").path
        game.prefix = SteamClient(disk: LibraryDisk(root: base)).prefix.path
        game.runtimePath = base.appendingPathComponent("Runtime/bin/wine").path
        game.trialAppID = steamAppID
        game.arguments = []
        game.graphicsBackend = .d3d12
        return game
    }
    func steamGame(disk: LibraryDisk) throws -> Game {
        let base = try Self.root(id: steamAppID, disk: disk)
        var steam = try SteamClient(disk: LibraryDisk(root: base)).entry()
        steam.name = name + " · 시험 Steam 로그인"
        steam.arguments = ["-no-cef-sandbox", "-cef-disable-gpu"]
        steam.runtimePath = base.appendingPathComponent("Runtime/bin/wine").path
        steam.trialAppID = steamAppID
        steam.graphicsBackend = .d3d12
        return steam
    }

    static func configure(game: Game, disk: LibraryDisk, environment: inout [String: String]) throws {
        guard let id = game.trialAppID else { return }
        let steam = URL(fileURLWithPath: game.path).lastPathComponent.lowercased() == "steam.exe"
        guard game.steamAppID == id || (steam && game.steamAppID == nil) else { throw DeckError.message("시험 게임의 Steam App ID가 일치하지 않습니다.") }
        let base = try root(id: id, disk: disk)
        guard game.runtimePath == base.appendingPathComponent("Runtime/bin/wine").path,
              disk.prefix(for: game).standardizedFileURL.path == SteamClient(disk: LibraryDisk(root: base)).prefix.standardizedFileURL.path else { throw DeckError.message("시험 설정을 일반 실행 환경에 적용하지 않습니다.") }
        // Keep the trial Steam host and its game on the same server-wait path.
        // The Elden trial's MSync host failed to show a login window locally.
        environment["WINEMSYNC"] = "0"
        environment.removeValue(forKey: "WINEMSYNC_QLIMIT")
        environment["WINEESYNC"] = "0"
        environment["WINE_LARGE_ADDRESS_AWARE"] = "1"
        if id == "1245620", try load(id: id, disk: disk)?.backend == "Apple-D3DMetal" {
            environment["WINEMSYNC"] = "1"
            environment["WINEMSYNC_QLIMIT"] = "512"
            environment["D3DM_MTL4"] = "0"
            environment["WINEDLLOVERRIDES"] = nativeAppleOverrides(environment["WINEDLLOVERRIDES"] ?? "")
            environment["DYLD_FALLBACK_LIBRARY_PATH", default: ""] += ":" + base.appendingPathComponent("Runtime/lib/external").path
            environment["DYLD_FRAMEWORK_PATH"] = base.appendingPathComponent("Runtime/lib/external").path
            environment["D3DMETAL_FRAMEWORK_PATH"] = base.appendingPathComponent("Runtime/lib/external/D3DMetal.framework/D3DMetal").path
        }
    }

    static func nativeAppleOverrides(_ original: String) -> String {
        let names: Set<String> = ["dxgi", "d3d10", "d3d11", "d3d12", "d3d12core"]
        let kept = original.split(separator: ";").compactMap { item -> String? in
            let pair = item.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard pair.count == 2 else { return nil }
            let remaining = pair[0].split(separator: ",").map(String.init).filter { !names.contains($0) }
            return remaining.isEmpty ? nil : remaining.joined(separator: ",") + "=" + pair[1]
        }
        return (kept + ["dxgi,d3d10,d3d11,d3d12,d3d12core=n,b"]).joined(separator: ";")
    }

    func importApple(redist: URL, license: URL, disk: LibraryDisk) throws -> GameTrial {
        guard steamAppID == "1245620" else { throw DeckError.message("D3DMetal은 엘든링 시험 런타임에만 가져옵니다.") }
        let fm = FileManager.default, base = try Self.root(id: steamAppID, disk: disk)
        let runtime = base.appendingPathComponent("Runtime")
        guard fm.fileExists(atPath: redist.appendingPathComponent("lib/external/D3DMetal.framework").path),
              fm.fileExists(atPath: license.path) else { throw DeckError.message("Apple 원본 배포 폴더와 라이선스가 필요합니다.") }
        var hashes: [String: String] = [:]
        for name in ["dxgi.dll", "d3d10.dll", "d3d11.dll", "d3d12.dll", "d3d12core.dll"] {
            let source = redist.appendingPathComponent("lib/wine/x86_64-windows/" + name)
            guard fm.fileExists(atPath: source.path) else { throw DeckError.message("Apple 구성요소 누락: " + name) }
            hashes[name] = try Self.sha(source)
        }
        let external = runtime.appendingPathComponent("lib/external")
        guard !fm.fileExists(atPath: external.path) else { throw DeckError.message("시험 런타임에 외부 구성요소가 이미 있습니다. 덮어쓰지 않습니다.") }
        try fm.copyItem(at: redist.appendingPathComponent("lib/external"), to: external)
        // Apple PE DLLs dispatch through matching Unix bridges, supplied as
        // relative symlinks to the original libd3dshared.dylib.
        let unix = runtime.appendingPathComponent("lib/wine/x86_64-unix")
        for name in ["dxgi", "d3d10", "d3d11", "d3d12", "d3d12core"] {
            let source = redist.appendingPathComponent("lib/wine/x86_64-unix/" + name + ".so")
            guard try fm.destinationOfSymbolicLink(atPath: source.path) == "../../external/libd3dshared.dylib" else {
                throw DeckError.message("Apple Unix 연결 경로를 확인할 수 없습니다: " + name)
            }
            let target = unix.appendingPathComponent(name + ".so")
            if fm.fileExists(atPath: target.path) { try fm.removeItem(at: target) }
            try fm.copyItem(at: source, to: target)
        }
        for name in hashes.keys {
            let target = runtime.appendingPathComponent("lib/wine/x86_64-windows/" + name)
            if fm.fileExists(atPath: target.path) { try fm.removeItem(at: target) }
            try fm.copyItem(at: redist.appendingPathComponent("lib/wine/x86_64-windows/" + name), to: target)
        }
        // The clone's D3D12 bridge source must agree with its Apple-native DLLs.
        let bridge = runtime.appendingPathComponent("lib/wine/dxgi-d3d12/x86_64-windows/dxgi.dll")
        if fm.fileExists(atPath: bridge.path) { try fm.removeItem(at: bridge) }
        try fm.copyItem(at: redist.appendingPathComponent("lib/wine/x86_64-windows/dxgi.dll"), to: bridge)
        let licenses = base.appendingPathComponent("Apple-D3DMetal", isDirectory: true)
        try fm.createDirectory(at: licenses, withIntermediateDirectories: true)
        try fm.copyItem(at: license, to: licenses.appendingPathComponent("License.rtf"))
        let bytes = try JSONSerialization.data(withJSONObject: hashes, options: [.prettyPrinted, .sortedKeys])
        try bytes.write(to: licenses.appendingPathComponent("components-sha256.json"))
        var value = self; value.backend = "Apple-D3DMetal"; try value.save(disk: disk); return value
    }

    static func sha(_ file: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: file); defer { try? handle.close() }
        var hash = SHA256()
        while let bytes = try handle.read(upToCount: 1_048_576), !bytes.isEmpty { hash.update(data: bytes) }
        return hash.finalize().map { String(format: "%02x", $0) }.joined()
    }
}

enum GameTrialCLI {
    static func confirmElden() throws {
        let disk = LibraryDisk.standard
        guard let original = try disk.load().games.first(where: { $0.steamAppID == "1245620" }),
              let trial = try GameTrial.load(id: "1245620", disk: disk), trial.backend == "Apple-D3DMetal" else {
            throw DeckError.message("확인할 엘든링 전용 환경이 없습니다.")
        }
        let game = try trial.game(original, disk: disk)
        guard try GameTrial.sha(URL(fileURLWithPath: game.path)) == trial.executableSHA256 else { throw DeckError.message("시험 게임 실행 파일이 변경되었습니다.") }
        let plan = try LaunchPlan.make(game: game, wine: game.runtimePath, disk: disk, verifyProfile: false)
        let store = GameProfileStore(disk: disk)
        var profile = try store.profile(game)
        profile.name = original.name + " · 전용 Metal 3"
        profile.engine = "FromSoftware / Direct3D 12"
        profile.status = .userReportedWorking
        profile.experimentalEnabled = false
        profile.notes = "2026-10-18 사용자 확인: 1920×1200 전체화면 60fps, DS4 입력/카메라 정상. Apple D3DMetal Metal3 + MSync1/ESync0 + SDL. 장시간·모든 구간 안정성은 미검증."
        profile.baseline = try GameProfileStore.baseline(game: game, plan: plan)
        try store.update(profile)
        var summary = try store.profile(original)
        summary.status = .userReportedWorking
        summary.notes = profile.notes + " 전용 환경으로 검증했으며 공유 Steam 경로의 성공을 뜻하지 않습니다."
        try store.update(summary)
        print("SAVED: steam:1245620:trial · protected user-reported configuration")
    }

    static func launch(arguments: [String]) async throws {
        let isSteam = arguments.contains("--trial-steam"), flag = isSteam ? "--trial-steam" : "--trial-run"
        guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else { throw DeckError.message("Steam App ID가 필요합니다.") }
        let id = arguments[index + 1], disk = LibraryDisk.standard
        if arguments.contains("--trial-esync") {
            throw DeckError.message("ESync 시험은 Wine 서비스 CPU 과점유로 중단했습니다. 기본 서버 대기 설정을 사용하세요.")
        }
        guard let original = try disk.load().games.first(where: { $0.steamAppID == id }),
              let trial = try GameTrial.load(id: id, disk: disk) else { throw DeckError.message("먼저 게임 전용 시험 환경을 준비하세요.") }
        if !isSteam && id == "1245620" && trial.backend != "Apple-D3DMetal" { throw DeckError.message("엘든링 시험 환경에 Apple D3DMetal을 먼저 가져오세요.") }
        let game = try isSteam ? trial.steamGame(disk: disk) : trial.game(original, disk: disk)
        var plan = try LaunchPlan.make(game: game, wine: game.runtimePath, disk: disk)
        if id == "1245620" {
            if arguments.contains("--trial-serverwait") { plan.environment["WINEMSYNC"] = "0" }
            if arguments.contains("--trial-metal4") { plan.environment["D3DM_MTL4"] = "1" }
            if arguments.contains("--trial-msync") || !arguments.contains("--trial-serverwait") {
                plan.environment["WINEMSYNC"] = "1"
                plan.environment["WINEMSYNC_QLIMIT"] = "512"
                plan.environment["WINEESYNC"] = "0"
            }
            if !isSteam && (arguments.contains("--trial-metal3") || !arguments.contains("--trial-metal4")) {
                plan.environment["D3DM_MTL4"] = "0"
            }
        }
        plan.environment["MTL_HUD_ENABLED"] = !isSteam && arguments.contains("--trial-hud") ? "1" : "0"
        try GameProfileStore(disk: disk).verify(game, plan: plan)
        let diagnostic = try SessionDiagnostics(game: game, plan: plan, disk: disk)
        plan.environment["DXMT_LOG_PATH"] = diagnostic.renderer.path
        plan.environment["DXVK_LOG_PATH"] = diagnostic.renderer.path
        let process = Process()
        process.executableURL = plan.executable; process.arguments = plan.arguments
        process.environment = plan.environment; process.currentDirectoryURL = plan.workingDirectory
        process.standardOutput = FileHandle.nullDevice
        let output = try FileHandle(forWritingTo: diagnostic.output)
        try output.seekToEnd()
        defer { try? output.close() }
        process.standardError = isSteam ? FileHandle.nullDevice : output
        try process.run(); try diagnostic.started(pid: process.processIdentifier)
        print("STARTED: " + game.name + " · pid=" + String(process.processIdentifier) + " · session=" + diagnostic.folder.path); fflush(stdout)
        while process.isRunning { try await Task.sleep(nanoseconds: 200_000_000) }
        try diagnostic.finish(code: process.terminationStatus, signaled: process.terminationReason == .uncaughtSignal)
        print("LAUNCHER_EXIT: " + String(process.terminationStatus)); fflush(stdout)
    }
}
