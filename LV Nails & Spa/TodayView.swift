import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var schedule: Schedule
    let openMenu: () -> Void

    @State private var now = Date()
    @State private var booking: Treatment?

    private let tick = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        Sheet {
            header
            soonest
            if let next = schedule.upcoming.first { yours(next) }
            wall
            signatures
        }
        .onReceive(tick) { now = $0 }
        .sheet(item: $booking) { treatment in
            ReserveSheet(treatment: treatment).environmentObject(schedule)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 9) {
            Kicker(text: "\(Salon.city), \(Salon.region)")
            Text(Salon.name)
                .font(Ink.display(33))
                .foregroundColor(Ink.letter)
                .fixedSize(horizontal: false, vertical: true)
            DoorLine(state: DoorState.now(now))
        }
    }

    private var lead: Treatment { Salon.treatment("mani-gel") ?? Salon.allTreatments[0] }

    private var soonest: some View {
        Card(lifted: true) {
            VStack(alignment: .leading, spacing: 14) {
                Kicker(text: "Next free chair")

                if let opening = schedule.soonest(for: lead.minutes) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(label(opening.day, opening.time))
                            .font(Ink.display(25))
                            .foregroundColor(Ink.letter)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("\(lead.name) · \(Salon.money(lead.priceCents)) · \(Salon.length(lead.minutes))")
                            .font(Ink.copy(14))
                            .foregroundColor(Ink.letterSoft)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("\(opening.time.chairsFree) of \(Salon.chairCount) chairs open then")
                            .font(Ink.figure(11))
                            .foregroundColor(Ink.accent)
                    }
                    FilledButton(title: "Hold This Chair") { booking = lead }
                } else {
                    Text("Full for the next fortnight.")
                        .font(Ink.copy(15))
                        .foregroundColor(Ink.letter)
                    QuietButton(title: "See the whole menu", action: openMenu)
                }
            }
        }
    }

    private func label(_ day: Date, _ time: ChairTime) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return "Today at \(time.label)" }
        if calendar.isDateInTomorrow(day) { return "Tomorrow at \(time.label)" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return "\(formatter.string(from: day)) at \(time.label)"
    }

    private func yours(_ held: Reservation) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 9) {
                Kicker(text: "Your chair", tint: Ink.accent)
                Text(held.treatment?.name ?? "Booked")
                    .font(Ink.copy(17, .semibold))
                    .foregroundColor(Ink.letter)
                Text("\(Mark.day(held.day)) at \(Salon.clock(held.minutes))")
                    .font(Ink.figure(13))
                    .foregroundColor(Ink.letterSoft)
            }
        }
    }

    private var wall: some View {
        VStack(alignment: .leading, spacing: 10) {
            Kicker(text: "The colour wall")
            ColourWall()
                .frame(height: 74)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(Ink.cardLifted)
                .overlay(
                    RoundedRectangle(cornerRadius: Span.corner)
                        .stroke(Ink.rule, lineWidth: Span.rule)
                )
                .clipShape(RoundedRectangle(cornerRadius: Span.corner))
            Text("Restocked every season. Bring a photo and the \(Salon.techNoun) will match it.")
                .font(Ink.copy(13))
                .foregroundColor(Ink.letterSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var signatures: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Kicker(text: "What people book")
                Spacer()
                Button(action: openMenu) {
                    Text("Full menu")
                        .font(Ink.figure(11, .semibold))
                        .foregroundColor(Ink.accent)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.bottom, 6)

            ForEach(Array(featured.enumerated()), id: \.element.id) { index, treatment in
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

    private var featured: [Treatment] {
        ["mani-gel", "pedi-deluxe", "polish-change"].compactMap { Salon.treatment($0) }
    }
}

struct DoorLine: View {
    let state: DoorState

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(state.isOpen ? Ink.accent : Ink.letterSoft.opacity(0.6))
                .frame(width: 7, height: 7)
            Text(state.label)
                .font(Ink.figure(11, .semibold))
                .tracking(1.1)
                .foregroundColor(Ink.letter)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// One line of the menu. The price column is the tightest part of this build — eleven
/// treatments from $10 to $60 — so figures are monospaced and right-aligned.
struct TreatmentRow: View {
    let treatment: Treatment
    let opening: (day: Date, time: ChairTime)?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 7) {
                    Text(treatment.name)
                        .font(Ink.copy(15, .semibold))
                        .foregroundColor(Ink.letter)
                    if treatment.isSignature {
                        Kicker(text: "Signature", tint: Ink.accent)
                    }
                }
                Text(treatment.detail)
                    .font(Ink.copy(13))
                    .foregroundColor(Ink.letterSoft)
                    .fixedSize(horizontal: false, vertical: true)
                Text(soonestLabel)
                    .font(Ink.figure(11))
                    .foregroundColor(opening == nil ? Ink.letterSoft : Ink.accent)
                    .padding(.top, 1)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 3) {
                Text(Salon.money(treatment.priceCents))
                    .font(Ink.figure(15, .semibold))
                    .foregroundColor(Ink.letter)
                Text(Salon.length(treatment.minutes))
                    .font(Ink.figure(11))
                    .foregroundColor(Ink.letterSoft)
            }
        }
        .padding(.vertical, 14)
    }

    private var soonestLabel: String {
        guard let opening else { return "Full this fortnight" }
        let calendar = Calendar.current
        if calendar.isDateInToday(opening.day) { return "Soonest today \(opening.time.label)" }
        if calendar.isDateInTomorrow(opening.day) { return "Soonest tomorrow \(opening.time.label)" }
        return "Soonest \(Mark.day(opening.day)) \(opening.time.label)"
    }
}
