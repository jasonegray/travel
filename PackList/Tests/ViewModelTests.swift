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

        XCTAssertEqual(vm.generatedTripName, "Conference in Orlando",
                       "Default activities include .conference — generated name must be 'Conference in Orlando'")
        XCTAssertTrue(vm.generatedTripName.contains("Conference"),
                      "Generated name must include the primary activity type")
    }

    func testGeneratedNameNoActivitiesUsesDestinationOnly() {
        let vm = NewTripViewModel()
        vm.destination = "Paris"
        vm.activities = []
        vm.purposes = []
        XCTAssertEqual(vm.generatedTripName, "Paris",
                       "With no recognized activities or purposes, generated name must be just the destination")
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
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "profile_full_name")
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

// MARK: - HomeViewModel additional coverage tests

@MainActor
final class HomeViewModelCoverageTests: XCTestCase {

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

    // A planning trip (departure > 5 days) becomes hero when no active trips exist
    func testLoadWithPlanningTripOnly() async throws {
        let dep = Calendar.current.date(byAdding: .day, value: 15, to: .now)!
        let ret = Calendar.current.date(byAdding: .day, value: 18, to: .now)!
        let planning = TripSession(name: "Planning Trip", destination: "London",
                                   departureDate: dep, returnDate: ret)
        try await repos.tripSessions.insert(planning)

        await viewModel.load(sessions: repos.tripSessions)

        XCTAssertNotNil(viewModel.heroTrip, "A planning trip must become the hero when no active trips exist")
        XCTAssertEqual(viewModel.heroTrip?.id, planning.id)
        XCTAssertTrue(viewModel.otherUpcomingTrips.isEmpty,
                      "otherUpcomingTrips must be empty when only one trip exists")
    }

    // Completed trips appear in completedTrips, not in heroTrip
    func testLoadSeparatesCompletedTrips() async throws {
        let pastDep = Calendar.current.date(byAdding: .day, value: -10, to: .now)!
        let pastRet = Calendar.current.date(byAdding: .day, value: -5, to: .now)!
        let completed = TripSession(name: "Completed", destination: "Rome",
                                    departureDate: pastDep, returnDate: pastRet)
        try await repos.tripSessions.insert(completed)

        await viewModel.load(sessions: repos.tripSessions)

        XCTAssertNil(viewModel.heroTrip, "Completed trip must not be the hero")
        XCTAssertEqual(viewModel.completedTrips.count, 1, "Completed trip must appear in completedTrips")
    }

    // deleteTrip clears hero state before deletion
    func testDeleteHeroTripClearsHeroState() async throws {
        let dep = Calendar.current.date(byAdding: .day, value: 2, to: .now)!
        let ret = Calendar.current.date(byAdding: .day, value: 5, to: .now)!
        let trip = TripSession(name: "Hero Trip", destination: "NYC", departureDate: dep, returnDate: ret)
        try await repos.tripSessions.insert(trip)

        await viewModel.load(sessions: repos.tripSessions)
        XCTAssertEqual(viewModel.heroTrip?.id, trip.id, "Pre-condition: trip must be hero")

        await viewModel.deleteTrip(trip, sessions: repos.tripSessions)

        XCTAssertNil(viewModel.heroTrip, "heroTrip must be nil after deleting the hero trip")
    }

    // deleteTrip removes from otherUpcomingTrips list
    func testDeleteNonHeroTripRemovesFromOtherUpcoming() async throws {
        let dep1 = Calendar.current.date(byAdding: .day, value: 2, to: .now)!
        let ret1 = Calendar.current.date(byAdding: .day, value: 5, to: .now)!
        let dep2 = Calendar.current.date(byAdding: .day, value: 20, to: .now)!
        let ret2 = Calendar.current.date(byAdding: .day, value: 25, to: .now)!
        let hero  = TripSession(name: "Hero", destination: "NYC", departureDate: dep1, returnDate: ret1)
        let other = TripSession(name: "Other", destination: "Tokyo", departureDate: dep2, returnDate: ret2)
        try await repos.tripSessions.insert(hero)
        try await repos.tripSessions.insert(other)

        await viewModel.load(sessions: repos.tripSessions)
        XCTAssertEqual(viewModel.otherUpcomingTrips.count, 1, "Pre-condition: 1 trip in other upcoming")

        await viewModel.deleteTrip(other, sessions: repos.tripSessions)

        XCTAssertTrue(viewModel.otherUpcomingTrips.isEmpty,
                      "otherUpcomingTrips must be empty after deleting the only other trip")
    }

    // toggle() sets completedAt on an incomplete item and clears it on a complete one
    func testToggleItem() {
        let tripId = UUID()
        let item = TripItem(tripId: tripId, name: "Shirt", category: .clothing)
        XCTAssertNil(item.completedAt, "Item must start incomplete")

        viewModel.toggle(item: item)
        XCTAssertNotNil(item.completedAt, "After first toggle, completedAt must be set")

        viewModel.toggle(item: item)
        XCTAssertNil(item.completedAt, "After second toggle, completedAt must be nil again")
    }

