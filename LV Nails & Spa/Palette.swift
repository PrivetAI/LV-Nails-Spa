import SwiftUI

/// Every colour is written out rather than taken from the system, so the salon looks the
/// same whatever the phone's appearance setting is doing.
enum Ink {
    static let page = Color(red: 0.984, green: 0.969, blue: 0.973)
    static let card = Color(red: 0.949, green: 0.918, blue: 0.933)
    static let cardLifted = Color.white
    static let letter = Color(red: 0.165, green: 0.125, blue: 0.157)
    static let letterSoft = Color(red: 0.471, green: 0.424, blue: 0.455)
    static let accent = Color(red: 0.698, green: 0.227, blue: 0.420)
    static let onAccent = Color(red: 0.984, green: 0.969, blue: 0.973)
    static let rule = Color(red: 0.890, green: 0.843, blue: 0.867)

    /// Rounded, not serif. The one build in the set aimed at a mostly female clientele,
    /// and rounded reads warm without falling into pastel cliché.
    static func display(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static func copy(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    /// Prices and times. The menu here is the longest of the set and the cheapest, so the
    /// price column carries figures of very different widths — monospaced keeps it a column.
    static func figure(_ size: CGFloat, _ weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

enum Span {
    static let gutter: CGFloat = 20
    static let corner: CGFloat = 14
    static let rule: CGFloat = 1
}

// MARK: - Drawn marks
//
// Nothing in this app comes from the system icon set — every mark below is a Canvas.

struct BottleMark: View {
    var size: CGFloat = 24
    var color: Color = Ink.accent

    var body: some View {
        Canvas { context, canvas in
            let unit = min(canvas.width, canvas.height)
            let line = max(1.4, unit * 0.08)

            var cap = Path()
            cap.addRoundedRect(in: CGRect(x: unit * 0.42, y: unit * 0.12,
                                          width: unit * 0.16, height: unit * 0.16),
                               cornerSize: CGSize(width: unit * 0.03, height: unit * 0.03))
            context.stroke(cap, with: .color(color), lineWidth: line)

            var body = Path()
            body.addRoundedRect(in: CGRect(x: unit * 0.3, y: unit * 0.32,
                                           width: unit * 0.4, height: unit * 0.54),
                                cornerSize: CGSize(width: unit * 0.12, height: unit * 0.12))
            context.stroke(body, with: .color(color), lineWidth: line)

            var fill = Path()
            fill.addRoundedRect(in: CGRect(x: unit * 0.38, y: unit * 0.55,
                                           width: unit * 0.24, height: unit * 0.23),
                                cornerSize: CGSize(width: unit * 0.06, height: unit * 0.06))
            context.fill(fill, with: .color(color.opacity(0.55)))
        }
        .frame(width: size, height: size)
    }
}

struct HandMark: View {
    var size: CGFloat = 24
    var color: Color = Ink.accent

    var body: some View {
        Canvas { context, canvas in
            let unit = min(canvas.width, canvas.height)
            let line = max(1.4, unit * 0.08)

            for finger in 0..<4 {
                let x = unit * (0.28 + Double(finger) * 0.13)
                let top = unit * (finger == 0 || finger == 3 ? 0.32 : 0.22)
                var path = Path()
                path.move(to: CGPoint(x: x, y: unit * 0.62))
                path.addLine(to: CGPoint(x: x, y: top))
                context.stroke(path, with: .color(color),
                               style: StrokeStyle(lineWidth: line, lineCap: .round))

                // The polished tip — the point of the whole app.
                context.fill(Path(ellipseIn: CGRect(x: x - line * 0.75, y: top - line * 0.9,
                                                    width: line * 1.5, height: line * 1.8)),
                             with: .color(color))
            }

            var palm = Path()
            palm.addRoundedRect(in: CGRect(x: unit * 0.22, y: unit * 0.6,
                                           width: unit * 0.5, height: unit * 0.24),
                                cornerSize: CGSize(width: unit * 0.1, height: unit * 0.1))
            context.stroke(palm, with: .color(color), lineWidth: line)
        }
        .frame(width: size, height: size)
    }
}

struct DiaryMark: View {
    var size: CGFloat = 24
    var color: Color = Ink.accent

    var body: some View {
        Canvas { context, canvas in
            let unit = min(canvas.width, canvas.height)
            let line = max(1.4, unit * 0.08)

            let frame = Path(roundedRect: CGRect(x: unit * 0.18, y: unit * 0.24,
                                                 width: unit * 0.64, height: unit * 0.58),
                             cornerRadius: unit * 0.1)
            context.stroke(frame, with: .color(color), lineWidth: line)

            for peg in 0..<2 {
                let x = unit * (0.35 + Double(peg) * 0.3)
                var path = Path()
                path.move(to: CGPoint(x: x, y: unit * 0.16))
                path.addLine(to: CGPoint(x: x, y: unit * 0.3))
                context.stroke(path, with: .color(color),
                               style: StrokeStyle(lineWidth: line, lineCap: .round))
            }

            var divider = Path()
            divider.move(to: CGPoint(x: unit * 0.18, y: unit * 0.42))
            divider.addLine(to: CGPoint(x: unit * 0.82, y: unit * 0.42))
            context.stroke(divider, with: .color(color), lineWidth: line * 0.8)

            context.fill(Path(ellipseIn: CGRect(x: unit * 0.44, y: unit * 0.56,
                                                width: unit * 0.12, height: unit * 0.12)),
                         with: .color(color))
        }
        .frame(width: size, height: size)
    }
}

struct PinMark: View {
    var size: CGFloat = 24
    var color: Color = Ink.accent

    var body: some View {
        Canvas { context, canvas in
            let unit = min(canvas.width, canvas.height)
            let line = max(1.4, unit * 0.08)

            var drop = Path()
            drop.move(to: CGPoint(x: unit * 0.5, y: unit * 0.86))
            drop.addCurve(to: CGPoint(x: unit * 0.22, y: unit * 0.42),
                          control1: CGPoint(x: unit * 0.3, y: unit * 0.68),
                          control2: CGPoint(x: unit * 0.22, y: unit * 0.56))
            drop.addArc(center: CGPoint(x: unit * 0.5, y: unit * 0.42),
                        radius: unit * 0.28,
                        startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
            drop.addCurve(to: CGPoint(x: unit * 0.5, y: unit * 0.86),
                          control1: CGPoint(x: unit * 0.78, y: unit * 0.56),
                          control2: CGPoint(x: unit * 0.7, y: unit * 0.68))
            context.stroke(drop, with: .color(color),
                           style: StrokeStyle(lineWidth: line, lineJoin: .round))

            context.fill(Path(ellipseIn: CGRect(x: unit * 0.41, y: unit * 0.33,
                                                width: unit * 0.18, height: unit * 0.18)),
                         with: .color(color))
        }
        .frame(width: size, height: size)
    }
}

struct CloseMark: View {
    var size: CGFloat = 16
    var color: Color = Ink.letterSoft

    var body: some View {
        Canvas { context, canvas in
            let unit = min(canvas.width, canvas.height)
            let inset = unit * 0.25
            var path = Path()
            path.move(to: CGPoint(x: inset, y: inset))
            path.addLine(to: CGPoint(x: unit - inset, y: unit - inset))
            path.move(to: CGPoint(x: unit - inset, y: inset))
            path.addLine(to: CGPoint(x: inset, y: unit - inset))
            context.stroke(path, with: .color(color),
                           style: StrokeStyle(lineWidth: max(1.3, unit * 0.11), lineCap: .round))
        }
        .frame(width: size, height: size)
    }
}

/// The colour wall, abstracted: a soft grid of dots in the season's shades. Stands in for
/// photography the salon has not sent, without pretending to be a photograph.
struct ColourWall: View {
    var rows = 3
    var columns = 9

    var body: some View {
        Canvas { context, size in
            let stepX = size.width / CGFloat(columns)
            let stepY = size.height / CGFloat(rows)
            let radius = min(stepX, stepY) * 0.28

            for row in 0..<rows {
                for column in 0..<columns {
                    let shade = Double((row * columns + column) % 7) / 7
                    let dot = Ink.accent.opacity(0.16 + shade * 0.5)
                    let center = CGPoint(x: stepX * (CGFloat(column) + 0.5),
                                         y: stepY * (CGFloat(row) + 0.5))
                    context.fill(Path(ellipseIn: CGRect(x: center.x - radius,
                                                        y: center.y - radius,
                                                        width: radius * 2,
                                                        height: radius * 2)),
                                 with: .color(dot))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Shared chrome

struct Kicker: View {
    let text: String
    var tint: Color = Ink.letterSoft

    var body: some View {
        Text(text.uppercased())
            .font(Ink.figure(11, .semibold))
            .tracking(1.4)
            .foregroundColor(tint)
    }
}

struct Rule: View {
    var body: some View {
        Rectangle().fill(Ink.rule).frame(height: Span.rule)
    }
}

struct Card<Content: View>: View {
    var lifted = false
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(lifted ? Ink.cardLifted : Ink.card)
            .overlay(
                RoundedRectangle(cornerRadius: Span.corner)
                    .stroke(Ink.rule, lineWidth: Span.rule)
            )
            .clipShape(RoundedRectangle(cornerRadius: Span.corner))
    }
}

struct FilledButton: View {
    let title: String
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Ink.copy(16, .semibold))
                .foregroundColor(Ink.onAccent)
                .padding(.vertical, 15)
                .frame(maxWidth: .infinity)
                .background(Ink.accent.opacity(isEnabled ? 1 : 0.35))
                .clipShape(RoundedRectangle(cornerRadius: Span.corner))
                .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!isEnabled)
    }
}

struct QuietButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Ink.copy(15, .medium))
                .foregroundColor(Ink.accent)
                .padding(.vertical, 13)
                .frame(maxWidth: .infinity)
                .overlay(
                    RoundedRectangle(cornerRadius: Span.corner)
                        .stroke(Ink.accent.opacity(0.45), lineWidth: Span.rule)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct Sheet<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                content
            }
            .padding(.horizontal, Span.gutter)
            .padding(.top, 10)
            .padding(.bottom, 36)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Ink.page.ignoresSafeArea())
    }
}
