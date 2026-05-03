import Foundation

@MainActor
protocol TripSessionRepository {
    func fetchAll() async throws -> [TripSession]
    func fetch(id: UUID) async throws -> TripSession?
    func fetch(status: TripStatus) async throws -> [TripSession]
    func insert(_ session: TripSession) async throws
    func delete(_ session: TripSession) async throws
}
