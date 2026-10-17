import Foundation

enum VDF {
    enum Token: Equatable { case text(String), open, close }
    static func tokens(_ text: String) throws -> [Token] {
        let chars = Array(text)
        var result: [Token] = [], index = 0
        while index < chars.count {
            let c = chars[index]
            if c.isWhitespace { index += 1; continue }
            if c == "/", index + 1 < chars.count, chars[index + 1] == "/" {
                while index < chars.count && chars[index] != "\n" { index += 1 }
                continue
            }
            if c == "{" { result.append(.open); index += 1; continue }
            if c == "}" { result.append(.close); index += 1; continue }
            if c == "\"" {
                index += 1
                var value = "", closed = false
                while index < chars.count {
                    let valueChar = chars[index]; index += 1
                    if valueChar == "\"" { closed = true; break }
                    if valueChar == "\\", index < chars.count {
                        let next = chars[index]
                        if next == "\\" || next == "\"" { value.append(next); index += 1 }
                        else { value.append("\\") }
                    } else { value.append(valueChar) }
                }
                guard closed else { throw DeckError.message("Steam VDF 문자열이 완성되지 않았습니다.") }
                result.append(.text(value))
            } else {
                var value = ""
                while index < chars.count && !chars[index].isWhitespace && chars[index] != "{" && chars[index] != "}" { value.append(chars[index]); index += 1 }
                result.append(.text(value))
            }
        }
        return result
    }

    indirect enum Value { case string(String), object([String: Value])
        var string: String? { if case .string(let text) = self { return text }; return nil }
        var object: [String: Value]? { if case .object(let object) = self { return object }; return nil }
    }

    static func encode(_ values: [String: Value], indent: String = "") -> String {
        func quoted(_ text: String) -> String { "\"" + text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\"" }
        return values.keys.sorted { $0.localizedStandardCompare($1) == .orderedAscending }.map { key in
            switch values[key]! {
            case .string(let value): return indent + quoted(key) + "\t\t" + quoted(value) + "\n"
            case .object(let object): return indent + quoted(key) + "\n" + indent + "{\n" + encode(object, indent: indent + "\t") + indent + "}\n"
            }
        }.joined()
    }

    static func parse(_ text: String) throws -> [String: Value] {
        let input = try tokens(text)
        var index = 0
        func object(nested: Bool, depth: Int) throws -> [String: Value] {
            guard depth < 32 else { throw DeckError.message("Steam VDF 중첩이 너무 깊습니다.") }
            var values: [String: Value] = [:]
            while index < input.count {
                if input[index] == .close {
                    guard nested else { throw DeckError.message("Steam VDF 괄호가 올바르지 않습니다.") }
                    index += 1; return values
                }
                guard case .text(let key) = input[index] else { throw DeckError.message("Steam VDF 키가 올바르지 않습니다.") }
                index += 1
                guard index < input.count else { throw DeckError.message("Steam VDF 값이 없습니다.") }
                switch input[index] {
                case .text(let value): values[key.lowercased()] = .string(value); index += 1
                case .open: index += 1; values[key.lowercased()] = .object(try object(nested: true, depth: depth + 1))
                case .close: throw DeckError.message("Steam VDF 값이 올바르지 않습니다.")
                }
            }
            guard !nested else { throw DeckError.message("Steam VDF 괄호가 완성되지 않았습니다.") }
            return values
        }
        return try object(nested: false, depth: 0)
    }
}

struct SteamClient {
    let disk: LibraryDisk
    var prefix: URL { disk.bottles.appendingPathComponent("Steam", isDirectory: true) }
    var root: URL? {
        ["drive_c/Program Files (x86)/Steam", "drive_c/Program Files/Steam"].map { prefix.appendingPathComponent($0) }
            .first { FileManager.default.fileExists(atPath: $0.appendingPathComponent("steam.exe").path) }
    }
    var executable: URL? { root?.appendingPathComponent("steam.exe") }
    static let arguments = ["-gamepadui", "-no-cef-sandbox", "-cef-disable-gpu", "-cef-disable-gpu-compositing"]

