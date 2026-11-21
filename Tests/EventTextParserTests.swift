import Foundation
import Testing
@testable import Timity

@Suite("Reading event descriptions")
struct EventTextParserTests {
    struct Example: CustomTestStringConvertible, Sendable {
        let text: String
        let locale: String
        let title: String
        /// Year, month, day and, for a time, hour and minute.
        let date: [Int]
        var recurrence: Recurrence?
        var symbolName: String?

        var testDescription: String { "\(locale): \(text)" }
    }

    let calendar = Calendar.fixture(timeZone: "Europe/Berlin")
    /// Tuesday, 20 October 2026, 10:00.
    var now: Date { calendar.date(2026, 10, 20, 10, 0) }

    nonisolated static let cake = "birthday.cake.fill"
    nonisolated static let heart = "heart.fill"

    nonisolated static let monthNames: [Example] = [
        Example(text: "Mum's birthday on 12 May", locale: "en_US", title: "Mum's birthday", date: [2027, 5, 12], recurrence: .yearly, symbolName: cake),
        Example(text: "Mamas Geburtstag am 12. Mai", locale: "de_DE", title: "Mamas Geburtstag", date: [2027, 5, 12], recurrence: .yearly, symbolName: cake),
        Example(text: "Cumpleaños de mamá el 12 de mayo", locale: "es_ES", title: "Cumpleaños de mamá", date: [2027, 5, 12], recurrence: .yearly, symbolName: cake),
        Example(text: "Anniversaire de maman le 12 mai", locale: "fr_FR", title: "Anniversaire de maman", date: [2027, 5, 12], recurrence: .yearly, symbolName: cake),
        Example(text: "Graduation on June 3rd, 2028", locale: "en_US", title: "Graduation", date: [2028, 6, 3]),
        Example(text: "Graduation on the 3rd of June 2028", locale: "en_GB", title: "Graduation", date: [2028, 6, 3]),
        Example(text: "Abschluss am 3. Juni 2028", locale: "de_DE", title: "Abschluss", date: [2028, 6, 3]),
        Example(text: "Graduación el 3 de junio de 2028", locale: "es_ES", title: "Graduación", date: [2028, 6, 3]),
        Example(text: "Remise des diplômes le 3 juin 2028", locale: "fr_FR", title: "Remise des diplômes", date: [2028, 6, 3]),
        Example(text: "Christmas on 24 Dec", locale: "en_GB", title: "Christmas", date: [2026, 12, 24]),
        Example(text: "Compleanno della mamma il 12 maggio", locale: "it_IT", title: "Compleanno della mamma", date: [2027, 5, 12], recurrence: .yearly, symbolName: cake),
        Example(text: "Aniversário da mãe em 12 de maio", locale: "pt_BR", title: "Aniversário da mãe", date: [2027, 5, 12], recurrence: .yearly, symbolName: cake),
        Example(text: "Verjaardag van mama op 12 mei", locale: "nl_NL", title: "Verjaardag van mama", date: [2027, 5, 12], recurrence: .yearly, symbolName: cake),
        Example(text: "День рождения мамы 12 мая", locale: "ru_RU", title: "День рождения мамы", date: [2027, 5, 12], recurrence: .yearly, symbolName: cake),
    ]

    nonisolated static let weekdays: [Example] = [
        Example(text: "Party on Saturday", locale: "en_US", title: "Party", date: [2026, 10, 24]),
        Example(text: "Meeting next Friday", locale: "en_US", title: "Meeting", date: [2026, 10, 30]),
        Example(text: "Party am Samstag", locale: "de_DE", title: "Party", date: [2026, 10, 24]),
        Example(text: "Treffen nächsten Freitag", locale: "de_DE", title: "Treffen", date: [2026, 10, 30]),
        Example(text: "Fiesta el sábado", locale: "es_ES", title: "Fiesta", date: [2026, 10, 24]),
        Example(text: "Reunión el próximo viernes", locale: "es_ES", title: "Reunión", date: [2026, 10, 30]),
        Example(text: "Reunión el viernes que viene", locale: "es_ES", title: "Reunión", date: [2026, 10, 30]),
        Example(text: "Fête samedi", locale: "fr_FR", title: "Fête", date: [2026, 10, 24]),
        Example(text: "Réunion vendredi prochain", locale: "fr_FR", title: "Réunion", date: [2026, 10, 30]),
        Example(text: "Festa sabato", locale: "it_IT", title: "Festa", date: [2026, 10, 24]),
        Example(text: "Feest op zaterdag", locale: "nl_NL", title: "Feest", date: [2026, 10, 24]),
        Example(text: "Vergadering volgende vrijdag", locale: "nl_NL", title: "Vergadering", date: [2026, 10, 30]),
        Example(text: "Вечеринка в субботу", locale: "ru_RU", title: "Вечеринка", date: [2026, 10, 24]),
        Example(text: "Встреча в следующую пятницу", locale: "ru_RU", title: "Встреча", date: [2026, 10, 30]),
    ]

