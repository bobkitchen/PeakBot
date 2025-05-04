//  TrainingPeaksLoginController.swift
//  PeakBot
//
//  Headless / sheet-based login that loads the TrainingPeaks web site in an off-screen WKWebView
//  with a desktop Safari user-agent. Once the user is authenticated we capture cookies and
//  persist them via KeychainHelper.tpSessionCookies so that other services (Export) can
//  attach them to URLSession requests.
//
//  NOTE: This bypasses the official TP partner API and relies on an HTML login flow. Use at
//  your own risk – the TP terms of service may prohibit automated scraping.

import SwiftUI
import WebKit
import AppKit
import Combine

/// SwiftUI wrapper that drives a hidden WKWebView. Show this once in a sheet; it dismisses
/// itself via the `onComplete` callback when a valid TP session cookie is observed.
struct TrainingPeaksLoginController: NSViewRepresentable {
    /// Called with `true` on success, `false` on failure (e.g. user closed sheet).
    let onComplete: (Bool) -> Void
    @State static var manualCloseRequested = false

    // MARK: – NSViewRepresentable
    func makeCoordinator() -> Coordinator { Coordinator(onComplete: onComplete) }

    func makeNSView(context: Context) -> NSView {
        print("[PeakBot DEBUG] TrainingPeaksLoginController.makeNSView called")
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 640, height: 480))
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        let cfg = WKWebViewConfiguration()
        cfg.websiteDataStore = .default() // Use persistent store for cookies
        cfg.applicationNameForUserAgent =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_3) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Safari/605.1.15"

        let webView = WKWebView(frame: container.bounds, configuration: cfg)
        webView.navigationDelegate = context.coordinator
        webView.autoresizingMask = [.width, .height]
        container.addSubview(webView)
        if let url = URL(string: "https://home.trainingpeaks.com/login") {
            print("[PeakBot DEBUG] Loading TP login URL: \(url)")
            webView.load(URLRequest(url: url))
        } else {
            let label = NSTextField(labelWithString: "Failed to construct login URL.")
            label.frame = NSRect(x: 20, y: 220, width: 600, height: 40)
            container.addSubview(label)
        }

        // Add a Done button, disabled until all cookies present
        let button = NSButton(frame: NSRect(x: 520, y: 5, width: 110, height: 30))
        button.title = "Done"
        button.bezelStyle = .rounded
        button.action = #selector(Coordinator.manualCloseButtonTapped(_:))
        button.target = context.coordinator
        button.isEnabled = false // Initially disabled
        container.addSubview(button)

        // Observe canDismiss to enable/disable the Done button
        context.coordinator.cancellable = context.coordinator.$canDismiss.receive(on: RunLoop.main).sink { canDismiss in
            button.isEnabled = canDismiss
        }

        return container
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    // MARK: – Coordinator
    final class Coordinator: NSObject, WKNavigationDelegate, ObservableObject {
        @Published var canDismiss = false
        var cancellable: AnyCancellable?
        private let onComplete: (Bool) -> Void
        init(onComplete: @escaping (Bool) -> Void) { self.onComplete = onComplete }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            let jar = HTTPCookieStorage.shared.cookies ?? []
            let names = Set(jar.map { $0.name.lowercased() })
            let haveAJS = jar.contains { $0.name == "ajs_user_id" && Int($0.value) != nil }
            if haveAJS {
                if !canDismiss {
                    print("[TPLogin] ajs_user_id present; athleteId available; enabling Done button.")
                    CookieVault.save(jar)
                    canDismiss = true
                }
            } else {
                print("[TPLogin] waiting – cookies now:", names.sorted())
            }
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            onComplete(false)
        }

        func persistTPCookies(webView: WKWebView) {
            let store = webView.configuration.websiteDataStore.httpCookieStore
            store.getAllCookies { cookies in
                // keep only what the REST client actually needs
                let keep = ["Production_tpAuth", "ajs_user_id"]
                let filtered = cookies.filter { keep.contains($0.name) }
                KeychainHelper.tpSessionCookies = filtered
                print("[TPLogin] Persisted TP cookies:", filtered.map { $0.name })
            }
        }

        @objc func manualCloseButtonTapped(_ sender: Any?) {
            if canDismiss {
                if let webView = (sender as? NSButton)?.superview?.subviews.compactMap({ $0 as? WKWebView }).first {
                    persistTPCookies(webView: webView)
                }
                onComplete(true)
            } else {
                print("[TPLogin] Not all cookies present – cannot dismiss yet.")
            }
        }
    }
}
