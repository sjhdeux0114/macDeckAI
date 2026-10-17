import Foundation
import GameController

enum SelfTests {
    static func run() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("macdeck-tests-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let disk = LibraryDisk(root: root)
        var checks = 0
        func check(_ condition: @autoclosure () throws -> Bool, _ text: String) throws {
            guard try condition() else { throw DeckError.message(text) }
            checks += 1
            print("PASS: " + text)
        }
        try check(try disk.load().games.isEmpty, "new library starts empty")
        let fakeExe = root.appendingPathComponent("game with spaces.exe")
        try Data([0x4d, 0x5a, 0, 0]).write(to: fakeExe)
        var game = try Game.importing(fakeExe)
        game.arguments = ["argument with spaces", ";touch UNEXPECTED", "$(touch UNEXPECTED)", "quote\"value"]
        try disk.save(LibraryData(games: [game], winePath: "/usr/bin/true"))
        let decoded = try disk.load()
        try check(decoded.games == [game], "library preserves identities, paths and literal arguments")
        let plan = try LaunchPlan.make(game: game, wine: "/usr/bin/true", disk: disk)
        try check(plan.arguments == [game.path] + game.arguments, "Windows arguments are passed directly without a shell")
        try check(plan.environment["WINEPREFIX"] == disk.prefix(for: game).path, "each game receives its own Wine prefix")
        try check(plan.environment["WINEDLLOVERRIDES"]?.contains("d3d11,dxgi,d3d10core,winemetal=b") == true, "DXMT builtin Metal path is selected")
        try check(plan.environment["SDL_RENDER_DRIVER"] == "direct3d11", "SDL games use the Direct3D 11 path")
        let process = Process()
        process.executableURL = plan.executable
        process.arguments = plan.arguments
        process.environment = plan.environment
        process.currentDirectoryURL = root
        try process.run()
        process.waitUntilExit()
        try check(process.terminationStatus == 0 && !FileManager.default.fileExists(atPath: root.appendingPathComponent("UNEXPECTED").path), "launch plan executes without evaluating injected shell syntax")
        let invalid = root.appendingPathComponent("invalid.exe")
        try Data("not an executable".utf8).write(to: invalid)
        do { _ = try Game.importing(invalid); throw DeckError.message("invalid executable accepted") }
        catch let error as DeckError { if error.localizedDescription == "invalid executable accepted" { throw error } }
        print("PASS: invalid Windows executable is rejected")
        try Data("corrupt".utf8).write(to: disk.file)
        do { _ = try disk.load(); throw DeckError.message("corrupt library accepted") }
        catch is DecodingError { print("PASS: corrupt library is rejected without overwriting it") }
        try check(try String(contentsOf: disk.file) == "corrupt", "corrupt library remains intact")
        let steam = SteamClient(disk: disk)
        let steamRoot = steam.prefix.appendingPathComponent("drive_c/Program Files (x86)/Steam")
        let steamapps = steamRoot.appendingPathComponent("steamapps")
        try FileManager.default.createDirectory(at: steamapps.appendingPathComponent("common/Test Game"), withIntermediateDirectories: true)
        try Data([0x4d, 0x5a]).write(to: steamRoot.appendingPathComponent("steam.exe"))
        try check(steam.executable != nil, "Steam install is detected in the dedicated prefix")
        let entry = try steam.entry()
        try check(entry.arguments.contains("-gamepadui") && entry.prefix == steam.prefix.path, "Steam launches Big Picture in its persistent prefix")
        let manifest = "\"AppState\" { \"appid\" \"123\" \"name\" \"Test Game\" \"StateFlags\" \"4\" \"installdir\" \"Test Game\" }"
        try Data(manifest.utf8).write(to: steamapps.appendingPathComponent("appmanifest_123.acf"))
        let incomplete = manifest.replacingOccurrences(of: "\"123\"", with: "\"456\"").replacingOccurrences(of: "\"4\"", with: "\"2\"")
        try Data(incomplete.utf8).write(to: steamapps.appendingPathComponent("appmanifest_456.acf"))
        let games = try steam.installedGames()
        try check(games.count == 1 && games[0].steamAppID == "123", "only fully installed Steam games are imported")
        let steamPlan = try LaunchPlan.make(game: games[0], wine: "/usr/bin/true", disk: disk)
        try check(steamPlan.arguments.suffix(2) == ["-applaunch", "123"] && steamPlan.environment["WINEPREFIX"] == steam.prefix.path, "Steam games route through the client and share its prefix")
        try check(steam.windowsPath("C:\\Games\\Test")?.path.hasSuffix("drive_c/Games/Test") == true, "Steam library Windows paths map into the correct prefix")
        try check(steam.windowsPath("C:\\..\\outside") == nil, "Steam library paths cannot traverse outside their drive mapping")
        let quoted = try VDF.parse("// comment\n\"root\" { \"path\" \"C:\\\\Games\" \"title\" \"A \\\"quoted\\\" game\" }")
        try check(quoted["root"]?.object?["path"]?.string == "C:\\Games", "VDF preserves escaped Windows paths")
        try check(quoted["root"]?.object?["title"]?.string == "A \"quoted\" game", "VDF handles quotes and comments")
        do { _ = try VDF.parse("\"root\" { \"path\" \"unfinished\""); throw DeckError.message("invalid VDF accepted") }
        catch let error as DeckError { if error.localizedDescription == "invalid VDF accepted" { throw error } }
        print("PASS: malformed VDF is rejected")
        let external = root.appendingPathComponent("External Drive 한글")
        try FileManager.default.createDirectory(at: external, withIntermediateDirectories: true)
        let storage = try ExternalLibrary.connect(folder: external, existing: [], prefix: steam.prefix)
        try check(storage.drive == "d" && storage.connected, "external folder receives an available persistent drive and identity marker")
        try check(steam.windowsPath("D:\\steamapps") == external.appendingPathComponent("steamapps"), "external Windows drive resolves to selected folder with Unicode and spaces")
        let externalApps = external.appendingPathComponent("steamapps")
        try FileManager.default.createDirectory(at: externalApps.appendingPathComponent("common/Test Game"), withIntermediateDirectories: true)
        try Data(manifest.replacingOccurrences(of: "123", with: "789").utf8).write(to: externalApps.appendingPathComponent("appmanifest_789.acf"))
        try Data(#""libraryfolders" { "1" { "path" "D:/" } }"#.utf8).write(to: steamapps.appendingPathComponent("libraryfolders.vdf"))
        let imported = try steam.installedGames()
        try check(imported.contains(where: { $0.steamAppID == "789" && $0.installedLocation == externalApps.appendingPathComponent("common/Test Game").path }), "Steam manifests on external drives import with actual install location")
        let offline = root.appendingPathComponent("Disconnected")
        try FileManager.default.moveItem(at: external, to: offline)
        try check(!storage.connected, "disconnected storage is detected without recreating its mount folder")
        try FileManager.default.createDirectory(at: external, withIntermediateDirectories: true)
        try check(!storage.connected, "different disk at the same mount path is not accepted as connected")
        try FileManager.default.removeItem(at: external)
        try FileManager.default.moveItem(at: offline, to: external)
        try check(storage.connected, "reconnected storage keeps its original drive mapping")
        try disk.save(LibraryData(externalLibraries: [storage]))
        try check(try disk.load().externalLibraries == [storage], "external mappings persist across app launches")
        let old = try JSONDecoder().decode(LibraryData.self, from: Data("{\"version\":1,\"games\":[],\"winePath\":\"\"}".utf8))
        try check(old.externalLibraries == nil, "libraries from previous releases remain readable")
        let service = SteamStorage(client: steam)
        let original = try Data(contentsOf: steamapps.appendingPathComponent("libraryfolders.vdf"))
        do { try service.update(storage, removing: false, steamRunning: true); throw DeckError.message("running Steam configuration modified") }
        catch let error as DeckError { if error.localizedDescription == "running Steam configuration modified" { throw error } }
        try check(try Data(contentsOf: steamapps.appendingPathComponent("libraryfolders.vdf")) == original, "Steam settings are unchanged while client is running")
        let mirror = steamRoot.appendingPathComponent("config/libraryfolders.vdf")
        try FileManager.default.createDirectory(at: mirror.deletingLastPathComponent(), withIntermediateDirectories: true)
        let settings = #""libraryfolders" { "0" { "path" "C:/Program Files (x86)/Steam" "apps" { "123" "42" } "future_field" "preserve" } } "other" "keep""#
        for file in [steamapps.appendingPathComponent("libraryfolders.vdf"), mirror] { try Data(settings.utf8).write(to: file) }
        try service.update(storage, removing: false, steamRunning: false)
        try check(service.registered(storage), "external library is registered in Steam")
        let mirrored = try VDF.parse(String(contentsOf: mirror))
        try check(mirrored["libraryfolders"]?.object?["1"]?.object?["path"]?.string == storage.windowsLibraryPath, "Steam mirror receives the same external library")
        try check(mirrored["other"]?.string == "keep" && mirrored["libraryfolders"]?.object?["0"]?.object?["future_field"]?.string == "preserve" && mirrored["libraryfolders"]?.object?["0"]?.object?["apps"]?.object?["123"]?.string == "42", "existing Steam metadata and installed apps are preserved")
        try service.update(storage, removing: false, steamRunning: false)
        try check(try VDF.parse(String(contentsOf: mirror))["libraryfolders"]?.object?.count == 2, "repeated registration does not duplicate libraries")
        do { _ = try ExternalLibrary.connect(folder: storage.installRoot, existing: [storage], prefix: steam.prefix); throw DeckError.message("duplicate install folder accepted") }
        catch let error as DeckError { if error.localizedDescription == "duplicate install folder accepted" { throw error } }
        try check((try? FileManager.default.destinationOfSymbolicLink(atPath: steam.prefix.appendingPathComponent("dosdevices/e:").path)) == nil, "same physical Steam library cannot receive a duplicate drive mapping")
        let keep = storage.installRoot.appendingPathComponent("steamapps/game-file-keep.txt")
        try Data("keep".utf8).write(to: keep)
        try service.update(storage, removing: true, steamRunning: false)
        try check(!service.registered(storage) && FileManager.default.fileExists(atPath: keep.path), "unregister removes Steam connection and retains game files")
        try service.unlink(storage)
        try check((try? FileManager.default.destinationOfSymbolicLink(atPath: steam.prefix.appendingPathComponent("dosdevices/d:").path)) == nil && FileManager.default.fileExists(atPath: keep.path), "disconnect removes drive mapping without deleting games")
        let again = try ExternalLibrary.connect(folder: external, existing: [], prefix: steam.prefix)
        try check(again.drive == "d" && again.connected, "a disconnected folder can be linked again")
        try Data("invalid {".utf8).write(to: mirror)
        let beforeInvalid = try Data(contentsOf: steamapps.appendingPathComponent("libraryfolders.vdf"))
        do { try service.update(again, removing: false, steamRunning: false); throw DeckError.message("corrupt mirror accepted") }
        catch let error as DeckError { if error.localizedDescription == "corrupt mirror accepted" { throw error } }
        try check(try Data(contentsOf: steamapps.appendingPathComponent("libraryfolders.vdf")) == beforeInvalid, "malformed mirror prevents partial library updates")
        let snapshot = GCController.withExtendedGamepad()
        snapshot.extendedGamepad!.buttonA.setValue(1)
        snapshot.extendedGamepad!.leftThumbstick.setValueForXAxis(0.8, yAxis: -0.7)
        snapshot.extendedGamepad!.leftTrigger.setValue(0.6)
        let sample = PadSample.read(snapshot.extendedGamepad!)
        try check(sample.buttons.contains("A / ✕") && sample.leftX > 0.7 && sample.leftTrigger > 0.5, "Apple gamepad profile reads face buttons sticks and triggers")
        var navigation = PadNavigation()
        try check(navigation.update(PadSample(leftX: 0.1), now: 0, enabled: true).isEmpty, "gamepad dead zone ignores stick drift")
        try check(navigation.update(PadSample(leftX: 0.8), now: 1, enabled: true) == [.next], "stick movement selects the next game")
        try check(navigation.update(PadSample(leftX: 0.8), now: 1.1, enabled: true).isEmpty && navigation.update(PadSample(leftX: 0.8), now: 1.5, enabled: true) == [.next], "held direction repeats only after its delay")
        navigation.reset()
        try check(navigation.update(PadSample(buttons: ["A / ✕"]), now: 2, enabled: true) == [.confirm] && navigation.update(PadSample(buttons: ["A / ✕"]), now: 2.1, enabled: true).isEmpty, "holding confirm cannot repeatedly launch games")
        navigation.reset()
        try check(navigation.update(PadSample(buttons: ["A / ✕"]), now: 3, enabled: false).isEmpty && navigation.update(PadSample(buttons: ["A / ✕"]), now: 3.1, enabled: true).isEmpty, "background input does not trigger a launch on returning to MacDeck")
        navigation.reset()
        try check(navigation.update(PadSample(buttons: ["RB / R1"]), now: 4, enabled: true) == [.nextPage], "shoulder buttons navigate launcher pages")
        try check(plan.environment["WINEDLLOVERRIDES"]?.contains("xinput1_1,xinput1_2,xinput1_3,xinput1_4,xinput9_1_0=b") == true, "Windows games use Wine builtin XInput")
        let diag = try SessionDiagnostics(game: game, plan: plan, disk: disk)
        let diag2 = try SessionDiagnostics(game: game, plan: plan, disk: disk)
        try check(diag.folder != diag2.folder && diag.renderer != diag2.renderer, "each launch has isolated process and renderer logs")
        try check(diag.record.environment["HOME"] == nil && diag.record.environment["WINEPREFIX"] != nil, "diagnostics include only an allowlist of environment variables")
        try diag.started(pid: 123)
        try diag.finish(code: 11, signaled: true)
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let failed = try decoder.decode(SessionRecord.self, from: Data(contentsOf: diag.folder.appendingPathComponent("diagnostics.json")))
        try check(failed.status == "terminated-by-signal" && failed.exitCode == 11 && failed.processID == 123 && failed.ended != nil, "diagnostics persist crash signal process ID and end time")
        let steamDiag = try SessionDiagnostics(game: entry, plan: try LaunchPlan.make(game: entry, wine: "/usr/bin/true", disk: disk), disk: disk)
        try check(steamDiag.record.arguments.isEmpty && steamDiag.record.notes.contains(where: { $0.contains("authentication") }), "Steam authentication output and arguments are excluded")
        let requestDiag = try SessionDiagnostics(game: games[0], plan: steamPlan, disk: disk)
        try requestDiag.finish(code: 0, signaled: false)
        try check(requestDiag.record.status == "request-process-ended" && requestDiag.record.notes.contains(where: { $0.contains("not the game's exit code") }), "Steam request exit is not recorded as game completion")
        try check(SessionDiagnostics.safeArguments(["--password", "secret", "--token=abc", "--seed", "42"]) == ["--password", "<redacted>", "--token=<redacted>", "--seed", "42"], "diagnostic arguments redact password and token values")
        try check(SessionDiagnostics.latest(gameID: game.id, disk: disk) != nil, "latest game diagnostics can be located after app restart")
        try Data("err: DXGI_ERROR_DEVICE_REMOVED\n".utf8).write(to: diag.renderer.appendingPathComponent("sample.log"))
        let summary = try SessionDiagnostics.summary(folder: diag.folder)
        try check(summary.contains("GPU 장치 손실") && summary.contains("확정된 원인이 아닙니다"), "diagnostics summarize GPU error clues without claiming a confirmed cause")
        try check(requestDiag.record.relatedSteamSessionID == steamDiag.record.sessionID, "Steam game diagnostics correlate with the client graphics log session")
        let volume = root.appendingPathComponent("Mounted Volume")
        let legacyFolder = volume.appendingPathComponent("SteamLibrary")
        try FileManager.default.createDirectory(at: legacyFolder.appendingPathComponent("steamapps"), withIntermediateDirectories: true)
        let legacyStorage = ExternalLibrary(path: legacyFolder.path, drive: "f")
        try Data(legacyStorage.id.uuidString.utf8).write(to: legacyStorage.marker)
        let driveLink = steam.prefix.appendingPathComponent("dosdevices/f:")
        try FileManager.default.createSymbolicLink(at: driveLink, withDestinationURL: legacyFolder)
        let rootSettings = #""libraryfolders" { "0" { "path" "C:/Program Files (x86)/Steam" } "1" { "path" "F:" "contentid" "12345" "apps" { } } }"#
        for file in service.files { try Data(rootSettings.utf8).write(to: file) }
        let corrected = try service.migrateMapping(legacyStorage)
        try check(corrected.windowsLibraryPath == "F:\\SteamLibrary" && corrected.mappingRoot == volume, "legacy drive-root libraries migrate to an absolute non-root Steam path")
        try check(corrected.installRoot == legacyFolder && corrected.connected, "drive mapping repair preserves actual game folder and identity marker")
        try service.update(corrected, removing: false, steamRunning: false)
        let repaired = try VDF.parse(String(contentsOf: service.files[0]))["libraryfolders"]?.object
        try check(repaired?.count == 2 && repaired?["1"]?.object?["path"]?.string == "F:\\SteamLibrary" && repaired?["1"]?.object?["contentid"]?.string == "12345", "repair replaces stale drive-only paths without duplicating libraries or losing IDs")
        try check(steam.windowsPath("F:") == volume, "Steam normalized drive-only paths map to the drive root")
        let contentLog = steamRoot.appendingPathComponent("logs/content_log.txt")
        try FileManager.default.createDirectory(at: contentLog.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("[test] Install folder F:\\SteamLibrary not mounted.\n".utf8).write(to: contentLog)
        try check(service.recognition(corrected).contains("인식하지 못함"), "Steam mount failure is shown even when the configuration entry exists")
        try Data("[test] Loaded 0 apps from install folder \"F:\\SteamLibrary\\steamapps\\appmanifest_*.acf\".\n".utf8).write(to: contentLog)
        try check(service.recognition(corrected).contains("인식 확인됨"), "Steam recognition requires a successful library scan log")
        print("\(checks + 3) checks passed")
    }
}
