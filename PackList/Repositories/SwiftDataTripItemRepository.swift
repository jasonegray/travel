import Foundation
import SwiftData

final class SwiftDataTripItemRepository: TripItemRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetchAll(for tripId: UUID) async throws -> [TripItem] {
        let descriptor = FetchDescriptor<TripItem>(
            predicate: #Predicate { $0.tripId == tripId }
        )
        return try context.fetch(descriptor)
    }

    func fetch(id: UUID) async throws -> TripItem? {
        var descriptor = FetchDescriptor<TripItem>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    func insert(_ item: TripItem) async throws {
        context.insert(item)
        try context.save()
    }

    func update(_ item: TripItem) async throws {
        try context.save()
    }

    func delete(_ item: TripItem) async throws {
        context.delete(item)
        try context.save()
    }
}
