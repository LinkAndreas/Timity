import Foundation

/// Every App Store release of Timity, newest first, with its notes: the App Store's
/// What's New for each version, shown in Settings › Version History.
///
/// To add a release, put it at the top of `releases` with the month it came out, and add
/// its notes to `Localizable.xcstrings` as `versionHistory.<version>.note<n>` — dots in the
/// version as underscores, as `versionHistory.4_10_0.note1` — in every language, with a
/// comment. The website's version history (`content/releases.js`) lists the same notes.
enum VersionHistory {
    /// One release and what it brought.
    struct Release: Identifiable {
        /// "4.10.0", as on the App Store.
        let version: String
        /// The month it came out.
        let date: Date
        /// What it brought, one point each.
        let notes: [LocalizedStringResource]

        var id: String { version }

        init(version: String, year: Int, month: Int, notes: [LocalizedStringResource]) {
            self.version = version
            self.date = Calendar(identifier: .gregorian).date(from: DateComponents(year: year, month: month, day: 15)) ?? .now
            self.notes = notes
        }

        /// Whether it's the version running now.
        var isInstalled: Bool {
            version == Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        }
    }

    static let releases: [Release] = [
        Release(
            version: "4.10.0", year: 2026, month: 11,
            notes: [
                "versionHistory.4_10_0.note1",
                "versionHistory.4_10_0.note2",
                "versionHistory.4_10_0.note3",
                "versionHistory.4_10_0.note4",
            ]
        ),
        Release(
            version: "4.9.67", year: 2026, month: 10,
            notes: [
                "versionHistory.4_9_67.note1",
                "versionHistory.4_9_67.note2",
                "versionHistory.4_9_67.note3",
                "versionHistory.4_9_67.note4",
                "versionHistory.4_9_67.note5",
                "versionHistory.4_9_67.note6",
                "versionHistory.4_9_67.note7",
                "versionHistory.4_9_67.note8",
                "versionHistory.4_9_67.note9",
                "versionHistory.4_9_67.note10",
                "versionHistory.4_9_67.note11",
                "versionHistory.4_9_67.note12",
                "versionHistory.4_9_67.note13",
            ]
        ),
        Release(
            version: "3.1.1", year: 2024, month: 4,
            notes: [
                "versionHistory.3_1_1.note1",
            ]
        ),
        Release(
            version: "3.1.0", year: 2023, month: 8,
            notes: [
                "versionHistory.3_1_0.note1",
                "versionHistory.3_1_0.note2",
            ]
        ),
        Release(
            version: "3.0", year: 2018, month: 3,
            notes: [
                "versionHistory.3_0.note1",
                "versionHistory.3_0.note2",
                "versionHistory.3_0.note3",
                "versionHistory.3_0.note4",
                "versionHistory.3_0.note5",
                "versionHistory.3_0.note6",
                "versionHistory.3_0.note7",
            ]
        ),
        Release(
            version: "2.0", year: 2014, month: 11,
            notes: [
                "versionHistory.2_0.note1",
                "versionHistory.2_0.note2",
            ]
        ),
        Release(
            version: "1.5", year: 2013, month: 4,
            notes: [
                "versionHistory.1_5.note1",
                "versionHistory.1_5.note2",
                "versionHistory.1_5.note3",
            ]
        ),
        Release(
            version: "1.4", year: 2012, month: 9,
            notes: [
                "versionHistory.1_4.note1",
                "versionHistory.1_4.note2",
                "versionHistory.1_4.note3",
            ]
        ),
        Release(
            version: "1.3", year: 2012, month: 6,
            notes: [
                "versionHistory.1_3.note1",
                "versionHistory.1_3.note2",
                "versionHistory.1_3.note3",
            ]
        ),
        Release(
            version: "1.2", year: 2012, month: 4,
            notes: [
                "versionHistory.1_2.note1",
                "versionHistory.1_2.note2",
                "versionHistory.1_2.note3",
            ]
        ),
        Release(
            version: "1.1", year: 2012, month: 3,
            notes: [
                "versionHistory.1_1.note1",
                "versionHistory.1_1.note2",
                "versionHistory.1_1.note3",
                "versionHistory.1_1.note4",
            ]
        ),
        Release(
            version: "1.0", year: 2012, month: 3,
            notes: [
                "versionHistory.1_0.note1",
                "versionHistory.1_0.note2",
                "versionHistory.1_0.note3",
                "versionHistory.1_0.note4",
            ]
        ),
        Release(
            version: "0.2", year: 2012, month: 2,
            notes: [
                "versionHistory.0_2.note1",
                "versionHistory.0_2.note2",
                "versionHistory.0_2.note3",
            ]
        ),
        Release(
            version: "0.1.2", year: 2012, month: 1,
            notes: [
                "versionHistory.0_1_2.note1",
                "versionHistory.0_1_2.note2",
                "versionHistory.0_1_2.note3",
            ]
        ),
        Release(
            version: "0.1.1", year: 2012, month: 1,
            notes: [
                "versionHistory.0_1_1.note1",
                "versionHistory.0_1_1.note2",
            ]
        ),
        Release(
            version: "0.1", year: 2011, month: 12,
            notes: [
                "versionHistory.0_1.note1",
                "versionHistory.0_1.note2",
                "versionHistory.0_1.note3",
            ]
        ),
    ]
}
