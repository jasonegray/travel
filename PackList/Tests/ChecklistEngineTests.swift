import XCTest
import SwiftData
@testable import PackList

final class ChecklistEngineTests: XCTestCase {

    // MARK: - Fixtures

    var engine: ChecklistEngine!
    var container: ModelContainer!
    var context: ModelContext!

    override func setUpWithError() throws {
        engine = ChecklistEngine()
        let schema = Schema([TripSession.self, TripInfo.self, MasterItem.self, TripItem.self,
                             ItemInsight.self, PendingSuggestion.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: config)
        context = ModelContext(container)
    }

    override func tearDown() {
        engine = nil
        context = nil
        container = nil
    }

    // MARK: - Always-include logic

    func testIsAlwaysInclude_addsItemRegardlessOfTags() {
        let session = makeSession()
        let item = makeItem(name: "Passport", isAlwaysInclude: true, tags: [])
        let result = engine.generateItems(for: session, from: [item])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].name, "Passport")
    }

    func testAlwaysTag_addsItemRegardlessOfProfile() {
        let session = makeSession(weather: .mild, activities: [])
        let item = makeItem(name: "Charger", tags: [.always])
        let result = engine.generateItems(for: session, from: [item])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].name, "Charger")
    }

    func testAlwaysInclude_notDuplicated_whenTagAlsoMatches() {
        let session = makeSession(activities: [.golf])
        let item = makeItem(name: "Hat", isAlwaysInclude: true, tags: [.golf])
        let result = engine.generateItems(for: session, from: [item])
        XCTAssertEqual(result.count, 1, "Item should appear exactly once")
    }

    // MARK: - Tag matching

    func testTagMatch_golfItem_includedForGolfTrip() {
        let session  = makeSession(activities: [.golf])
        let golfShoe = makeItem(name: "Golf Shoes", tags: [.golf])
        let snorkel  = makeItem(name: "Snorkel",    tags: [.beach])
        let result   = engine.generateItems(for: session, from: [golfShoe, snorkel])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].name, "Golf Shoes")
    }

    func testTagMatch_beachActivity_includesBothBeachAndPoolTaggedItems() {
        let session   = makeSession(activities: [.beach])
        let beachItem = makeItem(name: "Sunscreen",  tags: [.beach])
        let poolItem  = makeItem(name: "Pool Float", tags: [.pool])
        let result    = engine.generateItems(for: session, from: [beachItem, poolItem])
        XCTAssertEqual(result.count, 2, "Both .beach and .pool tags activated when .beach activity present")
    }

    func testTagMatch_coldWeather() {
        let session  = makeSession(weather: .cold)
        let coldGear = makeItem(name: "Thermal", tags: [.cold])
        let warmGear = makeItem(name: "T-Shirt",  tags: [.warm])
        let result   = engine.generateItems(for: session, from: [coldGear, warmGear])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].name, "Thermal")
    }

    func testTagMatch_hotWeather_activatesWarmTag() {
        let session  = makeSession(weather: .hot)
        let warmItem = makeItem(name: "Sun Hat", tags: [.warm])
        let result   = engine.generateItems(for: session, from: [warmItem])
        XCTAssertEqual(result.count, 1, ".hot weather should activate the .warm tag")
    }

    func testTagMatch_internationalRegion_europe() {
        let session      = makeSession(region: .europe)
        let europeItem   = makeItem(name: "Rail Pass",     tags: [.europe])
        let intlItem     = makeItem(name: "Power Adaptor", tags: [.international])
        let domesticItem = makeItem(name: "Local Card",    tags: [.us])
        let result = engine.generateItems(for: session, from: [europeItem, intlItem, domesticItem])
        XCTAssertEqual(result.count, 2)
    }

    func testTagMatch_kidsCompanion_activatesFamilyTag() {
        let session = makeSession(companions: [.kids])
        let active  = engine.activeTags(for: session)
        XCTAssertTrue(active.contains(.family), ".kids companion must activate the .family tag")
    }

    func testTagMatch_familyCompanion_activatesFamilyTag() {
        let session = makeSession(companions: [.family])
        let active  = engine.activeTags(for: session)
        XCTAssertTrue(active.contains(.family), ".family companion must activate the .family tag")
    }

    func testTagMatch_conferenceActivity_activatesConferenceAndBusinessTags() {
        let session = makeSession(activities: [.conference])
        let active  = engine.activeTags(for: session)
        XCTAssertTrue(active.contains(.conference), ".conference activity must activate .conference tag")
        XCTAssertTrue(active.contains(.business),   ".conference activity must also activate .business tag")
    }

    func testTagMatch_conferenceItem_includedForConferenceTrip() {
        let session       = makeSession(activities: [.conference])
        let badgeHolder   = makeItem(name: "Name badge holder", tags: [.conference])
        let unrelatedItem = makeItem(name: "Snorkel",            tags: [.beach])
        let result        = engine.generateItems(for: session, from: [badgeHolder, unrelatedItem])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].name, "Name badge holder")
    }

    func testTagMatch_businessItem_includedForConferenceTrip() {
        let session      = makeSession(activities: [.conference])
        let dressShirt   = makeItem(name: "Dress shirt", tags: [.business])
        let result       = engine.generateItems(for: session, from: [dressShirt])
        XCTAssertEqual(result.count, 1, "Business-tagged items must be included when conference is selected")
    }

    func testTagMatch_guysTripActivity_activatesCasualAndPersonalTags() {
        let session = makeSession(activities: [.guysTrip])
        let active  = engine.activeTags(for: session)
        XCTAssertTrue(active.contains(.casual),   ".guysTrip activity must activate .casual tag")
        XCTAssertTrue(active.contains(.personal), ".guysTrip activity must activate .personal tag")
    }

    func testTagMatch_guysTripActivity_doesNotActivateBusinessOrConference() {
        let session = makeSession(activities: [.guysTrip])
        let active  = engine.activeTags(for: session)
        XCTAssertFalse(active.contains(.business),   ".guysTrip must never activate .business tag")
        XCTAssertFalse(active.contains(.conference), ".guysTrip must never activate .conference tag")
    }

    func testTagMatch_guysTripItem_includesCasualItem_excludesBusinessItem() {
        let session     = makeSession(activities: [.guysTrip])
        let dayBag      = makeItem(name: "Fanny pack",  tags: [.casual])
        let dressShirt  = makeItem(name: "Dress shirt", tags: [.business])
        let result      = engine.generateItems(for: session, from: [dayBag, dressShirt])
        XCTAssertEqual(result.count, 1, "Guys Trip includes casual items but no business items")
        XCTAssertEqual(result[0].name, "Fanny pack")
    }

    func testTagMatch_japanRegion_activatesJapanAsiaInternational() {
        let session = makeSession(region: .japan, isFlyingTrip: true)
        let active  = engine.activeTags(for: session)
        XCTAssertTrue(active.contains(.japan))
        XCTAssertTrue(active.contains(.asia))
        XCTAssertTrue(active.contains(.international))
        XCTAssertTrue(active.contains(.longHaul))
    }

    // MARK: - Quantity formula — 5-night golf trip with laundry

    func testQuantity_halfDaysRoundUp_fiveNightGolfWithLaundry() {
        let departure = date(year: 2024, month: 6, day: 1)
        let returnDay = date(year: 2024, month: 6, day: 6) // 5 nights
        let session = makeSession(weather: .warm, activities: [.golf],
                                  laundryAvailable: true,
                                  departure: departure, returnDate: returnDay)
        let rule  = QuantityRule(contextTags: [.golf], laundryAvailable: true,
                                 formula: .halfDays(roundUp: true))
        let shirt = makeItem(name: "Golf Shirt", tags: [.golf], defaultQuantity: 7,
                             quantityRules: [rule])
        let result = engine.generateItems(for: session, from: [shirt])
        XCTAssertEqual(result[0].quantity, 3, "ceil(5 / 2) = 3")
    }

    func testQuantity_halfDaysRoundDown() {
        let departure = date(year: 2024, month: 6, day: 1)
        let returnDay = date(year: 2024, month: 6, day: 6)
        let session = makeSession(activities: [.golf], laundryAvailable: true,
                                  departure: departure, returnDate: returnDay)
        let rule = QuantityRule(contextTags: [.golf], laundryAvailable: true,
                                formula: .halfDays(roundUp: false))
        let item = makeItem(tags: [.golf], quantityRules: [rule])
        let result = engine.generateItems(for: session, from: [item])
        XCTAssertEqual(result[0].quantity, 2, "floor(5 / 2) = 2")
    }

    func testQuantity_perDay() {
        let departure = date(year: 2024, month: 6, day: 1)
        let returnDay = date(year: 2024, month: 6, day: 6)
        let session = makeSession(activities: [.golf], departure: departure, returnDate: returnDay)
        let rule = QuantityRule(contextTags: [.golf], laundryAvailable: nil, formula: .perDay)
        let item = makeItem(tags: [.golf], quantityRules: [rule])
        let result = engine.generateItems(for: session, from: [item])
        XCTAssertEqual(result[0].quantity, 5, "1 per night × 5 nights = 5")
    }

    func testQuantity_fixed() {
        let session = makeSession(activities: [.golf])
        let rule = QuantityRule(contextTags: [.golf], laundryAvailable: nil, formula: .fixed(3))
        let item = makeItem(tags: [.golf], defaultQuantity: 1, quantityRules: [rule])
        let result = engine.generateItems(for: session, from: [item])
        XCTAssertEqual(result[0].quantity, 3)
    }

    func testQuantity_customFormula() {
        let departure = date(year: 2024, month: 6, day: 1)
        let returnDay = date(year: 2024, month: 6, day: 6) // 5 nights
        let session = makeSession(activities: [.golf], departure: departure, returnDate: returnDay)
        // base 1 + (5 nights × 0.5) = 3.5 → round up → 4
        let rule = QuantityRule(contextTags: [.golf], laundryAvailable: nil,
                                formula: .custom(base: 1, perDay: 0.5, roundUp: true))
        let item = makeItem(tags: [.golf], quantityRules: [rule])
        let result = engine.generateItems(for: session, from: [item])
        XCTAssertEqual(result[0].quantity, 4, "ceil(1 + 5 × 0.5) = ceil(3.5) = 4")
    }

    func testQuantity_laundryMismatch_fallsThrough_toNextRule() {
        let session = makeSession(activities: [.golf], laundryAvailable: false)
        let ruleWithLaundry    = QuantityRule(contextTags: [.golf], laundryAvailable: true,  formula: .fixed(3))
        let ruleWithoutLaundry = QuantityRule(contextTags: [.golf], laundryAvailable: false, formula: .fixed(7))
        let item = makeItem(tags: [.golf], defaultQuantity: 1,
                            quantityRules: [ruleWithLaundry, ruleWithoutLaundry])
        let result = engine.generateItems(for: session, from: [item])
        XCTAssertEqual(result[0].quantity, 7, "Laundry-required rule must be skipped; no-laundry rule wins")
    }

    func testQuantity_noMatchingRule_usesDefaultQuantity() {
        let session = makeSession(activities: [.golf])
        let rule = QuantityRule(contextTags: [.business], laundryAvailable: nil, formula: .fixed(99))
        let item = makeItem(tags: [.golf], defaultQuantity: 2, quantityRules: [rule])
        let result = engine.generateItems(for: session, from: [item])
        XCTAssertEqual(result[0].quantity, 2)
    }

    // MARK: - Dependency resolution chain

    func testDependencyResolution_directDependency() {
        let session = makeSession()
        let aId   = UUID()
        let itemA = makeItem(name: "Item A", id: aId, tags: [.always])
        let itemB = makeItem(name: "Item B", requiredByItemId: aId, tags: [])
        let result = engine.generateItems(for: session, from: [itemA, itemB])
        XCTAssertEqual(result.count, 2)
        XCTAssertTrue(result.map { $0.name }.contains("Item B"),
                      "Dependency of always-item must be pulled in")
    }

    func testDependencyResolution_chain() {
        let session = makeSession()
        let aId = UUID()
        let bId = UUID()
        let itemA = makeItem(name: "A", id: aId, tags: [.always])
        let itemB = makeItem(name: "B", id: bId, requiredByItemId: aId, tags: [])
        let itemC = makeItem(name: "C",           requiredByItemId: bId, tags: [])
        let result = engine.generateItems(for: session, from: [itemA, itemB, itemC])
        XCTAssertEqual(result.count, 3, "A → B → C chain must all be included")
    }

    func testDependencyResolution_notIncluded_whenAnchorExcluded() {
        let session = makeSession(activities: [])
        let aId   = UUID()
        let itemA = makeItem(name: "A", id: aId, tags: [.golf]) // excluded — no golf activity
        let itemB = makeItem(name: "B", requiredByItemId: aId, tags: [])
        let result = engine.generateItems(for: session, from: [itemA, itemB])
        XCTAssertEqual(result.count, 0, "Dependency must not be pulled in when its anchor is excluded")
    }

    func testDependencyResolution_circularDeps_doNotLoop() {
        let session = makeSession()
        let aId = UUID()
        let bId = UUID()
        // A is always-included; A "required by" B (circular), B required by A
        let itemA = makeItem(name: "A", id: aId, requiredByItemId: bId, tags: [.always])
        let itemB = makeItem(name: "B", id: bId, requiredByItemId: aId, tags: [])
        let result = engine.generateItems(for: session, from: [itemA, itemB])
        XCTAssertEqual(result.count, 2)
    }

    // MARK: - Empty trip profile edge case

    func testEmptyProfile_onlyAlwaysItemsIncluded() {
        let session    = makeSession(weather: .mild, activities: [], region: .canada,
                                     business: false, companions: [.solo])
        let golfItem   = makeItem(name: "Golf Bag", tags: [.golf])
        let alwaysTag  = makeItem(name: "Phone",    tags: [.always])
        let alwaysFlag = makeItem(name: "Passport", isAlwaysInclude: true, tags: [])
        let coldItem   = makeItem(name: "Thermal",  tags: [.cold])
        let result     = engine.generateItems(for: session, from: [golfItem, alwaysTag, alwaysFlag, coldItem])
        XCTAssertEqual(result.count, 2)
        let names = result.map { $0.name }
        XCTAssertTrue(names.contains("Phone"))
        XCTAssertTrue(names.contains("Passport"))
    }

    func testEmptyProfile_derivesNoActiveTags() {
        let session = makeSession(weather: .mild, activities: [], region: .canada)
        let active  = engine.activeTags(for: session)
        XCTAssertTrue(active.isEmpty, "Mild/Canada/no-activities session should produce zero active tags")
    }

    // MARK: - Long-trip threshold

    func testLongTrip_sixNights_activatesLongTripTag() {
        let dep = date(year: 2024, month: 7, day: 1)
        let ret = date(year: 2024, month: 7, day: 7) // 6 nights
        let session = makeSession(departure: dep, returnDate: ret)
        let active  = engine.activeTags(for: session)
        XCTAssertTrue(active.contains(.longTrip))
    }

    func testLongTrip_fiveNights_doesNotActivateLongTripTag() {
        let dep = date(year: 2024, month: 7, day: 1)
        let ret = date(year: 2024, month: 7, day: 6) // exactly 5 nights — threshold is > 5
        let session = makeSession(departure: dep, returnDate: ret)
        let active  = engine.activeTags(for: session)
        XCTAssertFalse(active.contains(.longTrip))
    }

    // MARK: - Generated TripItem fields

    func testGeneratedItem_hasCorrectSourceAndTripId() {
        let session = makeSession()
        let item    = makeItem(tags: [.always])
        let result  = engine.generateItems(for: session, from: [item])
        XCTAssertEqual(result[0].source, .generated)
        XCTAssertEqual(result[0].tripId, session.id)
        XCTAssertNil(result[0].completedAt)
    }

    func testGeneratedItem_usesPackingLocationFromMasterItem() {
        let session = makeSession()
        let item    = makeItem(tags: [.always], packingLocation: .techPouch)
        let result  = engine.generateItems(for: session, from: [item])
        XCTAssertEqual(result[0].packingLocation, .techPouch)
    }

    func testGeneratedItem_defaultsToCarryOn_whenNoPackingLocation() {
        let session = makeSession()
        let item    = makeItem(tags: [.always], packingLocation: nil)
        let result  = engine.generateItems(for: session, from: [item])
        XCTAssertEqual(result[0].packingLocation, .carryOn)
    }

    // MARK: - Edge cases

    func testChecklistEngineOneDayTrip() {
        let today = Calendar.current.startOfDay(for: Date())
        let session = makeSession(departure: today, returnDate: today)
        let alwaysItem = makeItem(name: "Passport", isAlwaysInclude: true, tags: [])
        let taggedItem = makeItem(name: "Phone", tags: [.always])
        let result = engine.generateItems(for: session, from: [alwaysItem, taggedItem])
        XCTAssertGreaterThan(result.count, 0,
                             "Single-day (0-night) trip must still generate always-include items")
    }

    func testChecklistEngineSameDayDeparture() {
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        let session = makeSession(departure: today, returnDate: tomorrow)
        let alwaysItem = makeItem(name: "Wallet", isAlwaysInclude: true, tags: [])
        let result = engine.generateItems(for: session, from: [alwaysItem])
        XCTAssertGreaterThan(result.count, 0, "Trip departing today must still generate items")
    }

    func testChecklistEngineNoActivitiesSelected() {
        let session = makeSession(weather: .mild, activities: [], region: .canada)
        let alwaysItem  = makeItem(name: "Passport", isAlwaysInclude: true, tags: [])
        let taggedItem  = makeItem(name: "Charger",  tags: [.always])
        let golfItem    = makeItem(name: "Golf Bag", tags: [.golf])
        let result = engine.generateItems(for: session, from: [alwaysItem, taggedItem, golfItem])
        XCTAssertEqual(result.count, 2,
                       "No activities: only always-include and always-tagged items must appear; activity items excluded")
    }

    func testChecklistEngineAllActivitiesSelected() {
        let session = makeSession(activities: ActivityType.allCases)
        let items: [MasterItem] = [
            makeItem(name: "Golf Item",       tags: [.golf]),
            makeItem(name: "Beach Item",      tags: [.beach]),
            makeItem(name: "Pool Item",       tags: [.pool]),
            makeItem(name: "Workout Item",    tags: [.workout]),
            makeItem(name: "Conference Item", tags: [.conference]),
            makeItem(name: "Always Item",     tags: [.always]),
        ]
        let result = engine.generateItems(for: session, from: items)
        XCTAssertGreaterThan(result.count, 0,
                             "Selecting all activities must generate items without crashing")
    }

    func testChecklistEngineAlwaysIncludeItemsAppearRegardless() {
        let session = makeSession(weather: .mild, activities: [], region: .canada, companions: [.solo])
        let alwaysItems = (0..<5).map { i in
            makeItem(name: "Always-\(i)", isAlwaysInclude: true, tags: [])
        }
        let nonMatchItems: [MasterItem] = [
            makeItem(name: "Golf Bag", tags: [.golf]),
            makeItem(name: "Snorkel",  tags: [.beach]),
            makeItem(name: "Parka",    tags: [.cold]),
        ]
        let result = engine.generateItems(for: session, from: alwaysItems + nonMatchItems)
        let resultNames = Set(result.map(\.name))
        for item in alwaysItems {
            XCTAssertTrue(resultNames.contains(item.name),
                          "Always-include item '\(item.name)' must appear regardless of trip profile")
        }
        XCTAssertEqual(result.count, alwaysItems.count,
                       "Only the 5 always-include items must appear; non-matching tagged items excluded")
    }

    // MARK: - Helpers

    private func makeSession(
        weather: WeatherProfile = .mild,
        activities: [ActivityType] = [],
        region: TravelRegion = .canada,
        business: Bool = false,
        companions: [TravelCompanion] = [.solo],
        laundryAvailable: Bool = false,
        carryOnOnly: Bool = false,
        interacPhone: Bool = false,
        interacLaptop: Bool = false,
        isFlyingTrip: Bool = false,
        departure: Date = Date(),
        returnDate: Date? = nil
    ) -> TripSession {
        TripSession(
            name: "Test",
            destination: "Anywhere",
            region: region,
            departureDate: departure,
            returnDate: returnDate ?? Calendar.current.date(byAdding: .day, value: 3, to: departure)!,
            purposes: [.personal],
            weather: weather,
            companions: companions,
            activities: activities,
            laundryAvailable: laundryAvailable,
            carryOnOnly: carryOnOnly,
            business: business,
            interacPhone: interacPhone,
            interacLaptop: interacLaptop,
            isFlyingTrip: isFlyingTrip
        )
    }

    private func makeItem(
        name: String = "Item",
        id: UUID = UUID(),
        isAlwaysInclude: Bool = false,
        requiredByItemId: UUID? = nil,
        tags: [ItemTag] = [],
        defaultQuantity: Int = 1,
        quantityRules: [QuantityRule] = [],
        packingLocation: PackingLocation? = nil
    ) -> MasterItem {
        MasterItem(
            id: id,
            requiredByItemId: requiredByItemId,
            name: name,
            category: .misc,
            tags: tags,
            isAlwaysInclude: isAlwaysInclude,
            defaultQuantity: defaultQuantity,
            packingLocation: packingLocation,
            quantityRules: quantityRules
        )
    }

    private func date(year: Int, month: Int, day: Int) -> Date {
        var comps = DateComponents()
        comps.year = year; comps.month = month; comps.day = day
        comps.hour = 12 // noon avoids DST edge cases
        return Calendar(identifier: .gregorian).date(from: comps)!
    }
}
