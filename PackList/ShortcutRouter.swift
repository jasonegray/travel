import UIKit
import os.log

private let logger = Logger(subsystem: "com.packlist", category: "ShortcutRouter")

enum ShortcutActionType: String {
    case newTrip  = "com.packlist.shortcut.newtrip"
    case nextTrip = "com.packlist.shortcut.nexttrip"
}

@Observable
@MainActor
final class ShortcutRouter {
    var pendingAction: ShortcutActionType?

    func handle(_ shortcutItem: UIApplicationShortcutItem) {
        guard let action = ShortcutActionType(rawValue: shortcutItem.type) else {
            logger.warning("Unknown shortcut type: \(shortcutItem.type)")
            return
        }
        pendingAction = action
    }

    func consumeAction() -> ShortcutActionType? {
        defer { pendingAction = nil }
        return pendingAction
    }
}
