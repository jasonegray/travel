import Foundation
import SwiftData

@MainActor
final class SwiftDataPendingSuggestionRepository: PendingSuggestionRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetch(status: SuggestionStatus) async throws -> [PendingSuggestion] {
        try context.fetch(FetchDescriptor<PendingSuggestion>())
            .filter { $0.status == status }
    }

    func fetch(tripId: UUID) async throws -> [PendingSuggestion] {
        try context.fetch(FetchDescriptor<PendingSuggestion>())
            .filter { $0.tripId == tripId }
    }

    func insert(_ suggestion: PendingSuggestion) async throws {
        context.insert(suggestion)
        try context.save()
    }

    func update(_ suggestion: PendingSuggestion) async throws {
        try context.save()
    }

    func delete(_ suggestion: PendingSuggestion) async throws {
        context.delete(suggestion)
        try context.save()
    }
}
