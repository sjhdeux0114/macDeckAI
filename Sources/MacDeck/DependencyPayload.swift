import Foundation

// Only SHA-pinned Microsoft packages reach this parser. Reject truncated/false signatures.
enum DependencyPayload {
    static func cabinets(_ bytes: Data) -> [Data] {
        let b = [UInt8](bytes)
        guard b.count >= 36, b.count <= 64 * 1024 * 1024 else { return [] }
        func u32(_ p: Int) -> Int { (0..<4).reduce(0) { $0 | Int(b[p+$1]) << ($1*8) } }
        var result: [Data] = [], p = 0
        while p <= b.count - 36 {
            if b[p..<p+4].elementsEqual([77,83,67,70]), u32(p+4) == 0, u32(p+12) == 0, u32(p+20) == 0,
               b[p+24] == 3, b[p+25] == 1 {
                let size = u32(p+8), files = u32(p+16)
                if size >= 36, size <= b.count-p, files >= 36, files < size, b[p+26] != 0 || b[p+27] != 0 {
                    result.append(Data(b[p..<p+size])); p += size
                    if result.count > 16 { return [] }; continue
                }
            }
            p += 1
        }
        return result
    }
    static func candidate(_ name: String, dll: String, package: DependencyPackage) -> Bool {
        let stem = String(dll.dropLast(4)), arch = package.architecture
        if package.family == "vcrun2013" { return name == "F_CENTRAL_" + stem + "_" + arch }
        if package.family == "vcrun2008" {
            return name == dll + ".30729.6161.Microsoft_VC90_CRT_" + arch + ".QFE"
        }
        return false
    }
    static func replaceable(_ url: URL) -> Bool {
        guard FileManager.default.fileExists(atPath: url.path) else { return true }
        guard let data = try? Data(contentsOf: url), data.count < 32 * 1024 * 1024 else { return false }
        return data.range(of: DirectX12Support.wineBuiltinMarker) != nil || data.range(of: DirectX12Support.wineNativeMarker) != nil
    }
}

