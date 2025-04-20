//
//  WorkoutListViewModel.swift
//  PeakBot
//
//  Re‑written 20 Apr 2025 – fixes access level & actor isolation
//

import Foundation
import SwiftUI

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

    // Convenience init – the app calls this one
    convenience init() {
        self.init(service: .shared)
    }

    // MARK: – Public API ------------------------------------------------------

    /// Pull the latest *daysBack* days worth of activities.
    func refresh(daysBack: Int = 14) async {
        do {
            let csv     = try await fetchActivitiesCSV(daysBack: daysBack)
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
