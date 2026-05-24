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
        let info = TripInfo(tripId: trip.id, accommodationName: "Hotel Alpha")
        trip.tripInfo = info
        try await repo.insert(info)

        info.accommodationName = "Hotel Beta"
        try await repo.update(info)

        let fetched = try context.fetch(FetchDescriptor<TripInfo>())
        XCTAssertEqual(fetched.first?.accommodationName, "Hotel Beta")
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

// MARK: - Trip persistence tests

@MainActor
final class TripPersistenceTests: XCTestCase {

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

    // Test 1
    func testTripAllFieldsRoundTrip() throws {
        let id = UUID()
        let ownerId = UUID()
        let parentId = UUID()
        var comps = DateComponents()
        comps.year = 2025; comps.month = 6; comps.day = 15; comps.hour = 12
        let dep = Calendar(identifier: .gregorian).date(from: comps)!
        comps.day = 22
        let ret = Calendar(identifier: .gregorian).date(from: comps)!
        comps.day = 23
        let manualDone = Calendar(identifier: .gregorian).date(from: comps)!

        let session = TripSession(
            id: id,
            ownerId: ownerId,
            parentTripId: parentId,
            name: "All Fields Trip",
            destination: "Tokyo",
            region: .japan,
            departureDate: dep,
            returnDate: ret,
            purposes: [.business, .personal],
            weather: .hot,
            companions: [.spouse, .kids],
            activities: [.golf, .beach, .conference],
            laundryAvailable: true,
            carryOnOnly: true,
            business: true,
            interacPhone: true,
            interacLaptop: true,
            hasMedicalAppointment: true,
            manuallyCompletedAt: manualDone,
            notes: "Test notes content"
        )
        context.insert(session)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<TripSession>())
        XCTAssertEqual(fetched.count, 1,
                       "Expected 1 session after insert+save, got \(fetched.count)")
        let f = try XCTUnwrap(fetched.first, "Fetched session was nil")
        XCTAssertEqual(f.id, id, "id mismatch")
        XCTAssertEqual(f.ownerId, ownerId, "ownerId mismatch")
        XCTAssertEqual(f.parentTripId, parentId, "parentTripId mismatch")
        XCTAssertEqual(f.name, "All Fields Trip", "name mismatch")
        XCTAssertEqual(f.destination, "Tokyo", "destination mismatch")
        XCTAssertEqual(f.region, .japan, "region mismatch")
        XCTAssertEqual(f.departureDate, dep, "departureDate mismatch")
        XCTAssertEqual(f.returnDate, ret, "returnDate mismatch")
        XCTAssertEqual(Set(f.purposes), Set([.business, .personal]), "purposes mismatch")
        XCTAssertEqual(f.weather, .hot, "weather mismatch")
        XCTAssertEqual(Set(f.companions), Set([.spouse, .kids]), "companions mismatch")
        XCTAssertEqual(Set(f.activities), Set([.golf, .beach, .conference]), "activities mismatch")
        XCTAssertTrue(f.laundryAvailable, "laundryAvailable should be true")
        XCTAssertTrue(f.carryOnOnly, "carryOnOnly should be true")
        XCTAssertTrue(f.business, "business should be true")
        XCTAssertTrue(f.interacPhone, "interacPhone should be true")
        XCTAssertTrue(f.interacLaptop, "interacLaptop should be true")
        XCTAssertTrue(f.hasMedicalAppointment, "hasMedicalAppointment should be true")
        XCTAssertNotNil(f.manuallyCompletedAt, "manuallyCompletedAt should not be nil")
        XCTAssertEqual(f.manuallyCompletedAt?.timeIntervalSinceReferenceDate ?? 0,
                       manualDone.timeIntervalSinceReferenceDate, accuracy: 1,
                       "manuallyCompletedAt timestamp mismatch")
        XCTAssertEqual(f.notes, "Test notes content", "notes mismatch")
    }

    // Test 2
    func testMultipleTripsCoexist() throws {
        let names = ["Safari Trip", "Mountain Trek", "City Break"]
        for name in names {
            context.insert(TripSession(name: name, destination: "Anywhere",
                                       departureDate: .now, returnDate: .now))
        }
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<TripSession>())
        XCTAssertEqual(fetched.count, 3,
                       "Expected 3 trips after inserting 3, got \(fetched.count)")
        let fetchedNames = Set(fetched.map(\.name))
        for name in names {
            XCTAssertTrue(fetchedNames.contains(name),
                          "Trip '\(name)' not found in store — only found: \(fetchedNames)")
        }
    }

    // Test 3
    func testTripDeletionCascadesToItems() async throws {
        let session = TripSession(name: "Cascade Test", destination: "Anywhere",
                                  departureDate: .now, returnDate: .now)
        let tripId = session.id
        let items = (0..<5).map { i in TripItem(tripId: tripId, name: "Item \(i)", category: .misc) }
        session.items = items
        context.insert(session)
        try context.save()

        let before = try context.fetch(FetchDescriptor<TripItem>(
            predicate: #Predicate { $0.tripId == tripId }
        ))
        XCTAssertEqual(before.count, 5,
                       "Pre-delete: expected 5 TripItems, got \(before.count)")

        try await repos.tripSessions.delete(session)

        let after = try context.fetch(FetchDescriptor<TripItem>(
            predicate: #Predicate { $0.tripId == tripId }
        ))
        XCTAssertEqual(after.count, 0,
                       "Post-cascade-delete: expected 0 TripItems, got \(after.count) — cascade delete not working")
    }

    // Test 4
    func testTripItemsAreScopedToTrip() throws {
        let tripA = TripSession(name: "Trip A", destination: "Paris",
                                departureDate: .now, returnDate: .now)
        let tripB = TripSession(name: "Trip B", destination: "Berlin",
                                departureDate: .now, returnDate: .now)
        context.insert(tripA)
        context.insert(tripB)
        let aId = tripA.id
        let bId = tripB.id
        for i in 0..<3 { context.insert(TripItem(tripId: aId, name: "A\(i)", category: .misc)) }
        for i in 0..<4 { context.insert(TripItem(tripId: bId, name: "B\(i)", category: .misc)) }
        try context.save()

        let aItems = try context.fetch(FetchDescriptor<TripItem>(
            predicate: #Predicate { $0.tripId == aId }
        ))
        XCTAssertEqual(aItems.count, 3,
                       "Fetch scoped to Trip A should return 3 items, got \(aItems.count)")
        XCTAssertTrue(aItems.allSatisfy { $0.tripId == aId },
                      "All fetched items must have Trip A's tripId")
    }

    // Test 5
    func testTripInfoPersists() async throws {
        let session = TripSession(name: "Info Test", destination: "London",
                                  departureDate: .now, returnDate: .now)
        context.insert(session)
        let dep = Date(timeIntervalSinceNow: 86_400)

        let info = TripInfo(
            tripId: session.id,
            outboundAirline: "British Airways",
            outboundFlightNumber: "BA 092",
            outboundDepartureAirport: "YYZ",
            outboundDepartureTime: dep,
            outboundArrivalAirport: "LHR",
            accommodationName: "The Savoy"
        )
        session.tripInfo = info
        try await repos.tripInfo.insert(info)

        let fetched = try context.fetch(FetchDescriptor<TripInfo>())
        let f = try XCTUnwrap(fetched.first, "TripInfo not found after insert")
        XCTAssertEqual(f.tripId, session.id, "TripInfo tripId mismatch")
        XCTAssertEqual(f.outboundAirline, "British Airways", "outboundAirline mismatch")
        XCTAssertEqual(f.outboundFlightNumber, "BA 092", "outboundFlightNumber mismatch")
        XCTAssertEqual(f.outboundDepartureAirport, "YYZ", "outboundDepartureAirport mismatch")
        XCTAssertEqual(f.outboundArrivalAirport, "LHR", "outboundArrivalAirport mismatch")
        XCTAssertEqual(f.accommodationName, "The Savoy", "accommodationName mismatch")
    }

    // Test 6
    func testTripStatusComputedCorrectly() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)

        let planningDep = cal.date(byAdding: .day, value: 10, to: today)!
        let planningRet = cal.date(byAdding: .day, value: 14, to: today)!
        let planning = TripSession(name: "Planning", destination: "X",
                                   departureDate: planningDep, returnDate: planningRet)
        XCTAssertEqual(planning.status, .planning,
                       "Departure 10 days out should be .planning, got .\(planning.status)")

        let activeDep = cal.date(byAdding: .day, value: 3, to: today)!
        let activeRet = cal.date(byAdding: .day, value: 7, to: today)!
        let active = TripSession(name: "Active", destination: "X",
                                 departureDate: activeDep, returnDate: activeRet)
        XCTAssertEqual(active.status, .active,
                       "Departure 3 days out should be .active, got .\(active.status)")

        let pastDep = cal.date(byAdding: .day, value: -5, to: today)!
        let pastRet = cal.date(byAdding: .day, value: -1, to: today)!
        let completed = TripSession(name: "Completed", destination: "X",
                                    departureDate: pastDep, returnDate: pastRet)
        XCTAssertEqual(completed.status, .completed,
                       "Past return date should be .completed, got .\(completed.status)")

        let futureDep = cal.date(byAdding: .day, value: 20, to: today)!
        let futureRet = cal.date(byAdding: .day, value: 24, to: today)!
        let manual = TripSession(name: "Manual Done", destination: "X",
                                 departureDate: futureDep, returnDate: futureRet,
                                 manuallyCompletedAt: Date())
        XCTAssertEqual(manual.status, .completed,
                       "manuallyCompletedAt set should be .completed regardless of dates, got .\(manual.status)")
    }
}

