import SwiftUI

struct AppointmentsView: View {
    @EnvironmentObject private var schedule: Schedule
    @State private var pendingDrop: Reservation?

    var body: some View {
        Sheet {
            VStack(alignment: .leading, spacing: 7) {
                Kicker(text: "Your book")
                Text("Appointments")
                    .font(Ink.display(29))
                    .foregroundColor(Ink.letter)
            }

            if schedule.reservations.isEmpty {
                Card {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Nothing held yet")
                            .font(Ink.copy(16, .semibold))
                            .foregroundColor(Ink.letter)
                        Text("Pick something off the menu and the chair turns up here.")
                            .font(Ink.copy(14))
                            .foregroundColor(Ink.letterSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            if !schedule.upcoming.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Kicker(text: "Coming up")
                    ForEach(schedule.upcoming) { held in slip(held, isPast: false) }
                }
            }

            if !schedule.past.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Kicker(text: "Been and gone")
                    ForEach(schedule.past) { held in slip(held, isPast: true) }
                }
            }
        }
        .alert(item: $pendingDrop) { held in
            Alert(title: Text("Give up this chair?"),
                  message: Text("\(held.treatment?.name ?? "Booking") · \(Mark.day(held.day)) at \(Salon.clock(held.minutes))"),
                  primaryButton: .destructive(Text("Give it up")) { schedule.drop(held) },
                  secondaryButton: .cancel())
        }
    }

    private func slip(_ held: Reservation, isPast: Bool) -> some View {
        Card(lifted: !isPast) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(Salon.clock(held.minutes))
                            .font(Ink.figure(20, .bold))
                            .foregroundColor(isPast ? Ink.letterSoft : Ink.letter)
                        Text(Mark.day(held.day))
                            .font(Ink.figure(12))
                            .foregroundColor(Ink.letterSoft)
                    }
                    Spacer(minLength: 8)
                    if !isPast {
                        Button(action: { pendingDrop = held }) {
                            CloseMark(size: 15)
                                .frame(width: 32, height: 32)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }

                Rule()

                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(held.treatment?.name ?? "Booking")
                            .font(Ink.copy(15, .semibold))
                            .foregroundColor(isPast ? Ink.letterSoft : Ink.letter)
                        if !held.extras.isEmpty {
                            Text("with " + held.extras.map { $0.name }.joined(separator: ", "))
                                .font(Ink.copy(13))
                                .foregroundColor(Ink.letterSoft)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Text(Salon.length(held.totalMinutes))
                            .font(Ink.figure(11))
                            .foregroundColor(Ink.letterSoft)
                    }
                    Spacer(minLength: 8)
                    Text(Salon.money(held.totalCents))
                        .font(Ink.figure(15, .semibold))
                        .foregroundColor(isPast ? Ink.letterSoft : Ink.accent)
                }
            }
        }
    }
}
