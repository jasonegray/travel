import SwiftUI
import SwiftData
import os.log

private let logger = Logger(subsystem: "com.packlist", category: "PackListApp")

// PackList — travel packing list manager
@MainActor
@main
struct PackListApp: App {
    static let storeWipedKey = "packListStoreWasReset"

    private let container: ModelContainer
    private let repositories: RepositoryContainer
    private let profile = ProfileViewModel()
    @State private var showLaunchScreen = true
    @AppStorage("packListStoreWasReset") private var showStoreWipeAlert = false

    init() {
        let c = Self.makeContainer()
        container = c
        repositories = RepositoryContainer(modelContext: c.mainContext)
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .environment(\.repositories, repositories)
                    .environment(profile)

                if showLaunchScreen {
                    LaunchView()
                        .transition(.opacity)
                }
            }
            .task {
                // fade-in 0.3s + hold 1.2s = 1.5s before fade-out begins; total visible ~2.0s
                try? await Task.sleep(for: .milliseconds(1500))
                withAnimation(.easeInOut(duration: 0.5)) {
                    showLaunchScreen = false
                }
            }
            .alert("Your data was reset", isPresented: $showStoreWipeAlert) {
                Button("OK") {
                    showStoreWipeAlert = false
                }
            } message: {
                Text("A database error required PackList to start fresh. Your previous trips could not be recovered.")
            }
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
            // Reset seed flag so ImportService re-seeds into the fresh store
            UserDefaults.standard.removeObject(forKey: ImportService.seededKey)
            // Flag so ContentView shows a one-time data-loss alert on next launch
            UserDefaults.standard.set(true, forKey: PackListApp.storeWipedKey)
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
