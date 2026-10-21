import SwiftUI

/// A whole number set with a stepper. On iPhone and iPad the value beside the title, the
/// stepper's buttons at the end; on the Mac a small field to type the number into, with its
/// stepper right beside it and the unit after it, as in the Mac's own settings, and the arrow
/// keys stepping it while it's being typed in.
struct NumberStepperRow: View {
    let title: LocalizedStringKey
    @Binding var value: Int
    let range: ClosedRange<Int>
    var step = 1
    /// The value as the row shows it on iPhone and iPad, e.g. "1 hr, 30 min".
    let valueText: String
    /// After the field on the Mac, e.g. "min".
    var unit: String?

    var body: some View {
        #if os(macOS)
        LabeledContent(title) {
            HStack(spacing: 6) {
                TextField(title, value: clamped, format: .number.grouping(.never))
                    .labelsHidden()
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
                    .frame(width: 64)
                    .onKeyPress(.upArrow) {
                        move(by: step)
                        return .handled
                    }
                    .onKeyPress(.downArrow) {
                        move(by: -step)
                        return .handled
                    }
                Stepper(title, value: $value, in: range, step: step)
                    .labelsHidden()
                if let unit {
                    Text(unit)
                        .frame(minWidth: 28, alignment: .leading)
                }
            }
            // The form sets values in the secondary colour; this one is typed in.
            .foregroundStyle(.primary)
        }
        #else
        Stepper(value: $value, in: range, step: step) {
            LabeledContent(title, value: valueText)
        }
        #endif
    }

    /// Typed numbers kept within the range.
    private var clamped: Binding<Int> {
        Binding(
            get: { value },
            set: { value = min(max($0, range.lowerBound), range.upperBound) }
        )
    }

    private func move(by amount: Int) {
        value = min(max(value + amount, range.lowerBound), range.upperBound)
    }
}

extension NumberStepperRow {
    /// "min", after a number of minutes.
    static var minutesUnit: String { UnitDuration.minutes.symbol }
}
