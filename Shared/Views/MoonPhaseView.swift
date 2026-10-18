import SwiftUI

/// The Moon as it looks: the lit part bright, the rest faint. SF Symbols' moon
/// phases fill the shadow instead, so tinting them lights the wrong side.
struct MoonPhaseView: View {
    /// The lit fraction of the disc, from 0 (new) to 1 (full).
    let illumination: Double
    /// Whether the light is growing, between new and full moon.
    let isWaxing: Bool
    /// South of the equator the Moon is seen the other way up: a waxing Moon is lit on the left.
    var isSouthern = false
    var color = Color.yellow

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.22))
            MoonLitShape(illumination: illumination, isLitOnRight: isWaxing != isSouthern)
                .fill(color)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

nonisolated extension MoonPhaseView {
    init(_ moon: Astronomy.MoonState, isSouthern: Bool = false, color: Color = .yellow) {
        self.init(illumination: moon.illumination, isWaxing: moon.isWaxing, isSouthern: isSouthern, color: color)
    }

    init(_ phase: Astronomy.PrincipalPhase, isSouthern: Bool = false, color: Color = .yellow) {
        self.init(illumination: phase.illumination, isWaxing: phase.isWaxing, isSouthern: isSouthern, color: color)
    }
}

/// The lit part of the disc: the bright limb on one side, and the terminator — a
/// half ellipse — on the other, bulging into the dark for a gibbous Moon and into
/// the light for a crescent.
nonisolated private struct MoonLitShape: Shape {
    var illumination: Double
    var isLitOnRight: Bool

    var animatableData: Double {
        get { illumination }
        set { illumination = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let radius = min(rect.width, rect.height) / 2
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let lit = min(max(illumination, 0), 1)
        // The terminator's half width, towards the lit limb for a crescent.
        let terminator = (1 - 2 * lit) * radius
        let side: CGFloat = isLitOnRight ? 1 : -1
        let steps = 48

        var path = Path()
        // The limb, top to bottom, then the terminator back up.
        for step in 0...steps {
            let angle = -Double.pi / 2 + Double.pi * Double(step) / Double(steps)
            let point = CGPoint(x: center.x + side * radius * cos(angle), y: center.y + radius * sin(angle))
            step == 0 ? path.move(to: point) : path.addLine(to: point)
        }
        for step in (0...steps).reversed() {
            let angle = -Double.pi / 2 + Double.pi * Double(step) / Double(steps)
            path.addLine(to: CGPoint(x: center.x + side * terminator * cos(angle), y: center.y + radius * sin(angle)))
        }
        path.closeSubpath()
        return path
    }
}
