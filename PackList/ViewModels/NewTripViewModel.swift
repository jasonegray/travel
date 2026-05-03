import Foundation

@Observable
final class NewTripViewModel {

    // MARK: - Wizard step

    enum WizardStep: Int, CaseIterable {
        case nameDestination = 1
        case dates = 2
        case region = 3
        case purpose = 4
        case weather = 5
        case companions = 6
        case activities = 7
        case carryOnOnly = 8
        case laundry = 9
        case interac = 10
        case medicalAppointments = 11
        case confirm = 12
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
    var departureDate: Date = Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now
    var returnDate:    Date = Calendar.current.date(byAdding: .day, value: 10, to: .now) ?? .now
    var region: TravelRegion = .canada
    var purposes: Set<TripPurpose> = []
    var weather: WeatherProfile = .mild
    var companions: Set<TravelCompanion> = [.solo]
    var activities: Set<ActivityType> = []
    var carryOnOnly = false
    var laundryAvailable = false
    var interacChoice: InteracChoice = .none
    var hasMedicalAppointment = false

    // MARK: - Flow state

    var currentStep: WizardStep = .nameDestination
    var isGenerating = false
    var isDone = false
    var errorMessage: String?

    // MARK: - Derived

    var wizardTitle: String {
        let shortDest = destination
            .components(separatedBy: ",").first?
            .trimmingCharacters(in: .whitespaces) ?? ""
        guard !shortDest.isEmpty else { return "New trip" }
        guard currentStep.rawValue >= WizardStep.purpose.rawValue else { return shortDest }
        return generatedTripName
    }

    var skipsMedicalStep: Bool { region == .canada || region == .us }
    var totalSteps: Int { skipsMedicalStep ? 11 : 12 }
    var displayStep: Int { currentStep == .confirm ? totalSteps : currentStep.rawValue }
    var canGoBack: Bool { currentStep != .nameDestination }
    var isLastStep: Bool { currentStep == .confirm }

    var canContinue: Bool {
        switch currentStep {
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
        let purpose: String
        if purposes.contains(.golf)          { purpose = "Golf" }
        else if purposes.contains(.business) { purpose = "Business" }
        else if purposes.contains(.personal) { purpose = "Personal" }
        else if purposes.contains(.family)   { purpose = "Family" }
        else                                 { purpose = "Trip" }
        return "\(dest) · \(purpose) · \(formattedDateRange)"
    }

    var finalTripName: String {
        tripName.trimmingCharacters(in: .whitespaces).isEmpty ? generatedTripName : tripName
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
        case .nameDestination:  currentStep = .dates
        case .dates:
            region = inferRegion(from: destination)
            currentStep = .region
        case .region:           currentStep = .purpose
        case .purpose:          currentStep = .weather
        case .weather:          currentStep = .companions
        case .companions:
            if purposes.contains(.golf) { activities.insert(.golf) }
            currentStep = .activities
        case .activities:       currentStep = .carryOnOnly
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
        case .nameDestination:      break
        case .dates:                currentStep = .nameDestination
        case .region:               currentStep = .dates
        case .purpose:              currentStep = .region
        case .weather:              currentStep = .purpose
        case .companions:           currentStep = .weather
        case .activities:           currentStep = .companions
        case .carryOnOnly:          currentStep = .activities
        case .laundry:              currentStep = .carryOnOnly
        case .interac:              currentStep = .laundry
        case .medicalAppointments:  currentStep = .interac
        case .confirm:
            skipsMedicalStep ? (currentStep = .interac) : (currentStep = .medicalAppointments)
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
            "jakarta", "manila", "taipei", "ho chi minh",
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
