import SwiftData
import SwiftUI
import WidgetKit

@main
struct TimityWatchApp: App {
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            WatchEventList()
        }
        .modelContainer(TimityStore.container)
        .onChange(of: scenePhase) { _, phase in
            // Complications catch up with events that synced while the app was away.
            if phase == .background { WidgetCenter.shared.reloadAllTimelines() }
        }
    }
}

/// The events, soonest first, synced from iPhone and iPad through iCloud.
struct WatchEventList: View {
    @Query private var events: [Event]
    @State private var path: [UUID] = []

    var body: some View {
        NavigationStack(path: $path) {
            TimelineView(.everyMinute) { context in
                let sorted = sortedEvents(at: context.date)

                List {
                    ForEach(sorted) { event in
                        NavigationLink(value: event.id) {
                            WatchEventRow(event: event.snapshot, now: context.date)
                        }
                        .listRowBackground(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(event.color.color.gradient.opacity(0.35))
                        )
                    }
                }
                .overlay {
                    if events.isEmpty {
                        ContentUnavailableView {
                            Label("No Events", systemImage: "calendar.badge.plus")
                        } description: {
                            Text("Add events in Timity on your iPhone or iPad. They appear here through iCloud.")
                        }
                    }
                }
            }
            .navigationTitle("Timity")
            .navigationDestination(for: UUID.self) { id in
                if let event = events.first(where: { $0.id == id }) {
                    WatchEventDetail(event: event.snapshot)
                }
            }
        }
        .onOpenURL { url in
            if let id = DeepLink.eventID(in: url) { path = [id] }
        }
    }

    private func sortedEvents(at now: Date) -> [Event] {
        let order = events.map(\.snapshot).sortedByCountdown(at: now).map(\.id)
        let pinned = Set(events.filter(\.isPinned).map(\.id))
        let ids = order.filter { pinned.contains($0) } + order.filter { !pinned.contains($0) }
        return ids.compactMap { id in events.first { $0.id == id } }
    }
}

private struct WatchEventRow: View {
    let event: EventSnapshot
    let now: Date

    var body: some View {
        let countdown = event.countdown(at: now)

        HStack(spacing: 8) {
            Image(systemName: event.symbolName)
                .font(.body.weight(.semibold))
                .foregroundStyle(event.color.color)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 0) {
                Text(event.title)
                    .font(.headline)
                    .lineLimit(2)
                Text(CountdownText.relativeDays(countdown))
                    .font(.subheadline.weight(.semibold))
                    .fontDesign(.rounded)
                    .foregroundStyle(countdown.direction == .past ? .secondary : .primary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

/// One event: the days to go and a live breakdown, scrolling with the Digital Crown.
struct WatchEventDetail: View {
    let event: EventSnapshot

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let countdown = event.countdown(at: context.date)
            let breakdown = countdown.breakdown(includeWeeks: true)

            ScrollView {
                VStack(spacing: 10) {
                    Image(systemName: event.symbolName)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(event.color.gradient, in: .circle)

                    if countdown.isToday {
                        Text("Today")
                            .font(.system(size: 40, weight: .heavy, design: .rounded))
                    } else {
                        VStack(spacing: -4) {
                            Text(countdown.days, format: .number)
                                .font(.system(size: 52, weight: .heavy, design: .rounded))
                                .monospacedDigit()
                                .minimumScaleFactor(0.5)
                                .contentTransition(.numericText(countsDown: countdown.direction == .future))
                            Text(CountdownText.dayCaption(countdown))
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Text(countdown.targetText)
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)

                    Grid(horizontalSpacing: 6, verticalSpacing: 6) {
                        let parts = breakdown.parts(includingSeconds: true)
                        ForEach(Array(stride(from: 0, to: parts.count, by: 2)), id: \.self) { index in
                            GridRow {
                                ForEach(parts[index..<min(index + 2, parts.count)]) { part in
                                    VStack(spacing: 0) {
                                        Text(part.value, format: .number)
                                            .font(.headline.monospacedDigit())
                                            .contentTransition(.numericText())
                                        Text(CountdownText.unit(part.unit, value: part.value))
                                            .font(.system(size: 10, weight: .semibold))
                                            .textCase(.uppercase)
                                            .foregroundStyle(.secondary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 6)
                                    .background(event.color.color.opacity(0.2), in: .rect(cornerRadius: 10, style: .continuous))
                                }
                            }
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(CountdownText.spokenBreakdown(breakdown, includingSeconds: true))
                }
                .padding(.horizontal, 4)
            }
            .animation(.snappy, value: breakdown)
        }
        .navigationTitle(event.title)
        .containerBackground(event.color.color.gradient.opacity(0.4), for: .navigation)
    }
}
