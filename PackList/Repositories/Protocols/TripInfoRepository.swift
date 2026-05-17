import Foundation

@MainActor
protocol TripInfoRepository {
    func insert(_ info: TripInfo) async throws
    func update(_ info: TripInfo) async throws
    func delete(_ info: TripInfo) async throws
}
