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

private struct AppRootView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var repositories: RepositoryContainer?
    @State private var splashDone = false
    @State private var splashMinElapsed = false

    var showMain: Bool { splashDone && splashMinElapsed }

    var body: some View {
        ZStack {
            if showMain {
                ContentView()
                    .environment(\.repositories, repositories)
                    .transition(.opacity)
            } else {
                SplashView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: showMain)
        .onAppear {
            guard repositories == nil else { return }
            let repos = RepositoryContainer(modelContext: modelContext)
            repositories = repos
            Task {
                await ImportService(repository: repos.masterItems).seedIfNeeded()
                splashDone = true
            }
            Task {
                try? await Task.sleep(for: .seconds(1.5))
                splashMinElapsed = true
            }
        }
    }
}

private struct SplashView: View {
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            Image("SplashDonkey")
                .resizable()
                .scaledToFit()
                .padding(40)
        }
        .opacity(opacity)
        .onAppear {
            withAnimation(.easeIn(duration: 0.6)) {
                opacity = 1
            }
        }
    }
}
