import XCTest
import SwiftData
@testable import PackList

// MARK: - Home ViewModel Tests

@MainActor
final class HomeViewModelTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!
    var repos: RepositoryContainer!
    var viewModel: HomeViewModel!

    override func setUpWithError() throws {
        let schema = Schema([TripSession.self, TripInfo.self, MasterItem.self,
                             TripItem.self, ItemInsight.self, PendingSuggestion.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: config)
        context = ModelContext(container)
        repos = RepositoryContainer(modelContext: context)
        viewModel = HomeViewModel()
    }

    override func tearDown() {
        viewModel = nil
        repos = nil
        context = nil
        container = nil
    }

    func testHomeViewModelLoadsTrips() async throws {
        let dep1 = Calendar.current.date(byAdding: .day, value: 2, to: .now)!
        let ret1 = Calendar.current.date(byAdding: .day, value: 4, to: .now)!
        let tripA = TripSession(name: "Trip A", destination: "Orlando",
                                departureDate: dep1, returnDate: ret1)
        let dep2 = Calendar.current.date(byAdding: .day, value: 10, to: .now)!
        let ret2 = Calendar.current.date(byAdding: .day, value: 12, to: .now)!
        let tripB = TripSession(name: "Trip B", destination: "Tokyo",
                                departureDate: dep2, returnDate: ret2)

        try await repos.tripSessions.insert(tripA)
        try await repos.tripSessions.insert(tripB)

        await viewModel.load(sessions: repos.tripSessions)

        XCTAssertNotNil(viewModel.heroTrip, "heroTrip must be non-nil when active trips exist")
        XCTAssertEqual(viewModel.heroTrip?.id, tripA.id,
                       "heroTrip must be the most imminent active trip")
    }

    func testHomeViewModelEmptyState() async {
        await viewModel.load(sessions: repos.tripSessions)
        XCTAssertNil(viewModel.heroTrip, "heroTrip must be nil when no trips exist")
    }

    func testHomeViewModelMultipleTripsHeroIsCorrect() async throws {
        let dep2  = Calendar.current.date(byAdding: .day, value: 2,  to: .now)!
        let ret2  = Calendar.current.date(byAdding: .day, value: 4,  to: .now)!
        let dep10 = Calendar.current.date(byAdding: .day, value: 10, to: .now)!
        let ret10 = Calendar.current.date(byAdding: .day, value: 12, to: .now)!
        let dep30 = Calendar.current.date(byAdding: .day, value: 30, to: .now)!
        let ret30 = Calendar.current.date(byAdding: .day, value: 32, to: .now)!

        let tripSoon    = TripSession(name: "Soon",    destination: "NYC",
                                     departureDate: dep2,  returnDate: ret2)
        let tripMedium  = TripSession(name: "Medium",  destination: "London",
                                     departureDate: dep10, returnDate: ret10)
        let tripDistant = TripSession(name: "Distant", destination: "Tokyo",
                                     departureDate: dep30, returnDate: ret30)

        // Insert in reverse order to verify sorting is by date, not insertion order
        try await repos.tripSessions.insert(tripDistant)
        try await repos.tripSessions.insert(tripMedium)
        try await repos.tripSessions.insert(tripSoon)

        await viewModel.load(sessions: repos.tripSessions)

        XCTAssertEqual(viewModel.heroTrip?.id, tripSoon.id,
                       "heroTrip must be the 2-day-away active trip, not the 10- or 30-day planning trips")
    }
}

// MARK: - Trip Detail ViewModel Tests

