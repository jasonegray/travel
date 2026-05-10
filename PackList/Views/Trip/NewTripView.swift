import SwiftUI
import MapKit

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

// MARK: - Step 2: Destination + Map

private struct NameDestinationStep: View {
    @Bindable var vm: NewTripViewModel
    @State private var completer = LocationSearchCompleter()
    @State private var destinationText = ""
    @State private var mapPosition: MapCameraPosition = .automatic
    @State private var poiAnnotations: [POIAnnotation] = []
    @State private var selectedPOIId: UUID?

    private var categories: [MKPointOfInterestCategory] {
        poiCategories(for: vm.activities)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search header (non-scrollable)
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Where are you headed?")
                        .font(.title2).fontWeight(.bold)
                    Text(poiSubtitle)
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
                    .onChange(of: destinationText) { _, text in
                        vm.destination = text
                        completer.updateQuery(text)
                    }

                if !completer.suggestions.isEmpty {
                    suggestionsDropdown
                }
            }
            .padding(.horizontal)
            .padding(.top, 20)
            .padding(.bottom, 12)

            // Full-height interactive map
            if completer.selectedCoordinate != nil {
                Map(position: $mapPosition, selection: $selectedPOIId) {
                    if let coord = completer.selectedCoordinate {
                        Marker("", coordinate: coord)
                            .tint(.red)
                    }
                    ForEach(poiAnnotations) { poi in
                        Marker(poi.name, coordinate: poi.coordinate)
                            .tag(poi.id)
                            .tint(Color.accentColor)
                    }
                }
                .mapStyle(categories.isEmpty
                          ? .standard
                          : .standard(pointsOfInterest: .including(categories)))
                .frame(maxHeight: .infinity)
                .task(id: poiSearchKey) { await searchPOIs() }
                .overlay(alignment: .topLeading) {
                    Button {
                        completer.selectedCoordinate = nil
                        vm.destinationCoordinate = nil
                        poiAnnotations = []
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.black)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(.white))
                            .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                    }
                    .padding(8)
                }
            } else {
                Spacer()
            }
        }
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
        _ = await completer.select(suggestion)
        destinationText          = completer.query
        vm.destination           = completer.query
        vm.destinationCoordinate = completer.selectedCoordinate
        if let coord = completer.selectedCoordinate {
            mapPosition = .region(MKCoordinateRegion(
                center: coord,
                latitudinalMeters: 30_000,
                longitudinalMeters: 30_000
            ))
        }
    }

    // MARK: - POI search

    private var poiSearchKey: POISearchKey? {
        guard let coord = completer.selectedCoordinate else { return nil }
        return POISearchKey(lat: coord.latitude, lon: coord.longitude, activities: vm.activities)
    }

    private func searchPOIs() async {
        guard let coord = completer.selectedCoordinate, !categories.isEmpty else {
            poiAnnotations = []
            return
        }
        selectedPOIId = nil

        let request = MKLocalSearch.Request()
        request.pointOfInterestFilter = MKPointOfInterestFilter(including: categories)
        request.resultTypes = .pointOfInterest
        request.region = MKCoordinateRegion(
            center: coord,
            latitudinalMeters: 25_000,
            longitudinalMeters: 25_000
        )

        let items = (try? await MKLocalSearch(request: request).start())?.mapItems ?? []
        poiAnnotations = items.prefix(30).compactMap { item in
            guard let name = item.name, !name.isEmpty else { return nil }
            return POIAnnotation(name: name, coordinate: item.placemark.coordinate)
        }
    }

    // MARK: - Helpers

    private var poiSubtitle: String {
        guard !categories.isEmpty, completer.selectedCoordinate != nil else {
            return "Search for your destination."
        }
        var labels: [String] = []
        let a = vm.activities
        if a.contains(.golf)         { labels.append("golf courses") }
        if a.contains(.beach)        { labels.append("beaches") }
        if a.contains(.pool)         { labels.append("pools") }
        if a.contains(.hiking)       { labels.append("parks & trails") }
        if a.contains(.formalDinner) { labels.append("restaurants") }
        if a.contains(.workout)      { labels.append("gyms") }
        if a.contains(.sightseeing)  { labels.append("attractions") }
        if a.contains(.conference), #available(iOS 18.0, *) { labels.append("convention centres") }
        return "Showing \(labels.joined(separator: ", ")) nearby."
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

// MARK: - Step 4: Carry-on only

private struct CarryOnStep: View {
    @Bindable var vm: NewTripViewModel

    var body: some View {
        StepShell(title: "Carry-on only?", subtitle: "No checked bag on this trip.") {
            BinaryPicker(yesLabel: "Yes, carry-on only", noLabel: "No, I'm checking a bag", value: $vm.carryOnOnly)
        }
    }
}

// MARK: - Step 5: Laundry

private struct LaundryStep: View {
    @Bindable var vm: NewTripViewModel

    var body: some View {
        StepShell(title: "Will laundry be available?", subtitle: "Affects how many clothes we suggest.") {
            BinaryPicker(yesLabel: "Yes", noLabel: "No", value: $vm.laundryAvailable)
        }
    }
}

// MARK: - Step 6: Interac

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

// MARK: - Step 7: Medical appointments

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

// MARK: - POI support

private struct POIAnnotation: Identifiable {
    let id = UUID()
    let name: String
    let coordinate: CLLocationCoordinate2D
}

private struct POISearchKey: Equatable {
    let lat: Double
    let lon: Double
    let activities: Set<ActivityType>
}

private func poiCategories(for activities: Set<ActivityType>) -> [MKPointOfInterestCategory] {
    var seen  = Set<MKPointOfInterestCategory>()
    var cats  = [MKPointOfInterestCategory]()
    func add(_ c: MKPointOfInterestCategory) { if seen.insert(c).inserted { cats.append(c) } }

    if activities.contains(.golf), #available(iOS 18, *) { add(.golf) }
    if activities.contains(.beach)        { add(.beach); add(.marina) }
    if activities.contains(.pool)         { add(.fitnessCenter); add(.aquarium) }
    if activities.contains(.hiking)       { add(.nationalPark); add(.park); add(.campground) }
    if activities.contains(.formalDinner) { add(.restaurant) }
    if activities.contains(.workout)      { add(.fitnessCenter) }
    if activities.contains(.sightseeing)  { add(.museum); add(.theater) }
    if activities.contains(.conference), #available(iOS 18.0, *) { add(.conventionCenter) }
    return cats
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
