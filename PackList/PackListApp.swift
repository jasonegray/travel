import SwiftUI
import SwiftData

@main
struct PackListApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
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
