import SwiftUI
import UIKit

/// An event's countdown as a picture for Messages and Stories.
struct ShareCard: View {
    let event: Event
    let countdown: Countdown

    var body: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 0)
            EventBadge(symbolName: event.symbolName, color: event.color, size: 64)
                .shadow(color: .black.opacity(0.25), radius: 10, y: 5)
            Text(event.title)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .lineLimit(3)
            if countdown.isToday {
                Text("Today")
                    .font(.system(size: 96, weight: .heavy, design: .rounded))
            } else {
                VStack(spacing: -6) {
                    Text(countdown.days, format: .number)
                        .font(.system(size: 120, weight: .heavy, design: .rounded))
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    Text(CountdownText.dayCaption(countdown))
                        .font(.system(size: 26, weight: .semibold, design: .rounded))
                }
            }
            Text(countdown.targetText)
                .font(.system(size: 18, weight: .medium))
                .opacity(0.85)
            Spacer(minLength: 0)
            Label("Timity", systemImage: "hourglass")
                .font(.system(size: 15, weight: .semibold))
                .opacity(0.7)
        }
        .foregroundStyle(.white)
        .padding(32)
        .frame(width: 400, height: 500)
        .background { EventBackground(event: event) }
        .clipShape(.rect(cornerRadius: 40, style: .continuous))
    }

    /// The card as an image at three times its size.
    @MainActor
    static func image(for event: Event, countdown: Countdown) -> Image? {
        let renderer = ImageRenderer(content: ShareCard(event: event, countdown: countdown))
        renderer.scale = 3
        renderer.isOpaque = false
        return renderer.uiImage.map { Image(uiImage: $0) }
    }
}

/// Upcoming milestones since the event, such as 10,000 days.
struct MilestonesCard: View {
    let event: Event
    let now: Date
    let tint: Color

    var body: some View {
        let start = event.startDate()
        let upcoming = Milestones.upcoming(since: start, after: now, limit: 4)
        let recent = Milestones.recent(since: start, before: now)

        if !upcoming.isEmpty || recent != nil {
            Card(title: "Milestones") {
                VStack(spacing: 12) {
                    if let recent {
                        MilestoneRow(milestone: recent, now: now, tint: tint, isRecent: true)
                    }
                    ForEach(upcoming) { milestone in
                        MilestoneRow(milestone: milestone, now: now, tint: tint, isRecent: false)
                    }
                }
            }
        }
    }
}

private struct MilestoneRow: View {
    let milestone: Milestone
    let now: Date
    let tint: Color
    let isRecent: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isRecent ? "party.popper.fill" : "flag.checkered")
                .font(.title3)
                .foregroundStyle(tint)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: "\(milestone.value.formatted()) \(CountdownText.unit(milestone.unit, value: Int(clamping: milestone.value)))")
                    .font(.headline.monospacedDigit())
                Text(milestone.date, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated).year())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(isRecent ? String(localized: "Reached") : CountdownText.relativeDays(
                Countdown(startDate: milestone.date, isAllDay: true, recurrence: .never, now: now, calendar: .autoupdatingCurrent)
            ))
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(isRecent ? tint : .secondary)
        }
        .accessibilityElement(children: .combine)
    }
}
