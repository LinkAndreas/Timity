import PhotosUI
import SwiftData
import SwiftUI
import WidgetKit

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

    init() {}

    var timeZone: TimeZone? {
        timeZoneIdentifier.flatMap(TimeZone.init(identifier:))
    }

    init(_ event: Event) {
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
    }

    var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func apply(to event: Event) {
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
        event.modifiedAt = .now
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
    let event: Event?
    /// Values for a new event, e.g. from a received file.
    var template: EventDraft? = nil
    let onSave: (Event) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var draft = EventDraft()
    @State private var photoItem: PhotosPickerItem?
    @State private var isLoadingPhoto = false
    @State private var isConfirmingDiscard = false
    @State private var hasLoaded = false
    @State private var eventDescription = ""
    @State private var isUnderstanding = false
    @State private var isAddingList = false
    @State private var newListName = ""
    @Query private var allEvents: [Event]
    @FocusState private var isTitleFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    EditorPreview(draft: draft)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
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
                    Picker("Repeat", selection: $draft.recurrence) {
                        ForEach(Recurrence.allCases) { recurrence in
                            Text(recurrence.name).tag(recurrence)
                        }
                    }
                    if draft.isAllDay, draft.recurrence == .yearly {
                        Toggle("Year Unknown", isOn: $draft.isYearUnknown)
                    }
                } footer: {
                    if draft.recurrence == .yearly {
                        Text("Perfect for birthdays and anniversaries: Timity counts down to the next one and shows how many years it marks.")
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
                        ForEach(listNames, id: \.self) { name in
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
                            Task { await ReminderScheduler.requestAuthorization() }
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
        }
        return template != nil || !draft.trimmedTitle.isEmpty || draft.imageData != nil || !draft.notes.isEmpty
    }

    /// Lists used by any event, and the draft's own if it's new.
    private var listNames: [String] {
        let names = Set(allEvents.map(\.listName) + [draft.listName]).filter { !$0.isEmpty }
        return names.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    /// Fills in the draft from the typed description.
    private func understand() async {
        let text = eventDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isUnderstanding else { return }
        isUnderstanding = true
        defer { isUnderstanding = false }
        let parsed = await EventTextParser.parse(text)
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
        let saved: Event
        if let event {
            saved = event
        } else {
            saved = Event(title: draft.trimmedTitle, date: draft.date)
            modelContext.insert(saved)
        }
        draft.apply(to: saved)
        do {
            try modelContext.save()
        } catch {
            logger.error("Couldn't save the event: \(error)")
        }
        WidgetCenter.shared.reloadAllTimelines()
        Task { await ReminderScheduler.reschedule(container: modelContext.container) }
        onSave(saved)
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
            let time = ReminderScheduler.allDayReminderTime.formatted(date: .omitted, time: .shortened)
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
