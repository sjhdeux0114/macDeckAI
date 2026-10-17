import AppKit
import GameController
let app = NSApplication.shared
app.setActivationPolicy(.accessory)
GCController.shouldMonitorBackgroundEvents = true
let until = Date().addingTimeInterval(3)
while Date() < until { RunLoop.current.run(until: Date().addingTimeInterval(0.05)) }
let records = GCController.controllers().map { ["name": $0.vendorName ?? "Controller", "extendedGamepad": String($0.extendedGamepad != nil)] }
let data = try JSONSerialization.data(withJSONObject: records, options: [.prettyPrinted, .sortedKeys])
print(String(decoding: data, as: UTF8.self))
