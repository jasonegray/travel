import SwiftUI
import SwiftData

final class RepositoryContainer {
    let masterItems: any MasterItemRepository
    let tripSessions: any TripSessionRepository
    let tripItems: any TripItemRepository
    let itemInsights: any ItemInsightRepository
    let pendingSuggestions: any PendingSuggestionRepository

    init(modelContext: ModelContext) {
        masterItems = SwiftDataMasterItemRepository(context: modelContext)
        tripSessions = SwiftDataTripSessionRepository(context: modelContext)
        tripItems = SwiftDataTripItemRepository(context: modelContext)
        itemInsights = SwiftDataItemInsightRepository(context: modelContext)
        pendingSuggestions = SwiftDataPendingSuggestionRepository(context: modelContext)
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
