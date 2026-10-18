import AppKit
import Foundation
import UniformTypeIdentifiers

struct RuntimeStatus {
    var path: String?
    var intelAvailable: Bool
    var requiresIntel: Bool
    var version: String = "아직 검사하지 않음"
    var ready: Bool { path != nil && (!requiresIntel || intelAvailable) }
}

enum Runtime {
    static var bundledWine: String? {
        guard let resources = Bundle.main.resourceURL else { return nil }
        let folder = resources.appendingPathComponent("Runtime")
        return ["bin/wine64", "bin/wine"].map { folder.appendingPathComponent($0).path }
            .first { FileManager.default.isExecutableFile(atPath: $0) }
    }
    static let candidates = [
        "/Applications/Wine Stable.app/Contents/Resources/wine/bin/wine",
        "/Applications/Wine Stable.app/Contents/Resources/wine/bin/wine64",
        "/Applications/Wine Staging.app/Contents/Resources/wine/bin/wine",
        "/Applications/Wine Devel.app/Contents/Resources/wine/bin/wine",
        "/opt/homebrew/bin/wine", "/usr/local/bin/wine"
    ]

    static func resolve(_ path: String) -> String? {
        if FileManager.default.isExecutableFile(atPath: path), !path.hasSuffix(".app") { return path }
        for relative in ["Contents/Resources/wine/bin/wine", "Contents/Resources/wine/bin/wine64"] {
            let candidate = URL(fileURLWithPath: path).appendingPathComponent(relative).path
            if FileManager.default.isExecutableFile(atPath: candidate) { return candidate }
        }
        return nil
    }

    static func isIntelOnly(_ path: String) -> Bool {
        guard let handle = FileHandle(forReadingAtPath: URL(fileURLWithPath: path).resolvingSymlinksInPath().path) else { return false }
        defer { try? handle.close() }
        let bytes = [UInt8]((try? handle.read(upToCount: 4096)) ?? Data())
        func u32(_ offset: Int, big: Bool) -> UInt32 {
            guard offset + 4 <= bytes.count else { return 0 }
            return (0..<4).reduce(UInt32(0)) { value, i in value | UInt32(bytes[offset + i]) << (big ? (3 - i) * 8 : i * 8) }
        }
        guard bytes.count >= 8 else { return false }
        if u32(0, big: false) == 0xfeedfacf { return u32(4, big: false) == 0x01000007 }
        if u32(0, big: true) == 0xcafebabe {
            let count = min(Int(u32(4, big: true)), 100)
            let types = (0..<count).map { u32(8 + $0 * 20, big: true) }
            return types.contains(0x01000007) && !types.contains(0x0100000c)
        }
        return false
    }

    static func inspect(custom: String) -> RuntimeStatus {
        let supplied = custom.isEmpty ? ProcessInfo.processInfo.environment["MACDECK_WINE"] : custom
        let path = supplied.flatMap(resolve) ?? (supplied == nil ? (bundledWine ?? candidates.compactMap(resolve).first) : nil)
        #if arch(arm64)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/arch")
        process.arguments = ["-x86_64", "/usr/bin/true"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        let intel: Bool
        do { try process.run(); process.waitUntilExit(); intel = process.terminationStatus == 0 }
        catch { intel = false }
        #else
        let intel = true
        #endif
        return RuntimeStatus(path: path, intelAvailable: intel, requiresIntel: path.map(isIntelOnly) ?? false)
    }

    static func steamApp() -> URL? {
        let candidates = ["/Applications/Steam.app", NSHomeDirectory() + "/Applications/Steam.app"]
        return candidates.first(where: { FileManager.default.fileExists(atPath: $0) }).map { URL(fileURLWithPath: $0) }
    }
}

@MainActor
final class DeckModel: ObservableObject {
    @Published var library = LibraryData()
    @Published var selected: UUID?
    @Published var page = "steam"
    @Published var search = ""
    @Published var message: String?
    @Published var runtime = RuntimeStatus(intelAvailable: false, requiresIntel: false)
    @Published var sessions: Set<UUID> = []
    @Published var lastLogs: [UUID: URL] = [:]
    @Published var testingRuntime = false
    @Published var downloadingSteam = false
    @Published var steamProgress = ""
    @Published var managingStorage = false
    @Published var runtimeComponents: [RuntimeComponentStatus] = []
    @Published var checkingUpdates = false
    @Published var updatingComponents = false
    @Published var updateBannerMessage = ""
    let disk: LibraryDisk
    private var writable = true
    private var processes: [UUID: Process] = [:]
    private var graphicsFilters: [UUID: Process] = [:]
    private var nativeApps: [UUID: NSRunningApplication] = [:]
    private var logHandles: [UUID: FileHandle] = [:]
    private var timer: Timer?
    @Published private var refreshTick = 0
    private var didStart = false

