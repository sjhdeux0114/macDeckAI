import Foundation
import CryptoKit
import Darwin

struct DependencyNeed: Codable, Equatable {
    var packageID: String
    var appIDs: [String]
}
struct DependencyAttempt: Codable {
    var packageID: String
    var appIDs: [String]
    var started: Date
    var finished: Date?
    var status: String
    var exitCode: Int32?
    var installerSHA256: String
    var detail: String
}

/// Only Microsoft's pinned catalog is executable. VDF contributes requirements,
/// never executable paths, arguments, registry writes or success markers.
enum DependencyDiscovery {
    static func packageID(path: String, hint: String) -> String? {
        let p = path.lowercased(), h = hint.lowercased()
        let text = p + " " + h
        if text.contains("dotnet") || text.contains(".net") {
            if text.contains("481") || text.contains("4.8.1") { return nil }
            if text.contains("48") || text.contains("4.8") { return "dotnet48" }
            if text.contains("47") || text.contains("4.7") { return "dotnet472" }
            if text.contains("46") || text.contains("4.6") || text.contains("451") || text.contains("452") || text.contains("4.5.1") || text.contains("4.5.2") { return "dotnet462" }
            if text.contains("45") || text.contains("4.5") { return "dotnet45" }
            if text.contains("40") || text.contains("4.0") || h == "dotnet_4" { return "dotnet40" }
            if text.contains("35") || text.contains("3.5") || text.contains("2.0") { return "dotnet35sp1" }
            return nil
        }
        guard p.contains("vcredist") || p.contains("vc_redist") else { return nil }
        let arch: String
        if p.contains("x64") || p.contains("amd64") { arch = "x64" }
        else if p.contains("x86") { arch = "x86" }
        else { return nil }
        for year in [2022, 2019, 2017, 2015, 2013, 2012, 2010, 2008, 2005] where text.contains(String(year)) {
            return "vc\(year >= 2015 ? 2022 : year)-" + arch
        }
        return nil // ambiguous redistributables must never guess a version.
    }
    static func requirements(game: Game, profile: GameProfile? = nil) throws -> [String] {
        guard let id = game.steamAppID, !id.isEmpty, id.allSatisfy({ $0.isNumber }), let location = game.installedLocation else { return [] }
        guard id != "228980" else { return [] } // Steamworks Shared Redistributables is inventory, not a game's requirements.
        var found = Set((profile?.requiredRuntimes ?? []).filter { DependencyCatalog.package($0) != nil })
        let root = URL(fileURLWithPath: location)
        guard FileManager.default.fileExists(atPath: root.path) else { return [] }
        found.formUnion(PEDependencies.requirements(in: root))
        let script = root.appendingPathComponent("installscript.vdf")
        if FileManager.default.fileExists(atPath: script.path) {
            let attrs = try FileManager.default.attributesOfItem(atPath: script.path)
            guard ((attrs[.size] as? NSNumber)?.intValue ?? Int.max) <= 1_048_576 else { throw DeckError.message("설치 요구 목록이 너무 큽니다: App ID " + id) }
            let values = try VDF.parse(String(contentsOf: script, encoding: .utf8))
            let processes = values["installscript"]?.object?["run process"]?.object ?? [:]
            for (name, value) in processes {
                guard let entry = value.object else { continue }
                let hint = name + " " + (entry["description"]?.string ?? "")
                for (key, value) in entry where key.hasPrefix("process ") {
                    if let path = value.string, let package = packageID(path: path, hint: hint) { found.insert(package) }
                }
            }
        }
        // Standard Steamworks redistributable directories only, bounded traversal.
        for relative in ["_CommonRedist", "redist"] {
            let base = root.appendingPathComponent(relative)
            func scan(_ directory: URL, depth: Int) throws {
                guard depth < 5, let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey]) else { return }
                for file in files.prefix(256) {
                    let values = try file.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
                    guard values.isSymbolicLink != true else { continue }
                    if values.isDirectory == true { try scan(file, depth: depth + 1) }
                    else if file.pathExtension.lowercased() == "exe", let id = packageID(path: file.path.replacingOccurrences(of: root.path, with: ""), hint: "") { found.insert(id) }
                }
            }
            try scan(base, depth: 0)
        }
        return found.sorted()
    }
    static func plan(games: [Game], profiles: [GameProfile]) throws -> [DependencyNeed] {
        var packages: [String: Set<String>] = [:]
        for game in games {
            for id in try requirements(game: game, profile: profiles.first { $0.id == GameProfileStore.identity(game) }) {
                packages[id, default: []].insert(game.steamAppID!)
            }
        }
        let four = ["dotnet40", "dotnet45", "dotnet462", "dotnet472", "dotnet48"]
        let requested = four.filter { packages[$0] != nil }
        if let selected = requested.last {
            let ids = requested.reduce(into: Set<String>()) { $0.formUnion(packages[$1] ?? []) }
            for id in requested { packages.removeValue(forKey: id) }
            packages[selected] = ids
        }
        return packages.keys.sorted().map { DependencyNeed(packageID: $0, appIDs: packages[$0]!.sorted()) }
    }
}

