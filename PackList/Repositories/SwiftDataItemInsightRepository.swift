import Foundation
import SwiftData

@MainActor
final class SwiftDataItemInsightRepository: ItemInsightRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetch(masterItemId: UUID) async throws -> [ItemInsight] {
        let descriptor = FetchDescriptor<ItemInsight>(
            predicate: #Predicate { $0.masterItemId == masterItemId }
        )
        return try context.fetch(descriptor)
    }

    func upsert(_ insight: ItemInsight) async throws {
        let id = insight.id
        var descriptor = FetchDescriptor<ItemInsight>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        if try context.fetch(descriptor).isEmpty {
            context.insert(insight)
        }
        try context.save()
    }
}
