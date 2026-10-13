import SwiftUI

/// The sun's height through the day as a curve over the horizon, on a sky that
/// matches the sun's height now — blue by day, warm at golden hour, deep at night.
struct SunPathCard: View {
    let place: Place
    let day: SolarDay
    let date: Date
    let now: Date

    var body: some View {
        let calendar = placeCalendar
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart.addingTimeInterval(86_400)
        let isToday = calendar.isDate(now, inSameDayAs: date)
        let samples = elevations(from: dayStart, to: dayEnd)
        let marker = isToday ? now : day.solarNoon
        let markerElevation = SolarCalculator.elevation(at: marker, latitude: place.latitude, longitude: place.longitude)

        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: date.formatted(Date.FormatStyle(date: .complete, time: .omitted, timeZone: place.timeZone)))
                        .font(.headline)
                    if isToday {
                        Text(String(localized: "Sun at \(markerElevation.formatted(.number.precision(.fractionLength(0))))°"))
                            .font(.subheadline)
                            .opacity(0.85)
                    }
                }
                Spacer()
                Image(systemName: markerElevation > 0 ? "sun.max.fill" : "moon.stars.fill")
                    .font(.title)
                    .symbolRenderingMode(.multicolor)
            }

            Canvas { context, size in
                draw(samples: samples, marker: marker, markerElevation: markerElevation, start: dayStart, end: dayEnd, in: &context, size: size)
            }
            .frame(height: 170)
            .accessibilityElement()
            .accessibilityLabel(Text("Sun’s Path"))
            .accessibilityValue(Text(pathDescription(markerElevation: markerElevation, isToday: isToday)))

            // Each label sits under its hour on the curve.
            GeometryReader { proxy in
                ForEach([6, 12, 18], id: \.self) { hour in
                    Text(calendar.date(byAdding: .hour, value: hour, to: dayStart) ?? dayStart,
                         format: Date.FormatStyle(date: .omitted, time: .shortened, timeZone: place.timeZone))
                        .fixedSize()
                        .position(x: proxy.size.width * CGFloat(hour) / 24, y: proxy.size.height / 2)
                }
            }
            .frame(height: 16)
            .font(.caption2.monospacedDigit())
            .opacity(0.75)
        }
        .foregroundStyle(.white)
        .padding(20)
        .background(sky(for: markerElevation), in: .rect(cornerRadius: 28, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    /// The chart in words for VoiceOver: sunrise, sunset, and the sun's height now.
    private func pathDescription(markerElevation: Double, isToday: Bool) -> String {
        let style = Date.FormatStyle(date: .omitted, time: .shortened, timeZone: place.timeZone)
        var parts: [String] = []
        if let sunrise = day.sunrise { parts.append(String(localized: "Sunrise \(sunrise.formatted(style))")) }
        if let sunset = day.sunset { parts.append(String(localized: "Sunset \(sunset.formatted(style))")) }
        if isToday {
            parts.append(String(localized: "Sun at \(markerElevation.formatted(.number.precision(.fractionLength(0))))°"))
        }
        return parts.joined(separator: ", ")
    }

    private var placeCalendar: Calendar {
        var calendar = Calendar.autoupdatingCurrent
        calendar.timeZone = place.timeZone
        return calendar
    }

    /// The sun's elevation every ten minutes of the day.
    private func elevations(from start: Date, to end: Date) -> [(date: Date, elevation: Double)] {
        let step: TimeInterval = 600
        let count = Int(end.timeIntervalSince(start) / step)
        return (0...count).map { index in
            let date = start.addingTimeInterval(Double(index) * step)
            return (date, SolarCalculator.elevation(at: date, latitude: place.latitude, longitude: place.longitude))
        }
    }

    private func draw(
        samples: [(date: Date, elevation: Double)],
        marker: Date,
        markerElevation: Double,
        start: Date,
        end: Date,
        in context: inout GraphicsContext,
        size: CGSize
    ) {
        let highest = max(samples.map(\.elevation).max() ?? 60, 20)
        let lowest = min(samples.map(\.elevation).min() ?? -20, -10)
        let duration = end.timeIntervalSince(start)

        // Room above the highest and below the lowest point for the sun's glow.
        let inset: CGFloat = 20
        func point(_ date: Date, _ elevation: Double) -> CGPoint {
            let x = date.timeIntervalSince(start) / duration * size.width
            let y = inset + (highest - elevation) / (highest - lowest) * (size.height - 2 * inset)
            return CGPoint(x: x, y: y)
        }

        let horizonY = point(start, 0).y

        // Horizon.
        var horizon = Path()
        horizon.move(to: CGPoint(x: 0, y: horizonY))
        horizon.addLine(to: CGPoint(x: size.width, y: horizonY))
        context.stroke(horizon, with: .color(.white.opacity(0.5)), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

        // The curve, and the daylight under it.
        var curve = Path()
        for (index, sample) in samples.enumerated() {
            let p = point(sample.date, sample.elevation)
            if index == 0 { curve.move(to: p) } else { curve.addLine(to: p) }
        }

        var daylight = curve
        daylight.addLine(to: CGPoint(x: size.width, y: horizonY))
        daylight.addLine(to: CGPoint(x: 0, y: horizonY))
        daylight.closeSubpath()
        var above = context
        above.clip(to: Path(CGRect(x: 0, y: 0, width: size.width, height: horizonY)))
        above.fill(daylight, with: .linearGradient(
            Gradient(colors: [.yellow.opacity(0.45), .orange.opacity(0.1)]),
            startPoint: .zero,
            endPoint: CGPoint(x: 0, y: horizonY)
        ))

        context.stroke(curve, with: .color(.white.opacity(0.9)), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

        // The sun now, or at noon for another day.
        let sun = point(marker, markerElevation)
        let glow = CGRect(x: sun.x - 18, y: sun.y - 18, width: 36, height: 36)
        context.fill(Path(ellipseIn: glow), with: .radialGradient(
            Gradient(colors: [.yellow.opacity(0.7), .clear]),
            center: sun,
            startRadius: 0,
            endRadius: 18
        ))
        let disc = CGRect(x: sun.x - 8, y: sun.y - 8, width: 16, height: 16)
        context.fill(Path(ellipseIn: disc), with: .color(markerElevation > 0 ? .yellow : .white.opacity(0.8)))
    }

    /// A sky colour for the sun's height.
    private func sky(for elevation: Double) -> LinearGradient {
        let colors: [Color] = switch elevation {
        case 10...: [Color(red: 0.25, green: 0.55, blue: 0.95), Color(red: 0.45, green: 0.75, blue: 1.0)]
        case 0..<10: [Color(red: 0.35, green: 0.45, blue: 0.85), Color(red: 1.0, green: 0.6, blue: 0.35)]
        case -6..<0: [Color(red: 0.2, green: 0.25, blue: 0.6), Color(red: 0.85, green: 0.45, blue: 0.5)]
        case -12 ..< -6: [Color(red: 0.1, green: 0.12, blue: 0.4), Color(red: 0.3, green: 0.25, blue: 0.55)]
        default: [Color(red: 0.03, green: 0.04, blue: 0.15), Color(red: 0.1, green: 0.1, blue: 0.3)]
        }
        return LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
    }
}
