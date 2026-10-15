import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// What a description such as "Mum's birthday on 3 March" says about an event.
nonisolated struct ParsedEventDescription {
    var title: String?
    var date: Date?
    var isAllDay: Bool?
    var recurrence: Recurrence?
    var symbolName: String?
}

/// Turns "Mum's birthday on 3 March" into an event's name, date and repetition.
///
/// Uses Apple Intelligence's on-device model where it's available. Dates are taken
/// from the system's date detection first, which knows "next Friday at 6 pm" in
/// many languages; without Apple Intelligence the name is the text without the date.
nonisolated enum EventTextParser {
    /// In the background, as date detection and the language model take a moment.
    @concurrent
    static func parse(_ text: String, now: Date = .now) async -> ParsedEventDescription {
        var result = ParsedEventDescription()
        let detected = detectDate(in: text)
        if let detected {
            result.date = detected.date
            result.isAllDay = !detected.hasTime
        }

        #if canImport(FoundationModels)
        if let understood = await understand(text, now: now) {
            result.title = understood.title
            result.recurrence = understood.recurrence
            result.symbolName = understood.symbolName
            if result.date == nil {
                result.date = understood.date
                result.isAllDay = understood.isAllDay
            }
            return result
        }
        #endif

        // Without the model: the text minus the date, and a yearly repeat for birthdays and anniversaries.
        var title = text
        if let range = detected?.range { title.removeSubrange(range) }
        title = title
            .replacingOccurrences(of: #"\s+(on|am|at|um|the|den)\s*$"#, with: "", options: [.regularExpression, .caseInsensitive])
            .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        result.title = title.isEmpty ? nil : title
        let lowercased = text.lowercased()
        if ["birthday", "geburtstag", "anniversary", "jahrestag", "hochzeitstag"].contains(where: lowercased.contains) {
            result.recurrence = .yearly
            result.isAllDay = result.isAllDay ?? true
            result.symbolName = lowercased.contains("birthday") || lowercased.contains("geburtstag") ? "birthday.cake.fill" : "heart.fill"
        }
        return result
    }

    private static func detectDate(in text: String) -> (date: Date, hasTime: Bool, range: Range<String.Index>)? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard
            let match = detector.firstMatch(in: text, options: [], range: range),
            let date = match.date,
            let textRange = Range(match.range, in: text)
        else { return nil }
        // The detector sets noon when no time was mentioned and reports a zero duration for all-day dates.
        let components = Calendar.autoupdatingCurrent.dateComponents([.hour, .minute], from: date)
        let mentionsTime = text[textRange].contains(where: \.isNumber) && (components.hour != 12 || components.minute != 0)
        return (date, mentionsTime, textRange)
    }

    #if canImport(FoundationModels)
    @Generable
    nonisolated struct UnderstoodEvent {
        @Guide(description: "A short name for the event, without the date, e.g. \"Mum's Birthday\" or \"Flight to Tokyo\"")
        var title: String
        @Guide(description: "The year, or 0 if no year is mentioned")
        var year: Int
        @Guide(description: "The month, from 1 to 12")
        var month: Int
        @Guide(description: "The day of the month, from 1 to 31")
        var day: Int
        @Guide(description: "The hour from 0 to 23, or -1 if no time is mentioned")
        var hour: Int
        @Guide(description: "The minute from 0 to 59")
        var minute: Int
        @Guide(description: "How often the event repeats; birthdays and anniversaries repeat yearly", .anyOf(["never", "daily", "weekly", "monthly", "yearly"]))
        var repeats: String
        @Guide(description: "The SF Symbol name that fits the event best, e.g. birthday.cake.fill, airplane, heart.fill, graduationcap.fill")
        var symbol: String
    }

    nonisolated private struct Understood {
        var title: String
        var date: Date?
        var isAllDay: Bool
        var recurrence: Recurrence
        var symbolName: String
    }

    private static func understand(_ text: String, now: Date) async -> Understood? {
        guard SystemLanguageModel.default.isAvailable else { return nil }
        let today = now.formatted(.iso8601.year().month().day())
        let session = LanguageModelSession(instructions: """
            You read a short description of an event someone wants to count down to or since, \
            and extract its name, date and repetition. Today is \(today). Answer in the language of the description.
            """)
        do {
            let event = try await session.respond(to: text, generating: UnderstoodEvent.self).content
            let calendar = Calendar.autoupdatingCurrent
            var components = DateComponents(
                year: event.year > 0 ? event.year : calendar.component(.year, from: now),
                month: event.month,
                day: event.day
            )
            if event.hour >= 0 {
                components.hour = event.hour
                components.minute = event.minute
            }
            var date = calendar.date(from: components)
            // A date without a year that has passed this year means next year's.
            if event.year <= 0, let candidate = date, candidate < calendar.startOfDay(for: now) {
                date = calendar.date(byAdding: .year, value: 1, to: candidate)
            }
            return Understood(
                title: event.title,
                date: date,
                isAllDay: event.hour < 0,
                recurrence: Recurrence(rawValue: event.repeats) ?? .never,
                // Only symbols the picker offers, so the event can be edited like any other.
                symbolName: EventSymbol.groups.flatMap(\.symbols).contains(event.symbol) ? event.symbol : EventSymbol.defaultName
            )
        } catch {
            logger.error("Couldn't understand the event description: \(error)")
            return nil
        }
    }
    #endif
}
