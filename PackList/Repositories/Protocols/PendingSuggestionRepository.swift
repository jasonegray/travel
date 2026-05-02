import Foundation

protocol PendingSuggestionRepository {
    func fetch(status: SuggestionStatus) async throws -> [PendingSuggestion]
    func fetch(tripId: UUID) async throws -> [PendingSuggestion]
    func insert(_ suggestion: PendingSuggestion) async throws
    func update(_ suggestion: PendingSuggestion) async throws
    func delete(_ suggestion: PendingSuggestion) async throws
}
