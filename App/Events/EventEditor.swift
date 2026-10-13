import PhotosUI
import SwiftUI

/// The values being edited, kept apart from the event so Cancel leaves it untouched.
struct EventDraft {
    var title = ""
    var date = EventDraft.defaultDate
    var isAllDay = true
    var recurrence = Recurrence.never
    var color = EventColor.orange
    var symbolName = EventSymbol.defaultName
    var notes = ""
    var reminderMinutes: Int?
    var imageData: Data?
    var timeZoneIdentifier: String?
    var listName = ""
    var isYearUnknown = false
    var recurrenceInterval = 1
    var recurrencePattern = RecurrenceRule.Pattern.sameDay
    var eventCalendar: EventCalendar?
    var showsProgress = false
    var progressStart: Date?

    init() {}

    var rule: RecurrenceRule {
        RecurrenceRule(
            frequency: recurrence,
            interval: recurrenceInterval,
            pattern: recurrencePattern,
            calendarIdentifier: recurrence == .yearly ? eventCalendar?.identifier : nil
        )
    }

    /// The patterns that fit the date and frequency; a pattern that no longer fits
    /// falls back to the same day.
    var availablePatterns: [RecurrenceRule.Pattern] {
        RecurrenceRule.patterns(for: date, frequency: recurrence)
    }

    var timeZone: TimeZone? {
        timeZoneIdentifier.flatMap(TimeZone.init(identifier:))
    }

    init(_ event: EventSnapshot) {
        title = event.title
        date = event.startDate()
        isAllDay = event.isAllDay
        recurrence = event.recurrence
        color = event.color
        symbolName = event.symbolName
        notes = event.notes
        reminderMinutes = event.reminderMinutes
        imageData = event.imageData
        timeZoneIdentifier = event.timeZoneIdentifier
        listName = event.listName
        isYearUnknown = event.isYearUnknown
        recurrenceInterval = max(1, event.recurrenceInterval)
        recurrencePattern = event.recurrencePattern
        eventCalendar = event.eventCalendar
        showsProgress = event.showsProgress
        progressStart = event.progressStart
    }

    var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The event with the draft's values: `event` changed, or by default a new one.
    func applied(to event: EventSnapshot = EventSnapshot()) -> EventSnapshot {
        var event = event
        event.title = trimmedTitle
        event.isAllDay = isAllDay
        event.setStartDate(date)
        event.recurrence = recurrence
        event.color = color
        event.symbolName = symbolName
        event.notes = notes
        event.reminderMinutes = reminderMinutes
        event.imageData = imageData
        event.timeZoneIdentifier = isAllDay ? nil : timeZoneIdentifier
        event.listName = listName.trimmingCharacters(in: .whitespacesAndNewlines)
        event.isYearUnknown = isYearUnknown && isAllDay && recurrence == .yearly
        event.recurrenceInterval = recurrence == .never ? 1 : max(1, recurrenceInterval)
        event.recurrencePattern = availablePatterns.contains(recurrencePattern) ? recurrencePattern : .sameDay
        event.eventCalendar = recurrence == .yearly && isAllDay ? eventCalendar : nil
        event.showsProgress = showsProgress
        event.progressStart = recurrence == .never && showsProgress ? progressStart : nil
        event.modifiedAt = .now
        return event
    }

    /// Tomorrow at the next full hour, a sensible start for a new event.
    private static var defaultDate: Date {
        let calendar = Calendar.autoupdatingCurrent
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: .now) ?? .now
        return calendar.date(bySetting: .minute, value: 0, of: tomorrow) ?? tomorrow
    }
}

