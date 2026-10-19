import Foundation

// Runs only with --support-report-self-test; no email composer or real game is opened.
enum SupportReportTests {
    static func run() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("macdeck-support-test-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let disk = LibraryDisk(root: root)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        var game = Game(name: "Report fixture", path: "/usr/bin/true", kind: .executable)
        game.steamAppID = "214830"
        _ = try GameProfileStore(disk: disk).register([game])
        let plan = LaunchPlan(executable: URL(fileURLWithPath: "/usr/bin/true"), arguments: [], environment: [:], workingDirectory: root)
        let diagnostic = try SessionDiagnostics(game: game, plan: plan, disk: disk)
        try Data("warn: d3d9 test issue\n".utf8).write(to: diagnostic.renderer.appendingPathComponent("d3d9.log"))
        try Data(repeating: 65, count: 1024 * 1024).write(to: diagnostic.renderer.appendingPathComponent("large.log"))
        try Data("must not be sent".utf8).write(to: diagnostic.folder.appendingPathComponent("loginusers.vdf"))
        try FileManager.default.createSymbolicLink(at: diagnostic.renderer.appendingPathComponent("secret.log"), withDestinationURL: diagnostic.folder.appendingPathComponent("loginusers.vdf"))
        let zip = try await SupportReports.prepare(game: game, session: diagnostic.folder, disk: disk, reproduction: "New game > black screen")
        let stage = zip.deletingLastPathComponent().appendingPathComponent("MacDeck-Report")
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let report = try decoder.decode(SupportReportManifest.self, from: Data(contentsOf: stage.appendingPathComponent("issue-report.json")))
        guard report.steamAppID == "214830", report.gameKey == "steam:214830", !report.automaticPromotionAllowed,
              report.includedFiles.contains("Renderer/d3d9.log"), !report.includedFiles.contains(where: { $0.contains("secret") || $0.contains("loginusers") }),
              !report.limitations.isEmpty,
              (try Data(contentsOf: stage.appendingPathComponent("Renderer/large.log"))).count == 512 * 1024 else {
            print("Fixture files: \(report.includedFiles); limits: \(report.limitations); large: \((try? Data(contentsOf: stage.appendingPathComponent("Renderer/large.log")).count) ?? -1)")
            throw DeckError.message("support metadata, bounded logs or exclusion check failed")
        }
        let unzip = Process(), pipe = Pipe()
        unzip.executableURL = URL(fileURLWithPath: "/usr/bin/unzip"); unzip.arguments = ["-Z1", zip.path]
        unzip.standardOutput = pipe; unzip.standardError = FileHandle.nullDevice
        try unzip.run()
        let listing = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        unzip.waitUntilExit()
        guard unzip.terminationStatus == 0, listing.contains("issue-report.json"), listing.contains("d3d9.log"), !listing.contains("secret.log"), !listing.contains("loginusers.vdf") else { throw DeckError.message("ZIP contents verification failed") }
        print("PASS: real ZIP creation, schema round-trip, Steam App ID, DB key, renderer logs, size bounds, auth-file and symlink exclusion; email not sent")
    }
}
