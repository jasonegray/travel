import SwiftUI
import MapKit

// MARK: - Root

struct NewTripView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.repositories) private var repositories
    @State private var vm: NewTripViewModel
    @State private var forward = true

    init() {
        _vm = State(wrappedValue: NewTripViewModel())
    }

    init(prefilledWith source: NewTripViewModel) {
        _vm = State(wrappedValue: source)
    }

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
            .navigationTitle(vm.wizardTitle)
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
        .alert("Couldn't Create Trip", isPresented: Binding(
            get: { vm.errorMessage != nil },
            set: { if !$0 { vm.errorMessage = nil } }
        )) {
            Button("OK") { vm.errorMessage = nil }
        } message: {
            Text(vm.errorMessage ?? "An unexpected error occurred. Please try again.")
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
        HapticManager.lightImpact()
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
        case .activities:           ActivitiesStep(vm: vm)
        case .nameDestination:      NameDestinationStep(vm: vm)
        case .dates:                DatesStep(vm: vm)
        case .carryOnOnly:          CarryOnStep(vm: vm)
        case .laundry:              LaundryStep(vm: vm)
        case .interac:              InteracStep(vm: vm)
        case .medicalAppointments:  MedicalStep(vm: vm)
        case .confirm:              ConfirmStep(vm: vm)
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
    var yesIcon: String? = nil
    var noIcon: String? = nil
    @Binding var value: Bool

    var body: some View {
        HStack(spacing: 12) {
            BinaryCard(label: yesLabel, icon: yesIcon, isSelected: value)  { value = true }
            BinaryCard(label: noLabel,  icon: noIcon,  isSelected: !value) { value = false }
        }
    }
}

private struct BinaryCard: View {
    let label: String
    var icon: String? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                }
                Text(label)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
            }
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

// MARK: - Step 2: Destination + Map

