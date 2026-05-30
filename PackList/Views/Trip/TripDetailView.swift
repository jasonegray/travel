import SwiftUI

// MARK: - Root

struct TripDetailView: View {
    @State private var vm: TripDetailViewModel
    @State private var infoVM: TripInfoViewModel
    @State private var selectedTab: Tab = .packing
    @State private var showDeleteConfirmation = false
    @State private var showAddCustomItem = false
    @State private var showAddCustomTask = false
    @State private var showEditTrip = false
    @State private var showTripSettings = false
    @State private var showCloneWizard = false
    let initialPackingLocation: PackingLocation?
    let showTabPicker: Bool
    let onDismiss: (() -> Void)?
    @Environment(\.repositories) private var repositories

    enum Tab { case packing, prepTasks, info }

    init(trip: TripSession, initialTab: Tab = .packing, initialPackingLocation: PackingLocation? = nil, showTabPicker: Bool = true, onDismiss: (() -> Void)? = nil) {
        _vm = State(wrappedValue: TripDetailViewModel(trip: trip))
        _infoVM = State(wrappedValue: TripInfoViewModel(trip: trip))
        _selectedTab = State(wrappedValue: initialTab)
        self.initialPackingLocation = initialPackingLocation
        self.showTabPicker = showTabPicker
        self.onDismiss = onDismiss
    }

    var body: some View {
        VStack(spacing: 0) {
            if vm.trip.status == .archived {
                ArchivedBanner()
                Divider()
            } else if vm.trip.status == .completed {
                TripCompletedBanner(manuallyCompletedAt: vm.trip.manuallyCompletedAt)
                Divider()
            }

            if showTabPicker {
                Picker("", selection: $selectedTab) {
                    Text("Packing").tag(Tab.packing)
                    Text("Prep tasks").tag(Tab.prepTasks)
                    Text("Info").tag(Tab.info)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 10)

                Divider()
            }

            switch selectedTab {
            case .packing:   PackingTab(vm: vm, initialLocation: initialPackingLocation)
            case .prepTasks: PrepTab(vm: vm, onAddTask: { showAddCustomTask = true })
            case .info:      TripInfoView(vm: infoVM)
            }
        }
        .navigationTitle(vm.trip.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(vm.trip.name)
                    .font(.headline)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if selectedTab == .packing && vm.trip.status != .completed {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddCustomItem = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityIdentifier("addItemButton")
                }
            }
            if selectedTab == .prepTasks && vm.trip.status != .completed {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddCustomTask = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if vm.trip.status == .archived {
                        Button {
                            Task {
                                guard let repos = repositories else { return }
                                await vm.unarchiveTrip(sessions: repos.tripSessions)
                                // Do not pop — user stays on detail screen, banner updates in place
                            }
                        } label: {
                            Label("Unarchive", systemImage: "archivebox")
                        }
                        .accessibilityIdentifier("unarchive_menu_button")
                    } else {
                        Button {
                            showEditTrip = true
                        } label: {
                            Label("Edit Trip", systemImage: "pencil")
                        }
                        .accessibilityIdentifier("edit_trip_menu_button")

                        if vm.trip.status == .completed {
                            Button {
                                Task {
                                    guard let repos = repositories else { return }
                                    await vm.archiveTrip(sessions: repos.tripSessions)
                                    onDismiss?()
                                }
                            } label: {
                                Label("Archive Trip", systemImage: "archivebox")
                            }
                            .accessibilityIdentifier("archive_menu_button")
                        }
                        if vm.trip.status != .completed {
                            Button {
                                Task {
                                    guard let repos = repositories else { return }
                                    await vm.markCompleted(sessions: repos.tripSessions)
                                }
                            } label: {
                                Label("Mark as Completed", systemImage: "checkmark.circle")
                            }
                        }
                    }
                    if vm.trip.status != .archived {
                        Button {
                            showTripSettings = true
                        } label: {
                            Label("Trip Settings", systemImage: "slider.horizontal.3")
                        }
                    }
                    Button {
                        showCloneWizard = true
                    } label: {
                        Label("Duplicate Trip", systemImage: "doc.on.doc")
                    }
                    .accessibilityIdentifier("duplicate_trip_button")
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete Trip", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityIdentifier("trip_detail_menu")
            }
        }
        .sheet(isPresented: $showAddCustomItem) {
            AddCustomItemView { name, category, location, quantity in
                Task { await vm.addCustomItem(name: name, category: category, location: location, quantity: quantity) }
            }
        }
        .sheet(isPresented: $showAddCustomTask) {
            AddCustomTaskView { name, timing in
                Task { await vm.addCustomTask(name: name, timing: timing) }
            }
        }
        .sheet(isPresented: $showEditTrip) {
            EditTripMetadataView(trip: vm.trip) { name, destination, departure, returnDate in
                Task {
                    guard let repos = repositories else { return }
                    await vm.editTrip(
                        name: name,
                        destination: destination,
                        departureDate: departure,
                        returnDate: returnDate,
                        sessions: repos.tripSessions
                    )
                }
            }
        }
        .sheet(isPresented: $showTripSettings) {
            TripSettingsView(trip: vm.trip) { newItems in
                vm.setItems(newItems)
            }
        }
        .alert("Delete \"\(vm.trip.name)\"?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                Task {
                    guard let repos = repositories else { return }
                    // Navigate away first so SwiftUI stops rendering this view before
                    // the TripSession is tombstoned — otherwise the pop animation accesses
                    // deleted object properties and causes EXC_BAD_ACCESS.
                    onDismiss?()
                    await vm.deleteTrip(sessions: repos.tripSessions)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone.")
        }
        .sheet(isPresented: $showCloneWizard) {
            NewTripView(prefilledWith: NewTripViewModel(cloning: vm.trip))
        }
        .task(id: repositories != nil) {
            guard let repos = repositories else { return }
            await vm.load(repository: repos.tripItems)
            infoVM.loadRepository(repos.tripInfo)
        }
    }
}