    init(disk: LibraryDisk = .standard) {
        self.disk = disk
        do { library = try disk.load() }
        catch { writable = false; message = "라이브러리를 읽지 못했습니다. 원본 파일은 보존됩니다.\n\(error.localizedDescription)" }
        if writable, !FileManager.default.fileExists(atPath: disk.file.path),
           let source = Bundle.main.resourceURL?.appendingPathComponent("Games/BrogueCE-windows"),
           FileManager.default.fileExists(atPath: source.path) {
            do {
                let games = disk.root.appendingPathComponent("Games", isDirectory: true)
                try FileManager.default.createDirectory(at: games, withIntermediateDirectories: true)
                let destination = games.appendingPathComponent("BrogueCE-windows", isDirectory: true)
                if !FileManager.default.fileExists(atPath: destination.path) { try FileManager.default.copyItem(at: source, to: destination) }
                var game = try Game.importing(destination.appendingPathComponent("brogue.exe"))
                game.name = "Brogue CE · Windows"
                library.games = [game]
                try disk.save(library)
            } catch { message = "무료 게임 준비에 실패했습니다: \(error.localizedDescription)" }
        }
        selected = library.games.first?.id
        runtime = Runtime.inspect(custom: library.winePath)
        DirectX12Support.applyGlobal(mode: graphicsBackend, wine: runtime.path, games: library.games, disk: disk)
        reloadRuntimeComponents()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                for (id, app) in self.nativeApps where app.isTerminated {
                    self.nativeApps.removeValue(forKey: id)
                    self.sessions.remove(id)
                }
                self.refreshTick += 1
                if self.refreshTick % 5 == 0 { self.refreshSteamGames(silent: true) }
            }
        }
    }

    var game: Game? { library.games.first { $0.id == selected } }
    var filtered: [Game] { library.games.filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) } }
    var graphicsBackend: GraphicsBackend { library.graphicsBackend ?? .dxmt }
    var autoUpdateRuntime: Bool { library.autoUpdateRuntime ?? true }
    var availableUpdateCount: Int { runtimeComponents.filter(\.updateAvailable).count }

    private func commit(_ changed: LibraryData) throws {
        guard writable else { throw DeckError.message("읽기 오류가 있는 라이브러리는 덮어쓰지 않습니다. 데이터 폴더에서 library.json을 확인해 주세요.") }
        try disk.save(changed)
        library = changed
    }

    func add(_ url: URL) {
        do {
            let game = try Game.importing(url)
            if let existing = library.games.first(where: { $0.path == game.path }) { selected = existing.id; page = "library"; return }
            DirectX12Support.applyGlobal(mode: graphicsBackend, wine: runtime.path, games: [game], disk: disk)
            var data = library
            data.games.append(game)
            try commit(data)
            selected = game.id
            page = "library"
        } catch { message = error.localizedDescription }
    }

    func chooseGame() {
        let panel = NSOpenPanel()
        panel.title = "게임 추가"
        panel.message = "macOS 앱(.app), Windows 게임(.exe), 실행 파일을 선택하세요."
        panel.canChooseDirectories = false
        panel.treatsFilePackagesAsDirectories = false
        panel.allowsMultipleSelection = true
        if panel.runModal() == .OK { panel.urls.forEach(add) }
    }

    func saveGame(_ game: Game) {
        do {
            guard let index = library.games.firstIndex(where: { $0.id == game.id }) else { return }
            DirectX12Support.applyGlobal(mode: graphicsBackend, wine: runtime.path, games: [game], disk: disk)
            var data = library
            data.games[index] = game
            try commit(data)
        } catch { message = error.localizedDescription }
    }

    func remove(_ id: UUID) {
        do {
            var data = library
            data.games.removeAll { $0.id == id }
            try commit(data)
            if selected == id { selected = library.games.first?.id }
        } catch { message = error.localizedDescription }
    }

    func chooseRuntime() {
        let panel = NSOpenPanel()
        panel.title = "Wine 앱 또는 wine 실행 파일 선택"
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            do {
                guard let resolved = Runtime.resolve(url.path) else { throw DeckError.message("Wine 앱 번들이나 wine / wine64 실행 파일을 선택해 주세요.") }
                var data = library
                data.winePath = resolved
                try commit(data)
                runtime = Runtime.inspect(custom: resolved)
            } catch { message = error.localizedDescription }
        }
    }

    func resetRuntime() {
        do { var data = library; data.winePath = ""; try commit(data); runtime = Runtime.inspect(custom: "") }
        catch { message = error.localizedDescription }
    }

    func testRuntime() {
        guard !testingRuntime else { return }
        runtime = Runtime.inspect(custom: library.winePath)
        guard let path = runtime.path else { message = "먼저 Wine 실행 파일을 선택해 주세요."; return }
        guard runtime.ready else { message = "이 Wine은 Intel 실행 지원이 필요합니다. 런타임 탭의 설치 안내를 확인해 주세요."; return }
        testingRuntime = true
        let log = disk.root.appendingPathComponent("runtime-check.log")
        Task.detached {
            let result: String
            do {
                try FileManager.default.createDirectory(at: log.deletingLastPathComponent(), withIntermediateDirectories: true)
                FileManager.default.createFile(atPath: log.path, contents: nil)
                let output = try FileHandle(forWritingTo: log)
                defer { try? output.close() }
                let process = Process()
                process.executableURL = URL(fileURLWithPath: path)
                process.arguments = ["--version"]
                var environment = ProcessInfo.processInfo.environment
                environment["DYLD_FALLBACK_LIBRARY_PATH"] = URL(fileURLWithPath: path).resolvingSymlinksInPath()
                    .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("lib").path
                process.environment = environment
                process.standardOutput = output
                process.standardError = output
                try process.run()
                let deadline = Date().addingTimeInterval(10)
                while process.isRunning && Date() < deadline { try? await Task.sleep(nanoseconds: 50_000_000) }
                if process.isRunning { process.terminate(); result = "검사 시간 초과" }
                else {
                    let text = (try? String(contentsOf: log, encoding: .utf8))?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    result = process.terminationStatus == 0 ? String(text.prefix(300)) : "검사 실패: \(String(text.prefix(250)))"
                }
            } catch { result = error.localizedDescription }
            await MainActor.run { self.testingRuntime = false; self.runtime.version = result }
        }
    }

    func chooseExternalLibrary() {
        let picker = NSOpenPanel()
        picker.canChooseFiles = false; picker.canChooseDirectories = true
        picker.allowsMultipleSelection = false
        picker.message = "게임 폴더를 선택하면 Steam을 정상 종료하고 저장 공간에 적용합니다. 실행 중인 게임은 먼저 저장하고 종료하세요."
        picker.prompt = "연결하고 적용"
        guard picker.runModal() == .OK, let folder = picker.url else { return }
        do {
            var data = library
            let entry = try ExternalLibrary.connect(folder: folder, existing: data.externalLibraries ?? [], prefix: SteamClient(disk: disk).prefix)
            data.externalLibraries = (data.externalLibraries ?? []) + [entry]
            do { try commit(data) }
            catch {
                try? FileManager.default.removeItem(at: SteamClient(disk: disk).prefix.appendingPathComponent("dosdevices/" + entry.drive + ":"))
                try? FileManager.default.removeItem(at: entry.marker)
                throw error
            }
            applyExternalLibrary(entry)
        } catch { message = error.localizedDescription }
    }

    func externalLibraryRecognition(_ storage: ExternalLibrary) -> String {
        SteamStorage(client: SteamClient(disk: disk)).recognition(storage)
    }

    func externalLibraryRegistered(_ storage: ExternalLibrary) -> Bool {
        SteamStorage(client: SteamClient(disk: disk)).registered(storage)
    }

    func applyExternalLibrary(_ storage: ExternalLibrary, removing: Bool = false) {
        guard !managingStorage else { return }
        guard writable else { message = "라이브러리 읽기 오류를 먼저 해결해 주세요."; return }
        if removing && !steamInstalled {
            do {
                let old = library
                var data = library; data.externalLibraries = (data.externalLibraries ?? []).filter { $0.id != storage.id }
                try commit(data)
                do { try SteamStorage(client: SteamClient(disk: disk)).unlink(storage) }
                catch { try? commit(old); throw error }
                steamProgress = "폴더 연결을 해제했습니다. 게임 파일은 유지됩니다."
            } catch { message = error.localizedDescription }
            return
        }
        runtime = Runtime.inspect(custom: library.winePath)
        guard runtime.ready, let wine = runtime.path else { page = "runtime"; return }
        guard steamInstalled else { steamProgress = "폴더는 연결했습니다. Steam을 설치한 뒤 적용 버튼을 눌러 주세요."; return }
        managingStorage = true
        steamProgress = "Steam 종료 상태를 확인하고 있습니다. 게임 실행 중이면 먼저 저장하고 종료해 주세요."
        Task {
            defer { managingStorage = false }
            do {
                let service = SteamStorage(client: SteamClient(disk: disk))
                try await service.stopAndWait(wine: wine)
                let running = try await service.isRunning(wine: wine)
                var storage = storage
                if !removing {
                    let corrected = try service.migrateMapping(storage)
                    if corrected != storage {
                        var data = library
                        if let index = data.externalLibraries?.firstIndex(where: { $0.id == storage.id }) { data.externalLibraries?[index] = corrected }
                        do { try commit(data); storage = corrected }
                        catch {
                            let link = service.client.prefix.appendingPathComponent("dosdevices/" + storage.drive + ":")
                            try? FileManager.default.removeItem(at: link)
                            try? FileManager.default.createSymbolicLink(at: link, withDestinationURL: storage.mappingRoot)
                            throw error
                        }
                    }
                }
                try service.update(storage, removing: removing, steamRunning: running)
                if removing {
                    let old = library
                    var data = library
                    data.externalLibraries = (data.externalLibraries ?? []).filter { $0.id != storage.id }
                    data.games.removeAll { $0.steamAppID != nil && ($0.installedLocation?.hasPrefix(storage.installRoot.path + "/") ?? false) }
                    try commit(data)
                    do { try service.unlink(storage) }
                    catch { try? commit(old); throw error }
                    steamProgress = "연결을 해제했습니다. 외장 드라이브의 게임 파일은 그대로 유지됩니다."
                } else {
                    steamProgress = "Steam 설정에 \(storage.windowsLibraryPath)을 등록했습니다. Steam을 시작해 실제 폴더 인식을 확인하세요. 인식 상태는 폴더 목록에 표시됩니다."
                    refreshSteamGames(silent: true)
                    launchSteam()
                }
            } catch { message = error.localizedDescription; steamProgress = "작업을 완료하지 못했습니다. 폴더와 게임 파일을 확인하고 다시 시도해 주세요." }
        }
    }

    func openWindowsControllerTest() {
        let client = SteamClient(disk: disk)
        guard client.executable != nil else { message = "Steam 전용 환경을 먼저 설치해 주세요."; return }
        let control = client.prefix.appendingPathComponent("drive_c/windows/system32/control.exe")
        var game = Game(name: "Windows 게임패드 테스트", path: control.path, kind: .windows)
        game.prefix = client.prefix.path
        game.arguments = ["joy.cpl"]
        launch(game)
    }

    func launch(_ game: Game) {
        let steamCommand = URL(fileURLWithPath: game.path).lastPathComponent.lowercased() == "steam.exe"
        let controllerTest = game.path == SteamClient(disk: disk).prefix.appendingPathComponent("drive_c/windows/system32/control.exe").path && game.arguments == ["joy.cpl"]
        guard !sessions.contains(game.id) || steamCommand else { return }
        let trackSession = game.steamAppID == nil && !sessions.contains(game.id)
        do {
            guard writable else { throw DeckError.message("라이브러리 오류를 해결한 뒤 실행해 주세요.") }
            if let location = game.installedLocation {
                let storage = (library.externalLibraries ?? []).first { location.hasPrefix($0.path + "/") }
                guard (storage?.connected ?? true), FileManager.default.fileExists(atPath: location) else {
                    throw DeckError.message("게임 설치 폴더를 찾을 수 없습니다. 외장 드라이브를 연결한 뒤 다시 시도해 주세요.")
                }
            }
            guard FileManager.default.fileExists(atPath: game.path) else { throw DeckError.message("게임 파일을 찾을 수 없습니다. 편집에서 경로를 확인해 주세요.") }
            if game.kind == .macApp {
                let config = NSWorkspace.OpenConfiguration()
                config.arguments = game.arguments
                sessions.insert(game.id)
                NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: game.path), configuration: config) { [weak self] app, error in
                    Task { @MainActor in
                        guard let self else { return }
                        if let error { self.sessions.remove(game.id); self.message = error.localizedDescription }
                        else if let app { self.nativeApps[game.id] = app; self.markPlayed(game.id) }
                    }
                }
                return
            }
            if game.kind == .windows {
                runtime = Runtime.inspect(custom: library.winePath)
                guard runtime.ready else {
                    page = "runtime"
                    throw DeckError.message(runtime.path == nil ? "Windows 게임을 실행하려면 macOS용 Wine 런타임을 먼저 연결해 주세요." : "선택한 Wine은 Intel 실행 지원이 필요합니다. 설치 안내를 확인해 주세요.")
                }
                let prefix = disk.prefix(for: game)
                guard steamCommand || controllerTest || !library.games.contains(where: { $0.id != game.id && sessions.contains($0.id) && $0.kind == .windows && disk.prefix(for: $0) == prefix }) else {
                    throw DeckError.message("같은 Windows 환경에서 실행 중인 항목이 있습니다. 해당 실행이 끝난 뒤 다시 시도해 주세요.")
                }
                try disk.preparePrefix(for: game)
                if let wine = runtime.path { try WineFonts.prepare(prefix: prefix, wine: wine) }
            }
            var plan = try LaunchPlan.make(game: game, wine: runtime.path, disk: disk)
            let diagnostic = try SessionDiagnostics(game: game, plan: plan, disk: disk,
                runtimeManifest: Bundle.main.resourceURL?.appendingPathComponent("runtime-manifest.json"))
            plan.environment["DXMT_LOG_PATH"] = diagnostic.renderer.path
            if plan.environment["GST_DEBUG"] != nil {
                plan.environment["GST_DEBUG_FILE"] = diagnostic.renderer.appendingPathComponent("gstreamer.log").path
            }
            try FileManager.default.createDirectory(at: disk.logs, withIntermediateDirectories: true)
            let log = diagnostic.output
            let header = "MacDeck session\nGame: \(game.name)\nExecutable: \(plan.executable.path)\nStarted: \(Date())\n\n"
            if !steamCommand { try Data(header.utf8).write(to: log) }
            let output = try FileHandle(forWritingTo: log)
            try output.seekToEnd()
            let process = Process()
            let token = UUID()
            process.executableURL = plan.executable
            process.arguments = plan.arguments
            process.environment = plan.environment
            process.currentDirectoryURL = plan.workingDirectory
            process.standardOutput = steamCommand ? FileHandle.nullDevice : output
            process.standardError = steamCommand ? FileHandle.nullDevice : output
            var graphicsPipe: Pipe?
            if steamCommand, let filter = Bundle.main.executableURL?.deletingLastPathComponent().appendingPathComponent("graphics-log-filter"), FileManager.default.isExecutableFile(atPath: filter.path) {
                let pipe = Pipe(), collector = Process(), collectorID = UUID()
                collector.executableURL = filter
                collector.arguments = [diagnostic.renderer.appendingPathComponent("vulkan-stderr.log").path]
                collector.standardInput = pipe.fileHandleForReading
                collector.standardOutput = FileHandle.nullDevice; collector.standardError = FileHandle.nullDevice
                collector.terminationHandler = { [weak self] _ in
                    Task { @MainActor in self?.graphicsFilters.removeValue(forKey: collectorID) }
                }
                try collector.run()
                graphicsFilters[collectorID] = collector
                try? pipe.fileHandleForReading.close()
                process.standardError = pipe.fileHandleForWriting
                graphicsPipe = pipe
            }
            defer { try? graphicsPipe?.fileHandleForWriting.close() }
            process.terminationHandler = { [weak self] child in
                Task { @MainActor in
                    guard let self else { return }
                    try? diagnostic.finish(code: child.terminationStatus, signaled: child.terminationReason == .uncaughtSignal)
                    if trackSession { self.sessions.remove(game.id) }
                    self.processes.removeValue(forKey: token)
                    try? self.logHandles.removeValue(forKey: token)?.close()
                    if child.terminationStatus != 0 && !(steamCommand && child.terminationStatus == 42) { self.message = "\(game.name)의 실행 프로세스가 코드 \(child.terminationStatus)로 종료됐습니다. 게임 메뉴에서 로그를 확인해 주세요." }
                }
            }
            do { try process.run(); try? diagnostic.started(pid: process.processIdentifier) } catch { try? diagnostic.failedToStart(error.localizedDescription); try? output.close(); throw error }
            processes[token] = process
            logHandles[token] = output
            lastLogs[game.id] = log
            if trackSession { sessions.insert(game.id) }
            markPlayed(game.id)
        } catch { message = error.localizedDescription }
    }

    private func markPlayed(_ id: UUID) {
        guard var game = library.games.first(where: { $0.id == id }) else { return }
        game.lastPlayed = Date()
        saveGame(game)
    }

    func exportDiagnostics(_ game: Game) {
        guard let folder = SessionDiagnostics.latest(gameID: game.id, disk: disk) else { message = "진단 기록이 없습니다. 업데이트된 앱에서 게임을 실행한 뒤 다시 시도해 주세요."; return }
        let picker = NSSavePanel(); picker.allowedContentTypes = [.zip]
        picker.nameFieldStringValue = "MacDeck-" + game.id.uuidString + ".zip"
        picker.message = "로컬 경로와 게임 로그가 포함됩니다. 공유 전에 내용을 검토하세요. Steam 게임의 그래픽 로그는 Steam 클라이언트 진단 묶음에도 있습니다."
        guard picker.runModal() == .OK, let destination = picker.url else { return }
        Task {
            do { try await SessionDiagnostics.export(folder: folder, to: destination); NSWorkspace.shared.activateFileViewerSelecting([destination]) }
            catch { message = error.localizedDescription }
        }
    }

    func showLog(_ game: Game) {
        if let folder = SessionDiagnostics.latest(gameID: game.id, disk: disk) { _ = try? SessionDiagnostics.summary(folder: folder); NSWorkspace.shared.open(folder); return }
        let url = lastLogs[game.id] ?? (try? FileManager.default.contentsOfDirectory(at: disk.logs, includingPropertiesForKeys: nil))?
            .filter { $0.lastPathComponent.hasPrefix(game.id.uuidString) }.sorted { $0.lastPathComponent > $1.lastPathComponent }.first
        if let url { NSWorkspace.shared.open(url) }
        else { message = "이 게임의 실행 로그가 아직 없습니다. macOS 앱은 자체 로그를 사용합니다." }
    }

    func revealData() {
        do { try FileManager.default.createDirectory(at: disk.root, withIntermediateDirectories: true); NSWorkspace.shared.open(disk.root) }
        catch { message = error.localizedDescription }
    }

    func installSteam() {
        guard !downloadingSteam else { return }
        if SteamClient(disk: disk).executable != nil { launchSteam(); return }
        runtime = Runtime.inspect(custom: library.winePath)
        guard runtime.ready else { page = "runtime"; message = "Windows Steam 설치 전에 Wine 런타임을 연결해 주세요."; return }
        downloadingSteam = true
        steamProgress = "Valve 공식 설치 프로그램을 다운로드하고 있습니다."
        Task {
            defer { downloadingSteam = false }
            do {
                let source = URL(string: "https://cdn.akamai.steamstatic.com/client/installer/SteamSetup.exe")!
                let (temporary, response) = try await URLSession.shared.download(from: source)
                guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw DeckError.message("Steam 설치 프로그램 다운로드에 실패했습니다.") }
                let folder = disk.root.appendingPathComponent("Installers", isDirectory: true)
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                let destination = folder.appendingPathComponent("SteamSetup.exe")
                let bytes = try Data(contentsOf: temporary)
                guard bytes.starts(with: [0x4d, 0x5a]) else { throw DeckError.message("다운로드한 파일이 Windows 설치 프로그램이 아닙니다.") }
                try bytes.write(to: destination, options: .atomic)
                var installer = try Game.importing(destination)
                installer.name = "Steam 설치"
                installer.arguments = ["/S"]
                installer.prefix = disk.bottles.appendingPathComponent("Steam").path
                try disk.preparePrefix(for: installer)
                let plan = try LaunchPlan.make(game: installer, wine: runtime.path, disk: disk)
                steamProgress = "Steam 전용 Windows 환경을 구성하고 있습니다."
                try await SteamClient.runInstaller(plan, log: disk.logs.appendingPathComponent("steam-installer.log"))
                guard SteamClient(disk: disk).executable != nil else { throw DeckError.message("설치 후 Steam 실행 파일을 찾지 못했습니다.") }
                steamProgress = "Steam 업데이트와 로그인 화면을 열고 있습니다."
                launchSteam()
            } catch { steamProgress = "Steam 준비를 완료하지 못했습니다."; message = error.localizedDescription }
        }
    }

    var steamInstalled: Bool { SteamClient(disk: disk).executable != nil }
    var steamGameCount: Int { library.games.filter { $0.steamAppID != nil }.count }

    func reconnectExternalLibraries(steamRunning: Bool = false) {
        guard writable, let existing = library.externalLibraries, !existing.isEmpty else { return }
        let service = SteamStorage(client: SteamClient(disk: disk))
        let updated = service.autoConnectAll(existing, steamRunning: steamRunning)
        if updated != existing {
            var data = library
            data.externalLibraries = updated
            try? commit(data)
        }
    }

    func start() {
        guard !didStart else { return }
        didStart = true
        let winePath = runtime.path ?? Runtime.inspect(custom: library.winePath).path
        DirectX12Support.applyGlobal(mode: graphicsBackend, wine: winePath, games: library.games, disk: disk)
        reloadRuntimeComponents()
        reconnectExternalLibraries(steamRunning: false)
        refreshSteamGames(silent: true)
        let willStartSteam = CommandLine.arguments.contains("--setup-steam")
            || CommandLine.arguments.contains("--steam")
            || (steamInstalled && (library.startSteamOnLaunch ?? true))
        checkRuntimeUpdates(autoInstall: autoUpdateRuntime && !willStartSteam)
        if CommandLine.arguments.contains("--setup-steam") { installSteam() }
        else if CommandLine.arguments.contains("--steam") || (steamInstalled && (library.startSteamOnLaunch ?? true)) { launchSteam() }
    }

    func setSteamAutostart(_ enabled: Bool) {
        do { var data = library; data.startSteamOnLaunch = enabled; try commit(data) }
        catch { message = error.localizedDescription }
    }

    func setAutoUpdateRuntime(_ enabled: Bool) {
        do {
            var data = library
            data.autoUpdateRuntime = enabled
            try commit(data)
            if enabled {
                checkRuntimeUpdates(autoInstall: true)
            }
        } catch { message = error.localizedDescription }
    }

    func reloadRuntimeComponents() {
        let winePath = runtime.path ?? Runtime.inspect(custom: library.winePath).path
        let root = DirectX12Support.runtimeRoot(forWine: winePath)
        runtimeComponents = RuntimeComponentKind.allCases.map { kind in
            let existing = runtimeComponents.first(where: { $0.kind == kind })
            let installed = RuntimeUpdater.detectInstalledVersion(for: kind, runtimeRoot: root)
            return RuntimeComponentStatus(
                kind: kind,
                installedVersion: installed,
                latestVersion: existing?.latestVersion,
                asset: existing?.asset,
                checking: existing?.checking ?? false,
                updating: existing?.updating ?? false,
                statusMessage: existing?.statusMessage ?? "",
                error: existing?.error
            )
        }
    }

    func checkRuntimeUpdates(autoInstall: Bool = false) {
        guard !checkingUpdates && !updatingComponents else { return }
        reloadRuntimeComponents()
        checkingUpdates = true
        updateBannerMessage = "MoltenVK · DXMT · Wine 최신 릴리스를 확인하고 있습니다…"
        for index in runtimeComponents.indices {
            runtimeComponents[index].checking = true
            runtimeComponents[index].error = nil
        }
        Task {
            defer { checkingUpdates = false }
            for kind in RuntimeComponentKind.allCases {
                do {
                    let result = try await RuntimeUpdater.fetchRelease(for: kind)
                    if let idx = runtimeComponents.firstIndex(where: { $0.kind == kind }) {
                        runtimeComponents[idx].checking = false
                        runtimeComponents[idx].latestVersion = result.version
                        runtimeComponents[idx].asset = result.asset
                        runtimeComponents[idx].statusMessage = runtimeComponents[idx].updateAvailable
                            ? "업데이트 가능 (\(runtimeComponents[idx].installedVersion) → \(result.version))"
                            : "최신 버전 (\(runtimeComponents[idx].installedVersion))"
                    }
                } catch {
                    if let idx = runtimeComponents.firstIndex(where: { $0.kind == kind }) {
                        runtimeComponents[idx].checking = false
                        runtimeComponents[idx].error = error.localizedDescription
                        runtimeComponents[idx].statusMessage = "확인 실패"
                    }
                }
            }
            let count = availableUpdateCount
            if count > 0 {
                updateBannerMessage = "업데이트 가능한 런타임 구성요소가 \(count)개 있습니다."
                if autoInstall {
                    updateAllAvailableComponents()
                }
            } else {
                updateBannerMessage = "모든 런타임 구성요소(MoltenVK · DXMT · Wine)가 최신 버전입니다."
            }
        }
    }

    func updateComponent(_ kind: RuntimeComponentKind) {
        guard !updatingComponents else { return }
        guard let idx = runtimeComponents.firstIndex(where: { $0.kind == kind }),
              let latest = runtimeComponents[idx].latestVersion,
              let asset = runtimeComponents[idx].asset else { return }
        updatingComponents = true
        runtimeComponents[idx].updating = true
        runtimeComponents[idx].error = nil
        runtimeComponents[idx].statusMessage = "\(latest) 다운로드 및 설치 중…"
        updateBannerMessage = "\(kind.title) (\(latest)) 업데이트를 적용하고 있습니다…"
        Task {
            defer { updatingComponents = false }
            do {
                let currentWine = runtime.path ?? Runtime.inspect(custom: library.winePath).path
                let service = SteamStorage(client: SteamClient(disk: disk))
                var restartSteam = false
                if steamInstalled, let currentWine, (try? await service.isRunning(wine: currentWine)) == true {
                    restartSteam = true
                    try? await service.stopAndWait(wine: currentWine)
                }
                let ensured = try RuntimeUpdater.ensureWritableRuntime(currentWinePath: currentWine, disk: disk)
                if let newWinePath = ensured.updatedWinePath, newWinePath != library.winePath {
                    var data = library
                    data.winePath = newWinePath
                    try? commit(data)
                    runtime = Runtime.inspect(custom: newWinePath)
                }
                try await RuntimeUpdater.downloadAndInstall(
                    kind: kind,
                    version: latest,
                    asset: asset,
                    runtimeRoot: ensured.runtimeRoot,
                    graphicsMode: graphicsBackend
                )
                let finalWine = runtime.path ?? Runtime.inspect(custom: library.winePath).path
                DirectX12Support.applyGlobal(mode: graphicsBackend, wine: finalWine, games: library.games, disk: disk)
                reloadRuntimeComponents()
                if let newIdx = runtimeComponents.firstIndex(where: { $0.kind == kind }) {
                    runtimeComponents[newIdx].updating = false
                    runtimeComponents[newIdx].statusMessage = "업데이트 완료 (\(latest))"
                }
                updateBannerMessage = "\(kind.title)을(를) \(latest) 버전으로 업데이트했습니다."
                if restartSteam { launchSteam() }
            } catch {
                if let newIdx = runtimeComponents.firstIndex(where: { $0.kind == kind }) {
                    runtimeComponents[newIdx].updating = false
                    runtimeComponents[newIdx].error = error.localizedDescription
                    runtimeComponents[newIdx].statusMessage = "업데이트 실패"
                }
                updateBannerMessage = "\(kind.title) 업데이트 실패: \(error.localizedDescription)"
            }
        }
    }

    func updateAllAvailableComponents() {
        guard !updatingComponents else { return }
        let targets = runtimeComponents.filter { $0.updateAvailable && $0.latestVersion != nil && $0.asset != nil }
        guard !targets.isEmpty else { return }
        updatingComponents = true
        updateBannerMessage = "런타임 구성요소 \(targets.count)개를 자동으로 업데이트하고 있습니다…"
        Task {
            defer { updatingComponents = false }
            var updatedNames: [String] = []
            var restartSteam = false
            do {
                let currentWine = runtime.path ?? Runtime.inspect(custom: library.winePath).path
                let service = SteamStorage(client: SteamClient(disk: disk))
                if steamInstalled, let currentWine, (try? await service.isRunning(wine: currentWine)) == true {
                    restartSteam = true
                    try? await service.stopAndWait(wine: currentWine)
                }
                let ensured = try RuntimeUpdater.ensureWritableRuntime(currentWinePath: currentWine, disk: disk)
                if let newWinePath = ensured.updatedWinePath, newWinePath != library.winePath {
                    var data = library
                    data.winePath = newWinePath
                    try? commit(data)
                    runtime = Runtime.inspect(custom: newWinePath)
                }
                for item in targets {
                    guard let latest = item.latestVersion, let asset = item.asset else { continue }
                    if let idx = runtimeComponents.firstIndex(where: { $0.kind == item.kind }) {
                        runtimeComponents[idx].updating = true
                        runtimeComponents[idx].error = nil
                        runtimeComponents[idx].statusMessage = "\(latest) 다운로드 및 설치 중…"
                    }
                    do {
                        try await RuntimeUpdater.downloadAndInstall(
                            kind: item.kind,
                            version: latest,
                            asset: asset,
                            runtimeRoot: ensured.runtimeRoot,
                            graphicsMode: graphicsBackend
                        )
                        updatedNames.append("\(item.kind.title) (\(latest))")
                        reloadRuntimeComponents()
                        if let idx = runtimeComponents.firstIndex(where: { $0.kind == item.kind }) {
                            runtimeComponents[idx].updating = false
                            runtimeComponents[idx].statusMessage = "업데이트 완료 (\(latest))"
                        }
                    } catch {
                        if let idx = runtimeComponents.firstIndex(where: { $0.kind == item.kind }) {
                            runtimeComponents[idx].updating = false
                            runtimeComponents[idx].error = error.localizedDescription
                            runtimeComponents[idx].statusMessage = "업데이트 실패"
                        }
                    }
                }
                let finalWine = runtime.path ?? Runtime.inspect(custom: library.winePath).path
                DirectX12Support.applyGlobal(mode: graphicsBackend, wine: finalWine, games: library.games, disk: disk)
                if restartSteam { launchSteam() }
            } catch {
                updateBannerMessage = "런타임 업데이트 준비 실패: \(error.localizedDescription)"
                return
            }
            if !updatedNames.isEmpty {
                updateBannerMessage = "자동 업데이트 완료: " + updatedNames.joined(separator: ", ")
            }
        }
    }

    func setGraphicsBackend(_ mode: GraphicsBackend) {
        guard graphicsBackend != mode else { return }
        do {
            var data = library
            data.graphicsBackend = mode
            for index in data.games.indices { data.games[index].graphicsBackend = nil }
            try commit(data)
            let winePath = runtime.path ?? Runtime.inspect(custom: library.winePath).path
            guard steamInstalled, let winePath else {
                DirectX12Support.applyGlobal(mode: mode, wine: winePath, games: data.games, disk: disk)
                steamProgress = "전역 그래픽 모드를 \(mode.shortLabel)로 전환했습니다."
                return
            }
            let gamesSnapshot = data.games
            Task {
                let service = SteamStorage(client: SteamClient(disk: disk))
                let running = (try? await service.isRunning(wine: winePath)) == true
                if running {
                    steamProgress = "\(mode.shortLabel) 적용을 위해 Steam을 재시작하고 있습니다…"
                    try? await service.stopAndWait(wine: winePath)
                }
                DirectX12Support.applyGlobal(mode: mode, wine: winePath, games: gamesSnapshot, disk: disk)
                steamProgress = "전역 그래픽 모드(\(mode.shortLabel))가 모든 게임과 Steam에 적용되었습니다."
                if running {
                    launchSteam()
                }
            }
        } catch { message = error.localizedDescription }
    }

    func launchSteam() {
        guard steamInstalled else { installSteam(); return }
        do {
            reconnectExternalLibraries(steamRunning: sessions.contains(where: { id in library.games.first(where: { $0.id == id })?.steamAppID == nil }))
            var steam = try SteamClient(disk: disk).entry()
            var data = library
            if let index = data.games.firstIndex(where: { $0.path == steam.path && $0.steamAppID == nil }) {
                steam.id = data.games[index].id
                steam.added = data.games[index].added
                steam.lastPlayed = data.games[index].lastPlayed
                data.games[index] = steam
            } else { data.games.append(steam) }
            try commit(data)
            selected = steam.id
            page = "steam"
            launch(steam)
        } catch { message = error.localizedDescription }
    }

    func setSteamGPUAcceleration(_ enabled: Bool) {
        do {
            var data = library
            data.steamGPUAcceleration = enabled
            try commit(data)
            steamProgress = "화면 가속 설정은 Steam을 완전히 종료한 뒤 다시 실행하면 적용됩니다."
        } catch { message = error.localizedDescription }
    }

    func setMetalHUD(_ enabled: Bool) {
        do {
            var data = library
            data.showMetalHUD = enabled
            try commit(data)
            steamProgress = "Metal 성능 HUD 설정(\(enabled ? "켬" : "끔"))이 저장되었습니다. 게임 실행 중 Fn+Shift+F9(또는 Shift+F9)로 언제든지 실시간으로 켜고 끌 수 있습니다."
        } catch { message = error.localizedDescription }
    }

    func connectWindowsSteam() { launchSteam() }

    func refreshSteamGames(silent: Bool = false) {
        guard writable, steamInstalled else { return }
        do {
            reconnectExternalLibraries(steamRunning: true)
            let found = try SteamClient(disk: disk).installedGames()
            var data = library
            let winePath = runtime.path ?? Runtime.inspect(custom: library.winePath).path
            for var game in found {
                if let index = data.games.firstIndex(where: { $0.steamAppID == game.steamAppID }) {
                    game.id = data.games[index].id; game.added = data.games[index].added; game.lastPlayed = data.games[index].lastPlayed
                    game.graphicsBackend = data.games[index].graphicsBackend
                    data.games[index] = game
                } else { data.games.append(game) }
            }
            DirectX12Support.applyGlobal(mode: graphicsBackend, wine: winePath, games: data.games, disk: disk)
            if data.games != library.games { try commit(data) }
            if !silent { steamProgress = "설치된 Steam 게임 \(found.count)개를 확인했습니다. 전체 보유 라이브러리는 Steam에서 볼 수 있습니다." }
        } catch { if !silent { message = error.localizedDescription } }
    }

    func terminateAll() {
        timer?.invalidate()
        timer = nil
        for (_, process) in processes {
            if process.isRunning { process.terminate() }
        }
        for (_, filter) in graphicsFilters {
            if filter.isRunning { filter.terminate() }
        }
        for (_, handle) in logHandles {
            try? handle.close()
        }
        processes.removeAll()
        graphicsFilters.removeAll()
        logHandles.removeAll()
        sessions.removeAll()

        let winePath = runtime.path ?? Runtime.inspect(custom: library.winePath).path
        if let wine = winePath {
            SteamStorage(client: SteamClient(disk: disk)).killPrefixProcesses(wine: wine)
            let server = URL(fileURLWithPath: wine).resolvingSymlinksInPath()
                .deletingLastPathComponent().appendingPathComponent("wineserver")
            if FileManager.default.isExecutableFile(atPath: server.path) {
                let killProc = Process()
                killProc.executableURL = server
                killProc.arguments = ["-k"]
                killProc.standardOutput = FileHandle.nullDevice
                killProc.standardError = FileHandle.nullDevice
                try? killProc.run()
                let deadline = Date().addingTimeInterval(1.0)
                while killProc.isRunning && Date() < deadline {
                    usleep(20_000)
                }
                if killProc.isRunning { killProc.terminate() }
            }
        }
    }
}
