import Foundation

/// Numbers as the user writes them, for every number Timity shows.
///
/// `Text(_:format:)` and `formatted()` follow the language and region but not the Number Format
/// chosen in Settings › General › Language & Region: with Timity in German on a US iPhone set to
/// "1.234.567,89", they wrote "1,824.3" beside the localized strings' "in 1.118 Tagen".
/// `NumberFormatter` keeps that choice, as the localized strings do.
nonisolated enum NumberText {
    static func string(_ number: NSNumber, fractionDigits: ClosedRange<Int>) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = fractionDigits.lowerBound
        formatter.maximumFractionDigits = fractionDigits.upperBound
        return formatter.string(from: number) ?? number.description
    }
}

nonisolated extension BinaryInteger {
    /// "1.118" or "1,118", grouped as the user writes numbers.
    var localizedNumber: String {
        NumberText.string(NSNumber(value: Int64(clamping: self)), fractionDigits: 0...0)
    }
}

nonisolated extension BinaryFloatingPoint {
    /// "1.824,3" or "1,824.3", with `fractionDigits` decimals, as the user writes numbers.
    func localizedNumber(fractionDigits: ClosedRange<Int> = 0...0) -> String {
        NumberText.string(NSNumber(value: Double(self)), fractionDigits: fractionDigits)
    }
}
