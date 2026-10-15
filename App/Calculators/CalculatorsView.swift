import SwiftUI

/// The calculators, each answering one question.
nonisolated enum CalculatorTool: String, CaseIterable, Identifiable, Hashable {
    case timeBetween, addSubtract, workingDays, bridgeDays, weekNumbers, calendarConverter
    case hours, shift, timeZones, flight, sleep
    case age, milestones, lifeInWeeks

    nonisolated enum Category: CaseIterable, Identifiable {
        case dates, time, life

        var id: Self { self }

        var title: LocalizedStringKey {
            switch self {
            case .dates: "calculators.datesDeadlines"
            case .time: "calculators.hoursTimeZones"
            case .life: "calculators.youYourFamily"
            }
        }

        var tools: [CalculatorTool] {
            CalculatorTool.allCases.filter { $0.category == self }
        }
    }

    var id: String { rawValue }

    var category: Category {
        switch self {
        case .timeBetween, .addSubtract, .workingDays, .bridgeDays, .weekNumbers, .calendarConverter: .dates
        case .hours, .shift, .timeZones, .flight, .sleep: .time
        case .age, .milestones, .lifeInWeeks: .life
        }
    }

    var title: LocalizedStringKey {
        switch self {
        case .timeBetween: "common.timeBetween"
        case .addSubtract: "common.findADate"
        case .workingDays: "common.workdays"
        case .bridgeDays: "common.bridgeDays"
        case .weekNumbers: "common.weekNumber"
        case .calendarConverter: "common.calendarConverter"
        case .hours: "common.addUpTimes"
        case .shift: "common.workHours"
        case .timeZones: "common.timeZones"
        case .flight: "common.flightArrival"
        case .sleep: "common.bedtime"
        case .age: "common.exactAge"
        case .milestones: "common.milestones"
        case .lifeInWeeks: "common.lifeInWeeks"
        }
    }

    /// The question it answers.
    var summary: LocalizedStringKey {
        switch self {
        case .timeBetween: "calculators.howLongFromOneDate"
        case .addSubtract: "calculators.whichDateIs90Days"
        case .workingDays: "calculators.howManyWorkdaysUntilA"
        case .bridgeDays: "calculators.whichDaysOffGiveThe"
        case .weekNumbers: "calculators.whichWeekOfTheYear"
        case .calendarConverter: "calculators.whatsTheDateInThe"
        case .hours: "calculators.whatDoMyTimesAdd"
        case .shift: "calculators.howLongDidIWork"
        case .timeZones: "calculators.whatTimeIsItFor"
        case .flight: "calculators.whenDoILandIn"
        case .sleep: "calculators.whenShouldIGoTo"
        case .age: "calculators.howOldAmITo"
        case .milestones: "calculators.whenAmI10000"
        case .lifeInWeeks: "calculators.howManyWeeksHaveI"
        }
    }

    var systemImage: String {
        switch self {
        case .timeBetween: "arrow.left.and.right"
        case .addSubtract: "plusminus"
        case .workingDays: "briefcase.fill"
        case .bridgeDays: "beach.umbrella.fill"
        case .weekNumbers: "calendar.day.timeline.left"
        case .calendarConverter: "calendar.circle.fill"
        case .hours: "sum"
        case .shift: "clock.badge.checkmark"
        case .timeZones: "globe.europe.africa.fill"
        case .flight: "airplane.arrival"
        case .sleep: "bed.double.fill"
        case .age: "birthday.cake.fill"
        case .milestones: "sparkles"
        case .lifeInWeeks: "square.grid.3x3.fill"
        }
    }

    var color: EventColor {
        switch self {
        case .timeBetween: .blue
        case .addSubtract: .purple
        case .workingDays: .brown
        case .bridgeDays: .yellow
        case .weekNumbers: .teal
        case .calendarConverter: .mint
        case .hours: .orange
        case .shift: .green
        case .timeZones: .cyan
        case .flight: .blue
        case .sleep: .nightfall
        case .age: .pink
        case .milestones: .ember
        case .lifeInWeeks: .indigo
        }
    }
}

