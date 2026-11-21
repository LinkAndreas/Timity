#if DEBUG
import Foundation

/// Sample events for App Store and README screenshots, added when a debug build of
/// the iPhone, iPad or Watch app is launched with `-ScreenshotSamples`. They replace
/// the events on the device.
@MainActor
enum ScreenshotSamples {
    @MainActor
    static func addIfAsked(to repository: any EventRepository) {
        guard ProcessInfo.processInfo.arguments.contains("-ScreenshotSamples") else { return }
        repository.events.forEach { repository.delete($0.id) }
        repository.save(events(now: .now))
    }

    /// Lisbon, as the place the Sun and Moon are shown for, named in the app's language: neither
    /// the device's own location nor the places saved on it end up in a screenshot.
    static var place: Place {
        Place(latitude: 38.7223, longitude: -9.1393, timeZoneIdentifier: "Europe/Lisbon", name: titles("Lisbon"), detail: "Portugal")
    }

    /// The screen a screenshot is taken of, from `-ScreenshotScreen events|event|calculate|sun|settings|yearInReview` or a calculator's name,
    /// so each can be opened at launch without tapping there.
    static var requestedScreen: String? {
        UserDefaults.standard.string(forKey: "ScreenshotScreen")
    }

    private static func events(now: Date) -> [EventSnapshot] {
        let calendar = Calendar.autoupdatingCurrent
        func day(_ days: Int) -> Date { calendar.date(byAdding: .day, value: days, to: calendar.startOfDay(for: now)) ?? now }
        func event(_ title: String, in days: Int, symbol: String, color: EventColor, recurrence: Recurrence = .never,
                   list: String = "", pinned: Bool = false, progress: Bool = false) -> EventSnapshot {
            var event = EventSnapshot(title: title, isAllDay: true, recurrence: recurrence, color: color, symbolName: symbol, isPinned: pinned)
            event.setStartDate(day(days))
            event.listName = list
            event.showsProgress = progress
            event.progressStart = progress ? day(-60) : nil
            return event
        }
        let t = titles
        return [
            event(t("Trip to Lisbon"), in: 12, symbol: "airplane", color: .lagoon, list: t("Travel"), pinned: true, progress: true),
            event(t("Mum's Birthday"), in: 23, symbol: "birthday.cake.fill", color: .blossom, recurrence: .yearly, list: t("Family"), pinned: true),
            event(t("Final Exam"), in: 5, symbol: "graduationcap.fill", color: .indigo, list: t("Work")),
            event(t("Concert"), in: 41, symbol: "music.note", color: .purple),
            event(t("Wedding Anniversary"), in: 96, symbol: "heart.fill", color: .red, recurrence: .yearly, list: t("Family")),
            event(t("Christmas"), in: daysUntilChristmas(now: now, calendar: calendar), symbol: "gift.fill", color: .ember, recurrence: .yearly),
            event(t("Smoke-Free"), in: -214, symbol: "leaf.fill", color: .green),
            event(t("Moved to Berlin"), in: -680, symbol: "house.fill", color: .orange),
        ]
    }

    /// The sample titles in the language the app runs in, so screenshots in every language read naturally.
    private static func titles(_ english: String) -> String {
        let language = Bundle.main.preferredLocalizations.first ?? "en"
        return translations[language]?[english] ?? english
    }

