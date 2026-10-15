import SwiftUI
import UIKit

/// Brings birthdays and anniversaries from Contacts and upcoming events from
/// Calendar into Timity, choosing which ones.
struct ImportView: View {
    enum Source: Hashable {
        case contacts, calendar, holidays
    }

    enum LoadState {
        case loading
        case loaded([ImportCandidate])
        case denied
        case failed
    }

    /// The events there are, so ones already imported aren't offered again.
    let existingEvents: [EventSnapshot]
    /// Whose holidays to offer first.
    let defaultHolidayRegion: HolidayRegion?
    /// Birthdays and anniversaries; throws `ImportError.accessDenied` without access.
    let loadContacts: () async throws -> [ImportCandidate]
    /// Upcoming events; throws `ImportError.accessDenied` without access.
    let loadCalendar: () async throws -> [ImportCandidate]
    let onImport: ([EventSnapshot]) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var holidayRegion = HolidayRegion(locale: .autoupdatingCurrent) ?? .unitedStates
    @State private var source = Source.contacts
    @State private var state = LoadState.loading
    @State private var selection = Set<String>()
    @State private var importedCount = 0

    var body: some View {
        NavigationStack {
            content
                // The sources get a row of their own, so the toolbar keeps room for its title and buttons.
                .safeAreaBar(edge: .top) {
                    Picker("import.source", selection: $source) {
                        Text("import.contacts").tag(Source.contacts)
                        Text("common.calendar").tag(Source.calendar)
                        Text("import.holidays").tag(Source.holidays)
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 420)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
                .navigationTitle("import.import")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(role: .close) { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("import.add \(selection.count)") {
                            importSelection()
                        }
                        .disabled(selection.isEmpty)
                    }
                }
                .task(id: source) { await load() }
                .onChange(of: holidayRegion) { Task { await load() } }
                .onAppear { if let defaultHolidayRegion { holidayRegion = defaultHolidayRegion } }
                .sensoryFeedback(.success, trigger: importedCount)
        }
        .presentationSizing(.form)
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .denied:
            ContentUnavailableView {
                Label(source == .contacts ? LocalizedStringKey("import.noAccessToContacts") : LocalizedStringKey("import.noAccessToCalendar"),
                      systemImage: source == .contacts ? "person.crop.circle.badge.xmark" : "calendar.badge.exclamationmark")
            } description: {
                Text("import.allowAccessInSettingsTo")
            } actions: {
                Button("common.openSettings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
                .buttonStyle(.glassProminent)
            }
        case .failed:
            ContentUnavailableView("import.couldntLoad", systemImage: "exclamationmark.triangle", description: Text("import.pleaseTryAgain"))
        case let .loaded(candidates):
            if candidates.isEmpty {
                ContentUnavailableView(
                    source == .contacts ? LocalizedStringKey("import.noBirthdays") : LocalizedStringKey("import.noUpcomingEvents"),
                    systemImage: source == .contacts ? "birthday.cake" : "calendar",
                    description: Text(source == .contacts
                        ? LocalizedStringKey("import.addBirthdaysToYourContacts")
                        : LocalizedStringKey("import.eventsInTheNextTwelve"))
                )
            } else {
                list(candidates)
            }
        }
    }

    private func list(_ candidates: [ImportCandidate]) -> some View {
        List {
            if source == .holidays {
                Section {
                    Picker("import.country", selection: $holidayRegion) {
                        ForEach(HolidayRegion.allCases) { region in
                            Text(region.localizedName()).tag(region)
                        }
                    }
                }
            }
            Section {
                ForEach(candidates) { candidate in
                    let isImported = isAlreadyImported(candidate)
                    Button {
                        if selection.contains(candidate.id) {
                            selection.remove(candidate.id)
                        } else {
                            selection.insert(candidate.id)
                        }
                    } label: {
                        // Fixed text colours: inside a button, `.primary` and `.secondary` take the tint.
                        HStack(spacing: 12) {
                            EventBadge(symbolName: candidate.symbolName, color: candidate.color, size: 36)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(candidate.title)
                                    .foregroundStyle(Color.primary)
                                Text(dateText(candidate))
                                    .font(.caption)
                                    .foregroundStyle(Color.secondary)
                            }
                            Spacer()
                            if isImported {
                                Text("import.added")
                                    .font(.caption)
                                    .foregroundStyle(Color.secondary)
                            } else {
                                Image(systemName: selection.contains(candidate.id) ? "checkmark.circle.fill" : "circle")
                                    .font(.title3)
                                    .foregroundStyle(selection.contains(candidate.id) ? AnyShapeStyle(.tint) : AnyShapeStyle(Color.secondary))
                            }
                        }
                    }
                    .disabled(isImported)
                    .accessibilityAddTraits(selection.contains(candidate.id) ? .isSelected : [])
                }
            } header: {
                HStack {
                    Text(source == .contacts ? LocalizedStringKey("import.birthdaysAndAnniversaries") : LocalizedStringKey("import.nextTwelveMonths"))
                    Spacer()
                    let available = candidates.filter { !isAlreadyImported($0) }.map(\.id)
                    Button(selection.isSuperset(of: available) ? LocalizedStringKey("common.deselectAll") : LocalizedStringKey("common.selectAll")) {
                        if selection.isSuperset(of: available) {
                            selection.subtract(available)
                        } else {
                            selection.formUnion(available)
                        }
                    }
                    .font(.footnote)
                    .textCase(nil)
                }
            } footer: {
                if source == .contacts {
                    Text("import.birthdaysRepeatEveryYearFor")
                }
            }
        }
    }

    private func dateText(_ candidate: ImportCandidate) -> String {
        if candidate.isYearUnknown {
            return candidate.date.formatted(.dateTime.day().month(.wide))
        }
        return candidate.date.formatted(.shortDate(withTime: !candidate.isAllDay))
    }

    /// Whether an event with the same name already falls on the same day.
    private func isAlreadyImported(_ candidate: ImportCandidate) -> Bool {
        let calendar = Calendar.autoupdatingCurrent
        return existingEvents.contains { event in
            event.title == candidate.title && calendar.isDate(event.startDate(in: calendar), inSameDayAs: candidate.date)
        }
    }

    private func load() async {
        state = .loading
        selection = []
        do {
            let candidates: [ImportCandidate]
            switch source {
            case .contacts: candidates = try await loadContacts()
            case .calendar: candidates = try await loadCalendar()
            case .holidays: candidates = HolidayImport.candidates(region: holidayRegion)
            }
            state = .loaded(candidates)
        } catch ImportError.accessDenied {
            state = .denied
        } catch {
            logger.error("Couldn't load import candidates: \(error)")
            state = .failed
        }
    }

    private func importSelection() {
        guard case let .loaded(candidates) = state else { return }
        onImport(candidates.filter { selection.contains($0.id) }.map(\.event))
        importedCount += selection.count
        selection = []
        dismiss()
    }
}
