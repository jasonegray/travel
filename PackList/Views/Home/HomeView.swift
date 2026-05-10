import SwiftUI

struct HomeView: View {
    @State private var vm = HomeViewModel()
    @State private var showNewTrip = false
    @Environment(\.repositories) private var repositories

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text(greeting)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)

                    if let trip = vm.activeTrip {
                        NavigationLink {
                            TripDetailView(trip: trip)
                        } label: {
                            ActiveTripCard(
                                trip: trip,
                                packingProgress: vm.packingProgress,
                                prepProgress: vm.prepProgress
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal)

                        if !vm.bagsSummary.isEmpty {
                            BagsProgressView(summary: vm.bagsSummary)
                                .padding(.horizontal)
                        }

                        if !vm.upNextTasks.isEmpty {
                            UpNextView(
                                tasks: vm.upNextTasks,
                                departure: trip.departureDate,
                                deadlineFor: vm.recommendedByDate
                            )
                            .padding(.horizontal)
                        }
                    } else if !vm.isLoading {
                        EmptyHomeState(onNewTrip: { showNewTrip = true })
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal)
                    }

                    Spacer(minLength: 24)
                }
                .padding(.top, 8)
            }
            .navigationTitle("Trips")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showNewTrip = true }) {
                        Image(systemName: "plus")
                    }
                }
                #if DEBUG
                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .destructive) {
                        guard let repos = repositories else { return }
                        Task { await vm.deleteAllTrips(sessions: repos.tripSessions) }
                    } label: {
                        Image(systemName: "trash")
                    }
                }
                #endif
            }
            .sheet(isPresented: $showNewTrip) {
                NewTripView()
            }
            .onChange(of: showNewTrip) { _, isShowing in
                guard !isShowing, let repos = repositories else { return }
                Task { await vm.load(sessions: repos.tripSessions, tripItems: repos.tripItems) }
            }
            .task(id: repositories != nil) {
                guard let repos = repositories else { return }
                await vm.load(sessions: repos.tripSessions, tripItems: repos.tripItems)
            }
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<21: return "Good evening"
        default:     return "Good night"
        }
    }
}

// MARK: - Active Trip Card

struct ActiveTripCard: View {
    let trip: TripSession
    let packingProgress: (completed: Int, total: Int)
    let prepProgress: (completed: Int, total: Int)

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(trip.name)
                        .font(.headline)
                    Text(trip.destination)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text(trip.departureDate, format: .dateTime.month(.abbreviated).day().year())
                        .font(.subheadline)
                    Text(daysAwayLabel)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Divider()

            ProgressRow(
                label: "Packing",
                completed: packingProgress.completed,
                total: packingProgress.total,
                unit: "items",
                color: .accentColor
            )

            ProgressRow(
                label: "Prep tasks",
                completed: prepProgress.completed,
                total: prepProgress.total,
                unit: "tasks",
                color: .orange
            )
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var daysAwayLabel: String {
        let cal = Calendar.current
        let days = cal.dateComponents(
            [.day],
            from: cal.startOfDay(for: .now),
            to: cal.startOfDay(for: trip.departureDate)
        ).day ?? 0
        switch days {
        case ..<0: return "In progress"
        case 0:    return "Today"
        case 1:    return "Tomorrow"
        default:   return "\(days) days away"
        }
    }
}

// MARK: - Bags Progress

struct BagsProgressView: View {
    let summary: [(location: PackingLocation, packed: Int, total: Int)]

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Bags")
                .font(.headline)

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(summary, id: \.location) { entry in
                    BagCard(
                        location: entry.location,
                        packed: entry.packed,
                        total: entry.total
                    )
                }
            }
        }
    }
}

private struct BagCard: View {
    let location: PackingLocation
    let packed: Int
    let total: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(location.displayName)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(packed)")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("/\(total)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ThinProgressBar(
                fraction: total > 0 ? Double(packed) / Double(total) : 0
            )
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Up Next

struct UpNextView: View {
    let tasks: [TripItem]
    let departure: Date
    let deadlineFor: (TaskTiming?, Date) -> Date

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Up next")
                .font(.headline)

            VStack(spacing: 0) {
                ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
                    UpNextRow(
                        task: task,
                        deadline: deadlineFor(task.recommendedTiming, departure)
                    )
                    if index < tasks.count - 1 {
                        Divider()
                            .padding(.leading, 16)
                    }
                }
            }
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}

private struct UpNextRow: View {
    let task: TripItem
    let deadline: Date

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(task.name)
                    .font(.subheadline)
                Text("by \(deadline.formatted(.dateTime.month(.abbreviated).day()))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "circle")
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Empty State

private struct EmptyHomeState: View {
    let onNewTrip: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 60)

            Image(systemName: "suitcase")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)

            VStack(spacing: 6) {
                Text("No trips planned")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Create a trip to generate your packing list.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button("New Trip", action: onNewTrip)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

            Spacer(minLength: 60)
        }
    }
}

// MARK: - Shared: Progress components

struct ProgressRow: View {
    let label: String
    let completed: Int
    let total: Int
    let unit: String
    var color: Color = .accentColor

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(label)
                    .font(.caption)
                    .fontWeight(.medium)
                Spacer()
                Text("\(completed)/\(total) \(unit)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ThinProgressBar(
                fraction: total > 0 ? Double(completed) / Double(total) : 0,
                color: color
            )
        }
    }
}

struct ThinProgressBar: View {
    let fraction: Double
    var color: Color = .accentColor

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(.systemFill))
                if fraction > 0 {
                    Capsule()
                        .fill(color)
                        .frame(width: geo.size.width * min(fraction, 1.0))
                }
            }
        }
        .frame(height: 6)
    }
}

// MARK: - PackingLocation display

extension PackingLocation {
    var displayName: String {
        switch self {
        case .backpack:          return "Backpack"
        case .carryOn:           return "Carry-On"
        case .techPouch:         return "Tech Pouch"
        case .toiletryBag:       return "Toiletry Bag"
        case .passportWallet:    return "Wallet"
        case .golfBag:           return "Golf Bag"
        case .flightAccessPouch: return "Flight Pouch"
        case .checkedBag:        return "Checked Bag"
        case .wearing:           return "Wearing"
        case .pocket:            return "Pocket"
        }
    }

    var sortOrder: Int {
        switch self {
        case .wearing:           return 0
        case .pocket:            return 1
        case .backpack:          return 2
        case .flightAccessPouch: return 3
        case .carryOn:           return 4
        case .techPouch:         return 5
        case .toiletryBag:       return 6
        case .passportWallet:    return 7
        case .golfBag:           return 8
        case .checkedBag:        return 9
        }
    }
}

// MARK: - TaskTiming sort

extension TaskTiming {
    var sortOrdinal: Int {
        switch self {
        case .weekBefore:       return 0
        case .threeDaysBefore:  return 1
        case .dayBefore:        return 2
        case .morningOf:        return 3
        case .atAirport:        return 4
        case .onPlane:          return 5
        case .uponArrival:      return 6
        }
    }
}