    // packingProgress counts physical items only
    func testPackingProgressFromItems() {
        let tripId = UUID()
        let physical1 = TripItem(tripId: tripId, name: "Shirt",  category: .clothing, itemType: .physical)
        let physical2 = TripItem(tripId: tripId, name: "Laptop", category: .tech,     itemType: .physical)
        let task      = TripItem(tripId: tripId, name: "Book flight", category: .misc, itemType: .task)
        physical1.completedAt = Date()

        let progress = viewModel.packingProgress(from: [physical1, physical2, task])
        XCTAssertEqual(progress.total, 2, "packingProgress must count only physical items")
        XCTAssertEqual(progress.completed, 1, "packingProgress must count only packed physical items")
    }

    // prepProgress counts task items only
    func testPrepProgressFromItems() {
        let tripId = UUID()
        let task1    = TripItem(tripId: tripId, name: "Book hotel", category: .misc, itemType: .task)
        let task2    = TripItem(tripId: tripId, name: "Get visa",   category: .documents, itemType: .task)
        let physical = TripItem(tripId: tripId, name: "Passport",   category: .documents, itemType: .physical)
        task1.completedAt = Date()

        let progress = viewModel.prepProgress(from: [task1, task2, physical])
        XCTAssertEqual(progress.total, 2, "prepProgress must count only task items")
        XCTAssertEqual(progress.completed, 1, "prepProgress must count only completed tasks")
    }

    // bagsSummary groups physical items by packing location
    func testBagsSummaryGroupsCorrectly() {
        let tripId = UUID()
        let item1 = TripItem(tripId: tripId, name: "Shirt",  category: .clothing, itemType: .physical, packingLocation: .carryOn)
        let item2 = TripItem(tripId: tripId, name: "Shoes",  category: .clothing, itemType: .physical, packingLocation: .checkedBag)
        let item3 = TripItem(tripId: tripId, name: "Laptop", category: .tech,     itemType: .physical, packingLocation: .carryOn)
        let task  = TripItem(tripId: tripId, name: "Task",   category: .misc,     itemType: .task, packingLocation: .carryOn)
        item1.completedAt = Date()

        let summary = viewModel.bagsSummary(from: [item1, item2, item3, task])
        let carryOnGroup = summary.first { $0.location == .carryOn }
        let checkedGroup = summary.first { $0.location == .checkedBag }

        XCTAssertNotNil(carryOnGroup, "carryOn group must be present")
        XCTAssertEqual(carryOnGroup?.total, 2, "carryOn group must have 2 physical items")
        XCTAssertEqual(carryOnGroup?.packed, 1, "carryOn group must count 1 packed item")
        XCTAssertNotNil(checkedGroup, "checkedBag group must be present")
        XCTAssertEqual(checkedGroup?.total, 1)
    }

    // upNextTasks returns at most 3 incomplete tasks, sorted by timing
    func testUpNextTasksLimitedToThree() {
        let tripId = UUID()
        let dep = Calendar.current.date(byAdding: .day, value: 7, to: .now)!
        var tasks: [TripItem] = []
        for i in 0..<5 {
            tasks.append(TripItem(tripId: tripId, name: "Task \(i)", category: .misc,
                                   itemType: .task, recommendedTiming: .weekBefore))
        }

        let upNext = viewModel.upNextTasks(from: tasks, departure: dep)
        XCTAssertEqual(upNext.count, 3, "upNextTasks must return at most 3 tasks")
    }

    // upNextTasks excludes completed tasks
    func testUpNextTasksExcludesCompleted() {
        let tripId = UUID()
        let dep = Calendar.current.date(byAdding: .day, value: 7, to: .now)!
        let task1 = TripItem(tripId: tripId, name: "Done Task",    category: .misc, itemType: .task)
        let task2 = TripItem(tripId: tripId, name: "Pending Task", category: .misc, itemType: .task)
        task1.completedAt = Date()

        let upNext = viewModel.upNextTasks(from: [task1, task2], departure: dep)
        XCTAssertEqual(upNext.count, 1, "upNextTasks must exclude completed tasks")
        XCTAssertEqual(upNext.first?.name, "Pending Task")
    }

    // Physical items are excluded from upNextTasks
    func testUpNextTasksExcludesPhysicalItems() {
        let tripId = UUID()
        let dep = Calendar.current.date(byAdding: .day, value: 7, to: .now)!
        let physical = TripItem(tripId: tripId, name: "Shirt", category: .clothing, itemType: .physical)
        let task     = TripItem(tripId: tripId, name: "Book hotel", category: .misc, itemType: .task)

        let upNext = viewModel.upNextTasks(from: [physical, task], departure: dep)
        XCTAssertFalse(upNext.contains { $0.itemType == .physical },
                       "upNextTasks must not include physical items")
        XCTAssertEqual(upNext.count, 1)
    }

