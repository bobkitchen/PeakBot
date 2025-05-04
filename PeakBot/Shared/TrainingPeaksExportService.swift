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

        var daysBack: Int {
            switch self {
            case .days(let n): return n
            case .custom(let start, let end):
                let diff = Calendar.current.dateComponents([.day], from: start, to: end).day ?? 1
                return max(1, diff)
            }
        }
    }

    /// Sync wrapper used by the UI.
    func sync(range: Range = .days(1), trainingPeaksService: TrainingPeaksService) async {
        // NEW: Use TPConnector for FIT sync, not legacy export POST
        trainingPeaksService.isSyncing = true
        trainingPeaksService.errorMessage = nil
        await trainingPeaksService.syncLatestWorkouts(daysBack: range.daysBack)
        trainingPeaksService.lastSyncDate = Date()
        trainingPeaksService.errorMessage = nil
        trainingPeaksService.isSyncing = false
    }
}
