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
    /// Weekday names in other forms than Foundation's, by weekday (1 is Sunday), such as the
    /// Russian "пятницу" in "в пятницу" ("on Friday").
    var weekdayForms: [String: Int] = [:]
    /// Other ways than Foundation's to say "in" before an amount of time, such as "en 3 días".
    var inWords: [String] = []
    var repeats: [Recurrence: [String]] = [:]
    var birthdayWords: [String] = []
    /// Checked before birthdays, as in French "anniversaire de mariage" is an anniversary, not a birthday.
    var anniversaryWords: [String] = []

    /// The languages of Localizable.xcstrings that write words apart, which are tried for every
    /// description, as people don't always write in the language their device is set to.
    /// Japanese, Korean and Chinese are read only on a device set to them, through Foundation alone.
    static let supportedLanguageCodes = ["en", "de", "es", "fr", "it", "pt", "nl", "ru"]

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
        case "it":
            EventLanguage(
                dateWords: ["il", "lo", "la"],
                timeWords: ["alle", "ore"],
                nextBeforeWeekday: ["prossimo"],
                nextAfterWeekday: ["prossimo", "prossima"],
                everyBeforeWeekday: ["ogni", "tutti i"],
                inWords: ["fra"],
                repeats: [
                    .daily: ["ogni giorno", "tutti i giorni"],
                    .weekly: ["ogni settimana", "tutte le settimane"],
                    .monthly: ["ogni mese", "tutti i mesi"],
                    .yearly: ["ogni anno", "tutti gli anni"],
                ],
                birthdayWords: ["compleanno"],
                anniversaryWords: ["anniversario"]
            )
        case "pt":
            EventLanguage(
                dateWords: ["em", "no", "na", "dia"],
                timeWords: ["às"],
                monthWords: ["de"],
                nextBeforeWeekday: ["próximo", "próxima"],
                nextAfterWeekday: ["que vem"],
                everyBeforeWeekday: ["todo", "toda"],
                inWords: ["daqui a"],
                repeats: [
                    .daily: ["todo dia", "todos os dias"],
                    .weekly: ["toda semana", "todas as semanas"],
                    .monthly: ["todo mês", "todos os meses"],
                    .yearly: ["todo ano", "todos os anos"],
                ],
                birthdayWords: ["aniversário"],
                // Checked before birthdays: "aniversário de casamento" is a wedding anniversary.
                anniversaryWords: ["aniversário de casamento", "bodas"]
            )
        case "nl":
            EventLanguage(
                dateWords: ["op", "de"],
                timeWords: ["om"],
                nextBeforeWeekday: ["volgende", "komende"],
                everyBeforeWeekday: ["elke", "iedere"],
                repeats: [
                    .daily: ["elke dag", "iedere dag", "dagelijks"],
                    .weekly: ["elke week", "iedere week", "wekelijks"],
                    .monthly: ["elke maand", "iedere maand", "maandelijks"],
                    .yearly: ["elk jaar", "ieder jaar", "jaarlijks"],
                ],
                birthdayWords: ["verjaardag"],
                anniversaryWords: ["jubileum", "trouwdag"]
            )
        case "ru":
            EventLanguage(
                dateWords: ["в", "во"],
                timeWords: ["в"],
                nextBeforeWeekday: ["следующий", "следующую", "следующее", "ближайший", "ближайшую", "ближайшее"],
                everyBeforeWeekday: ["каждый", "каждую", "каждое"],
                // Foundation names weekdays in the nominative; "в среду" takes the accusative.
                weekdayForms: ["среду": 4, "пятницу": 6, "субботу": 7],
                repeats: [
                    .daily: ["каждый день", "ежедневно"],
                    .weekly: ["каждую неделю", "еженедельно"],
                    .monthly: ["каждый месяц", "ежемесячно"],
                    .yearly: ["каждый год", "ежегодно"],
                ],
                // Matched at the start of a word, so these cover every case ending.
                birthdayWords: ["день рождения", "дня рождения", "дню рождения", "днём рождения", "днем рождения", "дне рождения"],
                anniversaryWords: ["годовщин", "юбиле"]
            )
        default:
            EventLanguage()
        }
    }
}