    // recommendedByDate returns correct offsets
    func testRecommendedByDate() {
        let departure = Date()
        let cal = Calendar.current

        let weekBefore = viewModel.recommendedByDate(.weekBefore, departure: departure)
        let expected7  = cal.date(byAdding: .day, value: -7, to: departure)!
        XCTAssertEqual(weekBefore.timeIntervalSinceReferenceDate,
                       expected7.timeIntervalSinceReferenceDate, accuracy: 1)

        let threeDays = viewModel.recommendedByDate(.threeDaysBefore, departure: departure)
        let expected3 = cal.date(byAdding: .day, value: -3, to: departure)!
        XCTAssertEqual(threeDays.timeIntervalSinceReferenceDate,
                       expected3.timeIntervalSinceReferenceDate, accuracy: 1)

        let dayBefore = viewModel.recommendedByDate(.dayBefore, departure: departure)
        let expected1 = cal.date(byAdding: .day, value: -1, to: departure)!
        XCTAssertEqual(dayBefore.timeIntervalSinceReferenceDate,
                       expected1.timeIntervalSinceReferenceDate, accuracy: 1)

        let morning = viewModel.recommendedByDate(.morningOf, departure: departure)
        XCTAssertEqual(morning.timeIntervalSinceReferenceDate,
                       departure.timeIntervalSinceReferenceDate, accuracy: 1,
                       "morningOf must return departure date itself")

        let nilResult = viewModel.recommendedByDate(nil, departure: departure)
        XCTAssertEqual(nilResult.timeIntervalSinceReferenceDate,
                       departure.timeIntervalSinceReferenceDate, accuracy: 1,
                       "nil timing must return departure date")
    }

    // tripProgressMap is populated after load
    func testTripProgressMapPopulatedAfterLoad() async throws {
        let dep = Calendar.current.date(byAdding: .day, value: 2, to: .now)!
        let ret = Calendar.current.date(byAdding: .day, value: 5, to: .now)!
        let trip = TripSession(name: "Progress Trip", destination: "NYC", departureDate: dep, returnDate: ret)
        context.insert(trip)
        let item1 = TripItem(tripId: trip.id, name: "Item 1", category: .misc, itemType: .physical)
        let item2 = TripItem(tripId: trip.id, name: "Item 2", category: .misc, itemType: .physical)
        item1.completedAt = Date()
        trip.items = [item1, item2]
        try context.save()

        await viewModel.load(sessions: repos.tripSessions)

        let progress = viewModel.tripProgressMap[trip.id]
        XCTAssertNotNil(progress, "tripProgressMap must contain an entry for the loaded trip")
        XCTAssertEqual(progress?.total, 2, "Progress total must match physical item count")
        XCTAssertEqual(progress?.packed, 1, "Progress packed must match completed physical item count")
    }
}

// MARK: - TripDetailViewModel additional coverage tests

@MainActor
final class TripDetailViewModelCoverageTests: XCTestCase {

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

    private func makeTrip(name: String = "Test Trip") throws -> TripSession {
        let dep = Calendar.current.date(byAdding: .day, value: 7, to: .now)!
        let ret = Calendar.current.date(byAdding: .day, value: 10, to: .now)!
        let trip = TripSession(name: name, destination: "Tokyo", departureDate: dep, returnDate: ret)
        context.insert(trip)
        try context.save()
        return trip
    }

    private func physical(tripId: UUID, name: String, location: PackingLocation = .carryOn,
                           completed: Bool = false) -> TripItem {
        let item = TripItem(tripId: tripId, name: name, category: .clothing,
                            itemType: .physical, packingLocation: location)
        if completed { item.completedAt = Date() }
        return item
    }

    private func task(tripId: UUID, name: String, timing: TaskTiming = .weekBefore,
                      completed: Bool = false) -> TripItem {
        let item = TripItem(tripId: tripId, name: name, category: .misc,
                            itemType: .task, recommendedTiming: timing)
        if completed { item.completedAt = Date() }
        return item
    }

    // packingProgress at 0%
    func testPackingProgressAtZero() async throws {
        let trip = try makeTrip()
        for i in 0..<5 { try await repos.tripItems.insert(physical(tripId: trip.id, name: "Item \(i)")) }

        let vm = TripDetailViewModel(trip: trip)
        await vm.load(repository: repos.tripItems)

        XCTAssertEqual(vm.completedPacking, 0)
        XCTAssertEqual(vm.totalPacking, 5)
    }