/// The calculators by topic, on iPhone; the iPad lists them in its sidebar.
struct CalculatorsView<Content: View>: View {
    @Binding var selection: CalculatorTool?
    /// The open calculator.
    @ViewBuilder let tool: (CalculatorTool) -> Content

    @Environment(\.verticalSizeClass) private var verticalSizeClass

    var body: some View {
        // A stack, not a split view: on its side, the largest iPhone counts as
        // wide, and a split view would neither show the calculator beside the
        // grid nor open it.
        NavigationStack {
            Group {
                // With the iPhone on its side, cards side by side, as in Events.
                if verticalSizeClass == .compact {
                    grid
                } else {
                    list
                }
            }
            .navigationTitle("common.calculate")
            .navigationDestination(item: $selection) { selected in
                tool(selected)
            }
        }
    }

    private var list: some View {
        List(selection: $selection) {
            ForEach(CalculatorTool.Category.allCases) { category in
                Section(category.title) {
                    ForEach(category.tools) { tool in
                        NavigationLink(value: tool) {
                            ToolRow(tool: tool)
                                .padding(.vertical, 2)
                        }
                        .tag(tool)
                    }
                }
            }
        }
    }

    private var grid: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                ForEach(CalculatorTool.Category.allCases) { category in
                    GridSection(category.title) {
                        ForEach(category.tools) { tool in
                            Button {
                                selection = tool
                            } label: {
                                ToolRow(tool: tool)
                                    .gridCard()
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding([.horizontal, .bottom])
        }
        .background(Color(.systemGroupedBackground))
    }
}

/// A calculator's symbol, name and the question it answers.
private struct ToolRow: View {
    let tool: CalculatorTool

    var body: some View {
        HStack(spacing: 14) {
            EventBadge(symbolName: tool.systemImage, color: tool.color, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(tool.title)
                    .font(.headline)
                Text(tool.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// A calculator's result on a coloured card, like an event's countdown.
struct ResultHero<Content: View>: View {
    let color: EventColor
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 14) {
            content
        }
        .foregroundStyle(.white)
        .padding(.vertical, 24)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .background(color.gradient, in: .rect(cornerRadius: 28, style: .continuous))
        .shadow(color: color.color.opacity(0.3), radius: 18, y: 10)
    }
}

/// A date and time picker with a button that resets it to today, or now.
struct DateRow: View {
    let title: LocalizedStringKey
    @Binding var date: Date
    let includesTime: Bool

    var body: some View {
        // On one line when it fits; with a date and a time on a narrow screen, the
        // pickers move below the title so nothing has to squeeze.
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                Text(title)
                    .fixedSize()
                Spacer(minLength: 0)
                picker
                resetButton
            }
            VStack(alignment: .trailing, spacing: 8) {
                Text(title)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 12) {
                    picker
                    resetButton
                }
            }
        }
    }

    /// Its natural size, so it keeps the long date format.
    private var picker: some View {
        DatePicker(title, selection: $date, displayedComponents: includesTime ? [.date, .hourAndMinute] : [.date])
            .labelsHidden()
            .fixedSize()
    }

    /// Always there, at the end of the row, so every row lines up and nothing moves;
    /// dimmed while the date already is today, which it also tells at a glance.
    private var resetButton: some View {
        let label: LocalizedStringKey = includesTime ? "common.setToNow" : "common.setToToday"
        return Button(label, systemImage: "arrow.counterclockwise") {
            withAnimation { date = includesTime ? .now : Calendar.autoupdatingCurrent.startOfDay(for: .now) }
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
        .fontWeight(.semibold)
        .frame(minWidth: 28, minHeight: 44)
        .contentShape(.rect)
        .disabled(isNow)
        .help(Text(label))
    }

    private var isNow: Bool {
        includesTime
            ? abs(date.timeIntervalSinceNow) < 60
            : Calendar.autoupdatingCurrent.isDateInToday(date)
    }
}
