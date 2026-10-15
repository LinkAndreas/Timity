import Foundation

/// Every event as a file the user keeps: a complete JSON backup, or a CSV spreadsheet
/// for Numbers or Excel. Both open in Timity again; importing merges by ID, so the
/// same file imported twice changes nothing the second time.
nonisolated enum EventBackup {
    nonisolated enum Format: String, CaseIterable, Identifiable, Sendable {
        case json, csv

        var id: Self { self }
        var fileExtension: String { rawValue }
    }

    nonisolated enum ImportError: Error, Equatable {
        /// Neither a Timity backup, a `.timity` event nor a CSV with Title and Date columns.
        case unreadable
    }

    /// What an import did.
    nonisolated struct Outcome: Equatable, Sendable {
        var added = 0
        var updated = 0
        var unchanged = 0
        /// CSV rows without a title or a readable date.
        var skipped = 0
    }

    // MARK: JSON

    /// The whole file: a marker, a version and the events.
    nonisolated struct Archive: Codable {
        var format = Archive.marker
        var version = 1
        var exportedAt: Date
        var events: [Entry]

        static let marker = "timity-backup"
    }

    /// One event. Everything but the title and date is optional, so files from older
    /// and newer versions of Timity open alike.
    nonisolated struct Entry: Codable, Equatable {
        var id: UUID?
        var title: String
        /// As stored: for all-day events, midnight UTC of the day.
        var date: Date
        var isAllDay: Bool?
        var recurrence: String?
        var recurrenceInterval: Int?
        var recurrencePattern: String?
        var calendar: String?
        var color: String?
        var symbol: String?
        var isPinned: Bool?
        var isArchived: Bool?
        var list: String?
        var notes: String?
        var timeZone: String?
        var isYearUnknown: Bool?
        var reminderMinutes: Int?
        var showsProgress: Bool?
        var progressStart: Date?
        var resetHistory: [Date]?
        var createdAt: Date?
        var modifiedAt: Date?
        var photo: Data?

        init(_ event: EventSnapshot, includingPhoto: Bool) {
            id = event.id
            title = event.title
            date = event.date
            isAllDay = event.isAllDay
            recurrence = event.recurrence.rawValue
            recurrenceInterval = event.recurrenceInterval
            recurrencePattern = event.recurrencePattern.rawValue
            calendar = event.eventCalendar?.rawValue
            color = event.color.rawValue
            symbol = event.symbolName
            isPinned = event.isPinned
            isArchived = event.isArchived
            list = event.listName
            notes = event.notes
            timeZone = event.timeZoneIdentifier
            isYearUnknown = event.isYearUnknown
            reminderMinutes = event.reminderMinutes
            showsProgress = event.showsProgress
            progressStart = event.progressStart
            resetHistory = event.resetHistory
            createdAt = event.createdAt
            modifiedAt = event.modifiedAt
            photo = includingPhoto ? event.imageData : nil
        }

        func snapshot(now: Date) -> EventSnapshot {
            var event = EventSnapshot()
            event.id = id ?? UUID()
            event.title = title
            event.date = date
            event.isAllDay = isAllDay ?? false
            event.recurrence = recurrence.flatMap(Recurrence.init(rawValue:)) ?? .never
            event.recurrenceInterval = max(1, recurrenceInterval ?? 1)
            event.recurrencePattern = recurrencePattern.flatMap(RecurrenceRule.Pattern.init(rawValue:)) ?? .sameDay
            event.eventCalendar = calendar.flatMap(EventCalendar.init(rawValue:))
            event.color = color.flatMap(EventColor.init(rawValue:)) ?? .orange
            event.symbolName = symbol ?? EventSymbol.defaultName
            event.isPinned = isPinned ?? false
            event.isArchived = isArchived ?? false
            event.listName = list ?? ""
            event.notes = notes ?? ""
            event.timeZoneIdentifier = timeZone
            event.isYearUnknown = isYearUnknown ?? false
            event.reminderMinutes = reminderMinutes
            event.showsProgress = showsProgress ?? false
            event.progressStart = progressStart
            event.resetHistory = resetHistory ?? []
            event.createdAt = createdAt ?? now
            event.modifiedAt = modifiedAt ?? now
            event.imageData = photo
            return event
        }
    }

    static func json(_ events: [EventSnapshot], includingPhotos: Bool, now: Date = .now) throws -> Data {
        let archive = Archive(exportedAt: now, events: events.map { Entry($0, includingPhoto: includingPhotos) })
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(archive)
    }

    // MARK: CSV

    /// The columns, in order; reading accepts them in any order and leaves out unknown ones.
    nonisolated enum Column: String, CaseIterable {
        case title = "Title"
        case date = "Date"
        case time = "Time"
        case allDay = "All-Day"
        case timeZone = "Time Zone"
        case repeats = "Repeats"
        case every = "Every"
        case list = "List"
        case notes = "Notes"
        case color = "Color"
        case symbol = "Symbol"
        case pinned = "Pinned"
        case archived = "Archived"
        case reminder = "Reminder Minutes"
        case id = "ID"
    }

    /// A spreadsheet of every event, without photos. Dates read `2026-11-05`, times
    /// `14:30` where the event happens; a byte order mark lets Excel see UTF-8.
    static func csv(_ events: [EventSnapshot], calendar: Calendar = .autoupdatingCurrent) -> Data {
        var rows = [Column.allCases.map(\.rawValue)]
        for event in events {
            var eventCalendar = Calendar(identifier: .gregorian)
            eventCalendar.timeZone = event.timeZone ?? calendar.timeZone
            let start = event.isAllDay ? FloatingDay.localDate(fromStored: event.date, calendar: eventCalendar) : event.date
            let parts = eventCalendar.dateComponents([.year, .month, .day, .hour, .minute], from: start)
            let day = String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
            let time = event.isAllDay ? "" : String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0)
            rows.append(Column.allCases.map { column in
                switch column {
                case .title: event.title
                case .date: day
                case .time: time
                case .allDay: event.isAllDay ? "yes" : "no"
                case .timeZone: event.isAllDay ? "" : event.timeZoneIdentifier ?? ""
                case .repeats: event.recurrence.rawValue
                case .every: event.recurrence == .never ? "" : String(event.recurrenceInterval)
                case .list: event.listName
                case .notes: event.notes
                case .color: event.color.rawValue
                case .symbol: event.symbolName
                case .pinned: event.isPinned ? "yes" : "no"
                case .archived: event.isArchived ? "yes" : "no"
                case .reminder: event.reminderMinutes.map(String.init) ?? ""
                case .id: event.id.uuidString
                }
            })
        }
        let text = rows.map { $0.map(escaped).joined(separator: ",") }.joined(separator: "\r\n") + "\r\n"
        return Data("\u{FEFF}\(text)".utf8)
    }

    private static func escaped(_ field: String) -> String {
        guard field.contains(where: { ",;\"\r\n".contains($0) }) || field.hasPrefix(" ") || field.hasSuffix(" ") else { return field }
        return "\"\(field.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    // MARK: Reading

    /// The events in a Timity backup, a `.timity` event or a CSV file.
    static func events(from data: Data, calendar: Calendar = .autoupdatingCurrent, now: Date = .now) throws -> (events: [EventSnapshot], skipped: Int) {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let archive = try? decoder.decode(Archive.self, from: data), archive.format == Archive.marker {
            return (archive.events.map { $0.snapshot(now: now) }, 0)
        }
        if let file = try? EventFile.decode(data) {
            var event = EventSnapshot(title: file.title, date: file.date, isAllDay: file.isAllDay)
            event.recurrence = Recurrence(rawValue: file.recurrence) ?? .never
            event.color = EventColor(rawValue: file.color) ?? .orange
            event.symbolName = file.symbolName
            event.notes = file.notes
            event.timeZoneIdentifier = file.timeZoneIdentifier
            event.isYearUnknown = file.isYearUnknown
            event.imageData = file.imageData
            event.recurrenceInterval = max(1, file.recurrenceInterval ?? 1)
            event.recurrencePattern = file.recurrencePattern.flatMap(RecurrenceRule.Pattern.init(rawValue:)) ?? .sameDay
            event.eventCalendar = file.eventCalendar.flatMap(EventCalendar.init(rawValue:))
            event.id = UUID(stableFrom: "file|\(file.title)|\(file.date.timeIntervalSince1970)")
            event.createdAt = now
            event.modifiedAt = now
            return ([event], 0)
        }
        return try events(fromCSV: data, calendar: calendar, now: now)
    }

    private static func events(fromCSV data: Data, calendar: Calendar, now: Date) throws -> (events: [EventSnapshot], skipped: Int) {
        guard var text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            throw ImportError.unreadable
        }
        if text.hasPrefix("\u{FEFF}") { text.removeFirst() }
        // German Excel writes semicolons; the header shows which.
        let firstLine = text.prefix { $0 != "\n" && $0 != "\r" }
        let separator: Character = firstLine.filter { $0 == ";" }.count > firstLine.filter { $0 == "," }.count ? ";" : ","
        let rows = parseCSV(text, separator: separator)
        guard let header = rows.first else { throw ImportError.unreadable }

        var index: [Column: Int] = [:]
        for (position, name) in header.enumerated() {
            let name = name.trimmingCharacters(in: .whitespaces).lowercased()
            if let column = Column.allCases.first(where: { $0.rawValue.lowercased() == name }) {
                index[column] = position
            }
        }
        guard index[.title] != nil, index[.date] != nil else { throw ImportError.unreadable }

        var events: [EventSnapshot] = []
        var skipped = 0
        for row in rows.dropFirst() where !row.allSatisfy({ $0.trimmingCharacters(in: .whitespaces).isEmpty }) {
            func value(_ column: Column) -> String {
                guard let position = index[column], position < row.count else { return "" }
                return row[position].trimmingCharacters(in: .whitespacesAndNewlines)
            }
            let title = value(.title)
            guard !title.isEmpty, let event = event(title: title, value: value, calendar: calendar, now: now) else {
                skipped += 1
                continue
            }
            events.append(event)
        }
        return (events, skipped)
    }

    private static func event(title: String, value: (Column) -> String, calendar: Calendar, now: Date) -> EventSnapshot? {
        let zone = value(.timeZone).isEmpty ? nil : TimeZone(identifier: value(.timeZone))
        var eventCalendar = Calendar(identifier: .gregorian)
        eventCalendar.timeZone = zone ?? calendar.timeZone

        let dateText = value(.date)
        let timeText = value(.time)
        let allDayText = value(.allDay)
        var start: Date
        var isAllDay: Bool
        if let day = Self.day(dateText) {
            var components = day
            let time = Self.time(timeText)
            isAllDay = allDayText.isEmpty ? time == nil : bool(allDayText)
            if !isAllDay, let time {
                components.hour = time.hour
                components.minute = time.minute
            }
            guard let date = eventCalendar.date(from: components) else { return nil }
            start = date
        } else if let moment = try? Date(dateText, strategy: .iso8601) {
            start = moment
            isAllDay = !allDayText.isEmpty && bool(allDayText)
        } else {
            return nil
        }

        var event = EventSnapshot(title: title, isAllDay: isAllDay)
        event.date = isAllDay ? FloatingDay.storedDate(forDayOf: start, calendar: eventCalendar) : start
        event.timeZoneIdentifier = isAllDay ? nil : zone?.identifier
        event.recurrence = Recurrence(rawValue: value(.repeats).lowercased()) ?? .never
        event.recurrenceInterval = max(1, Int(value(.every)) ?? 1)
        event.listName = value(.list)
        event.notes = value(.notes)
        event.color = EventColor(rawValue: value(.color)) ?? .orange
        if !value(.symbol).isEmpty { event.symbolName = value(.symbol) }
        event.isPinned = bool(value(.pinned))
        event.isArchived = bool(value(.archived))
        event.reminderMinutes = Int(value(.reminder))
        // A row without an ID gets one from its title and date, so importing the same
        // spreadsheet again finds the events it added.
        event.id = UUID(uuidString: value(.id)) ?? UUID(stableFrom: "csv|\(title)|\(event.date.timeIntervalSince1970)")
        event.createdAt = now
        event.modifiedAt = now
        return event
    }

    /// `2026-11-05`, or `05.11.2026` as written in Germany.
    private static func day(_ text: String) -> DateComponents? {
        let iso = text.split(separator: "-")
        if iso.count == 3, iso[0].count == 4, let year = Int(iso[0]), let month = Int(iso[1]), let day = Int(iso[2]) {
            return DateComponents(year: year, month: month, day: day)
        }
        let dotted = text.split(separator: ".")
        if dotted.count == 3, let day = Int(dotted[0]), let month = Int(dotted[1]), let year = Int(dotted[2]), dotted[2].count == 4 {
            return DateComponents(year: year, month: month, day: day)
        }
        return nil
    }

    /// `14:30`.
    private static func time(_ text: String) -> (hour: Int, minute: Int)? {
        let parts = text.split(separator: ":")
        guard parts.count >= 2, let hour = Int(parts[0]), let minute = Int(parts[1]),
              (0..<24).contains(hour), (0..<60).contains(minute) else { return nil }
        return (hour, minute)
    }

    private static func bool(_ text: String) -> Bool {
        ["yes", "true", "1", "ja", "oui", "sí", "si", "x"].contains(text.lowercased())
    }

    /// Rows of fields, as RFC 4180 has them: quoted fields may hold separators,
    /// line breaks and doubled quotes.
    static func parseCSV(_ text: String, separator: Character = ",") -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var isQuoted = false
        var characters = text.makeIterator()
        var pending: Character?

        while let character = pending ?? characters.next() {
            pending = nil
            if isQuoted {
                if character == "\"" {
                    let next = characters.next()
                    if next == "\"" {
                        field.append("\"")
                    } else {
                        isQuoted = false
                        pending = next
                    }
                } else {
                    field.append(character)
                }
            } else if character == "\"", field.isEmpty {
                isQuoted = true
            } else if character == separator {
                row.append(field)
                field = ""
            } else if character == "\n" || character == "\r" || character == "\r\n" {
                row.append(field)
                rows.append(row)
                row = []
                field = ""
                if character == "\r", let next = characters.next(), next != "\n" { pending = next }
            } else {
                field.append(character)
            }
        }
        if !field.isEmpty || !row.isEmpty {
            row.append(field)
            rows.append(row)
        }
        return rows
    }

    // MARK: Merging

    /// What to save so `incoming` joins `existing`: new IDs are added, and a known
    /// event is replaced only when it differs and was changed later. A file without
    /// photos leaves the photos already here.
    static func merge(_ incoming: [EventSnapshot], into existing: [EventSnapshot]) -> (toSave: [EventSnapshot], outcome: Outcome) {
        let current = Dictionary(existing.map { ($0.id, $0) }, uniquingKeysWith: { $0.modifiedAt >= $1.modifiedAt ? $0 : $1 })
        var toSave: [EventSnapshot] = []
        var outcome = Outcome()
        for var event in incoming {
            guard let known = current[event.id] else {
                toSave.append(event)
                outcome.added += 1
                continue
            }
            if event.imageData == nil { event.imageData = known.imageData }
            var comparable = event
            comparable.createdAt = known.createdAt
            comparable.modifiedAt = known.modifiedAt
            if comparable == known || event.modifiedAt < known.modifiedAt {
                outcome.unchanged += 1
            } else {
                event.createdAt = known.createdAt
                toSave.append(event)
                outcome.updated += 1
            }
        }
        return (toSave, outcome)
    }
}
