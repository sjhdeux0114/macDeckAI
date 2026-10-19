import Foundation
import AppKit
import SwiftUI
import CryptoKit

struct SupportReportManifest: Codable {
    var schema = 1
    var kind = "macdeck-game-issue"
    var reportID: UUID
    var gameKey: String
    var gameName: String
    var steamAppID: String?
    var engine: String
    var profileRevision: Int
    var recordedStatus: GameCompatibilityStatus
    var reportStatus = "unverified-user-report"
    var sessionID: UUID
    var sessionKind: String
    var reportedAt: Date
    var reproduction: String
    var includedFiles: [String] = []
    var limitations: [String] = []
    // An importer must explicitly review reports; receiving a ZIP is not validation.
    var automaticPromotionAllowed = false
}

enum SupportReports {
    static let recipient = "sjhdeux@gmail.com"
    static func manifest(game: Game, session: SessionRecord, profile: GameProfile, reproduction: String) -> SupportReportManifest {
        SupportReportManifest(reportID: UUID(), gameKey: profile.id, gameName: game.name,
            steamAppID: game.steamAppID, engine: profile.engine, profileRevision: profile.revision,
            recordedStatus: profile.status, sessionID: session.sessionID, sessionKind: session.kind,
            reportedAt: Date(), reproduction: String(reproduction.prefix(12_000)))
    }
    static func prepare(game: Game, session: URL, disk: LibraryDisk, reproduction: String) async throws -> URL {
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let record = try decoder.decode(SessionRecord.self, from: Data(contentsOf: session.appendingPathComponent("diagnostics.json")))
        guard record.gameID == game.id, record.steamAppID == game.steamAppID else { throw DeckError.message("선택한 게임과 실행 기록이 일치하지 않습니다.") }
        var profile = try GameProfileStore(disk: disk).profile(game)
        let snapshot = session.appendingPathComponent("game-profile.json")
        if let size = try? snapshot.resourceValues(forKeys: [.fileSizeKey]).fileSize, size <= 2 * 1024 * 1024,
           let bytes = try? Data(contentsOf: snapshot), let recorded = try? JSONDecoder().decode(GameProfile.self, from: bytes),
           recorded.id == profile.id || recorded.id == profile.id + ":trial" { profile = recorded }
        var report = manifest(game: game, session: record, profile: profile, reproduction: reproduction)
        let parent = disk.logs.appendingPathComponent("SupportReports/" + report.reportID.uuidString)
        let staging = parent.appendingPathComponent("MacDeck-Report", isDirectory: true)
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        var budget = 12 * 1024 * 1024
        // Tail bounded logs; never include auth folders, account config, crash dumps or symlinks.
        func include(_ source: URL, _ relative: String, limit: Int = 512 * 1024) throws {
            let values = try? source.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
            guard values?.isRegularFile == true, values?.isSymbolicLink != true else { return }
            guard budget > 0 else { report.limitations.append("전체 로그 크기 제한으로 제외: " + relative); return }
            let handle = try FileHandle(forReadingFrom: source); defer { try? handle.close() }
            let size = (try? handle.seekToEnd()) ?? 0
            let cap = min(limit, budget)
            try handle.seek(toOffset: size > UInt64(cap) ? size - UInt64(cap) : 0)
            let bytes = try handle.read(upToCount: cap) ?? Data()
            if size > UInt64(cap) { report.limitations.append("마지막 \(cap)바이트만 포함: " + relative) }
            let target = staging.appendingPathComponent(relative)
            try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            try bytes.write(to: target)
            budget -= bytes.count; report.includedFiles.append(relative)
        }
        _ = try? SessionDiagnostics.summary(folder: session)
        for name in ["diagnostics.json", "summary.txt", "compatibility.json", "game-profile.json", "runtime-manifest.json"] {
            // JSON must remain parseable: these bounded metadata files are copied whole or excluded.
            let file = session.appendingPathComponent(name)
            if ((try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) <= 2 * 1024 * 1024 { try include(file, name, limit: 2 * 1024 * 1024) }
        }
        if let id = game.steamAppID, let prefix = record.environment["WINEPREFIX"] {
            let key = SHA256.hash(data: Data(URL(fileURLWithPath: prefix).standardizedFileURL.path.utf8)).map { String(format: "%02x", $0) }.joined()
            for package in DependencyCatalog.packages {
                let file = disk.root.appendingPathComponent("Dependencies/" + key + "/" + package.id + ".json")
                let attrs = try? file.resourceValues(forKeys: [.isSymbolicLinkKey,.fileSizeKey])
                guard attrs?.isSymbolicLink == false, (attrs?.fileSize ?? Int.max) <= 65536,
                      let bytes = try? Data(contentsOf: file), let attempt = try? JSONDecoder().decode(DependencyAttempt.self, from: bytes),
                      attempt.packageID == package.id, attempt.appIDs.contains(id) else { continue }
                try include(file, "Dependencies/" + package.id + ".json", limit: 65536)
            }
        }
        // Steam stdout is never captured by MacDeck; direct game logs may contain local paths.
        try include(session.appendingPathComponent("process.log"), "process.log")
        func includeRenderer(_ sourceRoot: URL, prefix: String) throws {
            guard (try? sourceRoot.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) != true else { report.limitations.append("심볼릭 링크 폴더 제외: " + prefix); return }
            let root = sourceRoot.resolvingSymlinksInPath().standardizedFileURL
            guard let files = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isSymbolicLinkKey], options: [.skipsHiddenFiles]) else { return }
            var visited = 0
            while let file = files.nextObject() as? URL {
                visited += 1
                if visited > 200 { report.limitations.append("렌더러 파일 수 제한: " + prefix); break }
                if (try? file.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true { files.skipDescendants(); continue }
                let canonical = file.standardizedFileURL.path
                guard canonical.hasPrefix(root.path + "/") else { continue }
                let relative = String(canonical.dropFirst(root.path.count + 1))
                if relative.split(separator: "/").count > 2 { files.skipDescendants(); continue }
                if ["log", "txt"].contains(file.pathExtension.lowercased()) { try include(file, prefix + "/" + relative) }
            }
        }
        try includeRenderer(session.appendingPathComponent("Renderer"), prefix: "Renderer")
        if let related = record.relatedSteamSessionID,
           let steam = SessionDiagnostics.entries(disk: disk).first(where: { $0.record.sessionID == related && $0.record.kind == "steam-client" && $0.record.environment["WINEPREFIX"] == record.environment["WINEPREFIX"] }) {
            try includeRenderer(steam.folder.appendingPathComponent("Renderer"), prefix: "RelatedSteamRenderer")
        }
        report.limitations.append("Steam 게임 요청의 종료 코드는 실제 게임 종료 코드가 아닙니다. GPU 가속 성공 및 원인은 별도 검증해야 합니다.")
        report.includedFiles.append("issue-report.json")
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601; encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(report).write(to: staging.appendingPathComponent("issue-report.json"), options: .atomic)
        let destination = parent.appendingPathComponent("MacDeck-" + (game.steamAppID ?? game.id.uuidString) + "-report.zip")
        let zip = Process(); zip.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        zip.arguments = ["-c", "-k", "--keepParent", staging.path, destination.path]
        zip.standardOutput = FileHandle.nullDevice; zip.standardError = FileHandle.nullDevice
        try zip.run()
        while zip.isRunning { try await Task.sleep(nanoseconds: 100_000_000) }
        guard zip.terminationStatus == 0 else { throw DeckError.message("오류 신고 ZIP을 만들지 못했습니다.") }
        return destination
    }
}

