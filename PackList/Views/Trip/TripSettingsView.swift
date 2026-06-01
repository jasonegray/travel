import SwiftUI

struct TripSettingsView: View {
    @State private var vm: TripSettingsViewModel
    let onComplete: ([TripItem]) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.repositories) private var repositories

    private let tripTypeActivities: [ActivityType] = [.conference, .golf]
    private let addOnActivities: [ActivityType] = [.beach, .pool, .hiking, .formalDinner, .workout, .sightseeing]

    init(trip: TripSession, onComplete: @escaping ([TripItem]) -> Void) {
        _vm = State(wrappedValue: TripSettingsViewModel(trip: trip))
        self.onComplete = onComplete
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Trip type") {
                    ForEach(tripTypeActivities, id: \.self) { activity in
                        activityToggleRow(activity)
                    }
                }

                Section("Activities") {
                    ForEach(addOnActivities, id: \.self) { activity in
                        activityToggleRow(activity)
                    }
                }

                Section("Luggage") {
                    Toggle("Carry-on only", isOn: $vm.carryOnOnly)
                    Toggle("Laundry available", isOn: $vm.laundryAvailable)
                }

                Section("Devices") {
                    Toggle("Interac phone reader", isOn: $vm.interacPhone)
                    Toggle("Interac laptop reader", isOn: $vm.interacLaptop)
                }
            }
            .navigationTitle("Trip Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(vm.isRegenerating)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if vm.isRegenerating {
                        ProgressView()
                    } else {
                        Button("Done") { vm.requestSave() }
                            .disabled(!vm.hasChanges)
                    }
                }
            }
            .alert("Regenerate Packing List?", isPresented: $vm.showConfirmation) {
                Button("Continue", role: .destructive) {
                    guard let repos = repositories else { return }
                    HapticManager.warning()
                    Task {
                        if let newItems = await vm.applyAndRegenerate(
                            sessions: repos.tripSessions,
                            tripItems: repos.tripItems,
                            masterItems: repos.masterItems
                        ) {
                            onComplete(newItems)
                            dismiss()
                        }
                    }
                }
                Button("Cancel", role: .cancel) {
                    vm.revertChanges()
                }
            } message: {
                Text("Updating these settings will regenerate your packing list. Items you have already packed may be reset. Continue?")
            }
            .alert("Update Failed", isPresented: Binding(
                get: { vm.errorMessage != nil },
                set: { if !$0 { vm.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(vm.errorMessage ?? "")
            }
        }
    }

    @ViewBuilder
    private func activityToggleRow(_ activity: ActivityType) -> some View {
        Toggle(isOn: Binding(
            get: { vm.activities.contains(activity) },
            set: { isOn in
                if isOn { vm.activities.insert(activity) }
                else { vm.activities.remove(activity) }
            }
        )) {
            Label(activity.displayName, systemImage: activity.icon)
        }
    }
}
