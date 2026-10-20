import Foundation

enum EpicRendererTests {
    static func run(root: URL, check: (Bool, String) throws -> Void) throws {
        let disk = LibraryDisk(root: root.appendingPathComponent("EpicRendererTests"))
        let support = EpicRendererSupport(disk: disk)
        var game = Game(name: "renamable", path: root.appendingPathComponent("HogwartsLegacy.exe").path, kind: .windows)
        game.epicAppID = EpicRendererSupport.hogwartsID; game.installedLocation = root.path
        var profile = GameProfile(id: "epic:" + EpicRendererSupport.hogwartsID, name: "unimportant name", engine: "UE4", status: .failing, notes: "candidate")
        let runtime = root.appendingPathComponent("CandidateRuntime")
        let off = try EpicRendererSupport.map(games: [game], profiles: [profile], runtime: runtime)
        try check(!off.contains(EpicRendererSupport.hogwartsID + "=metal"), "Epic Apple candidate defaults to disabled")
        profile.epicMetalFix = true
        try GameProfileStore.validate(profile)
        let on = try EpicRendererSupport.map(games: [game], profiles: [profile], runtime: runtime)
        try check(on.contains("default=dxmt") && on.contains(EpicRendererSupport.hogwartsID + "=metal") && on.contains("Phoenix\\Binaries\\Win64\\HogwartsLegacy.exe"), "Epic exact ID routes its bootstrap and shipping binary while keeping launcher on DXMT")
        var other = game; other.epicAppID = "different-id"
        try check(try !EpicRendererSupport.map(games: [other], profiles: [profile], runtime: runtime).contains(EpicRendererSupport.hogwartsID + "=metal"), "same-name foreign Epic game cannot inherit Hogwarts renderer")
        var invalid = profile; invalid.id = "steam:990080"
        var rejected = false
        do { try GameProfileStore.validate(invalid) } catch { rejected = true }
        try check(rejected, "Epic Apple fix rejects the Steam edition and other identities")
        try FileManager.default.createDirectory(at: support.marker.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(runtime.path.utf8).write(to: support.marker)
        let wine = runtime.appendingPathComponent("bin/wine").path
        var foreignEnv = ["WINEPREFIX": SteamClient(disk: disk).prefix.path, "WINEDLLOVERRIDES":"dxgi=b", "D3DM_MTL4":"1"]
        let original = foreignEnv
        try support.configure(wine: wine, environment: &foreignEnv)
        try check(foreignEnv == original, "Epic Metal configuration preserves the entire Steam environment")
        var env = ["WINEPREFIX": support.prefix.path, "WINEDLLOVERRIDES":"dxgi,d3d12=b;xaudio2_9=b;mshtml="]
        try support.configure(wine: wine, environment: &env)
        try check(env["WINEDLLOVERRIDES"] == "xaudio2_9=b;mshtml=;dxgi,d3d11,d3d12,d3d12core=n,b" && env["D3DM_MTL4"] == "0" && env["WINEMSYNC"] == "1", "Epic router environment preserves audio and uses its paired DXGI/D3D12 components")
        var wrongRuntimeRejected = false
        do { try support.configure(wine: "/different/bin/wine", environment: &env) } catch { wrongRuntimeRejected = true }
        try check(wrongRuntimeRejected, "Epic renderer runtime mismatch fails closed")
        let dll = support.prefix.appendingPathComponent("drive_c/windows/system32/dxgi.dll")
        try FileManager.default.createDirectory(at: dll.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("Epic router".utf8).write(to: dll)
        DirectX12Support.syncPrefix(support.prefix, mode: .dxmt, runtimeRoot: runtime)
        try check(try Data(contentsOf: dll) == Data("Epic router".utf8), "generic prefix preparation cannot replace explicitly installed Epic routers")
        let components = runtime.appendingPathComponent("lib/wine/x86_64-windows")
        try FileManager.default.createDirectory(at: components, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: runtime.appendingPathComponent("bin"), withIntermediateDirectories: true)
        try Data("test wine".utf8).write(to: URL(fileURLWithPath: wine))
        try Data(support.prefix.path.utf8).write(to: runtime.appendingPathComponent("macdeck-shared-renderer.marker"))
        try on.data(using: .utf16)!.write(to: support.marker.deletingLastPathComponent().appendingPathComponent("renderers.ini"))
        let candidate = components.appendingPathComponent("macdeck_metal_d3d12.dll")
        try Data("original Apple candidate".utf8).write(to: candidate)
        let plan = LaunchPlan(executable: URL(fileURLWithPath: wine), arguments: [], environment: ["WINEPREFIX": support.prefix.path], workingDirectory: root)
        let beforeGame = try GameProfileStore.baseline(game: game, plan: plan)
        let beforeOther = try GameProfileStore.baseline(game: other, plan: plan)
        try Data("changed Apple candidate".utf8).write(to: candidate)
        try check(try GameProfileStore.baseline(game: game, plan: plan) != beforeGame && GameProfileStore.baseline(game: other, plan: plan) == beforeOther, "Hogwarts detects Apple candidate changes while another Epic game's DXMT baseline is preserved")
        try Data("original Apple candidate".utf8).write(to: candidate)
        try on.replacingOccurrences(of: "Phoenix\\Binaries\\Win64\\HogwartsLegacy.exe", with: "Other\\HogwartsLegacy.exe").data(using: .utf16)!.write(to: support.marker.deletingLastPathComponent().appendingPathComponent("renderers.ini"))
        try check(try GameProfileStore.baseline(game: game, plan: plan) != beforeGame && GameProfileStore.baseline(game: other, plan: plan) == beforeOther, "exact Epic path-rule changes invalidate only the matching game's baseline")
    }
}
