import SwiftUI
import AppKit

typealias DeckState<Value> = SwiftUI.State<Value>

private let accent = Color(red: 0.53, green: 0.91, blue: 0.64)
private let deckBackground = Color(red: 0.055, green: 0.065, blue: 0.08)

@main
struct Entry {
    static func main() {
        if CommandLine.arguments.contains("--dependencies-plan") || CommandLine.arguments.contains("--dependencies-install") {
            Task {
                do {
                    let disk = LibraryDisk.standard, library = try disk.load()
                    let games = library.games.filter { $0.steamAppID != nil && $0.trialAppID == nil }
                    var needs = try DependencyDiscovery.plan(games: games, profiles: GameProfileStore(disk: disk).load().games)
                    if let i = CommandLine.arguments.firstIndex(of: "--package"), CommandLine.arguments.indices.contains(i+1) {
                        let id = CommandLine.arguments[i+1]
                        guard DependencyCatalog.package(id) != nil else { throw DeckError.message("지원하지 않는 패키지입니다.") }
                        needs = [DependencyNeed(packageID: id, appIDs: needs.first(where: { $0.packageID == id })?.appIDs ?? [])]
                    }
                    if CommandLine.arguments.contains("--dependencies-plan") {
                        print(String(decoding: try JSONEncoder().encode(needs), as: UTF8.self)); exit(0)
                    }
                    var prefix = SteamClient(disk: disk).prefix
                    if let i = CommandLine.arguments.firstIndex(of: "--prefix"), CommandLine.arguments.indices.contains(i+1) { prefix = URL(fileURLWithPath: CommandLine.arguments[i+1]) }
                    let wine = library.winePath.isEmpty ? Runtime.bundledWine : library.winePath
                    guard let wine else { throw DeckError.message("Wine이 없습니다.") }
                    let installer = DependencyInstaller(disk: disk, prefix: prefix, wine: wine)
                    let failures = try await installer.prepare(needs, retry: CommandLine.arguments.contains("--retry")) { print($0) }
                    if failures.isEmpty { try await installer.activateCLR(for: games, needs: needs) }
                    for failure in failures { print("FAIL: " + failure) }
                    exit(failures.isEmpty ? 0 : 1)
                } catch { fputs("FAIL: \(error)\n", stderr); exit(1) }
            }
            dispatchMain()
        }
        if CommandLine.arguments.contains("--prepare-shared-renderer") || CommandLine.arguments.contains("--enable-shared-renderer") || CommandLine.arguments.contains("--disable-shared-renderer") {
            Task {
                do {
                    let service = SharedSteamRuntime(disk: .standard)
                    if let index = CommandLine.arguments.firstIndex(of: "--prepare-shared-renderer"), CommandLine.arguments.indices.contains(index + 2) {
                        try await service.prepare(source: URL(fileURLWithPath: CommandLine.arguments[index + 1]), routers: URL(fileURLWithPath: CommandLine.arguments[index + 2]))
                    } else { try await service.setEnabled(CommandLine.arguments.contains("--enable-shared-renderer")) }
                    print("PASS: shared Steam renderer configuration"); exit(0)
                } catch { fputs("FAIL: \(error)\n", stderr); exit(1) }
            }
            dispatchMain()
        }
        if CommandLine.arguments.contains("--confirm-elden-trial") {
            do { try GameTrialCLI.confirmElden() } catch { fputs("FAIL: \(error)\n", stderr); exit(1) }
        } else if CommandLine.arguments.contains("--trial-steam") || CommandLine.arguments.contains("--trial-run") {
            Task {
                do { try await GameTrialCLI.launch(arguments: CommandLine.arguments); exit(0) }
                catch { fputs("FAIL: \(error)\n", stderr); exit(1) }
            }
            dispatchMain()
        } else if let flag = CommandLine.arguments.firstIndex(of: "--prepare-game-trial"), CommandLine.arguments.indices.contains(flag + 1) {
            let id = CommandLine.arguments[flag + 1]
            Task {
                do {
                    let disk = LibraryDisk.standard
                    guard let game = try disk.load().games.first(where: { $0.steamAppID == id }), let wine = Runtime.bundledWine else { throw DeckError.message("시험 게임 또는 Wine이 없습니다.") }
                    var candidate: URL?
                    if let index = CommandLine.arguments.firstIndex(of: "--candidate"), CommandLine.arguments.indices.contains(index + 1) { candidate = URL(fileURLWithPath: CommandLine.arguments[index + 1]) }
                    var prepared = try await GameTrial.prepare(game: game, wine: wine, disk: disk, candidate: candidate)
                    if let index = CommandLine.arguments.firstIndex(of: "--apple-image"), CommandLine.arguments.indices.contains(index + 1) {
                        let image = URL(fileURLWithPath: CommandLine.arguments[index + 1])
                        prepared = try prepared.importApple(redist: image.appendingPathComponent("redist"), license: image.appendingPathComponent("License.rtf"), disk: disk)
                    }
                    print("PREPARED: " + prepared.name + " · " + prepared.status); fflush(stdout)
                    let installed = try await prepared.installSteam(disk: disk)
                    print("READY: " + installed.name + " · " + installed.status); fflush(stdout)
                    exit(0)
                } catch { fputs("FAIL: \(error)\n", stderr); exit(1) }
            }
            dispatchMain()
        } else if CommandLine.arguments.contains("--support-report-self-test") {
            Task {
                do { try await SupportReportTests.run(); exit(0) }
                catch { fputs("FAIL: \(error)\n", stderr); exit(1) }
            }
            dispatchMain()
        } else if CommandLine.arguments.contains("--self-test") {
            do { try SelfTests.run() } catch { fputs("FAIL: \(error)\n", stderr); exit(1) }
        } else { MacDeckApp.main() }
    }
}

