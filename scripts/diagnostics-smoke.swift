import Foundation
@main struct DiagnosticsSmoke {
    static func main() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("macdeck-diagnostics-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let disk = LibraryDisk(root: root)
        let game = Game(name: "Controlled failing process", path: "/usr/bin/false", kind: .executable)
        let plan = try LaunchPlan.make(game: game, wine: nil, disk: disk)
        let log = try SessionDiagnostics(game: game, plan: plan, disk: disk)
        let process = Process(); process.executableURL = plan.executable
        let output = try FileHandle(forWritingTo: log.output)
        process.standardOutput = output; process.standardError = output
        try process.run(); try log.started(pid: process.processIdentifier)
        process.waitUntilExit(); try output.close()
        try log.finish(code: process.terminationStatus, signaled: false)
        guard log.record.exitCode == 1 && log.record.status == "process-failed" else { fatalError("Exit status not captured") }
        let fake = root.appendingPathComponent("Steam.exe"); try Data([0x4d,0x5a]).write(to: fake)
        var client = Game(name: "Steam test", path: fake.path, kind: .windows); client.prefix = root.appendingPathComponent("prefix").path
        let clientPlan = try LaunchPlan.make(game: client, wine: "/usr/bin/true", disk: disk)
        let clientLog = try SessionDiagnostics(game: client, plan: clientPlan, disk: disk)
        try Data("err: DXGI_ERROR_DEVICE_REMOVED\n".utf8).write(to: clientLog.renderer.appendingPathComponent("test.log"))
        var request = client; request.steamAppID = "123"; request.id = UUID()
        let requestLog = try SessionDiagnostics(game: request, plan: clientPlan, disk: disk)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("private"), withIntermediateDirectories: true)
        try Data("never-export-auth".utf8).write(to: root.appendingPathComponent("private/loginusers.vdf"))
        let archive = root.appendingPathComponent("diagnostic.zip")
        try await SessionDiagnostics.export(folder: requestLog.folder, to: archive)
        let unzip = Process(); unzip.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        unzip.arguments = ["-l", archive.path]; let pipe = Pipe(); unzip.standardOutput = pipe
        try unzip.run(); let bytes = pipe.fileHandleForReading.readDataToEndOfFile(); unzip.waitUntilExit()
        let names = String(decoding: bytes, as: UTF8.self)
        guard unzip.terminationStatus == 0 && names.contains("diagnostics.json") && names.contains("RelatedSteamRenderer/test.log") && names.contains("summary.txt") && !names.contains("loginusers.vdf") else { fatalError("Archive content incorrect: \(names)") }
        print("PASS: actual failing process exit code captured")
        print("PASS: exported ZIP contains correlated Steam graphics logs and summary")
        print("PASS: unrelated authentication files excluded")
    }
}
