import Foundation
import OSLog

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.jasonegray.PackList",
                            category: "ImportService")

final class ImportService {

    static let seededKey = "masterListSeeded"

    private let repository: any MasterItemRepository
    private let defaults: UserDefaults

    init(repository: any MasterItemRepository, defaults: UserDefaults = .standard) {
        self.repository = repository
        self.defaults = defaults
    }

    func seedIfNeeded() async {
        guard !defaults.bool(forKey: Self.seededKey) else { return }
        do {
            let existing = try await repository.fetchAll()
            if !existing.isEmpty {
                // Items already exist — flag was missing or reset. Deduplicate then repair.
                await removeDuplicateImportedItems(from: existing)
                let remaining = try await repository.fetchAll()
                logger.info("Seed repair complete — \(remaining.count) master items in database")
                defaults.set(true, forKey: Self.seededKey)
                return
            }
            let items = try Self.parseItems()
            for item in items {
                try await repository.insert(item)
            }
            defaults.set(true, forKey: Self.seededKey)
        } catch {
            logger.error("Seed failed — will retry on next launch: \(error)")
        }
    }

    // MARK: - Private

    private func removeDuplicateImportedItems(from items: [MasterItem]) async {
        let sorted = items.sorted { $0.createdAt < $1.createdAt }
        var seen = Set<String>()
        for item in sorted where item.source == .imported {
            if seen.contains(item.name) {
                do {
                    try await repository.delete(item)
                } catch {
                    logger.error("Failed to delete duplicate '\(item.name)': \(error)")
                }
            } else {
                seen.insert(item.name)
            }
        }
    }

    private static func parseItems() throws -> [MasterItem] {
        guard let url = Bundle.main.url(forResource: "master_items", withExtension: "json")
                     ?? Bundle.main.url(forResource: "master_items", withExtension: "json",
                                        subdirectory: "SeedData") else {
            throw ImportError.fileNotFound
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder()
            .decode([MasterItemDTO].self, from: data)
            .map(\.masterItem)
    }
}

// MARK: - Errors

private enum ImportError: Error, LocalizedError {
    case fileNotFound
    var errorDescription: String? { "master_items.json not found in app bundle" }
}

// MARK: - DTOs

private struct MasterItemDTO: Decodable {
    var name: String
    var category: ItemCategory
    var itemType: ItemType
    var tags: [ItemTag]
    var flightAccessible: Bool
    var isAlwaysInclude: Bool
    var defaultQuantity: Int
    var packingLocation: PackingLocation?
    var recommendedTiming: TaskTiming?
    var isActive: Bool
    var source: ItemSource
    var notes: String?
    var quantityRules: [QuantityRuleDTO]
    var replaceabilityRules: [ReplaceabilityRuleDTO]

    private enum CodingKeys: String, CodingKey {
        case name, category, itemType, tags, flightAccessible, isAlwaysInclude
        case defaultQuantity, packingLocation, recommendedTiming, isActive, source
        case notes, quantityRules, replaceabilityRules
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name             = try c.decode(String.self, forKey: .name)
        category         = try c.decode(ItemCategory.self, forKey: .category)
        itemType         = try c.decodeIfPresent(ItemType.self,       forKey: .itemType)         ?? .physical
        tags             = try c.decodeIfPresent([ItemTag].self,      forKey: .tags)             ?? []
        flightAccessible = try c.decodeIfPresent(Bool.self,           forKey: .flightAccessible) ?? true
        isAlwaysInclude  = try c.decodeIfPresent(Bool.self,           forKey: .isAlwaysInclude)  ?? false
        defaultQuantity  = try c.decodeIfPresent(Int.self,            forKey: .defaultQuantity)  ?? 1
        packingLocation  = try c.decodeIfPresent(PackingLocation.self, forKey: .packingLocation)
        recommendedTiming = try c.decodeIfPresent(TaskTiming.self,    forKey: .recommendedTiming)
        isActive         = try c.decodeIfPresent(Bool.self,           forKey: .isActive)         ?? true
        source           = try c.decodeIfPresent(ItemSource.self,     forKey: .source)           ?? .imported
        notes            = try c.decodeIfPresent(String.self,         forKey: .notes)
        quantityRules    = try c.decodeIfPresent([QuantityRuleDTO].self,        forKey: .quantityRules)        ?? []
        replaceabilityRules = try c.decodeIfPresent([ReplaceabilityRuleDTO].self, forKey: .replaceabilityRules) ?? []
    }

    var masterItem: MasterItem {
        MasterItem(
            name: name,
            category: category,
            itemType: itemType,
            tags: tags,
            flightAccessible: flightAccessible,
            isAlwaysInclude: isAlwaysInclude,
            defaultQuantity: defaultQuantity,
            packingLocation: packingLocation,
            recommendedTiming: recommendedTiming,
            isActive: isActive,
            source: source,
            notes: notes,
            quantityRules: quantityRules.map(\.quantityRule),
            replaceabilityRules: replaceabilityRules.map(\.replaceabilityRule)
        )
    }
}

private struct QuantityRuleDTO: Decodable {
    var contextTags: [ItemTag]
    var laundryAvailable: Bool?
    var formula: QuantityFormulaDTO

    private enum CodingKeys: String, CodingKey { case contextTags, laundryAvailable, formula }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        contextTags      = try c.decodeIfPresent([ItemTag].self, forKey: .contextTags) ?? []
        laundryAvailable = try c.decodeIfPresent(Bool.self, forKey: .laundryAvailable)
        formula          = try c.decode(QuantityFormulaDTO.self, forKey: .formula)
    }

    var quantityRule: QuantityRule {
        QuantityRule(contextTags: contextTags, laundryAvailable: laundryAvailable,
                     formula: formula.quantityFormula)
    }
}

private struct QuantityFormulaDTO: Decodable {
    var type: String
    var n: Int?
    var roundUp: Bool?
    var base: Int?
    var perDay: Double?

    var quantityFormula: QuantityFormula {
        switch type {
        case "fixed":    return .fixed(n ?? 1)
        case "halfDays": return .halfDays(roundUp: roundUp ?? true)
        case "perDay":   return .perDay
        case "custom":   return .custom(base: base ?? 0, perDay: perDay ?? 1.0, roundUp: roundUp ?? true)
        default:         return .fixed(1)
        }
    }
}

private struct ReplaceabilityRuleDTO: Decodable {
    var regions: [TravelRegion]?
    var tripPurposes: [TripPurpose]?
    var replaceability: Replaceability

    var replaceabilityRule: ReplaceabilityRule {
        ReplaceabilityRule(regions: regions, tripPurposes: tripPurposes,
                           replaceability: replaceability)
    }
}
