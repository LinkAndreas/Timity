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
                            Label("When Were You Born?", systemImage: "birthday.cake.fill")
                                .font(.headline)
                            Text("Life in Weeks draws every week of a life as a dot. Your birthday stays on your devices.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            DatePicker("Birthday", selection: $draftBirthday, in: ...Date.now, displayedComponents: .date)
                            Button {
                                withAnimation { birthday = draftBirthday }
                            } label: {
                                Text("Show My Weeks")
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
        .navigationTitle("Life in Weeks")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu("Options", systemImage: "ellipsis") {
                        Picker("Years Shown", selection: $lifeExpectancy) {
                            ForEach([80, 90, 100], id: \.self) { years in
                                Text("\(years) Years").tag(years)
                            }
                        }
                    Button("Change Birthday", systemImage: "birthday.cake") {
                        draftBirthday = birthday ?? draftBirthday
                        withAnimation { birthday = nil }
                    }
                }
                .disabled(birthday == nil)
            }
        }
    }

    private func content(_ life: LifeInWeeks) -> some View {
        VStack(spacing: 16) {
            ResultHero(color: color) {
                VStack(spacing: 0) {
                    Text("Week")
                        .font(.title3.weight(.semibold))
                        .opacity(0.9)
                    Text(life.weeksLived, format: .number)
                        .font(.system(size: 72, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
                .accessibilityElement(children: .combine)
                Text("of your life — \(life.progress.formatted(.percent.precision(.fractionLength(0)))) of \(lifeExpectancy) years")
                    .font(.subheadline.weight(.medium))
                    .multilineTextAlignment(.center)
            }

            Card {
                LifeInWeeksGrid(life: life, color: color.color)
                    .aspectRatio(CGFloat(LifeInWeeks.weeksPerRow) / CGFloat(life.years), contentMode: .fit)
                HStack {
                    Text("Each row is a year, each dot a week.")
                    Spacer()
                    Text("Age \(life.completedYears)")
                        .monospacedDigit()
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }
    }
}