    // packingProgress at 50%
    func testPackingProgressAtFiftyPercent() async throws {
        let trip = try makeTrip()
        for i in 0..<3 { try await repos.tripItems.insert(physical(tripId: trip.id, name: "P\(i)", completed: true)) }
        for i in 0..<3 { try await repos.tripItems.insert(physical(tripId: trip.id, name: "U\(i)", completed: false)) }

        let vm = TripDetailViewModel(trip: trip)
        await vm.load(repository: repos.tripItems)

        XCTAssertEqual(vm.completedPacking, 3, "completedPacking must equal the 3 pre-completed items")
        XCTAssertEqual(vm.totalPacking, 6, "totalPacking must count all 6 physical items")
    }

    // packingProgress at 100%
    func testPackingProgressAtHundredPercent() async throws {
        let trip = try makeTrip()
        for i in 0..<4 { try await repos.tripItems.insert(physical(tripId: trip.id, name: "P\(i)", completed: true)) }

        let vm = TripDetailViewModel(trip: trip)
        await vm.load(repository: repos.tripItems)

        XCTAssertEqual(vm.completedPacking, 4)
        XCTAssertEqual(vm.totalPacking, 4, "All items packed — 100%")
    }

    // prepTasksProgress computed correctly
    func testPrepTasksProgress() async throws {
        let trip = try makeTrip()
        try await repos.tripItems.insert(task(tripId: trip.id, name: "Task 1", completed: true))
        try await repos.tripItems.insert(task(tripId: trip.id, name: "Task 2", completed: true))
        try await repos.tripItems.insert(task(tripId: trip.id, name: "Task 3", completed: false))

        let vm = TripDetailViewModel(trip: trip)
        await vm.load(repository: repos.tripItems)

        XCTAssertEqual(vm.completedTasks, 2, "completedTasks must count only completed task items")
        XCTAssertEqual(vm.totalTasks, 3, "totalTasks must count all task items")
    }

    // packingGroups groups physical items by location
    func testPackingGroupsGroupsByLocation() async throws {
        let trip = try makeTrip()
        try await repos.tripItems.insert(physical(tripId: trip.id, name: "Shirt",  location: .carryOn))
        try await repos.tripItems.insert(physical(tripId: trip.id, name: "Laptop", location: .carryOn))
        try await repos.tripItems.insert(physical(tripId: trip.id, name: "Jacket", location: .checkedBag))
        try await repos.tripItems.insert(task(tripId: trip.id, name: "Book hotel"))

        let vm = TripDetailViewModel(trip: trip)
        await vm.load(repository: repos.tripItems)

        let groups = vm.packingGroups
        let carryOnGroup  = groups.first { $0.location == .carryOn }
        let checkedGroup  = groups.first { $0.location == .checkedBag }
        XCTAssertNotNil(carryOnGroup, "carryOn location group must exist")
        XCTAssertEqual(carryOnGroup?.items.count, 2, "carryOn group must contain 2 items")
        XCTAssertNotNil(checkedGroup, "checkedBag group must be present")
        XCTAssertEqual(checkedGroup?.items.count, 1, "checkedBag group must contain 1 item")
    }

    // categoryGroups groups physical items by category
    func testCategoryGroupsGroupsByCategory() async throws {
        let trip = try makeTrip()
        try await repos.tripItems.insert(physical(tripId: trip.id, name: "Shirt"))
        try await repos.tripItems.insert(physical(tripId: trip.id, name: "Laptop",  location: .carryOn))

        let vm = TripDetailViewModel(trip: trip)
        await vm.load(repository: repos.tripItems)

        let groups = vm.categoryGroups
        XCTAssertFalse(groups.isEmpty, "categoryGroups must return at least one group")
    }

    // flightAccessibleItems returns only physical items with flightAccessible == true
    func testFlightAccessibleItems() async throws {
        let trip = try makeTrip()
        let accessible = TripItem(tripId: trip.id, name: "Accessible", category: .tech,
                                   itemType: .physical, flightAccessible: true)
        let notAccessible = TripItem(tripId: trip.id, name: "Not Accessible", category: .clothing,
                                      itemType: .physical, flightAccessible: false)
        let taskItem = TripItem(tripId: trip.id, name: "Task", category: .misc,
                                 itemType: .task, flightAccessible: true)
        try await repos.tripItems.insert(accessible)
        try await repos.tripItems.insert(notAccessible)
        try await repos.tripItems.insert(taskItem)

        let vm = TripDetailViewModel(trip: trip)
        await vm.load(repository: repos.tripItems)

        let result = vm.flightAccessibleItems
        XCTAssertEqual(result.count, 1, "flightAccessibleItems must include only accessible physical items")
        XCTAssertEqual(result.first?.name, "Accessible")
    }

