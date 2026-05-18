import SwiftUI
import SwiftData
import os.log

private let logger = Logger(subsystem: "com.packlist", category: "PackListApp")

// PackList — travel packing list manager
@MainActor
@main
struct PackListApp: App {
    private let container: ModelContainer
    private let repositories: RepositoryContainer

    init() {
        let c = Self.makeContainer()
        container = c
        repositories = RepositoryContainer(modelContext: c.mainContext)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.repositories, repositories)
        }
        .modelContainer(container)
    }

    private static func makeContainer() -> ModelContainer {
        let config = ModelConfiguration("PackList")
        do {
            return try ModelContainer(
                for: TripSession.self,
                     TripInfo.self,
                     MasterItem.self,
                     TripItem.self,
                     ItemInsight.self,
                     PendingSuggestion.self,
                configurations: config
            )
        } catch {
            logger.error("ModelContainer open failed (\(error)) — wiping PackList store and starting fresh")
            let storeURL = config.url
            for suffix in ["", "-shm", "-wal"] {
                try? FileManager.default.removeItem(
                    at: URL(fileURLWithPath: storeURL.path + suffix)
                )
            }
            // swiftlint:disable:next force_try
            return try! ModelContainer(
                for: TripSession.self,
                     TripInfo.self,
                     MasterItem.self,
                     TripItem.self,
                     ItemInsight.self,
                     PendingSuggestion.self,
                configurations: config
            )
        }
    }
}
