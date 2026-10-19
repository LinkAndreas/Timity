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

    #if os(macOS)
    @State private var width: CGFloat = 0
    private static let spacing: CGFloat = 12
    private static let minCardWidth: CGFloat = 150

    /// The cards in rows of as many as fit, the rows as even as can be: five in a column
    /// for three make a row of three and one of two.
    private var rows: [[EventSnapshot]] {
        let fit = max(1, Int((width + Self.spacing) / (Self.minCardWidth + Self.spacing)))
        let rowCount = (events.count + fit - 1) / fit
        guard rowCount > 0 else { return [] }
        let perRow = (events.count + rowCount - 1) / rowCount
        return stride(from: 0, to: events.count, by: perRow).map { Array(events[$0..<min($0 + perRow, events.count)]) }
    }
    #endif

    var body: some View {
        #if os(macOS)
        // Every card in view, as many to a row as the column allows, each row's cards sharing
        // its width, so one card fills it and a last row is never half empty. A mouse scrolls
        // a row of cards sideways only awkwardly.
        VStack(spacing: Self.spacing) {
            // Rows by their place, so a card pinned or unpinned moves within them rather than
            // every row after it being built anew.
            ForEach(rows.indices, id: \.self) { index in
                HStack(spacing: Self.spacing) {
                    ForEach(rows[index]) { event in
                        card(event, minWidth: Self.minCardWidth)
                            .transition(.scale(scale: 0.85).combined(with: .opacity))
                    }
                }
                .frame(height: cardHeight)
            }
        }
        .onGeometryChange(for: CGFloat.self, of: \.size.width) { width = $0 }
        // In line with the rows' highlight below.
        .padding(.horizontal, 10)
        .padding(.vertical, 2)
        #else
        ScrollView(.horizontal) {
            LazyHStack(spacing: 12) {
                ForEach(events) { event in
                    // Never wider than the smallest iPhone's screen, so the next card still peeks in.
                    card(event)
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

    private func card(_ event: EventSnapshot, minWidth: CGFloat = 220) -> some View {
        Button {
            selection = event.id
        } label: {
            EventPreviewCard(event: event, now: now, showsPin: false, minWidth: minWidth)
        }
        .buttonStyle(.plain)
        // The pin, where the card shows it, as a button of its own that unpins.
        .overlay(alignment: .topTrailing) {
            Button {
                withAnimation(.snappy) { onUnpin(event) }
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
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(countdown.days, format: .number)
                        .scaledFont(size: 40, weight: .bold, design: .rounded, relativeTo: .title)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text(CountdownText.dayCaption(countdown))
                        .font(.subheadline.weight(.medium))
                        .opacity(0.85)
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

/// An event's photo, cropped around its subject and shaded where words sit on it,
/// or its colour gradient.
struct EventBackground: View {
    let event: EventSnapshot
    /// Whether the photo drifts slowly, as on the event's page.
    var isMoving = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast
    @State private var isDrifting = false
    @State private var focus = UnitPoint.center

    var body: some View {
        if let image = ImageProcessing.cgImage(from: event.imageData, maxPixelSize: 1200) {
            FocusedPhoto(image: image, focus: focus)
                // A slow zoom towards the subject, like a photo in Memories.
                .scaleEffect(isDrifting ? 1.08 : 1.0, anchor: focus)
                .overlay { scrim }
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

    /// Shade only at the bottom, where the words sit: on the event's page the name
    /// and date, in the list the name and the days. The rest of the photo stays as it
    /// is. Darker with Increase Contrast.
    private var scrim: some View {
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
        return LinearGradient(stops: stops, startPoint: .top, endPoint: .bottom)
    }
}