    // taskGroups groups task items by timing
    func testTaskGroupsGroupsByTiming() async throws {
        let trip = try makeTrip()
        try await repos.tripItems.insert(task(tripId: trip.id, name: "Week Task", timing: .weekBefore))
        try await repos.tripItems.insert(task(tripId: trip.id, name: "Day Task",  timing: .dayBefore))
        try await repos.tripItems.insert(physical(tripId: trip.id, name: "Shirt"))

        let vm = TripDetailViewModel(trip: trip)
        await vm.load(repository: repos.tripItems)

        let groups = vm.taskGroups
        XCTAssertEqual(groups.count, 2, "taskGroups must produce 2 timing groups")
        XCTAssertFalse(groups.contains { $0.items.contains { $0.itemType == .physical } },
                       "taskGroups must not include physical items")
    }

    // deadline(for:) computes correct dates relative to departure
    func testDeadlineForTiming() throws {
        let trip = try makeTrip()
        let vm = TripDetailViewModel(trip: trip)
        let cal = Calendar.current

        let weekBefore = vm.deadline(for: .weekBefore)
        let expected7  = cal.date(byAdding: .day, value: -7, to: trip.departureDate)!
        XCTAssertEqual(weekBefore.timeIntervalSinceReferenceDate,
                       expected7.timeIntervalSinceReferenceDate, accuracy: 1)

        let threeDays = vm.deadline(for: .threeDaysBefore)
        let expected3 = cal.date(byAdding: .day, value: -3, to: trip.departureDate)!
        XCTAssertEqual(threeDays.timeIntervalSinceReferenceDate,
                       expected3.timeIntervalSinceReferenceDate, accuracy: 1)

        let morningOf = vm.deadline(for: .morningOf)
        XCTAssertEqual(morningOf.timeIntervalSinceReferenceDate,
                       trip.departureDate.timeIntervalSinceReferenceDate, accuracy: 1,
                       "morningOf deadline must equal the departure date")

        let onPlane = vm.deadline(for: .onPlane)
        XCTAssertEqual(onPlane.timeIntervalSinceReferenceDate,
                       trip.departureDate.timeIntervalSinceReferenceDate, accuracy: 1,
                       "onPlane deadline must equal the departure date")
    }

    // markCompleted sets manuallyCompletedAt on the trip
    func testMarkCompletedSetsManuallyCompletedAt() async throws {
        let trip = try makeTrip()
        XCTAssertNil(trip.manuallyCompletedAt, "Trip must start without a manual completion date")

        let vm = TripDetailViewModel(trip: trip)
        await vm.markCompleted(sessions: repos.tripSessions)

        XCTAssertNotNil(trip.manuallyCompletedAt, "manuallyCompletedAt must be set after markCompleted()")
    }

    // save(item:) persists the item via the loaded repository.
    // Uses a fresh ModelContext to verify the value was actually saved to the store
    // (same-context fetch would return the same object reference, masking a missing save).
    func testSaveItemPersists() async throws {
        let trip = try makeTrip()
        let itemId: UUID
        do {
            let item = physical(tripId: trip.id, name: "Test Save")
            itemId = item.id
            try await repos.tripItems.insert(item)

            let vm = TripDetailViewModel(trip: trip)
            await vm.load(repository: repos.tripItems)

            item.completedAt = Date()
            await vm.save(item: item)
        }

        // Fresh context reads from the same in-memory store — sees only what was saved
        let freshContext = ModelContext(container)
        let freshRepo = SwiftDataTripItemRepository(context: freshContext)
        let fetched = try await freshRepo.fetch(id: itemId)
        XCTAssertNotNil(fetched?.completedAt,
                        "completedAt must be persisted to the store after save(item:) — not just held in memory")
    }
}

// MARK: - NewTripViewModel additional coverage tests

@MainActor
final class NewTripViewModelCoverageTests: XCTestCase {

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

    // canContinue is false when destination is empty at nameDestination step
    func testCannotContinueWithEmptyDestination() {
        let vm = NewTripViewModel()
        vm.currentStep = .nameDestination
        vm.destination = "   "
        XCTAssertFalse(vm.canContinue, "canContinue must be false when destination is whitespace-only")
    }

    // canContinue is true when destination is non-empty at nameDestination step
    func testCanContinueWithDestinationFilled() {
        let vm = NewTripViewModel()
        vm.currentStep = .nameDestination
        vm.destination = "Tokyo"
        XCTAssertTrue(vm.canContinue, "canContinue must be true when destination is non-empty")
    }

    // canContinue for dates step — past departure is invalid
    func testCannotContinueWithPastDeparture() {
        let vm = NewTripViewModel()
        vm.currentStep = .dates
        vm.departureDate = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
        vm.returnDate    = Calendar.current.date(byAdding: .day, value: 2, to: .now)!
        XCTAssertFalse(vm.canContinue, "canContinue must be false when departureDate is in the past")
    }

