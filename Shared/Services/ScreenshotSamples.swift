#if DEBUG
import Foundation

/// Sample events for App Store and README screenshots, added when a debug build of
/// the iPhone, iPad or Watch app is launched with `-ScreenshotSamples`. They replace
/// the events on the device.
enum ScreenshotSamples {
    @MainActor
    static func addIfAsked(to repository: any EventRepository) {
        guard ProcessInfo.processInfo.arguments.contains("-ScreenshotSamples") else { return }
        repository.events.forEach { repository.delete($0.id) }
        repository.save(events(now: .now))
    }

    private static func events(now: Date) -> [EventSnapshot] {
        let calendar = Calendar.autoupdatingCurrent
        func day(_ days: Int) -> Date { calendar.date(byAdding: .day, value: days, to: calendar.startOfDay(for: now)) ?? now }
        func event(_ title: String, in days: Int, symbol: String, color: EventColor, recurrence: Recurrence = .never,
                   list: String = "", pinned: Bool = false, progress: Bool = false, checklist: [String] = []) -> EventSnapshot {
            var event = EventSnapshot(title: title, isAllDay: true, recurrence: recurrence, color: color, symbolName: symbol, isPinned: pinned)
            event.setStartDate(day(days))
            event.listName = list
            event.showsProgress = progress
            event.progressStart = progress ? day(-60) : nil
            event.checklist = checklist.map { ChecklistItem(title: $0) }
            return event
        }
        let t = titles
        return [
            event(t("Trip to Lisbon"), in: 12, symbol: "airplane", color: .lagoon, list: t("Travel"), pinned: true, progress: true,
                  checklist: [t("Book hotel"), t("Passport"), t("Pack sunscreen")]),
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
            "Trip to Lisbon": "Reise nach Lissabon", "Travel": "Reisen", "Book hotel": "Hotel buchen", "Passport": "Reisepass",
            "Pack sunscreen": "Sonnencreme einpacken", "Mum's Birthday": "Mamas Geburtstag", "Family": "Familie",
            "Final Exam": "Abschlussprüfung", "Work": "Arbeit", "Concert": "Konzert", "Wedding Anniversary": "Hochzeitstag",
            "Christmas": "Weihnachten", "Smoke-Free": "Rauchfrei", "Moved to Berlin": "Umzug nach Berlin",
        ],
        "es": [
            "Trip to Lisbon": "Viaje a Lisboa", "Travel": "Viajes", "Book hotel": "Reservar hotel", "Passport": "Pasaporte",
            "Pack sunscreen": "Llevar protector solar", "Mum's Birthday": "Cumpleaños de mamá", "Family": "Familia",
            "Final Exam": "Examen final", "Work": "Trabajo", "Concert": "Concierto", "Wedding Anniversary": "Aniversario de boda",
            "Christmas": "Navidad", "Smoke-Free": "Sin fumar", "Moved to Berlin": "Mudanza a Berlín",
        ],
        "fr": [
            "Trip to Lisbon": "Voyage à Lisbonne", "Travel": "Voyages", "Book hotel": "Réserver l’hôtel", "Passport": "Passeport",
            "Pack sunscreen": "Prendre la crème solaire", "Mum's Birthday": "Anniversaire de maman", "Family": "Famille",
            "Final Exam": "Examen final", "Work": "Travail", "Concert": "Concert", "Wedding Anniversary": "Anniversaire de mariage",
            "Christmas": "Noël", "Smoke-Free": "Sans tabac", "Moved to Berlin": "Emménagement à Berlin",
        ],
    ]

    private static func daysUntilChristmas(now: Date, calendar: Calendar) -> Int {
        let year = calendar.component(.year, from: now)
        let christmas = calendar.date(from: DateComponents(year: year, month: 12, day: 25)) ?? now
        return calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: christmas).day ?? 0
    }
}
#endif