/// Adds or edits an event.
struct EventEditor: View {
    /// The event to edit, or `nil` to add one.
    let event: EventSnapshot?
    /// Values for a new event, e.g. from a received file.
    let template: EventDraft?
    /// Common events to start a new one from.
    let templates: [(EventTemplate, EventDraft)]
    /// The lists events already use, to pick from.
    let listNames: [String]
    /// Asks for permission to send reminders, once one is chosen.
    let requestReminderPermission: () async -> Void
    /// Reads an event's name, date and repetition from a description such as "Mum's birthday on 3 March".
    let parseDescription: (String) async -> ParsedEventDescription
    let onSave: (EventSnapshot) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft = EventDraft()
    @State private var photoItem: PhotosPickerItem?
    @State private var isLoadingPhoto = false
    @State private var isConfirmingDiscard = false
    @State private var hasLoaded = false
    @State private var eventDescription = ""
    @State private var isUnderstanding = false
    @State private var isAddingList = false
    @State private var newListName = ""
    @FocusState private var isTitleFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    EditorPreview(draft: draft)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                }

                // Templates while the new event is still blank, a tap away.
                if event == nil, template == nil, draft.trimmedTitle.isEmpty, !templates.isEmpty {
                    Section {
                        Menu {
                            ForEach(templates, id: \.0) { template, templateDraft in
                                Button(templateDraft.title, systemImage: template.symbolName) {
                                    withAnimation { draft = templateDraft }
                                    isTitleFocused = false
                                }
                            }
                        } label: {
                            Label("Start From a Template", systemImage: "square.grid.2x2")
                        }
                    }
                }

                if event == nil {
                    Section {
                        HStack {
                            TextField("Describe It", text: $eventDescription, prompt: Text("Mum's birthday on 3 March"))
                                .submitLabel(.go)
                                .onSubmit { Task { await understand() } }
                            if isUnderstanding {
                                ProgressView()
                            } else {
                                Button("Fill In", systemImage: "sparkles") {
                                    Task { await understand() }
                                }
                                .labelStyle(.iconOnly)
                                .disabled(eventDescription.trimmingCharacters(in: .whitespaces).isEmpty)
                            }
                        }
                    } footer: {
                        Text("Type an event in your own words, and Timity fills in the name, date and repetition.")
                    }
                }

                Section {
                    TextField("Name", text: $draft.title)
                        .font(.title3.weight(.semibold))
                        .focused($isTitleFocused)
                        .submitLabel(.done)
                }

                Section {
                    Toggle("All-Day", isOn: $draft.isAllDay.animation())
                    DatePicker(
                        "Date",
                        selection: $draft.date,
                        displayedComponents: draft.isAllDay ? [.date] : [.date, .hourAndMinute]
                    )
                    // The date and time as they read where the event happens.
                    .environment(\.timeZone, draft.isAllDay ? .autoupdatingCurrent : (draft.timeZone ?? .autoupdatingCurrent))
                    if !draft.isAllDay {
                        NavigationLink {
                            TimeZonePicker(selection: $draft.timeZoneIdentifier)
                        } label: {
                            LabeledContent("Time Zone") {
                                Text(draft.timeZone.map(TimeZonePicker.name(for:)) ?? String(localized: "Local Time"))
                            }
                        }
                    }
                } footer: {
                    if draft.recurrence == .yearly {
                        Text("Perfect for birthdays and anniversaries: Timity counts down to the next one and shows how many years it marks.")
                    }
                }

                RepeatSection(draft: $draft)

                Section {
                    Toggle("Show Progress", isOn: $draft.showsProgress.animation())
                    if draft.showsProgress, draft.recurrence == .never {
                        DatePicker(
                            "Progress From",
                            selection: Binding(
                                get: { draft.progressStart ?? event?.createdAt ?? .now },
                                set: { draft.progressStart = $0 }
                            ),
                            in: ...draft.date,
                            displayedComponents: draft.isAllDay ? [.date] : [.date, .hourAndMinute]
                        )
                    }
                } footer: {
                    if draft.showsProgress {
                        Text(draft.recurrence == .never
                            ? LocalizedStringKey("Shows how much of the wait has passed, from the date you choose to the event.")
                            : LocalizedStringKey("Shows how much of the wait has passed since the last time."))
                    }
                }

                Section("Appearance") {
                    ColorPalette(selection: $draft.color)
                    NavigationLink {
                        SymbolPicker(selection: $draft.symbolName, color: draft.color)
                    } label: {
                        LabeledContent("Symbol") {
                            Image(systemName: draft.symbolName)
                                .foregroundStyle(draft.color.color)
                        }
                    }
                    photoRow
                    Picker("List", selection: $draft.listName) {
                        Text("None").tag("")
                        ForEach(availableListNames, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                    Button("New List…", systemImage: "plus") {
                        newListName = ""
                        isAddingList = true
                    }
                }

                Section {
                    Picker("Reminder", selection: $draft.reminderMinutes) {
                        ForEach(ReminderOption.options(isAllDay: draft.isAllDay), id: \.self) { minutes in
                            Text(ReminderOption.title(minutes: minutes, isAllDay: draft.isAllDay)).tag(minutes)
                        }
                    }
                    .onChange(of: draft.reminderMinutes) { _, minutes in
                        if minutes != nil {
                            Task { await requestReminderPermission() }
                        }
                    }
                } footer: {
                    if draft.reminderMinutes != nil {
                        Text("Reminders are sent by each of your devices with Timity.")
                    }
                }

                Section("Notes") {
                    TextField("Notes", text: $draft.notes, axis: .vertical)
                        .lineLimit(3...8)
                }
            }
            .navigationTitle(event == nil ? LocalizedStringKey("New Event") : LocalizedStringKey("Edit Event"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .cancel) {
                        if hasChanges { isConfirmingDiscard = true } else { dismiss() }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) {
                        save()
                    }
                    .disabled(draft.trimmedTitle.isEmpty)
                }
            }
            .confirmationDialog("Discard Changes?", isPresented: $isConfirmingDiscard) {
                Button("Discard Changes", role: .destructive) { dismiss() }
                Button("Keep Editing", role: .cancel) {}
            }
            .alert("New List", isPresented: $isAddingList) {
                TextField("Name", text: $newListName)
                Button("Add") {
                    let name = newListName.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !name.isEmpty { draft.listName = name }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Lists group events, such as Family, Work or Travel.")
            }
            .onChange(of: draft.isAllDay) { _, isAllDay in
                // Reminder choices differ for all-day events.
                if let minutes = draft.reminderMinutes,
                   !ReminderOption.options(isAllDay: isAllDay).contains(minutes) {
                    draft.reminderMinutes = 0
                }
            }
            .onChange(of: photoItem) { _, item in
                Task { await loadPhoto(item) }
            }
            .onAppear {
                guard !hasLoaded else { return }
                hasLoaded = true
                if let event {
                    draft = EventDraft(event)
                } else if let template {
                    draft = template
                } else {
                    isTitleFocused = true
                }
            }
        }
        .interactiveDismissDisabled(hasChanges)
        .presentationSizing(.form)
    }

    @ViewBuilder
    private var photoRow: some View {
        PhotosPicker(selection: $photoItem, matching: .images, photoLibrary: .shared()) {
            HStack {
                Label(draft.imageData == nil ? LocalizedStringKey("Add Photo") : LocalizedStringKey("Change Photo"), systemImage: "photo")
                Spacer()
                if isLoadingPhoto {
                    ProgressView()
                } else if let image = ImageProcessing.image(from: draft.imageData, maxPixelSize: 120) {
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 36, height: 36)
                        .clipShape(.rect(cornerRadius: 8, style: .continuous))
                }
            }
        }
        if draft.imageData != nil {
            Button("Remove Photo", systemImage: "trash", role: .destructive) {
                withAnimation {
                    draft.imageData = nil
                    photoItem = nil
                }
            }
        }
    }

    private var hasChanges: Bool {
        if let event {
            let original = EventDraft(event)
            return original.title != draft.title
                || original.date != draft.date
                || original.isAllDay != draft.isAllDay
                || original.recurrence != draft.recurrence
                || original.color != draft.color
                || original.symbolName != draft.symbolName
                || original.notes != draft.notes
                || original.reminderMinutes != draft.reminderMinutes
                || original.imageData != draft.imageData
                || original.timeZoneIdentifier != draft.timeZoneIdentifier
                || original.listName != draft.listName
                || original.isYearUnknown != draft.isYearUnknown
                || original.rule != draft.rule
                || original.showsProgress != draft.showsProgress
                || original.progressStart != draft.progressStart
        }
        return template != nil || !draft.trimmedTitle.isEmpty || draft.imageData != nil || !draft.notes.isEmpty
    }

    /// Lists used by any event, and the draft's own if it's new.
    private var availableListNames: [String] {
        let names = Set(listNames + [draft.listName]).filter { !$0.isEmpty }
        return names.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    /// Fills in the draft from the typed description.
    private func understand() async {
        let text = eventDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isUnderstanding else { return }
        isUnderstanding = true
        defer { isUnderstanding = false }
        let parsed = await parseDescription(text)
        withAnimation {
            if let title = parsed.title { draft.title = title }
            if let date = parsed.date { draft.date = date }
            if let isAllDay = parsed.isAllDay { draft.isAllDay = isAllDay }
            if let recurrence = parsed.recurrence { draft.recurrence = recurrence }
            if let symbol = parsed.symbolName { draft.symbolName = symbol }
        }
    }

    private func loadPhoto(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        isLoadingPhoto = true
        defer { isLoadingPhoto = false }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else { return }
            let prepared = ImageProcessing.preparedForStorage(data)
            withAnimation { draft.imageData = prepared }
        } catch {
            logger.error("Couldn't load the picked photo: \(error)")
        }
    }

    private func save() {
        onSave(draft.applied(to: event ?? EventSnapshot()))
        dismiss()
    }
}

