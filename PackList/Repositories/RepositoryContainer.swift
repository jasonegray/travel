import SwiftUI
import SwiftData

@MainActor
final class RepositoryContainer {
    let masterItems: any MasterItemRepository
    let tripSessions: any TripSessionRepository
    let tripItems: any TripItemRepository
    let tripInfo: any TripInfoRepository
    let itemInsights: any ItemInsightRepository
    let pendingSuggestions: any PendingSuggestionRepository

    /// Shared coordinator for the one-time master-list seed. Every path that
    /// depends on the seed (HomeView, trip creation) awaits this instance so the
    /// seed runs exactly once and callers never race a partially-seeded store.
    let seedCoordinator: SeedCoordinator

    init(modelContext: ModelContext) {
        let masterItems = SwiftDataMasterItemRepository(context: modelContext)
        self.masterItems = masterItems
        tripSessions = SwiftDataTripSessionRepository(context: modelContext)
        tripItems = SwiftDataTripItemRepository(context: modelContext)
        tripInfo = SwiftDataTripInfoRepository(context: modelContext)
        itemInsights = SwiftDataItemInsightRepository(context: modelContext)
        pendingSuggestions = SwiftDataPendingSuggestionRepository(context: modelContext)
        seedCoordinator = SeedCoordinator(repository: masterItems)
    }
}

// MARK: - SwiftUI Environment

private struct RepositoryContainerKey: EnvironmentKey {
    static let defaultValue: RepositoryContainer? = nil
}

extension EnvironmentValues {
    var repositories: RepositoryContainer? {
        get { self[RepositoryContainerKey.self] }
        set { self[RepositoryContainerKey.self] = newValue }
    }
}
