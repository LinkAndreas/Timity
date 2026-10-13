import SwiftUI

/// Working days, leaving out weekends and public holidays: how many there are
/// between two dates, or which date a number of them leads to — for deadlines,
/// notice periods and deliveries.
struct WorkingDaysView: View {
    enum Question: Hashable {
        case between, deadline
    }

    /// Whose public holidays are left out.
    @Binding var holidayRegion: HolidayRegion?

    @State private var question = Question.between
    @State private var start = Calendar.autoupdatingCurrent.startOfDay(for: .now)
    @State private var end = Calendar.autoupdatingCurrent.date(byAdding: .month, value: 1, to: Calendar.autoupdatingCurrent.startOfDay(for: .now)) ?? .now
    @State private var count = 10

    var body: some View {
        SideBySideForm {
            Section {
                Picker("Question", selection: $question.animation()) {
                    Text("Count Workdays").tag(Question.between)
                    Text("Find a Deadline").tag(Question.deadline)
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }

            Section {
                DateRow(title: "From", date: $start, includesTime: false)
                switch question {
                case .between:
                    DateRow(title: "To", date: $end, includesTime: false)
                case .deadline:
                    Stepper(value: $count, in: 1...1000) {
                        LabeledContent("Workdays") {
                            TextField("Workdays", value: $count, format: .number)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .monospacedDigit()
                                .frame(maxWidth: 70)
                        }
                    }
                }
            }
        } trailing: {
            Section {
                Group {
                    switch question {
                    case .between: betweenResult
                    case .deadline: deadlineResult
                    }
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            if question == .between {
                Section {
                    let (from, to) = ordered
                    LabeledContent("Weekend Days", value: (DateMath.calendarDays(from: from, to: to) - DateMath.weekdays(between: from, and: to)).formatted())
                    if let holidayRegion {
                        LabeledContent("Public Holidays", value: (DateMath.weekdays(between: from, and: to) - DateMath.workingDays(between: from, and: to, region: holidayRegion)).formatted())
                    }
                }
            }

            Section {
                Picker("Skip Public Holidays In", selection: $holidayRegion) {
                    Text("None").tag(HolidayRegion?.none)
                    ForEach(HolidayRegion.allCases) { region in
                        Text(region.localizedName()).tag(Optional(region))
                    }
                }
            } footer: {
                Text(question == .between
                    ? "Weekends and nationwide public holidays don't count, and neither does the end date."
                    : "Counting starts on the next workday and skips weekends and nationwide public holidays.")
            }
        }
        .navigationTitle("Workdays")
        .scrollDismissesKeyboard(.interactively)
    }

    private var ordered: (Date, Date) {
        (min(start, end), max(start, end))
    }

    private var betweenResult: some View {
        let (from, to) = ordered
        let days = DateMath.workingDays(between: from, and: to, region: holidayRegion)
        return ResultHero(color: .brown) {
            VStack(spacing: 0) {
                Text(days, format: .number)
                    .font(.system(size: 72, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text("workdays")
                    .font(.title3.weight(.semibold))
            }
            .accessibilityElement(children: .combine)
        }
        .animation(.snappy, value: days)
    }

    @ViewBuilder
    private var deadlineResult: some View {
        if let date = DateMath.date(start, addingWorkingDays: max(1, count), region: holidayRegion) {
            ResultHero(color: .brown) {
                Text(date, format: .dateTime.weekday(.wide))
                    .font(.title3.weight(.semibold))
                    .opacity(0.9)
                Text(date, format: .dateTime.day().month(.wide).year())
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.6)
                    .contentTransition(.numericText())
                Text("\(DateMath.calendarDays(from: start, to: date).formatted()) calendar days")
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .glassEffect(.regular, in: .capsule)
            }
            .animation(.snappy, value: date)
        }
    }
}
