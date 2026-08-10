import SwiftUI

struct SalonView: View {
    @State private var now = Date()
    @State private var readingPolicy = false

    private let tick = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        Sheet {
            VStack(alignment: .leading, spacing: 8) {
                Kicker(text: "\(Salon.city), \(Salon.region)")
                Text(Salon.name)
                    .font(Ink.display(28))
                    .foregroundColor(Ink.letter)
                    .fixedSize(horizontal: false, vertical: true)
                DoorLine(state: DoorState.now(now))
            }

            Text(Salon.about)
                .font(Ink.copy(15))
                .foregroundColor(Ink.letterSoft)
                .fixedSize(horizontal: false, vertical: true)

            rating
            hoursTable
            contact
            policy
        }
        .onReceive(tick) { now = $0 }
        .sheet(isPresented: $readingPolicy) {
            PolicyPage()
        }
    }

    private var rating: some View {
        Card(lifted: true) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(String(format: "%.1f", Salon.ratingAverage))
                        .font(Ink.display(30))
                        .foregroundColor(Ink.accent)
                    Text("\(Salon.ratingCount) reviews")
                        .font(Ink.figure(11))
                        .foregroundColor(Ink.letterSoft)
                }
                Rectangle().fill(Ink.rule).frame(width: Span.rule, height: 46)
                VStack(alignment: .leading, spacing: 6) {
                    StarRow(value: Salon.ratingAverage)
                    Text("Four chairs, seven days, walk-ins taken when there is room.")
                        .font(Ink.copy(13))
                        .foregroundColor(Ink.letterSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
        }
    }

    /// Seven rows, and Sunday is deliberately not folded into the others — the short day
    /// is the single thing somebody checks this table for.
    private var hoursTable: some View {
        VStack(alignment: .leading, spacing: 0) {
            Kicker(text: "Hours")
                .padding(.bottom, 10)
            ForEach(Array(Salon.weekOrdered.enumerated()), id: \.element.weekday) { index, day in
                if index > 0 { Rule() }
                HStack {
                    Text(day.dayName)
                        .font(Ink.copy(15, isToday(day) ? .semibold : .regular))
                        .foregroundColor(Ink.letter)
                    if day.isShortDay {
                        Text("short day")
                            .font(Ink.figure(10, .semibold))
                            .foregroundColor(Ink.accent)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Ink.accent.opacity(0.4), lineWidth: Span.rule)
                            )
                    }
                    Spacer()
                    Text(day.rangeLabel)
                        .font(Ink.figure(13))
                        .foregroundColor(Ink.letterSoft)
                }
                .padding(.vertical, 11)
                .padding(.horizontal, isToday(day) ? 10 : 0)
                .background(isToday(day) ? Ink.card : Color.clear)
            }
        }
    }

    private func isToday(_ day: DayHours) -> Bool {
        Calendar.current.component(.weekday, from: now) == day.weekday
    }

    private var contact: some View {
        VStack(alignment: .leading, spacing: 12) {
            Kicker(text: "Find the salon")
            Text(Salon.addressLine)
                .font(Ink.copy(15))
                .foregroundColor(Ink.letter)
                .fixedSize(horizontal: false, vertical: true)
            Text(Salon.phone)
                .font(Ink.figure(15))
                .foregroundColor(Ink.accent)
        }
    }

    private var policy: some View {
        VStack(alignment: .leading, spacing: 10) {
            Kicker(text: "Legal")
            QuietButton(title: "Privacy Policy") { readingPolicy = true }
        }
    }
}

struct StarRow: View {
    let value: Double

    var body: some View {
        HStack(spacing: 3) {
            ForEach(1...5, id: \.self) { index in
                StarMark(filled: value >= Double(index) - 0.25)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("\(String(format: "%.1f", value)) out of 5")
    }
}

struct StarMark: View {
    let filled: Bool
    var size: CGFloat = 13

    var body: some View {
        Canvas { context, canvas in
            let unit = min(canvas.width, canvas.height)
            let center = CGPoint(x: unit / 2, y: unit / 2)
            let outer = unit * 0.48
            let inner = outer * 0.42

            var path = Path()
            for step in 0..<10 {
                let radius = step % 2 == 0 ? outer : inner
                let angle = -Double.pi / 2 + Double(step) * Double.pi / 5
                let point = CGPoint(x: center.x + CGFloat(cos(angle)) * radius,
                                    y: center.y + CGFloat(sin(angle)) * radius)
                if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
            path.closeSubpath()

            if filled {
                context.fill(path, with: .color(Ink.accent))
            } else {
                context.stroke(path, with: .color(Ink.accent.opacity(0.45)), lineWidth: 1)
            }
        }
        .frame(width: size, height: size)
    }
}
