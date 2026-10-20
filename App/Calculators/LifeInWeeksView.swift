import SwiftUI

/// A life drawn in weeks, from the user's birthday: a reminder to make each one count.
struct LifeInWeeksView: View {
    @Binding var birthday: Date?
    /// The years drawn.
    @Binding var lifeExpectancy: Int
    let color: EventColor

    @State private var draftBirthday = Calendar.autoupdatingCurrent.date(byAdding: .year, value: -30, to: .now) ?? .now

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let birthday {
                    TimelineView(.everyMinute) { context in
                        let life = LifeInWeeks(birth: birthday, now: context.date, expectedYears: lifeExpectancy)
                        content(life)
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

    private func content(_ life: LifeInWeeks) -> some View {
        VStack(spacing: 16) {
            ResultHero(color: color) {
                VStack(spacing: 0) {
                    Text("common.week2")
                        .font(.title3.weight(.semibold))
                        .opacity(0.9)
                    Text(life.currentWeek, format: .number)
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
