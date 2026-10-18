import Foundation
import Metal

struct SessionRecord: Codable {
    var schema = 1
    var sessionID: UUID
    var gameID: UUID
    var game: String
    var steamAppID: String?
    var relatedSteamSessionID: UUID?
    var kind: String
    var started: Date
    var ended: Date?
    var appVersion: String
    var gpu: String?
    var operatingSystem: String
    var wine: String?
    var executable: String
    var arguments: [String]
    var workingDirectory: String
    var environment: [String: String]
    var processID: Int32?
    var exitCode: Int32?
    var termination: String?
    var status: String
    var notes: [String]
}

final class SessionDiagnostics {
    let folder: URL
    let output: URL
    let renderer: URL
    private(set) var record: SessionRecord

    static func safeArguments(_ arguments: [String]) -> [String] {
        var redact = 0
        return arguments.map { value in
            if redact > 0 && !value.hasPrefix("-") { redact -= 1; return "<redacted>" }
            if value.hasPrefix("-") { redact = 0 }
            let key = value.lowercased()
            if ["password", "token", "secret", "auth", "login"].contains(where: { key.hasPrefix("-") && key.contains($0) }) {
                redact = value.contains("=") ? 0 : key.contains("login") ? 2 : 1
                return value.contains("=") ? String(value.prefix(while: { $0 != "=" })) + "=<redacted>" : value
            }
            return value
        }
    }
    init(game: Game, plan: LaunchPlan, disk: LibraryDisk, runtimeManifest: URL? = nil) throws {
        let id = UUID(), started = Date()
        let stamp = ISO8601DateFormatter().string(from: started).replacingOccurrences(of: ":", with: "-")
        folder = disk.logs.appendingPathComponent("Sessions/" + stamp + "-" + id.uuidString, isDirectory: true)
        output = folder.appendingPathComponent("process.log")
        renderer = folder.appendingPathComponent("Renderer", isDirectory: true)
        let steam = URL(fileURLWithPath: game.path).lastPathComponent.lowercased() == "steam.exe"
        let kind = game.steamAppID != nil ? "steam-launch-request" : steam ? "steam-client" : "direct-process"
        record = SessionRecord(sessionID: id, gameID: game.id, game: game.name, steamAppID: game.steamAppID,
            kind: kind, started: started, appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "development",
            gpu: MTLCreateSystemDefaultDevice()?.name, operatingSystem: ProcessInfo.processInfo.operatingSystemVersionString, wine: game.kind == .windows ? plan.executable.path : nil,
            executable: game.path, arguments: steam ? [] : Self.safeArguments(game.arguments), workingDirectory: plan.workingDirectory.path,
            environment: plan.environment.filter { [
                "WINEPREFIX", "WINEDLLOVERRIDES", "WINEDEBUG", "DXMT_LOG_LEVEL", "MTL_HUD_ENABLED", "SDL_RENDER_DRIVER",
                "MVK_CONFIG_RESUME_LOST_DEVICE", "WINEMSYNC", "WINEESYNC", "WINEMSYNC_QLIMIT", "WINE_LARGE_ADDRESS_AWARE",
                "DXMT_CONFIG", "MVK_CONFIG_USE_METAL_ARGUMENT_BUFFERS", "MVK_CONFIG_PREFILL_METAL_COMMAND_BUFFERS",
                "VKD3D_FEATURE_LEVEL", "VKD3D_CONFIG"
            ].contains($0.key) },
            status: "prepared", notes: [])
        if game.steamAppID != nil {
            record.relatedSteamSessionID = Self.entries(disk: disk).first { $0.record.kind == "steam-client" && $0.record.environment["WINEPREFIX"] == plan.environment["WINEPREFIX"] }?.record.sessionID
        }
        if steam { record.notes.append("Steam stdout, raw stderr and launch arguments are excluded. A separate filter retains only allowlisted Vulkan/MoltenVK graphics errors to protect authentication data.") }
        if game.steamAppID != nil { record.notes.append("This process sends a Steam launch request. Its exit code is not the game's exit code. Graphics logs belong to the running Steam client session.") }
        record.notes.append("Last recorded process state only; application termination can prevent the final status update.")
        try FileManager.default.createDirectory(at: renderer, withIntermediateDirectories: true)
        try Data("MacDeck session \(id.uuidString)\n\(steam ? "Steam process output excluded.\n" : "")".utf8).write(to: output)
        if let runtimeManifest, FileManager.default.fileExists(atPath: runtimeManifest.path) {
            try FileManager.default.copyItem(at: runtimeManifest, to: folder.appendingPathComponent("runtime-manifest.json"))
        }
        try Data("""
        MacDeck diagnostic bundle
        Session: \(id.uuidString)
        Reproduction: describe the steps, expected result and actual result when sharing this bundle.
        diagnostics.json: app/OS/runtime, selected environment, process status and exit code.
        process.log: direct game output; Steam process output is intentionally excluded.
        Renderer/: per-session DXMT logs. Steam games use the running Steam client's Renderer directory.
        Shader/compiler warnings and crash evidence may help explain rendering failures, but logs alone cannot guarantee a diagnosis.
        No Steam authentication files, memory dumps, game saves or screenshots are collected.
        The bundle contains local paths and game output. Review it before sharing.
        """.utf8).write(to: folder.appendingPathComponent("README.txt"))
        try save()
    }
    private func save() throws {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]; encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(record).write(to: folder.appendingPathComponent("diagnostics.json"), options: .atomic)
    }
    func started(pid: Int32) throws { record.processID = pid; record.status = "running"; try save() }
    func finish(code: Int32, signaled: Bool) throws {
        record.ended = Date(); record.exitCode = code; record.termination = signaled ? "signal" : "exit"
        record.status = !signaled && record.kind == "steam-client" && code == 42 ? "client-bootstrap-handoff" : signaled ? "terminated-by-signal" : record.kind == "steam-launch-request" ? "request-process-ended" : code == 0 ? "process-exited" : "process-failed"
        try save()
    }
    func failedToStart(_ message: String) throws { record.status = "failed-to-start"; record.ended = Date(); record.notes.append(message); try save() }
    struct Entry: Identifiable {
        var folder: URL
        var record: SessionRecord
        var id: UUID { record.sessionID }
    }
    static func entries(disk: LibraryDisk) -> [Entry] {
        let root = disk.logs.appendingPathComponent("Sessions")
        let folders = (try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? []
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        return folders.compactMap { folder -> Entry? in
            guard let bytes = try? Data(contentsOf: folder.appendingPathComponent("diagnostics.json")), let record = try? decoder.decode(SessionRecord.self, from: bytes) else { return nil }
            return Entry(folder: folder, record: record)
        }.sorted { $0.record.started > $1.record.started }
    }
    static func latest(gameID: UUID, disk: LibraryDisk) -> URL? {
        entries(disk: disk).first { $0.record.gameID == gameID }?.folder
    }
    static func summary(folder: URL) throws -> String {
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let record = try decoder.decode(SessionRecord.self, from: Data(contentsOf: folder.appendingPathComponent("diagnostics.json")))
        let patterns: [(String, String)] = [
            ("code=c0000005", "메모리 접근 위반 예외입니다. 예외 주소와 로드된 모듈을 비교해야 하며 이 코드만으로 GPU 또는 영상 재생 문제로 확정할 수 없습니다."),
            ("gpu timeout", "Metal GPU 작업 시간 초과가 기록됐습니다. 이후 VK_ERROR_DEVICE_LOST가 있으면 렌더링을 계속할 수 없는 상태일 수 있습니다. Game Mode Off와 구분해 셰이더/명령 제출 경로를 조사하세요."),
            ("createmetalview", "Metal 화면 생성 경로를 확인하세요."),
            ("17399d75-964e-4c03-99f8-9d4fd196dd62", "Direct3D 12 어댑터 인터페이스(IWineDXGIAdapter) 조회 단서입니다. 게임 실행 설정에서 DirectX 12(VKD3D · MoltenVK) 백엔드와 D3D12용 dxgi.dll 적용 상태를 확인하세요."),
            ("d3d12createdevicefailed", "Direct3D 12 장치 생성 실패 단서입니다. MoltenVK(libvulkan.1.dylib) 연결 및 D3D12 백엔드 구성을 확인하세요."),
            ("vk_error_device_lost", "Vulkan GPU 장치 손실 단서입니다. MoltenVK 오류와 직전 셰이더/커맨드 제출 로그를 함께 확인하세요."),
            ("dxgi_error_device_removed", "GPU 장치 손실이 기록됐습니다. GPU/셰이더 로그와 재현 상황을 함께 확인하세요."),
            ("dxgi_error_device_hung", "GPU 작업 정지가 기록됐습니다. 셰이더와 프레임 제출 경로를 확인하세요."),
            ("failed to compile", "컴파일 실패 단서입니다. 해당 셰이더/오류 메시지를 확인하세요."),
            ("unsupported feature level", "요청된 Direct3D 기능 수준과 런타임 지원을 확인하세요."),
            ("unhandled exception", "처리되지 않은 예외 단서입니다. 종료 코드와 인접 로그를 확인하세요."),
            ("import_dll", "DLL 로드 문제 단서입니다. 누락된 의존성과 런타임을 확인하세요.")
        ]
        var lines = ["MacDeck 진단 요약", "게임: " + record.game, "세션: " + record.sessionID.uuidString,
            "마지막 기록 상태: " + record.status, "종료 코드: " + (record.exitCode.map(String.init) ?? "미기록"),
            "GPU: " + (record.gpu ?? "미확인"), "", "아래 항목은 로그 단서이며 확정된 원인이 아닙니다."]
        let renderer = folder.appendingPathComponent("Renderer")
        var logs = [folder.appendingPathComponent("process.log")]
        logs += ((try? FileManager.default.contentsOfDirectory(at: renderer, includingPropertiesForKeys: nil)) ?? []).filter { $0.pathExtension == "log" }
        let related = folder.appendingPathComponent("RelatedSteamRenderer")
        logs += ((try? FileManager.default.contentsOfDirectory(at: related, includingPropertiesForKeys: nil)) ?? []).filter { $0.pathExtension == "log" }
        var found = false
        for file in logs {
            guard let handle = try? FileHandle(forReadingFrom: file) else { continue }
            defer { try? handle.close() }
            let size = try handle.seekToEnd(); try handle.seek(toOffset: size > 524288 ? size - 524288 : 0)
            let text = String(decoding: try handle.readToEnd() ?? Data(), as: UTF8.self)
            for (pattern, advice) in patterns {
                if let line = text.components(separatedBy: .newlines).first(where: { $0.lowercased().contains(pattern) }) {
                    found = true; lines.append("[" + file.lastPathComponent + "] " + advice); lines.append(String(line.prefix(300)))
                }
            }
        }
        if !found { lines.append("알려진 패턴을 찾지 못했습니다. 정상 동작을 의미하지는 않습니다. 재현 절차와 원본 로그를 함께 확인하세요.") }
        if record.kind == "steam-launch-request" { lines.append("Steam 실행 요청의 종료 상태입니다. 실제 게임 종료 여부와 구별해야 합니다.") }
        let text = lines.joined(separator: "\n") + "\n"
        try Data(text.utf8).write(to: folder.appendingPathComponent("summary.txt"), options: .atomic)
        return text
    }
    static func export(folder: URL, to destination: URL) async throws {
        let disk = LibraryDisk(root: folder.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent())
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let record = try decoder.decode(SessionRecord.self, from: Data(contentsOf: folder.appendingPathComponent("diagnostics.json")))
        if let related = record.relatedSteamSessionID,
           let entry = entries(disk: disk).first(where: { $0.record.sessionID == related && $0.record.kind == "steam-client" && $0.record.environment["WINEPREFIX"] == record.environment["WINEPREFIX"] }) {
            let target = folder.appendingPathComponent("RelatedSteamRenderer")
            if FileManager.default.fileExists(atPath: target.path) { try FileManager.default.removeItem(at: target) }
            try FileManager.default.copyItem(at: entry.folder.appendingPathComponent("Renderer"), to: target)
        }
        _ = try summary(folder: folder)
        let process = Process(); process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-c", "-k", "--keepParent", folder.path, destination.path]
        process.standardOutput = FileHandle.nullDevice; process.standardError = FileHandle.nullDevice
        try process.run()
        while process.isRunning { try await Task.sleep(nanoseconds: 150_000_000) }
        guard process.terminationStatus == 0 else { throw DeckError.message("진단 ZIP을 저장하지 못했습니다.") }
    }
}
