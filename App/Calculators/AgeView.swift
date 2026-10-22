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
    @Environment(\.usesResultColumn) private var usesResultColumn

    /// The birth as counted: the start of its day unless a time is given.
    private var counted: Date {
        includesTime ? birth : Calendar.autoupdatingCurrent.startOfDay(for: birth)
    }

    var body: some View {
        TimelineView(.everyMinute) { context in
            let facts = AgeFacts(birth: counted, now: context.date)

            SideBySideForm {
                Section {
                    DateRow(title: "common.birthday", date: $birth, includesTime: includesTime, range: Date.distantPast...Date.now, showsReset: false)
                    Toggle("calc.age.includeTimeOfBirth", isOn: $includesTime.animation())
                } footer: {
                    if birthday == nil {
                        Button("calc.age.useAsMyBirthday") { birthday = Calendar.autoupdatingCurrent.startOfDay(for: birth) }
                    }
                }

                // With a column for the answer, the two questions that are asked here too
                // stay with the birthday, each with its own short answer.
                if usesResultColumn {
                    AgeQuestions(ageDate: $ageDate, targetAge: $targetAge, birth: counted, includesTime: includesTime, currentYears: facts.age.years, now: context.date)
                }
            } trailing: {
                Section {
                    ResultHero(color: .pink) {
                        VStack(spacing: 0) {
                            Text(facts.age.years, format: .number)
                                .scaledFont(size: 72, weight: .heavy, design: .rounded)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                                .contentTransition(.numericText())
                            Text(CountdownText.unit(.year, value: facts.age.years))
                                .font(.title3.weight(.semibold))
                        }
                        // "and 5 months, 12 days": the rest of the same age, not a second one; on
                        // the birthday itself, nothing to add.
                        if facts.age.months > 0 || facts.age.days > 0 || (includesTime && facts.age.hours > 0) {
                            Group {
                                if includesTime {
                                    Text("calc.age.and \("\(facts.age.months) \(CountdownText.unit(.month, value: facts.age.months)), \(facts.age.days) \(CountdownText.unit(.day, value: facts.age.days)), \(facts.age.hours) \(CountdownText.unit(.hour, value: facts.age.hours))")")
                                } else {
                                    Text("calc.age.and \("\(facts.age.months) \(CountdownText.unit(.month, value: facts.age.months)), \(facts.age.days) \(CountdownText.unit(.day, value: facts.age.days))")")
                                }
                            }
                            .font(.headline)
                            .multilineTextAlignment(.center)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }

                Section {
                    LabeledContent("calc.age.youWereBornOnA", value: Calendar.autoupdatingCurrent.weekdaySymbols[facts.weekdayOfBirth - 1])
                    LabeledContent("calc.age.nextBirthday") {
                        Text("\(facts.nextBirthday.formatted(.shortDate())) · \(CountdownText.relativeDays(Countdown(startDate: facts.nextBirthday, isAllDay: true, recurrence: .never, now: context.date, calendar: .autoupdatingCurrent)))")
                    }
                    LabeledContent("calc.age.halfBirthday", value: facts.nextHalfBirthday.formatted(.shortDate()))
                }

                // The age in each unit on its own, as an event shows the time since it.
                Section("eventDetail.totalTime") {
                    TotalsGrid(totals: DateMath.totals(between: counted, and: context.date), tint: EventColor.pink.color)
                }

                if !usesResultColumn {
                    AgeQuestions(ageDate: $ageDate, targetAge: $targetAge, birth: counted, includesTime: includesTime, currentYears: facts.age.years, now: context.date)
                }

                Section("calc.age.onOtherPlanets") {
                    ForEach(facts.planetAges, id: \.planet) { planet, years in
                        LabeledContent(planetName(planet)) {
                            Text("\(years.formatted(.number.precision(.fractionLength(1)))) \(CountdownText.unit(.year, value: Int(years)))")
                                .monospacedDigit()
                        }
                    }
                }
            }
        }
        .navigationTitle("common.exactAge")
        .onAppear {
            if let birthday { birth = birthday }
        }
    }

    private func planetName(_ planet: AgeFacts.Planet) -> LocalizedStringKey {
        switch planet {
        case .mercury: "calc.age.mercury"
        case .venus: "calc.age.venus"
        case .mars: "calc.age.mars"
        case .jupiter: "calc.age.jupiter"
        case .saturn: "calc.age.saturn"
        }
    }
}

/// The age on a given date, and the date of a given age.
private struct AgeQuestions: View {
    @Binding var ageDate: Date
    @Binding var targetAge: Int?
    let birth: Date
    let includesTime: Bool
    let currentYears: Int
    let now: Date

    var body: some View {
        Section("calc.age.howOldOnADate") {
            DateRow(title: "common.on", date: $ageDate, includesTime: includesTime, range: birth...max(birth, Date.distantFuture))
            LabeledContent("calc.age.age") {
                Text(verbatim: ageText(AgeFacts(birth: birth, now: ageDate).age))
                    .multilineTextAlignment(.trailing)
            }
        }

        AgeTurningSection(
            targetAge: $targetAge,
            currentYears: currentYears,
            birth: birth,
            includesTime: includesTime,
            now: now
        )
    }

    /// "35 years, 2 months, 3 days".
    private func ageText(_ age: TimeBreakdown) -> String {
        String(localized: "\(age.years) \(CountdownText.unit(.year, value: age.years)), \(age.months) \(CountdownText.unit(.month, value: age.months)), \(age.days) \(CountdownText.unit(.day, value: age.days))")
    }
}

/// When an age is reached — "When do I turn 40?" The next round age until one is chosen.
private struct AgeTurningSection: View {
    @Binding var targetAge: Int?
    let currentYears: Int
    let birth: Date
    let includesTime: Bool
    let now: Date

    var body: some View {
        let age = Binding(
            get: { targetAge ?? (currentYears / 10 + 1) * 10 },
            set: { targetAge = $0 }
        )
        let date = Calendar.autoupdatingCurrent.date(byAdding: .year, value: age.wrappedValue, to: birth) ?? birth
        let countdown = Countdown(startDate: date, isAllDay: !includesTime, recurrence: .never, now: now, calendar: .autoupdatingCurrent)

        Section("calc.age.whenDoITurn") {
            NumberStepperRow(title: "calc.age.age", value: age, range: 1...130, valueText: age.wrappedValue.formatted())
            LabeledContent("common.on") {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(date, format: .shortDate(withTime: includesTime))
                    Text(CountdownText.relativeDays(countdown))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
