import CryptoKit
import Foundation

enum RuntimeComponentKind: String, Codable, CaseIterable, Identifiable {
    case moltenvk
    case dxmt
    case wine

    var id: String { rawValue }

    var title: String {
        switch self {
        case .moltenvk: return "MoltenVK (Vulkan → Metal 3)"
        case .dxmt: return "DXMT (DirectX 10/11 → Metal)"
        case .wine: return "Wine Engine (Sikarugir 10.x)"
        }
    }

    var summary: String {
        switch self {
        case .moltenvk: return "DirectX 12 (VKD3D) 및 Vulkan 게임을 Apple Metal 3로 가속하는 드라이버"
        case .dxmt: return "DirectX 10/11 게임을 Apple Metal로 직접 변환하는 드라이버"
        case .wine: return "Windows Steam 및 게임 실행을 위한 x86_64 호환성 엔진"
        }
    }

    var defaultReleaseAPI: URL {
        switch self {
        case .moltenvk: return URL(string: "https://api.github.com/repos/KhronosGroup/MoltenVK/releases/latest")!
        case .dxmt: return URL(string: "https://api.github.com/repos/3Shain/dxmt/releases/latest")!
        case .wine: return URL(string: "https://api.github.com/repos/Sikarugir-App/Engines/releases/latest")!
        }
    }
}

struct RuntimeReleaseAsset: Codable, Equatable {
    var name: String
    var downloadURL: URL
    var sha256: String?
    var size: Int64?
}

struct RuntimeComponentStatus: Identifiable, Equatable {
    var kind: RuntimeComponentKind
    var installedVersion: String
    var latestVersion: String?
    var asset: RuntimeReleaseAsset?
    var checking: Bool = false
    var updating: Bool = false
    var statusMessage: String = ""
    var error: String?

    var id: String { kind.id }

    var updateAvailable: Bool {
        guard let latestVersion, !latestVersion.isEmpty, latestVersion != "확인 안 됨" else { return false }
        return RuntimeUpdater.isNewer(remote: latestVersion, installed: installedVersion)
    }
}

struct RuntimeVersionStore: Codable, Equatable {
    var versions: [String: String] = [:]
    var lastChecked: Date?
    var lastUpdated: [String: Date] = [:]
}

enum RuntimeUpdater {
    static func versionNumbers(_ text: String) -> [Int] {
        let parts = text.split { !$0.isNumber }
        return parts.compactMap { Int($0) }
    }

    static func isNewer(remote: String, installed: String) -> Bool {
        let r = versionNumbers(remote)
        let i = versionNumbers(installed)
        guard !r.isEmpty else { return false }
        guard !i.isEmpty else { return true }
        let count = max(r.count, i.count)
        for index in 0..<count {
            let rv = index < r.count ? r[index] : 0
            let iv = index < i.count ? i[index] : 0
            if rv != iv { return rv > iv }
        }
        return false
    }

    static func versionFile(in runtimeRoot: URL) -> URL {
        runtimeRoot.appendingPathComponent("runtime-versions.json")
    }

    static func loadStore(in runtimeRoot: URL) -> RuntimeVersionStore {
        let url = versionFile(in: runtimeRoot)
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(RuntimeVersionStore.self, from: data) else {
            return RuntimeVersionStore()
        }
        return decoded
    }

    static func saveStore(_ store: RuntimeVersionStore, in runtimeRoot: URL) {
        let url = versionFile(in: runtimeRoot)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(store) {
            try? data.write(to: url, options: .atomic)
        }
    }

