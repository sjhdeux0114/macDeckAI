import Foundation
import CryptoKit

enum SteamRenderer: String, Codable, CaseIterable {
    case metal, dxmt, vkd3d
    var label: String { switch self { case .metal: return "Apple D3DMetal"; case .dxmt: return "DXMT"; case .vkd3d: return "VKD3D" } }
}

enum GameCompatibilityStatus: String, Codable {
    case untested, userReportedWorking, failing
    var label: String {
        switch self { case .untested: return "미검증"; case .userReportedWorking: return "사용자 구동 확인"; case .failing: return "실행 문제 있음" }
    }
}
struct GameBaseline: Codable, Equatable {
    var settings: [String: String]
    var runtime: [String: String]
}
struct GameProfile: Codable, Identifiable {
    var id: String
    var name: String
    var engine: String
    var status: GameCompatibilityStatus
    var notes: String
    var revision = 1
    var experimentalEnabled = false
    var environment: [String: String] = [:]
    var steamRenderer: SteamRenderer? = nil
    var dmcMetalFix: Bool? = nil
    var dmcClearFix: Bool? = nil
    var dmcSrgbFix: Bool? = nil
    var dmcQueryYieldFix: Bool? = nil
    var hmhMetalFix: Bool? = nil
    var hmhClearFix: Bool? = nil
    var dxmtMarshalFix: Bool? = nil
    var d3d9YieldFix: Bool? = nil
    var requiredRuntimes: [String]? = nil
    var epicMetalFix: Bool? = nil
    var baseline: GameBaseline?
    var updated = Date()
}
struct GameProfileDatabase: Codable {
    var schema = 1
    var games: [GameProfile] = []
}

/// Exact Steam identity wins over names. Renaming a game cannot inherit another game's fixes.
struct GameProfileStore {
    let disk: LibraryDisk
    var folder: URL { disk.root.appendingPathComponent("Compatibility", isDirectory: true) }
    var file: URL { folder.appendingPathComponent("game-profiles.json") }
    static let keys: Set<String> = ["DXMT_CONFIG", "WINE_D3D_CONFIG", "WINEMSYNC", "WINEESYNC", "WINEMSYNC_QLIMIT", "WINE_LARGE_ADDRESS_AWARE", "VKD3D_CONFIG", "MVK_CONFIG_PREFILL_METAL_COMMAND_BUFFERS", "D3DM_MTL4"]