// MARK: - Packing tab

private enum PackingMode { case category, bags }

private struct PackingTab: View {
    let vm: TripDetailViewModel
    let initialLocation: PackingLocation?
    @State private var mode: PackingMode
    @State private var selectedCategoryIndex: Int = 0
    @State private var selectedBagIndex: Int = 0
    @State private var editingItem: TripItem? = nil

    init(vm: TripDetailViewModel, initialLocation: PackingLocation? = nil) {
        self.vm = vm
        self.initialLocation = initialLocation
        _mode = State(wrappedValue: initialLocation != nil ? .bags : .category)
    }

    var body: some View {
        VStack(spacing: 0) {
            PackingHeaderStrip(
                completed: vm.completedPacking,
                total: vm.totalPacking,
                departureDate: vm.trip.departureDate,
                mode: $mode
            )

            Divider()

            switch mode {
            case .category:
                TabView(selection: $selectedCategoryIndex) {
                    ForEach(Array(vm.categoryGroups.enumerated()), id: \.offset) { index, group in
                        CategoryPageView(
                            group: group,
                            onToggle: { item in
                                withAnimation(.easeInOut(duration: 0.2)) { vm.toggle(item: item) }
                                Task { await vm.save(item: item) }
                            },
                            onDelete: { item in
                                Task { await vm.deleteCustomItem(item) }
                            },
                            onEdit: { item in
                                guard !vm.trip.isArchived else { return }
                                editingItem = item
                            }
                        )
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))
                .animation(.easeInOut(duration: 0.2), value: vm.completedPacking)

            case .bags:
                TabView(selection: $selectedBagIndex) {
                    ForEach(Array(vm.packingGroups.enumerated()), id: \.offset) { index, group in
                        BagPageView(
                            group: group,
                            onToggle: { item in
                                withAnimation(.easeInOut(duration: 0.2)) { vm.toggle(item: item) }
                                Task { await vm.save(item: item) }
                            },
                            onDelete: { item in
                                Task { await vm.deleteCustomItem(item) }
                            },
                            onEdit: { item in
                                guard !vm.trip.isArchived else { return }
                                editingItem = item
                            }
                        )
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))
                .animation(.easeInOut(duration: 0.2), value: vm.completedPacking)
                .task(id: vm.packingGroups.count) {
                    guard let location = initialLocation, !vm.packingGroups.isEmpty else { return }
                    if let index = vm.packingGroups.firstIndex(where: { $0.location == location }) {
                        selectedBagIndex = index
                    }
                }
            }
        }
        .sheet(item: $editingItem) { item in
            EditPackingItemView(item: item) { quantity, notes in
                Task { await vm.editItem(item, quantity: quantity, notes: notes) }
            }
        }
    }

}

// MARK: - Header strip

private struct PackingHeaderStrip: View {
    let completed: Int
    let total: Int
    let departureDate: Date
    @Binding var mode: PackingMode

    private var fraction: Double { total > 0 ? Double(completed) / Double(total) : 1.0 }
    private var daysAway: Int { daysUntilDeparture(from: departureDate) }

    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                ThinProgressBar(
                    fraction: fraction,
                    color: urgencyColor(daysUntilDeparture: daysAway, packingFraction: fraction),
                    shouldPulse: daysAway == 0 && fraction < 1.0
                )
                .frame(maxWidth: .infinity)

                Text("\(completed)/\(total)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize()
            }

