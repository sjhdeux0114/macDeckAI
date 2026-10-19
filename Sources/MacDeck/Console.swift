import SwiftUI
import AppKit

private let consoleAccent = Color(red: 0.57, green: 0.94, blue: 0.73)

struct ConsoleSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 14, weight: .semibold))
            .padding(.horizontal, 16).padding(.vertical, 11)
            .foregroundStyle(Color.white)
            .background(Color.white.opacity(configuration.isPressed ? 0.22 : 0.10), in: RoundedRectangle(cornerRadius: 10))
            .opacity(enabled ? 1 : 0.4)
    }
}

/// Pure navigation rules, shared by keyboard and controller. Never wrap across grid edges.
struct ConsoleGrid {
    static func move(index: Int, count: Int, columns: Int, action: PadAction) -> Int {
        guard count > 0 else { return 0 }
        let current = min(max(0, index), count - 1), width = max(1, columns)
        switch action {
        case .previous: return current % width == 0 ? current : current - 1
        case .next: return current % width == width - 1 ? current : min(count - 1, current + 1)
        case .up: return max(0, current - width)
        case .down: return min(count - 1, current + width)
        default: return current
        }
    }
}

private struct ConsoleAction: Identifiable {
    var id: String
    var title: String
    var subtitle: String
    var icon: String
    var enabled = true
    var destructive = false
    var run: () -> Void
}

private enum ConsoleArtwork {
    private static let cache = NSCache<NSString, NSImage>()
    static func image(for game: Game, disk: LibraryDisk) -> NSImage? {
        guard let id = game.steamAppID, id.allSatisfy({ $0.isNumber }),
              let root = SteamClient(disk: disk).root?.appendingPathComponent("appcache/librarycache") else { return nil }
        let key = root.path + "/" + id
        if let existing = cache.object(forKey: key as NSString) { return existing }
        for relative in [id + "/library_hero.jpg", id + "/header.jpg", id + "/library_600x900.jpg", id + "_library_600x900.jpg"] {
            if let image = NSImage(contentsOf: root.appendingPathComponent(relative)) {
                cache.setObject(image, forKey: key as NSString); return image
            }
        }
        return nil
    }
}

/// Key events stay inside MacDeck; no accessibility permission or global key injection.
private struct ConsoleKeys: NSViewRepresentable {
    var action: (PadAction) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(action: action) }
    func makeNSView(context: Context) -> NSView { context.coordinator.install(); return NSView() }
    func updateNSView(_ view: NSView, context: Context) { context.coordinator.action = action }
    static func dismantleNSView(_ view: NSView, coordinator: Coordinator) { coordinator.remove() }
    final class Coordinator {
        var action: (PadAction) -> Void
        var monitor: Any?
        init(action: @escaping (PadAction) -> Void) { self.action = action }
        func install() {
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard NSApp.isActive, NSApp.keyWindow?.attachedSheet == nil,
                      (!(NSApp.keyWindow?.firstResponder is NSTextView) || event.keyCode == 53),
                      event.modifierFlags.intersection([.command, .control, .option]).isEmpty else { return event }
                let mapped: PadAction?
                switch event.keyCode {
                case 123: mapped = .previous
                case 124: mapped = .next
                case 125: mapped = .down
                case 126: mapped = .up
                case 36, 76, 49: mapped = .confirm
                case 53: mapped = .back
                case 48: mapped = event.modifierFlags.contains(.shift) ? .previousPage : .nextPage
                case 7: mapped = .details
                default: mapped = nil
                }
                guard let mapped else { return event }
                // Holding Return must not launch several copies of a game.
                if !event.isARepeat || [.previous, .next, .up, .down].contains(mapped) { self?.action(mapped) }
                return nil
            }
        }
        func remove() { if let monitor { NSEvent.removeMonitor(monitor) }; monitor = nil }
        deinit { remove() }
    }
}