@MainActor
final class TripDetailViewModelTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!
    var repos: RepositoryContainer!

    override func setUpWithError() throws {
        let schema = Schema([TripSession.self, TripInfo.self, MasterItem.self,
                             TripItem.self, ItemInsight.self, PendingSuggestion.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: config)
        context = ModelContext(container)
        repos = RepositoryContainer(modelContext: context)
    }

    override func tearDown() {
        repos = nil
        context = nil
        container = nil
    }

    private func insertTrip(name: String = "Test") throws -> TripSession {
        let trip = TripSession(name: name, destination: "Anywhere",
                               departureDate: Date(), returnDate: Date())
        context.insert(trip)
        try context.save()
        return trip
    }

    private func makePhysicalItem(tripId: UUID, name: String) -> TripItem {
        TripItem(tripId: tripId, name: name, category: .misc, itemType: .physical)
    }

    func testTripDetailViewModelLoadsItemsForCorrectTrip() async throws {
        let tripA = try insertTrip(name: "Trip A")
        let tripB = try insertTrip(name: "Trip B")

        for i in 0..<5 {
            try await repos.tripItems.insert(makePhysicalItem(tripId: tripA.id, name: "A-Item \(i)"))
            try await repos.tripItems.insert(makePhysicalItem(tripId: tripB.id, name: "B-Item \(i)"))
        }

        let vm = TripDetailViewModel(trip: tripA)
        await vm.load(repository: repos.tripItems)

        XCTAssertEqual(vm.items.count, 5, "Must load exactly the 5 items belonging to Trip A")
        XCTAssertTrue(vm.items.allSatisfy { $0.tripId == tripA.id },
                      "All loaded items must belong to Trip A")
        XCTAssertFalse(vm.items.contains { $0.tripId == tripB.id },
                       "No items from Trip B must appear")
    }

    func testTripDetailViewModelMarkItemComplete() async throws {
        let trip = try insertTrip()
        for i in 0..<5 {
            try await repos.tripItems.insert(makePhysicalItem(tripId: trip.id, name: "Item \(i)"))
        }

        let vm = TripDetailViewModel(trip: trip)
        await vm.load(repository: repos.tripItems)

        XCTAssertEqual(vm.items.count, 5)
        vm.toggle(item: vm.items[0])

        XCTAssertNotNil(vm.items[0].completedAt, "Toggled item must have non-nil completedAt")
        XCTAssertTrue(vm.items.dropFirst().allSatisfy { $0.completedAt == nil },
                      "Remaining 4 items must still have nil completedAt")
    }

    func testTripDetailViewModelProgress() async throws {
        let trip = try insertTrip()
        for i in 0..<10 {
            try await repos.tripItems.insert(makePhysicalItem(tripId: trip.id, name: "Item \(i)"))
        }

        let vm = TripDetailViewModel(trip: trip)
        await vm.load(repository: repos.tripItems)

        XCTAssertEqual(vm.totalPacking, 10)

        for item in vm.items.prefix(5) { vm.toggle(item: item) }

        XCTAssertEqual(vm.completedPacking, 5)
        let ratio = Double(vm.completedPacking) / Double(vm.totalPacking)
        XCTAssertEqual(ratio, 0.5, "packingProgress must be 0.5 after marking 5 of 10 items complete")
    }
}

// MARK: - New Trip ViewModel Tests

@MainActor
final class NewTripViewModelTests: XCTestCase {

    func testNewTripViewModelDefaultsAreCorrect() {
        let vm = NewTripViewModel()
        XCTAssertTrue(vm.carryOnOnly,      "Default carryOnOnly must be true")
        XCTAssertTrue(vm.laundryAvailable, "Default laundryAvailable must be true")
        XCTAssertTrue(vm.activities.contains(.conference),
                      "Default activities must include .conference")
    }

    func testNewTripViewModelGeneratedNameFormat() {
        let vm = NewTripViewModel()
        vm.destination = "Orlando"

        var depComps = DateComponents()
        depComps.year = 2027; depComps.month = 5; depComps.day = 24; depComps.hour = 12
        var retComps = DateComponents()
        retComps.year = 2027; retComps.month = 5; retComps.day = 27; retComps.hour = 12

        let cal = Calendar(identifier: .gregorian)
        vm.departureDate = cal.date(from: depComps)!
        vm.returnDate    = cal.date(from: retComps)!

        XCTAssertEqual(vm.generatedTripName, "Orlando · May 24–27",
                       "Generated name must be 'Destination · Month DayStart–DayEnd'")
        XCTAssertFalse(vm.generatedTripName.contains("Conference"),
                       "Generated name must not include activity names")
    }
}

// MARK: - TripInfoViewModel shareSummary tests

