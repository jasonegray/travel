import SwiftUI
import os.log

private let logger = Logger(subsystem: "com.packlist", category: "TasksTabView")

struct TasksTabView: View {
    @State private var activeTrip: TripSession?
    @State private var isLoading = true
    @State private var loadFailed = false
    @State private var showNewTrip = false
    @Environment(\.repositories) private var repositories

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                } else if loadFailed {
                    LoadErrorState(
                        message: "Your prep tasks couldn't be loaded.",
                        onRetry: { Task { await loadTrip() } }
                    )
                    .navigationTitle("Tasks")
                } else if let trip = activeTrip {
                    TripDetailView(trip: trip, initialTab: .prepTasks, showTabPicker: false, onDismiss: { Task { await loadTrip() } })
                        .id(trip.id)
                } else {
                    NoActiveTripState(
                        systemImage: "calendar.badge.clock",
                        message: "Create a trip to see prep tasks.",
                        onNewTrip: { showNewTrip = true }
                    )
                    .navigationTitle("Tasks")
                }
            }
        }
        .sheet(isPresented: $showNewTrip) {
            NewTripView()
        }
        .onChange(of: showNewTrip) { _, isShowing in
            guard !isShowing else { return }
            Task { await loadTrip() }
        }
        .task(id: repositories != nil) {
            await loadTrip()
        }
    }

    private func loadTrip() async {
        guard let repos = repositories else { return }
        isLoading = true
        loadFailed = false
        do {
            let active = try await repos.tripSessions.fetch(status: .active)
            let planning = try await repos.tripSessions.fetch(status: .planning)
            activeTrip = active.first ?? planning.first
        } catch {
            logger.error("TasksTabView load failed: \(error)")
            loadFailed = true
        }
        isLoading = false
    }
}

// MARK: - Shared empty state

struct NoActiveTripState: View {
    let systemImage: String
    let message: String
    let onNewTrip: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: systemImage)
                .font(.system(size: 56))
                .foregroundStyle(.secondary)

            VStack(spacing: 6) {
                Text("No active trip")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button("New Trip", action: onNewTrip)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

            Spacer()
        }
        .padding(.horizontal)
    }
}