/// A live preview of the event being edited.
private struct EditorPreview: View {
    let draft: EventDraft

    var body: some View {
        TimelineView(.everyMinute) { context in
            let countdown = Countdown(
                startDate: draft.isAllDay ? Calendar.autoupdatingCurrent.startOfDay(for: draft.date) : draft.date,
                isAllDay: draft.isAllDay,
                recurrence: draft.recurrence,
                now: context.date,
                calendar: .autoupdatingCurrent
            )

            HStack(spacing: 16) {
                EventBadge(symbolName: draft.symbolName, color: draft.color, size: 64)
                VStack(alignment: .leading, spacing: 4) {
                    Text(draft.trimmedTitle.isEmpty ? String(localized: "New Event") : draft.trimmedTitle)
                        .font(.headline)
                        .lineLimit(2)
                    Text(CountdownText.relativeDays(countdown))
                        .font(.title2.weight(.bold))
                        .fontDesign(.rounded)
                        .foregroundStyle(draft.color.color)
                        .contentTransition(.numericText())
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 8)
            .animation(.snappy, value: countdown.days)
            .animation(.snappy, value: draft.color)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Reminder choices, in minutes before the event — or for all-day events,
/// before 9:00 on the day.
enum ReminderOption {
    static func options(isAllDay: Bool) -> [Int?] {
        isAllDay
            ? [nil, 0, 1440, 2880, 10_080]
            : [nil, 0, 5, 15, 30, 60, 120, 1440, 2880, 10_080]
    }

    static func title(minutes: Int?, isAllDay: Bool) -> String {
        guard let minutes else { return String(localized: "None") }
        if isAllDay {
            let time = ReminderPlanner.allDayReminderTime().formatted(date: .omitted, time: .shortened)
            switch minutes {
            case 0: return String(localized: "On the day (\(time))")
            case 1440: return String(localized: "1 day before (\(time))")
            case 2880: return String(localized: "2 days before (\(time))")
            default: return String(localized: "1 week before (\(time))")
            }
        }
        switch minutes {
        case 0: return String(localized: "At time of event")
        default:
            let formatter = DateComponentsFormatter()
            formatter.unitsStyle = .full
            formatter.allowedUnits = [.weekOfMonth, .day, .hour, .minute]
            formatter.maximumUnitCount = 1
            let duration = formatter.string(from: TimeInterval(minutes * 60)) ?? ""
            return String(localized: "\(duration) before")
        }
    }
}

/// How an event repeats: how often, every how many periods, on which day, and in
/// which calendar.
private struct RepeatSection: View {
    @Binding var draft: EventDraft

    var body: some View {
        Section {
            Picker("Repeat", selection: $draft.recurrence.animation()) {
                ForEach(Recurrence.allCases) { recurrence in
                    Text(recurrence.name).tag(recurrence)
                }
            }

            if draft.recurrence != .never {
                Stepper(value: $draft.recurrenceInterval, in: 1...99) {
                    LabeledContent("Every") {
                        Text(RecurrenceText.frequency(draft.rule))
                            .monospacedDigit()
                    }
                }
            }

            if draft.availablePatterns.count > 1 {
                Picker("On", selection: $draft.recurrencePattern) {
                    ForEach(draft.availablePatterns) { pattern in
                        Text(RecurrenceText.pattern(pattern, frequency: draft.recurrence, start: draft.date)).tag(pattern)
                    }
                }
            }

            if draft.recurrence == .yearly, draft.isAllDay {
                Picker("Calendar", selection: $draft.eventCalendar) {
                    Text("Gregorian").tag(EventCalendar?.none)
                    ForEach(EventCalendar.allCases) { calendar in
                        Text(calendar.name).tag(Optional(calendar))
                    }
                }
                Toggle("Year Unknown", isOn: $draft.isYearUnknown)
            }
        } footer: {
            if let calendar = draft.eventCalendar, draft.recurrence == .yearly, draft.isAllDay {
                Text("Repeats on \(calendar.formatted(draft.date)) every year, as birthdays and holidays kept by this calendar do.")
            }
        }
        .onChange(of: draft.availablePatterns) { _, patterns in
            if !patterns.contains(draft.recurrencePattern) { draft.recurrencePattern = .sameDay }
        }
    }
}
