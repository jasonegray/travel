import SwiftUI

// MARK: - Root

struct NewTripView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.repositories) private var repositories
    @State private var vm = NewTripViewModel()
    @State private var forward = true

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !vm.isGenerating {
                    WizardProgressBar(step: vm.displayStep, total: vm.totalSteps)
                        .padding(.horizontal)
                        .padding(.top, 4)
                        .padding(.bottom, 8)
                }

                Group {
                    if vm.isGenerating {
                        GeneratingStepView()
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .opacity
                            ))
                    } else {
                        stepContent
                            .id(vm.currentStep)
                            .transition(.asymmetric(
                                insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
                                removal:   .move(edge: forward ? .leading  : .trailing).combined(with: .opacity)
                            ))
                    }
                }
                .animation(.easeInOut(duration: 0.28), value: vm.currentStep)
                .animation(.easeInOut(duration: 0.28), value: vm.isGenerating)
                .frame(maxHeight: .infinity)

                if !vm.isGenerating {
                    VStack(spacing: 0) {
                        Divider()
                        Button(action: goNext) {
                            Text(vm.isLastStep ? "Generate My List" : "Continue")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!vm.canContinue)
                        .padding()
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if vm.canGoBack {
                        Button(action: goBack) {
                            Image(systemName: "chevron.left")
                                .fontWeight(.semibold)
                        }
                    } else {
                        Button("Cancel") { dismiss() }
                    }
                }
            }
        }
        .interactiveDismissDisabled()
        .onChange(of: vm.isDone) { _, done in
            if done { dismiss() }
        }
        .task(id: vm.isGenerating) {
            guard vm.isGenerating, let repos = repositories else { return }
            await vm.createTrip(
                sessions:    repos.tripSessions,
                tripItems:   repos.tripItems,
                masterItems: repos.masterItems
            )
        }
    }

    private func goNext() {
        forward = true
        withAnimation(.easeInOut(duration: 0.28)) { vm.next() }
    }

    private func goBack() {
        forward = false
        withAnimation(.easeInOut(duration: 0.28)) { vm.back() }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch vm.currentStep {
        case .nameDestination:      NameDestinationStep(vm: vm)
        case .dates:                DatesStep(vm: vm)
        case .region:               RegionStep(vm: vm)
        case .purpose:              PurposeStep(vm: vm)
        case .weather:              WeatherStep(vm: vm)
        case .companions:           CompanionsStep(vm: vm)
        case .activities:           ActivitiesStep(vm: vm)
        case .carryOnOnly:          CarryOnStep(vm: vm)
        case .laundry:              LaundryStep(vm: vm)
        case .interac:              InteracStep(vm: vm)
        case .medicalAppointments:  MedicalStep(vm: vm)
        }
    }
}

// MARK: - Progress bar

private struct WizardProgressBar: View {
    let step: Int
    let total: Int

    var body: some View {
        VStack(alignment: .trailing, spacing: 5) {
            ThinProgressBar(fraction: Double(step) / Double(total))
            Text("Step \(step) of \(total)")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Step container

private struct StepShell<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    @ViewBuilder let content: () -> Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.title2)
                        .fontWeight(.bold)
                    if let sub = subtitle {
                        Text(sub)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                content()
                Spacer(minLength: 8)
            }
            .padding(.horizontal)
            .padding(.top, 20)
        }
    }
}

// MARK: - Selection card

