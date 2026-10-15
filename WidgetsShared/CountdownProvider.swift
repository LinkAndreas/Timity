import AppIntents
import WidgetKit

struct CountdownEntry: TimelineEntry {
    let date: Date
    /// The event shown, or `nil` when there are no events yet.
    let event: EventSnapshot?

    /// How strongly the Smart Stack should show this countdown: most on the
    /// event's day, a little the day before, hardly otherwise.
    var relevance: TimelineEntryRelevance? {
        guard let event else { return nil }
        let countdown = event.countdown(at: date)
        let endOfDay = Calendar.autoupdatingCurrent.dateInterval(of: .day, for: date)?.end ?? date
        switch (countdown.days, countdown.direction) {
        case (0, _): return TimelineEntryRelevance(score: 100, duration: endOfDay.timeIntervalSince(date))
        case (1, .future): return TimelineEntryRelevance(score: 50, duration: endOfDay.timeIntervalSince(date))
        default: return TimelineEntryRelevance(score: 5)
        }
    }
}

/// Timelines for one event's countdown. The day count changes at midnight, so
/// there's an entry for each of the next days; shorter spans tick by themselves
/// with timer text.
struct CountdownProvider: AppIntentTimelineProvider {
    let events: any EventReader

    func placeholder(in context: Context) -> CountdownEntry {
        CountdownEntry(date: .now, event: .sample)
    }

    func snapshot(for configuration: SelectEventIntent, in context: Context) async -> CountdownEntry {
        CountdownEntry(date: .now, event: resolve(configuration) ?? (context.isPreview ? .sample : nil))
    }

    func timeline(for configuration: SelectEventIntent, in context: Context) async -> Timeline<CountdownEntry> {
        let event = resolve(configuration)
        let dates = WidgetSchedule.entryDates(for: event)
        let entries = dates.map { CountdownEntry(date: $0, event: event) }
        return Timeline(entries: entries, policy: .after(dates.last ?? .now.addingTimeInterval(3600)))
    }

    func recommendations() -> [AppIntentRecommendation<SelectEventIntent>] {
        // The Watch has no widget configuration screen; it offers these instead.
        let next = AppIntentRecommendation(intent: SelectEventIntent(), description: String(localized: "widgets.nextEvent"))
        let recommended = events.fetchEvents().active.sortedByCountdown().prefix(6).map { snapshot in
            AppIntentRecommendation(intent: SelectEventIntent(event: EventEntity(snapshot)), description: snapshot.title)
        }
        return [next] + recommended
    }

    /// The chosen event, or the next one to come when none is chosen.
    private func resolve(_ configuration: SelectEventIntent) -> EventSnapshot? {
        let all = events.fetchEvents()
        if let id = configuration.event?.id {
            return all.first { $0.id == id }
        }
        return WidgetSchedule.nextEvent(in: all.active)
    }
}

/// Timelines for the list of upcoming events.
struct UpcomingProvider: TimelineProvider {
    let events: any EventReader

    func placeholder(in context: Context) -> UpcomingEntry {
        UpcomingEntry(date: .now, events: EventSnapshot.samples)
    }

    func getSnapshot(in context: Context, completion: @escaping (UpcomingEntry) -> Void) {
        let upcoming = WidgetSchedule.upcoming(events.fetchEvents().active)
        completion(UpcomingEntry(date: .now, events: upcoming.isEmpty && context.isPreview ? EventSnapshot.samples : upcoming))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<UpcomingEntry>) -> Void) {
        let snapshots = events.fetchEvents().active
        let dates = WidgetSchedule.midnights(count: 7)
        let entries = ([Date.now] + dates).map { date in
            UpcomingEntry(date: date, events: WidgetSchedule.upcoming(snapshots, at: date))
        }
        completion(Timeline(entries: entries, policy: .after(dates.last ?? .now.addingTimeInterval(3600))))
    }
}

struct UpcomingEntry: TimelineEntry {
    let date: Date
    let events: [EventSnapshot]
}

enum WidgetSchedule {
    /// Now, every coming midnight for a week, and the event's moment if it falls in that week.
    static func entryDates(for event: EventSnapshot?, now: Date = .now) -> [Date] {
        var dates = [now] + midnights(count: 7, after: now)
        if let event {
            let target = event.countdown(at: now).target
            if target > now, target < dates.last! { dates.append(target) }
        }
        return dates.sorted()
    }

    static func midnights(count: Int, after date: Date = .now) -> [Date] {
        let calendar = Calendar.autoupdatingCurrent
        let today = calendar.startOfDay(for: date)
        return (1...count).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
    }

    static func nextEvent(in events: [EventSnapshot], at now: Date = .now) -> EventSnapshot? {
        upcoming(events, at: now).first ?? events.sortedByCountdown(at: now).first
    }

    /// Events today and later, soonest first, pinned events before the others.
    static func upcoming(_ events: [EventSnapshot], at now: Date = .now) -> [EventSnapshot] {
        let sorted = events.sortedByCountdown(at: now).filter {
            let countdown = $0.countdown(at: now)
            return countdown.direction != .past || countdown.isToday
        }
        return sorted.filter(\.isPinned) + sorted.filter { !$0.isPinned }
    }
}

extension EventSnapshot {
    static let sample = EventSnapshot(
        id: UUID(),
        title: String(localized: "widgets.summerHoliday"),
        date: Calendar.autoupdatingCurrent.date(byAdding: .day, value: 24, to: .now) ?? .now,
        isAllDay: false,
        recurrence: .never,
        color: .orange,
        symbolName: "beach.umbrella.fill",
        isPinned: true,
        imageData: nil
    )

    static let samples: [EventSnapshot] = [
        sample,
        EventSnapshot(id: UUID(), title: String(localized: "common.birthday"), date: Calendar.autoupdatingCurrent.date(byAdding: .day, value: 41, to: .now) ?? .now, isAllDay: false, recurrence: .yearly, color: .pink, symbolName: "birthday.cake.fill", isPinned: false, imageData: nil),
        EventSnapshot(id: UUID(), title: String(localized: "widgets.concert"), date: Calendar.autoupdatingCurrent.date(byAdding: .day, value: 63, to: .now) ?? .now, isAllDay: false, recurrence: .never, color: .purple, symbolName: "music.note", isPinned: false, imageData: nil),
    ]
}
