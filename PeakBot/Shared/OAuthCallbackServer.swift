import Foundation
import Swifter

/// Minimal local HTTP server to catch the OAuth callback from Strava
/// Listens on http://localhost:8080/callback and extracts the `code` query param
final class OAuthCallbackServer {
    private var server: URLSession?
    private var task: URLSessionDataTask?
    private let port: UInt16 = 8080
    private let callbackPath = "/callback"
    private var onCodeReceived: ((String) -> Void)?
    private var isRunning = false

    // Start listening for the OAuth callback
    func start(onCode: @escaping (String) -> Void) {
        guard !isRunning else { return }
        isRunning = true
        self.onCodeReceived = onCode
        DispatchQueue.global(qos: .background).async {
            self.runServer()
        }
    }

    private func runServer() {
        // Use a simple TCP socket for demo purposes
        let server = HttpServer()
        server[callbackPath] = { [weak self] (req: HttpRequest) -> HttpResponse in
            guard let self = self else { return .internalServerError }
            if let code = req.queryParams.first(where: { $0.0 == "code" })?.1 {
                DispatchQueue.main.async {
                    self.onCodeReceived?(code)
                }
                return .ok(.html("<h2>Strava authorization complete. You may close this window.</h2>"))
            } else {
                return .badRequest(nil)
            }
        }
        do {
            try server.start(port, forceIPv4: true)
            print("[OAuthCallbackServer] Listening on http://localhost:\(port)\(callbackPath)")
        } catch {
            print("[OAuthCallbackServer] Failed to start: \(error)")
        }
    }

    func stop() {
        // Not implemented: add shutdown logic if needed
    }
}

// Note: This example uses Swifter (https://github.com/httpswift/swifter) for the HTTP server.
// Add Swifter as a dependency via Swift Package Manager for this code to work.