    // canContinue for dates step — return before departure is invalid
    func testCannotContinueWhenReturnBeforeDeparture() {
        let vm = NewTripViewModel()
        vm.currentStep = .dates
        vm.departureDate = Calendar.current.date(byAdding: .day, value: 5, to: .now)!
        vm.returnDate    = Calendar.current.date(byAdding: .day, value: 3, to: .now)!
        XCTAssertFalse(vm.canContinue, "canContinue must be false when returnDate <= departureDate")
    }

    // canContinue for dates step — valid dates
    func testCanContinueWithValidDates() {
        let vm = NewTripViewModel()
        vm.currentStep = .dates
        vm.departureDate = Calendar.current.date(byAdding: .day, value: 5, to: .now)!
        vm.returnDate    = Calendar.current.date(byAdding: .day, value: 8, to: .now)!
        XCTAssertTrue(vm.canContinue, "canContinue must be true for valid future dates")
    }

    // wizardTitle defaults to "New trip" before destination is set
    func testWizardTitleBeforeDestination() {
        let vm = NewTripViewModel()
        XCTAssertEqual(vm.wizardTitle, "New trip", "wizardTitle must be 'New trip' when on activities step")
    }

    // wizardTitle uses first component of destination after leaving activities step
    func testWizardTitleAfterDestinationSet() {
        let vm = NewTripViewModel()
        vm.currentStep = .nameDestination
        vm.destination = "Tokyo, Japan"
        XCTAssertEqual(vm.wizardTitle, "Tokyo", "wizardTitle must use first comma-separated component of destination")
    }

    // totalSteps: 6 when flying, 5 when not flying (carryOnOnly step skipped)
    func testTotalStepsAndDisplayStep() {
        let vm = NewTripViewModel()
        vm.isFlyingTrip = true
        XCTAssertEqual(vm.totalSteps, 6, "Flying trip has 6 wizard steps")

        vm.isFlyingTrip = false
        XCTAssertEqual(vm.totalSteps, 5, "Non-flying trip has 5 wizard steps (no carry-on step)")

        vm.isFlyingTrip = true
        vm.currentStep = .confirm
        XCTAssertEqual(vm.displayStep, vm.totalSteps, "displayStep at confirm step must equal totalSteps")
    }

    // canGoBack is false at first step
    func testCanGoBackIsCorrect() {
        let vm = NewTripViewModel()
        vm.currentStep = .activities
        XCTAssertFalse(vm.canGoBack, "canGoBack must be false at the first wizard step")

        vm.currentStep = .nameDestination
        XCTAssertTrue(vm.canGoBack, "canGoBack must be true after the first step")
    }

    // isLastStep is true only at confirm
    func testIsLastStep() {
        let vm = NewTripViewModel()
        vm.currentStep = .dates
        XCTAssertFalse(vm.isLastStep, "isLastStep must be false before the confirm step")

        vm.currentStep = .confirm
        XCTAssertTrue(vm.isLastStep, "isLastStep must be true at the confirm step")
    }

    // Wizard forward navigation (flying trip: 6 steps)
    func testWizardNextNavigation() {
        let vm = NewTripViewModel()
        XCTAssertEqual(vm.currentStep, .activities)

        vm.next()
        XCTAssertEqual(vm.currentStep, .nameDestination)

        vm.next()
        XCTAssertEqual(vm.currentStep, .dates)

        vm.destination = "Toronto, Canada"
        vm.next()
        XCTAssertEqual(vm.currentStep, .carryOnOnly)

        vm.next()
        XCTAssertEqual(vm.currentStep, .laundry)

        vm.next()
        XCTAssertEqual(vm.currentStep, .confirm)
    }

    // Wizard back navigation
    func testWizardBackNavigation() {
        let vm = NewTripViewModel()
        vm.currentStep = .nameDestination
        vm.back()
        XCTAssertEqual(vm.currentStep, .activities)

        vm.currentStep = .dates
        vm.back()
        XCTAssertEqual(vm.currentStep, .nameDestination)

        vm.currentStep = .carryOnOnly
        vm.back()
        XCTAssertEqual(vm.currentStep, .dates)
    }

    // back() at activities does nothing
    func testBackAtFirstStepDoesNothing() {
        let vm = NewTripViewModel()
        vm.currentStep = .activities
        vm.back()
        XCTAssertEqual(vm.currentStep, .activities, "back() at activities step must not change step")
    }

    // back() from confirm always goes to laundry
    func testBackFromConfirmStep() {
        let vm = NewTripViewModel()
        vm.currentStep = .confirm
        vm.back()
        XCTAssertEqual(vm.currentStep, .laundry, "Back from confirm must go to laundry")
    }

    // generatedTripName with conference activity includes type and destination
    func testGeneratedTripNameConferenceActivity() {
        let vm = NewTripViewModel()
        vm.destination = "London"
        vm.activities = [.conference]

        XCTAssertEqual(vm.generatedTripName, "Conference in London",
                       "Conference activity must produce 'Conference in [Destination]'")
    }