// MARK: - Seed validation tests

@MainActor
final class SeedValidationTests: XCTestCase {

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

    // Test 7
    func testSeedIsIdempotent() async throws {
        let isolated = UserDefaults(suiteName: UUID().uuidString)!
        let service = ImportService(repository: repos.masterItems, defaults: isolated)

        await service.seedIfNeeded()
        let countAfterFirst = try context.fetch(FetchDescriptor<MasterItem>()).count

        await service.seedIfNeeded()
        let countAfterSecond = try context.fetch(FetchDescriptor<MasterItem>()).count

        XCTAssertEqual(countAfterFirst, countAfterSecond,
                       "seedIfNeeded() is not idempotent: count changed from \(countAfterFirst) to \(countAfterSecond) on second call")
    }

    // Test 8
    func testSeedItemsHaveRequiredFields() async throws {
        let isolated = UserDefaults(suiteName: UUID().uuidString)!
        await ImportService(repository: repos.masterItems, defaults: isolated).seedIfNeeded()

        let items = try context.fetch(FetchDescriptor<MasterItem>())
        XCTAssertGreaterThan(items.count, 0, "No items found after seeding")

        for item in items {
            XCTAssertFalse(item.name.isEmpty,
                           "Seed item has empty name (id: \(item.id))")
        }

        XCTAssertTrue(items.contains { $0.itemType == .physical },
                      "Seed data contains no .physical items")
        XCTAssertTrue(items.contains { $0.itemType == .task },
                      "Seed data contains no .task items")

        let categories = Set(items.map(\.category))
        XCTAssertGreaterThan(categories.count, 3,
                             "Expected items from >3 categories, got \(categories.count): \(categories)")
    }
}

// MARK: - ChecklistEngine coverage tests (seed-backed)

