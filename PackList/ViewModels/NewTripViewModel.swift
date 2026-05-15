import Foundation
import CoreLocation

@Observable
final class NewTripViewModel {

    // MARK: - Wizard step

    enum WizardStep: Int, CaseIterable {
        case activities = 1
        case nameDestination = 2
        case dates = 3
        case carryOnOnly = 4
        case laundry = 5
        case interac = 6
        case medicalAppointments = 7
        case confirm = 8
    }

    enum InteracChoice: CaseIterable {
        case none, phoneOnly, laptopOnly, both
        var displayName: String {
            switch self {
            case .none:       return "None"
            case .phoneOnly:  return "Phone only"
            case .laptopOnly: return "Laptop only"
            case .both:       return "Both"
            }
        }
        var interacPhone: Bool  { self == .phoneOnly  || self == .both }
        var interacLaptop: Bool { self == .laptopOnly || self == .both }
    }

    // MARK: - Per-step state

    var tripName = ""
    var destination = ""
    var destinationCoordinate: CLLocationCoordinate2D?
    var departureDate: Date = Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now
    var returnDate:    Date = Calendar.current.date(byAdding: .day, value: 10, to: .now) ?? .now
    var region: TravelRegion = .canada
    var purposes: Set<TripPurpose> = []
    var weather: WeatherProfile = .mild
    var companions: Set<TravelCompanion> = [.solo]
    var activities: Set<ActivityType> = []
    var carryOnOnly = true
    var laundryAvailable = true
    var interacChoice: InteracChoice = .none
    var hasMedicalAppointment = false

    // MARK: - Flow state

    var currentStep: WizardStep = .activities
    var isGenerating = false
    var isDone = false
    var errorMessage: String?

    // MARK: - Derived

    var wizardTitle: String {
        let label    = primaryActivityLabel
        let shortDest = destination
            .components(separatedBy: ",").first?
            .trimmingCharacters(in: .whitespaces) ?? ""

        if currentStep == .activities { return "New trip" }

        // Step 2+ with no destination typed yet
        if shortDest.isEmpty { return label.isEmpty ? "New trip" : label }

        // Destination available
        return label.isEmpty ? shortDest : "\(shortDest) · \(label)"
    }

    var skipsMedicalStep: Bool { region == .canada || region == .us }
    var totalSteps: Int { skipsMedicalStep ? 7 : 8 }
    var displayStep: Int { currentStep == .confirm ? totalSteps : currentStep.rawValue }
    var canGoBack: Bool { currentStep != .activities }
    var isLastStep: Bool { currentStep == .confirm }

    var canContinue: Bool {
        switch currentStep {
        case .activities:
            return true
        case .nameDestination:
            return !destination.trimmingCharacters(in: .whitespaces).isEmpty
        case .dates:
            let today = Calendar.current.startOfDay(for: .now)
            let dep   = Calendar.current.startOfDay(for: departureDate)
            return dep >= today && returnDate > departureDate
        default:
            return true
        }
    }

    // MARK: - Trip name

    var generatedTripName: String {
        let dest = destination
            .components(separatedBy: ",").first?
            .trimmingCharacters(in: .whitespaces) ?? destination
        let label = primaryActivityLabel.isEmpty ? "Trip" : primaryActivityLabel
        return "\(dest) · \(label) · \(formattedDateRange)"
    }

    var finalTripName: String {
        tripName.trimmingCharacters(in: .whitespaces).isEmpty ? generatedTripName : tripName
    }

    private var primaryActivityLabel: String {
        if activities.contains(.golf)         { return "Golf" }
        if activities.contains(.beach)        { return "Beach" }
        if activities.contains(.pool)         { return "Pool" }
        if activities.contains(.hiking)       { return "Hiking" }
        if activities.contains(.formalDinner) { return "Dinner" }
        if activities.contains(.workout)      { return "Workout" }
        if activities.contains(.sightseeing)  { return "Sightseeing" }
        if activities.contains(.conference)   { return "Conference" }
        return ""
    }

    private var formattedDateRange: String {
        let cal = Calendar.current
        let depMonth = departureDate.formatted(.dateTime.month(.abbreviated))
        let retMonth = returnDate.formatted(.dateTime.month(.abbreviated))
        let depDay   = cal.component(.day, from: departureDate)
        let retDay   = cal.component(.day, from: returnDate)
        return depMonth == retMonth
            ? "\(depMonth) \(depDay)–\(retDay)"
            : "\(depMonth) \(depDay)–\(retMonth) \(retDay)"
    }

