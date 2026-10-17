import Foundation

struct SteamStorage {
    let client: SteamClient
    var files: [URL] {
        guard let root = client.root else { return [] }
        let primary = root.appendingPathComponent("steamapps/libraryfolders.vdf")
        let mirror = root.appendingPathComponent("config/libraryfolders.vdf")
        return FileManager.default.fileExists(atPath: mirror.path) ? [primary, mirror] : [primary]
    }
    static func normalized(_ path: String) -> String {
        path.replacingOccurrences(of: "\\", with: "/").trimmingCharacters(in: CharacterSet(charactersIn: "/")).lowercased()
    }
    func registered(_ storage: ExternalLibrary) -> Bool {
        guard let file = files.first, let text = try? String(contentsOf: file), let entries = try? VDF.parse(text)["libraryfolders"]?.object else { return false }
        return entries.values.contains { Self.normalized($0.object?["path"]?.string ?? "") == Self.normalized(storage.windowsLibraryPath) }
    }

    func migrateMapping(_ storage: ExternalLibrary) throws -> ExternalLibrary {
        let corrected = storage.nonRootMapping
        guard corrected.mappingRoot != storage.mappingRoot else { return storage }
        let link = client.prefix.appendingPathComponent("dosdevices/" + storage.drive + ":")
        let target = try FileManager.default.destinationOfSymbolicLink(atPath: link.path)
        guard target == storage.mappingRoot.path else { throw DeckError.message("드라이브 매핑이 변경되어 복구를 중단했습니다.") }
        try FileManager.default.removeItem(at: link)
        do { try FileManager.default.createSymbolicLink(at: link, withDestinationURL: corrected.mappingRoot) }
        catch { try? FileManager.default.createSymbolicLink(atPath: link.path, withDestinationPath: target); throw error }
        return corrected
    }

    func recognition(_ storage: ExternalLibrary) -> String {
        guard registered(storage) else { return "폴더만 연결됨 · Steam 적용 필요" }
        guard let root = client.root,
              let handle = try? FileHandle(forReadingFrom: root.appendingPathComponent("logs/content_log.txt")) else { return "Steam 설정 등록됨 · 인식 확인 대기" }
        defer { try? handle.close() }
        let size = (try? handle.seekToEnd()) ?? 0
        try? handle.seek(toOffset: size > 524288 ? size - 524288 : 0)
        let lines = String(decoding: (try? handle.readToEnd()) ?? Data(), as: UTF8.self).components(separatedBy: .newlines)
        let target = Self.normalized(storage.windowsLibraryPath)
        for line in lines.reversed() {
            let text = line.replacingOccurrences(of: "\\", with: "/").lowercased()
            if text.contains("install folder " + target + " not mounted") { return "Steam이 드라이브를 인식하지 못함 · 다시 적용 필요" }
            if text.contains("apps from install folder \"" + target + "/steamapps/") { return "Steam 설치 폴더 인식 확인됨" }
        }
        return "Steam 설정 등록됨 · 인식 확인 대기"
    }

    func update(_ storage: ExternalLibrary, removing: Bool, steamRunning: Bool) throws {
        guard !steamRunning else { throw DeckError.message("Steam이 실행 중입니다. 종료 후 다시 적용해 주세요.") }
        guard !files.isEmpty else { throw DeckError.message("Steam 설치를 먼저 완료해 주세요.") }
        if !removing {
            let driveLink = client.prefix.appendingPathComponent("dosdevices/" + storage.drive + ":")
            guard (try? FileManager.default.destinationOfSymbolicLink(atPath: driveLink.path)) == storage.mappingRoot.path else { throw DeckError.message("Windows 드라이브 매핑이 없거나 변경됐습니다. 폴더 연결을 확인해 주세요.") }
            guard storage.connected else { throw DeckError.message("외장 드라이브가 연결되어 있지 않거나 다른 디스크입니다.") }
            guard storage.librarySubdirectory.isEmpty || (storage.librarySubdirectory != ".." && !storage.librarySubdirectory.contains("/") && !storage.librarySubdirectory.contains("\\")) else { throw DeckError.message("게임 설치 폴더 이름이 올바르지 않습니다.") }
        }
        let fm = FileManager.default
        let snapshots = try files.map { url -> (URL, Data?) in
            (url, fm.fileExists(atPath: url.path) ? try Data(contentsOf: url) : nil)
        }
        let changes = try snapshots.map { url, bytes -> (URL, Data) in
            var root = try bytes.map { try VDF.parse(String(decoding: $0, as: UTF8.self)) } ?? [:]
            guard root["libraryfolders"] == nil || root["libraryfolders"]?.object != nil else { throw DeckError.message("Steam 라이브러리 설정 형식이 올바르지 않습니다.") }
            var entries = root["libraryfolders"]?.object ?? [:]
            if entries.isEmpty, let steam = client.root {
                let defaultPath = "C:\\" + steam.path.components(separatedBy: "/drive_c/").last!.replacingOccurrences(of: "/", with: "\\")
                entries["0"] = .object(["path": .string(defaultPath), "apps": .object([:])])
            }
            let matching = entries.filter {
                let path = Self.normalized($0.value.object?["path"]?.string ?? "")
                return path == Self.normalized(storage.windowsLibraryPath) || path == Self.normalized(storage.windowsPath)
            }.map(\.key)
            if removing {
                for key in matching where key != "0" { entries.removeValue(forKey: key) }
            } else if let key = matching.first {
                var value = entries[key]?.object ?? [:]
                value["path"] = .string(storage.windowsLibraryPath)
                entries[key] = .object(value)
                for duplicate in matching.dropFirst() where duplicate != "0" { entries.removeValue(forKey: duplicate) }
            } else if matching.isEmpty {
                let key = String((entries.keys.compactMap(Int.init).max() ?? 0) + 1)
                entries[key] = .object(["path": .string(storage.windowsLibraryPath), "label": .string(""), "contentid": .string("0"), "totalsize": .string("0"), "apps": .object([:])])
            }
            root["libraryfolders"] = .object(entries)
            return (url, Data(VDF.encode(root).utf8))
        }
        if !removing { try fm.createDirectory(at: storage.installRoot.appendingPathComponent("steamapps"), withIntermediateDirectories: true) }
        for (url, bytes) in snapshots {
            if let bytes { try bytes.write(to: url.appendingPathExtension("macdeck-" + UUID().uuidString + ".bak"), options: .withoutOverwriting) }
        }
        do {
            for (url, bytes) in changes {
                try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try bytes.write(to: url, options: .atomic)
            }
        } catch {
            for (url, bytes) in snapshots {
                if let bytes { try? bytes.write(to: url, options: .atomic) }
                else { try? fm.removeItem(at: url) }
            }
            throw error
        }
    }

