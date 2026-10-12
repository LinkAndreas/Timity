import SwiftUI

/// The date calculators.
enum CalculatorTool: String, CaseIterable, Identifiable, Hashable {
    case timeBetween, addSubtract, hours, timeZones, weekNumbers, age, lifeInWeeks

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .timeBetween: "Time Between"
        case .addSubtract: "Add & Subtract"
        case .weekNumbers: "Week Numbers"
        case .lifeInWeeks: "Life in Weeks"
        case .hours: "Hours"
        case .timeZones: "Time Zones"
        case .age: "Exact Age"
        }
    }

    var summary: LocalizedStringKey {
        switch self {
        case .timeBetween: "How long from one date to another, or since and until now."
        case .addSubtract: "Add years, months, weeks, days and hours to a date."
        case .weekNumbers: "The week of any date, and the dates of any week."
        case .lifeInWeeks: "Every week of your life, one dot each."
        case .hours: "Add up hours and minutes, and time worked between two times."
        case .timeZones: "The same moment in several cities, and when they're all awake."
        case .age: "Your exact age, next birthday and age on other planets."
        }
    }

    var systemImage: String {
        switch self {
        case .timeBetween: "arrow.left.and.right"
        case .addSubtract: "plusminus"
        case .weekNumbers: "calendar.day.timeline.left"
        case .lifeInWeeks: "square.grid.3x3.fill"
        case .hours: "clock.badge.checkmark"
        case .timeZones: "globe.europe.africa.fill"
        case .age: "birthday.cake.fill"
        }
    }

    var color: EventColor {
        switch self {
        case .timeBetween: .blue
        case .addSubtract: .purple
        case .weekNumbers: .teal
        case .lifeInWeeks: .indigo
        case .hours: .orange
        case .timeZones: .cyan
        case .age: .pink
        }
    }
}

/// The date calculators, listed beside the open one on iPad.
struct CalculatorsView<Content: View>: View {
    @Binding var selection: CalculatorTool?
    /// The open calculator.
    @ViewBuilder let tool: (CalculatorTool) -> Content

    var body: some View {
        NavigationSplitView {
            List(CalculatorTool.allCases, selection: $selection) { tool in
                NavigationLink(value: tool) {
                    HStack(spacing: 14) {
                        EventBadge(symbolName: tool.systemImage, color: tool.color, size: 44)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(tool.title)
                                .font(.headline)
                            Text(tool.summary)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .tag(tool)
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
            Button("Now") {
                withAnimation { date = .now }
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .controlSize(.small)
        }
    }
}
