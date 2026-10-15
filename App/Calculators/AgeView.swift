import SwiftUI

/// An exact age, the next birthday and half-birthday, and a few fun facts —
/// down to the hour with a time of birth — and the age on any date, or the date
/// of any age.
struct AgeView: View {
    /// The user's own birthday, offered to set from here.
    @Binding var birthday: Date?
    @State private var birth = Calendar.autoupdatingCurrent.date(byAdding: .year, value: -30, to: .now) ?? .now
    @State private var includesTime = false
    /// The date to tell the age on.
    @State private var ageDate = Date.now
    /// The age to find the date of; `nil` for the next round one.
    @State private var targetAge: Int?

    /// The birth as counted: the start of its day unless a time is given.
    private var counted: Date {
        includesTime ? birth : Calendar.autoupdatingCurrent.startOfDay(for: birth)
    }

    var body: some View {
        TimelineView(.everyMinute) { context in
            let facts = AgeFacts(birth: counted, now: context.date)

            SideBySideForm {
                Section {
                    DatePicker("Birthday", selection: $birth, in: ...Date.now, displayedComponents: includesTime ? [.date, .hourAndMinute] : .date)
                    Toggle("Include Time of Birth", isOn: $includesTime.animation())
                } footer: {
                    if birthday == nil {
                        Button("Use as My Birthday") { birthday = Calendar.autoupdatingCurrent.startOfDay(for: birth) }
                    }
                }
            } trailing: {
                Section {
                    ResultHero(color: .pink) {
                        VStack(spacing: 0) {
                            Text(facts.age.years, format: .number)
                                .font(.system(size: 72, weight: .heavy, design: .rounded))
                                .contentTransition(.numericText())
                            Text(CountdownText.unit(.year, value: facts.age.years))
                                .font(.title3.weight(.semibold))
                        }
                        Group {
                            if includesTime {
                                Text("\(facts.age.months) \(CountdownText.unit(.month, value: facts.age.months)), \(facts.age.days) \(CountdownText.unit(.day, value: facts.age.days)), \(facts.age.hours) \(CountdownText.unit(.hour, value: facts.age.hours))")
                            } else {
                                Text("\(facts.age.months) \(CountdownText.unit(.month, value: facts.age.months)), \(facts.age.days) \(CountdownText.unit(.day, value: facts.age.days))")
                            }
                        }
                        .font(.headline)
                        .multilineTextAlignment(.center)
                    }
                    .accessibilityElement(children: .combine)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }

                Section {
                    LabeledContent("You Were Born on a", value: Calendar.autoupdatingCurrent.weekdaySymbols[facts.weekdayOfBirth - 1])
                    LabeledContent("Days Lived", value: facts.totalDays.formatted())
                    LabeledContent("Weeks Lived", value: facts.totalWeeks.formatted())
                    if includesTime {
                        LabeledContent("Hours Lived", value: Int(context.date.timeIntervalSince(counted) / 3600).formatted())
                    }
                    LabeledContent("Next Birthday") {
                        Text("\(facts.nextBirthday.formatted(date: .abbreviated, time: .omitted)) · \(CountdownText.relativeDays(Countdown(startDate: facts.nextBirthday, isAllDay: true, recurrence: .never, now: context.date, calendar: .autoupdatingCurrent)))")
                    }
                    LabeledContent("Half-Birthday", value: facts.nextHalfBirthday.formatted(date: .abbreviated, time: .omitted))
                }

                Section("How Old On a Date?") {
                    DatePicker("On", selection: $ageDate, in: counted..., displayedComponents: includesTime ? [.date, .hourAndMinute] : .date)
                    LabeledContent("Age") {
                        Text(verbatim: ageText(AgeFacts(birth: counted, now: ageDate).age))
                            .multilineTextAlignment(.trailing)
                    }
                }

                turningSection(facts: facts, now: context.date)

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

    /// When an age is reached — "When do I turn 40?"
    private func turningSection(facts: AgeFacts, now: Date) -> some View {
        let age = Binding(
            get: { targetAge ?? (facts.age.years / 10 + 1) * 10 },
            set: { targetAge = $0 }
        )
        let date = Calendar.autoupdatingCurrent.date(byAdding: .year, value: age.wrappedValue, to: counted) ?? counted
        let countdown = Countdown(startDate: date, isAllDay: !includesTime, recurrence: .never, now: now, calendar: .autoupdatingCurrent)

        return Section("When Do I Turn…") {
            Stepper(value: age, in: 1...130) {
                LabeledContent("Age", value: age.wrappedValue.formatted())
            }
            LabeledContent("On") {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(date, format: includesTime
                        ? Date.FormatStyle.dateTime.weekday(.abbreviated).day().month(.wide).year().hour().minute()
                        : Date.FormatStyle.dateTime.weekday(.abbreviated).day().month(.wide).year())
                    Text(CountdownText.relativeDays(countdown))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    /// "35 years, 2 months, 3 days".
    private func ageText(_ age: TimeBreakdown) -> String {
        String(localized: "\(age.years) \(CountdownText.unit(.year, value: age.years)), \(age.months) \(CountdownText.unit(.month, value: age.months)), \(age.days) \(CountdownText.unit(.day, value: age.days))")
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
