import Foundation
import Testing
@testable import Timity

/// The words beside Timity's numbers take the plural form each language needs for the
/// count: Russian has one for 1 and 21, another for 2–4 and 22–24, and a third for the rest.
@Suite("Unit wording")
struct UnitWordingTests {
    struct Example: CustomTestStringConvertible, Sendable {
        let language: String
        let unit: TimeUnit
        /// Count → expected word.
        let words: [Int: String]
        var testDescription: String { "\(language): \(unit.rawValue)" }
    }

    nonisolated static let counts = [1, 2, 5, 21, 22, 25, 11, 0]

    nonisolated static let examples: [Example] = [
        Example(language: "en", unit: .day, words: [1: "day", 2: "days", 5: "days", 21: "days", 22: "days", 25: "days", 11: "days", 0: "days"]),
        Example(language: "en", unit: .year, words: [1: "year", 2: "years", 5: "years", 21: "years", 22: "years", 25: "years", 11: "years", 0: "years"]),
        Example(language: "en", unit: .minute, words: [1: "minute", 2: "minutes", 5: "minutes", 21: "minutes", 22: "minutes", 25: "minutes", 11: "minutes", 0: "minutes"]),
        Example(language: "de", unit: .day, words: [1: "Tag", 2: "Tage", 5: "Tage", 21: "Tage", 22: "Tage", 25: "Tage", 11: "Tage", 0: "Tage"]),
        Example(language: "de", unit: .week, words: [1: "Woche", 2: "Wochen", 5: "Wochen", 21: "Wochen", 22: "Wochen", 25: "Wochen", 11: "Wochen", 0: "Wochen"]),
        Example(language: "de", unit: .hour, words: [1: "Stunde", 2: "Stunden", 5: "Stunden", 21: "Stunden", 22: "Stunden", 25: "Stunden", 11: "Stunden", 0: "Stunden"]),
        Example(language: "ru", unit: .year, words: [1: "год", 2: "года", 5: "лет", 21: "год", 22: "года", 25: "лет", 11: "лет", 0: "лет"]),
        Example(language: "ru", unit: .month, words: [1: "месяц", 2: "месяца", 5: "месяцев", 21: "месяц", 22: "месяца", 25: "месяцев", 11: "месяцев", 0: "месяцев"]),
        Example(language: "ru", unit: .week, words: [1: "неделя", 2: "недели", 5: "недель", 21: "неделя", 22: "недели", 25: "недель", 11: "недель", 0: "недель"]),
        Example(language: "ru", unit: .day, words: [1: "день", 2: "дня", 5: "дней", 21: "день", 22: "дня", 25: "дней", 11: "дней", 0: "дней"]),
        Example(language: "ru", unit: .hour, words: [1: "час", 2: "часа", 5: "часов", 21: "час", 22: "часа", 25: "часов", 11: "часов", 0: "часов"]),
        Example(language: "ru", unit: .minute, words: [1: "минута", 2: "минуты", 5: "минут", 21: "минута", 22: "минуты", 25: "минут", 11: "минут", 0: "минут"]),
        Example(language: "ru", unit: .second, words: [1: "секунда", 2: "секунды", 5: "секунд", 21: "секунда", 22: "секунды", 25: "секунд", 11: "секунд", 0: "секунд"]),
    ]

    @Test("A unit's name agrees with its number", arguments: examples)
    func unit(_ example: Example) {
        let locale = Locale(identifier: example.language)
        for count in Self.counts {
            #expect(CountdownText.unit(example.unit, value: count, locale: locale) == example.words[count], "\(count)")
        }
    }

    @Test("A negative amount takes the same word as its size")
    func negative() {
        let locale = Locale(identifier: "ru")
        #expect(CountdownText.unit(.day, value: -22, locale: locale) == "дня")
        #expect(CountdownText.unit(.day, value: -1, locale: Locale(identifier: "en")) == "day")
    }

