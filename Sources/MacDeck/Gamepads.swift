import AppKit
import GameController

struct PadSample: Equatable {
    var buttons: Set<String> = []
    var leftX: Float = 0
    var leftY: Float = 0
    var rightX: Float = 0
    var rightY: Float = 0
    var leftTrigger: Float = 0
    var rightTrigger: Float = 0

    static func read(_ pad: GCExtendedGamepad) -> PadSample {
        let buttons: [(String, GCControllerButtonInput)] = [
            ("A / ✕", pad.buttonA), ("B / ○", pad.buttonB), ("X / □", pad.buttonX), ("Y / △", pad.buttonY),
            ("LB / L1", pad.leftShoulder), ("RB / R1", pad.rightShoulder), ("Menu", pad.buttonMenu),
            ("↑", pad.dpad.up), ("↓", pad.dpad.down), ("←", pad.dpad.left), ("→", pad.dpad.right)
        ] + [("L3", pad.leftThumbstickButton), ("R3", pad.rightThumbstickButton), ("Options", pad.buttonOptions)].compactMap { name, button in button.map { (name, $0) } }
        return PadSample(buttons: Set(buttons.filter { $0.1.isPressed }.map { $0.0 }),
                         leftX: pad.leftThumbstick.xAxis.value, leftY: pad.leftThumbstick.yAxis.value,
                         rightX: pad.rightThumbstick.xAxis.value, rightY: pad.rightThumbstick.yAxis.value,
                         leftTrigger: pad.leftTrigger.value, rightTrigger: pad.rightTrigger.value)
    }
}

enum PadAction: Equatable { case previous, next, up, down, confirm, back, details, previousPage, nextPage, steam }

struct PadNavigation {
    private var held = Set<String>()
    private var nextMove: TimeInterval = 0
    mutating func reset() { held = []; nextMove = 0 }
    mutating func update(_ sample: PadSample, now: TimeInterval, enabled: Bool) -> [PadAction] {
        var current = sample.buttons
        if sample.leftX < -0.55 { current.insert("←") }
        if sample.leftX > 0.55 { current.insert("→") }
        if sample.leftY < -0.55 { current.insert("↓") }
        if sample.leftY > 0.55 { current.insert("↑") }
        defer { held = current }
        guard enabled else { return [] }
        let pressed = current.subtracting(held)
        let mapping: [(String, PadAction)] = [("A / ✕", .confirm), ("B / ○", .back), ("X / □", .details), ("LB / L1", .previousPage), ("RB / R1", .nextPage), ("Menu", .steam)]
        if let action = mapping.first(where: { pressed.contains($0.0) })?.1 { return [action] }
        let direction = current.contains("↑") || current.contains("←") ? -1 : current.contains("↓") || current.contains("→") ? 1 : 0
        if direction == 0 { nextMove = 0; return [] }
        let newlyPressed = !pressed.intersection(["↑", "↓", "←", "→"]).isEmpty
        guard newlyPressed || now >= nextMove else { return [] }
        nextMove = now + (newlyPressed ? 0.4 : 0.16)
        if current.contains("↑") { return [.up] }
        if current.contains("↓") { return [.down] }
        return [direction < 0 ? .previous : .next]
    }
}

struct PadStatus: Identifiable, Equatable {
    var id: ObjectIdentifier
    var name: String
    var extended: Bool
    var layout: GamepadLayout = .xbox
    var sample: PadSample
}

@MainActor
final class GamepadMonitor: ObservableObject {
    @Published private(set) var pads: [PadStatus] = []
    var onAction: ((PadAction) -> Void)?
    var navigationEnabled: (() -> Bool)?
    var acceptsAttachedSheet = false
    private var timer: Timer?
    private var navigation = PadNavigation()
    private var primary: ObjectIdentifier?

    init() {
        GCController.shouldMonitorBackgroundEvents = false
        poll()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.poll() }
        }
    }
    deinit { timer?.invalidate() }

    func poll() {
        let controllers = GCController.controllers()
        let updated = controllers.map { controller in
            PadStatus(id: ObjectIdentifier(controller), name: controller.vendorName ?? "게임패드",
                      extended: controller.extendedGamepad != nil,
                      layout: (controller.extendedGamepad is GCDualShockGamepad || controller.extendedGamepad is GCDualSenseGamepad) ? .playStation : .xbox,
                      sample: controller.extendedGamepad.map(PadSample.read) ?? PadSample())
        }
        if pads != updated { pads = updated }
        if primary != updated.first?.id { navigation.reset(); primary = updated.first?.id }
        let enabled = NSApp?.isActive == true && NSApp?.keyWindow != nil && (acceptsAttachedSheet || NSApp?.keyWindow?.attachedSheet == nil) && (navigationEnabled?() ?? false)
        for action in navigation.update(updated.first?.sample ?? PadSample(), now: ProcessInfo.processInfo.systemUptime, enabled: enabled) { onAction?(action) }
    }
}

// Input names stay stable internally; only presentation follows the connected pad.
enum GamepadLayout: String { case xbox, playStation }
struct ControllerHints {
    var layout: GamepadLayout
    var confirm: String { layout == .playStation ? "✕" : "A" }
    var back: String { layout == .playStation ? "○" : "B" }
    var details: String { layout == .playStation ? "□" : "X" }
    var shoulders: String { layout == .playStation ? "L1 / R1" : "LB / RB" }
    var menu: String { layout == .playStation ? "OPTIONS" : "Menu" }
}
