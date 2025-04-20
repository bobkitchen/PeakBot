//
//  WorkoutListViewModel.swift
//  PeakBot
//
//  Re‑written 20 Apr 2025 – fixes access level & actor isolation
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class WorkoutListViewModel: ObservableObject {

    // MARK: – Published state
    @Published var workouts: [Workout] = []
    @Published var errorMessage: String?

    // MARK: – Dependency
    private let service: IntervalsAPIService

    // Designated initialiser (used by preview / tests too)
    init(service: IntervalsAPIService) {
        self.service = service
    }

    // Convenience init removed: always inject the service dependency from above.

    // MARK: – Public API ------------------------------------------------------

    /// Pull the latest *daysBack* days worth of activities.
    func refresh(daysBack: Int = 14) async {
        print("[WorkoutListViewModel] refresh() called")
        do {
            let csv = try await service.fetchActivitiesCSV(daysBack: daysBack)
            print("[WorkoutListViewModel] Got CSV (first 500 chars): \(csv.prefix(500))")
            if let firstLine = csv.split(separator: "\n").first {
                print("[WorkoutListViewModel] CSV Header: \(firstLine)")
            }
            let parsed  = try CSVWorkoutParser.parse(csv)
            workouts    = parsed
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: – Private plumbing -----------------------------------------------

    /// Wrapper that simply forwards to the service.
    /// *Not* private so Dashboard VM can reuse it if desired.
    func fetchActivitiesCSV(daysBack: Int = 14) async throws -> String {
        try await service.fetchActivitiesCSV(daysBack: daysBack)
    }
}