actor DependencyInstaller {
    let disk: LibraryDisk
    let prefix: URL
    let wine: URL
    var folder: URL { disk.root.appendingPathComponent("Dependencies") }
    var key: String { SHA256.hash(data: Data(prefix.standardizedFileURL.path.utf8)).map { String(format: "%02x", $0) }.joined() }
    var state: URL { folder.appendingPathComponent(key) }
    init(disk: LibraryDisk, prefix: URL, wine: String) { self.disk = disk; self.prefix = prefix; self.wine = URL(fileURLWithPath: wine) }
    static func digest(_ url: URL) throws -> String {
        let input = try FileHandle(forReadingFrom: url); defer { try? input.close() }
        var hash = SHA256()
        while let data = try input.read(upToCount: 1_048_576), !data.isEmpty { hash.update(data: data) }
        return hash.finalize().map { String(format: "%02x", $0) }.joined()
    }
    func environment() -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        env["WINEPREFIX"] = prefix.path; env["WINEDEBUG"] = "-all"
        env["WINEMSYNC"] = "1"; env["WINEESYNC"] = "0"
        env["WINEDLLOVERRIDES"] = "winemenubuilder.exe=d;winedbg.exe=d;mscoree,mshtml=;fusion=b"
        env["DYLD_FALLBACK_LIBRARY_PATH"] = wine.deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("lib").path
        return env
    }
    func command(_ args: [String], timeout: TimeInterval = 20, capture: Bool = false, nativeCLR: Bool = false, installerCLR: Bool = false) async throws -> (Int32, String) {
        let p = Process(), pipe = Pipe()
        p.executableURL = wine; p.arguments = args; p.environment = environment()
        if nativeCLR { p.environment?["WINEDLLOVERRIDES"] = "winemenubuilder.exe=d;winedbg.exe=d;mshtml=;mscoree=n" }
        if installerCLR { p.environment?["WINEDLLOVERRIDES"] = "winemenubuilder.exe=d;winedbg.exe=d;mshtml=;fusion=b" }
        p.standardOutput = capture ? pipe.fileHandleForWriting : FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        try p.run()
        defer { if p.isRunning { p.terminate() } }
        let end = Date().addingTimeInterval(timeout)
        while p.isRunning && Date() < end { try Task.checkCancellation(); try await Task.sleep(nanoseconds: 100_000_000) }
        guard !p.isRunning else { p.terminate(); throw DeckError.message("필수 런타임 작업 시간이 초과되었습니다. 설치 완료로 기록하지 않았습니다.") }
        if capture {
            try? pipe.fileHandleForWriting.close()
            let data = try pipe.fileHandleForReading.read(upToCount: 65536) ?? Data()
            return (p.terminationStatus, String(decoding: data, as: UTF8.self))
        }
        return (p.terminationStatus, "")
    }
    func registry(_ path: String, name: String, arch: String = "x86") async throws -> String? {
        let result = try await command(["reg", "query", path, "/v", name, arch == "x64" ? "/reg:64" : "/reg:32"], capture: true)
        guard result.0 == 0 else { return nil }
        return result.1.components(separatedBy: .newlines).first { $0.trimmingCharacters(in: .whitespaces).hasPrefix(name + " ") }.flatMap { line in
            for type in ["REG_DWORD", "REG_SZ"] { if let range = line.range(of: type) { return line[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines) } }
            return nil
        }
    }
    static func nativePE(_ file: URL, architecture: String? = nil) -> Bool {
        guard let input = try? FileHandle(forReadingFrom: file) else { return false }; defer { try? input.close() }
        guard let bytes = try? input.read(upToCount: 4096), bytes.starts(with: [0x4d,0x5a]), bytes.count > 256 else { return false }
        let pe = (0..<4).reduce(0) { $0 | Int(bytes[60 + $1]) << ($1 * 8) }
        guard pe >= 64, pe + 24 < bytes.count, bytes[pe..<pe+4].elementsEqual([0x50,0x45,0,0]) else { return false }
        let machine = Int(bytes[pe+4]) | Int(bytes[pe+5]) << 8
        if let architecture, machine != (architecture == "x64" ? 0x8664 : 0x14c) { return false }
        return bytes.range(of: DirectX12Support.wineBuiltinMarker) == nil && bytes.range(of: DirectX12Support.wineNativeMarker) == nil
    }
    func isInstalled(_ package: DependencyPackage) async throws -> Bool {
        let windows = prefix.appendingPathComponent("drive_c/windows")
        if package.isCLR {
            let version = package.id == "dotnet35sp1" ? "v3.5" : "v4\\Full"
            let base = "HKLM\\Software\\Microsoft\\NET Framework Setup\\NDP\\" + version
            let install = try await registry(base, name: "Install")
            // Client Profile is sufficient only for 4.0 requirements, never for 4.5+.
            let client = package.id == "dotnet40" ? try await registry("HKLM\\Software\\Microsoft\\NET Framework Setup\\NDP\\v4\\Client", name: "Install") : nil
            guard install == "0x1" || client == "0x1" else { return false }
            if let minimum = ["dotnet45":378389, "dotnet462":394802, "dotnet472":461808, "dotnet48":528040][package.id] {
                guard let value = try await registry(base, name: "Release"), let release = Int(value.replacingOccurrences(of: "0x", with: ""), radix: 16), release >= minimum else { return false }
            }
            let clr = package.id == "dotnet35sp1" ? "Framework/v2.0.50727/mscorwks.dll" : "Framework/v4.0.30319/clr.dll"
            let wow64 = FileManager.default.fileExists(atPath: windows.appendingPathComponent("syswow64").path)
            guard Self.nativePE(windows.appendingPathComponent("Microsoft.NET/" + clr), architecture: "x86"), Self.nativePE(windows.appendingPathComponent((wow64 ? "syswow64" : "system32") + "/mscoree.dll"), architecture: "x86") else { return false }
            if wow64 { return Self.nativePE(windows.appendingPathComponent("Microsoft.NET/" + clr.replacingOccurrences(of: "Framework/", with: "Framework64/")), architecture: "x64") && Self.nativePE(windows.appendingPathComponent("system32/mscoree.dll"), architecture: "x64") }
            return true
        }
        let year = package.family.replacingOccurrences(of: "vcrun", with: "")
        if ["2005", "2008"].contains(year) {
            let tag = year == "2005" ? "80" : "90"
            let sxs = windows.appendingPathComponent("winsxs")
            let directories = (try? FileManager.default.contentsOfDirectory(at: sxs, includingPropertiesForKeys: nil)) ?? []
            let arch = package.architecture == "x64" ? "amd64_" : "x86_"
            return directories.contains { $0.lastPathComponent.lowercased().hasPrefix(arch + "microsoft.vc" + tag + ".crt_") && Self.nativePE($0.appendingPathComponent("msvcr" + tag + ".dll")) && Self.nativePE($0.appendingPathComponent("msvcp" + tag + ".dll")) }
        }
        let number = ["2010":"100", "2012":"110", "2013":"120", "2022":"140"][year]!
        let system = windows.appendingPathComponent(package.architecture == "x64" ? "system32" : "syswow64")
        return Self.nativePE(system.appendingPathComponent("msvcp" + number + ".dll"), architecture: package.architecture) && Self.nativePE(system.appendingPathComponent(number == "140" ? "vcruntime140.dll" : "msvcr" + number + ".dll"), architecture: package.architecture)
    }
    func download(_ package: DependencyPackage) async throws -> URL {
        let cache = folder.appendingPathComponent("Cache")
        try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
        let file = cache.appendingPathComponent(package.id + "-" + package.sha256 + ".exe")
        if FileManager.default.fileExists(atPath: file.path), try Self.digest(file) == package.sha256 { return file }
        let (temporary, response) = try await URLSession.shared.download(from: URL(string: package.url)!)
        defer { try? FileManager.default.removeItem(at: temporary) }
        guard let response = response as? HTTPURLResponse, response.statusCode == 200,
              response.url?.scheme == "https", let host = response.url?.host,
              ["download.microsoft.com", "download.visualstudio.microsoft.com", "aka.ms"].contains(host),
              try Self.digest(temporary) == package.sha256 else {
            throw DeckError.message(package.label + ": 공식 다운로드 또는 SHA-256 검증 실패. 실행하지 않았습니다.")
        }
        let data = try Data(contentsOf: temporary, options: .mappedIfSafe)
        guard data.starts(with: [0x4d,0x5a]) else { throw DeckError.message("Windows 설치 파일이 아닙니다.") }
        try data.write(to: file, options: .atomic)
        return file
    }
    func verifyCLR(_ package: DependencyPackage) async throws {
        let version = package.id == "dotnet35sp1" ? "v2.0.50727" : "v4.0.30319"
        let folder = prefix.appendingPathComponent("drive_c/ProgramData/MacDeck/DependencyProbe")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let source = folder.appendingPathComponent("Probe.cs"), exe = folder.appendingPathComponent("Probe.exe")
        try Data("using System; class Probe { static int Main() { try { int z=int.Parse(\"0\"); Console.WriteLine(1/z); return 1; } catch(DivideByZeroException) {} Console.WriteLine(\"MACDECK_CLR_OK\"); return 0; } }".utf8).write(to: source, options: .atomic)
        let compiler = prefix.appendingPathComponent("drive_c/windows/Microsoft.NET/Framework/" + version + "/csc.exe")
        let windowsSource = "C:\\ProgramData\\MacDeck\\DependencyProbe\\Probe.cs"
        let windowsEXE = "C:\\ProgramData\\MacDeck\\DependencyProbe\\Probe.exe"
        let architectures = FileManager.default.fileExists(atPath: prefix.appendingPathComponent("drive_c/windows/syswow64").path) ? ["x86","x64"] : ["x86"]
        for architecture in architectures {
            let compiled = try await command([compiler.path, "/nologo", "/platform:" + architecture, "/out:" + windowsEXE, windowsSource], nativeCLR: true)
            guard compiled.0 == 0, FileManager.default.fileExists(atPath: exe.path) else { throw DeckError.message(".NET 컴파일/초기화 검사 실패: " + architecture) }
            let tested = try await command([exe.path], capture: true, nativeCLR: true)
            guard tested.0 == 0, tested.1.contains("MACDECK_CLR_OK") else { throw DeckError.message(".NET 실행/예외 처리 검사 실패: " + architecture) }
        }
    }
    func install(_ package: DependencyPackage, file: URL) async throws -> (Int32,String) {
        guard package.isCLR else { return try await command([file.path] + package.arguments, timeout: 180) }
        // This is a maintenance operation with Steam/games stopped. Older .NET
        // setup programs reject modern OS versions; restore the exact old value.
        let key = "HKCU\\Software\\Wine"
        let before = try await registry(key, name: "Version", arch: "x64")
        try JSONEncoder().encode(["Version": before]).write(to: state.appendingPathComponent("windows-version-before.json"), options: .atomic)
        let pending = state.appendingPathComponent("windows-version-restore-required.json")
        try JSONEncoder().encode(["Version": before]).write(to: pending, options: .atomic)
        let target = ["dotnet35sp1","dotnet40"].contains(package.id) ? "winxp" : "win7"
        let changed = try await command(["reg","add",key,"/v","Version","/t","REG_SZ","/d",target,"/f"])
        guard changed.0 == 0 else { throw DeckError.message(".NET 설치용 Windows 버전을 설정하지 못했습니다.") }
        func restore() async throws {
            let args = before.map { ["reg","add",key,"/v","Version","/t","REG_SZ","/d",$0,"/f"] } ?? ["reg","delete",key,"/v","Version","/f"]
            let result = try await command(args)
            guard result.0 == 0 else { throw DeckError.message(".NET 설치 후 Windows 버전 복구 실패. Steam을 시작하지 말고 설치 기록을 확인하세요.") }
            try FileManager.default.removeItem(at: pending)
        }
        do {
            let result = try await command([file.path] + package.arguments, timeout: 480, installerCLR: true)
            try await restore(); return result
        } catch { try await restore(); throw error }
    }
    func ensureReadyForSteam() throws {
        guard !FileManager.default.fileExists(atPath: state.appendingPathComponent("windows-version-restore-required.json").path) else { throw DeckError.message("이전 .NET 설치의 Windows 버전 복구가 필요합니다. 런타임 다시 준비를 실행하세요.") }
    }
    static func unexpectedProcesses(_ listing: String) -> [String] {
        let allowed: Set<String> = ["tasklist.exe","services.exe","explorer.exe","plugplay.exe","svchost.exe","winedevice.exe","rpcss.exe","conhost.exe","winemenubuilder.exe","reg.exe","mscorsvw.exe","start.exe"]
        return listing.components(separatedBy: .newlines).compactMap { line -> String? in
            guard line.hasPrefix("\""), let end = line.dropFirst().firstIndex(of: "\"") else { return nil }
            let name = String(line[line.index(after: line.startIndex)..<end]).lowercased()
            return name.hasSuffix(".exe") && !allowed.contains(name) ? name : nil
        }
    }
    func assertIdlePrefix() async throws {
        let result = try await command(["tasklist", "/fo", "csv", "/nh"], capture: true)
        guard result.0 == 0, result.1.contains("tasklist.exe") else { throw DeckError.message("Wine 환경의 실행 상태를 확인하지 못해 설치를 보류했습니다.") }
        let unexpected = Self.unexpectedProcesses(result.1)
        guard unexpected.isEmpty else { throw DeckError.message("Wine 게임 또는 다른 작업이 실행 중입니다: " + unexpected.prefix(8).joined(separator: ", ") + ". 종료한 뒤 필수 런타임을 다시 준비하세요.") }
    }
    func restorePendingVersion() async throws {
        let file = state.appendingPathComponent("windows-version-restore-required.json")
        guard FileManager.default.fileExists(atPath: file.path) else { return }
        let values = try JSONDecoder().decode([String:String?].self, from: Data(contentsOf: file))
        let value = values["Version"] ?? nil
        let args = value.map { ["reg","add","HKCU\\Software\\Wine","/v","Version","/t","REG_SZ","/d",$0,"/f"] } ?? ["reg","delete","HKCU\\Software\\Wine","/v","Version","/f"]
        guard try await command(args).0 == 0 else { throw DeckError.message("이전 설치의 Windows 버전 복구 실패") }
        try FileManager.default.removeItem(at: file)
    }
    func prepare(_ needs: [DependencyNeed], retry: Bool = false, progress: @Sendable (String) async -> Void) async throws -> [String] {
        guard !needs.isEmpty || FileManager.default.fileExists(atPath: state.appendingPathComponent("windows-version-restore-required.json").path) else { return [] }
        try FileManager.default.createDirectory(at: state, withIntermediateDirectories: true)
        let lock = open(state.appendingPathComponent("install.lock").path, O_CREAT | O_RDWR | O_CLOEXEC | O_NOFOLLOW, S_IRUSR | S_IWUSR)
        guard lock >= 0 else { throw DeckError.message("필수 런타임 잠금 파일을 열 수 없습니다.") }
        defer { flock(lock, LOCK_UN); close(lock) }
        guard flock(lock, LOCK_EX | LOCK_NB) == 0 else { throw DeckError.message("다른 필수 런타임 설치가 진행 중입니다.") }
        guard !(try await SteamStorage(client: SteamClient(disk: disk)).isRunning(wine: wine.path)) else { return ["Steam 실행 중: 필수 런타임 설치는 다음 시작 때 진행합니다."] }
        try await assertIdlePrefix()
        try await restorePendingVersion()
        var failures: [String] = []
        for need in needs {
            try Task.checkCancellation()
            guard let package = DependencyCatalog.package(need.packageID) else { continue }
            await progress("필수 런타임 확인: " + package.label)
            let receipt = state.appendingPathComponent(package.id + ".json")
            if !retry, let bytes = try? Data(contentsOf: receipt), let prior = try? JSONDecoder().decode(DependencyAttempt.self, from: bytes), prior.status != "installed", Date().timeIntervalSince(prior.started) < 86400 {
                failures.append(package.label + ": 이전 실패 기록이 있어 자동 반복하지 않았습니다. 필수 런타임 다시 준비를 사용하세요."); continue
            }
            var record = DependencyAttempt(packageID: package.id, appIDs: need.appIDs, started: Date(), status: "preparing", installerSHA256: package.sha256, detail: "No game or authentication files collected.")
            func save() throws { let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted,.sortedKeys]; try encoder.encode(record).write(to: receipt, options: .atomic) }
            if let prior = try? Data(contentsOf: receipt), (try? JSONDecoder().decode(DependencyAttempt.self, from: prior)) != nil {
                let history = state.appendingPathComponent("History")
                try FileManager.default.createDirectory(at: history, withIntermediateDirectories: true)
                try prior.write(to: history.appendingPathComponent(package.id + "-" + UUID().uuidString + ".json"), options: .atomic)
            }
            try save()
            do {
                if try await isInstalled(package) {
                    if package.isCLR { try await verifyCLR(package) }
                    record.status = "installed"; record.finished = Date(); record.detail = "Existing native runtime verified; installer not rerun; game play unverified."
                    try save(); continue
                }
                if let free = try prefix.resourceValues(forKeys: [.volumeAvailableCapacityKey]).volumeAvailableCapacity, free < 2_000_000_000 { throw DeckError.message("필수 런타임 설치 공간이 부족합니다. Wine 환경 볼륨에 2GB 이상 확보하세요.") }
                let installer = try await download(package)
                await progress("필수 런타임 설치: " + package.label)
                record.status = "installing"; try save()
                try enableTracking()
                let result = try await install(package, file: installer)
                record.exitCode = result.0
                guard [0,194,102].contains(result.0), try await isInstalled(package) else { throw DeckError.message("설치 후 버전/네이티브 파일 확인 실패 (종료 \(result.0)).") }
                if package.isCLR { try await verifyCLR(package) }
                record.status = "installed"; record.finished = Date(); record.detail = result.0 == 194 ? "Installed; prefix restart required." : "Native runtime postconditions verified; game play is unverified."
                try save()
            } catch {
                let wasInstalling = record.status == "installing"
                record.status = "failed"; record.finished = Date(); record.detail = error.localizedDescription; try save()
                failures.append(package.label + ": " + error.localizedDescription)
                // A timed-out MSI may still own the prefix. Never start the next installer.
                if wasInstalling && record.exitCode == nil {
                    // No game/Steam was allowed to run when entering this maintenance operation.
                    SteamStorage(client: SteamClient(disk: disk)).killPrefix(prefix, wine: wine.path)
                    break
                }
            }
        }
        return failures
    }
}