    nonisolated static let relativeDays: [Example] = [
        Example(text: "Dentist tomorrow", locale: "en_US", title: "Dentist", date: [2026, 10, 21]),
        Example(text: "Trip in 3 days", locale: "en_US", title: "Trip", date: [2026, 10, 23]),
        Example(text: "Concert next week", locale: "en_US", title: "Concert", date: [2026, 10, 27]),
        Example(text: "Zahnarzt übermorgen", locale: "de_DE", title: "Zahnarzt", date: [2026, 10, 22]),
        Example(text: "Reise in 3 Tagen", locale: "de_DE", title: "Reise", date: [2026, 10, 23]),
        Example(text: "Konzert nächste Woche", locale: "de_DE", title: "Konzert", date: [2026, 10, 27]),
        Example(text: "Dentista pasado mañana", locale: "es_ES", title: "Dentista", date: [2026, 10, 22]),
        Example(text: "Viaje en 3 días", locale: "es_ES", title: "Viaje", date: [2026, 10, 23]),
        Example(text: "Viaje dentro de 2 semanas", locale: "es_ES", title: "Viaje", date: [2026, 11, 3]),
        Example(text: "Concierto la próxima semana", locale: "es_ES", title: "Concierto", date: [2026, 10, 27]),
        Example(text: "Dentiste demain", locale: "fr_FR", title: "Dentiste", date: [2026, 10, 21]),
        Example(text: "Voyage dans 3 jours", locale: "fr_FR", title: "Voyage", date: [2026, 10, 23]),
        Example(text: "Concert la semaine prochaine", locale: "fr_FR", title: "Concert", date: [2026, 10, 27]),
        Example(text: "Стоматолог завтра", locale: "ru_RU", title: "Стоматолог", date: [2026, 10, 21]),
        Example(text: "Поездка через 5 дней", locale: "ru_RU", title: "Поездка", date: [2026, 10, 25]),
    ]

    nonisolated static let times: [Example] = [
        Example(text: "Dinner tomorrow at 7 pm", locale: "en_US", title: "Dinner", date: [2026, 10, 21, 19, 0]),
        Example(text: "Call at 18:00", locale: "en_GB", title: "Call", date: [2026, 10, 20, 18, 0]),
        Example(text: "Abendessen morgen um 19 Uhr", locale: "de_DE", title: "Abendessen", date: [2026, 10, 21, 19, 0]),
        Example(text: "Frühstück um 8:30", locale: "de_DE", title: "Frühstück", date: [2026, 10, 21, 8, 30]),
        Example(text: "Cena mañana a las 19:30", locale: "es_ES", title: "Cena", date: [2026, 10, 21, 19, 30]),
        Example(text: "Dîner demain à 19h30", locale: "fr_FR", title: "Dîner", date: [2026, 10, 21, 19, 30]),
        Example(text: "Ужин завтра в 19:30", locale: "ru_RU", title: "Ужин", date: [2026, 10, 21, 19, 30]),
    ]