final class MacDeckAppDelegate: NSObject, NSApplicationDelegate {
    weak var model: DeckModel?
    static weak var sharedModel: DeckModel?

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: nil, queue: .main) { [weak self] _ in
            DispatchQueue.main.async {
                let regularWindows = NSApp.windows.filter {
                    $0.isVisible && !($0 is NSPanel) && $0.className != "NSStatusBarWindow"
                }
                if regularWindows.isEmpty {
                    (self?.model ?? Self.sharedModel)?.terminateAll()
                    NSApp.terminate(nil)
                }
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if Thread.isMainThread {
            MainActor.assumeIsolated {
                (model ?? Self.sharedModel)?.terminateAll()
            }
        } else {
            DispatchQueue.main.sync {
                MainActor.assumeIsolated {
                    (self.model ?? Self.sharedModel)?.terminateAll()
                }
            }
        }
    }
}

struct MacDeckApp: App {
    @NSApplicationDelegateAdaptor(MacDeckAppDelegate.self) var appDelegate
    @StateObject private var model = DeckModel()
    var body: some Scene {
        WindowGroup("MacDeck") {
            ConsoleView(model: model).frame(minWidth: 1180, minHeight: 720)
                .preferredColorScheme(.dark)
                .onAppear {
                    appDelegate.model = model
                    MacDeckAppDelegate.sharedModel = model
                    NSApp.setActivationPolicy(.regular)
                    if let appIcon = Bundle.main.image(forResource: "AppIcon") ?? NSImage(named: "AppIcon") {
                        NSApp.applicationIconImage = appIcon
                    } else {
                        NSApp.applicationIconImage = NSImage(systemSymbolName: "gamecontroller.fill", accessibilityDescription: "MacDeck")
                    }
                    if CommandLine.arguments.contains("--verify-game"), var game = model.game {
                        game.arguments = ["--seed", "42"]
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { model.launch(game) }
                    } else if CommandLine.arguments.contains("--controller-test") {
                        model.page = "controllers"
                        model.openWindowsControllerTest()
                    } else if CommandLine.arguments.contains("--no-steam") { model.refreshSteamGames(silent: true) }
                    else { model.start() }
                    if CommandLine.arguments.contains("--smoke-ui") {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { NSApp.terminate(nil) }
                    }
                }
        }
        .defaultSize(width: 1280, height: 820)
        .commands {
            CommandGroup(replacing: .appTermination) {
                Button("MacDeck 종료") {
                    model.terminateAll()
                    NSApp.terminate(nil)
                }.keyboardShortcut("q", modifiers: .command)
            }
            CommandGroup(after: .newItem) {
                Button("게임 추가…", action: model.chooseGame).keyboardShortcut("o")
                Button("런타임 설정") { model.page = "runtime" }.keyboardShortcut(",")
            }
        }
    }
}