    func command(_ executable: URL, arguments: [String], wine: String, timeout: TimeInterval = 20) async throws -> String {
        var game = Game(name: "Steam 저장 공간 관리", path: executable.path, kind: .windows)
        game.prefix = client.prefix.path; game.arguments = arguments
        let plan = try LaunchPlan.make(game: game, wine: wine, disk: client.disk)
        let capture = FileManager.default.temporaryDirectory.appendingPathComponent("macdeck-storage-" + UUID().uuidString)
        FileManager.default.createFile(atPath: capture.path, contents: nil)
        defer { try? FileManager.default.removeItem(at: capture) }
        let handle = try FileHandle(forWritingTo: capture)
        defer { try? handle.close() }
        let process = Process()
        process.executableURL = plan.executable; process.arguments = plan.arguments; process.environment = plan.environment
        process.currentDirectoryURL = plan.workingDirectory; process.standardOutput = handle; process.standardError = FileHandle.nullDevice
        try process.run()
        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning && Date() < deadline { try await Task.sleep(nanoseconds: 150_000_000) }
        guard !process.isRunning else { process.terminate(); throw DeckError.message("Steam 응답 대기가 끝났습니다. 실행 중인 게임과 Steam을 종료한 뒤 다시 시도해 주세요.") }
        guard process.terminationStatus == 0 else { throw DeckError.message("Steam 저장 공간 관리 명령을 실행하지 못했습니다 (\(process.terminationStatus)).") }
        return String(decoding: try Data(contentsOf: capture), as: UTF8.self)
    }
    func isRunning(wine: String) async throws -> Bool {
        let text = try await command(client.prefix.appendingPathComponent("drive_c/windows/system32/tasklist.exe"), arguments: ["/fo", "csv", "/nh"], wine: wine)
        guard text.contains("\",\"") else { throw DeckError.message("Windows 프로세스 상태를 확인하지 못해 설정을 보존했습니다.") }
        return text.lowercased().components(separatedBy: .newlines).contains { $0.hasPrefix("\"steam.exe\",") }
    }
    func stopAndWait(wine: String) async throws {
        guard try await isRunning(wine: wine) else { return }
        guard let executable = client.executable else { return }
        _ = try await command(executable, arguments: ["-shutdown"], wine: wine)
        let deadline = Date().addingTimeInterval(45)
        while try await isRunning(wine: wine) {
            guard Date() < deadline else { throw DeckError.message("Steam이 아직 종료되지 않았습니다. 게임을 저장하고 종료한 뒤 다시 시도해 주세요.") }
            try await Task.sleep(nanoseconds: 500_000_000)
        }
    }
    func unlink(_ storage: ExternalLibrary) throws {
        let link = client.prefix.appendingPathComponent("dosdevices/" + storage.drive + ":")
        if let destination = try? FileManager.default.destinationOfSymbolicLink(atPath: link.path) {
            guard destination == storage.mappingRoot.path else { throw DeckError.message("드라이브 매핑이 변경되어 해제를 중단했습니다.") }
            try FileManager.default.removeItem(at: link)
        }
        // Game content is retained. The marker is intentionally kept for recovery.
    }
}
