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
        // Spoof desktop Safari UA to avoid TP mobile / WKWebView blocks.
        cfg.applicationNameForUserAgent =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_3) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Safari/605.1.15"

        let webView = WKWebView(frame: container.bounds, configuration: cfg)
        webView.navigationDelegate = context.coordinator
        webView.autoresizingMask = [.width, .height]
        container.addSubview(webView)
        // Navigate to the preferred home TP login.
        if let url = URL(string: "https://home.trainingpeaks.com/login") {
            print("[PeakBot DEBUG] Loading TP login URL: \(url)")
            webView.load(URLRequest(url: url))
        } else {
            let label = NSTextField(labelWithString: "Failed to construct login URL.")
            label.frame = NSRect(x: 20, y: 220, width: 600, height: 40)
            container.addSubview(label)
        }

        // Add a manual close button
        let button = NSButton(frame: NSRect(x: 520, y: 5, width: 110, height: 30))
        button.title = "Done (manual)"
        button.bezelStyle = .rounded
        button.action = #selector(Coordinator.manualCloseButtonTapped(_:))
        button.target = context.coordinator
        container.addSubview(button)

        return container
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    // MARK: – Coordinator
    final class Coordinator: NSObject, WKNavigationDelegate {
        private let onComplete: (Bool) -> Void
        init(onComplete: @escaping (Bool) -> Void) { self.onComplete = onComplete }

        // REMOVE auto-close on navigation:
        // func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        //     // Look for successful redirect to the app sub-domain after login.
        //     let cookies = HTTPCookieStorage.shared.cookies ?? []
        //     let hasTPAuth = cookies.contains { $0.name == "TPAuth" || $0.name == "Production_tpAuth" }
        //     let hasSession = cookies.contains { $0.name == "ASP.NET_SessionId" }
        //     print("Captured cookies:")
        //     cookies.forEach { print($0.name, $0.domain, $0.value) }
        //     if hasTPAuth || hasSession {
        //         // Persist and finish.
        //         KeychainHelper.tpSessionCookies = cookies
        //         DispatchQueue.main.async { self.onComplete(true) }
        //     }
        // }

        @objc func manualCloseButtonTapped(_ sender: Any?) {
            let cookies = HTTPCookieStorage.shared.cookies ?? []
            print("Captured cookies (manual close):")
            cookies.forEach { print($0.name, $0.domain, $0.value) }
            if !cookies.isEmpty {
                KeychainHelper.tpSessionCookies = cookies
            }
            DispatchQueue.main.async { self.onComplete(true) }
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            // Edge case: process crashed.
            onComplete(false)
        }
    }
}
