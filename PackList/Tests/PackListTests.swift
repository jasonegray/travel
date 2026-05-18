import XCTest
import SwiftData
@testable import PackList

final class PackListTests: XCTestCase {
}

// MARK: - SwiftData insert/fetch round-trip regression test
//
// This test catches the bug introduced by PR #119: wrapping @Model classes inside
// a VersionedSchema enum changed their fully qualified type names, causing
// context.fetch() to return 0 immediately after context.insert() + save().

@MainActor
final class TripSessionRoundTripTests: XCTestCase {

    func testInsertAndFetchRoundTrip() throws {
        let schema = Schema([TripSession.self, TripInfo.self, MasterItem.self,
                             TripItem.self, ItemInsight.self, PendingSuggestion.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        let context = ModelContext(container)

        let session = TripSession(
            name: "Round-trip test",
            destination: "Tokyo",
            departureDate: Date(),
            returnDate: Date()
        )
        let insertedId = session.id

        context.insert(session)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<TripSession>())
        XCTAssertEqual(fetched.count, 1, "fetch() returned \(fetched.count) sessions immediately after insert+save on the same context")
        XCTAssertEqual(fetched.first?.id, insertedId, "Fetched session id does not match inserted session id")
    }
}

// MARK: - TripInfo repository integration tests

@MainActor
final class TripInfoRepositoryTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!
    var repo: SwiftDataTripInfoRepository!

    override func setUpWithError() throws {
        let schema = Schema([TripSession.self, TripInfo.self, MasterItem.self, TripItem.self,
                             ItemInsight.self, PendingSuggestion.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: config)
        context = ModelContext(container)
        repo = SwiftDataTripInfoRepository(context: context)
    }

    override func tearDown() {
        repo = nil
        context = nil
        container = nil
    }

    func testInsert_persistsInfoAndLinksToTrip() async throws {
        let trip = TripSession(name: "Test", destination: "London",
                               departureDate: Date(), returnDate: Date())
        context.insert(trip)

        let info = TripInfo(tripId: trip.id, outboundAirline: "Air Canada",
                            outboundFlightNumber: "AC 123")
        trip.tripInfo = info
        try await repo.insert(info)

        let fetched = try context.fetch(FetchDescriptor<TripInfo>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.outboundAirline, "Air Canada")
        XCTAssertEqual(fetched.first?.outboundFlightNumber, "AC 123")
    }

    func testUpdate_persistsChanges() async throws {
        let trip = TripSession(name: "Test", destination: "Paris",
                               departureDate: Date(), returnDate: Date())
        context.insert(trip)
        let info = TripInfo(tripId: trip.id, bookingReference: "XYZ123")
        trip.tripInfo = info
        try await repo.insert(info)

        info.bookingReference = "ABC456"
        try await repo.update(info)

        let fetched = try context.fetch(FetchDescriptor<TripInfo>())
        XCTAssertEqual(fetched.first?.bookingReference, "ABC456")
    }

    func testDelete_removesInfo() async throws {
        let trip = TripSession(name: "Test", destination: "Tokyo",
                               departureDate: Date(), returnDate: Date())
        context.insert(trip)
        let info = TripInfo(tripId: trip.id)
        trip.tripInfo = info
        try await repo.insert(info)

        try await repo.delete(info)

        let fetched = try context.fetch(FetchDescriptor<TripInfo>())
        XCTAssertEqual(fetched.count, 0)
    }
}

// MARK: - Seed + trip-creation integration tests

@MainActor
final class SeedAndGenerationTests: XCTestCase {

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

    func testSeedPopulatesMasterList() async throws {
        let isolated = UserDefaults(suiteName: UUID().uuidString)!
        await ImportService(repository: repos.masterItems, defaults: isolated).seedIfNeeded()

        let items = try context.fetch(FetchDescriptor<MasterItem>())
        XCTAssertGreaterThan(items.count, 200, "Expected >200 seed items, got \(items.count)")
        XCTAssertTrue(items.contains { $0.itemType == .physical }, "No .physical item found in seed data")
        XCTAssertTrue(items.contains { $0.itemType == .task },    "No .task item found in seed data")
    }

    func testTripCreationGeneratesItems() async throws {
        let isolated = UserDefaults(suiteName: UUID().uuidString)!
        await ImportService(repository: repos.masterItems, defaults: isolated).seedIfNeeded()

        let dep = Calendar.current.date(byAdding: .day, value: 14, to: .now) ?? .now
        let ret = Calendar.current.date(byAdding: .day, value: 17, to: .now) ?? .now
        let session = TripSession(
            name: "Test Conference",
            destination: "Vancouver",
            departureDate: dep,
            returnDate: ret,
            weather: .mild,
            activities: [.conference],
            carryOnOnly: true
        )

        let activeItems = try await repos.masterItems.fetchActive()
        let generated = ChecklistEngine().generateItems(for: session, from: activeItems)

        try await repos.tripSessions.insert(session)
        for item in generated {
            try await repos.tripItems.insert(item)
        }

        let tripId = session.id
        let fetched = try context.fetch(
            FetchDescriptor<TripItem>(predicate: #Predicate { $0.tripId == tripId })
        )
        XCTAssertGreaterThan(fetched.count, 0, "ChecklistEngine generated 0 items for a conference trip")
        XCTAssertTrue(fetched.allSatisfy { $0.tripId == session.id }, "Fetched TripItem has wrong tripId")
    }
}

// MARK: - Seed data validation

final class SeedDataTests: XCTestCase {

    func testSeedDataDecodesWithoutErrors() throws {
        guard let url = Bundle.main.url(forResource: "master_items", withExtension: "json")
                     ?? Bundle.main.url(forResource: "master_items", withExtension: "json",
                                        subdirectory: "SeedData") else {
            XCTFail("master_items.json not found in app bundle")
            return
        }

        let data = try Data(contentsOf: url)

        // Probe struct uses the real Swift enums — any missing case fails decode immediately
        struct SeedItemProbe: Decodable {
            let name: String
            let category: ItemCategory
            let itemType: ItemType?
            let tags: [ItemTag]
            let packingLocation: PackingLocation?
            let recommendedTiming: TaskTiming?
        }

        let items = try JSONDecoder().decode([SeedItemProbe].self, from: data)
        XCTAssertGreaterThan(items.count, 0, "Seed file decoded zero items")
    }
}
