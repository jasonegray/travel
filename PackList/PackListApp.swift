import SwiftUI
import SwiftData
import os.log

private let logger = Logger(subsystem: "com.packlist", category: "PackListApp")

// PackList — travel packing list manager
@main
struct PackListApp: App {
    private let container: ModelContainer

    init() {
        container = Self.makeContainer()
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
        }
        .modelContainer(container)
    }

    // If the schema has changed since last launch (e.g. a stored attribute was
    // removed or renamed), SwiftData will fail to open the existing store.
    // For v0.1 alpha, wiping and recreating is acceptable — data loss is noted
    // in the console. A versioned migration will be added before public release.
    private static func makeContainer() -> ModelContainer {
        let schema = Schema([
            TripSession.self, TripInfo.self, MasterItem.self, TripItem.self,
            ItemInsight.self, PendingSuggestion.self
        ])
        let config = ModelConfiguration("PackList", schema: schema)
        do {
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            logger.warning("ModelContainer open failed (\(error)) — wiping PackList store and starting fresh")
            let storeURL = config.url
            for suffix in ["", "-shm", "-wal"] {
                try? FileManager.default.removeItem(
                    at: URL(fileURLWithPath: storeURL.path + suffix)
                )
            }
            // swiftlint:disable:next force_try
            return try! ModelContainer(for: schema, configurations: config)
        }
    }
}

private struct AppRootView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var repositories: RepositoryContainer?

    var body: some View {
        Group {
            if let repositories {
                ContentView()
                    .environment(\.repositories, repositories)
            }
        }
        .onAppear {
            guard repositories == nil else { return }
            let repos = RepositoryContainer(modelContext: modelContext)
            repositories = repos
            Task {
                await ImportService(repository: repos.masterItems).seedIfNeeded()
            }
        }
    }
}
