import Foundation

enum GameKind: String, Codable {
    case windows, macApp, executable
    var label: String {
        switch self { case .windows: return "WINDOWS"; case .macApp, .executable: return "MACOS" }
    }
}

struct Game: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String
    var path: String
    var kind: GameKind
    var arguments: [String] = []
    var prefix: String? = nil
    var lastPlayed: Date? = nil
    var added: Date = Date()
    var steamAppID: String? = nil
    var installedLocation: String? = nil

    static func importing(_ url: URL) throws -> Game {
        let path = url.standardizedFileURL.path
        guard FileManager.default.fileExists(atPath: path) else { throw DeckError.message("파일을 찾을 수 없습니다.") }
        let kind: GameKind
        if url.pathExtension.lowercased() == "app" {
            guard Bundle(url: url)?.executableURL != nil else { throw DeckError.message("실행 가능한 macOS 앱 번들이 아닙니다.") }
            kind = .macApp
        } else if url.pathExtension.lowercased() == "exe" {
            let file = try FileHandle(forReadingFrom: url)
            defer { try? file.close() }
            guard try file.read(upToCount: 2) == Data([0x4d, 0x5a]) else { throw DeckError.message("Windows 실행 파일의 MZ 헤더가 없습니다.") }
            kind = .windows
        } else {
            guard FileManager.default.isExecutableFile(atPath: path) else { throw DeckError.message(".app, .exe 또는 실행 권한이 있는 파일을 선택해 주세요.") }
            kind = .executable
        }
        return Game(name: url.deletingPathExtension().lastPathComponent, path: path, kind: kind)
    }
}

struct LibraryData: Codable {
    var version = 1
    var games: [Game] = []
    var winePath = ""
    var startSteamOnLaunch: Bool? = nil
    var externalLibraries: [ExternalLibrary]? = nil
}

enum DeckError: LocalizedError {
    case message(String)
    var errorDescription: String? { switch self { case .message(let text): return text } }
}

struct LibraryDisk {
    let root: URL
    var file: URL { root.appendingPathComponent("library.json") }
    var logs: URL { root.appendingPathComponent("Logs", isDirectory: true) }
    var bottles: URL { root.appendingPathComponent("Bottles", isDirectory: true) }

    static var standard: LibraryDisk {
        if let override = ProcessInfo.processInfo.environment["MACDECK_DATA_DIR"] {
            return LibraryDisk(root: URL(fileURLWithPath: override, isDirectory: true))
        }
        return LibraryDisk(root: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("MacDeck", isDirectory: true))
    }

    func load() throws -> LibraryData {
        guard FileManager.default.fileExists(atPath: file.path) else { return LibraryData() }
        let library = try JSONDecoder().decode(LibraryData.self, from: Data(contentsOf: file))
        guard library.version == 1 else { throw DeckError.message("이 라이브러리는 더 새로운 버전의 MacDeck에서 만들었습니다.") }
        guard Set(library.games.map(\.id)).count == library.games.count else { throw DeckError.message("라이브러리에 중복된 게임 ID가 있습니다.") }
        return library
    }

    func save(_ value: LibraryData) throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(value).write(to: file, options: .atomic)
    }

    func prefix(for game: Game) -> URL {
        if let path = game.prefix, !path.isEmpty { return URL(fileURLWithPath: path, isDirectory: true) }
        return bottles.appendingPathComponent(game.id.uuidString, isDirectory: true)
    }

    func preparePrefix(for game: Game) throws {
        let prefix = prefix(for: game)
        let fresh = !FileManager.default.fileExists(atPath: prefix.appendingPathComponent("system.reg").path)
        try FileManager.default.createDirectory(at: prefix, withIntermediateDirectories: true)
        if fresh {
            let user = prefix.appendingPathComponent("drive_c/users/" + NSUserName(), isDirectory: true)
            for name in ["Desktop", "Documents", "Downloads", "Music", "Pictures", "Videos"] {
                let folder = user.appendingPathComponent(name, isDirectory: true)
                if !FileManager.default.fileExists(atPath: folder.path) {
                    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                }
            }
        }
    }
}

struct LaunchPlan {
    var executable: URL
    var arguments: [String]
    var environment: [String: String]
    var workingDirectory: URL

    static func make(game: Game, wine: String?, disk: LibraryDisk) throws -> LaunchPlan {
        guard FileManager.default.fileExists(atPath: game.path) else { throw DeckError.message("게임 파일이 이동되었거나 삭제되었습니다. 편집에서 경로를 다시 선택해 주세요.") }
        var environment = ProcessInfo.processInfo.environment
        let executable: URL
        var arguments = game.arguments
        if game.kind == .windows {
            guard let wine, FileManager.default.isExecutableFile(atPath: wine) else { throw DeckError.message("런타임 탭에서 macOS용 Wine 실행 파일을 선택해 주세요.") }
            executable = URL(fileURLWithPath: wine)
            arguments.insert(game.path, at: 0)
            environment["WINEPREFIX"] = disk.prefix(for: game).path
            environment["WINEDEBUG"] = "-all"
            environment["WINEDLLOVERRIDES"] = "winemenubuilder.exe=d;mscoree,mshtml=;d3d11,dxgi,d3d10core,winemetal=b;xinput1_1,xinput1_2,xinput1_3,xinput1_4,xinput9_1_0=b"
            environment["DYLD_FALLBACK_LIBRARY_PATH"] = URL(fileURLWithPath: wine).resolvingSymlinksInPath()
                .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("lib").path
            environment["DXMT_LOG_LEVEL"] = "info"
            environment["DXMT_LOG_PATH"] = disk.logs.path
            environment["MTL_HUD_ENABLED"] = "1"
            environment["SDL_RENDER_DRIVER"] = "direct3d11"
        } else if game.kind == .executable {
            executable = URL(fileURLWithPath: game.path)
        } else {
            throw DeckError.message("macOS 앱 번들은 Launch Services로 실행해야 합니다.")
        }
        return LaunchPlan(executable: executable, arguments: arguments, environment: environment,
                          workingDirectory: URL(fileURLWithPath: game.path).deletingLastPathComponent())
    }
}
