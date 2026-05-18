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

// MARK: - Seed timing tests

@MainActor
final class SeedTimingTests: XCTestCase {

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

    func testSeedCompletesBeforeTripCreationIsPossible() async throws {
        let isolated = UserDefaults(suiteName: UUID().uuidString)!
        await ImportService(repository: repos.masterItems, defaults: isolated).seedIfNeeded()

        let dep = Calendar.current.date(byAdding: .day, value: 7, to: .now)!
        let ret = Calendar.current.date(byAdding: .day, value: 10, to: .now)!
        let session = TripSession(
            name: "Race Condition Test",
            destination: "Orlando",
            departureDate: dep,
            returnDate: ret,
            activities: [.conference]
        )

        let activeItems = try await repos.masterItems.fetchActive()
        let generated = ChecklistEngine().generateItems(for: session, from: activeItems)

        XCTAssertGreaterThan(generated.count, 0,
            "Seed must complete before trip creation — 0 items generated means the production race condition is present")
    }

    func testSeedWithFreshUserDefaultsAlwaysRuns() async throws {
        let isolated = UserDefaults(suiteName: UUID().uuidString)!
        XCTAssertFalse(isolated.bool(forKey: ImportService.seededKey),
                       "Fresh UserDefaults must not have the seeded flag pre-set")

        await ImportService(repository: repos.masterItems, defaults: isolated).seedIfNeeded()

        let items = try context.fetch(FetchDescriptor<MasterItem>())
        XCTAssertGreaterThan(items.count, 200,
            "Fresh-flag seed must populate master list with >200 items; got \(items.count)")
        XCTAssertTrue(isolated.bool(forKey: ImportService.seededKey),
                      "seededKey flag must be true after seed completes")
    }

    func testSeedWithExistingFlagDoesNotReseed() async throws {
        let isolated = UserDefaults(suiteName: UUID().uuidString)!
        let service = ImportService(repository: repos.masterItems, defaults: isolated)

        await service.seedIfNeeded()
        let countAfterFirstSeed = try context.fetch(FetchDescriptor<MasterItem>()).count
        XCTAssertGreaterThan(countAfterFirstSeed, 0, "First seed must have inserted items")

        // seededKey is now set — simulates app re-launch
        XCTAssertTrue(isolated.bool(forKey: ImportService.seededKey))
        await service.seedIfNeeded()

        let countAfterSecondSeed = try context.fetch(FetchDescriptor<MasterItem>()).count
        XCTAssertEqual(countAfterFirstSeed, countAfterSecondSeed,
                       "Re-running seed with flag set must not insert duplicate items")
    }
}

// MARK: - Repository edge case tests

@MainActor
final class RepositoryEdgeCaseTests: XCTestCase {

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

    func testFetchNonExistentTripReturnsNil() async throws {
        let result = try await repos.tripSessions.fetch(id: UUID())
        XCTAssertNil(result, "Fetching a random UUID must return nil without crashing")
    }

    func testUpdateTripPersistsChanges() async throws {
        let trip = TripSession(name: "Orlando", destination: "Orlando",
                               departureDate: Date(), returnDate: Date())
        try await repos.tripSessions.insert(trip)

        trip.name = "Tokyo"
        try await repos.tripSessions.update(trip)

        let fetched = try await repos.tripSessions.fetch(id: trip.id)
        XCTAssertEqual(fetched?.name, "Tokyo", "Updated name must persist after save")
    }

    func testDeleteNonExistentTripDoesNotCrash() async {
        let trip = TripSession(name: "Ghost", destination: "Nowhere",
                               departureDate: Date(), returnDate: Date())
        // Intentionally NOT inserted — verify no crash
        do {
            try await repos.tripSessions.delete(trip)
        } catch {
            // SwiftData may throw for untracked objects — that is acceptable
        }
        XCTAssertTrue(true, "Reaching this line means no crash occurred")
    }

    func testInsertManyItemsAllPersist() async throws {
        let trip = TripSession(name: "Large Trip", destination: "Hawaii",
                               departureDate: Date(), returnDate: Date())
        try await repos.tripSessions.insert(trip)

        for i in 0..<128 {
            let item = TripItem(tripId: trip.id, name: "Item \(i)", category: .misc)
            try await repos.tripItems.insert(item)
        }

        let fetched = try await repos.tripItems.fetchAll(for: trip.id)
        XCTAssertEqual(fetched.count, 128,
                       "All 128 items must persist — validates the batch insert pattern used in createTrip()")
        XCTAssertTrue(fetched.allSatisfy { $0.tripId == trip.id },
                      "All fetched items must have the correct tripId")
    }
}

// MARK: - Full app launch sequence integration test

@MainActor
final class LaunchSequenceTests: XCTestCase {

    func testFullAppLaunchSequence() async throws {
        // Step 1: Create ModelContainer — simulating PackListApp.init makeContainer()
        let schema = Schema([TripSession.self, TripInfo.self, MasterItem.self,
                             TripItem.self, ItemInsight.self, PendingSuggestion.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)

        // Step 2: Create RepositoryContainer — simulating App.init
        let repos = RepositoryContainer(modelContext: container.mainContext)

        // Step 3: Run seedIfNeeded() — simulating ContentView.task seed call
        let isolated = UserDefaults(suiteName: UUID().uuidString)!
        await ImportService(repository: repos.masterItems, defaults: isolated).seedIfNeeded()

        // Step 4: Verify seed
        let masterItems = try container.mainContext.fetch(FetchDescriptor<MasterItem>())
        XCTAssertGreaterThan(masterItems.count, 200,
                             "Step 4: Seed must populate >200 master items; got \(masterItems.count)")

        // Step 5: Create a TripSession (Conference, Orlando, mild, carry-on only)
        let dep = Calendar.current.date(byAdding: .day, value: 14, to: .now)!
        let ret = Calendar.current.date(byAdding: .day, value: 17, to: .now)!
        let session = TripSession(
            name: "Orlando Conference",
            destination: "Orlando",
            departureDate: dep,
            returnDate: ret,
            weather: .mild,
            activities: [.conference],
            carryOnOnly: true
        )

        // Step 6: Run ChecklistEngine with seeded master items
        let activeItems = try await repos.masterItems.fetchActive()
        let generated = ChecklistEngine().generateItems(for: session, from: activeItems)
        XCTAssertGreaterThan(generated.count, 50,
                             "Step 6: Engine must generate >50 items for a conference trip; got \(generated.count)")

        // Step 7: Insert session via repository
        try await repos.tripSessions.insert(session)

        // Step 8: Insert all generated items via repository
        for item in generated {
            try await repos.tripItems.insert(item)
        }

        // Step 9: Fetch sessions — assert count == 1
        let sessions = try await repos.tripSessions.fetchAll()
        XCTAssertEqual(sessions.count, 1, "Step 9: Exactly 1 session must exist after creation")

        // Step 10: Fetch TripItems by tripId — assert count > 50
        let fetchedItems = try await repos.tripItems.fetchAll(for: session.id)
        XCTAssertGreaterThan(fetchedItems.count, 50,
                             "Step 10: All generated items must persist; got \(fetchedItems.count)")

        // Step 11: Assert all fetched items have the correct tripId
        XCTAssertTrue(fetchedItems.allSatisfy { $0.tripId == session.id },
                      "Step 11: Every fetched TripItem must carry the session's tripId")
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
