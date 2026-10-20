import Foundation

/// The words of a language that Foundation can't tell `EventTextReader`: the small words around
/// a date or time, how to say "next" or "every" with a weekday, repeats, and birthdays.
///
/// Month and weekday names, "tomorrow", "in 3 days" and how times are written all come from
/// Foundation for the language at hand, so only these remain. There's one list for each language
/// the app is localized in; any other language reads dates through Foundation alone.
nonisolated struct EventLanguage {
    /// Small words that go with a date or a relative day, such as "on" in "on 12 May".
    var dateWords: [String] = []
    /// Words that introduce a time, such as "at" in "at 7 pm"; after them a bare hour is a time.
    var timeWords: [String] = []
    /// Words between the day and the month, such as "of" in "12th of May".
    var monthWords: [String] = []
    /// "next" before a weekday, as in "next Friday".
    var nextBeforeWeekday: [String] = []
    /// "next" after a weekday, as in "vendredi prochain".
    var nextAfterWeekday: [String] = []
    /// "every" before a weekday, as in "every Monday", which makes the event weekly.
    var everyBeforeWeekday: [String] = []
    /// Other ways than Foundation's to say "in" before an amount of time, such as "en 3 días".
    var inWords: [String] = []
    var repeats: [Recurrence: [String]] = [:]
    var birthdayWords: [String] = []
    /// Checked before birthdays, as in French "anniversaire de mariage" is an anniversary, not a birthday.
    var anniversaryWords: [String] = []

    /// The languages of Localizable.xcstrings, which are tried for every description, as people
    /// don't always write in the language their device is set to.
    static let supportedLanguageCodes = ["en", "de", "es", "fr"]

    static func words(for languageCode: String?) -> EventLanguage {
        switch languageCode {
        case "en":
            EventLanguage(
                dateWords: ["on", "the"],
                timeWords: ["at"],
                monthWords: ["of"],
                nextBeforeWeekday: ["next"],
                everyBeforeWeekday: ["every"],
                repeats: [
                    .daily: ["every day"],
                    .weekly: ["every week"],
                    .monthly: ["every month"],
                    .yearly: ["every year"],
                ],
                birthdayWords: ["birthday"],
                anniversaryWords: ["anniversary"]
            )
        case "de":
            EventLanguage(
                dateWords: ["am", "den"],
                timeWords: ["um"],
                nextBeforeWeekday: ["nächsten", "nächster", "nächste", "kommenden", "kommender"],
                everyBeforeWeekday: ["jeden"],
                repeats: [
                    .daily: ["jeden Tag"],
                    .weekly: ["jede Woche"],
                    .monthly: ["jeden Monat"],
                    .yearly: ["jedes Jahr"],
                ],
                birthdayWords: ["geburtstag"],
                anniversaryWords: ["jahrestag", "hochzeitstag"]
            )
        case "es":
            EventLanguage(
                dateWords: ["el", "la"],
                timeWords: ["a las", "a la"],
                monthWords: ["de"],
                nextBeforeWeekday: ["próximo"],
                nextAfterWeekday: ["próximo", "que viene"],
                everyBeforeWeekday: ["cada", "todos los"],
                inWords: ["en"],
                repeats: [
                    .daily: ["cada día", "todos los días"],
                    .weekly: ["cada semana", "todas las semanas"],
                    .monthly: ["cada mes", "todos los meses"],
                    .yearly: ["cada año", "todos los años"],
                ],
                birthdayWords: ["cumpleaños"],
                anniversaryWords: ["aniversario"]
            )
        case "fr":
            EventLanguage(
                dateWords: ["le", "la"],
                timeWords: ["à"],
                nextAfterWeekday: ["prochain"],
                everyBeforeWeekday: ["chaque", "tous les"],
                repeats: [
                    .daily: ["chaque jour", "tous les jours"],
                    .weekly: ["chaque semaine", "toutes les semaines"],
                    .monthly: ["chaque mois", "tous les mois"],
                    .yearly: ["chaque année", "tous les ans"],
                ],
                birthdayWords: ["anniversaire"],
                anniversaryWords: ["anniversaire de mariage"]
            )
        default:
            EventLanguage()
        }
    }
}
