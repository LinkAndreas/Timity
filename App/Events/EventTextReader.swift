import Foundation

/// What `EventTextReader` found in a description, and where in the text it was said.
nonisolated struct EventTextReading {
    var date: Date?
    /// Whether a day was named; without one, a time alone means today or tomorrow.
    var hasDay = false
    var timeRange: Range<String.Index>?
    var recurrence: Recurrence?
    var symbolName: String?
    /// The parts that said the date, time or repeat, which don't belong in the event's name.
    var ranges: [Range<String.Index>] = []
    /// How much of the text the language understood, to pick the language it's written in.
    var score = 0
}

/// Reads dates, times and repeats from a description in one language.
///
/// Month and weekday names come from the calendar, "tomorrow" and "in 3 days" from
/// `RelativeDateTimeFormatter` and the way hours are written from the locale's time format,
/// so they match what the system says in that language. `EventLanguage` adds the few words
/// Foundation doesn't have.
nonisolated struct EventTextReader {
    let language: EventLanguage
    private let locale: Locale
    private let calendar: Calendar
    private let months: [String: Int]
    private let weekdays: [String: Int]
    private let namedDays: [String: (component: Calendar.Component, value: Int)]
    private let countedDays: [(regex: NSRegularExpression, component: Calendar.Component, sign: Int)]
    private let pmSymbols: Set<String>
    private let monthDayRegex: NSRegularExpression?
    private let dayMonthRegex: NSRegularExpression?
    private let namedDayRegex: NSRegularExpression?
    private let weekdayRegex: NSRegularExpression?
    private let timeRegex: NSRegularExpression?
    private let repeatRegex: NSRegularExpression?

    init(locale: Locale, calendar: Calendar) {
        let languageCode = locale.language.languageCode?.identifier
        let language = EventLanguage.words(for: languageCode)
        self.language = language
        self.locale = locale
        self.calendar = calendar
        var symbols = calendar
        symbols.locale = locale
        let key = { (word: String) in Self.key(word, locale: locale) }

        var months: [String: Int] = [:]
        for names in [symbols.monthSymbols, symbols.standaloneMonthSymbols, symbols.shortMonthSymbols, symbols.shortStandaloneMonthSymbols] {
            for (index, name) in names.enumerated() where months[key(name)] == nil { months[key(name)] = index + 1 }
        }
        self.months = months
        var weekdays: [String: Int] = [:]
        for names in [symbols.weekdaySymbols, symbols.standaloneWeekdaySymbols] {
            for (index, name) in names.enumerated() { weekdays[key(name)] = index + 1 }
        }
        for (name, weekday) in language.weekdayForms { weekdays[key(name)] = weekday }
        self.weekdays = weekdays

        // "yesterday", "übermorgen", "la próxima semana": the named relative days, skipping
        // those the language only says with a number.
        let named = RelativeDateTimeFormatter()
        named.locale = locale
        named.dateTimeStyle = .named
        named.unitsStyle = .full
        var namedDays: [String: (Calendar.Component, Int)] = [:]
        for (component, values) in [(Calendar.Component.day, -2...2), (.weekOfMonth, -1...1), (.month, -1...1), (.year, -1...1)] {
            for value in values where value != 0 || component == .day {
                var components = DateComponents()
                components.setValue(value, for: component)
                let phrase = named.localizedString(from: components)
                if !phrase.contains(where: \.isNumber) { namedDays[key(phrase)] = (component, value) }
            }
        }
        self.namedDays = namedDays

        // "in 3 days" and "3 days ago", with the number left open, in the singular and the plural
        // forms: 1, 3 and 5 days are "1 день", "3 дня" and "5 дней" in Russian.
        let numeric = RelativeDateTimeFormatter()
        numeric.locale = locale
        numeric.dateTimeStyle = .numeric
        numeric.unitsStyle = .full
        var countedDays: [(NSRegularExpression, Calendar.Component, Int)] = []
        for component in [Calendar.Component.day, .weekOfMonth, .month, .year] {
            for value in [1, 3, 5, -1, -3, -5] {
                var components = DateComponents()
                components.setValue(value, for: component)
                let phrase = numeric.localizedString(from: components)
                guard let number = phrase.range(of: String(abs(value))) else { continue }
                let prefix = String(phrase[..<number.lowerBound]), suffix = String(phrase[number.upperBound...])
                var prefixes = [prefix]
                if value > 0, !prefix.isEmpty { prefixes += language.inWords.map { $0 + " " } }
                for prefix in prefixes {
                    let pattern = Self.start + Self.pattern(for: prefix) + #"(\d{1,4})"# + Self.pattern(for: suffix) + Self.end
                    if let regex = Self.regex(pattern) { countedDays.append((regex, component, value.signum())) }
                }
            }
        }
        self.countedDays = countedDays

        // Whether the language writes "7 pm" and puts a word after the hour, as in "19 Uhr" or
        // "19 h", from the hour format of the locale and of the language's main region.
        var twelveHour = false
        var hourWords: [String] = []
        for hourLocale in [locale, Locale(identifier: languageCode ?? locale.identifier)] {
            guard let format = DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: hourLocale) else { continue }
            if format.contains("a") { twelveHour = true }
            hourWords += format.split(separator: "'", omittingEmptySubsequences: false).enumerated()
                .filter { $0.offset.isMultiple(of: 2) == false }
                .map { $0.element.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        }
        var amPM: [String] = []
        var pmSymbols: Set<String> = []
        if twelveHour {
            for (symbol, isPM) in [(symbols.amSymbol, false), (symbols.pmSymbol, true), ("am", false), ("pm", true)] {
                // "p. m." and "p.m." are also written "pm".
                let variants = [symbol, symbol.filter { $0 != "." && !$0.isWhitespace }]
                amPM += variants
                if isPM { pmSymbols.formUnion(variants.map(key)) }
            }
        }
        self.pmSymbols = pmSymbols

        let monthNames = Self.alternation(Array(months.keys), dot: true)
        let monthWords = language.monthWords.isEmpty ? "" : #"(?:\s+"# + Self.alternation(language.monthWords) + ")?"
        self.dayMonthRegex = Self.regex(
            Self.start + #"(?<day>\d{1,2})(?:\.|st|nd|rd|th|er|º)?"# + monthWords + #"\s+(?<month>"# + monthNames + ")"
                + #"(?:,?"# + monthWords + #"\s+(?<year>\d{4}))?"# + Self.end
        )
        self.monthDayRegex = Self.regex(
            Self.start + "(?<month>" + monthNames + #")\s+(?<day>\d{1,2})(?:st|nd|rd|th)?(?:,?\s+(?<year>\d{4}))?"# + Self.end
        )
        // Articles in front of a named day, as in "la próxima semana", are optional.
        let dateWords = Set(language.dateWords.map(key))
        let namedPatterns = namedDays.keys.map { phrase -> String in
            let words = phrase.split(separator: " ", maxSplits: 1)
            guard words.count == 2, dateWords.contains(String(words[0])) else { return Self.pattern(for: phrase) }
            return "(?:" + Self.pattern(for: String(words[0])) + #"\s+)?"# + Self.pattern(for: String(words[1]))
        }
        self.namedDayRegex = namedPatterns.isEmpty ? nil : Self.regex(Self.start + "(?<phrase>" + namedPatterns.sorted { $0.count > $1.count }.joined(separator: "|") + ")" + Self.end)
        self.weekdayRegex = Self.regex(
            Self.start
                + Self.optional("every", language.everyBeforeWeekday, before: true)
                + Self.optional("next", language.nextBeforeWeekday, before: true)
                + "(?<weekday>" + Self.alternation(Array(weekdays.keys)) + ")s?"
                + Self.optional("nextAfter", language.nextAfterWeekday, before: false)
                + Self.end
        )
        self.timeRegex = Self.regex(
            Self.start
                + (language.timeWords.isEmpty ? "" : "(?:(?<word>" + Self.alternation(language.timeWords) + #")\s+)?"#)
                + #"(?<![\d:.])(?<hour>\d{1,2})(?:(?<separator>[:.])(?<minute>\d{2}))?"#
                + (amPM.isEmpty ? "" : #"(?:\s*(?<ampm>"# + Self.alternation(amPM) + "))?")
                + (hourWords.isEmpty ? "" : #"(?:\s*(?<hourWord>"# + Self.alternation(hourWords) + #")(?<hourWordMinute>\d{2})?)?"#)
                + Self.end
        )
        let repeatPhrases = language.repeats.values.flatMap { $0 }
        self.repeatRegex = repeatPhrases.isEmpty ? nil : Self.regex(Self.start + "(?<phrase>" + Self.alternation(repeatPhrases) + ")" + Self.end)
    }

    func read(_ text: String, now: Date) -> EventTextReading {
        var reading = EventTextReading()
        let today = calendar.startOfDay(for: now)

        var weekly = false
        var day = monthDate(in: text, today: today) ?? countedDate(in: text, today: today) ?? namedDate(in: text, today: today)
        if day == nil, let weekday = weekdayDate(in: text, today: today) {
            day = (weekday.date, weekday.range)
            weekly = weekday.isEvery
        }
        let time = time(in: text, outside: day?.range)

        if let day {
            reading.hasDay = true
            reading.ranges.append(day.range)
            reading.score += 2
            reading.date = day.date
        }
        if let time {
            reading.timeRange = time.range
            reading.ranges.append(time.range)
            reading.score += 1
            let date = calendar.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: reading.date ?? now)
            // A time on its own is the next time it's that late.
            if reading.date == nil, let date, date < now {
                reading.date = calendar.date(byAdding: .day, value: 1, to: date)
            } else {
                reading.date = date
            }
        }

        if let match = repeatRegex?.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let range = Range(match.range(withName: "phrase"), in: text) {
            let phrase = Self.key(String(text[range]), locale: locale)
            reading.recurrence = language.repeats.first { $0.value.map { Self.key($0, locale: locale) }.contains(phrase) }?.key
            reading.ranges.append(range)
            reading.score += 1
        } else if weekly {
            reading.recurrence = .weekly
        }

        if contains(language.anniversaryWords, in: text) {
            reading.symbolName = "heart.fill"
        } else if contains(language.birthdayWords, in: text) {
            reading.symbolName = "birthday.cake.fill"
        }
        if reading.symbolName != nil {
            reading.recurrence = reading.recurrence ?? .yearly
            reading.score += 1
        }
        return reading
    }

    /// The text without the given parts and the small words that led up to them, such as
    /// "Mum's birthday" from "Mum's birthday on 12 May".
    func title(of text: String, without ranges: [Range<String.Index>]) -> String? {
        let marker = "\u{E000}"
        var title = ""
        var cursor = text.startIndex
        for range in Self.merged(ranges) {
            title += text[cursor..<range.lowerBound]
            title += marker
            cursor = range.upperBound
        }
        title += text[cursor...]
        let words = language.dateWords + language.timeWords
        if !words.isEmpty, let regex = Self.regex("(?:" + Self.start + Self.alternation(words) + #"\s+)+"# + marker) {
            title = regex.stringByReplacingMatches(in: title, range: NSRange(title.startIndex..., in: title), withTemplate: "")
        }
        title = title
            .replacingOccurrences(of: marker, with: " ")
            .replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        return title.isEmpty ? nil : title
    }

    // MARK: - Days

    /// "12 May", "12. Mai 2027", "12 de mayo", "May 12th".
    private func monthDate(in text: String, today: Date) -> (date: Date, range: Range<String.Index>)? {
        for regex in [dayMonthRegex, monthDayRegex].compactMap({ $0 }) {
            for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
                guard
                    let range = Range(match.range, in: text),
                    let day = capture("day", of: match, in: text).flatMap({ Int($0) }),
                    let month = capture("month", of: match, in: text).flatMap({ months[Self.key($0, locale: locale)] })
                else { continue }
                let year = capture("year", of: match, in: text).flatMap { Int($0) }
                let components = DateComponents(year: year ?? calendar.component(.year, from: today), month: month, day: day)
                // Rejects days the month doesn't have, such as 31 April.
                guard var date = calendar.date(from: components), calendar.component(.day, from: date) == day else { continue }
                // A date without a year that has passed this year means next year's.
                if year == nil, date < today, let next = calendar.date(byAdding: .year, value: 1, to: date) { date = next }
                return (date, range)
            }
        }
        return nil
    }

    /// "in 3 days", "vor 2 Wochen", "dentro de 3 meses".
    private func countedDate(in text: String, today: Date) -> (date: Date, range: Range<String.Index>)? {
        for counted in countedDays {
            guard
                let match = counted.regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
                let range = Range(match.range, in: text),
                let numberRange = Range(match.range(at: 1), in: text),
                let number = Int(text[numberRange]),
                let date = date(adding: counted.sign * number, counted.component, to: today)
            else { continue }
            return (date, range)
        }
        return nil
    }

    /// "tomorrow", "übermorgen", "la semaine prochaine".
    private func namedDate(in text: String, today: Date) -> (date: Date, range: Range<String.Index>)? {
        guard
            let match = namedDayRegex?.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
            let range = Range(match.range(withName: "phrase"), in: text)
        else { return nil }
        // The optional article isn't part of the formatter's phrase, so look it up with and without.
        let phrase = Self.key(String(text[range]), locale: locale)
        let withArticle = language.dateWords.lazy.map { Self.key($0, locale: locale) + " " + phrase }
        guard
            let offset = namedDays[phrase] ?? withArticle.compactMap({ namedDays[$0] }).first,
            let date = date(adding: offset.value, offset.component, to: today)
        else { return nil }
        return (date, range)
    }

    /// "Friday", "next Friday", "vendredi prochain", "every Monday".
    private func weekdayDate(in text: String, today: Date) -> (date: Date, range: Range<String.Index>, isEvery: Bool)? {
        guard
            let match = weekdayRegex?.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
            let range = Range(match.range, in: text),
            let weekday = capture("weekday", of: match, in: text).flatMap({ weekdays[Self.key($0, locale: locale)] }),
            var date = calendar.nextDate(after: today, matching: DateComponents(weekday: weekday), matchingPolicy: .nextTime, direction: .forward)
        else { return nil }
        // Today's weekday means today rather than in a week.
        if calendar.component(.weekday, from: today) == weekday { date = today }
        // "next Friday" is the one in next week, not later this week.
        let isNext = capture("next", of: match, in: text) != nil || capture("nextAfter", of: match, in: text) != nil
        if isNext, calendar.isDate(date, equalTo: today, toGranularity: .weekOfYear), let later = calendar.date(byAdding: .day, value: 7, to: date) {
            date = later
        }
        return (date, range, capture("every", of: match, in: text) != nil)
    }

    private func date(adding value: Int, _ component: Calendar.Component, to today: Date) -> Date? {
        component == .weekOfMonth
            ? calendar.date(byAdding: .day, value: 7 * value, to: today)
            : calendar.date(byAdding: component, value: value, to: today)
    }

    // MARK: - Time

    /// "at 7 pm", "18:00", "um 19 Uhr", "a las 19:30", "à 19h30". A bare number only counts as
    /// an hour after a word like "at", so that "12" in "12 May" or "3" in "in 3 days" isn't one.
    private func time(in text: String, outside excluded: Range<String.Index>?) -> (hour: Int, minute: Int, range: Range<String.Index>)? {
        guard let timeRegex else { return nil }
        for match in timeRegex.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            guard let range = Range(match.range, in: text), !(excluded?.overlaps(range) ?? false),
                  var hour = capture("hour", of: match, in: text).flatMap({ Int($0) })
            else { continue }
            let minute = (capture("minute", of: match, in: text) ?? capture("hourWordMinute", of: match, in: text)).flatMap { Int($0) } ?? 0
            let ampm = capture("ampm", of: match, in: text)
            let hasHourWord = capture("hourWord", of: match, in: text) != nil
            // "12.05." is a date, so a dot only separates minutes when something else says it's a time.
            let hasColon = capture("separator", of: match, in: text) == ":"
            let hasWord = capture("word", of: match, in: text) != nil
            guard hasColon || ampm != nil || hasHourWord || hasWord, minute < 60 else { continue }
            if let ampm {
                guard (1...12).contains(hour) else { continue }
                hour = hour % 12 + (pmSymbols.contains(Self.key(ampm, locale: locale)) ? 12 : 0)
            }
            guard hour < 24 else { continue }
            return (hour, minute, range)
        }
        return nil
    }

    // MARK: - Helpers

    private func contains(_ words: [String], in text: String) -> Bool {
        guard !words.isEmpty, let regex = Self.regex(Self.start + Self.alternation(words)) else { return false }
        return regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
    }

    private func capture(_ name: String, of match: NSTextCheckingResult, in text: String) -> String? {
        Range(match.range(withName: name), in: text).map { String(text[$0]) }
    }

    /// Words compare in lower case, with either apostrophe, single spaces and without a trailing dot.
    private static func key(_ word: String, locale: Locale) -> String {
        word.lowercased(with: locale)
            .replacingOccurrences(of: "’", with: "'")
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
    }

    private static let start = #"(?<![\p{L}\p{N}])"#
    private static let end = #"(?![\p{L}\p{N}])"#

    /// A phrase as a pattern that allows any spacing and either apostrophe.
    private static func pattern(for phrase: String) -> String {
        var pattern = ""
        for character in phrase {
            if character.isWhitespace {
                if !pattern.hasSuffix(#"\s+"#) { pattern += #"\s+"# }
            } else if character == "'" || character == "’" {
                pattern += "['’]"
            } else {
                pattern += NSRegularExpression.escapedPattern(for: String(character))
            }
        }
        return pattern
    }

    /// Longer phrases first, so "pasado mañana" wins over "mañana".
    private static func alternation(_ phrases: [String], dot: Bool = false) -> String {
        "(?:" + Set(phrases).sorted { $0.count > $1.count }.map(pattern).joined(separator: "|") + ")" + (dot ? #"\.?"# : "")
    }

    private static func optional(_ name: String, _ phrases: [String], before: Bool) -> String {
        guard !phrases.isEmpty else { return "" }
        let group = "(?<\(name)>" + alternation(phrases) + ")"
        return before ? "(?:" + group + #"\s+)?"# : #"(?:\s+"# + group + ")?"
    }

    private static func regex(_ pattern: String) -> NSRegularExpression? {
        try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
    }

    private static func merged(_ ranges: [Range<String.Index>]) -> [Range<String.Index>] {
        var merged: [Range<String.Index>] = []
        for range in ranges.sorted(by: { $0.lowerBound < $1.lowerBound }) {
            if let last = merged.last, last.upperBound >= range.lowerBound {
                merged[merged.count - 1] = last.lowerBound..<max(last.upperBound, range.upperBound)
            } else {
                merged.append(range)
            }
        }
        return merged
    }
}