    nonisolated static let recurrences: [Example] = [
        Example(text: "Team meeting every Monday at 10:00", locale: "en_US", title: "Team meeting", date: [2026, 10, 26, 10, 0], recurrence: .weekly),
        Example(text: "Tax return every year on 31 July", locale: "en_GB", title: "Tax return", date: [2027, 7, 31], recurrence: .yearly),
        Example(text: "Our anniversary on 5 June", locale: "en_GB", title: "Our anniversary", date: [2027, 6, 5], recurrence: .yearly, symbolName: heart),
        Example(text: "Teammeeting jeden Montag um 10 Uhr", locale: "de_DE", title: "Teammeeting", date: [2026, 10, 26, 10, 0], recurrence: .weekly),
        Example(text: "Steuererklärung jedes Jahr am 31. Juli", locale: "de_DE", title: "Steuererklärung", date: [2027, 7, 31], recurrence: .yearly),
        Example(text: "Hochzeitstag am 5. Juni", locale: "de_DE", title: "Hochzeitstag", date: [2027, 6, 5], recurrence: .yearly, symbolName: heart),
        Example(text: "Reunión de equipo cada lunes a las 10:00", locale: "es_ES", title: "Reunión de equipo", date: [2026, 10, 26, 10, 0], recurrence: .weekly),
        Example(text: "Declaración de la renta cada año el 31 de julio", locale: "es_ES", title: "Declaración de la renta", date: [2027, 7, 31], recurrence: .yearly),
        Example(text: "Aniversario el 5 de junio", locale: "es_ES", title: "Aniversario", date: [2027, 6, 5], recurrence: .yearly, symbolName: heart),
        Example(text: "Réunion d'équipe tous les lundis à 10h", locale: "fr_FR", title: "Réunion d'équipe", date: [2026, 10, 26, 10, 0], recurrence: .weekly),
        Example(text: "Déclaration d'impôts chaque année le 31 juillet", locale: "fr_FR", title: "Déclaration d'impôts", date: [2027, 7, 31], recurrence: .yearly),
        Example(text: "Anniversaire de mariage le 5 juin", locale: "fr_FR", title: "Anniversaire de mariage", date: [2027, 6, 5], recurrence: .yearly, symbolName: heart),
        Example(text: "Планёрка каждый понедельник в 10:00", locale: "ru_RU", title: "Планёрка", date: [2026, 10, 26, 10, 0], recurrence: .weekly),
        Example(text: "Годовщина свадьбы 5 июня", locale: "ru_RU", title: "Годовщина свадьбы", date: [2027, 6, 5], recurrence: .yearly, symbolName: heart),
    ]

    @Test("Dates with month names", arguments: monthNames)
    func monthName(_ example: Example) { check(example) }

    @Test("Weekdays", arguments: weekdays)
    func weekday(_ example: Example) { check(example) }

    @Test("Relative days", arguments: relativeDays)
    func relativeDay(_ example: Example) { check(example) }

    @Test("Times of day", arguments: times)
    func time(_ example: Example) { check(example) }

    @Test("Repeats", arguments: recurrences)
    func recurrence(_ example: Example) { check(example) }

    @Test("Text in another of the app's languages than the device's", arguments: [
        Example(text: "Mamas Geburtstag am 12. Mai", locale: "en_US", title: "Mamas Geburtstag", date: [2027, 5, 12], recurrence: .yearly, symbolName: cake),
        Example(text: "Cena mañana a las 19:30", locale: "de_DE", title: "Cena", date: [2026, 10, 21, 19, 30]),
        Example(text: "Dinner tomorrow at 7 pm", locale: "fr_FR", title: "Dinner", date: [2026, 10, 21, 19, 0]),
    ])
    func otherLanguage(_ example: Example) { check(example) }

    @Test("Without a date, only the name")
    func noDate() {
        let parsed = EventTextParser.read("Holiday", now: now, locale: Locale(identifier: "en_US"), calendar: calendar)
        #expect(parsed.title == "Holiday")
        #expect(parsed.recurrence == nil)
    }

    private func check(_ example: Example, sourceLocation: SourceLocation = #_sourceLocation) {
        let parsed = EventTextParser.read(example.text, now: now, locale: Locale(identifier: example.locale), calendar: calendar)
        let hasTime = example.date.count == 5
        let expected = calendar.date(example.date[0], example.date[1], example.date[2], hasTime ? example.date[3] : 0, hasTime ? example.date[4] : 0)
        let date = hasTime ? parsed.date : parsed.date.map(calendar.startOfDay(for:))
        #expect(date == expected, sourceLocation: sourceLocation)
        #expect(parsed.isAllDay == !hasTime, sourceLocation: sourceLocation)
        #expect(parsed.title == example.title, sourceLocation: sourceLocation)
        #expect(parsed.recurrence == example.recurrence, sourceLocation: sourceLocation)
        #expect(parsed.symbolName == example.symbolName, sourceLocation: sourceLocation)
    }
}
