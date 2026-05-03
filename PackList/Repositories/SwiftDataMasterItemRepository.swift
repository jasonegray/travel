import Foundation
import SwiftData

@MainActor
final class SwiftDataMasterItemRepository: MasterItemRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetchAll() async throws -> [MasterItem] {
        try context.fetch(FetchDescriptor<MasterItem>())
    }

    func fetchActive() async throws -> [MasterItem] {
        try context.fetch(FetchDescriptor<MasterItem>())
            .filter { $0.isActive }
    }

    func fetchActive(matchingAnyOf tags: Set<ItemTag>) async throws -> [MasterItem] {
        let active = try context.fetch(FetchDescriptor<MasterItem>())
            .filter { $0.isActive }
        guard !tags.isEmpty else { return active }
        return active.filter { $0.tags.contains(where: tags.contains) }
    }

    func fetch(id: UUID) async throws -> MasterItem? {
        var descriptor = FetchDescriptor<MasterItem>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    func insert(_ item: MasterItem) async throws {
        context.insert(item)
        try context.save()
    }

    func delete(_ item: MasterItem) async throws {
        context.delete(item)
        try context.save()
    }
}
