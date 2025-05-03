//  TrainingPeaksWebExporter.swift
//  PeakBot
//
//  Exports TrainingPeaks data by running JS inside the authenticated WKWebView session.
//  This bypasses CSRF/WAF issues by using TP's own JS context. The ZIP blob is passed to Swift via WKScriptMessageHandler.

import SwiftUI
import WebKit
import AppKit

struct TrainingPeaksWebExporter: NSViewRepresentable {
    let onExportComplete: (URL?) -> Void
    
    init(onExportComplete: @escaping (URL?) -> Void) {
        print("[PeakBot DEBUG] TrainingPeaksWebExporter INIT")
        self.onExportComplete = onExportComplete
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onExportComplete: onExportComplete)
    }

    func makeNSView(context: Context) -> WKWebView {
        print("[PeakBot DEBUG] makeNSView CALLED!")
        let cfg = WKWebViewConfiguration()
        cfg.applicationNameForUserAgent =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_3) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Safari/605.1.15"
        cfg.userContentController.add(context.coordinator, name: "zip")
        // Use a fresh process pool to avoid script caching issues
        cfg.processPool = WKProcessPool()
        // Explicitly enable JavaScript
        let prefs = WKPreferences()
        prefs.javaScriptEnabled = true
        // Enable the Web Inspector for debugging
        prefs.setValue(true, forKey: "developerExtrasEnabled")
        cfg.preferences = prefs

        // --- BEGIN: Robust JS injection with WKUserScript ---
        let js = """
(function peakbotInit() {
    if (window.peakbotReady) return;
    window.peakbotReady = true;
    console.log('PeakBot JS injected!');
    function insertButton() {
        var btn = document.createElement('button');
        btn.innerText = 'PeakBot Export';
        btn.style.position = 'fixed';
        btn.style.top = '20px';
        btn.style.right = '20px';
        btn.style.zIndex = 9999;
        btn.style.padding = '10px 20px';
        btn.style.background = '#4CAF50';
        btn.style.color = 'white';
        btn.style.fontSize = '16px';
        btn.style.border = 'none';
        btn.style.borderRadius = '6px';
        btn.style.cursor = 'pointer';
        btn.onclick = function() { console.log('PeakBot Export button clicked!'); };
        document.body.appendChild(btn);
    }
    if (document.body) {
        insertButton();
    } else {
        document.addEventListener('DOMContentLoaded', insertButton);
    }
})();
"""
        let script = WKUserScript(source: js, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        cfg.userContentController.addUserScript(script)
        print("[PeakBot DEBUG] Added user script. Creating WKWebView...")
        // --- END: Robust JS injection ---

        let webView = WKWebView(frame: .zero, configuration: cfg)
        webView.navigationDelegate = context.coordinator
        if let url = URL(string: "https://example.com") {
            webView.load(URLRequest(url: url))
        }
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        let onExportComplete: (URL?) -> Void
        private var didInjectExportButton = false
        init(onExportComplete: @escaping (URL?) -> Void) {
            self.onExportComplete = onExportComplete
        }

        // Listen for ZIP blob from JS
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "zip" else {
                onExportComplete(nil)
                return
            }
            if let payload = message.body as? String, payload.hasPrefix("ERROR:") {
                print("Export failed, server response:\n", payload)
                onExportComplete(nil)
                return
            }
            if let payload = message.body as? String, payload.hasPrefix("EXPORT_LINKS:") {
                print("Export links:\n", payload)
                onExportComplete(nil)
                return
            }
            if let payload = message.body as? String, payload.hasPrefix("TD_LOG:") {
                print("TD_LOG:\n", payload)
                onExportComplete(nil)
                return
            }
            if let bytes = message.body as? [UInt8] {
                let data = Data(bytes)
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("tp_export.zip")
                do {
                    try data.write(to: tempURL)
                    print("Saved ZIP to", tempURL)
                    onExportComplete(tempURL)
                } catch {
                    print("Failed to write ZIP:", error)
                    onExportComplete(nil)
                }
            } else {
                print("Failed to decode ZIP bytes")
                onExportComplete(nil)
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard !didInjectExportButton else { return }
            // Only inject after login (dashboard loaded)
            if let url = webView.url, url.host?.contains("trainingpeaks.com") == true {
                print("[PeakBot DEBUG] WKWebView didFinish navigation. Injecting JS via evaluateJavaScript...")
                let js = "alert('PeakBot JS injected via didFinish!')"
                webView.evaluateJavaScript(js) { result, error in
                    if let error = error {
                        print("[PeakBot DEBUG] JS injection error: \(error)")
                    } else {
                        print("[PeakBot DEBUG] JS injected via evaluateJavaScript")
                    }
                }
                injectExportButton(into: webView)
                didInjectExportButton = true
            }
        }

        private func injectExportButton(into webView: WKWebView) {
            // No-op: now handled by WKUserScript above
        }

        private func downloadBlob(from blobURL: URL) {
            // This is now replaced by base64 transfer in userContentController
        }
    }
}