@MainActor
final class ChecklistEngineCoverageTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!
    var repos: RepositoryContainer!
    var engine: ChecklistEngine!

    override func setUpWithError() throws {
        engine = ChecklistEngine()
        let schema = Schema([TripSession.self, TripInfo.self, MasterItem.self,
                             TripItem.self, ItemInsight.self, PendingSuggestion.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: config)
        context = ModelContext(container)
        repos = RepositoryContainer(modelContext: context)
    }

    override func tearDown() {
        engine = nil
        repos = nil
        context = nil
        container = nil
    }

    private func seededItems() async throws -> [MasterItem] {
        let isolated = UserDefaults(suiteName: UUID().uuidString)!
        await ImportService(repository: repos.masterItems, defaults: isolated).seedIfNeeded()
        return try await repos.masterItems.fetchActive()
    }

    private func session(activities: [ActivityType] = [], weather: WeatherProfile = .mild,
                         region: TravelRegion = .canada, carryOnOnly: Bool = false,
                         laundryAvailable: Bool = false) -> TripSession {
        let dep = Calendar.current.date(byAdding: .day, value: 14, to: .now) ?? .now
        let ret = Calendar.current.date(byAdding: .day, value: 17, to: .now) ?? .now
        return TripSession(name: "Test", destination: "Anywhere", region: region,
                           departureDate: dep, returnDate: ret,
                           weather: weather, activities: activities,
                           laundryAvailable: laundryAvailable, carryOnOnly: carryOnOnly)
    }

    // Test 9
    func testChecklistEngineConferenceTrip() async throws {
        let items = try await seededItems()
        let result = engine.generateItems(for: session(activities: [.conference]), from: items)

        XCTAssertGreaterThan(result.count, 20,
                             "Conference trip should produce >20 items, got \(result.count)")
        XCTAssertTrue(result.contains { $0.category == .clothing },
                      "Conference trip must include at least one .clothing item")
        XCTAssertTrue(result.contains { $0.category == .tech },
                      "Conference trip must include at least one .tech item")
    }

    // Test 10
    func testChecklistEngineGolfTrip() async throws {
        let items = try await seededItems()
        let result = engine.generateItems(for: session(activities: [.golf]), from: items)

        XCTAssertGreaterThan(result.count, 10,
                             "Golf trip should produce >10 items, got \(result.count)")
    }

    // Test 11
    func testChecklistEngineBeachTrip() async throws {
        let items = try await seededItems()
        let result = engine.generateItems(for: session(activities: [.beach]), from: items)

        XCTAssertGreaterThan(result.count, 10,
                             "Beach trip should produce >10 items, got \(result.count)")
    }

    // Test 12
    func testChecklistEngineAllActivityTypesGenerateItems() async throws {
        let items = try await seededItems()

        for activity in ActivityType.allCases {
            let result = engine.generateItems(for: session(activities: [activity]), from: items)
            XCTAssertGreaterThan(result.count, 0,
                                 "ActivityType.\(activity) generated 0 items — at least always-include items should appear")
        }
    }

    // Test 13
    func testChecklistEngineAllWeatherProfilesGenerateItems() async throws {
        let items = try await seededItems()

        for weather in WeatherProfile.allCases {
            let result = engine.generateItems(for: session(weather: weather), from: items)
            XCTAssertGreaterThan(result.count, 0,
                                 "WeatherProfile.\(weather) generated 0 items — always-include items must be present in seed")
        }
    }

    // Test 14
    func testChecklistEngineCarryOnOnlyExcludesCheckedBag() {
        let alwaysItem = MasterItem(name: "Passport", category: .documents,
                                    tags: [.always], packingLocation: .passportWallet)
        let checkedItem = MasterItem(name: "Large Luggage Item", category: .clothing,
                                     tags: [.always], packingLocation: .checkedBag)
        let carryOnItem = MasterItem(name: "Laptop", category: .tech,
                                     tags: [.always], packingLocation: .carryOn)

        let carryOnSession = session(carryOnOnly: true)
        let result = engine.generateItems(for: carryOnSession,
                                          from: [alwaysItem, checkedItem, carryOnItem])

        XCTAssertFalse(result.isEmpty,
                       "carryOnOnly session should still generate items")
        let checkedItems = result.filter { $0.packingLocation == .checkedBag }
        XCTAssertTrue(checkedItems.isEmpty,
                      "carryOnOnly session must not produce .checkedBag items — found: \(checkedItems.map(\.name))")
    }

    // Test 15
    func testChecklistEngineLaundryReducesClothingItems() async throws {
        let items = try await seededItems()
        let dep = Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now
        let ret = Calendar.current.date(byAdding: .day, value: 14, to: .now) ?? .now

        let withLaundry = TripSession(name: "With Laundry", destination: "X",
                                      departureDate: dep, returnDate: ret,
                                      activities: [.conference], laundryAvailable: true)
        let noLaundry = TripSession(name: "No Laundry", destination: "X",
                                    departureDate: dep, returnDate: ret,
                                    activities: [.conference], laundryAvailable: false)

        let laundryResult = engine.generateItems(for: withLaundry, from: items)
        let noLaundryResult = engine.generateItems(for: noLaundry, from: items)

        let laundryClothingQty = laundryResult
            .filter { $0.category == .clothing }
            .reduce(0) { $0 + $1.quantity }
        let noLaundryClothingQty = noLaundryResult
            .filter { $0.category == .clothing }
            .reduce(0) { $0 + $1.quantity }

        XCTAssertLessThanOrEqual(laundryClothingQty, noLaundryClothingQty,
                                  "Clothing quantity with laundry (\(laundryClothingQty)) should be ≤ without laundry (\(noLaundryClothingQty))")
    }
}

// MARK: - Core user flow tests

@MainActor
final class CoreUserFlowTests: XCTestCase {

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