    private static let translations: [String: [String: String]] = [
        "de": [
            "Trip to Lisbon": "Reise nach Lissabon", "Travel": "Reisen",
            "Mum's Birthday": "Mamas Geburtstag", "Family": "Familie",
            "Final Exam": "Abschlussprüfung", "Work": "Arbeit", "Concert": "Konzert", "Wedding Anniversary": "Hochzeitstag",
            "Christmas": "Weihnachten", "Smoke-Free": "Rauchfrei", "Moved to Berlin": "Umzug nach Berlin", "Lisbon": "Lissabon",
        ],
        "es": [
            "Trip to Lisbon": "Viaje a Lisboa", "Travel": "Viajes",
            "Mum's Birthday": "Cumpleaños de mamá", "Family": "Familia",
            "Final Exam": "Examen final", "Work": "Trabajo", "Concert": "Concierto", "Wedding Anniversary": "Aniversario de boda",
            "Christmas": "Navidad", "Smoke-Free": "Sin fumar", "Moved to Berlin": "Mudanza a Berlín", "Lisbon": "Lisboa",
        ],
        "fr": [
            "Trip to Lisbon": "Voyage à Lisbonne", "Travel": "Voyages",
            "Mum's Birthday": "Anniversaire de maman", "Family": "Famille",
            "Final Exam": "Examen final", "Work": "Travail", "Concert": "Concert", "Wedding Anniversary": "Anniversaire de mariage",
            "Christmas": "Noël", "Smoke-Free": "Sans tabac", "Moved to Berlin": "Emménagement à Berlin", "Lisbon": "Lisbonne",
        ],
        "it": [
            "Trip to Lisbon": "Viaggio a Lisbona", "Travel": "Viaggi",
            "Mum's Birthday": "Compleanno della mamma", "Family": "Famiglia",
            "Final Exam": "Esame finale", "Work": "Lavoro", "Concert": "Concerto", "Wedding Anniversary": "Anniversario di matrimonio",
            "Christmas": "Natale", "Smoke-Free": "Senza fumo", "Moved to Berlin": "Trasloco a Berlino", "Lisbon": "Lisbona",
        ],
        "pt-BR": [
            "Trip to Lisbon": "Viagem a Lisboa", "Travel": "Viagens",
            "Mum's Birthday": "Aniversário da mãe", "Family": "Família",
            "Final Exam": "Prova final", "Work": "Trabalho", "Concert": "Show", "Wedding Anniversary": "Aniversário de casamento",
            "Christmas": "Natal", "Smoke-Free": "Sem fumar", "Moved to Berlin": "Mudança para Berlim", "Lisbon": "Lisboa",
        ],
        "nl": [
            "Trip to Lisbon": "Reis naar Lissabon", "Travel": "Reizen",
            "Mum's Birthday": "Mama’s verjaardag", "Family": "Familie",
            "Final Exam": "Eindexamen", "Work": "Werk", "Concert": "Concert", "Wedding Anniversary": "Trouwdag",
            "Christmas": "Kerstmis", "Smoke-Free": "Rookvrij", "Moved to Berlin": "Verhuisd naar Berlijn", "Lisbon": "Lissabon",
        ],
        "ja": [
            "Trip to Lisbon": "リスボン旅行", "Travel": "旅行",
            "Mum's Birthday": "母の誕生日", "Family": "家族",
            "Final Exam": "期末試験", "Work": "仕事", "Concert": "コンサート", "Wedding Anniversary": "結婚記念日",
            "Christmas": "クリスマス", "Smoke-Free": "禁煙", "Moved to Berlin": "ベルリンに引っ越し", "Lisbon": "リスボン",
        ],
        "ko": [
            "Trip to Lisbon": "리스본 여행", "Travel": "여행",
            "Mum's Birthday": "엄마 생일", "Family": "가족",
            "Final Exam": "기말고사", "Work": "업무", "Concert": "콘서트", "Wedding Anniversary": "결혼기념일",
            "Christmas": "크리스마스", "Smoke-Free": "금연", "Moved to Berlin": "베를린 이사", "Lisbon": "리스본",
        ],
        "ru": [
            "Trip to Lisbon": "Поездка в Лиссабон", "Travel": "Путешествия",
            "Mum's Birthday": "День рождения мамы", "Family": "Семья",
            "Final Exam": "Выпускной экзамен", "Work": "Работа", "Concert": "Концерт", "Wedding Anniversary": "Годовщина свадьбы",
            "Christmas": "Рождество", "Smoke-Free": "Без курения", "Moved to Berlin": "Переезд в Берлин", "Lisbon": "Лиссабон",
        ],
        "zh-Hans": [
            "Trip to Lisbon": "里斯本之旅", "Travel": "旅行",
            "Mum's Birthday": "妈妈的生日", "Family": "家人",
            "Final Exam": "期末考试", "Work": "工作", "Concert": "音乐会", "Wedding Anniversary": "结婚纪念日",
            "Christmas": "圣诞节", "Smoke-Free": "戒烟", "Moved to Berlin": "搬到柏林", "Lisbon": "里斯本",
        ],
    ]

    private static func daysUntilChristmas(now: Date, calendar: Calendar) -> Int {
        let year = calendar.component(.year, from: now)
        let christmas = calendar.date(from: DateComponents(year: year, month: 12, day: 25)) ?? now
        return calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: christmas).day ?? 0
    }
}
#endif
