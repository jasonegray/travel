import Foundation
import SwiftData

@Model
final class PendingSuggestion {
    var id: UUID
    var targetItemId: UUID?
    var tripId: UUID?
    var type: SuggestionType
    var proposedChange: String
    var reasoning: String
    var status: SuggestionStatus
    var createdAt: Date

    init(
        id: UUID = UUID(),
        targetItemId: UUID? = nil,
        tripId: UUID? = nil,
        type: SuggestionType,
        proposedChange: String,
        reasoning: String,
        status: SuggestionStatus = .pending,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.targetItemId = targetItemId
        self.tripId = tripId
        self.type = type
        self.proposedChange = proposedChange
        self.reasoning = reasoning
        self.status = status
        self.createdAt = createdAt
    }
}
