// TrainingPeaksLoginView.swift
// PeakBot
//
// Secure TrainingPeaks login using ASWebAuthenticationSession (replaces WKWebView)

import SwiftUI
import AuthenticationServices
import AppKit

struct TrainingPeaksLoginView: View {
    let onLoginSuccess: () -> Void
    let onLoginFailure: (String) -> Void
    @State private var isAuthenticating = false
    @State private var authSession: ASWebAuthenticationSession?
    @State private var errorMessage: String? = nil
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Login to TrainingPeaks")
                .font(.title2)
            Button("Login with TrainingPeaks") {
                startAuthentication()
            }
            .disabled(isAuthenticating)
            if let errorMessage = errorMessage {
                Text("⚠️ " + errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
            }
        }
        .frame(minWidth: 320, minHeight: 200)
    }

    private func startAuthentication() {
        guard let authURL = URL(string: "https://app.trainingpeaks.com/login") else {
            errorMessage = "Invalid TrainingPeaks login URL."
            return
        }
        guard let anchor = NSApplication.shared.windows.first(where: { $0.isKeyWindow }) ?? NSApplication.shared.windows.first else {
            errorMessage = "No valid window for authentication presentation."
            return
        }
        isAuthenticating = true
        errorMessage = nil
        let session = ASWebAuthenticationSession(
            url: authURL,
            callbackURLScheme: nil // Not using OAuth, so no custom scheme needed
        ) { callbackURL, error in
            isAuthenticating = false
            if let error = error {
                errorMessage = "Authentication error: \(error.localizedDescription)"
                print("[TrainingPeaksLoginView] Authentication error: \(error)")
                return
            }
            // Try to extract cookies from shared storage
            let cookieStorage = HTTPCookieStorage.shared
            let cookies = cookieStorage.cookies?.filter { $0.domain.contains("trainingpeaks.com") }
            KeychainHelper.tpSessionCookies = cookies
            if let cookies = cookies, cookies.contains(where: { $0.name == "ASP.NET_SessionId" }) {
                print("[TrainingPeaksLoginView] Login success, session cookie found.")
                onLoginSuccess()
            } else {
                errorMessage = "Could not find TrainingPeaks session cookie."
                print("[TrainingPeaksLoginView] Login failure: session cookie not found.")
            }
        }
        session.presentationContextProvider = SimplePresentationProvider(anchor: anchor)
        session.prefersEphemeralWebBrowserSession = true // Avoids using existing cookies for security
        session.start()
        authSession = session // retain until completion
        print("[TrainingPeaksLoginView] Started ASWebAuthenticationSession")
    }
}

private class SimplePresentationProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    let anchor: ASPresentationAnchor
    init(anchor: ASPresentationAnchor) { self.anchor = anchor }
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        anchor
    }
}
