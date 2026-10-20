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
/// Dates, times and repeats are read in English, German, Spanish and French, with month and
/// weekday names and words like "tomorrow" taken from Foundation for each language; see
/// `EventTextReader`. Uses Apple Intelligence's on-device model where it's available for the
/// name and symbol; without it, the name is the text without the date.
nonisolated enum EventTextParser {
    /// In the background, as reading the text and the language model take a moment.
    @concurrent
    static func parse(
        _ text: String,
        now: Date = .now,
        locale: Locale = .autoupdatingCurrent,
        calendar: Calendar = .autoupdatingCurrent
    ) async -> ParsedEventDescription {
        var result = read(text, now: now, locale: locale, calendar: calendar)

        #if canImport(FoundationModels)
        if let understood = await understand(text, now: now) {
            result.title = understood.title
            result.recurrence = understood.recurrence
            result.symbolName = understood.symbolName
            if result.date == nil {
                result.date = understood.date
                result.isAllDay = understood.isAllDay
            }
        }
        #endif
        return result
    }

    /// The description read without the language model: the date, time and repeat it mentions,
    /// a yearly repeat for birthdays and anniversaries, and the rest of the text as the name.
    static func read(
        _ text: String,
        now: Date,
        locale: Locale = .autoupdatingCurrent,
        calendar: Calendar = .autoupdatingCurrent
    ) -> ParsedEventDescription {
        // The locale's language first, then the app's other languages, in case the text is in
        // one of those; the language that understands the most wins, the locale's on a tie.
        let languageCode = locale.language.languageCode?.identifier
        let locales = [locale] + EventLanguage.supportedLanguageCodes.filter { $0 != languageCode }.map(Locale.init(identifier:))
        var best: (reader: EventTextReader, reading: EventTextReading)?
        for locale in locales {
            let reader = EventTextReader(locale: locale, calendar: calendar)
            let reading = reader.read(text, now: now)
            if reading.score > best?.reading.score ?? -1 { best = (reader, reading) }
        }
        guard let (reader, reading) = best else { return ParsedEventDescription() }

        var result = ParsedEventDescription()
        var ranges = reading.ranges
        result.date = reading.date
        result.isAllDay = reading.date.map { _ in reading.timeRange == nil }
        // The system's date detection knows numeric dates such as "12.05." or "5/12", which the
        // reader leaves out; it's asked when no day was named, and wins over a time on its own
        // only when it found more numbers than the time's.
        if !reading.hasDay, let detected = detectDate(in: text), reading.timeRange.map({ time in
            text[detected.range].indices.contains { text[$0].isNumber && !time.contains($0) }
        }) ?? true {
            result.date = detected.date
            result.isAllDay = !detected.hasTime
            ranges.append(detected.range)
        }
        result.title = reader.title(of: text, without: ranges)
        result.recurrence = reading.recurrence
        result.symbolName = reading.symbolName
        if reading.symbolName != nil { result.isAllDay = result.isAllDay ?? true }
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
