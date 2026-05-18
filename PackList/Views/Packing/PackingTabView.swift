import SwiftUI
import os.log

private let logger = Logger(subsystem: "com.packlist", category: "PackingTabView")

struct PackingTabView: View {
    @State private var activeTrip: TripSession?
    @State private var isLoading = true
    @State private var showNewTrip = false
    @Environment(\.repositories) private var repositories

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                } else if let trip = activeTrip {
                    TripDetailView(trip: trip, initialTab: .packing, showTabPicker: false, onDeleted: { Task { await loadTrip() } })
                        .id(trip.id)
                } else {
                    NoActiveTripState(
                        systemImage: "checklist",
                        message: "Create a trip to start packing.",
                        onNewTrip: { showNewTrip = true }
                    )
                    .navigationTitle("Packing")
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
        do {
            let active = try await repos.tripSessions.fetch(status: .active)
            let planning = try await repos.tripSessions.fetch(status: .planning)
            activeTrip = active.first ?? planning.first
        } catch {
            logger.error("PackingTabView load failed: \(error)")
        }
        isLoading = false
    }
}