    // Test 16
    func testFullTripCreationFlow() async throws {
        let isolated = UserDefaults(suiteName: UUID().uuidString)!
        await ImportService(repository: repos.masterItems, defaults: isolated).seedIfNeeded()

        let dep = Calendar.current.date(byAdding: .day, value: 14, to: .now) ?? .now
        let ret = Calendar.current.date(byAdding: .day, value: 17, to: .now) ?? .now
        let session = TripSession(
            name: "Conference Orlando",
            destination: "Orlando",
            region: .us,
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

        let sessions = try context.fetch(FetchDescriptor<TripSession>())
        XCTAssertEqual(sessions.count, 1,
                       "Expected exactly 1 TripSession after full creation flow, got \(sessions.count)")

        let tripId = session.id
        let fetchedItems = try context.fetch(
            FetchDescriptor<TripItem>(predicate: #Predicate { $0.tripId == tripId })
        )
        XCTAssertGreaterThan(fetchedItems.count, 50,
                             "Conference/Orlando/mild trip should produce >50 items, got \(fetchedItems.count)")
        XCTAssertTrue(fetchedItems.allSatisfy { $0.tripId == session.id },
                      "All fetched TripItems must have the correct tripId")
    }

    // Test 17
    func testMarkItemCompleteUpdatesCompletedAt() throws {
        let tripId = UUID()
        var items: [TripItem] = []
        for i in 0..<5 {
            let item = TripItem(tripId: tripId, name: "Item \(i)", category: .misc)
            context.insert(item)
            items.append(item)
        }
        try context.save()

        let now = Date()
        for i in 0..<3 { items[i].completedAt = now }
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<TripItem>(
            predicate: #Predicate { $0.tripId == tripId }
        ))
        let completed = fetched.filter { $0.completedAt != nil }
        let incomplete = fetched.filter { $0.completedAt == nil }

        XCTAssertEqual(completed.count, 3,
                       "Expected 3 items with completedAt set, got \(completed.count)")
        XCTAssertEqual(incomplete.count, 2,
                       "Expected 2 items with nil completedAt, got \(incomplete.count)")
    }

    // Test 18
    func testMarkAllItemsComplete() throws {
        let tripId = UUID()
        let count = 8
        for i in 0..<count {
            context.insert(TripItem(tripId: tripId, name: "Item \(i)", category: .misc))
        }
        try context.save()

        let all = try context.fetch(FetchDescriptor<TripItem>(
            predicate: #Predicate { $0.tripId == tripId }
        ))
        let now = Date()
        for item in all { item.completedAt = now }
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<TripItem>(
            predicate: #Predicate { $0.tripId == tripId }
        ))
        XCTAssertEqual(fetched.count, count,
                       "Item count changed after marking complete: expected \(count), got \(fetched.count)")
        XCTAssertTrue(fetched.allSatisfy { $0.completedAt != nil },
                      "\(fetched.filter { $0.completedAt == nil }.count) item(s) still have nil completedAt after marking all complete")
    }
}

// MARK: - ProfileViewModel tests

final class ProfileViewModelTests: XCTestCase {

    // Test 22
    func testInitWithEmptyDefaultsUsesExpectedDefaults() {
        let isolated = UserDefaults(suiteName: UUID().uuidString)!
        let vm = ProfileViewModel(defaults: isolated)
        XCTAssertEqual(vm.fullName, "")
        XCTAssertEqual(vm.homeAirport, "")
        XCTAssertEqual(vm.aeroplanNumber, "")
        XCTAssertEqual(vm.aeroplanTier, .none)
        XCTAssertEqual(vm.bonvoyNumber, "")
        XCTAssertEqual(vm.bonvoyTier, .member)
        XCTAssertEqual(vm.appearance, .system)
    }

    // Test 23
    func testSaveWritesAllFieldsToUserDefaults() {
        let isolated = UserDefaults(suiteName: UUID().uuidString)!
        let vm = ProfileViewModel(defaults: isolated)
        vm.fullName = "Jason Gray"
        vm.homeAirport = "YYZ"
        vm.aeroplanNumber = "123456789"
        vm.aeroplanTier = .superElite
        vm.bonvoyNumber = "987654321"
        vm.bonvoyTier = .titaniumElite
        vm.appearance = .dark
        vm.save()

        XCTAssertEqual(isolated.string(forKey: "profile_full_name"), "Jason Gray")
        XCTAssertEqual(isolated.string(forKey: "profile_home_airport"), "YYZ")
        XCTAssertEqual(isolated.string(forKey: "profile_aeroplan_number"), "123456789")
        XCTAssertEqual(isolated.string(forKey: "profile_aeroplan_tier"), "Super Elite")
        XCTAssertEqual(isolated.string(forKey: "profile_bonvoy_number"), "987654321")
        XCTAssertEqual(isolated.string(forKey: "profile_bonvoy_tier"), "Titanium Elite")
        XCTAssertEqual(isolated.string(forKey: "profile_appearance"), "Dark")
    }

    // Test 24
    func testInitReadsPersistedValuesFromUserDefaults() {
        let isolated = UserDefaults(suiteName: UUID().uuidString)!
        isolated.set("Jason Gray", forKey: "profile_full_name")
        isolated.set("YYZ", forKey: "profile_home_airport")
        isolated.set("123456789", forKey: "profile_aeroplan_number")
        isolated.set("Super Elite", forKey: "profile_aeroplan_tier")
        isolated.set("987654321", forKey: "profile_bonvoy_number")
        isolated.set("Titanium Elite", forKey: "profile_bonvoy_tier")
        isolated.set("Dark", forKey: "profile_appearance")

        let vm = ProfileViewModel(defaults: isolated)
        XCTAssertEqual(vm.fullName, "Jason Gray")
        XCTAssertEqual(vm.homeAirport, "YYZ")
        XCTAssertEqual(vm.aeroplanNumber, "123456789")
        XCTAssertEqual(vm.aeroplanTier, .superElite)
        XCTAssertEqual(vm.bonvoyNumber, "987654321")
        XCTAssertEqual(vm.bonvoyTier, .titaniumElite)
        XCTAssertEqual(vm.appearance, .dark)
    }

    // Test 25
    func testSaveRoundTrip() {
        let isolated = UserDefaults(suiteName: UUID().uuidString)!
        let vm1 = ProfileViewModel(defaults: isolated)
        vm1.fullName = "Test User"
        vm1.homeAirport = "LHR"
        vm1.aeroplanTier = .elite75k
        vm1.bonvoyTier = .goldElite
        vm1.appearance = .light
        vm1.save()

        let vm2 = ProfileViewModel(defaults: isolated)
        XCTAssertEqual(vm2.fullName, "Test User")
        XCTAssertEqual(vm2.homeAirport, "LHR")
        XCTAssertEqual(vm2.aeroplanTier, .elite75k)
        XCTAssertEqual(vm2.bonvoyTier, .goldElite)
        XCTAssertEqual(vm2.appearance, .light)
    }
}

// MARK: - Add custom item tests (#117)

@MainActor
final class AddCustomItemTests: XCTestCase {

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

    private func makeSession() -> TripSession {
        TripSession(name: "Custom Item Test", destination: "Tokyo",
                    departureDate: Date(), returnDate: Date())
    }

