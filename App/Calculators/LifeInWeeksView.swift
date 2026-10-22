import SwiftUI

/// A life drawn in weeks, from the user's birthday: a reminder to make each one count.
struct LifeInWeeksView: View {
    @Binding var birthday: Date?
    /// The years drawn.
    @Binding var lifeExpectancy: Int
    let color: EventColor

    @State private var draftBirthday = Calendar.autoupdatingCurrent.date(byAdding: .year, value: -30, to: .now) ?? .now
    @Environment(\.usesResultColumn) private var usesResultColumn

    var body: some View {
        if usesResultColumn {
            LifeInWeeksColumns(birthday: $birthday, lifeExpectancy: $lifeExpectancy, draftBirthday: $draftBirthday, color: color)
        } else {
            LifeInWeeksSingleView(birthday: $birthday, lifeExpectancy: $lifeExpectancy, draftBirthday: $draftBirthday, color: color)
        }
    }
}

/// The birthday and the years drawn in the middle column, the weeks in the last.
private struct LifeInWeeksColumns: View {
    @Binding var birthday: Date?
    @Binding var lifeExpectancy: Int
    /// The day shown until a birthday is set.
    @Binding var draftBirthday: Date
    let color: EventColor

    var body: some View {
        Form {
            Section {
                DateRow(
                    title: "common.birthday",
                    date: Binding(get: { birthday ?? draftBirthday }, set: { birthday = $0 }),
                    includesTime: false,
                    range: Date.distantPast...Date.now,
                    showsReset: false
                )
                Picker("calc.lifeInWeeks.yearsShown", selection: $lifeExpectancy) {
                    ForEach([80, 90, 100], id: \.self) { years in
                        Text("calc.lifeInWeeks.years \(years)").tag(years)
                    }
                }
            } footer: {
                Text("calc.lifeInWeeks.lifeInWeeksDrawsEvery")
            }
        }
        .navigationTitle("common.lifeInWeeks")
        .resultColumn {
            ScrollView {
                Group {
                    if let birthday {
                        TimelineView(.everyMinute) { context in
                            LifeInWeeksSummary(
                                life: LifeInWeeks(birth: birthday, now: context.date, expectedYears: lifeExpectancy),
                                lifeExpectancy: lifeExpectancy,
                                color: color
                            )
                        }
                    } else {
                        ContentUnavailableView {
                            Label("calc.lifeInWeeks.whenWereYouBorn", systemImage: "birthday.cake.fill")
                        } description: {
                            Text("calc.lifeInWeeks.lifeInWeeksDrawsEvery")
                        }
                    }
                }
                .padding()
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
            }
        }
    }
}

/// Everything in one place, the weeks below the birthday, with the options in a menu.
private struct LifeInWeeksSingleView: View {
    @Binding var birthday: Date?
    @Binding var lifeExpectancy: Int
    /// The day picked before showing the weeks.
    @Binding var draftBirthday: Date
    let color: EventColor

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let birthday {
                    TimelineView(.everyMinute) { context in
                        LifeInWeeksSummary(
                            life: LifeInWeeks(birth: birthday, now: context.date, expectedYears: lifeExpectancy),
                            lifeExpectancy: lifeExpectancy,
                            color: color
                        )
                    }
                } else {
                    Card {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("calc.lifeInWeeks.whenWereYouBorn", systemImage: "birthday.cake.fill")
                                .font(.headline)
                            Text("calc.lifeInWeeks.lifeInWeeksDrawsEvery")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            DateRow(title: "common.birthday", date: $draftBirthday, includesTime: false, range: Date.distantPast...Date.now, showsReset: false)
                            Button {
                                withAnimation { birthday = draftBirthday }
                            } label: {
                                Text("calc.lifeInWeeks.showMyWeeks")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.glassProminent)
                            .controlSize(.large)
                        }
                    }
                }
            }
            .padding()
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("common.lifeInWeeks")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu("calc.lifeInWeeks.options", systemImage: "ellipsis") {
                    Picker("calc.lifeInWeeks.yearsShown", selection: $lifeExpectancy) {
                        ForEach([80, 90, 100], id: \.self) { years in
                            Text("calc.lifeInWeeks.years \(years)").tag(years)
                        }
                    }
                    Button("calc.lifeInWeeks.changeBirthday", systemImage: "birthday.cake") {
                        draftBirthday = birthday ?? draftBirthday
                        withAnimation { birthday = nil }
                    }
                }
                .menuIndicator(.hidden)
                .disabled(birthday == nil)
            }
        }
    }
}

/// The current week on a card, and every week of the life below it.
private struct LifeInWeeksSummary: View {
    let life: LifeInWeeks
    let lifeExpectancy: Int
    let color: EventColor

    var body: some View {
        VStack(spacing: 16) {
            ResultHero(color: color) {
                VStack(spacing: 0) {
                    Text("common.week2")
                        .font(.title3.weight(.semibold))
                        .opacity(0.9)
                    Text(verbatim: life.currentWeek.localizedNumber)
                        .scaledFont(size: 72, weight: .heavy, design: .rounded)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
                .accessibilityElement(children: .combine)
                Text("calc.lifeInWeeks.ofYourLifeOfYears \(life.progress.formatted(.percent.precision(.fractionLength(0)))) \(lifeExpectancy)")
                    .font(.subheadline.weight(.medium))
                    .multilineTextAlignment(.center)
            }

            Card {
                LifeInWeeksGrid(life: life, color: color.color)
                    #if os(macOS)
                    // A poster of a life, not a wall: at most this wide in a wide window.
                    .frame(maxWidth: 520)
                    .frame(maxWidth: .infinity)
                    #endif
                    .aspectRatio(CGFloat(LifeInWeeks.weeksPerRow) / CGFloat(life.years), contentMode: .fit)
                HStack {
                    Text("calc.lifeInWeeks.eachRowIsAYear")
                    Spacer()
                    Text("calc.lifeInWeeks.age \(life.completedYears)")
                        .monospacedDigit()
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }
    }
}
