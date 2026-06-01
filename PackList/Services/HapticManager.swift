import UIKit

// Single source of truth for haptic feedback across the app.
// Vocabulary maps to the 8-class system defined in the Phase 1 haptics audit (#211).
enum HapticManager {

    // MARK: - Selection

    /// Stateful chip/card toggle with no immediate persistence (wizard selections).
    static func selectionChanged() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    // MARK: - Impact

    /// Lightweight navigation: expand/collapse, wizard advance, form save.
    static func lightImpact() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// Meaningful but non-destructive state commit: item un-complete, archive.
    static func mediumImpact() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    /// Sharp commit: adding a new item or task to a trip list.
    static func rigidImpact() {
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
    }

    // MARK: - Notification

    /// Milestone completion: item checked off, trip created, trip marked complete.
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    /// Destructive confirmation: delete trip, delete item, regenerate packing list.
    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}