    func testAddCustomItemCreatesCorrectTripItem() async throws {
        let session = makeSession()
        try await repos.tripSessions.insert(session)

        let vm = TripDetailViewModel(trip: session)
        await vm.load(repository: repos.tripItems)

        await vm.addCustomItem(name: "Extra Toothbrush", category: .hygiene,
                               location: .toiletryBag, quantity: 2)

        XCTAssertEqual(vm.items.count, 1, "Expected 1 item after addCustomItem")
        let item = try XCTUnwrap(vm.items.first)
        XCTAssertEqual(item.name, "Extra Toothbrush")
        XCTAssertEqual(item.category, .hygiene)
        XCTAssertEqual(item.packingLocation, .toiletryBag)
        XCTAssertEqual(item.quantity, 2)
        XCTAssertEqual(item.source, .manual, "Custom item must have source == .manual")
        XCTAssertEqual(item.tripId, session.id, "Custom item must reference the correct trip")
    }

    func testCustomItemAppearsInPackingList() async throws {
        let session = makeSession()
        try await repos.tripSessions.insert(session)

        // Pre-seed a generated item in the same Misc category so we can verify sort order
        let generated = TripItem(tripId: session.id, name: "Alpha Generated", category: .misc)
        try await repos.tripItems.insert(generated)

        let vm = TripDetailViewModel(trip: session)
        await vm.load(repository: repos.tripItems)

        await vm.addCustomItem(name: "Deck of Cards", category: .misc,
                               location: .carryOn, quantity: 1)

        let groups = vm.categoryGroups
        let miscGroup = try XCTUnwrap(groups.first(where: { $0.category == .misc }),
                                      "Misc category group should exist after adding custom item")
        XCTAssertTrue(miscGroup.items.contains { $0.name == "Deck of Cards" },
                      "Custom item should appear in its category group")

        // Manual item must sort before any generated item regardless of name
        let manualIndex = try XCTUnwrap(miscGroup.items.firstIndex { $0.source == .manual },
                                        "Manual item should exist in group")
        let generatedIndex = try XCTUnwrap(miscGroup.items.firstIndex { $0.source == .generated },
                                           "Generated item should exist in group")
        XCTAssertLessThan(manualIndex, generatedIndex,
                          "Manual item must sort before generated items in the same section")
    }

    func testDeleteCustomItem() async throws {
        let session = makeSession()
        try await repos.tripSessions.insert(session)

        let vm = TripDetailViewModel(trip: session)
        await vm.load(repository: repos.tripItems)

        await vm.addCustomItem(name: "Temporary Item", category: .misc,
                               location: .carryOn, quantity: 1)
        XCTAssertEqual(vm.items.count, 1, "Should have 1 item before delete")

        let item = try XCTUnwrap(vm.items.first)
        await vm.deleteCustomItem(item)

        XCTAssertEqual(vm.items.count, 0, "Should have 0 items in VM after delete")

        let persisted = try await repos.tripItems.fetchAll(for: session.id)
        XCTAssertEqual(persisted.count, 0, "Repository should also have 0 items after delete")
    }
}

// MARK: - Regression tests

@MainActor
final class RegressionTests: XCTestCase {

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

    // Test 19 — regression for #102
    func testNoStateBleedBetweenTrips() throws {
        let tripA = TripSession(name: "Trip A", destination: "Paris",
                                departureDate: .now, returnDate: .now)
        let tripB = TripSession(name: "Trip B", destination: "Rome",
                                departureDate: .now, returnDate: .now)
        context.insert(tripA)
        context.insert(tripB)
        let aId = tripA.id
        let bId = tripB.id
        for i in 0..<5 { context.insert(TripItem(tripId: aId, name: "A\(i)", category: .misc)) }
        for i in 0..<3 { context.insert(TripItem(tripId: bId, name: "B\(i)", category: .misc)) }
        try context.save()

        let aItems = try context.fetch(FetchDescriptor<TripItem>(
            predicate: #Predicate { $0.tripId == aId }
        ))
        XCTAssertEqual(aItems.count, 5,
                       "Regression #102: Trip A fetch returned \(aItems.count) items, expected 5 — state bleed from Trip B suspected")
        XCTAssertTrue(aItems.allSatisfy { $0.tripId == aId },
                      "Regression #102: All fetched items must belong to Trip A")
    }

    // Test 20 — regression for context isolation bug
    func testTripItemInsertAndFetchSameContext() throws {
        let tripId = UUID()
        let item = TripItem(tripId: tripId, name: "Solo Item", category: .misc)
        context.insert(item)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<TripItem>(
            predicate: #Predicate { $0.tripId == tripId }
        ))
        XCTAssertEqual(fetched.count, 1,
                       "Context isolation regression: inserted 1 TripItem, fetch on same context returned \(fetched.count)")
    }

    // Test 21
    func testDeleteTripDoesNotAffectOtherTrips() async throws {
        let tripA = TripSession(name: "Trip A", destination: "Paris",
                                departureDate: .now, returnDate: .now)
        let tripB = TripSession(name: "Trip B", destination: "Rome",
                                departureDate: .now, returnDate: .now)
        context.insert(tripA)
        context.insert(tripB)
        let aId = tripA.id
        let bId = tripB.id
        for i in 0..<3 { context.insert(TripItem(tripId: aId, name: "A\(i)", category: .misc)) }
        for i in 0..<4 { context.insert(TripItem(tripId: bId, name: "B\(i)", category: .misc)) }
        try context.save()

        try await repos.tripSessions.delete(tripA)

        let bItems = try context.fetch(FetchDescriptor<TripItem>(
            predicate: #Predicate { $0.tripId == bId }
        ))
        XCTAssertEqual(bItems.count, 4,
                       "Deleting Trip A should not affect Trip B: expected 4 items, got \(bItems.count)")
        XCTAssertTrue(bItems.allSatisfy { $0.tripId == bId },
                      "All remaining items after Trip A deletion must belong to Trip B")
    }
}

// MARK: - PackingLocation display tests

final class PackingLocationDisplayTests: XCTestCase {

