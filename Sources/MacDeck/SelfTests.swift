import Foundation
import AppKit
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
        try DependencyTests.run(root: root) { condition, title in try check(condition, title) }
        let fakeExe = root.appendingPathComponent("game with spaces.exe")
        try Data([0x4d, 0x5a, 0, 0]).write(to: fakeExe)
        var game = try Game.importing(fakeExe)
        game.arguments = ["argument with spaces", ";touch UNEXPECTED", "$(touch UNEXPECTED)", "quote\"value"]
        try disk.save(LibraryData(games: [game], winePath: "/usr/bin/true"))
        let decoded = try disk.load()
        try check(decoded.games == [game], "library preserves identities, paths and literal arguments")
        let plan = try LaunchPlan.make(game: game, wine: "/usr/bin/true", disk: disk)
        try check(plan.arguments == [game.path] + game.arguments, "Windows arguments are passed directly without a shell")
        try check(plan.environment["MTL_HUD_ENABLED"] == "1", "Metal HUD defaults enabled so Fn+Shift+F9 shortcut functions and Metal stats are visible")
        var disabledHUD = try disk.load()
        disabledHUD.showMetalHUD = false
        try disk.save(disabledHUD)
        let planDisabled = try LaunchPlan.make(game: game, wine: "/usr/bin/true", disk: disk)
        try check(planDisabled.environment["MTL_HUD_ENABLED"] == "0", "Metal HUD can be explicitly disabled in settings")
        try disk.save(decoded)
        let overrides = plan.environment["WINEDLLOVERRIDES"] ?? ""
        try check(overrides.contains("winedbg.exe=d") && overrides.contains("d3d9=b")
                  && !overrides.contains("easyanticheat") && !overrides.contains("CrashHandler")
                  && !overrides.contains("dinput8=b") && !overrides.contains("nvngx"), "global overrides preserve game input proxies, anti-cheat and engine crash reporting")
        try check(plan.environment["WINEMSYNC"] == "1" && plan.environment["WINEESYNC"] == "0" && plan.environment["WINE_LARGE_ADDRESS_AWARE"] == "1", "Windows launch plan enables MSync for direct x64, disables ESync, and enables large address awareness")
        try check(plan.environment["WINE_D3D_CONFIG"] == "renderer=vulkan", "WineD3D configures Vulkan renderer with multithreaded command stream for Direct3D 9 GPU acceleration")
        var pe32Data = Data(count: 0x80)
        pe32Data[0] = 0x4d; pe32Data[1] = 0x5a
        pe32Data[0x3c] = 0x40
        pe32Data[0x40] = 0x50; pe32Data[0x41] = 0x45
        pe32Data[0x44] = 0x4c; pe32Data[0x45] = 0x01
        let fake32Exe = root.appendingPathComponent("game32.exe")
        try pe32Data.write(to: fake32Exe)
        let game32 = try Game.importing(fake32Exe)
        let plan32 = try LaunchPlan.make(game: game32, wine: "/usr/bin/true", disk: disk)
        try check(plan32.environment["WINEMSYNC"] == "0" && plan32.environment["WINEESYNC"] == "0" && plan32.environment["WINE_LARGE_ADDRESS_AWARE"] == "0", "32-bit Windows games use server waits and 2GB address cap for non-LAA safety")
        var steamGame32 = game
        let steamGame32Dir = root.appendingPathComponent("SteamCommon32")
        try FileManager.default.createDirectory(at: steamGame32Dir, withIntermediateDirectories: true)
        try pe32Data.write(to: steamGame32Dir.appendingPathComponent("nested32.exe"))
        steamGame32.installedLocation = steamGame32Dir.path
        let steamPlan32 = try LaunchPlan.make(game: steamGame32, wine: "/usr/bin/true", disk: disk)
        try check(steamPlan32.environment["WINEMSYNC"] == "0", "Steam game with 32-bit binary in installedLocation sets WINEMSYNC=0")
        var gamePerGameDX12 = game
        gamePerGameDX12.graphicsBackend = .d3d12
        let planPerGameDX12 = try LaunchPlan.make(game: gamePerGameDX12, wine: "/usr/bin/true", disk: disk)
        try check(planPerGameDX12.environment["WINEDLLOVERRIDES"]?.contains("d3d12,d3d12core") == true, "game-specific graphicsBackend overrides global graphics backend")
        try check(plan.environment["WINEDLLOVERRIDES"]?.contains("xaudio2_7,xaudio2_8,xaudio2_9") == true && plan.environment["WINEDLLOVERRIDES"]?.contains("dsound=b") == true, "Windows launch plan overrides XAudio2 and DirectSound to Wine builtins")
        var legacyLibrary = try JSONSerialization.jsonObject(with: JSONEncoder().encode(decoded)) as! [String: Any]
        var legacyGames = legacyLibrary["games"] as! [[String: Any]]
        legacyGames[0]["d3d9Mode"] = "native"
        legacyLibrary["games"] = legacyGames
        try JSONSerialization.data(withJSONObject: legacyLibrary).write(to: disk.file, options: .atomic)
        let migratedLegacy = try disk.load()
        let migratedPlan = try LaunchPlan.make(game: migratedLegacy.games[0], wine: "/usr/bin/true", disk: disk)
        try check(migratedPlan.environment["WINEDLLOVERRIDES"]?.contains("d3d9=b") == true
                  && migratedPlan.environment["WINEDLLOVERRIDES"]?.contains("d3d9=n") == false
                  && migratedPlan.environment["DXVK_CONFIG_FILE"] == nil
                  && migratedPlan.environment["WINE_D3D_CONFIG"] == "renderer=vulkan", "legacy native D9VK values decode but can only launch through the builtin Direct3D 9 path")
        try disk.save(decoded)
        try check(plan.environment["WINEDLLOVERRIDES"]?.contains("mfplat,mfreadwrite,mf,mfmediaengine,winegstreamer=b;quartz,amstream=b") == true, "Windows launch plan overrides Media Foundation and DirectShow to Wine builtins")
        try check(plan.environment["DXMT_CONFIG"]?.contains("ignoreMapFlagNoWait=True") == false && plan.environment["DXMT_CONFIG"]?.contains("handleAltTab=True") == true, "DXMT preserves NO_WAIT semantics and enables Alt-Tab handling")
        try check(plan.environment["SDL_RENDER_DRIVER"] == "direct3d11", "SDL games use the Direct3D 11 path")
        try check(plan.environment["DXVK_LOG_PATH"] == disk.logs.path && plan.environment["DXVK_LOG_LEVEL"] == "info", "graphics translation logs have a managed destination")
        let mixed = CompatibilityInspector.report(game: "Mixed", files: ["Game_Data/globalgamemanagers", "UnityPlayer.dll", "EasyAntiCheat/launcher.exe", "dinput8.dll"], imports: ["d3d9.dll"], architectures: ["x86"], truncated: false)
        try check(mixed.engines == ["Unity"] && mixed.findings.contains { $0.id == "d3d9-device" } && mixed.findings.contains { $0.id == "anticheat" } && mixed.findings.contains { $0.id == "native-proxy" }, "compatibility report separates engine, DX9, anti-cheat and proxy evidence")
        let unknown = CompatibilityInspector.report(game: "Unity Unreal Crysis", files: ["readme.txt"], imports: [], architectures: [], truncated: true)
        try check(unknown.engines.isEmpty && unknown.scanTruncated && unknown.findings.contains { $0.id == "scan-limit" }, "game names do not classify engines and scan limits remain visible")
        try check(CompatibilityInspector.peImports(fake32Exe).imports.isEmpty, "truncated PE files do not invent graphics imports")
        var importPE = Data(count: 1024)
        func put16(_ offset: Int, _ value: UInt16) { importPE[offset] = UInt8(value & 255); importPE[offset+1] = UInt8(value >> 8) }
        func put32(_ offset: Int, _ value: UInt32) { for byte in 0..<4 { importPE[offset+byte] = UInt8((value >> (byte*8)) & 255) } }
        importPE[0] = 0x4d; importPE[1] = 0x5a; put32(0x3c, 0x40)
        importPE[0x40] = 0x50; importPE[0x41] = 0x45
        put16(0x44, 0x14c); put16(0x46, 1); put16(0x54, 224); put16(0x58, 0x10b)
        put32(0x58+104, 0x1000)
        put32(0x138+12, 0x1000); put32(0x138+16, 512); put32(0x138+20, 512)
        put32(0x200+12, 0x1040)
        importPE.replaceSubrange(0x240..<0x249, with: Data("d3d9.dll\0".utf8))
        let importFile = root.appendingPathComponent("imports.exe"); try importPE.write(to: importFile)
        let parsedImports = CompatibilityInspector.peImports(importFile)
        try check(parsedImports.architecture == "x86" && parsedImports.imports == ["d3d9.dll"], "bounded PE parsing resolves a real import descriptor through its section RVA")
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
        var steam64 = pe32Data; steam64[0x44] = 0x64; steam64[0x45] = 0x86
        try steam64.write(to: steamRoot.appendingPathComponent("steam.exe"))
        try check(!DirectX12Support.is32BitWindowsBinary(at: steamRoot.appendingPathComponent("steam.exe")), "fixture Steam host is genuinely x64 while the game fixture is x86")
        let steamHostPlan = try LaunchPlan.make(game: entry, wine: "/usr/bin/true", disk: disk)
        try check(steamHostPlan.environment["WINEMSYNC"] == "1" && steamHostPlan.environment["WINEESYNC"] == "0", "Steam 64-bit host enables MSync for smooth Big Picture multithreading without ESync polling")
        try check(entry.arguments.contains("-gamepadui") && entry.prefix == steam.prefix.path, "Steam launches Big Picture in its persistent prefix")
        try check(SteamClient.arguments(gpuAcceleration: false).contains("-cef-disable-gpu-compositing") && !SteamClient.arguments(gpuAcceleration: true).contains(where: { $0.contains("disable-gpu") }), "Steam GPU acceleration removes both software-rendering overrides and retains a reversible fallback")
        try check(SteamClient.arguments(gpuAcceleration: true).contains("-cef-force-gpu"), "Steam accelerated mode explicitly requests GPU despite automatic software fallback")
        try check([false, true].allSatisfy { SteamClient.arguments(gpuAcceleration: $0).last == "steam://open/bigpicture" }, "both Steam rendering modes explicitly route an existing client to Big Picture")
        try check(SteamStorage.containsSteamProcess("wine " + steamRoot.appendingPathComponent("steam.exe").path + " -gamepadui", executable: steamRoot.appendingPathComponent("steam.exe").path), "native inspection detects Steam in its managed prefix")
        try check(!SteamStorage.containsSteamProcess("/other/prefix/steam.exe -gamepadui", executable: steamRoot.appendingPathComponent("steam.exe").path) && !SteamStorage.containsSteamProcess("", executable: steamRoot.appendingPathComponent("steam.exe").path), "native inspection does not mistake a stopped or unrelated Steam for the managed client")
        try check(SteamStorage.containsSteamProcess("C:\\Program Files (x86)\\Steam\\steam.exe -gamepadui", executable: steamRoot.appendingPathComponent("steam.exe").path), "native inspection recognizes Wine Windows process names without booting tasklist")
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
        navigation.reset()
        try check(navigation.update(PadSample(leftY: 0.8), now: 5, enabled: true) == [.up], "vertical controller navigation remains distinct from horizontal movement")
        navigation.reset()
        try check(navigation.update(PadSample(buttons: ["X / □"]), now: 6, enabled: true) == [.details], "DS4 square opens game management without launching")
        try check(ConsoleGrid.move(index: 2, count: 8, columns: 3, action: .next) == 2 && ConsoleGrid.move(index: 3, count: 8, columns: 3, action: .previous) == 3, "grid navigation never wraps across row edges")
        try check(ConsoleGrid.move(index: 1, count: 8, columns: 3, action: .down) == 4 && ConsoleGrid.move(index: 7, count: 8, columns: 3, action: .up) == 4, "up and down follow visual grid columns")
        try check(ConsoleGrid.move(index: 7, count: 8, columns: 3, action: .down) == 7 && ConsoleGrid.move(index: 1, count: 0, columns: 3, action: .confirm) == 0, "partial last rows and empty lists stay in bounds")
        try check(plan.environment["WINEDLLOVERRIDES"]?.contains("xinput1_1,xinput1_2,xinput1_3,xinput1_4,xinput9_1_0=b") == true, "Windows games use Wine builtin XInput")
        let xboxHints = ControllerHints(layout: .xbox), psHints = ControllerHints(layout: .playStation)
        try check(xboxHints.confirm == "A" && xboxHints.back == "B" && xboxHints.shoulders == "LB / RB" && psHints.confirm == "✕" && psHints.details == "□" && psHints.shoulders == "L1 / R1", "button hints distinguish Xbox and PlayStation while using the same actions")
        let profileDisk = LibraryDisk(root: root.appendingPathComponent("ProfileTests"))
        let profiles = GameProfileStore(disk: profileDisk)
        var secondGame = game; secondGame.id = UUID(); secondGame.name = "Different game"
        _ = try profiles.register([game, secondGame])
        var firstProfile = try profiles.profile(game)
        firstProfile.experimentalEnabled = true; firstProfile.environment = ["DXMT_CONFIG": "dxgi.handleAltTab=False"]
        try profiles.update(firstProfile)
        var firstEnvironment: [String: String] = [:], secondEnvironment: [String: String] = [:]
        try profiles.apply(game, environment: &firstEnvironment); try profiles.apply(secondGame, environment: &secondEnvironment)
        try check(firstEnvironment["DXMT_CONFIG"] != nil && secondEnvironment.isEmpty, "an experimental launch adjustment affects only its exact game identity")
        var sharedPrefixGame = game; sharedPrefixGame.prefix = SteamClient(disk: profileDisk).prefix.path
        var sharedEnvironment: [String: String] = [:]
        var sharedRejected = false
        do { try profiles.apply(sharedPrefixGame, environment: &sharedEnvironment) } catch { sharedRejected = true }
        try check(sharedRejected && sharedEnvironment.isEmpty, "direct executables in the shared Steam prefix cannot receive experimental settings")
        var renamed = game; renamed.name = "Renamed"
        try check(GameProfileStore.identity(renamed) == GameProfileStore.identity(game), "renaming a game preserves its compatibility identity")
        var steamIdentity = game; steamIdentity.steamAppID = "214830"
        try check(GameProfileStore.identity(steamIdentity) == "steam:214830" && (try profiles.profile(steamIdentity)).status == .failing, "Steam App ID resolves the failing HMH record without fuzzy name matching")
        var dmcIdentity = game; dmcIdentity.steamAppID = "220440"
        var dmc5Identity = game; dmc5Identity.steamAppID = "601150"
        let dmcRecord = try profiles.profile(dmcIdentity), dmc5Record = try profiles.profile(dmc5Identity)
        try check(dmcRecord.id != dmc5Record.id && dmcRecord.status == .failing && dmc5Record.status == .failing && dmcRecord.environment.isEmpty && dmc5Record.environment.isEmpty, "DmC CLR failure and DMC5 renderer regression remain separate and inject no shared experimental environment")
        let trialRoot = try GameTrial.root(id: "1245620", disk: profileDisk)
        let trialWine = trialRoot.appendingPathComponent("Runtime/bin/wine")
        try FileManager.default.createDirectory(at: trialWine.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.copyItem(atPath: "/usr/bin/true", toPath: trialWine.path)
        let trialStage = trialRoot.appendingPathComponent("Game")
        try FileManager.default.createDirectory(at: trialStage, withIntermediateDirectories: true)
        try Data([0x4d, 0x5a]).write(to: trialStage.appendingPathComponent("eldenring.exe"))
        let trial = GameTrial(steamAppID: "1245620", name: "Elden test", sourceGame: trialStage.path, executable: "eldenring.exe", executableSHA256: "test", runtimeSource: "test", candidateSHA256: nil, backend: "Apple-D3DMetal", status: "test")
        try trial.save(disk: profileDisk)
        var originalElden = game; originalElden.steamAppID = "1245620"
        let preparedElden = try trial.game(originalElden, disk: profileDisk)
        let appleDXGI = trialRoot.appendingPathComponent("Runtime/lib/wine/x86_64-windows/dxgi.dll")
        let wrongDXGI = trialRoot.appendingPathComponent("Runtime/lib/wine/dxgi-dxmt/x86_64-windows/dxgi.dll")
        for file in [appleDXGI, wrongDXGI] { try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true) }
        try Data("Apple DXGI".utf8).write(to: appleDXGI)
        try Data("other backend".utf8).write(to: wrongDXGI)
        let trialPlan = try LaunchPlan.make(game: preparedElden, wine: "/usr/bin/false", disk: profileDisk)
        try check(trialPlan.executable.path == trialWine.path && trialPlan.environment["WINEMSYNC"] == "1" && trialPlan.environment["WINEESYNC"] == "0" && trialPlan.environment["D3DM_MTL4"] == "0", "prepared Elden uses its private runtime and verified Metal3/MSync settings without CLI flags")
        try check(try Data(contentsOf: appleDXGI) == Data("Apple DXGI".utf8), "prepared Apple launch never replaces Apple's DXGI with the generic backend")
        try check(GameProfileStore.identity(preparedElden) == "steam:1245620:trial" && plan.environment["D3DM_MTL4"] == nil, "Elden trial identity and graphics environment remain separate from other games")
        var mismatchedTrial = preparedElden; mismatchedTrial.steamAppID = "214830"
        var mismatchRejected = false
        do { _ = try LaunchPlan.make(game: mismatchedTrial, wine: trialWine.path, disk: profileDisk) } catch { mismatchRejected = true }
        try check(mismatchRejected, "trial environment rejects a different Steam App ID")
        var trialProfile = try profiles.profile(preparedElden)
        trialProfile.baseline = try GameProfileStore.baseline(game: preparedElden, plan: trialPlan)
        try profiles.update(trialProfile)
        try Data("changed Apple DXGI".utf8).write(to: appleDXGI)
        var appleChangeRejected = false
        do { try profiles.verify(preparedElden, plan: trialPlan) } catch { appleChangeRejected = true }
        try check(appleChangeRejected, "protected Elden trial detects Apple-native DXGI changes")
        let sharedMap = SharedSteamRuntime(disk: profileDisk)
        var selectedRenderer = try profiles.profile(steamIdentity)
        selectedRenderer.steamRenderer = .dxmt
        try profiles.update(selectedRenderer)
        try sharedMap.writeMap()
        let mapping = try String(contentsOf: SteamClient(disk: profileDisk).prefix.appendingPathComponent("drive_c/ProgramData/MacDeck/renderers.ini"), encoding: .utf16)
        try check(mapping.contains("default=metal") && mapping.contains("0=dxmt") && mapping.contains("214830=dxmt"), "shared renderer map keeps Big Picture on DXMT and scopes overrides by exact Steam App ID")
        try check(!mapping.contains("1245620:trial"), "internal trial profiles never become common Steam renderer rules")
        var rollbackDMC5 = try profiles.profile(dmc5Identity)
        rollbackDMC5.steamRenderer = .dxmt
        let priorEldenRecord = try profiles.profile(preparedElden)
        try profiles.update(rollbackDMC5)
        try sharedMap.writeMap()
        let mapPrefix = SteamClient(disk: profileDisk).prefix
        try check(try SharedSteamRuntime.selection(appID: "601150", prefix: mapPrefix) == "dxmt" && SharedSteamRuntime.selection(appID: "1245620", prefix: mapPrefix) == "metal" && SharedSteamRuntime.selection(appID: "952060", prefix: mapPrefix) == "metal" && SharedSteamRuntime.selection(appID: "220440", prefix: mapPrefix) == "metal", "DMC5 DXMT rollback preserves Elden/RE3/default and does not match DmC by name")
        rollbackDMC5.dxmtMarshalFix = true
        try profiles.update(rollbackDMC5)
        try sharedMap.writeMap()
        try check(try SharedSteamRuntime.component(appID: "601150", module: "d3d11", prefix: mapPrefix, renderer: "dxmt") == "macdeck_dxmt_gsts_v1_d3d11.dll", "DMC5 explicitly selects the GS/TS candidate")
        try check(try SharedSteamRuntime.component(appID: "952060", module: "d3d11", prefix: mapPrefix, renderer: "dxmt") == "macdeck_dxmt_d3d11.dll" && SharedSteamRuntime.component(appID: "601150", module: "dxgi", prefix: mapPrefix, renderer: "dxmt") == "macdeck_dxmt_dxgi.dll", "GS/TS candidate never changes RE3 or DXGI")
        var invalidMarshalProfile = rollbackDMC5; invalidMarshalProfile.id = "steam:220440"
        var invalidMarshalRejected = false
        do { try GameProfileStore.validate(invalidMarshalProfile) } catch { invalidMarshalRejected = true }
        try check(invalidMarshalRejected, "GS/TS candidate rejects a different exact App ID")
        let unchangedEldenRecord = try profiles.profile(preparedElden)
        try check(unchangedEldenRecord.revision == priorEldenRecord.revision && unchangedEldenRecord.baseline == priorEldenRecord.baseline, "DMC5 renderer rollback preserves the Elden protected revision and baseline")
        let sharedTestWine = sharedMap.runtime.appendingPathComponent("bin/wine")
        let sharedTestDLLs = sharedMap.runtime.appendingPathComponent("lib/wine/x86_64-windows")
        try FileManager.default.createDirectory(at: sharedTestWine.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: sharedTestDLLs, withIntermediateDirectories: true)
        try Data("wine".utf8).write(to: sharedTestWine)
        try Data(mapPrefix.path.utf8).write(to: sharedMap.runtime.appendingPathComponent("macdeck-shared-renderer.marker"))
        let selectedCandidate = sharedTestDLLs.appendingPathComponent("macdeck_dxmt_gsts_v1_d3d11.dll")
        try Data("candidate v1".utf8).write(to: selectedCandidate)
        let protectedPlan = LaunchPlan(executable: sharedTestWine, arguments: [], environment: ["WINEPREFIX": mapPrefix.path], workingDirectory: root)
        let beforeCandidateChange = try GameProfileStore.baseline(game: dmc5Identity, plan: protectedPlan)
        var protectedRE3 = dmc5Identity; protectedRE3.steamAppID = "952060"
        let beforeRE3CandidateChange = try GameProfileStore.baseline(game: protectedRE3, plan: protectedPlan)
        try Data("changed candidate".utf8).write(to: selectedCandidate)
        try check(try GameProfileStore.baseline(game: dmc5Identity, plan: protectedPlan) != beforeCandidateChange, "DMC5 baseline detects a changed GS/TS candidate")
        try check(try GameProfileStore.baseline(game: protectedRE3, plan: protectedPlan) == beforeRE3CandidateChange, "DMC5 candidate changes preserve the RE3 runtime baseline")
        var hmhProfile = try profiles.profile(steamIdentity)
        try check(hmhProfile.hmhMetalFix != true, "Half Minute Hero direct Metal candidate defaults to disabled")
        hmhProfile.hmhMetalFix = true
        try profiles.update(hmhProfile); try sharedMap.writeMap()
        try check(try SharedSteamRuntime.hmhMetalEnabled(prefix: mapPrefix) && !SharedSteamRuntime.dmcMetalEnabled(prefix: mapPrefix), "exact App ID214830 selects only its Direct Metal candidate")
        let hmhCandidateDLL = sharedTestDLLs.deletingLastPathComponent().appendingPathComponent("i386-windows/macdeck_hmh_dxmt_v1.dll")
        try FileManager.default.createDirectory(at: hmhCandidateDLL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("hmh direct metal candidate".utf8).write(to: hmhCandidateDLL)
        let beforeHMHCandidate = try GameProfileStore.baseline(game: steamIdentity, plan: protectedPlan)
        let beforeHMHRE3 = try GameProfileStore.baseline(game: protectedRE3, plan: protectedPlan)
        try Data("changed hmh direct metal candidate".utf8).write(to: hmhCandidateDLL)
        try check(try GameProfileStore.baseline(game: steamIdentity, plan: protectedPlan) != beforeHMHCandidate && GameProfileStore.baseline(game: protectedRE3, plan: protectedPlan) == beforeHMHRE3, "HMH candidate changes are detected without changing RE3 baseline")
        var invalidHMH = hmhProfile; invalidHMH.id = "steam:220440"
        var invalidHMHRejected = false
        do { try GameProfileStore.validate(invalidHMH) } catch { invalidHMHRejected = true }
        try check(invalidHMHRejected, "HMH direct Metal candidate rejects another exact App ID")
        try check(hmhProfile.hmhClearFix != true, "HMH Clear candidate defaults to disabled")
        hmhProfile.hmhClearFix = true
        try profiles.update(hmhProfile); try sharedMap.writeMap()
        try check(try SharedSteamRuntime.hmhMetalPatch(prefix: mapPrefix) == "dxmt-clear-v2", "exact App ID214830 selects its isolated Clear candidate")
        let hmhClearDLL = hmhCandidateDLL.deletingLastPathComponent().appendingPathComponent("macdeck_hmh_dxmt_clear_v2.dll")
        try Data("hmh clear candidate".utf8).write(to: hmhClearDLL)
        let beforeHMHClear = try GameProfileStore.baseline(game: steamIdentity, plan: protectedPlan)
        try Data("changed hmh clear candidate".utf8).write(to: hmhClearDLL)
        try check(try GameProfileStore.baseline(game: steamIdentity, plan: protectedPlan) != beforeHMHClear && GameProfileStore.baseline(game: protectedRE3, plan: protectedPlan) == beforeHMHRE3, "HMH Clear changes are detected without changing RE3 baseline")
        var missingHMHMetal = hmhProfile; missingHMHMetal.hmhMetalFix = false
        var missingHMHMetalRejected = false
        do { try GameProfileStore.validate(missingHMHMetal) } catch { missingHMHMetalRejected = true }
        try check(missingHMHMetalRejected, "HMH Clear candidate requires its exact Direct Metal route")
        hmhProfile.hmhClearFix = false
        try profiles.update(hmhProfile); try sharedMap.writeMap()
        try check(try SharedSteamRuntime.hmhMetalPatch(prefix: mapPrefix) == "dxmt-v1", "disabling HMH Clear restores its base Direct Metal candidate")
        hmhProfile.hmhMetalFix = false
        try profiles.update(hmhProfile); try sharedMap.writeMap()
        try check(try !SharedSteamRuntime.hmhMetalEnabled(prefix: mapPrefix), "disabling HMH candidate removes its exact map entry")
        try check(hmhProfile.d3d9YieldFix != true, "D3D9 CPU spin yield fix defaults to disabled")
        hmhProfile.d3d9YieldFix = true
        try profiles.update(hmhProfile); try sharedMap.writeMap()
        try check(try SharedSteamRuntime.d3d9YieldEnabled(prefix: mapPrefix, appID: "214830"), "exact App ID214830 enables D3D9 yield fix in shared renderer map")
        try check(try !SharedSteamRuntime.d3d9YieldEnabled(prefix: mapPrefix, appID: "952060"), "D3D9 yield fix is scoped and does not enable for RE3")
        let yieldHelperDLL = sharedTestDLLs.deletingLastPathComponent().appendingPathComponent("i386-windows/macdeck_d3d9_yield_helper.dll")
        try FileManager.default.createDirectory(at: yieldHelperDLL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("d3d9 yield helper candidate".utf8).write(to: yieldHelperDLL)
        let beforeYieldHMH = try GameProfileStore.baseline(game: steamIdentity, plan: protectedPlan)
        try Data("changed d3d9 yield helper candidate".utf8).write(to: yieldHelperDLL)
        try check(try GameProfileStore.baseline(game: steamIdentity, plan: protectedPlan) != beforeYieldHMH && GameProfileStore.baseline(game: protectedRE3, plan: protectedPlan) == beforeHMHRE3, "D3D9 yield helper changes are detected without changing RE3 baseline")
        var protectedWithYield = hmhProfile
        protectedWithYield.baseline = beforeYieldHMH
        var protectedYieldRejected = false
        do { try GameProfileStore.validate(protectedWithYield) } catch { protectedYieldRejected = true }
        try check(protectedYieldRejected, "D3D9 yield fix cannot be combined with protected baseline")
        hmhProfile.d3d9YieldFix = false
        try profiles.update(hmhProfile); try sharedMap.writeMap()
        try check(try !SharedSteamRuntime.d3d9YieldEnabled(prefix: mapPrefix, appID: "214830"), "disabling D3D9 yield fix removes it from shared renderer map")
        var dmc9Profile = try profiles.profile(dmcIdentity)
        try check(dmc9Profile.dmcMetalFix != true, "DmC direct Metal adjustment defaults to disabled")
        dmc9Profile.dmcMetalFix = true
        try profiles.update(dmc9Profile)
        try sharedMap.writeMap()
        try check(try SharedSteamRuntime.dmcMetalEnabled(prefix: mapPrefix) && SharedSteamRuntime.component(appID: "601150", module: "d3d11", prefix: mapPrefix, renderer: "dxmt") == "macdeck_dxmt_gsts_v1_d3d11.dll", "DmC direct Metal map preserves DMC5 GS/TS selection")
        try check(dmc9Profile.dmcClearFix != true, "DmC partial Clear experiment defaults to disabled")
        let beforeClear = try GameProfileStore.baseline(game: dmcIdentity, plan: protectedPlan)
        let beforeClearRE3 = try GameProfileStore.baseline(game: protectedRE3, plan: protectedPlan)
        dmc9Profile.dmcClearFix = true
        try profiles.update(dmc9Profile)
        try sharedMap.writeMap()
        try check(try SharedSteamRuntime.dmcClearEnabled(prefix: mapPrefix) && SharedSteamRuntime.dmcMetalPatch(prefix: mapPrefix) == "dxmt-bind-v3", "explicit DmC Clear experiment is written to its exact map entry")
        try check(try SharedSteamRuntime.component(appID: "601150", module: "d3d11", prefix: mapPrefix, renderer: "dxmt") == "macdeck_dxmt_gsts_v1_d3d11.dll", "DmC Clear experiment preserves DMC5 renderer")
        try check(try GameProfileStore.baseline(game: dmcIdentity, plan: protectedPlan) != beforeClear && GameProfileStore.baseline(game: protectedRE3, plan: protectedPlan) == beforeClearRE3, "DmC Clear map changes are detected while RE3 baseline is preserved")
        let clearBindingDLL = sharedTestDLLs.deletingLastPathComponent().appendingPathComponent("i386-windows/macdeck_dmc_dxmt_clear_v3.dll")
        try FileManager.default.createDirectory(at: clearBindingDLL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("binding candidate".utf8).write(to: clearBindingDLL)
        let beforeBindingChange = try GameProfileStore.baseline(game: dmcIdentity, plan: protectedPlan)
        try Data("changed binding candidate".utf8).write(to: clearBindingDLL)
        try check(try GameProfileStore.baseline(game: dmcIdentity, plan: protectedPlan) != beforeBindingChange && GameProfileStore.baseline(game: protectedRE3, plan: protectedPlan) == beforeClearRE3, "native DmC Clear DLL changes are detected without changing RE3 baseline")
        var wrongClear = dmc9Profile; wrongClear.id = "steam:952060"; wrongClear.dmcMetalFix = false
        var wrongClearRejected = false
        do { try GameProfileStore.validate(wrongClear) } catch { wrongClearRejected = true }
        try check(wrongClearRejected, "DmC Clear experiment rejects RE3 exact ID")
        var missingMetalClear = dmc9Profile; missingMetalClear.dmcMetalFix = false
        var missingMetalRejected = false
        do { try GameProfileStore.validate(missingMetalClear) } catch { missingMetalRejected = true }
        try check(missingMetalRejected, "DmC Clear experiment requires private direct Metal")
        try check(dmc9Profile.dmcSrgbFix != true, "DmC BC sRGB candidate defaults to disabled")
        dmc9Profile.dmcSrgbFix = true
        try profiles.update(dmc9Profile); try sharedMap.writeMap()
        try check(try SharedSteamRuntime.dmcMetalPatch(prefix: mapPrefix) == "dxmt-srgb-v4" && SharedSteamRuntime.dmcClearEnabled(prefix: mapPrefix), "exact DmC sRGB candidate retains native Clear")
        let srgbDLL = clearBindingDLL.deletingLastPathComponent().appendingPathComponent("macdeck_dmc_dxmt_srgb_v4.dll")
        try Data("srgb candidate".utf8).write(to: srgbDLL)
        let beforeSrgbChange = try GameProfileStore.baseline(game: dmcIdentity, plan: protectedPlan)
        try Data("changed srgb candidate".utf8).write(to: srgbDLL)
        try check(try GameProfileStore.baseline(game: dmcIdentity, plan: protectedPlan) != beforeSrgbChange && GameProfileStore.baseline(game: protectedRE3, plan: protectedPlan) == beforeClearRE3, "sRGB binary changes are detected only for DmC baseline")
        var foreignSrgb = dmc9Profile; foreignSrgb.id = "steam:214830"
        var foreignSrgbRejected = false
        do { try GameProfileStore.validate(foreignSrgb) } catch { foreignSrgbRejected = true }
        try check(foreignSrgbRejected, "DmC sRGB candidate cannot affect Half Minute Hero")
        var noClearSrgb = dmc9Profile; noClearSrgb.dmcClearFix = false
        var noClearSrgbRejected = false
        do { try GameProfileStore.validate(noClearSrgb) } catch { noClearSrgbRejected = true }
        try check(noClearSrgbRejected, "sRGB candidate requires native Clear fix")
        try check(dmc9Profile.dmcQueryYieldFix != true, "DmC query-yield candidate defaults to disabled")
        dmc9Profile.dmcQueryYieldFix = true
        try profiles.update(dmc9Profile); try sharedMap.writeMap()
        try check(try SharedSteamRuntime.dmcMetalPatch(prefix: mapPrefix) == "dxmt-smooth-v5" && SharedSteamRuntime.dmcClearEnabled(prefix: mapPrefix), "exact DmC query-yield candidate retains sRGB and native Clear")
        let queryYieldDLL = clearBindingDLL.deletingLastPathComponent().appendingPathComponent("macdeck_dmc_query_yield_v1.dll")
        try Data("query yield candidate".utf8).write(to: queryYieldDLL)
        let beforeQueryYieldChange = try GameProfileStore.baseline(game: dmcIdentity, plan: protectedPlan)
        try Data("changed query yield candidate".utf8).write(to: queryYieldDLL)
        try check(try GameProfileStore.baseline(game: dmcIdentity, plan: protectedPlan) != beforeQueryYieldChange && GameProfileStore.baseline(game: protectedRE3, plan: protectedPlan) == beforeClearRE3, "query-yield binary changes are detected only for DmC baseline")
        var foreignQueryYield = dmc9Profile; foreignQueryYield.id = "steam:214830"
        var foreignQueryYieldRejected = false
        do { try GameProfileStore.validate(foreignQueryYield) } catch { foreignQueryYieldRejected = true }
        try check(foreignQueryYieldRejected, "DmC query-yield candidate cannot affect Half Minute Hero")
        var noSrgbQueryYield = dmc9Profile; noSrgbQueryYield.dmcSrgbFix = false
        var noSrgbQueryYieldRejected = false
        do { try GameProfileStore.validate(noSrgbQueryYield) } catch { noSrgbQueryYieldRejected = true }
        try check(noSrgbQueryYieldRejected, "query-yield candidate requires sRGB fix")
        dmc9Profile.dmcQueryYieldFix = false
        try profiles.update(dmc9Profile); try sharedMap.writeMap()
        try check(try SharedSteamRuntime.dmcMetalPatch(prefix: mapPrefix) == "dxmt-srgb-v4", "disabling query-yield candidate restores v4")
        dmc9Profile.dmcSrgbFix = false
        try profiles.update(dmc9Profile); try sharedMap.writeMap()
        try check(try SharedSteamRuntime.dmcMetalPatch(prefix: mapPrefix) == "dxmt-bind-v3", "disabling sRGB candidate restores v3")
        dmc9Profile.dmcClearFix = false
        try profiles.update(dmc9Profile)
        try sharedMap.writeMap()
        try check(try !SharedSteamRuntime.dmcClearEnabled(prefix: mapPrefix), "disabling DmC Clear experiment restores original direct Metal map")
        var invalidDmc9 = dmc9Profile; invalidDmc9.id = "steam:601150"
        var invalidDmc9Rejected = false
        do { try GameProfileStore.validate(invalidDmc9) } catch { invalidDmc9Rejected = true }
        try check(invalidDmc9Rejected, "DmC direct Metal adjustment rejects another exact game ID")
        let dmcCandidateDLL = sharedTestDLLs.deletingLastPathComponent().appendingPathComponent("i386-windows/macdeck_dmc_dxmt_v1.dll")
        try FileManager.default.createDirectory(at: dmcCandidateDLL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("d9vk candidate".utf8).write(to: dmcCandidateDLL)
        let beforeDmcDLL = try GameProfileStore.baseline(game: dmcIdentity, plan: protectedPlan)
        let beforeDmcRE3 = try GameProfileStore.baseline(game: protectedRE3, plan: protectedPlan)
        try Data("changed d9vk candidate".utf8).write(to: dmcCandidateDLL)
        try check(try GameProfileStore.baseline(game: dmcIdentity, plan: protectedPlan) != beforeDmcDLL && GameProfileStore.baseline(game: protectedRE3, plan: protectedPlan) == beforeDmcRE3, "DmC candidate changes are detected without changing RE3 baseline")
        var unmarkedEnvironment = ["WINEMSYNC": "unchanged"]
        try SharedSteamRuntime.configure(wine: "/usr/bin/true", environment: &unmarkedEnvironment)
        try check(unmarkedEnvironment == ["WINEMSYNC": "unchanged"], "shared renderer configuration never changes an unmarked runtime")
        var rejected = false
        firstProfile.environment = ["DYLD_INSERT_LIBRARIES": "/tmp/other.dylib"]
        do { try profiles.update(firstProfile) } catch { rejected = true }
        try check(rejected, "profile database rejects process injection and arbitrary environment settings")
        firstProfile = try profiles.profile(game); firstProfile.experimentalEnabled = false; firstProfile.environment = [:]
        firstProfile.baseline = try GameProfileStore.baseline(game: game, plan: plan)
        try profiles.update(firstProfile)
        try profiles.verify(game, plan: plan)
        var alteredPlan = plan; alteredPlan.environment["DXMT_CONFIG"] = "changed"
        rejected = false
        do { try profiles.verify(game, plan: alteredPlan) } catch { rejected = true }
        try check(rejected, "a protected game's changed launch settings are blocked before execution")
        try check((try profiles.profile(secondGame)).baseline == nil, "protecting one game leaves another game's baseline untouched")
        let protectedFolder = root.appendingPathComponent("NoAutomaticGameEdits")
        try FileManager.default.createDirectory(at: protectedFolder, withIntermediateDirectories: true)
        let originalFiles = ["sample.exe": Data([0x4d, 0x5a]), "d3d9.dll": Data("custom-d3d9".utf8), "settings.ini": Data("Capability=DirectX12".utf8), "eldenring.exe": Data("game".utf8), "start_protected_game.exe": Data("original launcher".utf8)]
        for (name, bytes) in originalFiles { try bytes.write(to: protectedFolder.appendingPathComponent(name)) }
        var protectedGame = game; protectedGame.path = protectedFolder.appendingPathComponent("sample.exe").path; protectedGame.installedLocation = protectedFolder.path
        _ = DirectX12Support.applyGlobal(mode: .dxmt, wine: "/usr/bin/true", games: [protectedGame], disk: profileDisk)
        try check(originalFiles.allSatisfy { name, bytes in (try? Data(contentsOf: protectedFolder.appendingPathComponent(name))) == bytes }, "global graphics preparation never renames game DLLs, edits INI files or replaces game launchers")
        let diag = try SessionDiagnostics(game: game, plan: plan, disk: disk)
        let issue = SupportReports.manifest(game: steamIdentity, session: diag.record, profile: try profiles.profile(steamIdentity), reproduction: "New game crashes")
        let issueBytes = try JSONEncoder().encode(issue)
        let issueRoundTrip = try JSONDecoder().decode(SupportReportManifest.self, from: issueBytes)
        try check(issueRoundTrip.gameKey == "steam:214830" && issueRoundTrip.steamAppID == "214830" && !issueRoundTrip.automaticPromotionAllowed && issueRoundTrip.reportStatus == "unverified-user-report", "support report JSON carries App ID, stable database key and an explicitly unverified status")
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
        try FileManager.default.removeItem(at: driveLink)
        let unmigrated = ExternalLibrary(id: corrected.id, path: legacyFolder.path, drive: "f", libraryFolder: "")
        let reconnected = service.autoConnectAll([unmigrated], steamRunning: false)
        try check(reconnected.first?.windowsLibraryPath == "F:\\SteamLibrary" && (try? FileManager.default.destinationOfSymbolicLink(atPath: driveLink.path)) == volume.path && service.registered(unmigrated), "configured external libraries automatically reconnect and migrate on app startup")
        let fakeRuntime = root.appendingPathComponent("FakeRuntime")
        let fakeWineBin = fakeRuntime.appendingPathComponent("bin/wine64")
        let fakeDXMTDXGI = fakeRuntime.appendingPathComponent("lib/wine/dxgi-dxmt/x86_64-windows/dxgi.dll")
        let fakeD3D12DXGI = fakeRuntime.appendingPathComponent("lib/wine/dxgi-d3d12/x86_64-windows/dxgi.dll")
        let activeRuntimeDXGI = fakeRuntime.appendingPathComponent("lib/wine/x86_64-windows/dxgi.dll")
        try FileManager.default.createDirectory(at: fakeWineBin.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: fakeDXMTDXGI.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: fakeD3D12DXGI.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: activeRuntimeDXGI.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("#!/bin/sh\nexit 0\n".utf8).write(to: fakeWineBin)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: fakeWineBin.path)
        let dxmtDXGIBytes = Data([0x4d, 0x5a]) + Data("dxmt-dxgi".utf8)
        let d3d12DXGIBytes = Data([0x4d, 0x5a]) + DirectX12Support.wineBuiltinMarker + Data("d3d12-bridge".utf8)
        try dxmtDXGIBytes.write(to: fakeDXMTDXGI)
        try d3d12DXGIBytes.write(to: fakeD3D12DXGI)
        let dx12GameDir = root.appendingPathComponent("DX12Game")
        try FileManager.default.createDirectory(at: dx12GameDir, withIntermediateDirectories: true)
        let dx12Exe = dx12GameDir.appendingPathComponent("re3.exe")
        try Data([0x4d, 0x5a, 0, 0]).write(to: dx12Exe)
        let configINI = dx12GameDir.appendingPathComponent("re3_config.ini")
        try "[Render]\nCapability=DirectX12\nTargetPlatform=DirectX12\n".write(to: configINI, atomically: true, encoding: .utf8)
        let deployedDXGI = dx12GameDir.appendingPathComponent("dxgi.dll")
        try d3d12DXGIBytes.write(to: deployedDXGI)
        let steamSys32 = steam.prefix.appendingPathComponent("drive_c/windows/system32", isDirectory: true)
        try FileManager.default.createDirectory(at: steamSys32, withIntermediateDirectories: true)
        let fakeD3D11 = fakeRuntime.appendingPathComponent("lib/wine/x86_64-windows/d3d11.dll")
        let d3d11Bytes = Data([0x4d, 0x5a]) + Data("dxmt-d3d11-patched".utf8)
        try d3d11Bytes.write(to: fakeD3D11)
        let fakeD3D9 = fakeRuntime.appendingPathComponent("lib/wine/x86_64-windows/d3d9.dll")
        let d3d9Bytes = Data([0x4d, 0x5a]) + Data("dxvk-d3d9-patched".utf8)
        try d3d9Bytes.write(to: fakeD3D9)
        let fakeMedia = fakeRuntime.appendingPathComponent("Media")
        let fakeGstDylib = fakeMedia.appendingPathComponent("lib/libgstreamer-1.0.0.dylib")
        let fakeBundledReg = fakeMedia.appendingPathComponent("gst-registry.bin")
        try FileManager.default.createDirectory(at: fakeGstDylib.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("fake-gst".utf8).write(to: fakeGstDylib)
        let bundledRegBytes = Data("bundled-registry-cache".utf8)
        try bundledRegBytes.write(to: fakeBundledReg)
        var dx12Game = try Game.importing(dx12Exe)
        dx12Game.prefix = steam.prefix.path
        DirectX12Support.applyGlobal(mode: .dxmt, wine: fakeWineBin.path, games: [dx12Game], disk: disk)
        try check((try? Data(contentsOf: activeRuntimeDXGI)) == dxmtDXGIBytes && (try? Data(contentsOf: steamSys32.appendingPathComponent("dxgi.dll"))) == dxmtDXGIBytes, "Global DX11 Mode switches runtime and prefix system32 dxgi.dll to DXMT")
        try check((try? Data(contentsOf: steamSys32.appendingPathComponent("d3d11.dll"))) == d3d11Bytes, "Global sync keeps prefix system32 d3d11.dll synchronized with runtime")
        try check((try? Data(contentsOf: steamSys32.appendingPathComponent("d3d9.dll"))) == d3d9Bytes, "Global sync keeps prefix system32 d3d9.dll synchronized with runtime")
        try check((try? Data(contentsOf: deployedDXGI)) == d3d12DXGIBytes, "global preparation preserves existing game-local renderer DLLs")
        try check((try? String(contentsOf: configINI)).map {  $0.contains("Capability=DirectX12") && $0.contains("TargetPlatform=DirectX12") } == true, "global DX11 selection does not rewrite another game configuration")
        DirectX12Support.applyGlobal(mode: .d3d12, wine: fakeWineBin.path, games: [dx12Game], disk: disk)
        try check((try? Data(contentsOf: activeRuntimeDXGI)) == d3d12DXGIBytes && (try? Data(contentsOf: steamSys32.appendingPathComponent("dxgi.dll"))) == d3d12DXGIBytes, "Global DX12 Mode switches runtime and prefix system32 dxgi.dll to Wine D3D12 bridge")
        try check((try? String(contentsOf: configINI)).map { $0.contains("Capability=DirectX12") && $0.contains("TargetPlatform=DirectX12") } == true, "Global DX12 Mode updates game config INI to DirectX12")
        try disk.save(LibraryData(games: [dx12Game], winePath: fakeWineBin.path, graphicsBackend: .d3d12))
        let dx12Plan = try LaunchPlan.make(game: dx12Game, wine: fakeWineBin.path, disk: disk)
        try check(dx12Plan.environment["MVK_CONFIG_RESUME_LOST_DEVICE"] == "0", "DX12 surfaces GPU device loss instead of forcing resume after timeout")
        try check(dx12Plan.environment["MVK_CONFIG_USE_METAL_ARGUMENT_BUFFERS"] == "1" && dx12Plan.environment["MVK_CONFIG_PREFILL_METAL_COMMAND_BUFFERS"] == "0", "DX12 enables MoltenVK Metal argument buffers and prefilled command buffers")
        try check(dx12Plan.environment["VKD3D_FEATURE_LEVEL"] == nil && dx12Plan.environment["VKD3D_CONFIG"] == nil, "DX12 does not spoof feature levels or inject unsupported vkd3d-proton flags")
        try check(dx12Plan.environment["WINEDLLOVERRIDES"]?.contains("dxgi,d3d12,d3d12core,vulkan-1,winevulkan") == true, "Global DX12 Mode enables D3D12 and Vulkan overrides in LaunchPlan")
        let runtimeProfiles = GameProfileStore(disk: disk)
        var protectedRuntimeProfile = try runtimeProfiles.profile(dx12Game)
        protectedRuntimeProfile.baseline = try GameProfileStore.baseline(game: dx12Game, plan: dx12Plan)
        try runtimeProfiles.update(protectedRuntimeProfile)
        try Data("different renderer".utf8).write(to: fakeD3D11)
        var runtimeChangeBlocked = false
        do { try runtimeProfiles.verify(dx12Game, plan: dx12Plan) } catch { runtimeChangeBlocked = true }
        try check(runtimeChangeBlocked, "protected games detect a shared renderer binary change by SHA-256")
        try d3d11Bytes.write(to: fakeD3D11)
        try runtimeProfiles.verify(dx12Game, plan: dx12Plan)
        protectedRuntimeProfile.baseline = nil; try runtimeProfiles.update(protectedRuntimeProfile)
        let brokenStore = GameProfileStore(disk: LibraryDisk(root: root.appendingPathComponent("BrokenProfiles")))
        try FileManager.default.createDirectory(at: brokenStore.folder, withIntermediateDirectories: true)
        let brokenBytes = Data("invalid JSON".utf8); try brokenBytes.write(to: brokenStore.file)
        var brokenRejected = false
        do { _ = try brokenStore.register([game]) } catch { brokenRejected = true }
        try check(brokenRejected && (try? Data(contentsOf: brokenStore.file)) == brokenBytes, "malformed compatibility databases fail closed and preserve their original bytes")
        let userReg = disk.logs.appendingPathComponent("gst-registry-x86_64.bin")
        try check((try? Data(contentsOf: userReg)) == bundledRegBytes, "LaunchPlan pre-seeds user GStreamer registry from bundled cache to eliminate cold start scanning")
        let customDXGI = Data("third-party-reshade-dxgi".utf8)
        try customDXGI.write(to: deployedDXGI)
        DirectX12Support.applyGlobal(mode: .dxmt, wine: fakeWineBin.path, games: [dx12Game], disk: disk)
        try check((try? Data(contentsOf: deployedDXGI)) == customDXGI, "third-party dxgi.dll is never deleted when switching global modes")
        try Data("warn: DXGIAdapter: Unknown interface query 17399d75-964e-4c03-99f8-9d4fd196dd62\nD3D12CreateDeviceFailed\n".utf8).write(to: diag.renderer.appendingPathComponent("re3_dxgi.log"))
        let dx12Summary = try SessionDiagnostics.summary(folder: diag.folder)
        try check(dx12Summary.contains("IWineDXGIAdapter") && dx12Summary.contains("Direct3D 12 장치 생성 실패"), "diagnostics identify D3D12 adapter and device creation clues")
        try Data("[mvk-warn] VK_TIMEOUT: Caused GPU Timeout Error\n[mvk-error] VK_ERROR_DEVICE_LOST\n".utf8).write(to: diag.renderer.appendingPathComponent("vulkan-stderr.log"))
        let timeoutSummary = try SessionDiagnostics.summary(folder: diag.folder)
        try check(timeoutSummary.contains("Metal GPU 작업 시간 초과") && timeoutSummary.contains("Vulkan GPU 장치 손실"), "diagnostics distinguish Metal timeout and subsequent device loss")
        try check(RuntimeUpdater.isNewer(remote: "v1.4.2", installed: "v1.4.1") && !RuntimeUpdater.isNewer(remote: "v0.80", installed: "v0.80") && RuntimeUpdater.isNewer(remote: "v10.0_9", installed: "v10.0_8"), "RuntimeUpdater compares semantic and engine versions accurately")
        let mvkJSON = Data(#"{"tag_name":"v1.4.2","assets":[{"name":"MoltenVK-all.tar","browser_download_url":"https://example.com/all.tar"},{"name":"MoltenVK-macos.tar","browser_download_url":"https://example.com/MoltenVK-macos.tar","digest":"sha256:f95765a6229cb7b915990a2890ce12ebe36a730b021545d3d52ae69ce4c4024e","size":46479360}]}"#.utf8)
        let parsedMVK = try RuntimeUpdater.parseReleaseJSON(mvkJSON, for: .moltenvk)
        try check(parsedMVK.version == "v1.4.2" && parsedMVK.asset.name == "MoltenVK-macos.tar" && parsedMVK.asset.sha256 == "f95765a6229cb7b915990a2890ce12ebe36a730b021545d3d52ae69ce4c4024e", "RuntimeUpdater parses MoltenVK release asset and SHA-256 digest")
        let dxmtJSON = Data(#"{"tag_name":"v0.81","assets":[{"name":"dxmt-v0.81-builtin.tar.gz","browser_download_url":"https://example.com/dxmt.tar.gz","digest":"sha256:1234abcd"}]}"#.utf8)
        let parsedDXMT = try RuntimeUpdater.parseReleaseJSON(dxmtJSON, for: .dxmt)
        try check(parsedDXMT.version == "v0.81" && parsedDXMT.asset.name == "dxmt-v0.81-builtin.tar.gz" && parsedDXMT.asset.sha256 == "1234abcd", "RuntimeUpdater parses DXMT builtin release asset")
        let wineJSON = Data(#"{"tag_name":"v1.0","assets":[{"name":"WS12WineSikarugir10.0_8.tar.xz","browser_download_url":"https://example.com/w8.tar.xz"},{"name":"WS12WineSikarugir10.0_9_Battle.Net.tar.xz","browser_download_url":"https://example.com/wb.tar.xz"},{"name":"WS12WineSikarugir10.0_9.tar.xz","browser_download_url":"https://example.com/w9.tar.xz"}]}"#.utf8)
        let parsedWine = try RuntimeUpdater.parseReleaseJSON(wineJSON, for: .wine)
        try check(parsedWine.version == "v10.0_9" && parsedWine.asset.name == "WS12WineSikarugir10.0_9.tar.xz", "RuntimeUpdater selects the newest non-Battle.Net Sikarugir 10.x Wine engine")
        let mvkPkgDir = root.appendingPathComponent("mvk-pkg/MoltenVK/MoltenVK/dynamic/dylib/macOS")
        try FileManager.default.createDirectory(at: mvkPkgDir, withIntermediateDirectories: true)
        let fakeMachO64 = Data([0xcf, 0xfa, 0xed, 0xfe, 0x07, 0x00, 0x00, 0x01]) + Data("MoltenVK-1.4.2-x86_64".utf8)
        try fakeMachO64.write(to: mvkPkgDir.appendingPathComponent("libMoltenVK.dylib"))
        let mvkTar = root.appendingPathComponent("MoltenVK-macos.tar")
        let tarProc = Process()
        tarProc.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        tarProc.arguments = ["-cf", mvkTar.path, "-C", root.appendingPathComponent("mvk-pkg").path, "MoltenVK"]
        try tarProc.run(); tarProc.waitUntilExit()
        let mvkSHA = try RuntimeUpdater.sha256Hex(of: mvkTar)
        try RuntimeUpdater.installLocalArchive(kind: .moltenvk, version: "v1.4.2", archiveURL: mvkTar, expectedSHA256: mvkSHA, runtimeRoot: fakeRuntime, graphicsMode: .dxmt)
        try check(RuntimeUpdater.detectInstalledVersion(for: .moltenvk, runtimeRoot: fakeRuntime) == "v1.4.2" && FileManager.default.fileExists(atPath: fakeRuntime.appendingPathComponent("lib/libMoltenVK.dylib").path), "RuntimeUpdater verifies SHA-256 and installs MoltenVK dylib and version record")
        let oldPlistHead = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<plist version=\"1.0\"><dict><key>CFBundleIdentifier</key><string>org.winehq.wine</string><key>CFBundleExecutable</key><string>wine</string><key>NSPrincipalClass</key><string>WineApplication</string><key>LSUIElement</key><string>1</string>"
        let oldPlistEnd = "</dict>\n</plist>\n"
        let oldEmbedded = Data((oldPlistHead + String(repeating: " ", count: 936 - oldPlistHead.utf8.count - oldPlistEnd.utf8.count) + oldPlistEnd).utf8)
        let oldWine = Data("HEADER".utf8) + oldEmbedded + Data("TAIL".utf8)
        let fixedWine = RuntimeUpdater.patchWineGameModePlist(oldWine)
        let fixedPlist = try PropertyListSerialization.propertyList(from: fixedWine.subdata(in: 6..<(6 + 936)), format: nil) as! [String: Any]
        try check(fixedWine.count == oldWine.count && fixedWine.prefix(6) == oldWine.prefix(6) && fixedWine.suffix(4) == oldWine.suffix(4), "Game Mode patch preserves executable size and bytes outside the plist")
        try check(fixedPlist["LSSupportsGameMode"] as? Bool == true && fixedPlist["LSApplicationCategoryType"] as? String == "public.app-category.games" && fixedPlist["LSUIElement"] == nil, "Game Mode opt-in fits the actual 936-byte Wine plist instead of silently skipping")
        try check(fixedPlist["NSPrincipalClass"] as? String == "WineApplication" && RuntimeUpdater.patchWineGameModePlist(fixedWine) == fixedWine, "Game Mode patch preserves Wine application class and is idempotent")
        let epicClient = EpicClient(disk: disk)
        try check(epicClient.prefix.path == disk.bottles.appendingPathComponent("EpicGames").path, "Epic prefix is located in dedicated Bottles/EpicGames folder")
        try check(EpicClient.arguments.contains("-SkipBuildPatchPrereq") && EpicClient.arguments.contains("-ForceDX11"), "Epic client launches with DirectX prerequisite skip and forced DX11 Metal backend")
        let launcherFixture = epicClient.prefix.appendingPathComponent("drive_c/Program Files/Epic Games/Launcher/Portal/Binaries/Win64/EpicGamesLauncher.exe")
        try FileManager.default.createDirectory(at: launcherFixture.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data([0x4d,0x5a]).write(to: launcherFixture)
        let launcherEntry = try epicClient.entry()
        try check(epicClient.requiresDependencies(launcherEntry), "Epic library launcher entry cannot bypass prerequisite preparation")
        var foreignLauncher = launcherEntry; foreignLauncher.prefix = disk.bottles.appendingPathComponent("OtherEpic").path
        try check(!epicClient.requiresDependencies(foreignLauncher), "Epic prerequisite gate is limited to the managed Epic bottle")
        var epicGame = game
        epicGame.epicAppID = "Sugar"
        try check(GameProfileStore.identity(epicGame) == "epic:Sugar" && GameProfileStore.identity(epicGame) != GameProfileStore.identity(game), "Epic Game identity is prefixed with epic: and separated from generic games")
        let epicDosdevices = epicClient.prefix.appendingPathComponent("dosdevices")
        try FileManager.default.createDirectory(at: epicDosdevices, withIntermediateDirectories: true)
        try storage.syncTo(prefix: epicClient.prefix)
        try check((try? FileManager.default.destinationOfSymbolicLink(atPath: epicDosdevices.appendingPathComponent("d:").path)) == storage.mappingRoot.path, "external storage maps directly into Epic dosdevices")
        let epicManifests = epicClient.prefix.appendingPathComponent("drive_c/ProgramData/Epic/EpicGamesLauncher/Data/Manifests")
        try FileManager.default.createDirectory(at: epicManifests, withIntermediateDirectories: true)
        let epicGameExe = storage.mappingRoot.appendingPathComponent("EpicGames/Cyberpunk2077/bin/x64/Cyberpunk2077.exe")
        try FileManager.default.createDirectory(at: epicGameExe.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data([0x4d, 0x5a]).write(to: epicGameExe)
        let manifestJSON = """
        {
            "AppName": "Sugar",
            "DisplayName": "Cyberpunk 2077",
            "InstallLocation": "D:\\\\EpicGames\\\\Cyberpunk2077",
            "LaunchExecutable": "bin\\\\x64\\\\Cyberpunk2077.exe"
        }
        """
        try Data(manifestJSON.utf8).write(to: epicManifests.appendingPathComponent("Sugar.item"))
        let discoveredEpicGames = try epicClient.installedGames()
        try check(discoveredEpicGames.count == 1 && discoveredEpicGames[0].epicAppID == "Sugar" && discoveredEpicGames[0].name == "Cyberpunk 2077" && discoveredEpicGames[0].path == epicGameExe.path && discoveredEpicGames[0].prefix == epicClient.prefix.path, "Epic JSON manifests discover installed games on mapped external drives")
        storage.unlinkFrom(prefix: epicClient.prefix)
        try check((try? FileManager.default.destinationOfSymbolicLink(atPath: epicDosdevices.appendingPathComponent("d:").path)) == nil && FileManager.default.fileExists(atPath: epicGameExe.path), "unlinkFrom cleanly removes Epic drive mapping while preserving external game files")
        let fakeMSI = root.appendingPathComponent("fake-setup.msi")
        try Data("fake-msi".utf8).write(to: fakeMSI)
        var msiGame = Game(name: "MSI Setup", path: fakeMSI.path, kind: .windows)
        msiGame.arguments = ["/qn"]
        let msiPlan = try LaunchPlan.make(game: msiGame, wine: fakeWineBin.path, disk: disk)
        try check(msiPlan.arguments.starts(with: ["msiexec", "/i", fakeMSI.path, "/qn"]), "LaunchPlan translates .msi Windows installer into wine msiexec invocation")
        try epicClient.prepareEOSDirectories()
        try check(FileManager.default.fileExists(atPath: epicClient.prefix.appendingPathComponent("drive_c/ProgramData/Epic/EpicOnlineServices/EOSInstaller/Logs").path), "prepareEOSDirectories creates required EOS log and binary target paths")
        try check(!epicClient.eosInstalled, "EOS defaults to not installed on fresh bottle")
        try FileManager.default.createDirectory(at: epicClient.eosUserHelper.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data([0x4d, 0x5a]).write(to: epicClient.eosUserHelper)
        try check(epicClient.eosInstalled, "EpicClient correctly detects installed Epic Online Services via UserHelper")
        let fakeLauncherDir = epicClient.prefix.appendingPathComponent("drive_c/Program Files/Epic Games/Launcher/Portal/Binaries/Win64")
        try FileManager.default.createDirectory(at: fakeLauncherDir, withIntermediateDirectories: true)
        let fakeLauncherExe = fakeLauncherDir.appendingPathComponent("EpicGamesLauncher.exe")
        let origTestBytes = Data([0x90, 0x90]) + Data([0x84, 0xc0, 0x0f, 0x85, 0x82, 0x00, 0x00, 0x00, 0x48, 0x8b, 0x0d, 0xba, 0xf7, 0xe8, 0x01, 0x48]) + Data([0xcc, 0xcc])
        try origTestBytes.write(to: fakeLauncherExe)
        let patchApplied = epicClient.applyDirectoryPreparationPatch()
        let patchedBytes = try Data(contentsOf: fakeLauncherExe)
        let expectedPatchBytes = Data([0x90, 0x90]) + Data([0x84, 0xc0, 0xe9, 0x83, 0x00, 0x00, 0x00, 0x90, 0x48, 0x8b, 0x0d, 0xba, 0xf7, 0xe8, 0x01, 0x48]) + Data([0xcc, 0xcc])
        let origBak = fakeLauncherExe.deletingPathExtension().appendingPathExtension("exe.orig")
        try check(patchApplied && patchedBytes == expectedPatchBytes && FileManager.default.fileExists(atPath: origBak.path), "applyDirectoryPreparationPatch safely replaces conditional jump with jmp and preserves backup")
        try check(epicClient.applyDirectoryPreparationPatch(), "applyDirectoryPreparationPatch is idempotent on already patched binary")
        try EpicRendererTests.run(root: root) { value, label in try check(value, label) }
        print("\(checks) checks passed")
    }
}
