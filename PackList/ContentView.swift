import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Home", systemImage: "house.fill") }
            Text("Trips")
                .tabItem { Label("Trips", systemImage: "suitcase.fill") }
            Text("Master List")
                .tabItem { Label("Master List", systemImage: "list.bullet") }
            Text("Profile")
                .tabItem { Label("Profile", systemImage: "person.fill") }
        }
    }
}
