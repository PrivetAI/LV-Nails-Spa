import SwiftUI
import WebKit

struct LVWebDisplay: UIViewRepresentable {
    let address: String

    func makeUIView(context: Context) -> WKWebView {
        let settings = WKWebViewConfiguration()
        settings.allowsInlineMediaPlayback = true

        let display = WKWebView(frame: .zero, configuration: settings)
        display.allowsBackForwardNavigationGestures = true
        // Belt and braces — the real guarantee against the notch is the frame, set where
        // this is presented. Never .never: that always draws under the clock.
        display.scrollView.contentInsetAdjustmentBehavior = .always
        display.isOpaque = true
        display.backgroundColor = UIColor(red: 0.984, green: 0.969, blue: 0.973, alpha: 1)

        if let url = URL(string: address) {
            display.load(URLRequest(url: url))
        }
        return display
    }

    /// Stays empty on purpose. Loading here would reload the page on every SwiftUI
    /// re-render, and the page would never settle.
    func updateUIView(_ display: WKWebView, context: Context) {}
}

/// Reached from the Salon screen. Same address the app opens on, so there is one page to
/// keep current rather than two.
struct PolicyPage: View {
    @Environment(\.presentationMode) private var presentation

    var body: some View {
        ZStack {
            Ink.page.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Text("Privacy Policy")
                        .font(Ink.display(18))
                        .foregroundColor(Ink.letter)
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

                LVWebDisplay(address: LVGate.endpoint)
            }
        }
    }
}
