import SwiftUI

/// Held for the second or two the launch check takes, in the salon's own plum on off-white
/// so the wait reads as the app opening rather than as a blank frame.
struct LVSplashView: View {
    @State private var settling = false

    var body: some View {
        ZStack {
            Ink.page.ignoresSafeArea()

            VStack(spacing: 24) {
                ColourWall(rows: 2, columns: 6)
                    .frame(width: 190, height: 60)
                    .opacity(settling ? 1 : 0.35)
                    .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                               value: settling)

                VStack(spacing: 7) {
                    Text(Salon.name)
                        .font(Ink.display(25))
                        .foregroundColor(Ink.letter)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    Kicker(text: "\(Salon.city), \(Salon.region)")
                }
            }
            .padding(.horizontal, 32)
        }
        .onAppear { settling = true }
    }
}