    func entry() throws -> Game {
        guard let executable else { throw DeckError.message("Steam 설치를 먼저 완료해 주세요.") }
        var game = try Game.importing(executable)
        game.name = "Steam · Big Picture"
        game.prefix = prefix.path
        game.arguments = Self.arguments
        return game
    }

    func windowsPath(_ value: String) -> URL? {
        let path = value.replacingOccurrences(of: "\\", with: "/")
        guard path.count >= 2, path[path.index(after: path.startIndex)] == ":" else { return nil }
        let drive = String(path.prefix(1)).lowercased()
        let relative = String(path.dropFirst(2)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !relative.split(separator: "/").contains("..") else { return nil }
        let base = drive == "c" ? prefix.appendingPathComponent("drive_c") : prefix.appendingPathComponent("dosdevices/" + drive + ":").resolvingSymlinksInPath()
        return relative.isEmpty ? base.standardizedFileURL : base.appendingPathComponent(relative).standardizedFileURL
    }

    func installedGames() throws -> [Game] {
        guard let root, let executable else { return [] }
        var folders = [root.appendingPathComponent("steamapps")]
        let libraries = root.appendingPathComponent("steamapps/libraryfolders.vdf")
        if FileManager.default.fileExists(atPath: libraries.path) {
            let info = try VDF.parse(String(contentsOf: libraries))
            for (_, value) in info["libraryfolders"]?.object ?? [:] {
                if let path = value.object?["path"]?.string ?? value.string, let folder = windowsPath(path) {
                    folders.append(folder.appendingPathComponent("steamapps"))
                }
            }
        }
        var games: [String: Game] = [:]
        for folder in Set(folders) {
            let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
            for file in files where file.lastPathComponent.hasPrefix("appmanifest_") && file.pathExtension == "acf" {
                guard let contents = try? String(contentsOf: file), let state = try? VDF.parse(contents)["appstate"]?.object,
                      let id = state["appid"]?.string, !id.isEmpty, id.allSatisfy(\.isNumber),
                      let name = state["name"]?.string, let flags = state["stateflags"]?.string.flatMap(Int.init), flags & 4 != 0,
                      let directory = state["installdir"]?.string, !directory.contains("/"), !directory.contains("\\"), directory != "..",
                      FileManager.default.fileExists(atPath: folder.appendingPathComponent("common/" + directory).path) else { continue }
                var game = Game(name: name, path: executable.path, kind: .windows)
                game.prefix = prefix.path
                game.arguments = ["-applaunch", id]
                game.steamAppID = id
                game.installedLocation = folder.appendingPathComponent("common/" + directory).path
                games[id] = game
            }
        }
        return games.values.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    static func runInstaller(_ plan: LaunchPlan, log: URL) async throws {
        try FileManager.default.createDirectory(at: log.deletingLastPathComponent(), withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: log.path, contents: nil)
        let output = try FileHandle(forWritingTo: log)
        defer { try? output.close() }
        let process = Process()
        process.executableURL = plan.executable; process.arguments = plan.arguments
        process.environment = plan.environment; process.currentDirectoryURL = plan.workingDirectory
        process.standardOutput = output; process.standardError = output
        try process.run()
        let deadline = Date().addingTimeInterval(240)
        while process.isRunning && Date() < deadline { try await Task.sleep(nanoseconds: 200_000_000) }
        if process.isRunning { process.terminate(); throw DeckError.message("Steam 설치가 지연되고 있습니다. 설치 로그를 확인해 주세요.") }
        guard process.terminationStatus == 0 else { throw DeckError.message("Steam 설치가 코드 \(process.terminationStatus)로 종료됐습니다. 설치 로그를 확인해 주세요.") }
    }
}
