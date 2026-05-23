import SwiftUI

struct ContentView: View {
    @Environment(ProfileViewModel.self) private var profile

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Trips", systemImage: "suitcase.fill") }
            PackingTabView()
                .tabItem { Label("Packing", systemImage: "checklist") }
            TasksTabView()
                .tabItem { Label("Tasks", systemImage: "calendar.badge.clock") }
            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.fill") }
        }
        .preferredColorScheme(preferredScheme)
    }

    private var preferredScheme: ColorScheme? {
        switch profile.appearance {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
