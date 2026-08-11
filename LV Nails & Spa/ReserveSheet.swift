import SwiftUI

/// Booking here works by part of day rather than by scrolling a full column: the salon
/// takes four chairs at once, so what a customer is really choosing is "some time this
/// afternoon", and the count of open chairs is the honest signal.
struct ReserveSheet: View {
    let treatment: Treatment

    @EnvironmentObject private var schedule: Schedule
    @Environment(\.presentationMode) private var presentation

    @State private var day = Date()
    @State private var part = PartOfDay.afternoon
    @State private var extras: Set<String> = []
    @State private var confirmed: ChairTime?

    var body: some View {
        ZStack {
            Ink.page.ignoresSafeArea()

            VStack(spacing: 0) {
                bar
                if confirmed == nil { picker } else { receipt }
            }
        }
        .onAppear(perform: startOnAnOpenPart)
    }

    private var runMinutes: Int {
        treatment.minutes + extras.compactMap { Salon.treatment($0)?.minutes }.reduce(0, +)
    }

    private var runCents: Int {
        treatment.priceCents + extras.compactMap { Salon.treatment($0)?.priceCents }.reduce(0, +)
    }

    private var bar: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(treatment.name)
                        .font(Ink.display(19))
                        .foregroundColor(Ink.letter)
                    Text("\(Salon.money(runCents)) · \(Salon.length(runMinutes))")
                        .font(Ink.figure(12))
                        .foregroundColor(Ink.letterSoft)
                }
                Spacer()
                Button(action: { presentation.wrappedValue.dismiss() }) {
                    CloseMark(size: 17, color: Ink.letter)
                        .frame(width: 40, height: 40)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, Span.gutter)
            .padding(.vertical, 12)
            Rule()
        }
    }

    // MARK: Picking

    private var picker: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                dayStrip
                if !addOns.isEmpty { addOnBlock }
                partStrip
                times
            }
            .padding(.horizontal, Span.gutter)
            .padding(.vertical, 18)
        }
    }

    private var days: [Date] {
        (0..<14).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: Date()) }
    }

    private var dayStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            Kicker(text: "Day")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 9) {
                    // Open seven days, so every chip is live — no greyed-out Sunday here.
                    ForEach(days, id: \.timeIntervalSince1970) { candidate in
                        Button(action: { day = candidate; startOnAnOpenPart() }) {
                            VStack(spacing: 4) {
                                Text(Mark.weekday(candidate).uppercased())
                                    .font(Ink.figure(10, .semibold))
                                    .tracking(0.7)
                                Text(Mark.number(candidate))
                                    .font(Ink.figure(16, .bold))
                            }
                            .foregroundColor(isChosen(candidate) ? Ink.onAccent : Ink.letter)
                            .frame(width: 52, height: 56)
                            .background(isChosen(candidate) ? Ink.accent : Ink.cardLifted)
                            .overlay(
                                RoundedRectangle(cornerRadius: Span.corner)
                                    .stroke(isChosen(candidate) ? Ink.accent : Ink.rule,
                                            lineWidth: Span.rule)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: Span.corner))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 1)
            }
        }
    }

    private func isChosen(_ candidate: Date) -> Bool {
        Calendar.current.isDate(candidate, inSameDayAs: day)
    }

    private var addOns: [Treatment] {
        Salon.menu.first { $0.id == "extras" }?.treatments.filter { $0.id != treatment.id } ?? []
    }

    private var addOnBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Kicker(text: "Add on")
            VStack(spacing: 0) {
                ForEach(Array(addOns.enumerated()), id: \.element.id) { index, extra in
                    if index > 0 { Rule() }
                    Button(action: { toggle(extra) }) {
                        HStack(spacing: 12) {
                            Tick(on: extras.contains(extra.id))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(extra.name)
                                    .font(Ink.copy(15))
                                    .foregroundColor(Ink.letter)
                                Text(extra.detail)
                                    .font(Ink.copy(12))
                                    .foregroundColor(Ink.letterSoft)
                            }
                            Spacer(minLength: 8)
                            Text("+\(Salon.money(extra.priceCents))")
                                .font(Ink.figure(13, .semibold))
                                .foregroundColor(Ink.accent)
                        }
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }

    private func toggle(_ extra: Treatment) {
        if extras.contains(extra.id) { extras.remove(extra.id) } else { extras.insert(extra.id) }
    }

    private var partStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            Kicker(text: "Part of day")
            HStack(spacing: 9) {
                ForEach(PartOfDay.allCases) { candidate in
                    let count = openCount(in: candidate)
                    Button(action: { part = candidate }) {
                        VStack(spacing: 3) {
                            Text(candidate.title)
                                .font(Ink.copy(14, .medium))
                            Text(count == 0 ? "full" : "\(count) open")
                                .font(Ink.figure(10))
                        }
                        .foregroundColor(part == candidate ? Ink.onAccent
                                                           : (count == 0 ? Ink.letterSoft : Ink.letter))
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(part == candidate ? Ink.accent : Ink.cardLifted)
                        .overlay(
                            RoundedRectangle(cornerRadius: Span.corner)
                                .stroke(part == candidate ? Ink.accent : Ink.rule,
                                        lineWidth: Span.rule)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: Span.corner))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }

    private func openCount(in part: PartOfDay) -> Int {
        schedule.chairTimes(on: day, runningFor: runMinutes, part: part).filter { $0.isTakeable }.count
    }

    /// Opens on a part of the day that actually has something in it, rather than dropping
    /// the customer onto an empty afternoon and making them hunt.
    private func startOnAnOpenPart() {
        if openCount(in: part) > 0 { return }
        if let first = PartOfDay.allCases.first(where: { openCount(in: $0) > 0 }) {
            part = first
        }
    }

    private var times: some View {
        VStack(alignment: .leading, spacing: 10) {
            Kicker(text: "Times")
            let slots = schedule.chairTimes(on: day, runningFor: runMinutes, part: part)
            if slots.isEmpty {
                Text("Nothing runs that long in the \(part.title.lowercased()).")
                    .font(Ink.copy(14))
                    .foregroundColor(Ink.letterSoft)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                FlowGrid(items: slots) { slot in
                    Button(action: { take(slot) }) {
                        VStack(spacing: 2) {
                            Text(slot.label)
                                .font(Ink.figure(13, .semibold))
                                .foregroundColor(slot.isTakeable ? Ink.letter : Ink.letterSoft.opacity(0.6))
                            Text(slot.isTakeable ? "\(slot.chairsFree) free" : (slot.isPast ? "gone" : "full"))
                                .font(Ink.figure(9))
                                .foregroundColor(slot.isTakeable ? Ink.accent : Ink.letterSoft.opacity(0.6))
                        }
                        .frame(width: 82, height: 46)
                        .background(slot.isTakeable ? Ink.cardLifted : Ink.card)
                        .overlay(
                            RoundedRectangle(cornerRadius: Span.corner)
                                .stroke(slot.isTakeable ? Ink.accent.opacity(0.4) : Ink.rule,
                                        lineWidth: Span.rule)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: Span.corner))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(!slot.isTakeable)
                }
            }
        }
    }

    private func take(_ slot: ChairTime) {
        guard slot.isTakeable else { return }
        schedule.reserve(treatment,
                         extras: extras.compactMap { Salon.treatment($0) },
                         day: day,
                         minutes: slot.minutes)
        confirmed = slot
    }

    // MARK: Confirmation

    private var receipt: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Card(lifted: true) {
                    VStack(alignment: .leading, spacing: 12) {
                        Kicker(text: "Held on this phone", tint: Ink.accent)
                        Text("\(Mark.day(day)) at \(confirmed.map { Salon.clock($0.minutes) } ?? "")")
                            .font(Ink.display(23))
                            .foregroundColor(Ink.letter)
                        Text(lineUp)
                            .font(Ink.copy(15))
                            .foregroundColor(Ink.letterSoft)
                            .fixedSize(horizontal: false, vertical: true)
                        Rule()
                        Text("This build keeps the book on your phone. Nothing has reached the "
                             + "salon — call \(Salon.phone) to confirm the chair.")
                            .font(Ink.copy(13))
                            .foregroundColor(Ink.letterSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                FilledButton(title: "Done") { presentation.wrappedValue.dismiss() }
            }
            .padding(.horizontal, Span.gutter)
            .padding(.vertical, 20)
        }
    }

    private var lineUp: String {
        let names = [treatment.name] + extras.compactMap { Salon.treatment($0)?.name }
        return "\(names.joined(separator: " + ")) · \(Salon.money(runCents))"
    }
}

struct Tick: View {
    let on: Bool

    var body: some View {
        Canvas { context, size in
            let unit = min(size.width, size.height)
            let box = Path(roundedRect: CGRect(x: unit * 0.08, y: unit * 0.08,
                                               width: unit * 0.84, height: unit * 0.84),
                           cornerRadius: unit * 0.24)
            if on {
                context.fill(box, with: .color(Ink.accent))
                var check = Path()
                check.move(to: CGPoint(x: unit * 0.28, y: unit * 0.52))
                check.addLine(to: CGPoint(x: unit * 0.43, y: unit * 0.68))
                check.addLine(to: CGPoint(x: unit * 0.73, y: unit * 0.33))
                context.stroke(check, with: .color(Ink.onAccent),
                               style: StrokeStyle(lineWidth: unit * 0.11,
                                                  lineCap: .round, lineJoin: .round))
            } else {
                context.stroke(box, with: .color(Ink.rule), lineWidth: unit * 0.08)
            }
        }
        .frame(width: 22, height: 22)
    }
}

/// A wrapping row of fixed-width chips. LazyVGrid's adaptive columns are iOS 14+, but the
/// widths here are known, so measuring against the screen keeps it predictable on iPad too.
struct FlowGrid<Item: Identifiable, Cell: View>: View {
    let items: [Item]
    @ViewBuilder let cell: (Item) -> Cell

    private let chipWidth: CGFloat = 82
    private let spacing: CGFloat = 9

    var body: some View {
        let usable = UIScreen.main.bounds.width - Span.gutter * 2
        let perRow = max(1, Int((usable + spacing) / (chipWidth + spacing)))
        let rows = stride(from: 0, to: items.count, by: perRow).map { start in
            Array(items[start..<min(start + perRow, items.count)])
        }

        return VStack(alignment: .leading, spacing: spacing) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: spacing) {
                    ForEach(row) { item in cell(item) }
                    Spacer(minLength: 0)
                }
            }
        }
    }
}
