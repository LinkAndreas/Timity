import SwiftUI

/// How much of the wait has passed, as a rounded bar.
struct EventProgressBar: View {
    let progress: Double
    let fill: Color
    let track: Color
    var height: CGFloat = 6

    var body: some View {
        Capsule()
            .fill(track)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    // A sliver of colour as soon as the wait begins, so the bar never looks empty by mistake.
                    let width = progress > 0 ? max(height, proxy.size.width * progress) : 0
                    Capsule()
                        .fill(fill.gradient)
                        .frame(width: width)
                }
            }
            .frame(height: height)
            .clipShape(.capsule)
            .animation(.smooth, value: progress)
            .accessibilityHidden(true)
    }
}

/// The progress in a list card or a pinned card: a thin bar and the percentage.
struct CompactEventProgress: View {
    let progress: Double
    let fill: Color
    let track: Color
    var textStyle: AnyShapeStyle = AnyShapeStyle(.secondary)

    var body: some View {
        HStack(spacing: 6) {
            EventProgressBar(progress: progress, fill: fill, track: track, height: 5)
            Text(EventProgressText.percent(progress))
                .font(.caption2.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(textStyle)
                .contentTransition(.numericText())
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("common.ofTheWaitIsOver \(EventProgressText.percent(progress))"))
    }
}

/// The progress below the big countdown: the percentage, the days gone, and the
/// dates the wait runs between.
struct HeroEventProgress: View {
    let countdown: Countdown
    let progress: Double

    var body: some View {
        if progress >= 1, countdown.direction != .future {
            Label("progress.theWaitIsOver", systemImage: "checkmark.seal.fill")
                .font(.footnote.weight(.semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .heroGlass(in: .capsule)
        } else {
            VStack(spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(EventProgressText.percent(progress))
                        .font(.title3.weight(.bold))
                        .fontDesign(.rounded)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Spacer(minLength: 8)
                    if let days = countdown.progressDays() {
                        Text("progress.ofDays \(days.gone) \(days.total)")
                            .font(.footnote.weight(.semibold))
                            .monospacedDigit()
                            .opacity(0.85)
                    } else {
                        Text("common.ofTheWaitIsOver \(EventProgressText.percent(progress))")
                            .font(.footnote.weight(.semibold))
                            .opacity(0.85)
                    }
                }
                EventProgressBar(progress: progress, fill: .white, track: .white.opacity(0.25), height: 10)
                if let from = countdown.progressFrom {
                    HStack {
                        Text(EventProgressText.date(from, countdown: countdown))
                        Spacer(minLength: 8)
                        Text(EventProgressText.date(countdown.target, countdown: countdown))
                    }
                    .font(.caption.weight(.medium))
                    .opacity(0.8)
                }
            }
            .frame(maxWidth: 480)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .heroGlass(in: .rect(cornerRadius: 20, style: .continuous))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("common.ofTheWaitIsOver \(EventProgressText.percent(progress))"))
            .accessibilityValue(countdown.progressDays().map { Text("progress.ofDays \($0.gone) \($0.total)") } ?? Text(verbatim: ""))
        }
    }
}

nonisolated enum EventProgressText {
    /// "62 %" as the locale writes it.
    static func percent(_ progress: Double) -> String {
        progress.formatted(.percent.precision(.fractionLength(0)))
    }

    /// "3 Aug", with the year when it isn't this year, or the time for waits shorter than two days.
    static func date(_ date: Date, countdown: Countdown) -> String {
        if countdown.progressDays() == nil, !countdown.isAllDay {
            return date.formatted(.dateTime.hour().minute())
        }
        let calendar = Calendar.autoupdatingCurrent
        let style = calendar.isDate(date, equalTo: countdown.now, toGranularity: .year)
            ? Date.FormatStyle.dateTime.day().month(.abbreviated)
            : Date.FormatStyle.dateTime.day().month(.abbreviated).year()
        return date.formatted(style)
    }
}

nonisolated extension Countdown {
    /// Whole days gone of the wait, for waits of two days or more.
    func progressDays(calendar: Calendar = .autoupdatingCurrent) -> (gone: Int, total: Int)? {
        guard let progressFrom else { return nil }
        let total = DateMath.calendarDays(from: progressFrom, to: target, calendar: calendar)
        guard total >= 2 else { return nil }
        let gone = DateMath.calendarDays(from: progressFrom, to: now, calendar: calendar)
        return (min(max(gone, 0), total), total)
    }
}
