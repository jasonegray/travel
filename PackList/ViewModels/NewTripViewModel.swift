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

    var skipsMedicalStep: Bool { region == .canada || region == .us }
    var totalSteps: Int { skipsMedicalStep ? 10 : 11 }
    var displayStep: Int { currentStep.rawValue }
    var canGoBack: Bool { currentStep != .nameDestination }

    var isLastStep: Bool {
        skipsMedicalStep ? currentStep == .interac : currentStep == .medicalAppointments
    }

    var canContinue: Bool {
        switch currentStep {
        case .nameDestination:
            return !tripName.trimmingCharacters(in: .whitespaces).isEmpty
                && !destination.trimmingCharacters(in: .whitespaces).isEmpty
        case .dates:
            let today = Calendar.current.startOfDay(for: .now)
            let dep   = Calendar.current.startOfDay(for: departureDate)
            return dep >= today && returnDate > departureDate
        default:
            return true
        }
    }

    // MARK: - Navigation

    func next() {
        switch currentStep {
        case .nameDestination:  currentStep = .dates
        case .dates:            currentStep = .region
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
            skipsMedicalStep ? (isGenerating = true) : (currentStep = .medicalAppointments)
        case .medicalAppointments:
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
        }
    }

    // MARK: - Create trip

    @MainActor
    func createTrip(
        sessions:    any TripSessionRepository,
        tripItems:   any TripItemRepository,
        masterItems: any MasterItemRepository
    ) async {
        let session = TripSession(
            name:                 tripName.trimmingCharacters(in: .whitespaces),
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