    func testSfSymbolNonEmptyForAllCases() {
        for location in PackingLocation.allCases {
            XCTAssertFalse(location.sfSymbol.isEmpty,
                           "sfSymbol must not be empty for PackingLocation.\(location)")
        }
    }

    func testSfSymbolKnownValues() {
        XCTAssertEqual(PackingLocation.backpack.sfSymbol,          "backpack.fill")
        XCTAssertEqual(PackingLocation.carryOn.sfSymbol,           "suitcase.rolling.fill")
        XCTAssertEqual(PackingLocation.checkedBag.sfSymbol,        "suitcase.fill")
        XCTAssertEqual(PackingLocation.flightAccessPouch.sfSymbol, "airplane")
        XCTAssertEqual(PackingLocation.techPouch.sfSymbol,         "cable.connector")
        XCTAssertEqual(PackingLocation.toiletryBag.sfSymbol,       "drop.fill")
        XCTAssertEqual(PackingLocation.passportWallet.sfSymbol,    "wallet.pass")
        XCTAssertEqual(PackingLocation.golfBag.sfSymbol,           "figure.golf")
        XCTAssertEqual(PackingLocation.wearing.sfSymbol,           "figure.walk")
        XCTAssertEqual(PackingLocation.pocket.sfSymbol,            "bag.badge.questionmark")
    }

    func testDisplayNameNonEmptyForAllCases() {
        for location in PackingLocation.allCases {
            XCTAssertFalse(location.displayName.isEmpty,
                           "displayName must not be empty for PackingLocation.\(location)")
        }
    }
}

// MARK: - Mock Repositories (used by ImportServiceCoverageTests)

@MainActor
private final class InsertThrowingMasterItemRepository: MasterItemRepository {
    func fetchAll() async throws -> [MasterItem] { [] }
    func fetchActive() async throws -> [MasterItem] { [] }
    func fetchActive(matchingAnyOf tags: Set<ItemTag>) async throws -> [MasterItem] { [] }
    func fetch(id: UUID) async throws -> MasterItem? { nil }
    func insert(_ item: MasterItem) async throws {
        throw NSError(domain: "test.insert", code: 1,
                      userInfo: [NSLocalizedDescriptionKey: "Simulated insert failure"])
    }
    func delete(_ item: MasterItem) async throws { }
}

@MainActor
private final class DeleteThrowingMasterItemRepository: MasterItemRepository {
    var storedItems: [MasterItem]
    init(items: [MasterItem]) { storedItems = items }
    func fetchAll() async throws -> [MasterItem] { storedItems }
    func fetchActive() async throws -> [MasterItem] { storedItems.filter { $0.isActive } }
    func fetchActive(matchingAnyOf tags: Set<ItemTag>) async throws -> [MasterItem] { [] }
    func fetch(id: UUID) async throws -> MasterItem? { storedItems.first { $0.id == id } }
    func insert(_ item: MasterItem) async throws { storedItems.append(item) }
    func delete(_ item: MasterItem) async throws {
        throw NSError(domain: "test.delete", code: 1,
                      userInfo: [NSLocalizedDescriptionKey: "Simulated delete failure"])
    }
}

// MARK: - ImportService coverage tests

@MainActor
final class ImportServiceCoverageTests: XCTestCase {

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

    // Covers removeDuplicateImportedItems: the dedup delete path
    func testSeedDeduplicationByName() async throws {
        let older = MasterItem(name: "zzz_dupe_test", category: .misc, source: .imported,
                               createdAt: Date().addingTimeInterval(-200))
        let newer = MasterItem(name: "zzz_dupe_test", category: .misc, source: .imported,
                               createdAt: Date())
        try await repos.masterItems.insert(older)
        try await repos.masterItems.insert(newer)

        let before = try context.fetch(FetchDescriptor<MasterItem>(
            predicate: #Predicate { $0.name == "zzz_dupe_test" }
        ))
        XCTAssertEqual(before.count, 2, "Pre-condition: 2 duplicate items must exist before seed")

        let isolated = UserDefaults(suiteName: UUID().uuidString)!
        await ImportService(repository: repos.masterItems, defaults: isolated).seedIfNeeded()

        let after = try context.fetch(FetchDescriptor<MasterItem>(
            predicate: #Predicate { $0.name == "zzz_dupe_test" }
        ))
        XCTAssertEqual(after.count, 1, "Deduplication must leave exactly one item with this name")
        XCTAssertEqual(after.first?.id, older.id,
                       "Deduplication must keep the OLDER item (earliest createdAt), not the newer one")
    }

    // Covers seedIfNeeded() catch block — seededKey must not be set on failure
    func testSeedInsertErrorDoesNotSetSeededFlag() async {
        let isolated = UserDefaults(suiteName: UUID().uuidString)!
        let throwingRepo = InsertThrowingMasterItemRepository()
        await ImportService(repository: throwingRepo, defaults: isolated).seedIfNeeded()

        XCTAssertFalse(isolated.bool(forKey: ImportService.seededKey),
                       "seededKey must not be set when seed insert fails — ensures retry on next launch")
    }

    // Covers the guard-return early exit when seededKey is already set
    func testSeedDoesNotRunWhenAlreadySeeded() async throws {
        let isolated = UserDefaults(suiteName: UUID().uuidString)!
        isolated.set(true, forKey: ImportService.seededKey)
        await ImportService(repository: repos.masterItems, defaults: isolated).seedIfNeeded()

        let items = try context.fetch(FetchDescriptor<MasterItem>())
        XCTAssertEqual(items.count, 0, "No items must be inserted when the seeded flag is already set")
    }

    // Covers removeDuplicateImportedItems delete-error catch — must not crash
    func testSeedDuplicateDeleteErrorIsSilentlyHandled() async {
        let older = MasterItem(name: "zzz_dupe_delete_err", category: .misc, source: .imported,
                               createdAt: Date().addingTimeInterval(-200))
        let newer = MasterItem(name: "zzz_dupe_delete_err", category: .misc, source: .imported,
                               createdAt: Date())
        let throwRepo = DeleteThrowingMasterItemRepository(items: [older, newer])
        let isolated = UserDefaults(suiteName: UUID().uuidString)!

        await ImportService(repository: throwRepo, defaults: isolated).seedIfNeeded()
        // Seed must complete (delete error is swallowed) and set the seeded flag
        XCTAssertTrue(isolated.bool(forKey: ImportService.seededKey),
                      "seededKey must be set — seed must complete successfully despite a delete-error in dedup")
    }

