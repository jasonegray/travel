import Foundation
import SwiftData

@Model
final class MasterItem {
    var id: UUID
    var ownerId: UUID?
    var requiredByItemId: UUID?
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
    var quantityRules: [QuantityRule]
    var replaceabilityRules: [ReplaceabilityRule]
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        ownerId: UUID? = nil,
        requiredByItemId: UUID? = nil,
        name: String,
        category: ItemCategory,
        itemType: ItemType = .physical,
        tags: [ItemTag] = [],
        flightAccessible: Bool = true,
        isAlwaysInclude: Bool = false,
        defaultQuantity: Int = 1,
        packingLocation: PackingLocation? = nil,
        recommendedTiming: TaskTiming? = nil,
        isActive: Bool = true,
        source: ItemSource = .user,
        notes: String? = nil,
        quantityRules: [QuantityRule] = [],
        replaceabilityRules: [ReplaceabilityRule] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.ownerId = ownerId
        self.requiredByItemId = requiredByItemId
        self.name = name
        self.category = category
        self.itemType = itemType
        self.tags = tags
        self.flightAccessible = flightAccessible
        self.isAlwaysInclude = isAlwaysInclude
        self.defaultQuantity = defaultQuantity
        self.packingLocation = packingLocation
        self.recommendedTiming = recommendedTiming
        self.isActive = isActive
        self.source = source
        self.notes = notes
        self.quantityRules = quantityRules
        self.replaceabilityRules = replaceabilityRules
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
