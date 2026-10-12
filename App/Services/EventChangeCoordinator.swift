import Foundation
import Observation

/// Runs the follow-up work after events change — here, in a widget or through
/// iCloud: widgets, reminders, Spotlight and so on. Changes in quick succession,
/// such as ticking off a checklist, are handled once.
@MainActor
final class EventChangeCoordinator {
    typealias Handler = @MainActor ([EventSnapshot]) async -> Void

    private let repository: any EventRepository
    private let handlers: [Handler]
    private var observation: Task<Void, Never>?
    private var pending: Task<Void, Never>?

    /// - Parameter handlers: Called with every event after each change.
    init(repository: any EventRepository, handlers: [Handler]) {
        self.repository = repository
        self.handlers = handlers
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
        pending = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            let events = repository.events
            for handler in handlers {
                await handler(events)
            }
        }
    }
}
