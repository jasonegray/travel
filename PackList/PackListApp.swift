import SwiftUI
import SwiftData

// PackList — travel packing list manager
@main
struct PackListApp: App {
    var body: some Scene {
        WindowGroup {
            AppRootView()
        }
        .modelContainer(for: [
            TripSession.self,
            TripInfo.self,
            MasterItem.self,
            TripItem.self,
            ItemInsight.self,
            PendingSuggestion.self
        ])
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
