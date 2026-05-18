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
