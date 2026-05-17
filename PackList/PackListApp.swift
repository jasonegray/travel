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

    // Schema versioning is managed via PackListMigrationPlan + PackListSchemaV1.
    // Future schema changes must add a new VersionedSchema and MigrationStage — never wipe.
    // The store-wipe fallback below handles only the one-time transition from the legacy
    // unversioned store to v1; it should never fire again after that initial upgrade.
    private static func makeContainer() -> ModelContainer {
        let config = ModelConfiguration("PackList")
        do {
            return try ModelContainer(migrationPlan: PackListMigrationPlan.self,
                                      configurations: config)
        } catch {
            logger.error("ModelContainer open failed (\(error)) — wiping PackList store and starting fresh")
            let storeURL = config.url
            for suffix in ["", "-shm", "-wal"] {
                try? FileManager.default.removeItem(
                    at: URL(fileURLWithPath: storeURL.path + suffix)
                )
            }
            // swiftlint:disable:next force_try
            return try! ModelContainer(migrationPlan: PackListMigrationPlan.self,
                                       configurations: config)
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
