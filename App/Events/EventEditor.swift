import PhotosUI
import SwiftUI

/// The values being edited, kept apart from the event so Cancel leaves it untouched.
nonisolated struct EventDraft {
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
                    EditorPreview(draft: draft, event: event)
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
                            Label("editor.startFromATemplate", systemImage: "square.grid.2x2")
                        }
                    }
                }

                if event == nil {
                    Section {
                        HStack {
                            TextField("editor.describeIt", text: $eventDescription, prompt: Text("editor.mumsBirthdayOn3March"))
                                .submitLabel(.go)
                                .onSubmit { Task { await understand() } }
                            if isUnderstanding {
                                ProgressView()
                            } else {
                                Button("editor.fillIn", systemImage: "sparkles") {
                                    Task { await understand() }
                                }
                                .labelStyle(.iconOnly)
                                .disabled(eventDescription.trimmingCharacters(in: .whitespaces).isEmpty)
                            }
                        }
                    } footer: {
                        Text("editor.typeAnEventInYour")
                    }
                }

                Section {
                    TextField("common.name", text: $draft.title)
                        .font(.title3.weight(.semibold))
                        .focused($isTitleFocused)
                        .submitLabel(.done)
                }

                Section {
                    Toggle("common.allDay", isOn: $draft.isAllDay.animation())
                    DatePicker(
                        "common.date",
                        selection: $draft.date,
                        displayedComponents: draft.isAllDay ? [.date] : [.date, .hourAndMinute]
                    )
                    // The date and time as they read where the event happens.
                    .environment(\.timeZone, draft.isAllDay ? .autoupdatingCurrent : (draft.timeZone ?? .autoupdatingCurrent))
                    if !draft.isAllDay {
                        NavigationLink {
                            TimeZonePicker(selection: $draft.timeZoneIdentifier)
                        } label: {
                            LabeledContent("common.timeZone") {
                                Text(draft.timeZone.map(TimeZonePicker.name(for:)) ?? String(localized: "common.localTime"))
                            }
                        }
                    }
                } footer: {
                    if draft.recurrence == .yearly {
                        Text("editor.perfectForBirthdaysAndAnniversaries")
                    }
                }

                RepeatSection(draft: $draft)

                Section {
                    Toggle("editor.showProgress", isOn: $draft.showsProgress.animation())
                    if draft.showsProgress, draft.recurrence == .never {
                        DatePicker(
                            "editor.progressFrom",
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
                            ? LocalizedStringKey("editor.showsHowMuchOfThe")
                            : LocalizedStringKey("editor.showsHowMuchOfThe2"))
                    }
                }

                Section("common.appearance") {
                    ColorPalette(selection: $draft.color)
                    NavigationLink {
                        SymbolPicker(selection: $draft.symbolName, color: draft.color)
                    } label: {
                        LabeledContent("common.symbol") {
                            Image(systemName: draft.symbolName)
                                .foregroundStyle(draft.color.color)
                        }
                    }
                    photoRow
                    Picker("common.list", selection: $draft.listName) {
                        Text("common.none").tag("")
                        ForEach(availableListNames, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                    Button("editor.newList", systemImage: "plus") {
                        newListName = ""
                        isAddingList = true
                    }
                }

                Section {
                    Picker("common.reminder", selection: $draft.reminderMinutes) {
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
                        Text("editor.remindersAreSentByEach")
                    }
                }

                Section("common.notes") {
                    TextField("common.notes", text: $draft.notes, axis: .vertical)
                        .lineLimit(3...8)
                }
            }
            .navigationTitle(event == nil ? LocalizedStringKey("common.newEvent") : LocalizedStringKey("editor.editEvent"))
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
            .confirmationDialog("editor.discardChanges", isPresented: $isConfirmingDiscard) {
                Button("editor.discardChanges2", role: .destructive) { dismiss() }
                Button("editor.keepEditing", role: .cancel) {}
            }
            .alert("editor.newList2", isPresented: $isAddingList) {
                TextField("common.name", text: $newListName)
                Button("editor.add") {
                    let name = newListName.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !name.isEmpty { draft.listName = name }
                }
                Button("editor.cancel", role: .cancel) {}
            } message: {
                Text("editor.listsGroupEventsSuchAs")
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
                Label(draft.imageData == nil ? LocalizedStringKey("editor.addPhoto") : LocalizedStringKey("editor.changePhoto"), systemImage: "photo")
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
            Button("editor.removePhoto", systemImage: "trash", role: .destructive) {
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
    /// The event being edited, whose date added is where progress starts by default.
    let event: EventSnapshot?

    var body: some View {
        TimelineView(.everyMinute) { context in
            let countdown = Countdown(
                startDate: draft.isAllDay ? Calendar.autoupdatingCurrent.startOfDay(for: draft.date) : draft.date,
                isAllDay: draft.isAllDay,
                recurrence: draft.recurrence,
                now: context.date,
                calendar: .autoupdatingCurrent
            )
            // The event as it would be saved, for the progress from its chosen or default start.
            let progressed = draft.showsProgress ? draft.applied(to: event ?? EventSnapshot()).countdown(at: context.date) : nil

            HStack(spacing: 16) {
                EventBadge(symbolName: draft.symbolName, color: draft.color, size: 64)
                VStack(alignment: .leading, spacing: 4) {
                    Text(draft.trimmedTitle.isEmpty ? String(localized: "common.newEvent") : draft.trimmedTitle)
                        .font(.headline)
                        .lineLimit(2)
                    Text(CountdownText.relativeDays(countdown))
                        .font(.title2.weight(.bold))
                        .fontDesign(.rounded)
                        .foregroundStyle(draft.color.color)
                        .contentTransition(.numericText())
                    if let progressed, let progress = progressed.progress, progressed.direction == .future {
                        CompactEventProgress(progress: progress, fill: draft.color.color, track: draft.color.color.opacity(0.18))
                            .padding(.top, 2)
                            .transition(.opacity)
                    }
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
nonisolated enum ReminderOption {
    static func options(isAllDay: Bool) -> [Int?] {
        isAllDay
            ? [nil, 0, 1440, 2880, 10_080]
            : [nil, 0, 5, 15, 30, 60, 120, 1440, 2880, 10_080]
    }

    static func title(minutes: Int?, isAllDay: Bool) -> String {
        guard let minutes else { return String(localized: "common.none") }
        if isAllDay {
            let time = ReminderPlanner.allDayReminderTime().formatted(date: .omitted, time: .shortened)
            switch minutes {
            case 0: return String(localized: "editor.onTheDay \(time)")
            case 1440: return String(localized: "editor.1DayBefore \(time)")
            case 2880: return String(localized: "editor.2DaysBefore \(time)")
            default: return String(localized: "editor.1WeekBefore \(time)")
            }
        }
        switch minutes {
        case 0: return String(localized: "editor.atTimeOfEvent")
        default:
            let formatter = DateComponentsFormatter()
            formatter.unitsStyle = .full
            formatter.allowedUnits = [.weekOfMonth, .day, .hour, .minute]
            formatter.maximumUnitCount = 1
            let duration = formatter.string(from: TimeInterval(minutes * 60)) ?? ""
            return String(localized: "editor.before \(duration)")
        }
    }
}

/// How an event repeats: how often, every how many periods, on which day, and in
/// which calendar.
private struct RepeatSection: View {
    @Binding var draft: EventDraft

    var body: some View {
        Section {
            Picker("editor.repeat", selection: $draft.recurrence.animation()) {
                ForEach(Recurrence.allCases) { recurrence in
                    Text(recurrence.name).tag(recurrence)
                }
            }

            if draft.recurrence != .never {
                Stepper(value: $draft.recurrenceInterval, in: 1...99) {
                    LabeledContent("common.every") {
                        Text(RecurrenceText.frequency(draft.rule))
                            .monospacedDigit()
                    }
                }
            }

            if draft.availablePatterns.count > 1 {
                Picker("common.on", selection: $draft.recurrencePattern) {
                    ForEach(draft.availablePatterns) { pattern in
                        Text(RecurrenceText.pattern(pattern, frequency: draft.recurrence, start: draft.date)).tag(pattern)
                    }
                }
            }

            if draft.recurrence == .yearly, draft.isAllDay {
                Picker("common.calendar", selection: $draft.eventCalendar) {
                    Text("editor.gregorian").tag(EventCalendar?.none)
                    ForEach(EventCalendar.allCases) { calendar in
                        Text(calendar.name).tag(Optional(calendar))
                    }
                }
                Toggle("editor.yearUnknown", isOn: $draft.isYearUnknown)
            }
        } footer: {
            if let calendar = draft.eventCalendar, draft.recurrence == .yearly, draft.isAllDay {
                Text("editor.repeatsOnEveryYearAs \(calendar.formatted(draft.date))")
            }
        }
        .onChange(of: draft.availablePatterns) { _, patterns in
            if !patterns.contains(draft.recurrencePattern) { draft.recurrencePattern = .sameDay }
        }
    }
}