    // Verifies that user-sourced items with duplicate names are NOT deduped
    func testSeedDeduplicationIgnoresUserSourceItems() async throws {
        let user1 = MasterItem(name: "zzz_user_dupe", category: .misc, source: .user,
                               createdAt: Date().addingTimeInterval(-100))
        let user2 = MasterItem(name: "zzz_user_dupe", category: .misc, source: .user,
                               createdAt: Date())
        try await repos.masterItems.insert(user1)
        try await repos.masterItems.insert(user2)

        let isolated = UserDefaults(suiteName: UUID().uuidString)!
        await ImportService(repository: repos.masterItems, defaults: isolated).seedIfNeeded()

        let remaining = try context.fetch(FetchDescriptor<MasterItem>(
            predicate: #Predicate { $0.name == "zzz_user_dupe" }
        ))
        XCTAssertEqual(remaining.count, 2, "User-sourced items must not be touched by deduplication")
    }

    // Verifies re-seed with existing DB does not create duplicates
    func testSeedWithExistingItemsDoesNotDuplicate() async throws {
        let isolated = UserDefaults(suiteName: UUID().uuidString)!
        let service = ImportService(repository: repos.masterItems, defaults: isolated)

        await service.seedIfNeeded()
        let firstCount = try context.fetch(FetchDescriptor<MasterItem>()).count
        XCTAssertGreaterThan(firstCount, 0, "First seed must insert items")

        isolated.set(false, forKey: ImportService.seededKey)
        await service.seedIfNeeded()

        let secondCount = try context.fetch(FetchDescriptor<MasterItem>()).count
        XCTAssertEqual(firstCount, secondCount,
                       "Re-seed with existing items must not duplicate — dedup + skip-present logic must apply")
    }
}

// MARK: - MasterItemRepository coverage tests

@MainActor
final class MasterItemRepositoryTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!
    var repo: SwiftDataMasterItemRepository!

    override func setUpWithError() throws {
        let schema = Schema([TripSession.self, TripInfo.self, MasterItem.self,
                             TripItem.self, ItemInsight.self, PendingSuggestion.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: config)
        context = ModelContext(container)
        repo = SwiftDataMasterItemRepository(context: context)
    }

    override func tearDown() {
        repo = nil
        context = nil
        container = nil
    }

    func testFetchActiveReturnsOnlyActiveItems() async throws {
        let active1  = MasterItem(name: "Active 1", category: .clothing, isActive: true)
        let active2  = MasterItem(name: "Active 2", category: .tech,     isActive: true)
        let inactive = MasterItem(name: "Inactive", category: .misc,     isActive: false)
        try await repo.insert(active1)
        try await repo.insert(active2)
        try await repo.insert(inactive)

        let result = try await repo.fetchActive()
        XCTAssertEqual(result.count, 2, "fetchActive() must return only active items")
        XCTAssertFalse(result.contains { $0.name == "Inactive" },
                       "Inactive item must not appear in fetchActive() results")
    }

    func testFetchActiveWithMatchingTagsFilters() async throws {
        let golfItem  = MasterItem(name: "Golf Glove", category: .golf,      tags: [.golf],  isActive: true)
        let passItem  = MasterItem(name: "Passport",   category: .documents, tags: [.always], isActive: true)
        let beachItem = MasterItem(name: "Sunscreen",  category: .hygiene,   tags: [.beach], isActive: true)
        try await repo.insert(golfItem)
        try await repo.insert(passItem)
        try await repo.insert(beachItem)

        let result = try await repo.fetchActive(matchingAnyOf: [.golf, .beach])
        XCTAssertEqual(result.count, 2,
                       "fetchActive(matchingAnyOf:) must return items matching any of the supplied tags")
        XCTAssertTrue(result.contains { $0.name == "Golf Glove" })
        XCTAssertTrue(result.contains { $0.name == "Sunscreen" })
        XCTAssertFalse(result.contains { $0.name == "Passport" },
                       "Item without a matching tag must be excluded")
    }

    func testFetchActiveWithEmptyTagsReturnsAllActive() async throws {
        let item1 = MasterItem(name: "Item A", category: .misc, tags: [.always], isActive: true)
        let item2 = MasterItem(name: "Item B", category: .tech, tags: [.golf],   isActive: true)
        try await repo.insert(item1)
        try await repo.insert(item2)

        let result = try await repo.fetchActive(matchingAnyOf: [])
        XCTAssertEqual(result.count, 2,
                       "fetchActive(matchingAnyOf: []) must return all active items when tag set is empty")
    }

    func testFetchByIdReturnsCorrectItem() async throws {
        let item = MasterItem(name: "Known Item", category: .tech)
        try await repo.insert(item)

        let fetched = try await repo.fetch(id: item.id)
        XCTAssertNotNil(fetched, "fetch(id:) must return the item for a known ID")
        XCTAssertEqual(fetched?.name, "Known Item")
        XCTAssertEqual(fetched?.id, item.id)
    }

    func testFetchByIdReturnsNilForUnknownId() async throws {
        let result = try await repo.fetch(id: UUID())
        XCTAssertNil(result, "fetch(id:) must return nil for an ID that does not exist")
    }

    func testDeleteRemovesItemFromStore() async throws {
        let item = MasterItem(name: "To Delete", category: .misc)
        try await repo.insert(item)

        let before = try context.fetch(FetchDescriptor<MasterItem>())
        XCTAssertEqual(before.count, 1, "Pre-condition: item must exist before delete")

        try await repo.delete(item)

        let after = try context.fetch(FetchDescriptor<MasterItem>())
        XCTAssertEqual(after.count, 0, "Item must be removed from store after delete()")
    }

    func testFetchAllIncludesInactiveItems() async throws {
        let active   = MasterItem(name: "Active",   category: .misc, isActive: true)
        let inactive = MasterItem(name: "Inactive", category: .misc, isActive: false)
        try await repo.insert(active)
        try await repo.insert(inactive)

        let all = try await repo.fetchAll()
        XCTAssertEqual(all.count, 2, "fetchAll() must return both active and inactive items")
    }

    func testDeactivateItemExcludesFromFetchActive() async throws {
        let item = MasterItem(name: "Deactivate Me", category: .misc, isActive: true)
        try await repo.insert(item)

        let activeBefore = try await repo.fetchActive()
        XCTAssertEqual(activeBefore.count, 1, "Item must appear in fetchActive() when active")

        item.isActive = false
        try context.save()

        let activeAfter = try await repo.fetchActive()
        XCTAssertEqual(activeAfter.count, 0, "Deactivated item must not appear in fetchActive()")
    }

    func testFetchByCategory() async throws {
        let clothing = MasterItem(name: "T-Shirt", category: .clothing, isActive: true)
        let tech     = MasterItem(name: "Laptop",  category: .tech,     isActive: true)
        try await repo.insert(clothing)
        try await repo.insert(tech)

        let all = try await repo.fetchAll()
        XCTAssertEqual(all.filter { $0.category == .clothing }.count, 1,
                       "Exactly 1 clothing item must be in the store")
        XCTAssertEqual(all.filter { $0.category == .tech }.count, 1,
                       "Exactly 1 tech item must be in the store")
    }
}