    static func detectInstalledVersion(for kind: RuntimeComponentKind, runtimeRoot: URL?) -> String {
        guard let runtimeRoot, FileManager.default.fileExists(atPath: runtimeRoot.path) else {
            return "미설치"
        }
        let store = loadStore(in: runtimeRoot)
        if let saved = store.versions[kind.rawValue], !saved.isEmpty {
            return saved
        }
        switch kind {
        case .moltenvk:
            let dylib = runtimeRoot.appendingPathComponent("lib/libMoltenVK.dylib")
            if let version = scanBinaryVersion(at: dylib, pattern: #"(?:^|[^0-9.])(1\.[0-9]+\.[0-9]+)(?:[^0-9.]|$)"#) {
                return "v" + version
            }
            return "v1.4.1"
        case .dxmt:
            let dll = runtimeRoot.appendingPathComponent("lib/wine/x86_64-windows/d3d11.dll")
            if let version = scanBinaryVersion(at: dll, pattern: #"v(0\.[0-9]+|1\.[0-9]+)"#) {
                return version.hasPrefix("v") ? version : "v" + version
            }
            return "v0.80"
        case .wine:
            let versionURL = runtimeRoot.appendingPathComponent("version")
            if let text = try? String(contentsOf: versionURL, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines),
               !text.isEmpty {
                let nums = versionNumbers(text)
                if nums.count >= 3 {
                    return "v\(nums[0]).\(nums[1])_\(nums[2])"
                } else if nums.count == 2 {
                    return "v\(nums[0]).\(nums[1])"
                }
            }
            return "v10.0_8"
        }
    }

    private static func scanBinaryVersion(at url: URL, pattern: String) -> String? {
        guard let data = try? Data(contentsOf: url, options: .mappedIfSafe),
              let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let ascii = String(decoding: data, as: UTF8.self)
        let range = NSRange(ascii.startIndex..<ascii.endIndex, in: ascii)
        guard let match = regex.firstMatch(in: ascii, range: range) else { return nil }
        let targetRange = match.numberOfRanges > 1 ? match.range(at: 1) : match.range(at: 0)
        guard let swiftRange = Range(targetRange, in: ascii) else { return nil }
        return String(ascii[swiftRange])
    }