struct GameEditor: View {
    @DeckState var game: Game
    @ObservedObject var model: DeckModel
    @StateObject private var pads = GamepadMonitor()
    @DeckState private var arguments = ""
    @DeckState private var error: String?
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("실행 설정").font(.title2.bold())
            TextField("게임 이름", text: $game.name)
            TextField("실행 파일 경로", text: $game.path)
            Text("실행 인수 · JSON 문자열 배열").font(.caption).foregroundStyle(.secondary)
            TextEditor(text: $arguments).font(.system(size: 12, design: .monospaced)).frame(height: 74).border(.white.opacity(0.1))
            if game.kind == .windows {
                Picker("그래픽 모드 (이 게임)", selection: $game.graphicsBackend) {
                    Text("전역 설정 사용 (현재: \(model.graphicsBackend.shortLabel))").tag(GraphicsBackend?.none)
                    ForEach(GraphicsBackend.allCases, id: \.self) { backend in
                        Text(backend.label).tag(GraphicsBackend?.some(backend))
                    }
                }
                Picker("Direct3D 9 렌더러 (고전 게임)", selection: Binding(get: { game.d3d9Mode ?? .automatic }, set: { game.d3d9Mode = $0 })) {
                    ForEach(D3D9Mode.allCases, id: \.self) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                Text(game.d3d9Mode == .native ? "Native D9VK 선택 시 게임 폴더의 d3d9.dll을 로드하여 Metal GPU로 가속합니다." : "자동/WineD3D 선택 시 내장 WineD3D Vulkan Metal 가속 및 2GB VRAM 캡이 적용됩니다.").font(.caption).foregroundStyle(.secondary)
                TextField("Windows 환경 폴더 · 비워두면 게임별 자동 생성", text: Binding(get: { game.prefix ?? "" }, set: { game.prefix = $0.isEmpty ? nil : $0 }))
            }
            Text("인수 예: [\"-windowed\", \"-width\", \"1280\"]. 쉘 명령은 실행하지 않습니다.").font(.caption).foregroundStyle(.secondary)
            if let error { Text(error).foregroundStyle(.orange).font(.caption) }
            HStack {
                Button("로그 보기") { model.showLog(game) }.buttonStyle(ConsoleSecondaryButtonStyle())
                Spacer()
                Button("취소 · \(ControllerHints(layout: pads.pads.first?.layout ?? .xbox).back)") { dismiss() }.buttonStyle(ConsoleSecondaryButtonStyle()).keyboardShortcut(.cancelAction)
                Button("저장 · \(ControllerHints(layout: pads.pads.first?.layout ?? .xbox).details)", action: save).buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
            }
        }.padding(28).frame(width: 540)
             .onAppear {
                arguments = String(decoding: (try? JSONEncoder().encode(game.arguments)) ?? Data("[]".utf8), as: UTF8.self)
                pads.acceptsAttachedSheet = true
                pads.onAction = { action in
                    if action == .back { dismiss() }
                    else if action == .details { save() }
                }
            }
    }
    private func save() {
        do {
            let args = try JSONDecoder().decode([String].self, from: Data(arguments.utf8))
            guard !game.name.trimmingCharacters(in: .whitespaces).isEmpty else { throw DeckError.message("게임 이름을 입력해 주세요.") }
            game.arguments = args
            model.saveGame(game)
            dismiss()
        } catch { self.error = error.localizedDescription }
    }

}