extension DependencyInstaller {
    // MSI sometimes leaves Wine CRT placeholders behind despite exit 0. Repair only the
    // selected Epic bottle; never change another bottle or any installed game directory.
    func repairEpicPayload(_ package: DependencyPackage, installer: URL) async throws -> Bool {
        guard prefix.standardizedFileURL == EpicClient(disk: disk).prefix.standardizedFileURL,
              ["vcrun2008", "vcrun2013"].contains(package.family) else { return false }
        guard try Self.digest(installer) == package.sha256 else { throw DeckError.message("VC++ 복구 원본 SHA-256 불일치") }
        let helper = Bundle.main.resourceURL!.appendingPathComponent("DependencyTools/wine-cab-extract.exe")
        guard FileManager.default.fileExists(atPath: helper.path) else { throw DeckError.message("VC++ CAB 복구 도구가 없습니다.") }
        let fm = FileManager.default, id = UUID().uuidString
        let scratch = prefix.appendingPathComponent("drive_c/ProgramData/MacDeck/DependencyPayload/" + id)
        try fm.createDirectory(at: scratch, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: scratch) }
        var queue = DependencyPayload.cabinets(try Data(contentsOf: installer)).map { ($0, 0) }
        var extracted: [URL] = [], count = 0, total = 0
        while !queue.isEmpty {
            let (cab, depth) = queue.removeFirst(); count += 1
            guard count <= 16, depth <= 2 else { throw DeckError.message("VC++ CAB 복구 한도 초과") }
            let source = scratch.appendingPathComponent("\(count).cab"), output = scratch.appendingPathComponent("out\(count)")
            try cab.write(to: source); try fm.createDirectory(at: output, withIntermediateDirectories: false)
            func windows(_ file: URL) -> String { "C:\\ProgramData\\MacDeck\\DependencyPayload\\" + id + "\\" + file.lastPathComponent }
            let result = try await command([helper.path, windows(source), windows(output)], timeout: 60)
            guard result.0 == 0 else { throw DeckError.message("VC++ CAB 추출 실패") }
            for file in try fm.contentsOfDirectory(at: output, includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey]) {
                let values = try file.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
                guard values.isRegularFile == true else { throw DeckError.message("VC++ CAB 비정상 항목") }
                total += values.fileSize ?? 0
                guard total <= 256 * 1024 * 1024 else { throw DeckError.message("VC++ CAB 용량 한도 초과") }
                let header = try FileHandle(forReadingFrom: file); let magic = try header.read(upToCount: 4); try header.close()
                if magic == Data([77,83,67,70]) { queue.append((try Data(contentsOf: file), depth+1)) }
                else { extracted.append(file) }
            }
        }
        let windows = prefix.appendingPathComponent("drive_c/windows")
        let dlls: [String], destinations: [URL]
        if package.family == "vcrun2008" {
            dlls = ["msvcr90.dll", "msvcp90.dll", "msvcm90.dll"]
            let arch = package.architecture == "x64" ? "amd64" : "x86"
            let sxs = windows.appendingPathComponent("winsxs")
            destinations = try fm.contentsOfDirectory(at: sxs, includingPropertiesForKeys: nil).filter {
                $0.lastPathComponent.lowercased().hasPrefix(arch + "_microsoft.vc90.crt_1fc8b3b9a1e18e3b_9.0.30729.6161_")
            }
        } else {
            dlls = package.requiredSystemDLLs
            destinations = [windows.appendingPathComponent(package.architecture == "x64" ? "system32" : "syswow64")]
        }
        guard !destinations.isEmpty else { throw DeckError.message("VC++ 복구 대상 SxS 설치가 없습니다.") }
        var replacements: [(URL,URL)] = []
        for dll in dlls {
            let matches = extracted.filter { DependencyPayload.candidate($0.lastPathComponent, dll: dll, package: package) && Self.nativePE($0, architecture: package.architecture) }
            guard matches.count == 1 else { throw DeckError.message("VC++ 복구 DLL/아키텍처 확인 실패: " + dll) }
            for directory in destinations {
                let target = directory.appendingPathComponent(dll)
                guard directory.resolvingSymlinksInPath().path.hasPrefix(windows.resolvingSymlinksInPath().path + "/"),
                      target.resolvingSymlinksInPath().deletingLastPathComponent() == directory.resolvingSymlinksInPath() else { throw DeckError.message("VC++ 복구 경로 확인 실패") }
                if Self.nativePE(target, architecture: package.architecture) { continue }
                guard DependencyPayload.replaceable(target) else { throw DeckError.message("기존 비-Wine DLL은 자동 교체하지 않습니다: " + dll) }
                replacements.append((matches[0],target))
            }
        }
        guard !replacements.isEmpty else { return false }
        let backup = state.appendingPathComponent("NativeRepair/" + id)
        try fm.createDirectory(at: backup, withIntermediateDirectories: true)
        var originals: [(URL,Data?)] = []
        do {
            for (index, entry) in replacements.enumerated() {
                let (source,target) = entry, original = try fm.fileExists(atPath: target.path) ? Data(contentsOf: target) : nil
                originals.append((target,original))
                if let original { try original.write(to: backup.appendingPathComponent("\(index)-" + target.lastPathComponent), options: .atomic) }
                let audit = "package=\(package.id)\ninstallerSHA256=\(package.sha256)\nsourceSHA256=\(try Self.digest(source))\ntarget=\(target.path)\n"
                try Data(audit.utf8).write(to: backup.appendingPathComponent("\(index).txt"), options: .atomic)
                try Data(contentsOf: source).write(to: target, options: .atomic)
            }
            guard try await isInstalled(package) else { throw DeckError.message("복구 후 VC++ 네이티브 검증 실패") }
        } catch {
            for (file,original) in originals.reversed() {
                if let original { try original.write(to: file, options: .atomic) } else if fm.fileExists(atPath: file.path) { try fm.removeItem(at: file) }
            }
            throw error
        }
        return true
    }
}