private struct NameDestinationStep: View {
    @Bindable var vm: NewTripViewModel
    @State private var completer = LocationSearchCompleter()
    @State private var destinationText = ""
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Where are you headed?")
                    .font(.title2).fontWeight(.bold)
                Text("Search for your destination.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            TextField("e.g. Orlando, Tokyo, Paris", text: $destinationText)
                .textFieldStyle(.plain)
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .submitLabel(.search)
                .autocorrectionDisabled()
                .focused($searchFocused)
                .onChange(of: destinationText) { _, text in
                    vm.destination = text
                    completer.updateQuery(text)
                }
                .onChange(of: searchFocused) { _, focused in
                    if focused && !destinationText.isEmpty {
                        DispatchQueue.main.async {
                            UIApplication.shared.sendAction(
                                #selector(UIResponder.selectAll(_:)), to: nil, from: nil, for: nil
                            )
                        }
                    }
                }

            if !completer.suggestions.isEmpty {
                suggestionsDropdown
            }

            Spacer()
        }
        .padding(.horizontal)
        .padding(.top, 20)
        .onAppear {
            if destinationText.isEmpty { destinationText = vm.destination }
        }
    }

    // MARK: - Suggestions dropdown

    private var suggestionsDropdown: some View {
        VStack(spacing: 0) {
            ForEach(Array(completer.suggestions.prefix(5).enumerated()), id: \.offset) { idx, suggestion in
                Button {
                    Task { await pick(suggestion) }
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(suggestion.title)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                        if !suggestion.subtitle.isEmpty {
                            Text(suggestion.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)

                if idx < min(completer.suggestions.count, 5) - 1 {
                    Divider().padding(.leading, 12)
                }
            }
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Actions

    @MainActor
    private func pick(_ suggestion: MKLocalSearchCompletion) async {
        searchFocused = false
        _ = await completer.select(suggestion)
        destinationText          = completer.query
        vm.destination           = completer.query
        vm.destinationCoordinate = completer.selectedCoordinate
    }
}

// MARK: - Step 3: Dates

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

// MARK: - Step 1: Activities

private let tripTypeActivities: [ActivityType] = [.conference, .golf]
private let addOnActivities: [ActivityType]    = [.beach, .pool, .hiking, .formalDinner, .workout, .sightseeing]

private struct ActivitiesStep: View {
    @Bindable var vm: NewTripViewModel

    private let typeColumns   = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
    private let addOnColumns  = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        StepShell(title: "What will you be doing?") {
            VStack(alignment: .leading, spacing: 24) {
                // Flying toggle
                VStack(alignment: .leading, spacing: 10) {
                    Text("Are you flying?")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    BinaryPicker(yesLabel: "Flying", noLabel: "Not flying", yesIcon: "airplane", noIcon: "car.fill", value: $vm.isFlyingTrip)
                }

                // Trip Types
                VStack(alignment: .leading, spacing: 10) {
                    Text("What type of trip?")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    LazyVGrid(columns: typeColumns, spacing: 12) {
                        ForEach(tripTypeActivities, id: \.self) { activity in
                            let selected = vm.activities.contains(activity)
                            ActivityChip(
                                title: activity.displayName,
                                icon: activity.icon,
                                isSelected: selected,
                                action: {
                                    if selected { vm.activities.remove(activity) }
                                    else        { vm.activities.insert(activity) }
                                }
                            )
                        }
                    }
                }

                // Add-ons
                VStack(alignment: .leading, spacing: 10) {
                    Text("Any extras?")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    LazyVGrid(columns: addOnColumns, spacing: 10) {
                        ForEach(addOnActivities, id: \.self) { activity in
                            let selected = vm.activities.contains(activity)
                            AddOnChip(
                                title: activity.displayName,
                                icon: activity.icon,
                                isSelected: selected,
                                action: {
                                    if selected { vm.activities.remove(activity) }
                                    else        { vm.activities.insert(activity) }
                                }
                            )
                        }
                    }
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

private struct AddOnChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)
                    .frame(height: 28)
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                Text(title)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .frame(height: 28)
            }
            .frame(maxWidth: .infinity, minHeight: 80, maxHeight: 80)
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

// MARK: - Step 4: Carry-on only

private struct CarryOnStep: View {
    @Bindable var vm: NewTripViewModel

    var body: some View {
        StepShell(title: "Carry-on only?", subtitle: "No checked bag on this trip.") {
            BinaryPicker(yesLabel: "Yes, carry-on only", noLabel: "No, I'm checking a bag", yesIcon: "bag.fill", noIcon: "shippingbox.fill", value: $vm.carryOnOnly)
        }
    }
}

// MARK: - Step 5: Laundry

private struct LaundryStep: View {
    @Bindable var vm: NewTripViewModel

    var body: some View {
        StepShell(title: "Will laundry be available?", subtitle: "Affects how many clothes we suggest.") {
            BinaryPicker(yesLabel: "Yes, laundry access", noLabel: "No, packing for the full trip", yesIcon: "washer.fill", noIcon: "xmark.circle.fill", value: $vm.laundryAvailable)
        }
    }
}

// MARK: - Step 6: Interac

private struct InteracStep: View {
    @Bindable var vm: NewTripViewModel

    var body: some View {
        StepShell(title: "Are you travelling with electronics?", subtitle: "We'll include the right charging cables and accessories.") {
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

// MARK: - Step 7: Medical appointments

private struct MedicalStep: View {
    @Bindable var vm: NewTripViewModel

    var body: some View {
        StepShell(
            title: "Any medical appointments?",
            subtitle: "We'll add relevant items like your health card, referral letters, and any specific supplies."
        ) {
            BinaryPicker(yesLabel: "Yes, I have appointments", noLabel: "No appointments", yesIcon: "cross.case.fill", noIcon: "xmark.circle.fill", value: $vm.hasMedicalAppointment)
        }
    }
}

// MARK: - Confirm step

private struct ConfirmStep: View {
    @Bindable var vm: NewTripViewModel
    @State private var isEditing = false
    @FocusState private var nameFocused: Bool

    var body: some View {
        StepShell(title: "Ready to pack?",
                  subtitle: "Here's your trip name — tap the pencil to change it.") {
            VStack(alignment: .leading, spacing: 24) {

                // Trip name
                VStack(alignment: .leading, spacing: 10) {
                    if isEditing {
                        TextField("Trip name", text: $vm.tripName)
                            .textFieldStyle(.plain)
                            .font(.title3).fontWeight(.semibold)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .submitLabel(.done)
                            .focused($nameFocused)
                            .onSubmit { isEditing = false }
                    } else {
                        HStack(alignment: .center, spacing: 8) {
                            Text(vm.finalTripName)
                                .font(.title3).fontWeight(.semibold)
                                .fixedSize(horizontal: false, vertical: true)
                            Button {
                                if vm.tripName.isEmpty { vm.tripName = vm.generatedTripName }
                                isEditing = true
                                nameFocused = true
                            } label: {
                                Image(systemName: "pencil.circle")
                                    .font(.title3)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                // Trip summary
                VStack(alignment: .leading, spacing: 12) {
                    summaryRow("mappin.circle", vm.destination)
                    summaryRow("calendar",
                               "\(vm.departureDate.formatted(.dateTime.month(.abbreviated).day().year())) – \(vm.returnDate.formatted(.dateTime.month(.abbreviated).day().year()))")
                    if !vm.activities.isEmpty {
                        summaryRow("tag", vm.activities.map(\.displayName).joined(separator: ", "))
                    }
                    summaryRow("thermometer.medium", vm.weather.displayName)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    @ViewBuilder
    private func summaryRow(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 20)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
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

// MARK: - Location search completer

@Observable
final class LocationSearchCompleter: NSObject, MKLocalSearchCompleterDelegate {
    var suggestions: [MKLocalSearchCompletion] = []
    var selectedCoordinate: CLLocationCoordinate2D?
    private(set) var query: String = ""

    @ObservationIgnored private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }

    func updateQuery(_ text: String) {
        query = text
        if text.trimmingCharacters(in: .whitespaces).isEmpty {
            suggestions = []
            selectedCoordinate = nil
            completer.queryFragment = ""
        } else {
            completer.queryFragment = text
        }
    }

    @MainActor
    func select(_ completion: MKLocalSearchCompletion) async -> String {
        query = [completion.title, completion.subtitle]
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
        suggestions = []
        let request = MKLocalSearch.Request(completion: completion)
        if let response = try? await MKLocalSearch(request: request).start(),
           let item = response.mapItems.first {
            selectedCoordinate = item.placemark.coordinate
        }
        return completion.title
            .components(separatedBy: ",").first?
            .trimmingCharacters(in: .whitespaces) ?? completion.title
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        suggestions = completer.results
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        suggestions = []
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
        case .conference:   return "Conference"
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
        case .conference:   return "building.2.fill"
        }
    }
}
