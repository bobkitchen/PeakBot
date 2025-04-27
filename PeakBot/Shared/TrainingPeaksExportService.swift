//  TrainingPeaksExportService.swift
//  PeakBot – high-level wrapper around the HTML export flow.
//
//  1. Reads cookies from KeychainHelper.tpSessionCookies.
//  2. POSTs to ExportData/ExportUserData with date range form data.
//  3. Follows 302 → downloads ZIP to caches dir.
//  4. Delegates ingest to TrainingPeaksService.ingestExportedData(...).
//
//  Uses async/await for clarity.

import Foundation
import ZIPFoundation

@MainActor
final class TrainingPeaksExportService {
    static let shared = TrainingPeaksExportService()
    private init() {}

    /// Export window.
    enum Range {
        case days(Int)          // N days back from today
        case custom(Date, Date) // explicit UTC range
    }

    /// Sync wrapper used by the UI.
    func sync(range: Range = .days(1), trainingPeaksService: TrainingPeaksService) async {
        guard let zipURL = try? await downloadExport(range: range) else {
            trainingPeaksService.errorMessage = "Export download failed."
            return
        }
        await withCheckedContinuation { cont in
            trainingPeaksService.ingestExportedData(from: zipURL) { ok in
                cont.resume()
            }
        }
    }

    // MARK: - Low-level download
    private func downloadExport(range: Range) async throws -> URL {
        guard let cookies = KeychainHelper.tpSessionCookies else {
            throw URLError(.userAuthenticationRequired)
        }
        var comps = URLComponents(string: "https://app.trainingpeaks.com/ExportData/ExportUserData")!
        var request = URLRequest(url: comps.url!)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = HTTPCookie.requestHeaderFields(with: cookies)
        print("Export POST headers:", request.allHTTPHeaderFields ?? [:])
        // Simple form values – TP ignores many. We post dummy dates to satisfy server.
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let (start, end): (Date, Date) = {
            switch range {
            case .days(let n):
                let end = Date()
                let start = Calendar.current.date(byAdding: .day, value: -n, to: end)!
                return (start, end)
            case .custom(let a, let b):
                return (a, b)
            }
        }()
        let body = "FromDate=\(dateFormatter.string(from: start))&ToDate=\(dateFormatter.string(from: end))"
        request.httpBody = body.data(using: .utf8)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let (data, resp) = try await URLSession.shared.data(for: request, delegate: nil)
        if let http = resp as? HTTPURLResponse {
            print("Export POST status: \(http.statusCode)")
            print("Headers: \(http.allHeaderFields)")
            print("Body: \(String(data: data, encoding: .utf8) ?? "<binary>")")
        }
        guard let http = resp as? HTTPURLResponse, http.statusCode == 302,
              let loc = http.allHeaderFields["Location"] as? String,
              let zipLoc = URL(string: loc) else {
            throw URLError(.badServerResponse)
        }
        // Download ZIP.
        let (zipTmp, _) = try await URLSession.shared.download(from: zipLoc)
        // Move to caches.
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let dest = caches.appendingPathComponent("tp_export.zip")
        try? FileManager.default.removeItem(at: dest)
        try FileManager.default.moveItem(at: zipTmp, to: dest)
        return dest
    }
}