    static func identity(_ game: Game) -> String {
        if let id = game.steamAppID, !id.isEmpty, id.allSatisfy({ $0.isNumber }) {
            return "steam:" + id + (game.trialAppID == id ? ":trial" : "")
        }
        if let id = game.epicAppID, !id.isEmpty {
            return "epic:" + id
        }
        return "local:" + game.id.uuidString
    }
    static var initial: [GameProfile] {
        [
            GameProfile(id: "steam:952060", name: "Resident Evil 3", engine: "RE Engine", status: .userReportedWorking, notes: "과거 사용자 구동 보고: dx11_non-rt. 현재 빌드의 장시간 안정성은 별도 확인 필요. 자동 수정 없음."),
            GameProfile(id: "steam:601150", name: "Devil May Cry 5", engine: "RE Engine", status: .failing, notes: "2026-10-19 Apple 공통 렌더러에서 로딩 중 크래시·macOS 로그아웃 사용자 보고. WindowServer WATCHDOG 기록 확인, 인과관계 미확정. 과거 DXMT GS/TS 수정 후 렉 해소 보고는 보존. 해당 App ID의 DXMT 복귀는 재검증 필요하며 정상 기준을 자동 갱신하지 않음.", revision: 2),
            GameProfile(id: "steam:220440", name: "DmC Devil May Cry", engine: "Unreal Engine 3 / Direct3D 9 / CLR 4", status: .failing, notes: "2026-10-19 실행 직후 종료 사용자 보고. PE32 CLR 4 헤더와 mscoree.dll import 실패 확인. .NET 4 의존성 격리 검증 중. DMC5와 별도 게임이며 공유 Steam의 CLR 설정을 자동 변경하지 않음."),
            GameProfile(id: "steam:214830", name: "Half Minute Hero: Super Mega Neo Climax Ultimate Boy / 용사30", engine: "Direct3D 9", status: .failing, notes: "최신 사용자 보고: 실행 실패. 이전 D9VK 실험은 안정 구동으로 승격하지 않음."),
            GameProfile(id: "steam:1245620", name: "ELDEN RING / 엘든링", engine: "FromSoftware / Direct3D 12", status: .userReportedWorking, notes: "사용자 실기 검증 완료: 1920×1200 해상도 전체화면 60 FPS 구동 확인 (격리 런타임 Apple D3DMetal + MSync1 + Metal3(D3DM_MTL4=0) + SDL 패드 연동). 장시간 플레이 시 발열 및 안정성은 지속 관찰 필요.", revision: 2)
        ]
    }
    func load() throws -> GameProfileDatabase {
        guard FileManager.default.fileExists(atPath: file.path) else { return GameProfileDatabase(games: Self.initial) }
        let value = try JSONDecoder().decode(GameProfileDatabase.self, from: Data(contentsOf: file))
        guard value.schema == 1, Set(value.games.map(\.id)).count == value.games.count else { throw DeckError.message("게임 호환성 DB 형식 또는 중복 ID를 확인하세요. 원본 DB는 보존됩니다.") }
        for profile in value.games { try Self.validate(profile) }
        return value
    }
    static func validate(_ profile: GameProfile) throws {
        guard profile.epicMetalFix != true || (profile.id == "epic:" + EpicRendererSupport.hogwartsID && profile.baseline == nil) else { throw DeckError.message("Epic Metal 시험은 보호 기준 없는 정확한 호그와트 Epic ID에만 허용됩니다.") }
        guard profile.dmcMetalFix != true || (profile.id == "steam:220440" && profile.baseline == nil) else { throw DeckError.message("DmC 직접 Metal 보완은 보호 기준이 없는220440 프로필에만 적용할 수 있습니다.") }
        guard profile.dmcClearFix != true || (profile.id == "steam:220440" && profile.dmcMetalFix == true && profile.baseline == nil) else { throw DeckError.message("DmC Clear experiment requires the exact unprotected direct Metal profile.") }
        guard profile.dmcSrgbFix != true || (profile.id == "steam:220440" && profile.dmcMetalFix == true && profile.dmcClearFix == true && profile.baseline == nil) else { throw DeckError.message("DmC sRGB experiment requires exact unprotected220440 with native Clear fix.") }
        guard profile.dmcQueryYieldFix != true || (profile.id == "steam:220440" && profile.dmcMetalFix == true && profile.dmcClearFix == true && profile.dmcSrgbFix == true && profile.baseline == nil) else { throw DeckError.message("DmC query-yield fix requires exact unprotected220440 with sRGB fix.") }
        guard profile.hmhMetalFix != true || (profile.id == "steam:214830" && profile.baseline == nil) else { throw DeckError.message("용사30 직접 Metal 후보는 보호 기준이 없는 exact App ID214830에만 적용할 수 있습니다.") }
        guard profile.hmhClearFix != true || (profile.id == "steam:214830" && profile.hmhMetalFix == true && profile.baseline == nil) else { throw DeckError.message("용사30 Clear 후보는 exact App ID214830 직접 Metal 프로필에만 적용할 수 있습니다.") }
        guard profile.dxmtMarshalFix != true || (profile.id == "steam:601150" && profile.steamRenderer == .dxmt && profile.baseline == nil) else { throw DeckError.message("GS/TS 보완판은 보호 기준이 없는 DMC5 DXMT 프로필에만 적용할 수 있습니다.") }
        guard profile.d3d9YieldFix != true || (profile.id.hasPrefix("steam:") && profile.baseline == nil) else { throw DeckError.message("D3D9 CPU 스핀 완화(d3d9YieldFix)는 보호 기준이 없는 Steam 프로필에만 적용할 수 있습니다.") }
        guard Set(profile.requiredRuntimes ?? []).isSubset(of: Set(DependencyCatalog.packages.map(\.id))) else { throw DeckError.message("지원하지 않는 필수 런타임 ID입니다.") }
        guard Set(profile.environment.keys).isSubset(of: keys),
              profile.environment.values.allSatisfy({ $0.count <= 4096 && !$0.contains("\n") && !$0.contains("\0") }) else {
            throw DeckError.message("허용되지 않은 게임 프로필 설정입니다. 셸 명령·DLL 배포·전역 변경은 지원하지 않습니다.")
        }
        guard profile.baseline == nil || !profile.experimentalEnabled else { throw DeckError.message("정상 실행 보호와 실험 설정을 동시에 켤 수 없습니다.") }
    }
    func save(_ value: GameProfileDatabase) throws {
        guard value.schema == 1, Set(value.games.map(\.id)).count == value.games.count else { throw DeckError.message("게임 호환성 DB 형식이 올바르지 않습니다.") }
        for profile in value.games { try Self.validate(profile) }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(value).write(to: file, options: .atomic)
    }
    func register(_ games: [Game]) throws -> GameProfileDatabase {
        var value = try load()
        let originalCount = value.games.count
        for game in games where !value.games.contains(where: { $0.id == Self.identity(game) }) {
            value.games.append(GameProfile(id: Self.identity(game), name: game.name, engine: "미확인", status: .untested, notes: "실제 플레이 확인 전에는 정상 구동으로 간주하지 않습니다."))
        }
        if !FileManager.default.fileExists(atPath: file.path) || value.games.count != originalCount { try save(value) }
        return value
    }
    func profile(_ game: Game) throws -> GameProfile {
        try load().games.first { $0.id == Self.identity(game) }
            ?? GameProfile(id: Self.identity(game), name: game.name, engine: "미확인", status: .untested, notes: "아직 실행 검증 기록이 없습니다.")
    }
    func update(_ profile: GameProfile) throws {
        var value = try load(), changed = profile
        changed.revision += 1; changed.updated = Date()
        if let index = value.games.firstIndex(where: { $0.id == profile.id }) {
            let prior = value.games[index]
            let history = folder.appendingPathComponent("History")
            try FileManager.default.createDirectory(at: history, withIntermediateDirectories: true)
            let identity = SHA256.hash(data: Data(prior.id.utf8)).map { String(format: "%02x", $0) }.joined()
            let snapshot = history.appendingPathComponent(identity + "-r" + String(prior.revision) + ".json")
            if !FileManager.default.fileExists(atPath: snapshot.path) { try JSONEncoder().encode(prior).write(to: snapshot, options: .atomic) }
            value.games[index] = changed
        }
        else { value.games.append(changed) }
        try save(value)
    }
    func apply(_ game: Game, environment: inout [String: String]) throws {
        let profile = try profile(game)
        try Self.validate(profile)
        guard profile.experimentalEnabled, !profile.environment.isEmpty else { return }
        // A Steam -applaunch request cannot modify an already-running client's children.
        guard URL(fileURLWithPath: game.path).lastPathComponent.lowercased() != "steam.exe" else {
            throw DeckError.message("이 게임의 실험 설정은 Steam 공유 프로세스에 적용할 수 없습니다. 별도 실행 환경에서 검증하세요. 다른 게임에는 적용하지 않았습니다.")
        }
        let prefix = disk.prefix(for: game).resolvingSymlinksInPath().standardizedFileURL.path
        let steamPrefix = SteamClient(disk: disk).prefix.resolvingSymlinksInPath().standardizedFileURL.path
        let siblings = (try disk.load()).games.filter { $0.id != game.id && $0.kind == .windows }
        guard prefix != steamPrefix, !siblings.contains(where: { disk.prefix(for: $0).resolvingSymlinksInPath().standardizedFileURL.path == prefix }) else {
            throw DeckError.message("공유 Windows 환경에서는 게임별 실험을 적용하지 않습니다. 해당 게임 전용 환경을 선택한 뒤 검증하세요.")
        }
        for (key, value) in profile.environment { environment[key] = value }
    }
    static func baseline(game: Game, plan: LaunchPlan) throws -> GameBaseline {
        var settings = plan.environment.filter { keys.contains($0.key) }
        settings["WINEDLLOVERRIDES"] = plan.environment["WINEDLLOVERRIDES"]
        settings["prefix"] = plan.environment["WINEPREFIX"]
        settings["argumentsSHA256"] = SHA256.hash(data: Data(plan.arguments.joined(separator: "\0").utf8)).map { String(format: "%02x", $0) }.joined()
        var runtime: [String: String] = [:]
        let root = DirectX12Support.runtimeRoot(forWine: plan.executable.path)
        if let root {
            if SharedSteamRuntime.isRuntime(plan.executable.path), let prefix = plan.environment["WINEPREFIX"] {
                let selected = try SharedSteamRuntime.selection(appID: game.steamAppID ?? game.epicAppID, prefix: URL(fileURLWithPath: prefix))
                settings["sharedRenderer"] = selected
                if let id = game.epicAppID {
                    settings["epicIdentity"] = "epic:" + id
                    settings["epicExecutableRules"] = try EpicRendererSupport.executableRules(id: id, prefix: URL(fileURLWithPath: prefix))
                    runtime["epic-renderer-marker"] = try fingerprint(URL(fileURLWithPath: prefix).appendingPathComponent("drive_c/ProgramData/MacDeck/epic-renderers.json"))
                }
                for name in SharedSteamRuntime.modules {
                    runtime["shared-prefix/" + name] = try fingerprint(URL(fileURLWithPath: prefix).appendingPathComponent("drive_c/windows/system32/" + name + ".dll"))
                    let backend = selected == "dxmt" && ["d3d12", "d3d12core"].contains(name) ? "vkd3d" : selected
                    runtime["shared-component/" + name] = try fingerprint(root.appendingPathComponent("lib/wine/x86_64-windows/" + (try SharedSteamRuntime.component(appID: game.steamAppID, module: name, prefix: URL(fileURLWithPath: prefix), renderer: backend))))
                }
                if game.steamAppID == "220440", try SharedSteamRuntime.dmcMetalEnabled(prefix: URL(fileURLWithPath: prefix)) {
                    settings["dmcMetalFix"] = try SharedSteamRuntime.dmcMetalPatch(prefix: URL(fileURLWithPath: prefix)) ?? "dxmt-v1"
                    if settings["dmcMetalFix"] == "dxmt-bind-v3" {
                        runtime["dmc-metal-clear-binding"] = try fingerprint(root.appendingPathComponent("lib/wine/i386-windows/macdeck_dmc_dxmt_clear_v3.dll"))
                    }
                    if settings["dmcMetalFix"] == "dxmt-srgb-v4" {
                        runtime["dmc-metal-srgb"] = try fingerprint(root.appendingPathComponent("lib/wine/i386-windows/macdeck_dmc_dxmt_srgb_v4.dll"))
                    }
                    if settings["dmcMetalFix"] == "dxmt-smooth-v5" {
                        runtime["dmc-metal-srgb"] = try fingerprint(root.appendingPathComponent("lib/wine/i386-windows/macdeck_dmc_dxmt_srgb_v4.dll"))
                        runtime["dmc-query-yield"] = try fingerprint(root.appendingPathComponent("lib/wine/i386-windows/macdeck_dmc_query_yield_v1.dll"))
                    }
                    runtime["dmc-metal-router"] = try fingerprint(root.appendingPathComponent("lib/wine/i386-windows/d3d9.dll"))
                    runtime["dmc-metal-prefix-router"] = try fingerprint(URL(fileURLWithPath: prefix).appendingPathComponent("drive_c/windows/syswow64/d3d9.dll"))
                    runtime["dmc-metal-prefix-alias"] = try fingerprint(URL(fileURLWithPath: prefix).appendingPathComponent("drive_c/windows/syswow64/wm_dmc001.dll"))
                    for relative in ["i386-windows/macdeck_dmc_dxmt_v1.dll", "i386-windows/wm_dmc001.dll", "x86_64-unix/wm_dmc001.so"] {
                        runtime["dmc-metal/" + relative] = try fingerprint(root.appendingPathComponent("lib/wine/" + relative))
                    }
                }
                if game.steamAppID == "214830", try SharedSteamRuntime.hmhMetalEnabled(prefix: URL(fileURLWithPath: prefix)) {
                    settings["hmhMetalFix"] = try SharedSteamRuntime.hmhMetalPatch(prefix: URL(fileURLWithPath: prefix)) ?? "dxmt-v1"
                    runtime["hmh-metal-router"] = try fingerprint(root.appendingPathComponent("lib/wine/i386-windows/d3d9.dll"))
                    runtime["hmh-metal-prefix-router"] = try fingerprint(URL(fileURLWithPath: prefix).appendingPathComponent("drive_c/windows/syswow64/d3d9.dll"))
                    runtime["hmh-metal"] = try fingerprint(root.appendingPathComponent("lib/wine/i386-windows/macdeck_hmh_dxmt_v1.dll"))
                    if settings["hmhMetalFix"] == "dxmt-clear-v2" {
                        runtime["hmh-metal-clear"] = try fingerprint(root.appendingPathComponent("lib/wine/i386-windows/macdeck_hmh_dxmt_clear_v2.dll"))
                    }
                    for relative in ["i386-windows/wm_dmc001.dll", "x86_64-unix/wm_dmc001.so"] {
                        runtime["hmh-metal/" + relative] = try fingerprint(root.appendingPathComponent("lib/wine/" + relative))
                    }
                }
                if let appID = game.steamAppID, try SharedSteamRuntime.d3d9YieldEnabled(prefix: URL(fileURLWithPath: prefix), appID: appID) {
                    settings["d3d9YieldFix"] = "true"
                    runtime["d3d9-yield-helper"] = try fingerprint(root.appendingPathComponent("lib/wine/i386-windows/macdeck_d3d9_yield_helper.dll"))
                }
                if selected == "metal" {
                    runtime["shared-metal-framework"] = try fingerprint(root.appendingPathComponent("lib/external/D3DMetal.framework/Versions/A/D3DMetal"))
                    runtime["shared-metal-bridge"] = try fingerprint(root.appendingPathComponent("lib/external/libd3dshared.dylib"))
                }
            }
            for arch in ["x86_64-windows", "i386-windows"] {
                // Stable source bridges, not the active DXGI selection switched per launch.
                for relative in ["lib/wine/\(arch)/d3d11.dll", "lib/wine/\(arch)/d3d12.dll", "lib/wine/\(arch)/winemetal.dll", "lib/wine/dxgi-dxmt/\(arch)/dxgi.dll", "lib/wine/dxgi-d3d12/\(arch)/dxgi.dll"] {
                    runtime[relative] = try fingerprint(root.appendingPathComponent(relative))
                }
            }
            runtime["lib/libMoltenVK.dylib"] = try fingerprint(root.appendingPathComponent("lib/libMoltenVK.dylib"))
            runtime["wine"] = try fingerprint(plan.executable)
            if game.trialAppID == "1245620" {
                for relative in ["lib/wine/x86_64-windows/dxgi.dll", "lib/wine/x86_64-windows/d3d12core.dll", "lib/external/libd3dshared.dylib", "lib/external/D3DMetal.framework/Versions/A/D3DMetal", "lib/external/D3DMetal.framework/Versions/A/Resources/libmetalirconverter.dylib"] {
                    runtime[relative] = try fingerprint(root.appendingPathComponent(relative))
                }
            }
        }
        // Include game-local renderers/configs: protected games notice manual proxy changes too.
        if let prefix = plan.environment["WINEPREFIX"] {
            for (relative, file) in DependencyInstaller.trackedFiles(prefix: URL(fileURLWithPath: prefix)) { runtime["dependency/" + relative] = try fingerprint(file) }
        }
        if let folder = DirectX12Support.targetDirectory(for: game) {
            for name in ["d3d9.dll", "dxgi.dll", "d3d11.dll", "dxvk.conf"] { runtime["game/" + name] = try fingerprint(folder.appendingPathComponent(name)) }
        }
        return GameBaseline(settings: settings, runtime: runtime)
    }
    private static func fingerprint(_ url: URL) throws -> String {
        guard FileManager.default.fileExists(atPath: url.path) else { return "absent" }
        let handle = try FileHandle(forReadingFrom: url); defer { try? handle.close() }
        var hash = SHA256()
        while let data = try handle.read(upToCount: 1_048_576), !data.isEmpty { hash.update(data: data) }
        return hash.finalize().map { String(format: "%02x", $0) }.joined()
    }
    func verify(_ game: Game, plan: LaunchPlan) throws {
        guard let expected = try profile(game).baseline else { return }
        let actual = try Self.baseline(game: game, plan: plan)
        guard actual == expected else {
            throw DeckError.message("\(game.name)의 정상 실행 보호 설정 또는 런타임이 변경되었습니다. 다른 게임용 수정을 그대로 적용하지 않고 실행을 멈췄습니다. 게임 관리에서 기준을 확인하거나 보호를 해제한 뒤 검증하세요.")
        }
    }
}