@MainActor
final class SupportMailComposer: NSObject, NSSharingServiceDelegate {
    private var service: NSSharingService?
    private var failure: ((String) -> Void)?
    func compose(game: Game, attachment: URL, reproduction: String, failure: @escaping (String) -> Void) {
        self.failure = failure
        let body = """
        MacDeck 게임 오류 신고
        게임: \(game.name)
        Steam App ID: \(game.steamAppID ?? "비 Steam 게임")
        DB Key: \(GameProfileStore.identity(game))

        재현 상황:
        \(reproduction)

        첨부 ZIP의 issue-report.json에 DB 등록용 게임 식별자와 검증 상태가 있습니다.
        전송 전에 로그와 로컬 경로를 확인해 주세요.
        """
        let items: [Any] = [body, attachment]
        guard let mail = NSSharingService(named: .composeEmail), mail.canPerform(withItems: items) else {
            failure("메일 앱을 사용할 수 없어 ZIP을 Finder에 표시합니다. \(SupportReports.recipient)로 직접 첨부해 보내 주세요."); return
        }
        service = mail; mail.delegate = self
        mail.recipients = [SupportReports.recipient]
        mail.subject = "[MacDeck 오류] " + game.name + " · " + (game.steamAppID ?? "non-Steam")
        mail.perform(withItems: items)
    }
    func sharingService(_ sharingService: NSSharingService, didFailToShareItems items: [Any], error: Error) {
        failure?("메일 작성 창을 열지 못했습니다. ZIP은 저장되어 있습니다. \(SupportReports.recipient)로 직접 첨부해 주세요. " + error.localizedDescription)
    }
}

struct SupportReportView: View {
    let game: Game
    @ObservedObject var model: DeckModel
    @DeckState private var reproduction = "발생 위치 / 재현 순서:\n\n기대 동작:\n\n실제 증상 (크래시·멈춤·화면 오류 등):\n"
    @StateObject private var pads = GamepadMonitor()
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("게임 오류 신고").font(.largeTitle.bold())
            Text(game.name + " · Steam App ID: " + (game.steamAppID ?? "비 Steam 게임")).font(.headline)
            Text("받는 사람: " + SupportReports.recipient).foregroundStyle(consoleReportAccent)
            TextEditor(text: $reproduction).font(.body).frame(height: 200)
            Text("진단 로그·GPU 정보·프로필과 DB 등록용 JSON을 ZIP으로 첨부합니다. Steam 인증 파일과 메모리 덤프는 제외합니다. 로그에는 로컬 경로와 게임 출력이 포함될 수 있습니다. 메일 작성 창에서 검토 후 직접 전송하세요.")
                .font(.callout).foregroundStyle(.secondary)
            HStack {
                Button("취소 · Esc") { dismiss() }.buttonStyle(ConsoleSecondaryButtonStyle()).keyboardShortcut(.cancelAction)
                Spacer()
                Button("ZIP 폴더 보기") { NSWorkspace.shared.open(model.disk.logs.appendingPathComponent("SupportReports")) }.buttonStyle(ConsoleSecondaryButtonStyle())
                Button(model.preparingSupportReport ? "준비 중…" : "ZIP 만들고 메일 작성 · " + ControllerHints(layout: pads.pads.first?.layout ?? .xbox).details) { submit() }
                    .buttonStyle(.borderedProminent).disabled(model.preparingSupportReport)
            }
        }.padding(32).frame(width: 650).background(Color(red: 0.065, green: 0.10, blue: 0.14))
            .onAppear { pads.acceptsAttachedSheet = true; pads.onAction = { action in if action == .back { dismiss() }; if action == .details { submit() } } }
    }
    private func submit() { model.emailSupportReport(game, reproduction: reproduction); dismiss() }
    private var consoleReportAccent: Color { Color(red: 0.57, green: 0.94, blue: 0.73) }
}
