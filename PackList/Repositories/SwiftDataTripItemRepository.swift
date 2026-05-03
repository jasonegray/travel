import Foundation
import SwiftData

@MainActor
final class SwiftDataTripItemRepository: TripItemRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetchAll(for tripId: UUID) async throws -> [TripItem] {
        try context.fetch(FetchDescriptor<TripItem>())
            .filter { $0.tripId == tripId }
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