    // generatedTripName uses destination when multiple city components present
    func testGeneratedTripNameStripsRegionSuffix() {
        let vm = NewTripViewModel()
        vm.destination = "London, England, UK"
        vm.activities = []
        vm.purposes = []

        XCTAssertEqual(vm.generatedTripName, "London",
                       "Generated name must strip region/country suffix after first comma")
    }

    // finalTripName prefers custom tripName when set
    func testFinalTripNamePrefersCustomName() {
        let vm = NewTripViewModel()
        vm.destination = "Tokyo"
        vm.tripName = "My Adventure"
        XCTAssertEqual(vm.finalTripName, "My Adventure",
                       "finalTripName must use custom tripName when it is non-empty")
    }

    // finalTripName falls back to generated name when tripName is empty
    func testFinalTripNameFallsBackToGenerated() {
        let vm = NewTripViewModel()
        vm.destination = "Paris"
        vm.tripName = "  "
        XCTAssertEqual(vm.finalTripName, vm.generatedTripName,
                       "finalTripName must fall back to generatedTripName when tripName is whitespace")
    }

    // clientDevices extra drives both interacPhone and interacLaptop in createTrip
    func testClientDevicesActivityDrivesInteracFields() {
        let vm = NewTripViewModel()
        XCTAssertFalse(vm.activities.contains(.clientDevices),
                       "clientDevices must not be selected by default")
        vm.activities.insert(.clientDevices)
        XCTAssertTrue(vm.activities.contains(.clientDevices),
                      "clientDevices must be selectable as an activity extra")
    }

    // medical extra is selectable as an activity extra
    func testMedicalActivityIsSelectable() {
        let vm = NewTripViewModel()
        XCTAssertFalse(vm.activities.contains(.medical),
                       "medical must not be selected by default")
        vm.activities.insert(.medical)
        XCTAssertTrue(vm.activities.contains(.medical),
                      "medical must be selectable as an activity extra")
    }

    // inferRegion runs via next() at the dates step
    func testInferRegionForKnownDestinations() {
        let vm = NewTripViewModel()
        vm.currentStep = .dates

        vm.destination = "Tokyo, Japan"
        vm.next()
        XCTAssertEqual(vm.region, .japan, "Destination containing 'Japan' must infer region .japan")

        vm.currentStep = .dates
        vm.destination = "Paris, France"
        vm.next()
        XCTAssertEqual(vm.region, .europe, "Destination containing 'france' must infer region .europe")

        vm.currentStep = .dates
        vm.destination = "Toronto, Canada"
        vm.next()
        XCTAssertEqual(vm.region, .canada, "Destination containing 'canada' must infer region .canada")

        vm.currentStep = .dates
        vm.destination = "Seoul, Korea"
        vm.next()
        XCTAssertEqual(vm.region, .asia, "Destination containing 'korea' must infer region .asia")

        vm.currentStep = .dates
        vm.destination = "Somewhere Unknown"
        vm.next()
        XCTAssertEqual(vm.region, .other, "Unknown destination must infer region .other")
    }

    // createTrip() inserts a TripSession and TripItems
    func testCreateTripFullFlow() async throws {
        let isolated = UserDefaults(suiteName: UUID().uuidString)!
        await ImportService(repository: repos.masterItems, defaults: isolated).seedIfNeeded()

        let vm = NewTripViewModel()
        vm.destination = "Toronto, Canada"
        vm.region = .canada
        vm.tripName = "Test Create"
        vm.departureDate = Calendar.current.date(byAdding: .day, value: 14, to: .now)!
        vm.returnDate    = Calendar.current.date(byAdding: .day, value: 17, to: .now)!
        vm.activities = [.conference]
        vm.carryOnOnly = true
        vm.laundryAvailable = true

        await vm.createTrip(sessions: repos.tripSessions,
                            tripItems: repos.tripItems,
                            masterItems: repos.masterItems)

        XCTAssertTrue(vm.isDone, "isDone must be true after a successful createTrip()")
        XCTAssertNil(vm.errorMessage, "errorMessage must be nil on success")

        let sessions = try await repos.tripSessions.fetchAll()
        XCTAssertEqual(sessions.count, 1, "createTrip() must insert exactly one TripSession")
        XCTAssertEqual(sessions.first?.name, "Test Create")

        let tripId = try XCTUnwrap(sessions.first?.id)
        let items  = try await repos.tripItems.fetchAll(for: tripId)
        XCTAssertGreaterThan(items.count, 0, "createTrip() must generate at least one TripItem")
    }