struct CLRLoadPolicy: Codable {
    var schema = 1
    var applications: [String: [String]] // numeric App ID -> unique CLR executable names
}
extension DependencyInstaller {
    static func executableNames(in root: URL, clrOnly: Bool) -> Set<String> {
        var result = Set<String>()
        func scan(_ folder: URL, depth: Int) {
            guard depth <= 4, let files = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.isDirectoryKey,.isSymbolicLinkKey], options: .skipsHiddenFiles) else { return }
            for file in files.prefix(256) {
                guard let values = try? file.resourceValues(forKeys: [.isDirectoryKey,.isSymbolicLinkKey]), values.isSymbolicLink != true else { continue }
                if values.isDirectory == true {
                    if !["redist","_commonredist","directx","easyanticheat"].contains(file.lastPathComponent.lowercased()) { scan(file, depth: depth + 1) }
                } else if file.pathExtension.lowercased() == "exe" {
                    let name = file.lastPathComponent.lowercased()
                    guard name.range(of: "^[a-z0-9_. -]+$", options: .regularExpression) != nil else { continue }
                    if !clrOnly { result.insert(name); continue }
                    guard let input = try? FileHandle(forReadingFrom: file) else { continue }
                    let bytes = (try? input.read(upToCount: 65536)) ?? Data(); try? input.close()
                    func u32(_ offset: Int) -> Int { guard offset >= 0, offset + 4 <= bytes.count else { return 0 }; return (0..<4).reduce(0) { $0 | Int(bytes[offset + $1]) << ($1 * 8) } }
                    guard bytes.starts(with: [0x4d,0x5a]) else { continue }
                    let pe = u32(60), optional = pe + 24
                    guard pe >= 64, pe + 26 < bytes.count, u32(pe) == 0x4550 else { continue }
                    let magic = Int(bytes[optional]) | Int(bytes[optional+1]) << 8
                    guard magic == 0x10b || magic == 0x20b else { continue }
                    let directory = optional + (magic == 0x10b ? 96 : 112) + 14 * 8
                    if u32(directory) != 0 && u32(directory + 4) >= 72 { result.insert(name) }
                }
            }
        }
        scan(root, depth: 0)
        return result
    }
    func activateCLR(for games: [Game], needs: [DependencyNeed]) async throws {
        var applications: [String: [String]] = [:]
        let allNames = games.map { ($0.steamAppID, Self.executableNames(in: URL(fileURLWithPath: $0.installedLocation ?? "/nonexistent"), clrOnly: false)) }
        for game in games {
            guard let id = game.steamAppID, let root = game.installedLocation else { continue }
            let required = needs.filter { $0.appIDs.contains(id) }.compactMap { DependencyCatalog.package($0.packageID) }.filter(\.isCLR)
            guard !required.isEmpty else { continue }
            var ready = true
            for package in required {
                let file = state.appendingPathComponent(package.id + ".json")
                let attempt = (try? Data(contentsOf: file)).flatMap { try? JSONDecoder().decode(DependencyAttempt.self, from: $0) }
                guard attempt?.status == "installed", attempt?.appIDs.contains(id) == true else { ready = false; continue }
                if !(try await isInstalled(package)) { ready = false }
            }
            guard ready else { continue }
            let names = Self.executableNames(in: URL(fileURLWithPath: root), clrOnly: true)
            guard !names.isEmpty else { continue }
            guard !allNames.contains(where: { $0.0 != id && !$0.1.isDisjoint(with: names) }) else { throw DeckError.message("동일 실행 파일 이름이 다른 게임에도 있어 .NET 자동 활성화를 보류했습니다: App ID " + id) }
            applications[id] = names.sorted()
        }
        guard !applications.isEmpty else { return }
        try enableTracking()
        let global = "HKCU\\Software\\Wine\\DllOverrides"
        let paths = [global] + applications.values.flatMap { $0 }.sorted().map { "HKCU\\Software\\Wine\\AppDefaults\\" + $0 + "\\DllOverrides" }
        var backups: [String: String?] = [:]
        let backup = state.appendingPathComponent("clr-overrides-before.json")
        if FileManager.default.fileExists(atPath: backup.path) {
            backups = try JSONDecoder().decode([String:String?].self, from: Data(contentsOf: backup))
        }
        for path in paths where !backups.keys.contains(path) { backups[path] = .some(try await registry(path, name: "mscoree")) }
        try JSONEncoder().encode(backups).write(to: backup, options: .atomic)
        for path in paths {
            let result = try await command(["reg","add",path,"/v","mscoree","/t","REG_SZ","/d",path == global ? "" : "n","/f"])
            guard result.0 == 0 else { throw DeckError.message("게임별 .NET 활성화 저장 실패") }
        }
        let file = prefix.appendingPathComponent("drive_c/ProgramData/MacDeck/clr-policy.json")
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(CLRLoadPolicy(applications: applications)).write(to: file, options: .atomic)
    }
    static func applyCLRPolicy(prefix: URL, environment: inout [String:String]) throws {
        let file = prefix.appendingPathComponent("drive_c/ProgramData/MacDeck/clr-policy.json")
        guard FileManager.default.fileExists(atPath: file.path) else { return }
        let policy = try JSONDecoder().decode(CLRLoadPolicy.self, from: Data(contentsOf: file))
        guard policy.schema == 1, !policy.applications.isEmpty else { throw DeckError.message(".NET 활성화 기록을 확인하세요.") }
        // The registry still disables CLR globally, and enables it only for
        // uniquely identified CLR executables. Remove the environment veto.
        environment["WINEDLLOVERRIDES"] = environment["WINEDLLOVERRIDES", default: ""].split(separator: ";").compactMap { group in
            let pair = group.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard pair.count == 2 else { return String(group) }
            let names = pair[0].split(separator: ",").filter { $0 != "mscoree" }
            return names.isEmpty ? nil : names.joined(separator: ",") + "=" + pair[1]
        }.joined(separator: ";")
    }
}

