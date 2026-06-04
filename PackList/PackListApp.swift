import SwiftUI
import SwiftData
import UIKit
import os.log

private let logger = Logger(subsystem: "com.packlist", category: "PackListApp")

// MARK: - App delegate (shortcut handling)

final class AppDelegate: NSObject, UIApplicationDelegate {
    // Cold-launch: shortcut arrives in launchOptions before the SwiftUI tree is ready.
    // Store it here; PackListApp wires it to ShortcutRouter once the scene is running.
    private(set) var coldLaunchShortcutItem: UIApplicationShortcutItem?

    // Called when app is already running and user selects a quick action.
    var onShortcutAction: ((UIApplicationShortcutItem) -> Void)?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        coldLaunchShortcutItem = launchOptions?[.shortcutItem] as? UIApplicationShortcutItem
        return true
    }

    func application(
        _ application: UIApplication,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        onShortcutAction?(shortcutItem)
        completionHandler(true)
    }
}

// MARK: - App entry point

// PackList — travel packing list manager
@MainActor
@main
struct PackListApp: App {
    static let storeWipedKey = "packListStoreWasReset"

    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    private let container: ModelContainer
    private let repositories: RepositoryContainer
    private let profile = ProfileViewModel()
    private let shortcutRouter = ShortcutRouter()

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
                RootContainerView()
                    .environment(\.repositories, repositories)
                    .environment(profile)
                    .environment(shortcutRouter)

                if showLaunchScreen {
                    LaunchView()
                        .transition(.opacity)
                }
            }
            .task {
                // Wire AppDelegate → router for app-already-running shortcut callbacks.
                appDelegate.onShortcutAction = { [shortcutRouter] item in
                    Task { @MainActor in shortcutRouter.handle(item) }
                }
                // Flush any shortcut that arrived during cold launch.
                if let item = appDelegate.coldLaunchShortcutItem {
                    shortcutRouter.handle(item)
                }

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
            // Flag so RootContainerView shows a one-time data-loss alert on next launch
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
