import Foundation

protocol TripItemRepository {
    func fetchAll(for tripId: UUID) async throws -> [TripItem]
    func fetch(id: UUID) async throws -> TripItem?
    func insert(_ item: TripItem) async throws
    func update(_ item: TripItem) async throws
    func delete(_ item: TripItem) async throws
}
