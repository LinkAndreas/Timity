import SwiftUI

/// A life as a grid: one row per year, one dot per week. Lived weeks are filled,
/// the current one glows.
struct LifeInWeeksGrid: View {
    let life: LifeInWeeks
    let color: Color

    var body: some View {
        Canvas { context, size in
            let columns = LifeInWeeks.weeksPerRow
            let rows = life.years
            let spacing: CGFloat = size.width > 300 ? 1.5 : 1
            let cell = min(
                (size.width - spacing * CGFloat(columns - 1)) / CGFloat(columns),
                (size.height - spacing * CGFloat(rows - 1)) / CGFloat(rows)
            )
            let gridWidth = cell * CGFloat(columns) + spacing * CGFloat(columns - 1)
            let originX = (size.width - gridWidth) / 2

            for row in 0..<rows {
                for column in 0..<columns {
                    let rect = CGRect(
                        x: originX + CGFloat(column) * (cell + spacing),
                        y: CGFloat(row) * (cell + spacing),
                        width: cell,
                        height: cell
                    )
                    let shape = Path(roundedRect: rect, cornerRadius: cell * 0.3)
                    if life.isCurrent(row: row, column: column) {
                        context.fill(shape, with: .color(color))
                        context.stroke(Path(roundedRect: rect.insetBy(dx: -cell * 0.3, dy: -cell * 0.3), cornerRadius: cell * 0.5),
                                       with: .color(color.opacity(0.6)), lineWidth: max(0.5, cell * 0.2))
                    } else if life.isLived(row: row, column: column) {
                        // Each decade a shade lighter, so they're easy to count.
                        context.fill(shape, with: .color(color.opacity(row / 10 % 2 == 0 ? 0.85 : 0.6)))
                    } else {
                        context.fill(shape, with: .color(.secondary.opacity(0.18)))
                    }
                }
            }
        }
        .accessibilityElement()
        .accessibilityLabel(Text("Life in Weeks"))
        .accessibilityValue(Text("\(life.weeksLived) weeks lived, \(life.progress.formatted(.percent.precision(.fractionLength(0))))"))
    }
}
