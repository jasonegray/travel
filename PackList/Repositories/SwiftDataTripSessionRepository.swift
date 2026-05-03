import Foundation
import SwiftData

@MainActor
final class SwiftDataTripSessionRepository: TripSessionRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetchAll() async throws -> [TripSession] {
        try context.fetch(FetchDescriptor<TripSession>())
    }

    func fetch(id: UUID) async throws -> TripSession? {
        var descriptor = FetchDescriptor<TripSession>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    func fetch(status: TripStatus) async throws -> [TripSession] {
        try context.fetch(FetchDescriptor<TripSession>())
            .filter { $0.status == status }
    }

    func insert(_ session: TripSession) async throws {
        context.insert(session)
        try context.save()
    }

    func delete(_ session: TripSession) async throws {
        context.delete(session)
        try context.save()
    }
}
