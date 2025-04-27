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
                injectExportButton(into: webView)
                didInjectExportButton = true
            }
        }

        private func injectExportButton(into webView: WKWebView) {
            let peakbotJS = """
(function peakbotInit() {
  if (window.peakbotReady) return;
  window.peakbotReady = true;

  function log(m){ console.log('[PeakBot]', m); }

  // 1. Floating helper
  const helper = document.createElement('button');
  helper.textContent = 'Export ▶︎ PeakBot';
  helper.style = 'position:fixed;top:8px;right:8px;z-index:1e5;padding:6px';
  document.body.appendChild(helper);

  // 2. Wait-for util
  const wait = (sel,max=100)=>new Promise((ok,fail)=>{
     const i=setInterval(()=>{const e=document.querySelector(sel);
        if(e){clearInterval(i);ok(e);}
        else if(--max===0){clearInterval(i);fail();}
     },100);});

  // 3. Click handler
  helper.onclick = async ()=>{
    try{
      // a) fill date boxes (workout-files row, two <input>)
      const row = await wait('td:contains(\"Workout Files\")');
      const ins = row.closest('tr').querySelectorAll('input[type=text]');
      const d = new Date().toISOString().slice(0,10);
      ins[0].value = d;  ins[1].value = d;

      // b) click first Export link
      row.closest('tr').querySelector('a,button').click();
      log('clicked Export link; waiting for modal');

      // c) wait for modal anchor & fetch ZIP
      const a = await wait('.tpDialog a[href$=\".zip\"]');
      const buf = await fetch(a.href).then(r=>r.arrayBuffer());
      window.webkit.messageHandlers.zip.postMessage([...new Uint8Array(buf)]);
      log('ZIP bytes sent to Swift');
    }catch(e){
      alert('PeakBot failed: '+e);
    }
  };
})();
"""
            let debugJS = """
(function peakbotDebug() {
  if (window.peakbotReady) return;
  window.peakbotReady = true;
  function waitModal(sel, max=100) {
    return new Promise((ok,fail)=>{
      const i=setInterval(()=>{
        const e=document.querySelector(sel);
        if(e){clearInterval(i);ok(e);}
        else if(--max===0){clearInterval(i);fail('Modal not found');}
      },100);
    });
  }
  waitModal('.tpDialog').then(modal => {
    const helper = document.createElement('button');
    helper.textContent = 'Export ▶︎ PeakBot (Debug)';
    helper.style = `
      width: 90%;
      margin: 24px 5%;
      padding: 24px 0;
      background: #ffe000 !important;
      color: #222 !important;
      font-size: 28px !important;
      font-weight: bold !important;
      border: 6px solid #d00 !important;
      border-radius: 18px !important;
      box-shadow: 4px 4px 16px #000, 0 0 0 8px #fff !important;
      opacity: 1 !important;
      outline: 8px solid #222 !important;
      pointer-events: auto !important;
      display: block !important;
      z-index: 999999999 !important;
    `;
    modal.appendChild(helper);
    helper.onclick = () => {
      var tds = Array.from(document.querySelectorAll('td'));
      var log = tds.map((td,i) => `#${i}: "${td.innerText.trim()}"`).join('\n');
      window.webkit.messageHandlers.zip.postMessage('TD_LOG:' + log);
    };
  }).catch(()=>{});
})();
"""
            webView.evaluateJavaScript(peakbotJS, completionHandler: nil)
            webView.evaluateJavaScript(debugJS, completionHandler: nil)
        }

        private func downloadBlob(from blobURL: URL) {
            // This is now replaced by base64 transfer in userContentController
        }
    }
}
