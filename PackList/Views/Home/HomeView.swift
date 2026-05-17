import SwiftUI

struct HomeView: View {
    @State private var vm = HomeViewModel()
    @State private var showNewTrip = false
    @State private var navTarget: TripNavTarget?
    @Environment(\.repositories) private var repositories

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text(greeting)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)

                    if let trip = vm.heroTrip {
                        // MARK: Hero card
                        ActiveTripCard(
                            trip: trip,
                            packingProgress: vm.packingProgress,
                            prepProgress: vm.prepProgress,
                            onPackingTap: {
                                navTarget = TripNavTarget(tripId: trip.id, tab: .packing)
                            },
                            onPrepTasksTap: {
                                navTarget = TripNavTarget(tripId: trip.id, tab: .prepTasks)
                            }
                        )
                        .padding(.horizontal)

                        // MARK: Bags
                        if !vm.bagsSummary.isEmpty {
                            BagsProgressView(
                                summary: vm.bagsSummary,
                                onBagTap: { location in
                                    navTarget = TripNavTarget(tripId: trip.id, tab: .packing, location: location)
                                }
                            )
                            .padding(.horizontal)
                        }

                        // MARK: Up next
                        if !vm.upNextTasks.isEmpty {
                            UpNextView(
                                tasks: vm.upNextTasks,
                                departure: trip.departureDate,
                                deadlineFor: vm.recommendedByDate,
                                onComplete: { item in
                                    withAnimation(.easeInOut(duration: 0.2)) { vm.toggle(item: item) }
                                    guard let repos = repositories else { return }
                                    Task { await vm.save(item: item, repository: repos.tripItems) }
                                }
                            )
                            .padding(.horizontal)
                        }

                        // MARK: Other upcoming trips strip
                        if !vm.otherUpcomingTrips.isEmpty {
                            OtherTripsStrip(
                                trips: vm.otherUpcomingTrips,
                                progressMap: vm.tripProgressMap,
                                onTap: { other in
                                    navTarget = TripNavTarget(tripId: other.id)
                                }
                            )
                        }

                        // MARK: Completed trips
                        if !vm.completedTrips.isEmpty {
                            CompletedTripsSection(
                                trips: vm.completedTrips,
                                progressMap: vm.tripProgressMap,
                                onTap: { completed in
                                    navTarget = TripNavTarget(tripId: completed.id)
                                }
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
            .onAppear {
                guard let repos = repositories else { return }
                Task { await vm.load(sessions: repos.tripSessions, tripItems: repos.tripItems) }
            }
            .task(id: repositories != nil) {
                guard let repos = repositories else { return }
                await vm.load(sessions: repos.tripSessions, tripItems: repos.tripItems)
            }
            .navigationDestination(item: $navTarget) { target in
                if let trip = findTrip(id: target.tripId) {
                    TripDetailView(
                        trip: trip,
                        initialTab: target.tab,
                        initialPackingLocation: target.location
                    )
                }
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

    private func findTrip(id: UUID) -> TripSession? {
        if vm.heroTrip?.id == id { return vm.heroTrip }
        return (vm.otherUpcomingTrips + vm.completedTrips).first { $0.id == id }
    }
}

// MARK: - Navigation target

private struct TripNavTarget: Hashable {
    let tripId: UUID
    var tab: TripDetailView.Tab = .packing
    var location: PackingLocation? = nil
}

// MARK: - Other trips strip

private struct OtherTripsStrip: View {
    let trips: [TripSession]
    let progressMap: [UUID: (packed: Int, total: Int)]
    let onTap: (TripSession) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Other trips")
                .font(.headline)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(trips) { trip in
                        Button { onTap(trip) } label: {
                            TripStripCard(
                                trip: trip,
                                progress: progressMap[trip.id]
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

private struct TripStripCard: View {
    let trip: TripSession
    let progress: (packed: Int, total: Int)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TripStatusBadge(status: trip.status)

            Text(trip.name)
                .font(.subheadline)
                .fontWeight(.semibold)
                .lineLimit(1)

            Text(trip.destination)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(trip.departureDate, format: .dateTime.month(.abbreviated).day().year())
                .font(.caption)
                .foregroundStyle(.secondary)

            if let p = progress, p.total > 0 {
                VStack(alignment: .leading, spacing: 3) {
                    ThinProgressBar(
                        fraction: Double(p.packed) / Double(p.total),
                        color: p.packed == p.total ? .green : .accentColor
                    )
                    Text("\(p.packed)/\(p.total) packed")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: 160)
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Completed trips section

private struct CompletedTripsSection: View {
    let trips: [TripSession]
    let progressMap: [UUID: (packed: Int, total: Int)]
    let onTap: (TripSession) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Completed")
                .font(.headline)

            VStack(spacing: 8) {
                ForEach(trips) { trip in
                    Button { onTap(trip) } label: {
                        CompletedTripCard(trip: trip, progress: progressMap[trip.id])
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct CompletedTripCard: View {
    let trip: TripSession
    let progress: (packed: Int, total: Int)?

    private var dateRange: String {
        "\(trip.departureDate.formatted(.dateTime.month(.abbreviated).day())) – \(trip.returnDate.formatted(.dateTime.month(.abbreviated).day().year()))"
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(trip.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Text(trip.destination)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(dateRange)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.title3)
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Status badge

struct TripStatusBadge: View {
    let status: TripStatus

    var body: some View {
        Text(status.displayName)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(status.badgeColor.opacity(0.15))
            .foregroundStyle(status.badgeColor)
            .clipShape(Capsule())
    }
}

private extension TripStatus {
    var badgeColor: Color {
        switch self {
        case .planning:  return .blue
        case .active:    return .green
        case .completed: return .secondary
        case .archived:  return .secondary
        }
    }
}

// MARK: - Active Trip Card

struct ActiveTripCard: View {
    let trip: TripSession
    let packingProgress: (completed: Int, total: Int)
    let prepProgress: (completed: Int, total: Int)
    var onPackingTap: (() -> Void)? = nil
    var onPrepTasksTap: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button { onPackingTap?() } label: {
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
                .padding([.top, .horizontal], 16)
                .padding(.bottom, 16)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Divider()
                .padding(.horizontal)

            if isReadyToGo {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Good to go")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.green)
                        Text("All packed · All tasks done")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
                .transition(.opacity)
            } else {
                Button { onPackingTap?() } label: {
                    ProgressRow(
                        label: "Packing",
                        completed: packingProgress.completed,
                        total: packingProgress.total,
                        unit: "items",
                        color: urgencyColor(daysUntilDeparture: daysAway, packingFraction: packingFraction),
                        shouldPulse: daysAway == 0 && packingFraction < 1.0
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button { onPrepTasksTap?() } label: {
                    ProgressRow(
                        label: "Prep tasks",
                        completed: prepProgress.completed,
                        total: prepProgress.total,
                        unit: "tasks",
                        color: urgencyColor(daysUntilDeparture: daysAway, packingFraction: prepFraction)
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 16)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .animation(.easeInOut(duration: 0.2), value: isReadyToGo)
    }

    private var daysAway: Int { daysUntilDeparture(from: trip.departureDate) }

    private var daysAwayLabel: String {
        switch daysAway {
        case ..<0: return "In progress"
        case 0:    return "Today"
        case 1:    return "Tomorrow"
        default:   return "\(daysAway) days away"
        }
    }

    private var packingFraction: Double {
        packingProgress.total > 0
            ? Double(packingProgress.completed) / Double(packingProgress.total)
            : 1.0
    }

    private var prepFraction: Double {
        prepProgress.total > 0
            ? Double(prepProgress.completed) / Double(prepProgress.total)
            : 1.0
    }

    private var isReadyToGo: Bool {
        packingProgress.total > 0 && prepProgress.total > 0 &&
        packingProgress.completed == packingProgress.total &&
        prepProgress.completed == prepProgress.total
    }
}

// MARK: - Bags Progress

struct BagsProgressView: View {
    let summary: [(location: PackingLocation, packed: Int, total: Int)]
    var onBagTap: ((PackingLocation) -> Void)? = nil

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
                    Button {
                        onBagTap?(entry.location)
                    } label: {
                        BagCard(
                            location: entry.location,
                            packed: entry.packed,
                            total: entry.total
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct BagCard: View {
    let location: PackingLocation
    let packed: Int
    let total: Int

    private var isDone: Bool { total > 0 && packed == total }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(location.displayName)
                .font(.caption)
                .foregroundStyle(.secondary)

            if isDone {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(packed)")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("/\(total)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            ThinProgressBar(
                fraction: total > 0 ? Double(packed) / Double(total) : 0,
                color: isDone ? .green : .accentColor
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
    let onComplete: (TripItem) -> Void

    @State private var completingIDs: Set<UUID> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Up next")
                .font(.headline)

            VStack(spacing: 0) {
                ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
                    UpNextRow(
                        task: task,
                        deadline: deadlineFor(task.recommendedTiming, departure),
                        isCompleting: completingIDs.contains(task.id),
                        onTap: {
                            guard !completingIDs.contains(task.id) else { return }
                            withAnimation(.easeInOut(duration: 0.2)) {
                                completingIDs.insert(task.id)
                            }
                            Task {
                                try? await Task.sleep(for: .milliseconds(400))
                                onComplete(task)
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    completingIDs.remove(task.id)
                                }
                            }
                        }
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
    let isCompleting: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(task.name)
                        .font(.subheadline)
                        .strikethrough(isCompleting, color: .secondary)
                        .foregroundStyle(isCompleting ? .secondary : .primary)
                    Text("by \(deadline.formatted(.dateTime.month(.abbreviated).day()))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: isCompleting ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isCompleting ? Color.accentColor : Color.secondary)
                    .animation(.easeInOut(duration: 0.2), value: isCompleting)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
    var shouldPulse: Bool = false

    private var isDone: Bool { total > 0 && completed == total }

    var body: some View {
        if isDone {
            HStack {
                Text(label)
                    .font(.caption)
                    .fontWeight(.medium)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                    Text(unit == "items" ? "All packed" : "All done")
                }
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.green)
            }
        } else {
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
                    color: color,
                    shouldPulse: shouldPulse
                )
            }
        }
    }
}

struct ThinProgressBar: View {
    let fraction: Double
    var color: Color = .accentColor
    var shouldPulse: Bool = false

    @State private var pulsing = false

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(.systemFill))
                if fraction > 0 {
                    Capsule()
                        .fill(color)
                        .frame(width: geo.size.width * min(fraction, 1.0))
                        .opacity(pulsing ? 0.45 : 1.0)
                }
            }
        }
        .frame(height: 6)
        .onAppear {
            guard shouldPulse else { return }
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                pulsing = true
            }
        }
        .onChange(of: shouldPulse) { _, newValue in
            if newValue {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    pulsing = true
                }
            } else {
                withAnimation(.default) { pulsing = false }
            }
        }
    }
}

func daysUntilDeparture(from departureDate: Date) -> Int {
    let cal = Calendar.current
    return cal.dateComponents(
        [.day],
        from: cal.startOfDay(for: .now),
        to: cal.startOfDay(for: departureDate)
    ).day ?? 0
}

func urgencyColor(daysUntilDeparture: Int, packingFraction: Double) -> Color {
    switch daysUntilDeparture {
    case ..<0:   return .blue
    case 0:      return packingFraction < 1.0 ? .red : .blue
    case 1...2:  return packingFraction < 0.80 ? .red : .blue
    case 3...6:  return packingFraction < 0.50 ? .orange : .blue
    default:     return .blue
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