extension DependencyInstaller {
    static func trackedFiles(prefix: URL) -> [String:URL] {
        let root = prefix.appendingPathComponent("drive_c/windows")
        guard FileManager.default.fileExists(atPath: prefix.appendingPathComponent("drive_c/ProgramData/MacDeck/dependencies-enabled.json").path) else { return [:] }
        var result: [String:URL] = [:]
        for system in ["system32","syswow64"] {
            for name in ["mscoree","msvcr100_clr0400","msvcr100","msvcp100","msvcr110","msvcp110","msvcr120","msvcp120","msvcp140","vcruntime140","vcruntime140_1"] {
                let relative = system + "/" + name + ".dll"; result[relative] = root.appendingPathComponent(relative)
            }
        }
        for framework in ["Framework","Framework64"] {
            for relative in ["v2.0.50727/mscorwks.dll","v2.0.50727/mscorlib.dll","v4.0.30319/clr.dll","v4.0.30319/mscorlib.dll"] {
                let file = "Microsoft.NET/" + framework + "/" + relative; result[file] = root.appendingPathComponent(file)
            }
        }
        let sxs = root.appendingPathComponent("winsxs")
        for folder in ((try? FileManager.default.contentsOfDirectory(at: sxs, includingPropertiesForKeys: nil)) ?? []).prefix(512) {
            let name = folder.lastPathComponent.lowercased()
            guard name.contains("microsoft.vc80.crt_") || name.contains("microsoft.vc90.crt_") else { continue }
            for dll in ["msvcr80.dll","msvcp80.dll","msvcr90.dll","msvcp90.dll"] {
                let relative = "winsxs/" + folder.lastPathComponent + "/" + dll; result[relative] = root.appendingPathComponent(relative)
            }
        }
        return result
    }
    func enableTracking() throws {
        let file = prefix.appendingPathComponent("drive_c/ProgramData/MacDeck/dependencies-enabled.json")
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("{\"schema\":1}".utf8).write(to: file, options: .atomic)
    }
}
