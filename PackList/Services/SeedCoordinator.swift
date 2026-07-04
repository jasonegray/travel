import Foundation

/// Coordinates the one-time master-list seed so every caller awaits a single
/// shared seed operation.
///
/// Fixes the first-run race (#348): on a fresh install the seed runs
/// asynchronously from `HomeView`, but trip creation reads the master list to
/// generate a packing list. A fast user can confirm a trip before the seed has
/// finished and get an empty or partial list. Both paths now await this
/// coordinator, so trip creation blocks until the seed completes.
///
/// The seed is memoized: concurrent callers share one in-flight `Task` (which
/// also prevents two seed runs from double-inserting), and a successful seed is
/// cached so later calls return instantly with no added latency.
@MainActor
final class SeedCoordinator {
    private let importService: ImportService
    private var inFlight: Task<Bool, Never>?
    private var didSucceed = false

    init(repository: any MasterItemRepository, defaults: UserDefaults = .standard) {
        importService = ImportService(repository: repository, defaults: defaults)
    }

    /// Runs the master-list seed if needed and returns whether master items are
    /// available. Safe to call from multiple sites concurrently and repeatedly.
    /// A successful result is cached; a failure clears state so a later call retries.
    @discardableResult
    func ensureSeeded() async -> Bool {
        if didSucceed { return true }
        if let inFlight { return await inFlight.value }

        let task = Task { await importService.seedIfNeeded() }
        inFlight = task
        let success = await task.value
        didSucceed = success
        inFlight = nil
        return success
    }
}
