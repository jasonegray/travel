import UIKit

// Single source of truth for haptic feedback across the app.
// All methods must be called from the main thread (they're always reached through View/ViewModel callbacks).
// Vocabulary maps to the 8-class system defined in the Phase 1 haptics audit (#211).
enum HapticManager {

    // MARK: - Cached generators (avoids allocating a new generator on every call)

    private static let selectionGenerator    = UISelectionFeedbackGenerator()
    private static let lightGenerator        = UIImpactFeedbackGenerator(style: .light)
    private static let mediumGenerator       = UIImpactFeedbackGenerator(style: .medium)
    private static let rigidGenerator        = UIImpactFeedbackGenerator(style: .rigid)
    private static let notificationGenerator = UINotificationFeedbackGenerator()

    // MARK: - Selection

    /// Stateful chip/card toggle with no immediate persistence (wizard selections).
    static func selectionChanged() {
        selectionGenerator.selectionChanged()
    }

    // MARK: - Impact

    /// Lightweight navigation: expand/collapse, form save.
    static func lightImpact() {
        lightGenerator.impactOccurred()
    }

    /// Meaningful state commit: wizard step advance, item un-complete, archive.
    static func mediumImpact() {
        mediumGenerator.impactOccurred()
    }

    /// Sharp commit: adding a new item or task to a trip list.
    static func rigidImpact() {
        rigidGenerator.impactOccurred()
    }

    // MARK: - Notification

    /// Milestone completion: item checked off, trip created, trip marked complete.
    static func success() {
        notificationGenerator.notificationOccurred(.success)
    }

    /// Destructive confirmation: delete trip, delete item, regenerate packing list.
    static func warning() {
        notificationGenerator.notificationOccurred(.warning)
    }
}
