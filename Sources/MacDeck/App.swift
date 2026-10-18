import SwiftUI
import AppKit

typealias DeckState<Value> = SwiftUI.State<Value>

private let accent = Color(red: 0.53, green: 0.91, blue: 0.64)
private let deckBackground = Color(red: 0.055, green: 0.065, blue: 0.08)

@main
struct Entry {
    static func main() {
        if CommandLine.arguments.contains("--self-test") {
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
            DeckView(model: model).frame(minWidth: 960, minHeight: 650)
                .preferredColorScheme(.dark)
                .onAppear {
                    appDelegate.model = model
                    MacDeckAppDelegate.sharedModel = model
                    NSApp.setActivationPolicy(.regular)
                    NSApp.applicationIconImage = NSImage(systemSymbolName: "gamecontroller.fill", accessibilityDescription: "MacDeck")
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
        .defaultSize(width: 1160, height: 780)
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

struct DeckView: View {
    @ObservedObject var model: DeckModel
    @StateObject private var gamepads = GamepadMonitor()
    @DeckState private var editing: Game?
    @FocusState private var searching: Bool

    var body: some View {
        HStack(spacing: 0) {
            sidebar.frame(width: 208)
            Divider().overlay(Color.white.opacity(0.05))
            VStack(spacing: 0) {
                toolbar
                Divider().opacity(0.35)
                ScrollView {
                    VStack(alignment: .leading, spacing: 26) {
                        if model.page == "runtime" { runtimePage }
                        else if model.page == "steam" { steamPage }
                        else if model.page == "controllers" { controllerPage }
                        else if model.page == "diagnostics" { diagnosticsPage }
                        else { libraryPage }
                    }.padding(30).frame(maxWidth: .infinity, alignment: .leading)
                }
            }.background(deckBackground)
        }
        .onAppear {
            gamepads.navigationEnabled = { editing == nil && model.message == nil && !searching && !(NSApp.keyWindow?.firstResponder is NSTextView) }
            gamepads.onAction = { action in
                if model.page == "controllers" && action != .back { return }
                let pages = ["steam", "library", "runtime", "controllers", "diagnostics"]
                switch action {
                case .previousPage, .nextPage:
                    let index = pages.firstIndex(of: model.page) ?? 0
                    model.page = pages[(index + (action == .nextPage ? 1 : pages.count - 1)) % pages.count]
                case .previous, .next:
                    model.page = "library"
                    let games = model.filtered
                    if !games.isEmpty {
                        let index = games.firstIndex(where: { $0.id == model.selected }) ?? 0
                        model.selected = games[(index + (action == .next ? 1 : games.count - 1)) % games.count].id
                    }
                case .confirm:
                    if model.page == "steam" { model.launchSteam() }
                    else if model.page == "library", let game = model.game { model.launch(game) }
                case .back: model.page = "steam"
                case .steam: model.launchSteam()
                }
            }
        }
        .tint(accent)
        .alert("MacDeck", isPresented: Binding(get: { model.message != nil }, set: { if !$0 { model.message = nil } })) {
            Button("확인") { model.message = nil }
        } message: { Text(model.message ?? "") }
        .sheet(item: $editing) { game in GameEditor(game: game, model: model) }
    }

    var sidebar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "gamecontroller.fill").font(.system(size: 25)).foregroundStyle(accent)
                Text("macdeck").font(.system(size: 24, weight: .bold, design: .rounded))
            }.padding(.bottom, 36).padding(.top, 20)
            Text("PLAY YOUR WAY").font(.system(size: 9, weight: .bold)).tracking(2).foregroundStyle(.secondary).padding(.bottom, 10)
            nav("라이브러리", icon: "square.grid.2x2", page: "library")
            nav("Steam", icon: "circle.hexagongrid.fill", page: "steam")
            nav("런타임", icon: "cpu", page: "runtime")
            nav("게임패드", icon: "gamecontroller", page: "controllers")
            nav("실행 기록", icon: "doc.text.magnifyingglass", page: "diagnostics")
            Spacer()
            VStack(alignment: .leading, spacing: 9) {
                Label("DIRECT3D → METAL", systemImage: "sparkles").font(.system(size: 10, weight: .bold)).foregroundStyle(accent)
                Text("전역 설정: " + model.graphicsBackend.shortLabel).font(.system(size: 12, weight: .semibold)).foregroundStyle(.primary)
                Text(model.graphicsBackend == .dxmt ? "DXMT → Metal (DirectX 11)" : "VKD3D · MoltenVK → Metal (DirectX 12)").font(.system(size: 10)).foregroundStyle(.secondary)
            }.padding(14).frame(maxWidth: .infinity, alignment: .leading).background(accent.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
            Button("데이터 폴더 열기", action: model.revealData).buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(.secondary).padding(.top, 12)
            Button("MacDeck 종료") {
                model.terminateAll()
                NSApp.terminate(nil)
            }.buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(.secondary)
            Text("MacDeck · 0.5.5").font(.system(size: 10)).foregroundStyle(.tertiary).padding(.top, 6)
        }.padding(20).background(Color(red: 0.075, green: 0.085, blue: 0.1))
    }

    func nav(_ title: String, icon: String, page: String) -> some View {
        Button { model.page = page } label: {
            HStack(spacing: 12) {
                Image(systemName: icon).frame(width: 18)
                Text(title).fontWeight(.medium)
                Spacer()
                if page == "runtime" && model.availableUpdateCount > 0 {
                    Text("\(model.availableUpdateCount)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(accent, in: Capsule())
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 13)
            .foregroundStyle(model.page == page ? accent : Color.secondary)
            .background(model.page == page ? accent.opacity(0.1) : .clear, in: RoundedRectangle(cornerRadius: 9))
        }.buttonStyle(.plain)
    }

    var globalModePicker: some View {
        Picker("그래픽 모드", selection: Binding(get: { model.graphicsBackend }, set: model.setGraphicsBackend)) {
            ForEach(GraphicsBackend.allCases, id: \.self) { backend in
                Text(backend.shortLabel).tag(backend)
            }
        }
        .pickerStyle(.segmented)
        .frame(width: 210)
    }

    var toolbar: some View {
        HStack(spacing: 16) {
            Text(model.page == "runtime" ? "실행 환경" : model.page == "steam" ? "Steam 연결" : "라이브러리").font(.system(size: 14, weight: .semibold))
            Spacer()
            globalModePicker
            if model.page == "library" {
                HStack { Image(systemName: "magnifyingglass"); TextField("게임 검색", text: $model.search).textFieldStyle(.plain).focused($searching) }
                    .font(.system(size: 12)).foregroundStyle(.secondary).padding(9).frame(width: 190).background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
            }
            Button(action: model.chooseGame) { Label("게임 추가", systemImage: "plus") }.buttonStyle(.bordered).keyboardShortcut("o")
            Button { NSApp.keyWindow?.toggleFullScreen(nil) } label: { Image(systemName: "arrow.up.left.and.arrow.down.right") }.buttonStyle(.plain).help("전체 화면")
        }.padding(.horizontal, 28).padding(.vertical, 18)
    }

    var libraryPage: some View {
        VStack(alignment: .leading, spacing: 26) {
            hero
            HStack { Text("내 게임").font(.system(size: 19, weight: .semibold)); Text("\(model.library.games.count)").foregroundStyle(.secondary); Spacer() }
            if model.filtered.isEmpty {
                VStack(spacing: 14) {
                    Image(systemName: "gamecontroller").font(.system(size: 40)).foregroundStyle(accent.opacity(0.7))
                    Text(model.search.isEmpty ? "첫 게임을 추가하세요" : "검색 결과가 없습니다").font(.headline)
                    Text("Windows .exe와 macOS .app을 라이브러리에 등록할 수 있습니다.").font(.callout).foregroundStyle(.secondary)
                    if model.search.isEmpty { Button("게임 찾아보기", action: model.chooseGame).buttonStyle(.borderedProminent) }
                }.frame(maxWidth: .infinity).padding(44).background(.white.opacity(0.025), in: RoundedRectangle(cornerRadius: 14))
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 190, maximum: 300), spacing: 18)], spacing: 18) {
                    ForEach(model.filtered) { game in card(game) }
                }
            }
            Text("모든 Windows 및 Steam 게임에 전역 그래픽 모드(\(model.graphicsBackend.shortLabel))가 공통 적용됩니다.")
                .font(.system(size: 11)).foregroundStyle(.secondary)
        }
    }

    var hero: some View {
        HStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 14) {
                Text("YOUR GAMES. YOUR MAC.").font(.system(size: 10, weight: .bold)).tracking(2.5).foregroundStyle(accent)
                Text(model.game?.name ?? "게임을, Mac에서.").font(.system(size: 34, weight: .bold)).lineLimit(2)
                Text(model.game == nil ? "나만의 게임 라이브러리와 Metal 실행 환경" : model.game?.kind == .windows ? "Windows · 전역 \(model.graphicsBackend.shortLabel) → Metal" : "macOS 네이티브 실행")
                    .font(.system(size: 13)).foregroundStyle(.secondary)
                HStack(spacing: 12) {
                    Button {
                        if let game = model.game { model.launch(game) } else { model.chooseGame() }
                    } label: { Label(model.game.map { model.sessions.contains($0.id) ? "실행 중" : "플레이" } ?? "게임 추가", systemImage: "play.fill").fontWeight(.semibold).padding(.horizontal, 16).padding(.vertical, 7) }
                    .buttonStyle(.borderedProminent).foregroundStyle(model.game.map { model.sessions.contains($0.id) } == true ? Color.white.opacity(0.6) : .black).disabled(model.game.map { model.sessions.contains($0.id) } ?? false)
                    if let game = model.game { Button("실행 설정") { editing = game }.buttonStyle(.bordered) }
                }.padding(.top, 6)
            }
            Spacer(minLength: 0)
            Image(systemName: model.game?.kind == .windows ? "cube.transparent.fill" : "gamecontroller.fill")
                .font(.system(size: 94, weight: .light)).foregroundStyle(accent.opacity(0.36)).rotationEffect(.degrees(-12)).padding(.trailing, 12)
        }.padding(30).frame(maxWidth: .infinity, minHeight: 238, alignment: .leading)
            .background(LinearGradient(colors: [Color(red: 0.11, green: 0.2, blue: 0.18), Color(red: 0.08, green: 0.1, blue: 0.14)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 19))
            .overlay(RoundedRectangle(cornerRadius: 19).strokeBorder(accent.opacity(0.12)))
    }

    func card(_ game: Game) -> some View {
        Button { model.selected = game.id } label: {
            VStack(alignment: .leading, spacing: 0) {
                ZStack {
                    LinearGradient(colors: [game.kind == .windows ? Color(red: 0.15, green: 0.23, blue: 0.25) : Color(red: 0.2, green: 0.18, blue: 0.3), .black.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    if game.name.localizedCaseInsensitiveContains("brogue") {
                        VStack(spacing: 3) { Text("@  ·  ·  ·  ░"); Text("░  ░  ·  ♜  ·"); Text("·  ·  ·  ░  ░") }.font(.system(size: 22, weight: .medium, design: .monospaced)).foregroundStyle(accent.opacity(0.8))
                    } else { Image(systemName: game.kind == .windows ? "cube.fill" : "gamecontroller.fill").font(.system(size: 42)).foregroundStyle(.white.opacity(0.65)) }
                }.frame(height: 132)
                VStack(alignment: .leading, spacing: 8) {
                    Text(game.name).font(.system(size: 14, weight: .semibold)).lineLimit(1)
                    HStack { Text(game.kind.label).font(.system(size: 9, weight: .bold)).tracking(1); Spacer(); Text(game.kind == .windows ? model.graphicsBackend.shortLabel.uppercased() : "NATIVE").font(.system(size: 9, weight: .bold)).foregroundStyle(accent) }.foregroundStyle(.secondary)
                }.padding(14)
            }.background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 12)).clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(model.selected == game.id ? accent.opacity(0.8) : .white.opacity(0.06), lineWidth: model.selected == game.id ? 2 : 1))
        }.buttonStyle(.plain)
        .contextMenu {
            Button("플레이") { model.launch(game) }
            Button("실행 설정") { editing = game }
            Button("실행 로그 / 진단 폴더") { model.showLog(game) }
            Button("진단 ZIP 저장…") { model.exportDiagnostics(game) }
            Button("Finder에서 보기") { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: game.path)]) }
            Divider()
            Button("라이브러리에서 제거") { model.remove(game.id) }
        }
    }

    var runtimePage: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("Metal로 이어지는 실행 환경").font(.system(size: 29, weight: .bold))
            Text("Direct3D 10 / 11 (DXMT) · Direct3D 12 (VKD3D / MoltenVK) → Apple Metal").foregroundStyle(accent)
            panel("전역 그래픽 모드 (모든 게임 공통)", icon: "slider.horizontal.3") {
                Picker("전역 그래픽 모드", selection: Binding(get: { model.graphicsBackend }, set: model.setGraphicsBackend)) {
                    ForEach(GraphicsBackend.allCases, id: \.self) { backend in
                        Text(backend.label).tag(backend)
                    }
                }
                .pickerStyle(.radioGroup)
                Text("선택한 모드는 Steam 및 모든 Windows 게임에 전역으로 적용됩니다. 변경 시 런타임의 DXGI 브리지와 오버라이드 설정이 전환되며, 실행 중인 Steam이 있으면 자동으로 재시작해 새 모드를 반영합니다.").font(.callout).foregroundStyle(.secondary)
            }
            panel("런타임 구성요소 자동 업데이트 (MoltenVK · DXMT · Wine)", icon: "arrow.triangle.2.circlepath.circle.fill") {
                Toggle("앱 시작 시 MoltenVK · DXMT · Wine 업데이트 자동 확인 및 설치", isOn: Binding(get: { model.autoUpdateRuntime }, set: model.setAutoUpdateRuntime))
                if !model.updateBannerMessage.isEmpty {
                    Text(model.updateBannerMessage).font(.callout).foregroundStyle(accent)
                }
                ForEach(model.runtimeComponents) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(item.kind.title).font(.subheadline.weight(.semibold))
                            Spacer()
                            if item.checking || item.updating {
                                ProgressView().controlSize(.small)
                            }
                            Text(item.statusMessage.isEmpty ? "설치됨: \(item.installedVersion)" : item.statusMessage)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(item.updateAvailable ? .orange : (item.error != nil ? .red : accent))
                        }
                        Text(item.kind.summary).font(.caption).foregroundStyle(.secondary)
                        HStack(spacing: 12) {
                            Text("현재 버전: \(item.installedVersion)").font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                            if let latest = item.latestVersion {
                                Text("최신 릴리스: \(latest)").font(.system(size: 11, design: .monospaced)).foregroundStyle(item.updateAvailable ? .orange : .secondary)
                            }
                            Spacer()
                            if item.updateAvailable {
                                Button(item.updating ? "설치 중…" : "\(item.latestVersion ?? "") 업데이트") {
                                    model.updateComponent(item.kind)
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                                .disabled(model.updatingComponents || model.checkingUpdates)
                            }
                        }
                        if let err = item.error {
                            Text(err).font(.caption2).foregroundStyle(.orange)
                        }
                    }
                    .padding(12)
                    .background(.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 9))
                }
                HStack(spacing: 12) {
                    Button(model.checkingUpdates ? "확인 중…" : "업데이트 확인") {
                        model.checkRuntimeUpdates(autoInstall: false)
                    }
                    .buttonStyle(.bordered)
                    .disabled(model.checkingUpdates || model.updatingComponents)

                    Button(model.updatingComponents ? "업데이트 적용 중…" : "지금 자동 업데이트 실행") {
                        if model.availableUpdateCount > 0 {
                            model.updateAllAvailableComponents()
                        } else {
                            model.checkRuntimeUpdates(autoInstall: true)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .foregroundStyle(.black)
                    .disabled(model.checkingUpdates || model.updatingComponents)
                }
                Text("GitHub 공식 릴리스(KhronosGroup/MoltenVK, 3Shain/dxmt, Sikarugir-App/Engines)에서 최신 버전을 확인하고 SHA-256 무결성 검증 후 런타임에 자동 반영합니다.").font(.caption).foregroundStyle(.secondary)
            }
            panel("Wine 런타임", icon: "shippingbox") {
                Text(model.runtime.path ?? "연결된 Wine이 없습니다").font(.system(size: 11, design: .monospaced)).textSelection(.enabled)
                Text(model.runtime.version).font(.callout).foregroundStyle(.secondary)
                HStack {
                    Button("Wine 선택…", action: model.chooseRuntime)
                    Button("자동 감지", action: model.resetRuntime)
                    Button(model.testingRuntime ? "검사 중…" : "버전 검사", action: model.testRuntime).disabled(model.testingRuntime)
                }
            }
            panel("Intel 실행 지원", icon: "cpu") {
                Label(model.runtime.intelAvailable ? "사용 가능" : "설치가 필요합니다", systemImage: model.runtime.intelAvailable ? "checkmark.circle.fill" : "exclamationmark.circle").foregroundStyle(model.runtime.intelAvailable ? accent : .orange)
                Text("Intel용 Wine을 Apple Silicon에서 실행할 때 사용합니다.").font(.callout).foregroundStyle(.secondary)
                Link("Apple 설치 안내", destination: URL(string: "https://support.apple.com/102527")!)
            }
            panel("그래픽 검증 및 macOS 게임 모드", icon: "sparkles") {
                Toggle("Metal 성능 HUD 표시 (Fn+Shift+F9)", isOn: Binding(get: { model.library.showMetalHUD ?? true }, set: model.setMetalHUD))
                Text("기본값은 켬입니다. 게임 화면에서 Fn+Shift+F9(또는 Shift+F9)로 언제든지 실시간으로 켜고 끌 수 있습니다. Fn+Shift+F7로 화면 표시 위치를 변경할 수 있습니다.")
                Text("DX11 Mode는 D3D10/11을 DXMT로 가속하며 D3D12 전용 게임을 DX11로 변환하지 않습니다. DX12 Mode는 실험적입니다. Game Mode가 Off이면 게임 창에서 Control–Command–F로 기본 전체화면에 진입하고 macOS 게임 오버레이에서 상태를 확인하세요.").font(.callout).foregroundStyle(.secondary)
                Button("로그 및 데이터 폴더", action: model.revealData)
            }
        }
    }

    var diagnosticsPage: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("실행 기록").font(.system(size: 33, weight: .bold))
            Text("실행마다 게임 출력·GPU 정보·DXMT 로그·종료 상태를 분리해 보관합니다. 문제를 재현한 뒤 진단 ZIP과 재현 절차를 함께 전달하세요.").foregroundStyle(.secondary)
            ForEach(Array(SessionDiagnostics.entries(disk: model.disk).prefix(20))) { entry in
                panel(entry.record.game, icon: "doc.text") {
                    Text(entry.record.started.formatted() + " · " + entry.record.status).font(.caption).foregroundStyle(.secondary)
                    HStack {
                        Button("이 실행 로그 열기") { _ = try? SessionDiagnostics.summary(folder: entry.folder); NSWorkspace.shared.open(entry.folder) }
                        if let game = model.library.games.first(where: { $0.id == entry.record.gameID }) {
                            Button("최근 실행 진단 ZIP 저장…") { model.exportDiagnostics(game) }
                        }
                    }
                }
            }
            Text("Steam 게임 요청의 종료 코드는 게임 종료 코드가 아닙니다. Steam 인증 파일과 메모리 덤프는 수집하지 않습니다. ZIP에는 로컬 경로와 게임 출력이 포함됩니다.").font(.caption).foregroundStyle(.secondary)
        }
    }

    var controllerPage: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("게임패드").font(.system(size: 33, weight: .bold))
            Text("USB 또는 macOS Bluetooth로 연결하세요. 이 화면에서 버튼과 스틱 입력을 확인할 수 있습니다.").foregroundStyle(.secondary)
            if gamepads.pads.isEmpty {
                panel("연결된 게임패드가 없습니다", icon: "gamecontroller") {
                    Text("컨트롤러를 연결하면 자동으로 표시됩니다. macOS에서 인식되는 것과 Windows 게임에서 인식되는 것은 각각 확인해야 합니다.").font(.callout).foregroundStyle(.secondary)
                }
            }
            ForEach(gamepads.pads) { pad in
                panel(pad.name, icon: "gamecontroller.fill") {
                    if pad.extended {
                        Text(pad.sample.buttons.isEmpty ? "버튼을 눌러 보세요" : pad.sample.buttons.sorted().joined(separator: "   ")).font(.headline).foregroundStyle(accent)
                        Text(String(format: "왼쪽 스틱  X %+.2f  Y %+.2f\n오른쪽 스틱  X %+.2f  Y %+.2f\n트리거  L %.2f  R %.2f", pad.sample.leftX, pad.sample.leftY, pad.sample.rightX, pad.sample.rightY, pad.sample.leftTrigger, pad.sample.rightTrigger))
                            .font(.system(.body, design: .monospaced)).textSelection(.enabled)
                    } else { Text("확장 게임패드 프로필이 없는 장치입니다. Windows 테스트에서도 인식을 확인하세요.").foregroundStyle(.secondary) }
                }
            }
            panel("MacDeck 조작", icon: "arrow.up.and.down.and.arrow.left.and.right") {
                Text("방향키·왼쪽 스틱: 게임 선택 · A / ✕: 실행 · B / ○: Steam 화면 · LB/RB: 화면 이동 · Menu: Steam 시작")
                Text("이 테스트 화면은 B / ○로 나갈 수 있습니다. 다른 버튼은 테스트 입력만 표시합니다. Steam과 게임이 전면에 있으면 입력은 해당 앱에서 처리합니다.").font(.callout).foregroundStyle(.secondary)
            }
            panel("Windows와 Steam에서 확인", icon: "checkmark.circle") {
                Button("Windows 게임패드 테스트 열기", action: model.openWindowsControllerTest).buttonStyle(.bordered).disabled(!model.steamInstalled)
                Text("Windows 테스트 창의 XInput/DInput에서 버튼·스틱을 확인한 뒤 Steam 설정 → 컨트롤러에서도 입력을 확인하세요. 게임별 Steam Input 설정은 Steam에서 관리합니다.").font(.callout).foregroundStyle(.secondary)
                Text("진동·자이로·터치패드와 게임별 호환성은 실제 기기로 별도 확인이 필요합니다.").font(.caption).foregroundStyle(.secondary)
                Button("Steam Big Picture 열기", action: model.launchSteam).buttonStyle(.borderedProminent)
            }
        }
    }

    var steamPage: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 16) {
                Text("STEAM MACHINE · MAC").font(.system(size: 10, weight: .bold)).tracking(2.5).foregroundStyle(accent)
                Text("로그인하고, 라이브러리로.").font(.system(size: 33, weight: .bold))
                Text("실제 Windows Steam의 Big Picture를 엽니다. Steam 계정, 게임 설치와 업데이트를 한곳에서 관리하세요.").foregroundStyle(.secondary)
                HStack {
                    Button(action: model.launchSteam) {
                        Label(model.downloadingSteam ? "Steam 준비 중…" : model.steamInstalled ? "Steam 머신 시작" : "Steam 설치하고 시작", systemImage: "play.fill")
                            .fontWeight(.semibold).padding(.horizontal, 14).padding(.vertical, 8)
                    }.buttonStyle(.borderedProminent).foregroundStyle(.black).disabled(model.downloadingSteam)
                    if model.steamInstalled { Button("설치 게임 새로 고침") { model.refreshSteamGames() }.buttonStyle(.bordered) }
                }
            }.padding(30).frame(maxWidth: .infinity, alignment: .leading)
                .background(LinearGradient(colors: [Color(red: 0.1, green: 0.2, blue: 0.21), Color(red: 0.08, green: 0.1, blue: 0.14)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 19))
            if !model.steamProgress.isEmpty { Text(model.steamProgress).font(.callout).foregroundStyle(accent) }
            panel("Steam 전용 환경 및 전역 그래픽 모드", icon: "circle.hexagongrid.fill") {
                Label(model.steamInstalled ? "Steam 설치됨" : "첫 실행 준비가 필요합니다", systemImage: model.steamInstalled ? "checkmark.circle.fill" : "arrow.down.circle").foregroundStyle(model.steamInstalled ? accent : .secondary)
                HStack(spacing: 12) {
                    Text("전역 그래픽 모드:").font(.callout.weight(.semibold))
                    Picker("전역 그래픽 모드", selection: Binding(get: { model.graphicsBackend }, set: model.setGraphicsBackend)) {
                        ForEach(GraphicsBackend.allCases, id: \.self) { backend in
                            Text(backend.label).tag(backend)
                        }
                    }
                    .labelsHidden()
                }
                Text("선택한 DX11 Mode / DX12 Mode는 모든 게임에 전역으로 적용됩니다. 비밀번호와 Steam Guard 코드는 Steam 창에서 직접 입력하세요.").font(.callout).foregroundStyle(.secondary)
                Toggle("MacDeck을 열면 Steam Big Picture 자동 시작", isOn: Binding(get: { model.library.startSteamOnLaunch ?? true }, set: model.setSteamAutostart))
                Toggle("Steam 화면 GPU 가속 (실험적)", isOn: Binding(get: { model.library.steamGPUAcceleration ?? false }, set: model.setSteamGPUAcceleration))
                Text("Big Picture의 화면 가속을 허용합니다. Steam을 완전히 종료한 뒤 다시 실행해야 적용됩니다. 검은 화면이나 Steam 오류가 생기면 이 옵션을 끄세요. 게임의 Metal 가속 설정과는 별개입니다.").font(.caption).foregroundStyle(.secondary)
            }
            panel("게임 설치 폴더", icon: "externaldrive") {
                Text("큰 게임 파일은 외장 SSD나 HDD에 저장할 수 있습니다. Steam과 Windows 실행 환경은 Mac에 유지됩니다.").font(.callout).foregroundStyle(.secondary)
                ForEach(model.library.externalLibraries ?? []) { storage in
                    VStack(alignment: .leading, spacing: 5) {
                        Label(storage.windowsPath + " · " + (storage.connected ? storage.availableSpace : "드라이브 연결 필요"), systemImage: storage.connected ? "externaldrive.fill" : "externaldrive.badge.exclamationmark")
                        Text(storage.path).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                        Text(model.externalLibraryRecognition(storage) + " · " + storage.nonRootMapping.windowsLibraryPath).font(.caption).foregroundStyle(model.externalLibraryRegistered(storage) ? accent : .orange)
                        HStack {
                            Button("Steam에 적용하고 시작") { model.applyExternalLibrary(storage) }.disabled(!storage.connected || model.managingStorage || model.downloadingSteam)
                            Button("연결 해제 (게임 파일 유지)") { model.applyExternalLibrary(storage, removing: true) }.disabled(model.managingStorage || model.downloadingSteam)
                        }
                    }
                }
                Button("외장 드라이브의 폴더 연결…", action: model.chooseExternalLibrary).buttonStyle(.bordered).disabled(model.managingStorage || model.downloadingSteam)
                Text("적용·해제 시 Steam을 정상 종료합니다. 실행 중인 게임은 먼저 저장하고 종료하세요. 새 게임 설치 위치와 기존 게임 이동은 Steam 저장 공간에서 선택합니다. 해제해도 게임 파일은 삭제하지 않습니다.").font(.caption).foregroundStyle(.secondary)
            }
            panel("설치된 Steam 게임", icon: "square.grid.2x2") {
                Text("MacDeck에 연결된 게임 \(model.steamGameCount)개").font(.headline)
                Text("Steam에서 게임을 설치하면 자동으로 확인해 라이브러리에 추가합니다. 상단 툴바 또는 런타임 설정에서 전역 DX11 Mode / DX12 Mode를 전환할 수 있습니다.").font(.callout).foregroundStyle(.secondary)
                Button("MacDeck 라이브러리 보기") { model.page = "library" }
                Text("게임 카드 메뉴에서 실행별 진단 폴더와 ZIP을 열 수 있습니다. Steam 게임의 그래픽 로그는 Steam 항목의 진단 폴더에서도 확인하세요.").font(.caption).foregroundStyle(.secondary)
            }
            panel("Mac용 Steam", icon: "desktopcomputer") {
                Text("Mac 네이티브 게임을 위한 기존 Steam도 별도로 연결할 수 있습니다.").font(.callout).foregroundStyle(.secondary)
                Button("설치된 Mac Steam 연결") {
                    if let app = Runtime.steamApp() { model.add(app) }
                    else { model.message = "Mac용 Steam이 설치되어 있지 않습니다." }
                }
            }
        }
    }

    func panel<Content: View>(_ title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(title, systemImage: icon).font(.headline)
            content()
        }.padding(23).frame(maxWidth: .infinity, alignment: .leading).background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 13))
    }
}

