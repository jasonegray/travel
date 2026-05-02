import Foundation

protocol ItemInsightRepository {
    func fetch(masterItemId: UUID) async throws -> [ItemInsight]
    func upsert(_ insight: ItemInsight) async throws
}
