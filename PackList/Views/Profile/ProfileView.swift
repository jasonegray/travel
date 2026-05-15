import SwiftUI

struct ProfileView: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        MasterListView()
                    } label: {
                        Label("Master List", systemImage: "list.bullet")
                    }
                }
            }
            .navigationTitle("Profile")
        }
    }
}
