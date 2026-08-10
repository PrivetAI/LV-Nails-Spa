import SwiftUI

/// A hand-built bar rather than TabView: `.tabItem` renders only Image and Text, so the
/// Canvas marks this app uses would simply never show up inside one.
struct TabShell: View {
    @EnvironmentObject private var schedule: Schedule
    @State private var tab = 0

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch tab {
                case 0: TodayView(openMenu: { tab = 1 })
                case 1: MenuView()
                case 2: AppointmentsView()
                default: SalonView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // A ScrollView draws its content through the top inset by design — fine under
            // a navigation bar, but nothing here has one, so rows would ride over the
            // clock. Clipping to the content area is what actually stops it.
            .clipped()

            bar
        }
        // Painted through `.background`, not as a ZStack sibling: a sibling that ignores
        // the safe area stretches the stack, and scrolled content then runs under the clock.
        .background(Ink.page.ignoresSafeArea())
        // Nothing here carries a navigation bar, so scrolled content would otherwise ride
        // up over the clock. A zero-height band that ignores the top inset expands into it
        // and paints it out, without taking part in layout.
        .overlay(
            Ink.page
                .frame(height: 0)
                .ignoresSafeArea(edges: .top),
            alignment: .top
        )
    }

    private var bar: some View {
        VStack(spacing: 0) {
            Rule()
            HStack(spacing: 0) {
                button(index: 0, label: "Today") { HandMark(size: 22, color: tint(0)) }
                button(index: 1, label: "Menu") { BottleMark(size: 22, color: tint(1)) }
                button(index: 2, label: "Book") { DiaryMark(size: 22, color: tint(2)) }
                button(index: 3, label: "Salon") { PinMark(size: 22, color: tint(3)) }
            }
            .padding(.top, 9)
            .padding(.bottom, 3)
            .background(Ink.cardLifted.ignoresSafeArea(edges: .bottom))
        }
    }

    private func tint(_ index: Int) -> Color {
        tab == index ? Ink.accent : Ink.letterSoft.opacity(0.7)
    }

    private func button<Glyph: View>(index: Int, label: String,
                                     @ViewBuilder glyph: () -> Glyph) -> some View {
        Button(action: { tab = index }) {
            VStack(spacing: 5) {
                glyph()
                Text(label)
                    .font(Ink.figure(10, .semibold))
                    .tracking(0.7)
                    .foregroundColor(tint(index))
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}