    static func parseReleaseJSON(_ data: Data, for kind: RuntimeComponentKind) throws -> (version: String, asset: RuntimeReleaseAsset) {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw DeckError.message("\(kind.title) 릴리스 정보를 해석하지 못했습니다.")
        }
        let tagName = (root["tag_name"] as? String) ?? ""
        let assets = (root["assets"] as? [[String: Any]]) ?? []
        switch kind {
        case .moltenvk:
            guard let chosen = assets.first(where: { ($0["name"] as? String) == "MoltenVK-macos.tar" }) ??
                  assets.first(where: {
                      let name = ($0["name"] as? String)?.lowercased() ?? ""
                      return name.contains("moltenvk") && name.contains("macos") && !name.contains("privateapi") && (name.hasSuffix(".tar") || name.hasSuffix(".tar.gz") || name.hasSuffix(".tar.xz"))
                  }),
                  let name = chosen["name"] as? String,
                  let urlString = chosen["browser_download_url"] as? String,
                  let url = URL(string: urlString) else {
                throw DeckError.message("MoltenVK macOS 릴리스 패키지를 찾지 못했습니다.")
            }
            let digest = (chosen["digest"] as? String)?.replacingOccurrences(of: "sha256:", with: "")
            let size = (chosen["size"] as? NSNumber)?.int64Value
            let version = tagName.isEmpty ? "v1.4.2" : (tagName.hasPrefix("v") ? tagName : "v" + tagName)
            return (version, RuntimeReleaseAsset(name: name, downloadURL: url, sha256: digest, size: size))

        case .dxmt:
            guard let chosen = assets.first(where: {
                      let name = ($0["name"] as? String)?.lowercased() ?? ""
                      return name.contains("dxmt") && name.contains("builtin") && (name.hasSuffix(".tar.gz") || name.hasSuffix(".tar.xz"))
                  }) ?? assets.first(where: {
                      let name = ($0["name"] as? String)?.lowercased() ?? ""
                      return name.contains("dxmt") && (name.hasSuffix(".tar.gz") || name.hasSuffix(".tar.xz"))
                  }),
                  let name = chosen["name"] as? String,
                  let urlString = chosen["browser_download_url"] as? String,
                  let url = URL(string: urlString) else {
                throw DeckError.message("DXMT builtin 릴리스 패키지를 찾지 못했습니다.")
            }
            let digest = (chosen["digest"] as? String)?.replacingOccurrences(of: "sha256:", with: "")
            let size = (chosen["size"] as? NSNumber)?.int64Value
            let version = tagName.isEmpty ? "v0.80" : (tagName.hasPrefix("v") ? tagName : "v" + tagName)
            return (version, RuntimeReleaseAsset(name: name, downloadURL: url, sha256: digest, size: size))

        case .wine:
            let candidates = assets.compactMap { item -> (version: String, asset: RuntimeReleaseAsset)? in
                guard let name = item["name"] as? String,
                      name.hasPrefix("WS12WineSikarugir10.0"),
                      !name.localizedCaseInsensitiveContains("battle.net"),
                      name.hasSuffix(".tar.xz") || name.hasSuffix(".tar.gz"),
                      let urlString = item["browser_download_url"] as? String,
                      let url = URL(string: urlString) else { return nil }
                let stripped = name
                    .replacingOccurrences(of: "WS12WineSikarugir", with: "")
                    .replacingOccurrences(of: ".tar.xz", with: "")
                    .replacingOccurrences(of: ".tar.gz", with: "")
                let version = stripped.hasPrefix("v") ? stripped : "v" + stripped
                let digest = (item["digest"] as? String)?.replacingOccurrences(of: "sha256:", with: "")
                let size = (item["size"] as? NSNumber)?.int64Value
                return (version, RuntimeReleaseAsset(name: name, downloadURL: url, sha256: digest, size: size))
            }
            guard let best = candidates.max(by: { isNewer(remote: $1.version, installed: $0.version) }) else {
                throw DeckError.message("WineSikarugir 10.x 엔진 릴리스 패키지를 찾지 못했습니다.")
            }
            return best
        }
    }

    static func fetchRelease(for kind: RuntimeComponentKind, apiOverride: URL? = nil) async throws -> (version: String, asset: RuntimeReleaseAsset) {
        let url = apiOverride ?? kind.defaultReleaseAPI
        if url.isFileURL {
            let data = try Data(contentsOf: url)
            return try parseReleaseJSON(data, for: kind)
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("MacDeck-Updater", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw DeckError.message("\(kind.title) 업데이트 확인 실패 (HTTP \(http.statusCode))")
        }
        return try parseReleaseJSON(data, for: kind)
    }

    static func ensureWritableRuntime(currentWinePath: String?, disk: LibraryDisk) throws -> (runtimeRoot: URL, updatedWinePath: String?) {
        if let root = DirectX12Support.runtimeRoot(forWine: currentWinePath),
           FileManager.default.isWritableFile(atPath: root.path),
           FileManager.default.isWritableFile(atPath: root.appendingPathComponent("lib").path) {
            return (root, nil)
        }
        let fallbackRoot = disk.root.appendingPathComponent("Runtime", isDirectory: true)
        if !FileManager.default.fileExists(atPath: fallbackRoot.appendingPathComponent("bin/wine").path),
           let sourceRoot = DirectX12Support.runtimeRoot(forWine: currentWinePath) {
            if FileManager.default.fileExists(atPath: fallbackRoot.path) {
                try FileManager.default.removeItem(at: fallbackRoot)
            }
            try FileManager.default.createDirectory(at: fallbackRoot.deletingLastPathComponent(), withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: sourceRoot, to: fallbackRoot)
        }
        let wineBin = ["bin/wine64", "bin/wine"].map { fallbackRoot.appendingPathComponent($0).path }
            .first { FileManager.default.isExecutableFile(atPath: $0) }
        guard FileManager.default.fileExists(atPath: fallbackRoot.path) else {
            throw DeckError.message("업데이트할 Wine 런타임 폴더를 찾을 수 없습니다.")
        }
        return (fallbackRoot, wineBin)
    }

    static func sha256Hex(of fileURL: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: fileURL)
        defer { try? handle.close() }
        var hasher = SHA256()
        while autoreleasepool(invoking: {
            guard let chunk = try? handle.read(upToCount: 1024 * 1024), !chunk.isEmpty else { return false }
            hasher.update(data: chunk)
            return true
        }) {}
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    static func hasX86_64Slice(_ url: URL) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? handle.close() }
        let bytes = [UInt8]((try? handle.read(upToCount: 4096)) ?? Data())
        guard bytes.count >= 8 else { return false }
        func u32(_ offset: Int, big: Bool) -> UInt32 {
            guard offset + 4 <= bytes.count else { return 0 }
            return (0..<4).reduce(UInt32(0)) { value, i in value | UInt32(bytes[offset + i]) << (big ? (3 - i) * 8 : i * 8) }
        }
        if u32(0, big: false) == 0xfeedfacf {
            return u32(4, big: false) == 0x01000007
        }
        if u32(0, big: true) == 0xcafebabe {
            let count = min(Int(u32(4, big: true)), 32)
            let types = (0..<count).map { u32(8 + $0 * 20, big: true) }
            return types.contains(0x01000007)
        }
        return false
    }

    static func downloadAndInstall(
        kind: RuntimeComponentKind,
        version: String,
        asset: RuntimeReleaseAsset,
        runtimeRoot: URL,
        graphicsMode: GraphicsBackend
    ) async throws {
        let stagingBase = FileManager.default.temporaryDirectory.appendingPathComponent("macdeck-update-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: stagingBase, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: stagingBase) }

        let archiveURL = stagingBase.appendingPathComponent(asset.name)
        if asset.downloadURL.isFileURL {
            try FileManager.default.copyItem(at: asset.downloadURL, to: archiveURL)
        } else {
            let (downloaded, response) = try await URLSession.shared.download(from: asset.downloadURL)
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                throw DeckError.message("\(kind.title) 다운로드 실패 (HTTP \(http.statusCode))")
            }
            try FileManager.default.moveItem(at: downloaded, to: archiveURL)
        }

        try installLocalArchive(
            kind: kind,
            version: version,
            archiveURL: archiveURL,
            expectedSHA256: asset.sha256,
            runtimeRoot: runtimeRoot,
            graphicsMode: graphicsMode
        )
    }

    static func installLocalArchive(
        kind: RuntimeComponentKind,
        version: String,
        archiveURL: URL,
        expectedSHA256: String?,
        runtimeRoot: URL,
        graphicsMode: GraphicsBackend
    ) throws {
        if let expected = expectedSHA256?.lowercased(), !expected.isEmpty {
            let actual = try sha256Hex(of: archiveURL)
            guard actual == expected else {
                throw DeckError.message("\(kind.title) 파일 무결성(SHA-256) 검증에 실패했습니다.")
            }
        }

        let extractDir = FileManager.default.temporaryDirectory.appendingPathComponent("macdeck-extract-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: extractDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: extractDir) }
        try extractArchive(archiveURL, to: extractDir)

        switch kind {
        case .moltenvk:
            try installMoltenVK(from: extractDir, into: runtimeRoot)
        case .dxmt:
            try installDXMT(from: extractDir, into: runtimeRoot, graphicsMode: graphicsMode)
        case .wine:
            try installWine(from: extractDir, into: runtimeRoot, graphicsMode: graphicsMode)
        }

        var store = loadStore(in: runtimeRoot)
        store.versions[kind.rawValue] = version
        store.lastUpdated[kind.rawValue] = Date()
        store.lastChecked = Date()
        saveStore(store, in: runtimeRoot)
    }

    private static func extractArchive(_ archive: URL, to destination: URL) throws {
        let process = Process()
        if archive.pathExtension.lowercased() == "zip" {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
            process.arguments = ["-oq", archive.path, "-d", destination.path]
        } else {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
            process.arguments = ["-xf", archive.path, "-C", destination.path]
        }
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw DeckError.message("업데이트 아카이브 압축 해제에 실패했습니다 (\(archive.lastPathComponent)).")
        }
    }

    private static func findFiles(named fileName: String, in directory: URL) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) else {
            return []
        }
        var matches: [URL] = []
        for case let url as URL in enumerator where url.lastPathComponent == fileName {
            matches.append(url)
        }
        return matches
    }

    private static func installMoltenVK(from extracted: URL, into runtimeRoot: URL) throws {
        let candidates = findFiles(named: "libMoltenVK.dylib", in: extracted)
        let chosen = candidates.first(where: { $0.path.contains("dynamic/dylib/macOS") })
            ?? candidates.first(where: { $0.path.contains("macos-arm64_x86_64") })
            ?? candidates.first
        guard let source = chosen else {
            throw DeckError.message("압축 해제된 패키지에서 libMoltenVK.dylib를 찾지 못했습니다.")
        }
        guard hasX86_64Slice(source) else {
            throw DeckError.message("새 libMoltenVK.dylib에 x86_64 아키텍처 슬라이스가 없습니다.")
        }
        let libDir = runtimeRoot.appendingPathComponent("lib", isDirectory: true)
        try FileManager.default.createDirectory(at: libDir, withIntermediateDirectories: true)
        let target = libDir.appendingPathComponent("libMoltenVK.dylib")
        let backup = libDir.appendingPathComponent("libMoltenVK.dylib.bak")
        try? FileManager.default.removeItem(at: backup)
        if FileManager.default.fileExists(atPath: target.path) {
            try FileManager.default.copyItem(at: target, to: backup)
        }
        do {
            let bytes = try Data(contentsOf: source)
            try bytes.write(to: target, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: target.path)
            for linkName in ["libvulkan.1.dylib", "libvulkan.dylib"] {
                let linkURL = libDir.appendingPathComponent(linkName)
                if (try? FileManager.default.destinationOfSymbolicLink(atPath: linkURL.path)) != "libMoltenVK.dylib" {
                    try? FileManager.default.removeItem(at: linkURL)
                    try FileManager.default.createSymbolicLink(atPath: linkURL.path, withDestinationPath: "libMoltenVK.dylib")
                }
            }
            codesignAdHoc(target)
            try? FileManager.default.removeItem(at: backup)
        } catch {
            if FileManager.default.fileExists(atPath: backup.path) {
                try? FileManager.default.removeItem(at: target)
                try? FileManager.default.moveItem(at: backup, to: target)
            }
            throw error
        }
    }

    private static func installDXMT(from extracted: URL, into runtimeRoot: URL, graphicsMode: GraphicsBackend) throws {
        let d3d11Candidates = findFiles(named: "d3d11.dll", in: extracted)
        guard !d3d11Candidates.isEmpty else {
            throw DeckError.message("DXMT 패키지에서 d3d11.dll을 찾지 못했습니다.")
        }
        for arch in ["x86_64-unix", "x86_64-windows", "i386-windows"] {
            for fileName in ["winemetal.so", "winemetal.dll", "d3d11.dll", "dxgi.dll", "d3d10core.dll"] {
                guard let match = findFiles(named: fileName, in: extracted).first(where: { $0.deletingLastPathComponent().lastPathComponent == arch }) else {
                    continue
                }
                let destDir = runtimeRoot.appendingPathComponent("lib/wine/\(arch)", isDirectory: true)
                try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
                let dest = destDir.appendingPathComponent(fileName)
                var bytes = try Data(contentsOf: match)
                if arch == "x86_64-windows" && fileName == "d3d11.dll" {
                    bytes = applyDXMTIdentityPatchIfApplicable(bytes)
                }
                try bytes.write(to: dest, options: .atomic)
                if fileName == "winemetal.so" {
                    codesignAdHoc(dest)
                }
                if fileName == "dxgi.dll" && (arch == "x86_64-windows" || arch == "i386-windows") {
                    let dxmtDir = runtimeRoot.appendingPathComponent("lib/wine/dxgi-dxmt/\(arch)", isDirectory: true)
                    try FileManager.default.createDirectory(at: dxmtDir, withIntermediateDirectories: true)
                    try bytes.write(to: dxmtDir.appendingPathComponent("dxgi.dll"), options: .atomic)
                }
            }
        }
        let wineBin = runtimeRoot.appendingPathComponent("bin/wine").path
        DirectX12Support.applyGlobal(mode: graphicsMode, wine: wineBin)
    }

    static func applyDXMTIdentityPatchIfApplicable(_ raw: Data) -> Data {
        let originalSHA = SHA256.hash(data: raw).map { String(format: "%02x", $0) }.joined()
        guard originalSHA == "7ca382af0eb32d8a432f6efb14d594fefb45673663be1f7e6682254bff885c47" else {
            return raw
        }
        var patched = [UInt8](raw)
        let expected: [UInt8] = [0x55, 0x48, 0x89, 0xe5, 0xb8, 0x01, 0x40, 0x00, 0x80, 0x5d, 0xc3, 0x90, 0x90, 0x90, 0x90, 0x90]
        let replacement: [UInt8] = [0x31, 0xc0, 0x83, 0xfa, 0x01, 0x74, 0x05, 0xb8, 0x01, 0x40, 0x00, 0x80, 0xc3, 0x90, 0x90, 0x90]
        for offset in [813120, 797920] {
            guard offset + 16 <= patched.count, Array(patched[offset..<(offset + 16)]) == expected else {
                return raw
            }
            patched.replaceSubrange(offset..<(offset + 16), with: replacement)
        }
        return Data(patched)
    }

    private static func installWine(from extracted: URL, into runtimeRoot: URL, graphicsMode: GraphicsBackend) throws {
        let bundleDir = extracted.appendingPathComponent("wswine.bundle", isDirectory: true)
        guard FileManager.default.fileExists(atPath: bundleDir.appendingPathComponent("bin/wine").path) else {
            throw DeckError.message("Wine 아카이브에서 wswine.bundle/bin/wine을 찾지 못했습니다.")
        }
        let preservePaths = [
            "lib/libMoltenVK.dylib",
            "lib/wine/x86_64-unix/winemetal.so",
            "lib/wine/x86_64-windows/winemetal.dll",
            "lib/wine/x86_64-windows/d3d11.dll",
            "lib/wine/x86_64-windows/d3d10core.dll",
            "lib/wine/i386-windows/winemetal.dll",
            "lib/wine/i386-windows/d3d11.dll",
            "lib/wine/i386-windows/d3d10core.dll",
            "lib/wine/dxgi-dxmt/x86_64-windows/dxgi.dll",
            "lib/wine/dxgi-dxmt/i386-windows/dxgi.dll"
        ]
        var preserved: [String: Data] = [:]
        for rel in preservePaths {
            let url = runtimeRoot.appendingPathComponent(rel)
            if let data = try? Data(contentsOf: url) {
                preserved[rel] = data
            }
        }
        var d3d12DXGI: [String: Data] = [:]
        for arch in ["x86_64-windows", "i386-windows"] {
            let newWineDXGI = bundleDir.appendingPathComponent("lib/wine/\(arch)/dxgi.dll")
            if let data = try? Data(contentsOf: newWineDXGI) {
                d3d12DXGI[arch] = data
            }
        }
        let rsync = Process()
        rsync.executableURL = URL(fileURLWithPath: "/usr/bin/rsync")
        rsync.arguments = ["-a", bundleDir.path + "/", runtimeRoot.path + "/"]
        try rsync.run()
        rsync.waitUntilExit()
        guard rsync.terminationStatus == 0 else {
            throw DeckError.message("Wine 런타임 파일 동기화에 실패했습니다.")
        }
        for (arch, data) in d3d12DXGI {
            let d3d12Dir = runtimeRoot.appendingPathComponent("lib/wine/dxgi-d3d12/\(arch)", isDirectory: true)
            try FileManager.default.createDirectory(at: d3d12Dir, withIntermediateDirectories: true)
            try data.write(to: d3d12Dir.appendingPathComponent("dxgi.dll"), options: .atomic)
        }
        for (rel, data) in preserved {
            let dest = runtimeRoot.appendingPathComponent(rel)
            try FileManager.default.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: dest, options: .atomic)
            if rel.hasSuffix(".dylib") || rel.hasSuffix(".so") {
                try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: dest.path)
                codesignAdHoc(dest)
            }
        }
        let libDir = runtimeRoot.appendingPathComponent("lib", isDirectory: true)
        if FileManager.default.fileExists(atPath: libDir.appendingPathComponent("libMoltenVK.dylib").path) {
            for linkName in ["libvulkan.1.dylib", "libvulkan.dylib"] {
                let linkURL = libDir.appendingPathComponent(linkName)
                if (try? FileManager.default.destinationOfSymbolicLink(atPath: linkURL.path)) != "libMoltenVK.dylib" {
                    try? FileManager.default.removeItem(at: linkURL)
                    try? FileManager.default.createSymbolicLink(atPath: linkURL.path, withDestinationPath: "libMoltenVK.dylib")
                }
            }
        }
        let wineBinTarget = runtimeRoot.appendingPathComponent("bin/wine")
        if var wineBytes = try? Data(contentsOf: wineBinTarget) {
            wineBytes = patchWineGameModePlist(wineBytes)
            try wineBytes.write(to: wineBinTarget, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: wineBinTarget.path)
            codesignAdHoc(wineBinTarget)
        }
        DirectX12Support.applyGlobal(mode: graphicsMode, wine: wineBinTarget.path)
    }

    static func patchWineGameModePlist(_ wineBytes: Data) -> Data {
        let startMarker = Data("<?xml version=\"1.0\" encoding=\"UTF-8\"?>".utf8)
        let endMarker = Data("</plist>\n".utf8)
        guard let startRange = wineBytes.range(of: startMarker),
              let endRange = wineBytes.range(of: endMarker, in: startRange.lowerBound..<wineBytes.endIndex) else {
            return wineBytes
        }
        let origLen = endRange.upperBound - startRange.lowerBound
        guard var plist = (try? PropertyListSerialization.propertyList(from: wineBytes.subdata(in: startRange.lowerBound..<endRange.upperBound), format: nil)) as? [String: Any] else { return wineBytes }
        for key in ["LSUIElement", "LSBackgroundOnly", "CFBundleSignature", "CFBundleAllowMixedLocalizations", "CFBundleDevelopmentRegion", "CFBundleInfoDictionaryVersion"] { plist.removeValue(forKey: key) }
        plist["LSApplicationCategoryType"] = "public.app-category.games"
        plist["LSSupportsGameMode"] = true
        plist["GCSupportsGameMode"] = true
        guard let xml = try? PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0),
              let text = String(data: xml, encoding: .utf8) else { return wineBytes }
        let compact = Data(text.replacingOccurrences(of: "\n", with: "").replacingOccurrences(of: "\t", with: "").utf8)
        guard compact.count <= origLen else { return wineBytes }
        var patched = wineBytes
        patched.replaceSubrange(startRange.lowerBound..<endRange.upperBound, with: compact + Data(repeating: 0x20, count: origLen - compact.count))
        return patched
    }

    private static func codesignAdHoc(_ url: URL) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        process.arguments = ["--force", "--sign", "-", url.path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
    }
}