    // MARK: - Navigation

    func next() {
        switch currentStep {
        case .activities:       currentStep = .nameDestination
        case .nameDestination:  currentStep = .dates
        case .dates:
            region = inferRegion(from: destination)
            fetchWeatherIfPossible()
            currentStep = .carryOnOnly
        case .carryOnOnly:      currentStep = .laundry
        case .laundry:          currentStep = .interac
        case .interac:
            skipsMedicalStep ? (currentStep = .confirm) : (currentStep = .medicalAppointments)
        case .medicalAppointments:
            currentStep = .confirm
        case .confirm:
            isGenerating = true
        }
    }

    func back() {
        switch currentStep {
        case .activities:           break
        case .nameDestination:      currentStep = .activities
        case .dates:                currentStep = .nameDestination
        case .carryOnOnly:          currentStep = .dates
        case .laundry:              currentStep = .carryOnOnly
        case .interac:              currentStep = .laundry
        case .medicalAppointments:  currentStep = .interac
        case .confirm:
            skipsMedicalStep ? (currentStep = .interac) : (currentStep = .medicalAppointments)
        }
    }

    private func fetchWeatherIfPossible() {
        guard let coord = destinationCoordinate else { return }
        let dep = departureDate
        let ret = returnDate
        Task { @MainActor [weak self] in
            let profile = await WeatherService.fetchProfile(for: coord, from: dep, to: ret)
            self?.weather = profile
        }
    }

    private func inferRegion(from destination: String) -> TravelRegion {
        let s = destination.lowercased()

        if s.contains("canada") { return .canada }
        if s.contains("united states") || s.contains(", usa") { return .us }
        if s.contains("japan") { return .japan }

        let europeKeywords = [
            "france", "germany", "united kingdom", "england", "scotland", "wales", "ireland",
            "italy", "spain", "netherlands", "portugal", "switzerland", "austria", "belgium",
            "sweden", "norway", "denmark", "finland", "greece", "poland", "czechia",
            "czech republic", "hungary", "romania", "croatia", "europe",
            "paris", "london", "berlin", "rome", "madrid", "amsterdam", "barcelona",
            "lisbon", "brussels", "zurich", "vienna", "prague", "milan", "munich",
            "florence", "venice", "edinburgh", "dublin", "stockholm", "oslo", "copenhagen",
        ]
        if europeKeywords.contains(where: s.contains) { return .europe }

        let asiaKeywords = [
            "korea", "china", "thailand", "vietnam", "singapore", "india", "hong kong",
            "taiwan", "indonesia", "malaysia", "philippines", "cambodia", "myanmar",
            "laos", "sri lanka", "nepal", "bangladesh", "pakistan",
            "seoul", "beijing", "shanghai", "guangzhou", "bangkok", "hanoi",
            "ho chi minh", "mumbai", "delhi", "kolkata", "chennai", "kuala lumpur",
            "jakarta", "manila", "taipei",
        ]
        if asiaKeywords.contains(where: s.contains) { return .asia }

        return .other
    }

    // MARK: - Create trip

    @MainActor
    func createTrip(
        sessions:    any TripSessionRepository,
        tripItems:   any TripItemRepository,
        masterItems: any MasterItemRepository
    ) async {
        let session = TripSession(
            name:                 finalTripName,
            destination:          destination.trimmingCharacters(in: .whitespaces),
            region:               region,
            departureDate:        departureDate,
            returnDate:           returnDate,
            purposes:             Array(purposes),
            weather:              weather,
            companions:           Array(companions),
            activities:           Array(activities),
            laundryAvailable:     laundryAvailable,
            carryOnOnly:          carryOnOnly,
            business:             purposes.contains(.business),
            interacPhone:         interacChoice.interacPhone,
            interacLaptop:        interacChoice.interacLaptop,
            hasMedicalAppointment: hasMedicalAppointment,
            status:               .planning
        )

        do {
            let activeItems = try await masterItems.fetchActive()
            let generated   = ChecklistEngine().generateItems(for: session, from: activeItems)
            try await sessions.insert(session)
            for item in generated {
                try await tripItems.insert(item)
            }
            isDone = true
        } catch {
            errorMessage = error.localizedDescription
            isGenerating = false
        }
    }
}