struct GameEditor: View {
    @DeckState var game: Game
    @ObservedObject var model: DeckModel
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
                Picker("전역 그래픽 모드 (모든 게임 공통)", selection: Binding(get: { model.graphicsBackend }, set: model.setGraphicsBackend)) {
                    ForEach(GraphicsBackend.allCases, id: \.self) { backend in
                        Text(backend.label).tag(backend)
                    }
                }
                Text("현재 전역 그래픽 모드: " + model.graphicsBackend.label).font(.caption).foregroundStyle(accent)
                TextField("Windows 환경 폴더 · 비워두면 게임별 자동 생성", text: Binding(get: { game.prefix ?? "" }, set: { game.prefix = $0.isEmpty ? nil : $0 }))
            }
            Text("인수 예: [\"-windowed\", \"-width\", \"1280\"]. 쉘 명령은 실행하지 않습니다.").font(.caption).foregroundStyle(.secondary)
            if let error { Text(error).foregroundStyle(.orange).font(.caption) }
            HStack {
                Button("로그 보기") { model.showLog(game) }
                Spacer()
                Button("취소") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("저장") {
                    do {
                        let args = try JSONDecoder().decode([String].self, from: Data(arguments.utf8))
                        guard !game.name.trimmingCharacters(in: .whitespaces).isEmpty else { throw DeckError.message("게임 이름을 입력해 주세요.") }
                        game.arguments = args
                        model.saveGame(game)
                        dismiss()
                    } catch { self.error = error.localizedDescription }
                }.buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
            }
        }.padding(28).frame(width: 540)
            .onAppear { arguments = String(decoding: (try? JSONEncoder().encode(game.arguments)) ?? Data("[]".utf8), as: UTF8.self) }
    }
}