@MainActor
final class TripInfoViewModelShareTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!
    var trip: TripSession!
    var vm: TripInfoViewModel!

    override func setUpWithError() throws {
        let schema = Schema([TripSession.self, TripInfo.self, MasterItem.self,
                             TripItem.self, ItemInsight.self, PendingSuggestion.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: config)
        context = ModelContext(container)
        var comps = DateComponents()
        comps.year = 2027; comps.month = 6; comps.day = 10
        let dep = Calendar(identifier: .gregorian).date(from: comps)!
        comps.day = 17
        let ret = Calendar(identifier: .gregorian).date(from: comps)!
        trip = TripSession(name: "London Trip", destination: "London",
                           departureDate: dep, returnDate: ret)
        context.insert(trip)
        vm = TripInfoViewModel(trip: trip)
        UserDefaults.standard.removeObject(forKey: "profile_full_name")
        UserDefaults.standard.removeObject(forKey: "profile_aeroplan_number")
        UserDefaults.standard.removeObject(forKey: "profile_bonvoy_number")
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "profile_full_name")
        UserDefaults.standard.removeObject(forKey: "profile_aeroplan_number")
        UserDefaults.standard.removeObject(forKey: "profile_bonvoy_number")
        vm = nil; trip = nil; context = nil; container = nil
    }

    func testShareSummary_headerLines() {
        let summary = vm.shareSummary
        XCTAssertTrue(summary.hasPrefix("London Trip\n"), "First line must be trip name")
        XCTAssertTrue(summary.contains("London ·"), "Second line must contain destination")
    }

    func testShareSummary_omitsOutboundWhenNoFlightNumber() {
        vm.outboundAirline = "Air Canada"
        vm.outboundFlightNumber = ""
        XCTAssertFalse(vm.shareSummary.contains("OUTBOUND"), "OUTBOUND section must be absent with no flight number")
    }

    func testShareSummary_includesOutboundWhenFlightNumberSet() {
        vm.outboundAirline = "Air Canada"
        vm.outboundFlightNumber = "AC 123"
        vm.outboundDepartureAirport = "YYZ"
        vm.outboundArrivalAirport = "LHR"
        let summary = vm.shareSummary
        XCTAssertTrue(summary.contains("OUTBOUND"), "OUTBOUND section must appear when flight number is set")
        XCTAssertTrue(summary.contains("Air Canada AC 123"), "Flight line must contain airline and flight number")
        XCTAssertTrue(summary.contains("YYZ → LHR"), "Flight line must contain route")
    }

    func testShareSummary_flightAwareURL_stripsSpaces() {
        vm.outboundFlightNumber = "AC 123"
        let summary = vm.shareSummary
        XCTAssertTrue(summary.contains("https://flightaware.com/live/flight/AC123"),
                      "FlightAware URL must strip spaces from flight number")
    }

    func testShareSummary_omitsReturnWhenNoFlightNumber() {
        vm.returnFlightNumber = ""
        XCTAssertFalse(vm.shareSummary.contains("RETURN"), "RETURN section must be absent with no return flight number")
    }

    func testShareSummary_includesReturnWhenFlightNumberSet() {
        vm.returnFlightNumber = "AC 124"
        vm.returnDepartureAirport = "LHR"
        vm.returnArrivalAirport = "YYZ"
        let summary = vm.shareSummary
        XCTAssertTrue(summary.contains("RETURN"), "RETURN section must appear when return flight number is set")
        XCTAssertTrue(summary.contains("https://flightaware.com/live/flight/AC124"),
                      "RETURN FlightAware URL must strip spaces")
    }

    func testShareSummary_omitsHotelWhenNoName() {
        vm.accommodationName = ""
        XCTAssertFalse(vm.shareSummary.contains("HOTEL"), "HOTEL section must be absent with no hotel name")
    }

    func testShareSummary_hotelSection_appleMapsURL() {
        vm.accommodationName = "The Savoy"
        let summary = vm.shareSummary
        XCTAssertTrue(summary.contains("HOTEL"), "HOTEL section must appear when hotel name is set")
        XCTAssertTrue(summary.contains("The Savoy"), "Hotel name must appear in section")
        XCTAssertTrue(summary.contains("https://maps.apple.com/?q=The%20Savoy"),
                      "Apple Maps URL must be URL-encoded")
    }

    func testShareSummary_hotelSection_encodesPlusSign() {
        vm.accommodationName = "M+G London"
        let summary = vm.shareSummary
        XCTAssertTrue(summary.contains("%2B"), "Apple Maps URL must percent-encode + as %2B")
        XCTAssertFalse(summary.contains("?q=M+G"), "Literal + in query value must not appear unencoded")
    }

    func testShareSummary_omitsLoyaltyFooterWhenNoNumbers() {
        let summary = vm.shareSummary
        XCTAssertFalse(summary.contains("—"), "Loyalty footer must be absent when no numbers are set")
        XCTAssertFalse(summary.contains("Aeroplan"), "Aeroplan line must be absent")
        XCTAssertFalse(summary.contains("Marriott"), "Marriott line must be absent")
    }

    func testShareSummary_includesAeroplanWhenSet() {
        UserDefaults.standard.set("12345678", forKey: "profile_aeroplan_number")
        let summary = vm.shareSummary
        XCTAssertTrue(summary.contains("—"), "Loyalty separator must appear")
        XCTAssertTrue(summary.contains("Aeroplan Super Elite: 12345678"), "Aeroplan line must appear")
        XCTAssertFalse(summary.contains("Marriott"), "Marriott must not appear when not set")
    }

    func testShareSummary_includesBonvoyWhenSet() {
        UserDefaults.standard.set("99999999", forKey: "profile_bonvoy_number")
        let summary = vm.shareSummary
        XCTAssertTrue(summary.contains("Marriott Titanium Elite: 99999999"), "Bonvoy line must appear")
        XCTAssertFalse(summary.contains("Aeroplan"), "Aeroplan must not appear when not set")
    }

    func testShareSummary_includesFullNameWhenBothSet() {
        UserDefaults.standard.set("Jason Gray", forKey: "profile_full_name")
        UserDefaults.standard.set("12345678", forKey: "profile_aeroplan_number")
        let summary = vm.shareSummary
        XCTAssertTrue(summary.contains("Jason Gray"), "Full name must appear in footer")
    }

    func testShareSummary_omitsFullNameWhenOnlyNameSet() {
        UserDefaults.standard.set("Jason Gray", forKey: "profile_full_name")
        let summary = vm.shareSummary
        XCTAssertFalse(summary.contains("Jason Gray"),
                       "Full name alone must not trigger loyalty footer — need at least one loyalty number")
    }

    func testLoadFromModel_populatesFields() throws {
        let info = TripInfo(
            tripId: trip.id,
            outboundAirline: "United",
            outboundFlightNumber: "UA 500",
            outboundDepartureAirport: "ORD",
            outboundArrivalAirport: "LHR",
            returnFlightNumber: "UA 501",
            accommodationName: "Hilton London"
        )
        context.insert(info)
        trip.tripInfo = info

        let loaded = TripInfoViewModel(trip: trip)
        XCTAssertEqual(loaded.outboundAirline, "United")
        XCTAssertEqual(loaded.outboundFlightNumber, "UA 500")
        XCTAssertEqual(loaded.outboundDepartureAirport, "ORD")
        XCTAssertEqual(loaded.outboundArrivalAirport, "LHR")
        XCTAssertEqual(loaded.returnFlightNumber, "UA 501")
        XCTAssertEqual(loaded.accommodationName, "Hilton London")
    }

    func testSave_insertsNewTripInfo() async throws {
        let schema = Schema([TripSession.self, TripInfo.self, MasterItem.self,
                             TripItem.self, ItemInsight.self, PendingSuggestion.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let c = try ModelContainer(for: schema, configurations: config)
        let ctx = ModelContext(c)
        let repo = SwiftDataTripInfoRepository(context: ctx)

        var comps = DateComponents()
        comps.year = 2027; comps.month = 7; comps.day = 1
        let dep = Calendar(identifier: .gregorian).date(from: comps)!
        comps.day = 8
        let ret = Calendar(identifier: .gregorian).date(from: comps)!
        let t = TripSession(name: "Save Test", destination: "Paris", departureDate: dep, returnDate: ret)
        ctx.insert(t)

        let saveVm = TripInfoViewModel(trip: t)
        saveVm.loadRepository(repo)
        saveVm.outboundFlightNumber = "AF 001"
        saveVm.accommodationName = "Le Meurice"
        await saveVm.save()

        let fetched = try ctx.fetch(FetchDescriptor<TripInfo>())
        XCTAssertEqual(fetched.count, 1, "save() must insert one TripInfo record")
        XCTAssertEqual(fetched.first?.outboundFlightNumber, "AF 001")
        XCTAssertEqual(fetched.first?.accommodationName, "Le Meurice")
    }

    func testShareSummary_routeWithDepartureOnly() {
        vm.outboundFlightNumber = "AC 100"
        vm.outboundDepartureAirport = "YYZ"
        vm.outboundArrivalAirport = ""
        let summary = vm.shareSummary
        XCTAssertTrue(summary.contains("From: YYZ"), "Partial route must show 'From: <airport>'")
    }

    func testShareSummary_routeWithArrivalOnly() {
        vm.outboundFlightNumber = "AC 100"
        vm.outboundDepartureAirport = ""
        vm.outboundArrivalAirport = "LHR"
        let summary = vm.shareSummary
        XCTAssertTrue(summary.contains("To: LHR"), "Partial route must show 'To: <airport>'")
    }
}
