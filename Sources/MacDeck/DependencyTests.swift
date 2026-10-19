import Foundation

enum DependencyTests {
    static func run(root: URL, check: (Bool, String) throws -> Void) throws {
        try check(["vc2005-x86","vc2005-x64","vc2008-x86","vc2008-x64"].allSatisfy { DependencyCatalog.package($0)?.arguments == ["/q"] } && DependencyCatalog.package("vc2010-x86")?.arguments == ["/q","/norestart"], "legacy VC2005/2008 wrappers use their supported quiet syntax without changing newer installer options")
        try check(DependencyCatalog.package("dotnet40")?.arguments == ["/q","/c:install.exe /q"], ".NET4 full bootstrapper passes the quiet option to its inner installer")
        try check(DependencyDiscovery.packageID(path: "%INSTALLDIR%\\redist\\vcredist_x86.exe", hint: "Microsoft VC Redist Package 2005") == "vc2005-x86", "dependency VDF resolves the exact VC2005 architecture without executing its command")
        try check(DependencyDiscovery.packageID(path: "_CommonRedist/vcredist/2015/vc_redist.x64.exe", hint: "") == "vc2022-x64", "VC2015-2022 uses its compatible catalog family and preserves x64")
        try check(DependencyDiscovery.packageID(path: "vcredist_x86.exe", hint: "") == nil && DependencyDiscovery.packageID(path: "cmd.exe", hint: "vcredist 2005") == nil, "ambiguous packages and arbitrary installer commands are not executable requirements")
        try check(DependencyDiscovery.packageID(path: "dotNetFx40_Client_x86_x64.exe", hint: "") == "dotnet40", "DmC bundled .NET4 client requirements resolve without guessing from game names")
        let gameRoot = root.appendingPathComponent("DependencyGame")
        try FileManager.default.createDirectory(at: gameRoot, withIntermediateDirectories: true)
        let vdf = "\"installscript\" { \"Run Process\" { \"vc\" { \"process 1\" \"%INSTALLDIR%\\\\redist\\\\vcredist_x86.exe\" \"description\" \"VC 2010\" \"command 1\" \"malicious --do-not-run\" } } }"
        try Data(vdf.utf8).write(to: gameRoot.appendingPathComponent("installscript.vdf"))
        var a = Game(name: "same name", path: "/fake/steam.exe", kind: .windows); a.steamAppID = "220440"; a.installedLocation = gameRoot.path
        var b = a; b.steamAppID = "1245620"
        var pa = GameProfile(id: "steam:220440", name: "first", engine: "", status: .untested, notes: "")
        pa.requiredRuntimes = ["dotnet40"]
        var pb = pa; pb.id = "steam:1245620"; pb.requiredRuntimes = ["dotnet48"]
        let plan = try DependencyDiscovery.plan(games: [a,b], profiles: [pa,pb])
        try check(plan.contains(DependencyNeed(packageID: "dotnet48", appIDs: ["1245620","220440"])) && !plan.contains { $0.packageID == "dotnet40" }, ".NET4 in-place families coalesce to the highest requested version and preserve source App IDs")
        try check(try DependencyDiscovery.requirements(game: a, profile: nil) == ["vc2010-x86"], "game installscript arguments never become installer arguments")
        let prefix = root.appendingPathComponent("PolicyPrefix")
        var env = ["WINEDLLOVERRIDES":"mscoree,mshtml=;d3d11,dxgi=b", "WINEMSYNC":"1"]
        let original = env
        try DependencyInstaller.applyCLRPolicy(prefix: prefix, environment: &env)
        try check(env == original, "prefixes without an installed CLR policy keep their launch environment unchanged")
        let policyFile = prefix.appendingPathComponent("drive_c/ProgramData/MacDeck/clr-policy.json")
        try FileManager.default.createDirectory(at: policyFile.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(CLRLoadPolicy(applications: ["220440":["dmc-devilmaycry.exe"]])).write(to: policyFile)
        try DependencyInstaller.applyCLRPolicy(prefix: prefix, environment: &env)
        try check(env == ["WINEDLLOVERRIDES":"mshtml=;d3d11,dxgi=b", "WINEMSYNC":"1"], "CLR activation removes only the veto and preserves graphics and synchronization settings")
        let bad = root.appendingPathComponent("not-a-native.dll")
        try Data([0x4d,0x5a] + Array(repeating: UInt8(0), count: 510)).write(to: bad)
        try check(!DependencyInstaller.nativePE(bad), "an MZ placeholder cannot satisfy runtime installation detection")
        try check(Set(DependencyCatalog.packages.map(\.id)).count == DependencyCatalog.packages.count && DependencyCatalog.packages.allSatisfy { $0.sha256.count == 64 && $0.url.hasPrefix("https://") }, "redistributable catalog has unique IDs and HTTPS SHA256 pins")
        let listing = "\"services.exe\",\"1\"\n\"tasklist.exe\",\"2\"\n\"eldenring.exe\",\"3\"\n"
        try check(DependencyInstaller.unexpectedProcesses(listing) == ["eldenring.exe"], "dependency maintenance refuses a game running in the same prefix")
        var inventory = a; inventory.steamAppID = "228980"
        try check(try DependencyDiscovery.requirements(game: inventory, profile: pa).isEmpty, "Steamworks shared installer inventory is not treated as every game's requirements")
        try check(PEDependencies.requirements(file: bad).isEmpty, "malformed PE headers cannot synthesize redistributable requirements")
        var pe = Data(repeating: 0, count: 1024)
        func put(_ offset: Int, _ value: UInt32) { for i in 0..<4 { pe[offset+i] = UInt8((value >> (i*8)) & 255) } }
        pe[0]=0x4d; pe[1]=0x5a; put(60,128); put(128,0x4550)
        pe[132]=0x4c; pe[133]=1; pe[134]=1; pe[148]=224; pe[152]=0x0b; pe[153]=1
        put(152+96+14*8,0x1080); put(152+96+14*8+4,72)
        put(376+12,0x1000); put(376+16,512); put(376+20,512)
        put(640+8,0x1100); put(768,0x424a5342)
        for (i,c) in "v4.0.30319".utf8.enumerated() { pe[784+i]=c }
        let clrEXE = root.appendingPathComponent("managed.exe"), clrDLL = root.appendingPathComponent("managed.dll")
        try pe.write(to: clrEXE); try pe.write(to: clrDLL)
        try check(PEDependencies.requirements(file: clrEXE) == ["dotnet40"] && PEDependencies.requirements(file: clrDLL).isEmpty, "CLR executable detection does not install Windows .NET for Unity/Mono managed DLLs")
        let tracking = prefix.appendingPathComponent("drive_c/ProgramData/MacDeck/dependencies-enabled.json")
        try Data("{\"schema\":1}".utf8).write(to: tracking)
        let protectedPlan = LaunchPlan(executable: URL(fileURLWithPath: "/usr/bin/true"), arguments: [], environment: ["WINEPREFIX":prefix.path], workingDirectory: root)
        let beforeRuntime = try GameProfileStore.baseline(game: a, plan: protectedPlan)
        let vc = prefix.appendingPathComponent("drive_c/windows/syswow64/msvcp100.dll")
        try FileManager.default.createDirectory(at: vc.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("changed dependency".utf8).write(to: vc)
        let afterRuntime = try GameProfileStore.baseline(game: a, plan: protectedPlan)
        try check(beforeRuntime != afterRuntime && beforeRuntime.runtime["dependency/syswow64/msvcp100.dll"] == "absent", "normal-game baselines detect a shared redistributable change without auto-approving it")
        try check(DependencyInstaller.trackedFiles(prefix: root.appendingPathComponent("OtherPrefix")).isEmpty, "dependency tracking never touches another prefix")
        var invalid = pa; invalid.requiredRuntimes = ["arbitrary-shell-command"]
        var rejected = false
        do { try GameProfileStore.validate(invalid) } catch { rejected = true }
        try check(rejected, "profiles cannot inject arbitrary packages into automatic dependency installation")
    }
}