    @Test("The caption under a day count agrees with it", arguments: ["en", "de", "ru"])
    func dayCaption(_ language: String) {
        let expected: [String: (future: [Int: String], past: [Int: String])] = [
            "en": (
                [1: "day to go", 2: "days to go", 5: "days to go", 21: "days to go", 22: "days to go", 25: "days to go", 11: "days to go", 0: "days to go"],
                [1: "day ago", 2: "days ago", 5: "days ago", 21: "days ago", 22: "days ago", 25: "days ago", 11: "days ago", 0: "days ago"]
            ),
            "de": (
                [1: "Tag übrig", 2: "Tage übrig", 5: "Tage übrig", 21: "Tage übrig", 22: "Tage übrig", 25: "Tage übrig", 11: "Tage übrig", 0: "Tage übrig"],
                [1: "Tag her", 2: "Tage her", 5: "Tage her", 21: "Tage her", 22: "Tage her", 25: "Tage her", 11: "Tage her", 0: "Tage her"]
            ),
            "ru": (
                [1: "день остался", 2: "дня осталось", 5: "дней осталось", 21: "день остался", 22: "дня осталось", 25: "дней осталось", 11: "дней осталось", 0: "дней осталось"],
                [1: "день назад", 2: "дня назад", 5: "дней назад", 21: "день назад", 22: "дня назад", 25: "дней назад", 11: "дней назад", 0: "дней назад"]
            ),
        ]
        let locale = Locale(identifier: language)
        for count in Self.counts {
            #expect(CountdownText.dayCaption(days: count, direction: .future, locale: locale) == expected[language]?.future[count], "\(count)")
            #expect(CountdownText.dayCaption(days: count, direction: .past, locale: locale) == expected[language]?.past[count], "\(count)")
        }
    }

    @Test("A decimal amount takes the plural form for fractions")
    func decimals() {
        func word(_ language: String, _ value: Double) -> String {
            CountdownText.unit(.year, decimal: value, locale: Locale(identifier: language))
        }
        #expect(word("en", 1.5) == "years")
        #expect(word("en", 2.3) == "years")
        #expect(word("de", 1.5) == "Jahre")
        #expect(word("de", 2.3) == "Jahre")
        #expect(word("ru", 1.5) == "года")
        #expect(word("ru", 2.3) == "года")
        #expect(word("ru", 5.7) == "года")
        // Whole amounts still follow the integer rules.
        #expect(word("ru", 21) == "год")
        #expect(word("ru", 25) == "лет")
        #expect(word("en", 1) == "year")
        #expect(CountdownText.unit(.day, decimal: 1.5, locale: Locale(identifier: "ru")) == "дня")
    }

    @Test("A label without a number uses the plain plural")
    func labels() {
        #expect(CountdownText.label(.day, locale: Locale(identifier: "en")) == "days")
        #expect(CountdownText.label(.day, locale: Locale(identifier: "de")) == "Tage")
        #expect(CountdownText.label(.day, locale: Locale(identifier: "ru")) == "дни")
        #expect(CountdownText.label(.hour, locale: Locale(identifier: "ru")) == "часы")
    }

    @Test("Strings with a count and other values agree in Russian")
    func russianSentences() {
        let ru = Locale(identifier: "ru")
        func text(_ key: String.LocalizationValue) -> String {
            String(localized: LocalizedStringResource(key, locale: ru))
        }
        #expect(text("progress.ofDays \(3) \(21)") == "3 из 21 дня")
        #expect(text("progress.ofDays \(3) \(25)") == "3 из 25 дней")
        #expect(text("recurrence.everyWeeks \(2)") == "Каждые 2 недели")
        #expect(text("recurrence.everyDays \(21)") == "Каждый 21 день")
        #expect(text("recurrence.everyYears \(5)") == "Каждые 5 лет")
        #expect(text("calc.bridgeDays.daysOff \(4)") == "4 дня отдыха")
        #expect(text("calc.sleep.cycles \(5) \("7 ч 30 мин")") == "5 циклов · 7 ч 30 мин")
        #expect(text("shared.weeksLived \(21) \("1 %")") == "Прожита 21 неделя, 1 %")
        #expect(text("astronomy.litDaysOld \("40 %") \(3)") == "Освещено 40 % · возраст 3 дня")
    }

    @Test("The Moon's age agrees with its number in English and German")
    func moonAge() {
        func text(_ language: String, _ age: Int) -> String {
            String(localized: LocalizedStringResource("astronomy.litDaysOld \("40 %") \(age)", locale: Locale(identifier: language)))
        }
        #expect(text("en", 1) == "40 % lit · 1 day old")
        #expect(text("en", 12) == "40 % lit · 12 days old")
        #expect(text("de", 1) == "40 % beleuchtet · 1 Tag alt")
    }
}