            Picker("", selection: $mode) {
                Text("Category").tag(PackingMode.category)
                Text("Bags").tag(PackingMode.bags)
            }
            .pickerStyle(.segmented)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color(.systemBackground))
    }
}

// MARK: - Category page

private struct CategoryPageView: View {
    let group: (category: ItemCategory, items: [TripItem])
    let onToggle: (TripItem) -> Void
    let onDelete: (TripItem) -> Void
    let onEdit: (TripItem) -> Void

    private var remaining: Int { group.items.filter { $0.completedAt == nil }.count }
    private var allPacked: Bool { remaining == 0 }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: group.category.sfSymbol)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text(group.category.displayName)
                    .font(.headline)
                Spacer()
                if allPacked {
                    Text("All packed ✓")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.green)
                } else {
                    Text("\(remaining) remaining")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.red)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)

            Divider()

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(group.items) { item in
                        PackingRow(item: item, onToggle: { onToggle(item) }, onDelete: { onDelete(item) }, onEdit: { onEdit(item) })
                            .padding(.horizontal)
                            .padding(.vertical, 2)
                        if item.id != group.items.last?.id {
                            Divider().padding(.leading, 60)
                        }
                    }
                    Spacer(minLength: 60)
                }
            }
        }
    }
}

// MARK: - Bag page

private struct BagPageView: View {
    let group: (location: PackingLocation, items: [TripItem])
    let onToggle: (TripItem) -> Void
    let onDelete: (TripItem) -> Void
    let onEdit: (TripItem) -> Void

    private var remaining: Int { group.items.filter { $0.completedAt == nil }.count }
    private var allPacked: Bool { remaining == 0 }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: group.location.sfSymbol)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text(group.location.displayName)
                    .font(.headline)
                Spacer()
                if allPacked {
                    Text("All packed ✓")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.green)
                } else {
                    Text("\(remaining) remaining")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.red)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)

            Divider()

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(group.items) { item in
                        PackingRow(item: item, onToggle: { onToggle(item) }, onDelete: { onDelete(item) }, onEdit: { onEdit(item) })
                            .padding(.horizontal)
                            .padding(.vertical, 2)
                        if item.id != group.items.last?.id {
                            Divider().padding(.leading, 60)
                        }
                    }
                    Spacer(minLength: 60)
                }
            }
        }
    }
}

// MARK: - Prep tasks tab

private struct PrepTab: View {
    let vm: TripDetailViewModel
    var onAddTask: (() -> Void)? = nil
    @State private var selectedTaskIndex: Int = 0

    var body: some View {
        let daysAway = daysUntilDeparture(from: vm.trip.departureDate)
        let prepFraction = vm.totalTasks > 0 ? Double(vm.completedTasks) / Double(vm.totalTasks) : 1.0
        VStack(spacing: 0) {
            ProgressRow(
                label: "Completed",
                completed: vm.completedTasks,
                total: vm.totalTasks,
                unit: "tasks",
                color: urgencyColor(daysUntilDeparture: daysAway, packingFraction: prepFraction)
            )
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(Color(.systemBackground))

            Divider()

            if vm.taskGroups.isEmpty {
                PrepTasksEmptyState(onAddTask: onAddTask)
            } else {
                TabView(selection: $selectedTaskIndex) {
                    ForEach(Array(vm.taskGroups.enumerated()), id: \.offset) { index, group in
                        TaskPageView(
                            group: group,
                            deadline: vm.deadline(for: group.timing),
                            onToggle: { item in
                                withAnimation(.easeInOut(duration: 0.2)) { vm.toggle(item: item) }
                                Task { await vm.save(item: item) }
                            }
                        )
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))
                .animation(.easeInOut(duration: 0.2), value: vm.completedTasks)
            }
        }
    }
}

// MARK: - Prep tasks empty state

private struct PrepTasksEmptyState: View {
    var onAddTask: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "checkmark.circle")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)

            VStack(spacing: 6) {
                Text("No prep tasks yet")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Add tasks to prep before your trip.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let onAddTask {
                Button("Add Task", action: onAddTask)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }

            Spacer()
        }
        .padding(.horizontal)
    }
}

// MARK: - Task page

private struct TaskPageView: View {
    let group: (timing: TaskTiming, items: [TripItem])
    let deadline: Date
    let onToggle: (TripItem) -> Void