private struct OptionCard: View {
    let title: String
    var subtitle: String? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    if let sub = subtitle {
                        Text(sub)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    .font(.system(size: 20))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color(.secondarySystemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Binary choice (Yes / No in two columns)

private struct BinaryPicker: View {
    let yesLabel: String
    let noLabel: String
    @Binding var value: Bool

    var body: some View {
        HStack(spacing: 12) {
            BinaryCard(label: yesLabel, isSelected: value)  { value = true }
            BinaryCard(label: noLabel,  isSelected: !value) { value = false }
        }
    }
}

private struct BinaryCard: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline)
                .fontWeight(.medium)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(isSelected ? Color.accentColor.opacity(0.1) : Color(.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Step 1: Name + Destination

private struct NameDestinationStep: View {
    @Bindable var vm: NewTripViewModel

    var body: some View {
        StepShell(title: "Let's plan your trip.", subtitle: "Give it a name and tell us where you're headed.") {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Trip name")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    TextField("e.g. Tokyo Golf Trip", text: $vm.tripName)
                        .textFieldStyle(.plain)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .submitLabel(.next)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Destination")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    TextField("e.g. Tokyo, Japan", text: $vm.destination)
                        .textFieldStyle(.plain)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .submitLabel(.done)
                }
            }
        }
    }
}

// MARK: - Step 2: Dates

private struct DatesStep: View {
    @Bindable var vm: NewTripViewModel

    private var minReturn: Date {
        Calendar.current.date(byAdding: .day, value: 1, to: vm.departureDate) ?? vm.departureDate
    }

    var body: some View {
        StepShell(title: "When are you travelling?") {
            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Departure", systemImage: "airplane.departure")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    DatePicker(
                        "",
                        selection: $vm.departureDate,
                        in: Calendar.current.startOfDay(for: .now)...,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .onChange(of: vm.departureDate) { _, dep in
                        if vm.returnDate <= dep {
                            vm.returnDate = Calendar.current.date(byAdding: .day, value: 3, to: dep) ?? dep
                        }
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 10) {
                    Label("Return", systemImage: "airplane.arrival")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    DatePicker(
                        "",
                        selection: $vm.returnDate,
                        in: minReturn...,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}

// MARK: - Step 3: Region

private struct RegionStep: View {
    @Bindable var vm: NewTripViewModel

    var body: some View {
        StepShell(title: "Where in the world?") {
            VStack(spacing: 10) {
                ForEach(TravelRegion.allCases, id: \.self) { region in
                    OptionCard(
                        title: region.displayName,
                        isSelected: vm.region == region,
                        action: { vm.region = region }
                    )
                }
            }
        }
    }
}

// MARK: - Step 4: Purpose

private struct PurposeStep: View {
    @Bindable var vm: NewTripViewModel

    var body: some View {
        StepShell(title: "What's the purpose?", subtitle: "Select all that apply.") {
            VStack(spacing: 10) {
                ForEach(TripPurpose.allCases, id: \.self) { purpose in
                    let selected = vm.purposes.contains(purpose)
                    OptionCard(
                        title: purpose.displayName,
                        isSelected: selected,
                        action: {
                            if selected { vm.purposes.remove(purpose) }
                            else         { vm.purposes.insert(purpose) }
                        }
                    )
                }
            }
        }
    }
}

// MARK: - Step 5: Weather

private struct WeatherStep: View {
    @Bindable var vm: NewTripViewModel

    var body: some View {
        StepShell(title: "What's the weather like?") {
            VStack(spacing: 10) {
                ForEach(WeatherProfile.allCases, id: \.self) { w in
                    OptionCard(
                        title: w.displayName,
                        isSelected: vm.weather == w,
                        action: { vm.weather = w }
                    )
                }
            }
        }
    }
}

// MARK: - Step 6: Companions

private struct CompanionsStep: View {
    @Bindable var vm: NewTripViewModel

    var body: some View {
        StepShell(title: "Who's coming with you?", subtitle: "Select all that apply.") {
            VStack(spacing: 10) {
                ForEach(TravelCompanion.allCases, id: \.self) { companion in
                    let selected = vm.companions.contains(companion)
                    OptionCard(
                        title: companion.displayName,
                        isSelected: selected,
                        action: {
                            if selected { vm.companions.remove(companion) }
                            else         { vm.companions.insert(companion) }
                        }
                    )
                }
            }
        }
    }
}

// MARK: - Step 7: Activities

private struct ActivitiesStep: View {
    @Bindable var vm: NewTripViewModel

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        StepShell(title: "What will you be doing?", subtitle: "Select all that apply.") {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(ActivityType.allCases, id: \.self) { activity in
                    let selected = vm.activities.contains(activity)
                    ActivityChip(
                        title: activity.displayName,
                        icon: activity.icon,
                        isSelected: selected,
                        action: {
                            if selected { vm.activities.remove(activity) }
                            else         { vm.activities.insert(activity) }
                        }
                    )
                }
            }
        }
    }
}

private struct ActivityChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color(.secondarySystemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Step 8: Carry-on only

private struct CarryOnStep: View {
    @Bindable var vm: NewTripViewModel

    var body: some View {
        StepShell(title: "Carry-on only?", subtitle: "No checked bag on this trip.") {
            BinaryPicker(yesLabel: "Yes, carry-on only", noLabel: "No, I'm checking a bag", value: $vm.carryOnOnly)
        }
    }
}

// MARK: - Step 9: Laundry

private struct LaundryStep: View {
    @Bindable var vm: NewTripViewModel

    var body: some View {
        StepShell(title: "Will laundry be available?", subtitle: "Affects how many clothes we suggest.") {
            BinaryPicker(yesLabel: "Yes", noLabel: "No", value: $vm.laundryAvailable)
        }
    }
}

// MARK: - Step 10: Interac

private struct InteracStep: View {
    @Bindable var vm: NewTripViewModel

    var body: some View {
        StepShell(title: "Are you bringing Interac-connected assets?", subtitle: "We'll include the right charging cables and accessories.") {
            VStack(spacing: 10) {
                ForEach(NewTripViewModel.InteracChoice.allCases, id: \.self) { choice in
                    OptionCard(
                        title: choice.displayName,
                        isSelected: vm.interacChoice == choice,
                        action: { vm.interacChoice = choice }
                    )
                }
            }
        }
    }
}

// MARK: - Step 11: Medical appointments

private struct MedicalStep: View {
    @Bindable var vm: NewTripViewModel

    var body: some View {
        StepShell(
            title: "Any medical appointments?",
            subtitle: "We'll add relevant items like your health card, referral letters, and any specific supplies."
        ) {
            BinaryPicker(yesLabel: "Yes", noLabel: "No", value: $vm.hasMedicalAppointment)
        }
    }
}

// MARK: - Generating

private struct GeneratingStepView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            ProgressView()
                .scaleEffect(1.4)
                .tint(.accentColor)
            VStack(spacing: 8) {
                Text("Generating your list…")
                    .font(.headline)
                Text("Matching items to your trip profile")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Enum display extensions

extension TravelRegion {
    var displayName: String {
        switch self {
        case .canada: return "🇨🇦  Canada"
        case .us:     return "🇺🇸  United States"
        case .europe: return "🇪🇺  Europe"
        case .japan:  return "🇯🇵  Japan"
        case .asia:   return "🌏  Asia"
        case .other:  return "🌍  Other"
        }
    }
}

extension TripPurpose {
    var displayName: String {
        switch self {
        case .golf:     return "⛳️  Golf"
        case .business: return "💼  Business"
        case .personal: return "🌴  Personal"
        case .family:   return "👨‍👩‍👧  Family"
        }
    }
}

extension WeatherProfile {
    var displayName: String {
        switch self {
        case .hot:   return "☀️  Hot"
        case .warm:  return "🌤  Warm"
        case .mild:  return "🌥  Mild"
        case .cold:  return "❄️  Cold"
        case .rainy: return "🌧  Rainy"
        }
    }
}

extension TravelCompanion {
    var displayName: String {
        switch self {
        case .solo:       return "Solo"
        case .spouse:     return "Spouse / Partner"
        case .kids:       return "Kids"
        case .family:     return "Family"
        case .colleagues: return "Colleagues"
        }
    }
}

extension ActivityType {
    var displayName: String {
        switch self {
        case .golf:         return "Golf"
        case .beach:        return "Beach"
        case .pool:         return "Pool"
        case .hiking:       return "Hiking"
        case .formalDinner: return "Formal dinner"
        case .workout:      return "Workout"
        case .sightseeing:  return "Sightseeing"
        }
    }

    var icon: String {
        switch self {
        case .golf:         return "figure.golf"
        case .beach:        return "beach.umbrella"
        case .pool:         return "figure.pool.swim"
        case .hiking:       return "figure.hiking"
        case .formalDinner: return "fork.knife"
        case .workout:      return "figure.run"
        case .sightseeing:  return "camera"
        }
    }
}
