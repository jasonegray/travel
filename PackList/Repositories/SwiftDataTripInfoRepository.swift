import Foundation
import SwiftData

@MainActor
final class SwiftDataTripInfoRepository: TripInfoRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func insert(_ info: TripInfo) async throws {
        context.insert(info)
        try context.save()
    }

    func update(_ info: TripInfo) async throws {
        try context.save()
    }

    func delete(_ info: TripInfo) async throws {
        context.delete(info)
        try context.save()
    }
}
