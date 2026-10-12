import SwiftUI

/// An exact age, the next birthday and half-birthday, and a few fun facts.
struct AgeView: View {
    /// The user's own birthday, offered to set from here.
    @Binding var birthday: Date?
    @State private var birth = Calendar.autoupdatingCurrent.date(byAdding: .year, value: -30, to: .now) ?? .now

    var body: some View {
        TimelineView(.everyMinute) { context in
            let facts = AgeFacts(birth: birth, now: context.date)

            Form {
                Section {
                    DatePicker("Born", selection: $birth, in: ...Date.now, displayedComponents: .date)
                } footer: {
                    if birthday == nil {
                        Button("Use as My Birthday") { birthday = birth }
                    }
                }

                Section {
                    ResultHero(color: .pink) {
                        VStack(spacing: 0) {
                            Text(facts.age.years, format: .number)
                                .font(.system(size: 72, weight: .heavy, design: .rounded))
                                .contentTransition(.numericText())
                            Text(CountdownText.unit(.year, value: facts.age.years))
                                .font(.title3.weight(.semibold))
                        }
                        Text("\(facts.age.months) \(CountdownText.unit(.month, value: facts.age.months)), \(facts.age.days) \(CountdownText.unit(.day, value: facts.age.days))")
                            .font(.headline)
                    }
                    .accessibilityElement(children: .combine)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }

                Section {
                    LabeledContent("Born on a", value: Calendar.autoupdatingCurrent.weekdaySymbols[facts.weekdayOfBirth - 1])
                    LabeledContent("Days Lived", value: facts.totalDays.formatted())
                    LabeledContent("Weeks Lived", value: facts.totalWeeks.formatted())
                    LabeledContent("Next Birthday") {
                        Text("\(facts.nextBirthday.formatted(date: .abbreviated, time: .omitted)) · \(CountdownText.relativeDays(Countdown(startDate: facts.nextBirthday, isAllDay: true, recurrence: .never, now: context.date, calendar: .autoupdatingCurrent)))")
                    }
                    LabeledContent("Half-Birthday", value: facts.nextHalfBirthday.formatted(date: .abbreviated, time: .omitted))
                }

                Section("On Other Planets") {
                    ForEach(facts.planetAges, id: \.planet) { planet, years in
                        LabeledContent(planetName(planet)) {
                            Text("\(years.formatted(.number.precision(.fractionLength(1)))) \(CountdownText.unit(.year, value: Int(years)))")
                                .monospacedDigit()
                        }
                    }
                }
            }
        }
        .navigationTitle("Exact Age")
        .onAppear {
            if let birthday { birth = birthday }
        }
    }

    private func planetName(_ planet: AgeFacts.Planet) -> LocalizedStringKey {
        switch planet {
        case .mercury: "Mercury"
        case .venus: "Venus"
        case .mars: "Mars"
        case .jupiter: "Jupiter"
        case .saturn: "Saturn"
        }
    }
}
