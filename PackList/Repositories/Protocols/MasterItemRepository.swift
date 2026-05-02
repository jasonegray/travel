import Foundation

protocol MasterItemRepository {
    func fetchAll() async throws -> [MasterItem]
    func fetchActive() async throws -> [MasterItem]
    func fetchActive(matchingAnyOf tags: Set<ItemTag>) async throws -> [MasterItem]
    func fetch(id: UUID) async throws -> MasterItem?
    func insert(_ item: MasterItem) async throws
    func delete(_ item: MasterItem) async throws
}