struct ConsoleView: View {
    @ObservedObject var model: DeckModel
    @StateObject private var pads = GamepadMonitor()
    @DeckState private var uiFailures: [String] = []
    @DeckState private var testLayout: GamepadLayout?
    @DeckState private var focusID: String?
    @DeckState private var detailID: UUID?
    @DeckState private var editing: Game?
    @DeckState private var reporting: Game?
    @DeckState private var removal: Game?
    @DeckState private var disconnect: ExternalLibrary?
    @DeckState private var quitRequested = false
    @DeckState private var history: [SessionDiagnostics.Entry] = []
    @FocusState private var searching: Bool
    private let pages = ["library", "steam", "storage", "runtime", "controllers", "diagnostics", "compatibility"]
    private let titles = ["라이브러리", "Steam", "저장 공간", "실행 환경", "게임패드", "실행 기록", "호환성 DB"]
    private var page: String { pages.contains(model.page) ? model.page : "library" }
    private var detail: Game? { model.library.games.first { $0.id == detailID } }
    private var columns: Int { 3 }
    private var hints: ControllerHints { ControllerHints(layout: testLayout ?? pads.pads.first?.layout ?? .xbox) }

    var body: some View {
        VStack(spacing: 0) {
            topbar
            Divider().overlay(.white.opacity(0.06))
            ScrollViewReader { scroll in
                ScrollView {
                    VStack(alignment: .leading, spacing: 26) {
                        heading
                        if page == "library" && detail == nil { libraryHero }
                        if page == "controllers" { controllerReadout }
                        if !status.isEmpty { Text(status).font(.callout).foregroundStyle(consoleAccent).textSelection(.enabled) }
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 20), count: columns), spacing: 20) {
                            ForEach(actions) { item in tile(item).id(item.id) }
                        }
                        if actions.isEmpty {
                            Text(model.search.isEmpty ? "아직 게임이 없습니다. 상단 + 버튼으로 게임을 추가하세요." : "검색 결과가 없습니다.")
                                .font(.title3).foregroundStyle(.secondary).padding(.vertical, 40)
                        }
                    }.padding(36)
                }
                .onChange(of: focusID) { id in
                    if let id { withAnimation(.easeOut(duration: 0.16)) { scroll.scrollTo(id, anchor: .bottom) } }
                }
            }
            footer
        }
        .background(LinearGradient(colors: [Color(red: 0.065, green: 0.10, blue: 0.14), Color(red: 0.025, green: 0.035, blue: 0.055)], startPoint: .topLeading, endPoint: .bottomTrailing))
        .tint(consoleAccent)
        .background(ConsoleKeys(action: handle))
        .onAppear {
            history = SessionDiagnostics.entries(disk: model.disk)
            normalizeFocus()
            pads.navigationEnabled = { editing == nil && reporting == nil }
            pads.onAction = handle
            if CommandLine.arguments.contains("--console-ui-test") { runInterfaceCheck() }
        }
        .onChange(of: model.page) { _ in if page == "diagnostics" { history = SessionDiagnostics.entries(disk: model.disk) }; detailID = nil; focusID = nil; normalizeFocus() }
        .onChange(of: model.search) { _ in focusID = nil; normalizeFocus() }
        .onChange(of: actions.map(\.id)) { _ in normalizeFocus() }
        .allowsHitTesting(model.message == nil && removal == nil && disconnect == nil && !quitRequested)
        .overlay {
            if let message = model.message {
                ZStack {
                    Color.black.opacity(0.8).ignoresSafeArea()
                    VStack(alignment: .leading, spacing: 24) {
                        Text("MacDeck").font(.title.bold())
                        ScrollView { Text(message).textSelection(.enabled) }.frame(maxHeight: 260)
                        Button("\(hints.confirm) / \(hints.back) · Enter / Esc  확인") { model.message = nil }.buttonStyle(.borderedProminent)
                    }.padding(36).frame(width: 600).background(Color(red: 0.09, green: 0.13, blue: 0.17), in: RoundedRectangle(cornerRadius: 24))
                }
            } else if quitRequested {
                confirmation(title: "MacDeck을 종료할까요?", message: "Steam과 실행 중인 게임도 종료됩니다. 게임을 먼저 저장하세요.", confirm: {
                    model.terminateAll(); NSApp.terminate(nil)
                }, cancel: { quitRequested = false })
            } else if let game = removal {
                confirmation(title: "라이브러리에서 제거할까요?", message: game.name + "의 게임 파일은 삭제하지 않습니다.", confirm: {
                    model.remove(game.id); removal = nil; detailID = nil
                }, cancel: { removal = nil })
            } else if let storage = disconnect {
                confirmation(title: "폴더 연결을 해제할까요?", message: storage.path + "\n게임을 먼저 저장하고 종료하세요. Steam을 종료하며 게임 파일은 유지됩니다.", confirm: {
                    model.applyExternalLibrary(storage, removing: true); disconnect = nil
                }, cancel: { disconnect = nil })
            }
        }
        .sheet(item: $editing) { game in GameEditor(game: game, model: model) }
        .sheet(item: $reporting) { game in SupportReportView(game: game, model: model) }
    }

    private var topbar: some View {
        HStack(spacing: 18) {
            Image(systemName: "gamecontroller.fill").font(.title).foregroundStyle(consoleAccent)
            Text("MacDeck").font(.system(size: 25, weight: .bold, design: .rounded))
            Spacer(minLength: 8)
            ForEach(Array(pages.enumerated()), id: \.element) { index, tab in
                Button { switchPage(tab) } label: {
                    Text(titles[index]).font(.system(size: 14, weight: .semibold))
                        .padding(.horizontal, 13).padding(.vertical, 12)
                        .foregroundStyle(page == tab ? Color.black : Color.white.opacity(0.65))
                        .background(page == tab ? consoleAccent : .clear, in: Capsule())
                }.buttonStyle(.plain)
            }
            Button { model.chooseGame() } label: { Image(systemName: "plus").font(.title3).padding(10) }.buttonStyle(.plain).help("게임 추가 · ⌘O")
            Button { NSApp.keyWindow?.toggleFullScreen(nil) } label: { Image(systemName: "arrow.up.left.and.arrow.down.right").padding(10) }.buttonStyle(.plain).help("전체 화면")
        }.padding(.horizontal, 30).padding(.vertical, 22)
    }

    private var heading: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 8) {
                Text(detail == nil ? "PLAY YOUR WAY" : "GAME DETAILS").font(.system(size: 11, weight: .bold)).tracking(3).foregroundStyle(consoleAccent)
                Text(detail?.name ?? titles[pages.firstIndex(of: page) ?? 0]).font(.system(size: 34, weight: .bold)).lineLimit(2)
                Text(subtitle).font(.system(size: 15)).foregroundStyle(.secondary)
            }
            Spacer()
            if page == "library" && detail == nil {
                HStack {
                    Image(systemName: "magnifyingglass")
                    TextField("게임 검색", text: $model.search).textFieldStyle(.plain).focused($searching)
                    if searching { Button("완료") { searching = false; NSApp.keyWindow?.makeFirstResponder(nil) } }
                }.padding(14).frame(width: 230).background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var subtitle: String {
        if let game = detail {
            let profile = model.gameProfile(game)
            return (profile?.status.label ?? "미검증") + " · " + (game.steamAppID.map { "Steam App ID " + $0 } ?? "로컬 게임") + (profile?.baseline == nil ? "" : " · 실행 기준 보호 중")
        }
        switch page {
        case "library": return "\(model.filtered.count)개의 게임 · \(model.graphicsBackend.shortLabel) → Metal"
        case "steam": return "Steam에 로그인하고 Big Picture에서 게임을 설치하세요."
        case "storage": return "외장 SSD와 HDD에 게임을 보관하세요."
        case "runtime": return "그래픽 모드 · 업데이트 · 성능 표시"
        case "controllers": return "연결 상태와 실시간 입력을 확인하세요."
        case "compatibility": return "게임명 · Steam App ID · 검증 상태 · 실행 기준 보호"
        default: return "최근 실행 로그와 문제 진단"
        }
    }

    private var status: String {
        switch page {
        case "steam", "storage": return model.steamProgress
        case "runtime": return model.updateBannerMessage
        default: return ""
        }
    }

    private var libraryHero: some View {
        HStack(spacing: 28) {
            VStack(alignment: .leading, spacing: 12) {
                Text("READY WHEN YOU ARE").font(.system(size: 11, weight: .bold)).tracking(3).foregroundStyle(consoleAccent)
                Text(focusedGame?.name ?? "다음 플레이를 골라보세요.").font(.system(size: 30, weight: .bold)).lineLimit(2)
                Text("\(hints.confirm) 플레이 · Enter     \(hints.details) 게임 관리 · X").foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "cube.transparent.fill").font(.system(size: 76, weight: .light)).foregroundStyle(consoleAccent.opacity(0.65))
        }.padding(30).frame(maxWidth: .infinity, minHeight: 170, alignment: .leading)
            .background(LinearGradient(colors: [Color(red: 0.12, green: 0.28, blue: 0.29), Color(red: 0.10, green: 0.14, blue: 0.24)], startPoint: .leading, endPoint: .trailing), in: RoundedRectangle(cornerRadius: 22))
    }

    private var focusedGame: Game? {
        model.filtered.first { "game-" + $0.id.uuidString == focusID }
    }

    private func tile(_ item: ConsoleAction) -> some View {
        let focused = focusID == item.id
        let game = model.library.games.first { "game-" + $0.id.uuidString == item.id }
        let artwork = game.flatMap { ConsoleArtwork.image(for: $0, disk: model.disk) }
        return ZStack(alignment: .topTrailing) {
        Button {
            focusID = item.id
            if item.enabled { item.run() }
        } label: {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Image(systemName: item.icon).font(.system(size: 33, weight: .light))
                    Spacer()
                    if focused && game == nil { Image(systemName: "arrow.up.right").font(.title3) }
                }.foregroundStyle(item.destructive ? Color.orange : consoleAccent)
                Spacer(minLength: 0)
                Text(item.title).font(.system(size: 20, weight: .semibold)).lineLimit(2).multilineTextAlignment(.leading)
                Text(item.subtitle).font(.system(size: 13)).foregroundStyle(.secondary).lineLimit(3).multilineTextAlignment(.leading)
            }.padding(24).frame(maxWidth: .infinity, minHeight: 185, maxHeight: 220, alignment: .leading)
                .background {
                    if let artwork {
                        GeometryReader { geometry in
                            Image(nsImage: artwork).resizable().scaledToFill().frame(width: geometry.size.width, height: geometry.size.height).clipped()
                                .overlay(LinearGradient(colors: [.black.opacity(0.08), .black.opacity(0.88)], startPoint: .top, endPoint: .bottom))
                        }
                    } else { focused ? Color.white.opacity(0.115) : Color.white.opacity(0.045) }
                }
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(focused ? consoleAccent : .white.opacity(0.08), lineWidth: focused ? 3 : 1))
                .shadow(color: focused ? consoleAccent.opacity(0.15) : .clear, radius: 14)
                .opacity(item.enabled ? 1 : 0.4)
                .contentShape(RoundedRectangle(cornerRadius: 18))
        }.buttonStyle(.plain)
            .accessibilityLabel(item.title + ", " + item.subtitle)
            .accessibilityValue(focused ? "선택됨" : "")
            if let game {
                Button {
                    model.selected = game.id; detailID = game.id; focusID = nil; normalizeFocus()
                } label: {
                    Image(systemName: "ellipsis").font(.system(size: 19, weight: .bold)).foregroundStyle(.white)
                        .frame(width: 40, height: 36).background(.black.opacity(0.5), in: Capsule())
                }.buttonStyle(.plain).padding(16).help("게임 관리 · " + hints.details + " / 키보드 X")
                    .accessibilityLabel(game.name + " 게임 관리")
            }
        }

    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 24) {
                Text("스틱 · D-Pad  이동")
                Text("\(hints.confirm)  선택")
                Text("\(hints.back)  뒤로")
                Text("\(hints.details)  게임 관리")
                Text("\(hints.shoulders)  화면 전환")
                Spacer()
                Label(pads.pads.first?.name ?? "패드 연결 대기 · Xbox 표기", systemImage: "gamecontroller.fill")
            }
            Text("키보드  ↑↓←→ 이동 · Enter / Space 선택 · Esc 뒤로 · X 게임 관리 · Tab / Shift-Tab 화면 전환 · ⌘O 게임 추가")
                .foregroundStyle(.secondary)
        }.font(.system(size: 12, weight: .medium)).padding(.horizontal, 32).padding(.vertical, 15).background(.black.opacity(0.23))
    }

    private func normalizeFocus() {
        if !actions.contains(where: { $0.id == focusID }) { focusID = actions.first?.id }
        selectFocusedGame()
    }
    private func selectFocusedGame() { if let game = focusedGame { model.selected = game.id } }
    private func switchPage(_ target: String) { detailID = nil; focusID = nil; model.page = target; normalizeFocus() }
    private func handle(_ action: PadAction) {
        guard editing == nil && reporting == nil else { return }
        if searching || NSApp.keyWindow?.firstResponder is NSTextView {
            if action == .back { searching = false; NSApp.keyWindow?.makeFirstResponder(nil) }
            return
        }
        if removal != nil || disconnect != nil || quitRequested {
            // Destructive operations require a fresh explicit press; directions never confirm.
            if action == .back { removal = nil; disconnect = nil; quitRequested = false }
            if action == .confirm {
                if quitRequested { model.terminateAll(); NSApp.terminate(nil); return }
                if let game = removal { model.remove(game.id); removal = nil; detailID = nil }
                else if let storage = disconnect { model.applyExternalLibrary(storage, removing: true); disconnect = nil }
            }
            return
        }
        if model.message != nil { if action == .back || action == .confirm { model.message = nil }; return }
        switch action {
        case .previousPage, .nextPage:
            let index = pages.firstIndex(of: page) ?? 0
            switchPage(pages[(index + (action == .nextPage ? 1 : pages.count - 1)) % pages.count])
        case .back:
            if detailID != nil { detailID = nil; focusID = nil; normalizeFocus() }
            else { switchPage("library") }
        case .steam: switchPage("steam") // Menu navigates; never silently starts Steam.
        case .details:
            if let game = focusedGame { detailID = game.id; focusID = nil; normalizeFocus() }
        case .confirm:
            if let item = actions.first(where: { $0.id == focusID }), item.enabled { item.run() }
        default:
            let index = actions.firstIndex { $0.id == focusID } ?? 0
            let next = ConsoleGrid.move(index: index, count: actions.count, columns: columns, action: action)
            if actions.indices.contains(next) { focusID = actions[next].id; selectFocusedGame() }
        }
    }

    private func confirmation(title: String, message: String, confirm: @escaping () -> Void, cancel: @escaping () -> Void) -> some View {
        ZStack {
            Color.black.opacity(0.8).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 24) {
                Text(title).font(.title.bold())
                Text(message).foregroundStyle(.secondary)
                HStack {
                    Button("\(hints.back) · Esc  취소", action: cancel).buttonStyle(ConsoleSecondaryButtonStyle())
                    Spacer()
                    Button("\(hints.confirm) · Enter  확인", action: confirm).buttonStyle(.borderedProminent)
                }
            }.padding(36).frame(width: 560).background(Color(red: 0.09, green: 0.13, blue: 0.17), in: RoundedRectangle(cornerRadius: 24))
        }
    }

    private func runInterfaceCheck() {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 900_000_000)
            switchPage("library")
            try? await Task.sleep(nanoseconds: 400_000_000)
            capture("library")
            testLayout = .xbox
            try? await Task.sleep(nanoseconds: 250_000_000)
            capture("library-xbox")
            testLayout = nil
            let initial = focusID
            handle(.next)
            if actions.count > 1 { checkUI(focusID != initial, "right moves selection") }
            handle(.previous)
            checkUI(focusID == initial, "left restores selection")
            if focusedGame != nil {
                handle(.details)
                checkUI(detail != nil && focusID == "play", "details exposes controller actions")
                try? await Task.sleep(nanoseconds: 300_000_000)
                capture("details")
                if let game = detail {
                    reporting = game
                    try? await Task.sleep(nanoseconds: 400_000_000)
                    capture("report")
                    reporting = nil
                    try? await Task.sleep(nanoseconds: 300_000_000)
                }
                handle(.back)
                checkUI(detail == nil, "back restores library")
            }
            for target in ["steam", "storage", "runtime", "controllers", "diagnostics", "compatibility"] {
                switchPage(target)
                try? await Task.sleep(nanoseconds: 300_000_000)
                capture(target)
                checkUI(actions.contains { $0.id == focusID }, "page always has a valid selection")
                handle(.down)
                checkUI(actions.contains { $0.id == focusID }, "down remains in bounds")
            }
            handle(.steam)
            checkUI(page == "steam", "Menu navigates without launching Steam")
            let result = uiFailures.isEmpty ? "PASS: console navigation, details, seven pages, Xbox/PlayStation hints, report sheet and snapshots" : "FAIL: " + uiFailures.joined(separator: "; ")
            print(result); fflush(stdout)
            try? Data((result + "\n").utf8).write(to: evidenceFolder.appendingPathComponent("console-ui-result.log"))
            switchPage("library")
        }
    }

    private var evidenceFolder: URL {
        let arguments = CommandLine.arguments
        if let index = arguments.firstIndex(of: "--console-evidence-dir"), arguments.indices.contains(index + 1) {
            return URL(fileURLWithPath: arguments[index + 1], isDirectory: true)
        }
        return FileManager.default.temporaryDirectory.appendingPathComponent("MacDeck-UI-Checks", isDirectory: true)
    }

    private func checkUI(_ condition: Bool, _ detail: String) {
        if !condition { uiFailures.append(detail) }
    }

    private func capture(_ name: String) {
        let main = NSApp.mainWindow ?? NSApp.windows.first { $0.isVisible && !($0 is NSPanel) }
        guard let view = main?.attachedSheet?.contentView ?? NSApp.keyWindow?.contentView ?? main?.contentView,
              let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
            uiFailures.append("No visible MacDeck view for " + name); return
        }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        do {
            guard let png = bitmap.representation(using: .png, properties: [:]) else { uiFailures.append("PNG capture failed: " + name); return }
            try FileManager.default.createDirectory(at: evidenceFolder, withIntermediateDirectories: true)
            try png.write(to: evidenceFolder.appendingPathComponent("console-" + name + ".png"))
        } catch { uiFailures.append("Could not save snapshot " + name) }
    }

    private var controllerReadout: some View {
        VStack(alignment: .leading, spacing: 12) {
            if pads.pads.isEmpty { Text("연결된 게임패드가 없습니다.").foregroundStyle(.secondary) }
            ForEach(pads.pads) { pad in
                Text(pad.name).font(.title2.bold())
                Text(pad.sample.buttons.sorted().joined(separator: "  ")).foregroundStyle(consoleAccent)
                Text(String(format: "L  %+.2f  %+.2f     R  %+.2f  %+.2f     LT  %.2f     RT  %.2f", pad.sample.leftX, pad.sample.leftY, pad.sample.rightX, pad.sample.rightY, pad.sample.leftTrigger, pad.sample.rightTrigger)).font(.system(.body, design: .monospaced))
            }
            Text("MacDeck이 전면에 있을 때만 조작합니다. Steam과 게임이 전면에 있으면 입력을 가로채지 않습니다.").font(.caption).foregroundStyle(.secondary)
        }
    }

    private func action(_ id: String, _ title: String, _ subtitle: String, _ icon: String, enabled: Bool = true, destructive: Bool = false, run: @escaping () -> Void) -> ConsoleAction {
        ConsoleAction(id: id, title: title, subtitle: subtitle, icon: icon, enabled: enabled, destructive: destructive, run: run)
    }

    private var actions: [ConsoleAction] {
        if let game = detail {
            let items = [
                action("play", "플레이", game.name, "play.fill", run: { model.launch(game) }),
                action("edit", "이름 · 실행 인수", "키보드로 편집 · 게임별 실행 옵션", "slider.horizontal.3", run: { editing = game }),
                action("steam-renderer", "Steam 게임 렌더러", model.gameProfile(game)?.steamRenderer?.label ?? "통합 모드 기본값 · Apple 비교", "cube.transparent", enabled: game.steamAppID != nil && model.library.sharedSteamRenderer == true, run: { model.cycleSteamRenderer(game) }),
                action("dx9", "Direct3D 9", (game.d3d9Mode ?? .automatic).label, "cube", run: {
                    var changed = game; let modes = D3D9Mode.allCases; let index = modes.firstIndex(of: game.d3d9Mode ?? .automatic) ?? 0
                    changed.d3d9Mode = modes[(index + 1) % modes.count]; model.saveGame(changed)
                }),
                action("compatibility", "호환성 점검", "엔진 · 그래픽 API · 충돌 후보 확인", "checkmark.shield", run: { model.inspectCompatibility(game) }),
                action("log", "실행 로그", "최근 실행의 GPU · 오류 기록", "doc.text.magnifyingglass", run: { model.showLog(game) }),
                action("report", "오류 신고 메일", "ZIP + App ID · " + SupportReports.recipient, "envelope", enabled: !model.preparingSupportReport, run: { reporting = game }),
                action("working", "정상 실행 기준 저장", "실제 플레이를 확인한 뒤 선택 · 설정과 렌더러 보호", "checkmark.shield", run: { model.markGameWorking(game) }),
                action("failing", "실행 문제 기록", "이 게임만 문제 있음으로 기록 · 다른 게임 유지", "exclamationmark.triangle", run: { model.markGameFailing(game) }),
                action("release", "실행 기준 보호 해제", "이 게임의 보호만 해제 · 실험은 자동 적용하지 않음", "lock.open", enabled: model.gameProfile(game)?.baseline != nil, run: { model.releaseGameProtection(game) }),
                action("export", "진단 ZIP 저장", "재현한 문제의 기록 내보내기", "square.and.arrow.up", run: { model.exportDiagnostics(game) }),
                action("remove", "라이브러리에서 제거", "게임 파일은 유지됩니다", "minus.circle", destructive: true, run: { removal = game }),
                action("back", "라이브러리로", "다른 게임 선택", "arrow.left", run: { detailID = nil; focusID = nil; normalizeFocus() })
            ]
            return items
        }
        switch page {
        case "library":
            return model.filtered.map { game in
                action("game-" + game.id.uuidString, game.name, (model.gameProfile(game)?.status.label ?? "미검증") + " · " + hints.details + " / X 게임 관리", game.steamAppID != nil ? "gamecontroller.fill" : "cube.fill", run: { model.selected = game.id; model.launch(game) })
            } + [action("add", "게임 추가", "Windows .exe · macOS .app", "plus", run: model.chooseGame)]
        case "steam":
            return [
                action("steam", model.steamInstalled ? "Steam Big Picture 열기" : "Steam 설치", "로그인 · 전체 라이브러리 · 게임 설치", "play.rectangle.fill", enabled: !model.downloadingSteam, run: model.launchSteam),
                action("refresh", "설치 게임 새로 고침", "설치된 Steam 게임을 MacDeck에 표시", "arrow.clockwise", enabled: model.steamInstalled, run: { model.refreshSteamGames() }),
                action("autostart", "Steam 자동 시작", (model.library.startSteamOnLaunch ?? true) ? "켬 · MacDeck을 열 때 한 번 실행" : "끔 · 직접 실행", "power", run: { model.setSteamAutostart(!(model.library.startSteamOnLaunch ?? true)) }),
                action("gpu", "Steam GPU 가속", (model.library.steamGPUAcceleration ?? false) ? "켬 · 변경 후 Steam 다시 실행" : "끔 · 변경 후 Steam 다시 실행", "sparkles", run: { model.setSteamGPUAcceleration(!(model.library.steamGPUAcceleration ?? false)) }),
                action("storage", "게임 설치 폴더", "외장 드라이브 연결 · 해제", "externaldrive", run: { switchPage("storage") })
            ]
        case "storage":
            var result = [action("connect", "외장 폴더 연결", "시스템 폴더 선택 창을 엽니다", "externaldrive.badge.plus", enabled: !model.managingStorage, run: model.chooseExternalLibrary)]
            for storage in model.library.externalLibraries ?? [] {
                let id = storage.id.uuidString
                result.append(action("apply-" + id, storage.windowsPath + " 적용", storage.path + " · " + model.externalLibraryRecognition(storage), "externaldrive.fill", enabled: storage.connected && !model.managingStorage && !model.downloadingSteam, run: { model.applyExternalLibrary(storage) }))
                result.append(action("disconnect-" + id, storage.windowsPath + " 연결 해제", "게임 파일 유지 · " + storage.path, "eject", enabled: !model.managingStorage && !model.downloadingSteam, destructive: true, run: { disconnect = storage }))
            }
            return result
        case "compatibility":
            return model.gameProfiles.map { profile in
                action("profile-" + profile.id, profile.name, profile.id + " · " + profile.status.label + (profile.baseline == nil ? "" : " · 보호 중"), profile.baseline != nil ? "lock.shield" : profile.status == .failing ? "exclamationmark.triangle" : profile.status == .untested ? "questionmark.circle" : "checkmark.circle", run: {
                    if let game = model.library.games.first(where: { GameProfileStore.identity($0) == profile.id }) {
                        detailID = game.id; focusID = nil; normalizeFocus()
                    } else { model.message = profile.notes }
                })
            } + [action("profile-file", "DB 파일 열기", "게임별 기록 · 실험 설정은 기본 끔", "doc.text", run: { NSWorkspace.shared.open(GameProfileStore(disk: model.disk).file) })]
        case "runtime":
            var result = [
                action("shared-renderer", "Steam 통합 렌더러", model.library.sharedSteamRenderer == true ? "Apple 비교 모드 · 선택하면 기존 환경 복구" : "기존 환경 · 선택하면 Apple 비교 모드", "square.stack.3d.up", enabled: SharedSteamRuntime(disk: model.disk).available, run: { model.setSharedRenderer(model.library.sharedSteamRenderer != true) }),
                action("dependencies", "필수 런타임 다시 준비", model.dependencyProgress, "shippingbox", enabled: !model.preparingDependencies, run: { model.prepareGameDependencies(retry: true) }),
                action("graphics", "전역 그래픽 모드", model.graphicsBackend.shortLabel + " · 선택하면 전환", "cube.transparent", run: { model.setGraphicsBackend(model.graphicsBackend == .dxmt ? .d3d12 : .dxmt) }),
                action("hud", "Metal 성능 HUD", (model.library.showMetalHUD ?? true) ? "켬 · 선택하면 끔" : "끔 · 선택하면 켬", "gauge", run: { model.setMetalHUD(!(model.library.showMetalHUD ?? true)) }),
                action("auto-update", "자동 업데이트", model.autoUpdateRuntime ? "켬 · 선택하면 끔" : "끔 · 선택하면 켬", "arrow.triangle.2.circlepath", run: { model.setAutoUpdateRuntime(!model.autoUpdateRuntime) }),
                action("check-update", "업데이트 확인", model.updateBannerMessage.isEmpty ? "공식 런타임 릴리스 확인" : model.updateBannerMessage, "arrow.clockwise", enabled: !model.checkingUpdates && !model.updatingComponents, run: { model.checkRuntimeUpdates(autoInstall: false) }),
                action("wine", "Wine 선택", model.runtime.path ?? "연결된 런타임 없음", "shippingbox", run: model.chooseRuntime),
                action("detect", "런타임 자동 감지", "설치된 Wine 다시 찾기", "antenna.radiowaves.left.and.right", run: model.resetRuntime),
                action("test", "런타임 검사", model.runtime.version, "checkmark.circle", enabled: !model.testingRuntime, run: model.testRuntime),
                action("fullscreen", "전체 화면 전환", "MacDeck 화면 확대 · 복귀", "arrow.up.left.and.arrow.down.right", run: { NSApp.keyWindow?.toggleFullScreen(nil) }),
                action("data", "데이터 폴더", "라이브러리 · 로그 · 실행 환경", "folder", run: model.revealData),
                action("quit", "MacDeck 종료", "실행 중인 게임을 먼저 저장하세요", "power", destructive: true, run: { quitRequested = true })
            ]
            for item in model.runtimeComponents {
                result.append(action("component-" + item.kind.rawValue, item.kind.title, item.statusMessage.isEmpty ? "설치됨: " + item.installedVersion : item.statusMessage, "arrow.down.circle", enabled: item.updateAvailable && !model.updatingComponents && !model.checkingUpdates, run: { model.updateComponent(item.kind) }))
            }
            return result
        case "controllers":
            return [
                action("windows-pad", "Windows 입력 테스트", "XInput · DirectInput 인식 확인", "gamecontroller", enabled: model.steamInstalled, run: model.openWindowsControllerTest),
                action("steam-pad", "Steam 컨트롤러 설정", "Big Picture에서 Steam Input 설정", "gamecontroller.fill", run: model.launchSteam),
                action("fullscreen", "전체 화면 전환", "소파에서도 편한 화면", "arrow.up.left.and.arrow.down.right", run: { NSApp.keyWindow?.toggleFullScreen(nil) })
            ]
        default:
            var result = [action("logs", "로그 폴더 열기", "실행별 렌더러 로그와 종료 상태", "folder", run: model.revealData)]
            for entry in history.prefix(20) {
                result.append(action("session-" + entry.folder.lastPathComponent, entry.record.game, entry.record.started.formatted() + " · " + entry.record.status, "doc.text", run: { _ = try? SessionDiagnostics.summary(folder: entry.folder); NSWorkspace.shared.open(entry.folder) }))
            }
            return result
        }
    }
}
