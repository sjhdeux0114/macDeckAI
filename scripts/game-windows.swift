import Foundation
import CoreGraphics

let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
let games = windows.filter { window in
    let owner = (window[kCGWindowOwnerName as String] as? String ?? "").lowercased()
    let name = (window[kCGWindowName as String] as? String ?? "").lowercased()
    return (owner.contains("wine") || owner.contains("brogue") || owner.contains("macdeck") || owner.contains("steam") || name.contains("brogue") || name.contains("steam")) && (window[kCGWindowLayer as String] as? Int == 0)
}
let data = try JSONSerialization.data(withJSONObject: games, options: [.prettyPrinted, .sortedKeys])
print(String(decoding: data, as: UTF8.self))
