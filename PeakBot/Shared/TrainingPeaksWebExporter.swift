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

    func makeCoordinator() -> Coordinator {
        Coordinator(onExportComplete: onExportComplete)
    }

    func makeNSView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        cfg.applicationNameForUserAgent =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_3) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Safari/605.1.15"
        cfg.userContentController.add(context.coordinator, name: "zip")

        let webView = WKWebView(frame: .zero, configuration: cfg)
        webView.navigationDelegate = context.coordinator
        if let url = URL(string: "https://home.trainingpeaks.com/login") {
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
            guard message.name == "zip", let base64 = message.body as? String else {
                onExportComplete(nil)
                return
            }
            // Decode and save to temp file
            if let data = Data(base64Encoded: base64) {
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
                print("Failed to decode base64 ZIP")
                onExportComplete(nil)
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard !didInjectExportButton else { return }
            // Only inject after login (dashboard loaded)
            if let url = webView.url, url.host?.contains("trainingpeaks.com") == true {
                injectExportButton(into: webView)
                didInjectExportButton = true
            }
        }

        private func injectExportButton(into webView: WKWebView) {
            let js = """
            if (!window.peakbotExportBtn) {
              var btn = document.createElement('button');
              btn.innerText = 'Export ZIP for PeakBot';
              btn.style.position = 'fixed'; btn.style.bottom = '30px'; btn.style.right = '30px'; btn.style.zIndex = 9999; btn.style.padding = '10px 18px'; btn.style.background = '#2d7dd2'; btn.style.color = '#fff'; btn.style.border = 'none'; btn.style.borderRadius = '8px'; btn.style.fontSize = '18px'; btn.style.cursor = 'pointer';
              btn.onclick = function() {
                var from = new Date();
                from.setHours(0,0,0,0);
                var to = new Date();
                var params = 'startDate=' + from.toISOString().slice(0,10) + '&endDate=' + to.toISOString().slice(0,10) + '&exportOptions=7';
                fetch('/ExportData/ExportUserData', {
                  method:'POST',
                  headers:{'Content-Type':'application/x-www-form-urlencoded'},
                  body: params
                }).then(r=>r.blob()).then(b=>{
                  var reader = new FileReader();
                  reader.onloadend = function() {
                    var base64data = reader.result.split(',')[1];
                    window.webkit.messageHandlers.zip.postMessage(base64data);
                  };
                  reader.readAsDataURL(b);
                });
              };
              document.body.appendChild(btn);
              window.peakbotExportBtn = btn;
            }
            """
            webView.evaluateJavaScript(js, completionHandler: nil)
        }

        private func downloadBlob(from blobURL: URL) {
            // This is now replaced by base64 transfer in userContentController
        }
    }
}
