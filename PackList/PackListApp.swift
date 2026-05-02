import SwiftUI
import SwiftData

@main
struct PackListApp: App {
    var body: some Scene {
        WindowGroup {
            AppRootView()
        }
        .modelContainer(for: [
            TripSession.self,
            MasterItem.self,
            TripItem.self,
            ItemInsight.self,
            PendingSuggestion.self
        ])
    }
}

/// Bridges the SwiftData model context into the repository layer.
/// Lives here so that RepositoryContainer is created exactly once,
/// on the main actor, after the model container is ready.
private struct AppRootView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var repositories: RepositoryContainer?

    var body: some View {
        ContentView()
            .environment(\.repositories, repositories)
            .onAppear {
                guard repositories == nil else { return }
                repositories = RepositoryContainer(modelContext: modelContext)
            }
    }
}
