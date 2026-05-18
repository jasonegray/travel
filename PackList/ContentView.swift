import SwiftUI

struct ContentView: View {
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
    }
}
