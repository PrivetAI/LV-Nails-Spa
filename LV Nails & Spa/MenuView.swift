import SwiftUI

struct MenuView: View {
    @EnvironmentObject private var schedule: Schedule
    @State private var booking: Treatment?

    var body: some View {
        Sheet {
            VStack(alignment: .leading, spacing: 7) {
                Kicker(text: "Eleven treatments")
                Text("The Menu")
                    .font(Ink.display(29))
                    .foregroundColor(Ink.letter)
                Text("From \(Salon.money(Salon.cheapestCents)). Add-ons book alongside any set.")
                    .font(Ink.copy(14))
                    .foregroundColor(Ink.letterSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ForEach(Salon.menu) { group in
                VStack(alignment: .leading, spacing: 0) {
                    Kicker(text: group.name)
                        .padding(.bottom, group.note == nil ? 6 : 5)

                    if let note = group.note {
                        Text(note)
                            .font(Ink.copy(13))
                            .foregroundColor(Ink.letterSoft)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.bottom, 6)
                    }

                    ForEach(Array(group.treatments.enumerated()), id: \.element.id) { index, treatment in
                        if index > 0 { Rule() }
                        Button(action: { booking = treatment }) {
                            TreatmentRow(treatment: treatment,
                                         opening: schedule.soonest(for: treatment.minutes))
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
        .sheet(item: $booking) { treatment in
            ReserveSheet(treatment: treatment).environmentObject(schedule)
        }
    }
}
