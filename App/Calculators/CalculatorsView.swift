import SwiftUI

/// The calculators, each answering one question.
enum CalculatorTool: String, CaseIterable, Identifiable, Hashable {
    case timeBetween, addSubtract, workingDays, weekNumbers
    case hours, shift, timeZones, sleep
    case age, lifeInWeeks, dueDate

    enum Category: CaseIterable, Identifiable {
        case dates, time, life

        var id: Self { self }

        var title: LocalizedStringKey {
            switch self {
            case .dates: "Dates"
            case .time: "Time"
            case .life: "Life"
            }
        }

        var tools: [CalculatorTool] {
            CalculatorTool.allCases.filter { $0.category == self }
        }
    }

    var id: String { rawValue }

    var category: Category {
        switch self {
        case .timeBetween, .addSubtract, .workingDays, .weekNumbers: .dates
        case .hours, .shift, .timeZones, .sleep: .time
        case .age, .lifeInWeeks, .dueDate: .life
        }
    }

    var title: LocalizedStringKey {
        switch self {
        case .timeBetween: "Days Between"
        case .addSubtract: "Add & Subtract"
        case .workingDays: "Working Days"
        case .weekNumbers: "Week Numbers"
        case .hours: "Add Up Hours"
        case .shift: "Hours Worked"
        case .timeZones: "Time Zones"
        case .sleep: "Sleep"
        case .age: "Exact Age"
        case .lifeInWeeks: "Life in Weeks"
        case .dueDate: "Due Date"
        }
    }

    /// The question it answers.
    var summary: LocalizedStringKey {
        switch self {
        case .timeBetween: "How long from one date to another?"
        case .addSubtract: "What date is it 90 days from now?"
        case .workingDays: "How many working days until then?"
        case .weekNumbers: "Which week is it?"
        case .hours: "What do these durations add up to?"
        case .shift: "How long did I work, and what did I earn?"
        case .timeZones: "What time is it there?"
        case .sleep: "When should I go to bed?"
        case .age: "How old am I, exactly?"
        case .lifeInWeeks: "How many weeks have I lived?"
        case .dueDate: "When is the baby due?"
        }
    }

    var systemImage: String {
        switch self {
        case .timeBetween: "arrow.left.and.right"
        case .addSubtract: "plusminus"
        case .workingDays: "briefcase.fill"
        case .weekNumbers: "calendar.day.timeline.left"
        case .hours: "sum"
        case .shift: "clock.badge.checkmark"
        case .timeZones: "globe.europe.africa.fill"
        case .sleep: "bed.double.fill"
        case .age: "birthday.cake.fill"
        case .lifeInWeeks: "square.grid.3x3.fill"
        case .dueDate: "figure.and.child.holdinghands"
        }
    }

    var color: EventColor {
        switch self {
        case .timeBetween: .blue
        case .addSubtract: .purple
        case .workingDays: .brown
        case .weekNumbers: .teal
        case .hours: .orange
        case .shift: .green
        case .timeZones: .cyan
        case .sleep: .nightfall
        case .age: .pink
        case .lifeInWeeks: .indigo
        case .dueDate: .blossom
        }
    }
}

/// The calculators by topic, listed beside the open one on iPad.
struct CalculatorsView<Content: View>: View {
    @Binding var selection: CalculatorTool?
    /// The open calculator.
    @ViewBuilder let tool: (CalculatorTool) -> Content

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                ForEach(CalculatorTool.Category.allCases) { category in
                    Section(category.title) {
                        ForEach(category.tools) { tool in
                            NavigationLink(value: tool) {
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
                                .padding(.vertical, 2)
                            }
                            .tag(tool)
                        }
                    }
                }
            }
            .navigationTitle("Calculate")
        } detail: {
            NavigationStack {
                if let selection {
                    tool(selection)
                } else {
                    ContentUnavailableView("Choose a Calculator", systemImage: "plus.forwardslash.minus")
                }
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

/// A date and time picker with a button that resets it to now.
struct DateRow: View {
    let title: LocalizedStringKey
    @Binding var date: Date
    let includesTime: Bool

    var body: some View {
        HStack {
            DatePicker(title, selection: $date, displayedComponents: includesTime ? [.date, .hourAndMinute] : [.date])
            Button(includesTime ? LocalizedStringKey("Now") : LocalizedStringKey("Today")) {
                withAnimation { date = includesTime ? .now : Calendar.autoupdatingCurrent.startOfDay(for: .now) }
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .controlSize(.small)
        }
    }
}
