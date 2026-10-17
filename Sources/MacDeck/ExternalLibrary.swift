import Foundation

struct ExternalLibrary: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var path: String
    var drive: String
    var libraryFolder: String? = nil
    var driveFolder: String? = nil
    var mappingRoot: URL { URL(fileURLWithPath: driveFolder ?? path).standardizedFileURL }
    var windowsPath: String { drive.uppercased() + ":\\" }
    var librarySubdirectory: String { libraryFolder ?? (FileManager.default.fileExists(atPath: URL(fileURLWithPath: path).appendingPathComponent("steamapps").path) ? "" : "SteamLibrary") }
    var installRoot: URL { librarySubdirectory.isEmpty ? URL(fileURLWithPath: path) : URL(fileURLWithPath: path).appendingPathComponent(librarySubdirectory) }
    var windowsLibraryPath: String {
        let base = mappingRoot.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let actual = installRoot.standardizedFileURL.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let relative = actual == base ? "" : actual.hasPrefix(base + "/") ? String(actual.dropFirst(base.count + 1)) : librarySubdirectory
        return windowsPath + relative.replacingOccurrences(of: "/", with: "\\")
    }
    var nonRootMapping: ExternalLibrary {
        var result = self
        if installRoot.standardizedFileURL == mappingRoot {
            result.libraryFolder = librarySubdirectory
            result.driveFolder = installRoot.deletingLastPathComponent().path
        }
        return result
    }
    var marker: URL { URL(fileURLWithPath: path).appendingPathComponent(".macdeck-library-" + id.uuidString) }
    var connected: Bool { (try? String(contentsOf: marker)) == id.uuidString }
    var availableSpace: String {
        guard connected, let values = try? URL(fileURLWithPath: path).resourceValues(forKeys: [.volumeAvailableCapacityKey]), let bytes = values.volumeAvailableCapacity else { return "연결되지 않음" }
        return ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file) + " 사용 가능"
    }

    static func connect(folder: URL, existing: [ExternalLibrary], prefix: URL) throws -> ExternalLibrary {
        let folder = folder.resolvingSymlinksInPath().standardizedFileURL
        var directory: ObjCBool = false
        let fm = FileManager.default
        guard fm.fileExists(atPath: folder.path, isDirectory: &directory), directory.boolValue else { throw DeckError.message("연결된 드라이브의 기존 폴더를 선택해 주세요.") }
        guard !existing.contains(where: { $0.path == folder.path }) else { throw DeckError.message("이미 연결한 폴더입니다.") }
        let devices = prefix.appendingPathComponent("dosdevices")
        try fm.createDirectory(at: devices, withIntermediateDirectories: true)
        if !fm.fileExists(atPath: prefix.appendingPathComponent("system.reg").path) {
            try fm.createDirectory(at: prefix.appendingPathComponent("drive_c"), withIntermediateDirectories: true)
            for (letter, target) in [("c:", "../drive_c"), ("z:", "/")] {
                let link = devices.appendingPathComponent(letter)
                if (try? fm.attributesOfItem(atPath: link.path)) == nil {
                    try fm.createSymbolicLink(atPath: link.path, withDestinationPath: target)
                }
            }
        }
        guard let drive = (100...121).compactMap({ UnicodeScalar($0).map(String.init) }).first(where: { letter in
            !existing.contains(where: { $0.drive == letter }) && (try? fm.attributesOfItem(atPath: devices.appendingPathComponent(letter + ":").path)) == nil
        }) else { throw DeckError.message("사용 가능한 드라이브 문자가 없습니다.") }
        let entry = ExternalLibrary(path: folder.path, drive: drive, libraryFolder: fm.fileExists(atPath: folder.appendingPathComponent("steamapps").path) ? "" : "SteamLibrary").nonRootMapping
        guard !existing.contains(where: { $0.installRoot.resolvingSymlinksInPath().standardizedFileURL == entry.installRoot.resolvingSymlinksInPath().standardizedFileURL }) else { throw DeckError.message("이미 연결된 게임 설치 폴더입니다. 기존 드라이브 항목을 사용해 주세요.") }
        try Data(entry.id.uuidString.utf8).write(to: entry.marker, options: .withoutOverwriting)
        do { try fm.createSymbolicLink(at: devices.appendingPathComponent(drive + ":"), withDestinationURL: entry.mappingRoot) }
        catch { try? fm.removeItem(at: entry.marker); throw error }
        return entry
    }
}
