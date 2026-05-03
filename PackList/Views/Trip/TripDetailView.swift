import SwiftUI

// MARK: - Root

struct TripDetailView: View {
    @State private var vm: TripDetailViewModel
    @State private var selectedTab: Tab = .packing
    @Environment(\.repositories) private var repositories

    enum Tab { case packing, prepTasks }

    init(trip: TripSession) {
        _vm = State(wrappedValue: TripDetailViewModel(trip: trip))
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                Text("Packing").tag(Tab.packing)
                Text("Prep tasks").tag(Tab.prepTasks)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 10)

            Divider()

            switch selectedTab {
            case .packing:   PackingTab(vm: vm)
            case .prepTasks: PrepTab(vm: vm)
            }
        }
        .navigationTitle(vm.trip.name)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: repositories != nil) {
            guard let repos = repositories else { return }
            await vm.load(repository: repos.tripItems)
        }
    }
}

// MARK: - Packing tab

private struct PackingTab: View {
    let vm: TripDetailViewModel

    var body: some View {
        VStack(spacing: 0) {
            ProgressRow(
                label: "Packed",
                completed: vm.completedPacking,
                total: vm.totalPacking,
                unit: "items"
            )
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(Color(.systemBackground))

            Divider()

            List {
                ForEach(vm.packingGroups, id: \.location) { group in
                    let packedCount = group.items.filter { $0.completedAt != nil }.count
                    Section {
                        ForEach(group.items) { item in
                            PackingRow(item: item) {
                                withAnimation(.easeInOut(duration: 0.2)) { vm.toggle(item: item) }
                                Task { await vm.save(item: item) }
                            }
                        }
                    } header: {
                        HStack {
                            Text(group.location.displayName)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)
                            Spacer()
                            Text("\(packedCount)/\(group.items.count)")
                                .foregroundStyle(.secondary)
                        }
                        .font(.subheadline)
                        .textCase(nil)
                        .padding(.vertical, 4)
                    }
                }
            }
            .listStyle(.plain)
            .animation(.default, value: vm.completedPacking)
        }
    }
}

// MARK: - Prep tasks tab

private struct PrepTab: View {
    let vm: TripDetailViewModel

    var body: some View {
        VStack(spacing: 0) {
            ProgressRow(
                label: "Completed",
                completed: vm.completedTasks,
                total: vm.totalTasks,
                unit: "tasks",
                color: .orange
            )
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(Color(.systemBackground))

            Divider()

            List {
                ForEach(vm.taskGroups, id: \.timing) { group in
                    let deadline = vm.deadline(for: group.timing)
                    let hasIncomplete = group.items.contains { $0.completedAt == nil }
                    let overdue = hasIncomplete && deadline < Calendar.current.startOfDay(for: .now)

                    Section {
                        ForEach(group.items) { item in
                            TaskRow(item: item) {
                                withAnimation(.easeInOut(duration: 0.2)) { vm.toggle(item: item) }
                                Task { await vm.save(item: item) }
                            }
                        }
                    } header: {
                        HStack {
                            Text(group.timing.sectionLabel)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(deadline, format: .dateTime.month(.abbreviated).day())
                                .foregroundStyle(overdue ? Color.red : Color.secondary)
                        }
                        .font(.subheadline)
                        .textCase(nil)
                        .padding(.vertical, 4)
                    }
                }
            }
            .listStyle(.plain)
            .animation(.default, value: vm.completedTasks)
        }
    }
}

// MARK: - Packing row

private struct PackingRow: View {
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
                    if item.quantity > 1 {
                        Text("×\(item.quantity)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

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

                Text(item.name)
                    .strikethrough(item.completedAt != nil, color: .secondary)
                    .foregroundStyle(item.completedAt != nil ? Color.secondary : Color.primary)

                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
}
