import Foundation
import Observation

/// Runs the follow-up work after events change — here, in a widget or through
/// iCloud: widgets, reminders, Spotlight and so on. Changes in quick succession,
/// such as a batch arriving from iCloud, are handled once.
@MainActor
final class EventChangeCoordinator {
    typealias Handler = @MainActor ([EventSnapshot]) async -> Void

    /// Waits before the handlers run, so changes in quick succession are handled once.
    typealias Pause = @Sendable () async throws -> Void

    private let repository: any EventRepository
    private let handlers: [Handler]
    private let pause: Pause
    private var observation: Task<Void, Never>?
    private var pending: Task<Void, Never>?

    /// - Parameters:
    ///   - handlers: Called with every event after each change.
    ///   - pause: How long changes are gathered; tests end it when they choose.
    init(
        repository: any EventRepository,
        handlers: [Handler],
        pause: @escaping Pause = { try await Task.sleep(for: .milliseconds(300)) }
    ) {
        self.repository = repository
        self.handlers = handlers
        self.pause = pause
    }

    /// Follows the repository from now on.
    func start() {
        guard observation == nil else { return }
        observation = Task { [repository] in
            for await _ in Observations({ repository.events }) {
                refresh()
            }
        }
    }

    /// Runs the handlers, e.g. when the day changed while the app was away.
    func refresh() {
        pending?.cancel()
        pending = Task { [pause] in
            try? await pause()
            guard !Task.isCancelled else { return }
            let events = repository.events
            for handler in handlers {
                await handler(events)
            }
        }
    }

    /// Returns once the handlers of the latest change have run.
    func waitUntilHandled() async {
        await pending?.value
    }
}