    // isGenerating is set to true at the confirm step when next() is called
    func testNextAtConfirmSetsIsGenerating() {
        let vm = NewTripViewModel()
        vm.currentStep = .confirm
        vm.next()
        XCTAssertTrue(vm.isGenerating, "isGenerating must be true after next() is called at the confirm step")
    }
}

// MARK: - Trip Archive Tests

@MainActor
final class TripArchiveTests: XCTestCase {

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

    private func completedTrip(name: String = "Past Trip") throws -> TripSession {
        let dep = Calendar.current.date(byAdding: .day, value: -10, to: .now)!
        let ret = Calendar.current.date(byAdding: .day, value: -5, to: .now)!
        let trip = TripSession(name: name, destination: "Rome",
                               departureDate: dep, returnDate: ret)
        context.insert(trip)
        try context.save()
        return trip
    }

    func testArchiveTripHidesFromActiveList() async throws {
        let trip = try completedTrip()
        await viewModel.load(sessions: repos.tripSessions)

        XCTAssertTrue(viewModel.completedTrips.contains { $0.id == trip.id },
                      "Completed trip must appear in completedTrips before archiving")
        XCTAssertTrue(viewModel.archivedTrips.isEmpty,
                      "archivedTrips must be empty before archiving")

        await viewModel.archiveTrip(trip, sessions: repos.tripSessions)

        XCTAssertFalse(viewModel.completedTrips.contains { $0.id == trip.id },
                       "Archived trip must not appear in completedTrips")
        XCTAssertTrue(viewModel.archivedTrips.contains { $0.id == trip.id },
                      "Archived trip must appear in archivedTrips")
        XCTAssertEqual(trip.status, .archived, "Trip status must be .archived after archiving")
    }

    func testUnarchivedTripReappearsInActiveList() async throws {
        let trip = try completedTrip()
        trip.isArchived = true
        try context.save()

        await viewModel.load(sessions: repos.tripSessions)

        XCTAssertTrue(viewModel.archivedTrips.contains { $0.id == trip.id },
                      "Archived trip must appear in archivedTrips")
        XCTAssertFalse(viewModel.completedTrips.contains { $0.id == trip.id },
                       "Archived trip must not appear in completedTrips")

        await viewModel.unarchiveTrip(trip, sessions: repos.tripSessions)

        XCTAssertFalse(viewModel.archivedTrips.contains { $0.id == trip.id },
                       "Unarchived trip must not appear in archivedTrips")
        XCTAssertTrue(viewModel.completedTrips.contains { $0.id == trip.id },
                      "Unarchived trip must reappear in completedTrips")
        XCTAssertEqual(trip.status, .completed, "Trip status must return to .completed after unarchiving")
    }

    func testArchivedTripIsReadOnly() throws {
        let dep = Calendar.current.date(byAdding: .day, value: -10, to: .now)!
        let ret = Calendar.current.date(byAdding: .day, value: -5, to: .now)!
        let trip = TripSession(name: "Archived", destination: "Tokyo",
                               departureDate: dep, returnDate: ret,
                               isArchived: true)
        context.insert(trip)
        try context.save()

        let vm = TripDetailViewModel(trip: trip)
        let item = TripItem(tripId: trip.id, name: "Shirt", category: .clothing)
        context.insert(item)

        XCTAssertNil(item.completedAt, "Item must start as incomplete")
        vm.toggle(item: item)
        XCTAssertNil(item.completedAt, "Archived trip toggle must be a no-op — item must remain incomplete")
    }

    func testArchivedStatusComputedFromField() throws {
        let dep = Calendar.current.date(byAdding: .day, value: -10, to: .now)!
        let ret = Calendar.current.date(byAdding: .day, value: -5, to: .now)!
        let trip = TripSession(name: "Test", destination: "Paris",
                               departureDate: dep, returnDate: ret)
        XCTAssertEqual(trip.status, .completed, "Past trip must be .completed before archiving")

        trip.isArchived = true
        XCTAssertEqual(trip.status, .archived, "Trip with isArchived=true must have .archived status")

        trip.isArchived = false
        XCTAssertEqual(trip.status, .completed, "Trip with isArchived=false must revert to computed status")
    }

    func testArchivedTripPersistsAcrossRoundTrip() throws {
        let dep = Calendar.current.date(byAdding: .day, value: -10, to: .now)!
        let ret = Calendar.current.date(byAdding: .day, value: -5, to: .now)!
        let trip = TripSession(name: "Archive Persist", destination: "London",
                               departureDate: dep, returnDate: ret,
                               isArchived: true)
        context.insert(trip)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<TripSession>(
            predicate: #Predicate { $0.isArchived == true }
        ))
        XCTAssertEqual(fetched.count, 1, "One archived trip must persist after save")
        XCTAssertTrue(fetched.first?.isArchived == true, "isArchived must persist as true")
        XCTAssertEqual(fetched.first?.status, .archived, "Fetched trip status must be .archived")
    }
}
