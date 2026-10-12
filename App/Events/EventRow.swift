import SwiftUI

/// An event in the list: its badge or photo, name and date, and the days to go.
struct EventRow: View {
    let event: Event
    let countdown: Countdown

    var body: some View {
        HStack(spacing: 14) {
            EventThumbnail(event: event, size: 48)

            VStack(alignment: .leading, spacing: 3) {
                Text(event.title)
                    .font(.headline)
                    .lineLimit(2)
                Text(countdown.targetText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if event.recurrence != .never {
                    Label {
                        Text(RecurrenceText.summary(event.recurrenceRule, start: event.startDate()))
                    } icon: {
                        Image(systemName: "repeat")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .labelStyle(.titleAndIcon)
                }
            }

            Spacer(minLength: 8)

            DayCount(countdown: countdown, color: event.color)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

/// The days to go in large digits with a caption, or "Today".
struct DayCount: View {
    let countdown: Countdown
    let color: EventColor

    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            if countdown.isToday {
                Text("Today")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(color.color)
            } else {
                Text(countdown.days, format: .number)
                    .font(.title2.weight(.bold).monospacedDigit())
                    .fontDesign(.rounded)
                    .contentTransition(.numericText(countsDown: countdown.direction == .future))
                    .foregroundStyle(countdown.direction == .past ? AnyShapeStyle(.secondary) : AnyShapeStyle(color.color))
                Text(CountdownText.dayCaption(countdown))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .animation(.default, value: countdown.days)
    }
}

/// An event's photo, or its badge when it has none.
struct EventThumbnail: View {
    let event: Event
    var size: CGFloat = 44

    var body: some View {
        if let image = ImageProcessing.image(from: event.imageData, maxPixelSize: size * 3) {
            image
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(.rect(cornerRadius: size * 0.28, style: .continuous))
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: event.symbolName)
                        .font(.system(size: size * 0.22, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(size * 0.08)
                        .background(event.color.gradient, in: .circle)
                        .offset(x: size * 0.08, y: size * 0.08)
                }
                .accessibilityHidden(true)
        } else {
            EventBadge(symbolName: event.symbolName, color: event.color, size: size)
        }
    }
}

/// Pinned events as large cards in a row that scrolls sideways.
struct PinnedEventsCarousel: View {
    let events: [Event]
    let now: Date
    @Binding var selection: UUID?

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 12) {
                ForEach(events) { event in
                    Button {
                        selection = event.id
                    } label: {
                        EventPreviewCard(event: event, now: now)
                            .frame(width: 220, height: 150)
                    }
                    .buttonStyle(.plain)
                }
            }
            .scrollTargetLayout()
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollIndicators(.hidden)
    }
}

/// A card with an event's colour or photo and its countdown — pinned events and
/// context menu previews.
struct EventPreviewCard: View {
    let event: Event
    let now: Date

    var body: some View {
        let countdown = event.snapshot.countdown(at: now)

        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top) {
                Image(systemName: event.symbolName)
                    .font(.title3.weight(.semibold))
                Spacer()
                if event.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption)
                        .accessibilityLabel("Pinned")
                }
            }
            Spacer(minLength: 8)
            if countdown.isToday {
                Text("Today")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(countdown.days, format: .number)
                        .font(.system(size: 40, weight: .bold, design: .rounded).monospacedDigit())
                        .contentTransition(.numericText())
                    Text(CountdownText.dayCaption(countdown))
                        .font(.subheadline.weight(.medium))
                        .opacity(0.85)
                }
            }
            Text(event.title)
                .font(.headline)
                .lineLimit(1)
        }
        .foregroundStyle(.white)
        .padding(16)
        .frame(minWidth: 220, maxWidth: .infinity, minHeight: 150, maxHeight: .infinity, alignment: .leading)
        .background { EventBackground(event: event) }
        .clipShape(.rect(cornerRadius: 24, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// An event's photo darkened for legible text, or its colour gradient.
struct EventBackground: View {
    let event: Event

    var body: some View {
        if let image = ImageProcessing.image(from: event.imageData, maxPixelSize: 1200) {
            image
                .resizable()
                .scaledToFill()
                .overlay {
                    LinearGradient(colors: [.black.opacity(0.1), .black.opacity(0.55)], startPoint: .top, endPoint: .bottom)
                }
        } else {
            event.color.gradient
        }
    }
}
