import SwiftUI

// Root tab container that replaces ContentView as the app's entry point.
// Adds Home Screen Quick Action routing via ShortcutRouter while preserving
// all existing ContentView behaviour (onboarding, appearance, new-trip sheet).
struct RootContainerView: View {
    @Environment(ProfileViewModel.self) private var profile
    @Environment(ShortcutRouter.self) private var router

    @State private var selectedTab = 0
    @State private var showOnboarding = !UserDefaults.standard.bool(forKey: UserDefaults.onboardingCompletedKey)
    @State private var showNewTripAfterOnboarding = false
    @State private var showNewTripFromShortcut = false

    // Tab index constants
    private enum Tab {
        static let trips   = 0
        static let packing = 1
        static let tasks   = 2
        static let profile = 3
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem { Label("Trips", systemImage: "suitcase.fill") }
                .tag(Tab.trips)
            PackingTabView()
                .tabItem { Label("Packing", systemImage: "checklist") }
                .tag(Tab.packing)
            TasksTabView()
                .tabItem { Label("Tasks", systemImage: "calendar.badge.clock") }
                .tag(Tab.tasks)
            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.fill") }
                .tag(Tab.profile)
        }
        .preferredColorScheme(preferredScheme)
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView { createFirstTrip in
                showOnboarding = false
                if createFirstTrip {
                    showNewTripAfterOnboarding = true
                }
            }
        }
        .sheet(isPresented: $showNewTripAfterOnboarding) {
            NewTripView()
        }
        .sheet(isPresented: $showNewTripFromShortcut) {
            NewTripView()
        }
        // Route on first appear (handles cold-launch shortcut already in router)
        .onAppear { applyPendingShortcut() }
        // Route when a shortcut fires while app is in memory
        .onChange(of: router.pendingAction) { _, action in
            guard action != nil else { return }
            applyPendingShortcut()
        }
    }

    private func applyPendingShortcut() {
        guard let action = router.consumeAction() else { return }
        switch action {
        case .newTrip:
            selectedTab = Tab.trips
            showNewTripFromShortcut = true
        case .nextTrip:
            selectedTab = Tab.trips
        case .masterList:
            selectedTab = Tab.profile
        case .profile:
            selectedTab = Tab.profile
        }
    }

    private var preferredScheme: ColorScheme? {
        switch profile.appearance {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}
