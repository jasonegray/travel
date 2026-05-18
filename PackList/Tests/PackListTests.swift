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
