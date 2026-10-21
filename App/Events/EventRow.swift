import SwiftUI

/// An event in the list: its badge or photo, name and date, and the days to go.
struct EventRow: View {
    let event: EventSnapshot
    let countdown: Countdown

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        AdaptiveStack(spacing: 14) {
            EventThumbnail(event: event, size: 48)

            VStack(alignment: .leading, spacing: 3) {
                Text(event.displayTitle)
                    .font(.headline)
                    .lineLimit(2)
                Text(countdown.targetText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if event.recurrence != .never {
                    Label {
                        Text(RecurrenceText.summary(event.rule, start: event.startDate()))
                    } icon: {
                        Image(systemName: "repeat")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .labelStyle(.titleAndIcon)
                }
                if let progress = countdown.progress, countdown.direction == .future {
                    CompactEventProgress(progress: progress, fill: event.color.color, track: event.color.color.opacity(0.18))
                        .frame(maxWidth: 220)
                        .padding(.top, 3)
                }
            }

            if !dynamicTypeSize.isAccessibilitySize {
                Spacer(minLength: 8)
            }

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

    /// Increased on a selected row, whose highlight takes the event's colour away.
    @Environment(\.backgroundProminence) private var prominence

    private var tint: AnyShapeStyle {
        prominence == .increased ? AnyShapeStyle(.primary) : AnyShapeStyle(color.color)
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            if countdown.isToday {
                Text("common.today")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(tint)
            } else {
                Text(countdown.days, format: .number)
                    .font(.title2.weight(.bold).monospacedDigit())
                    .fontDesign(.rounded)
                    .contentTransition(.numericText(countsDown: countdown.direction == .future))
                    .foregroundStyle(countdown.direction == .past ? AnyShapeStyle(.secondary) : tint)
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
    let event: EventSnapshot
    var size: CGFloat = 44

    @State private var focus = UnitPoint.center

    var body: some View {
        if let image = ImageProcessing.cgImage(from: event.imageData, maxPixelSize: size * 3) {
            // Square, so cropped around the subject: a face rather than a shoulder.
            FocusedPhoto(image: image, focus: focus)
                .frame(width: size, height: size)
                .task(id: event.imageData?.hashValue) {
                    if let data = event.imageData { focus = await PhotoFocus.point(for: data) }
                }
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
    let events: [EventSnapshot]
    let now: Date
    @Binding var selection: UUID?
    let onUnpin: (EventSnapshot) -> Void

    /// The cards grow with the text, so large sizes don't cut off the name or the symbol.
    @ScaledMetric(relativeTo: .headline) private var cardWidth: CGFloat = 220
    @ScaledMetric(relativeTo: .headline) private var cardHeight: CGFloat = 150

    var body: some View {
        #if os(macOS)
        // Every card in view, as many to a row as the column allows, each row's cards sharing
        // its width, so one card fills it and a last row is never half empty. A mouse scrolls
        // a row of cards sideways only awkwardly. One layout for all of them, so a card pinned
        // or unpinned makes the others slide to their new places.
        EvenRowsLayout(minItemWidth: 150, itemHeight: cardHeight, spacing: 12) {
            ForEach(events) { event in
                PinnedEventCard(event: event, now: now, minWidth: 150, open: { selection = event.id }, unpin: { onUnpin(event) })
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
            }
        }
        // In line with the rows' highlight below.
        .padding(.horizontal, 10)
        .padding(.vertical, 2)
        #else
        ScrollView(.horizontal) {
            LazyHStack(spacing: 12) {
                ForEach(events) { event in
                    // Never wider than the smallest iPhone's screen, so the next card still peeks in.
                    PinnedEventCard(event: event, now: now, open: { selection = event.id }, unpin: { onUnpin(event) })
                        .frame(width: min(cardWidth, 340), height: cardHeight)
                        .transition(.scale(scale: 0.85).combined(with: .opacity))
                }
            }
            .scrollTargetLayout()
            .padding(.vertical, 2)
        }
        // The first card lines up with the rows and cards below, which bring their own
        // margins; while scrolling, cards may pass the margin up to the screen's edge.
        .scrollClipDisabled()
        .scrollTargetBehavior(.viewAligned)
        .scrollIndicators(.hidden)
        #endif
    }

}

/// A pinned event as a card that opens it, with its pin as a button of its own that unpins.
private struct PinnedEventCard: View {
    let event: EventSnapshot
    let now: Date
    var minWidth: CGFloat = 220
    let open: () -> Void
    let unpin: () -> Void

    var body: some View {
        Button(action: open) {
            EventPreviewCard(event: event, now: now, showsPin: false, minWidth: minWidth)
        }
        .buttonStyle(.plain)
        // The pin, where the card shows it, as a button of its own that unpins.
        .overlay(alignment: .topTrailing) {
            Button {
                withAnimation(.snappy) { unpin() }
            } label: {
                Image(systemName: "pin.fill")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .glassEffect(.clear, in: .circle)
                    .contentShape(.circle)
            }
            .buttonStyle(.plain)
            .padding(8)
            .accessibilityLabel(Text("common.unpin"))
        }
    }
}

#if os(macOS)
/// Items in rows of as many as fit, the rows as even as can be — five where three fit make a
/// row of three and one of two — each row's items sharing its width.
struct EvenRowsLayout: Layout {
    let minItemWidth: CGFloat
    let itemHeight: CGFloat
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? minItemWidth
        let rows = rowCounts(count: subviews.count, width: width)
        let height = CGFloat(rows.count) * itemHeight + CGFloat(max(rows.count - 1, 0)) * spacing
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var index = 0
        var y = bounds.minY
        for count in rowCounts(count: subviews.count, width: bounds.width) {
            let itemWidth = (bounds.width - spacing * CGFloat(count - 1)) / CGFloat(count)
            for column in 0..<count {
                let x = bounds.minX + CGFloat(column) * (itemWidth + spacing)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(width: itemWidth, height: itemHeight))
                index += 1
            }
            y += itemHeight + spacing
        }
    }

    /// How many items each row holds.
    private func rowCounts(count: Int, width: CGFloat) -> [Int] {
        guard count > 0 else { return [] }
        let fit = max(1, Int((width + spacing) / (minItemWidth + spacing)))
        let rows = (count + fit - 1) / fit
        let perRow = (count + rows - 1) / rows
        return stride(from: 0, to: count, by: perRow).map { min(perRow, count - $0) }
    }
}
#endif

/// A card with an event's colour or photo and its countdown — pinned events and
/// context menu previews.
struct EventPreviewCard: View {
    let event: EventSnapshot
    let now: Date
    /// Off where the pin is a button laid over the card instead.
    var showsPin = true
    /// Narrower in a grid of cards side by side than as a preview on its own.
    var minWidth: CGFloat = 220

    var body: some View {
        let countdown = event.countdown(at: now)

        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top) {
                Image(systemName: event.symbolName)
                    .font(.title3.weight(.semibold))
                Spacer()
                if event.isPinned, showsPin {
                    Image(systemName: "pin.fill")
                        .font(.caption)
                        .accessibilityLabel("common.pinned")
                }
            }
            Spacer(minLength: 8)
            if countdown.isToday {
                Text("common.today")
                    .scaledFont(size: 34, weight: .bold, design: .rounded, relativeTo: .title)
            } else {
                // The number whole, always: beside it the caption, smaller where the card is narrow,
                // and below it where even that doesn't fit, rather than "6…" for 680.
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        PreviewCardNumber(days: countdown.days)
                        PreviewCardCaption(countdown: countdown, font: .subheadline.weight(.medium))
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        PreviewCardNumber(days: countdown.days)
                        PreviewCardCaption(countdown: countdown, font: .caption.weight(.medium))
                    }
                    VStack(alignment: .leading, spacing: -4) {
                        PreviewCardNumber(days: countdown.days)
                        PreviewCardCaption(countdown: countdown, font: .caption.weight(.medium))
                    }
                }
            }
            Text(event.displayTitle)
                .font(.headline)
                .lineLimit(1)
            if let progress = countdown.progress, countdown.direction == .future {
                CompactEventProgress(
                    progress: progress,
                    fill: .white,
                    track: .white.opacity(0.3),
                    textStyle: AnyShapeStyle(.white.opacity(0.85))
                )
                .padding(.top, 2)
            }
        }
        .foregroundStyle(.white)
        .padding(16)
        .frame(minWidth: minWidth, maxWidth: .infinity, minHeight: 150, maxHeight: .infinity, alignment: .leading)
        .background { EventBackground(event: event) }
        .clipShape(.rect(cornerRadius: 24, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// A preview card's day count, never cut short.
private struct PreviewCardNumber: View {
    let days: Int

    var body: some View {
        Text(days, format: .number)
            .scaledFont(size: 40, weight: .bold, design: .rounded, relativeTo: .title)
            .monospacedDigit()
            .contentTransition(.numericText())
            .fixedSize()
    }
}

/// "days to go" or "days ago" beside or below a preview card's number.
private struct PreviewCardCaption: View {
    let countdown: Countdown
    let font: Font

    var body: some View {
        Text(CountdownText.dayCaption(countdown))
            .font(font)
            .opacity(0.85)
            .fixedSize()
    }
}

/// An event's photo, cropped around its subject and shaded where words sit on it,
/// or its colour gradient.
struct EventBackground: View {
    let event: EventSnapshot
    /// Whether the photo drifts slowly, as on the event's page.
    var isMoving = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isDrifting = false
    @State private var focus = UnitPoint.center

    var body: some View {
        if let image = ImageProcessing.cgImage(from: event.imageData, maxPixelSize: 1200) {
            FocusedPhoto(image: image, focus: focus)
                // A slow zoom towards the subject, like a photo in Memories.
                .scaleEffect(isDrifting ? 1.08 : 1.0, anchor: focus)
                .overlay { PhotoScrim(isMoving: isMoving) }
                .task(id: event.imageData?.hashValue) {
                    if let data = event.imageData { focus = await PhotoFocus.point(for: data) }
                }
                .onAppear {
                    guard isMoving, !reduceMotion else { return }
                    withAnimation(.easeInOut(duration: 24).repeatForever(autoreverses: true)) {
                        isDrifting = true
                    }
                }
                .onChange(of: reduceMotion) { _, reduce in
                    if reduce { isDrifting = false }
                }
        } else {
            event.color.gradient
        }
    }

}

/// Shade only at the bottom, where the words sit: on the event's page the name
/// and date, in the list the name and the days. The rest of the photo stays as it
/// is. Darker with Increase Contrast.
private struct PhotoScrim: View {
    /// On the event's page, where the photo drifts: shade lower down only.
    let isMoving: Bool

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let strength = contrast == .increased ? 1.4 : 1.0
        let stops: [Gradient.Stop] = isMoving
            ? [
                .init(color: .clear, location: 0.45),
                .init(color: .black.opacity(0.6 * strength), location: 1),
            ]
            : [
                .init(color: .black.opacity(0.1 * strength), location: 0),
                .init(color: .black.opacity(0.55 * strength), location: 1),
            ]
        LinearGradient(stops: stops, startPoint: .top, endPoint: .bottom)
    }
}