    private var remaining: Int { group.items.filter { $0.completedAt == nil }.count }
    private var allDone: Bool { remaining == 0 }
    private var overdue: Bool { !allDone && deadline < Calendar.current.startOfDay(for: .now) }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: group.timing.sfSymbol)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text(group.timing.sectionLabel)
                    .font(.headline)
                Spacer()
                if allDone {
                    Text("All done ✓")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.green)
                } else {
                    Text(deadline, format: .dateTime.month(.abbreviated).day())
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(overdue ? Color.red : Color.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)

            Divider()

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(group.items) { item in
                        TaskRow(item: item) { onToggle(item) }
                            .padding(.horizontal)
                            .padding(.vertical, 2)
                        if item.id != group.items.last?.id {
                            Divider().padding(.leading, 60)
                        }
                    }
                    Spacer(minLength: 60)
                }
            }
        }
    }
}

// MARK: - Packing row

private struct PackingRow: View {
    let item: TripItem
    let onToggle: () -> Void
    let onDelete: () -> Void
    let onEdit: () -> Void

    var body: some View {
        if item.source == .manual {
            rowContent
                .contextMenu {
                    Button(role: .destructive, action: onDelete) {
                        Label("Delete", systemImage: "trash")
                    }
                }
        } else {
            rowContent
        }
    }

    private var rowContent: some View {
        HStack(spacing: 0) {
            Button(action: onToggle) {
                Image(systemName: item.completedAt != nil ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(item.completedAt != nil ? Color.accentColor : Color.secondary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)

            Button(action: onEdit) {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name)
                            .strikethrough(item.completedAt != nil, color: .secondary)
                            .foregroundStyle(item.completedAt != nil ? Color.secondary : Color.primary)
                        if item.quantity > 1 {
                            Text("×\(item.quantity)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let notes = item.notes, !notes.isEmpty {
                            Text(notes)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }

                    Spacer()

                    if item.source == .manual {
                        Text("Custom")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.15))
                            .foregroundStyle(Color.orange)
                            .clipShape(Capsule())
                    }

                    if item.flightAccessible {
                        Image(systemName: "airplane")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Task row

private struct TaskRow: View {
    let item: TripItem
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: item.completedAt != nil ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(item.completedAt != nil ? Color.accentColor : Color.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .strikethrough(item.completedAt != nil, color: .secondary)
                        .foregroundStyle(item.completedAt != nil ? Color.secondary : Color.primary)
                    if let notes = item.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Completed banner

private struct TripCompletedBanner: View {
    let manuallyCompletedAt: Date?

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text(manuallyCompletedAt != nil ? "Completed early" : "Completed")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.green)
            if let date = manuallyCompletedAt {
                Text("· \(date, format: .dateTime.month(.abbreviated).day().year())")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color.green.opacity(0.08))
    }
}

// MARK: - Archived banner

private struct ArchivedBanner: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "archivebox.fill")
                .foregroundStyle(.secondary)
            Text("Archived")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
            Text("· Read only")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemBackground))
    }
}

// MARK: - TaskTiming display

extension TaskTiming {
    var sectionLabel: String {
        switch self {
        case .weekBefore:      return "A week before"
        case .threeDaysBefore: return "3 days before"
        case .dayBefore:       return "Day before"
        case .morningOf:       return "Morning of"
        case .atAirport:       return "At the airport"
        case .onPlane:         return "On the plane"
        case .uponArrival:     return "Upon arrival"
        }
    }

    var sfSymbol: String {
        switch self {
        case .weekBefore:      return "calendar"
        case .threeDaysBefore: return "calendar.badge.clock"
        case .dayBefore:       return "moon.stars.fill"
        case .morningOf:       return "sunrise.fill"
        case .atAirport:       return "airplane.departure"
        case .onPlane:         return "airplane"
        case .uponArrival:     return "airplane.arrival"
        }
    }
}

// MARK: - ItemCategory display

extension ItemCategory {
    var displayName: String {
        switch self {
        case .clothing:        return "Clothing"
        case .golf:            return "Golf"
        case .tech:            return "Tech"
        case .health:          return "Health"
        case .meds:            return "Medications"
        case .hygiene:         return "Hygiene"
        case .documents:       return "Documents"
        case .misc:            return "Miscellaneous"
        case .workoutClothing: return "Workout"
        }
    }

    var sfSymbol: String {
        switch self {
        case .clothing:        return "tshirt.fill"
        case .golf:            return "figure.golf"
        case .tech:            return "laptopcomputer"
        case .health:          return "cross.case.fill"
        case .meds:            return "pills.fill"
        case .hygiene:         return "shower.fill"
        case .documents:       return "doc.fill"
        case .misc:            return "ellipsis.circle.fill"
        case .workoutClothing: return "figure.run"
        }
    }

    var sortOrder: Int {
        switch self {
        case .documents:       return 0
        case .clothing:        return 1
        case .workoutClothing: return 2
        case .golf:            return 3
        case .tech:            return 4
        case .hygiene:         return 5
        case .health:          return 6
        case .meds:            return 7
        case .misc:            return 8
        }
    }
}