// MARK: - TripItemRepository coverage tests

@MainActor
final class TripItemRepositoryTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!
    var repo: SwiftDataTripItemRepository!

    override func setUpWithError() throws {
        let schema = Schema([TripSession.self, TripInfo.self, MasterItem.self,
                             TripItem.self, ItemInsight.self, PendingSuggestion.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: config)
        context = ModelContext(container)
        repo = SwiftDataTripItemRepository(context: context)
    }

    override func tearDown() {
        repo = nil
        context = nil
        container = nil
    }

    func testFetchAllScopedToTripId() async throws {
        let tripA = UUID()
        let tripB = UUID()
        for i in 0..<3 { try await repo.insert(TripItem(tripId: tripA, name: "A\(i)", category: .misc)) }
        for i in 0..<5 { try await repo.insert(TripItem(tripId: tripB, name: "B\(i)", category: .misc)) }

        let forA = try await repo.fetchAll(for: tripA)
        let forB = try await repo.fetchAll(for: tripB)

        XCTAssertEqual(forA.count, 3, "fetchAll(for:) must return only Trip A's 3 items")
        XCTAssertEqual(forB.count, 5, "fetchAll(for:) must return only Trip B's 5 items")
        XCTAssertTrue(forA.allSatisfy { $0.tripId == tripA }, "All Trip A items must carry Trip A's id")
        XCTAssertTrue(forB.allSatisfy { $0.tripId == tripB }, "All Trip B items must carry Trip B's id")
    }

    func testFetchByIdReturnsCorrectItem() async throws {
        let tripId = UUID()
        let item = TripItem(tripId: tripId, name: "Specific Item", category: .tech)
        try await repo.insert(item)

        let fetched = try await repo.fetch(id: item.id)
        XCTAssertNotNil(fetched, "fetch(id:) must return the item for a known ID")
        XCTAssertEqual(fetched?.id, item.id)
        XCTAssertEqual(fetched?.name, "Specific Item")
    }

    func testFetchByIdReturnsNilForUnknownId() async throws {
        let result = try await repo.fetch(id: UUID())
        XCTAssertNil(result, "fetch(id:) must return nil for an ID that does not exist")
    }

    func testUpdateCompletedAtPersists() async throws {
        let tripId = UUID()
        let item = TripItem(tripId: tripId, name: "Pack Me", category: .clothing)
        try await repo.insert(item)

        XCTAssertNil(item.completedAt, "Item must start with nil completedAt")

        let now = Date()
        item.completedAt = now
        try await repo.update(item)

        let fetched = try await repo.fetch(id: item.id)
        XCTAssertNotNil(fetched?.completedAt, "completedAt must persist after update()")
        XCTAssertEqual(fetched?.completedAt?.timeIntervalSinceReferenceDate ?? 0,
                       now.timeIntervalSinceReferenceDate, accuracy: 1,
                       "Persisted completedAt must match the value set before update()")
    }

    func testDeleteItemRemovesFromStore() async throws {
        let tripId = UUID()
        let item = TripItem(tripId: tripId, name: "Delete Me", category: .misc)
        try await repo.insert(item)

        let before = try await repo.fetchAll(for: tripId)
        XCTAssertEqual(before.count, 1, "Pre-condition: item must exist before delete")

        try await repo.delete(item)

        let after = try await repo.fetchAll(for: tripId)
        XCTAssertEqual(after.count, 0, "Item must be gone after delete()")
    }

    func testFetchAllForUnknownTripIdReturnsEmpty() async throws {
        let result = try await repo.fetchAll(for: UUID())
        XCTAssertEqual(result.count, 0, "fetchAll(for: unknownId) must return an empty array")
    }

    func testFetchItemsByPackingLocation() async throws {
        let tripId = UUID()
        let carryOn    = TripItem(tripId: tripId, name: "Carry-on Item", category: .tech,
                                   packingLocation: .carryOn)
        let checkedBag = TripItem(tripId: tripId, name: "Checked Item",  category: .clothing,
                                   packingLocation: .checkedBag)
        let backpack   = TripItem(tripId: tripId, name: "Backpack Item", category: .misc,
                                   packingLocation: .backpack)
        try await repo.insert(carryOn)
        try await repo.insert(checkedBag)
        try await repo.insert(backpack)

        let all = try await repo.fetchAll(for: tripId)
        XCTAssertEqual(all.filter { $0.packingLocation == .carryOn }.count, 1,
                       "Exactly 1 carryOn item must be fetched")
        XCTAssertEqual(all.filter { $0.packingLocation == .checkedBag }.count, 1,
                       "Exactly 1 checkedBag item must be fetched")
        XCTAssertEqual(all.filter { $0.packingLocation == .backpack }.count, 1,
                       "Exactly 1 backpack item must be fetched")
    }
}
