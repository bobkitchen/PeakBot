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
    @Published var workouts: [Workout] = [] {
        didSet {
            dashboardVM?.updateWorkouts(workouts)
        }
    }
    @Published var errorMessage: String?

    // MARK: – Dependency
    private let service: IntervalsAPIService
    var dashboardVM: DashboardViewModel?

    // Designated initialiser (used by preview / tests too)
    init(service: IntervalsAPIService, dashboardVM: DashboardViewModel? = nil) {
        self.service = service
        self.dashboardVM = dashboardVM
    }

    // Convenience init removed: always inject the service dependency from above.

    // MARK: – Public API ------------------------------------------------------

    /// Pull the latest *daysBack* days worth of activities.
    func refresh(daysBack: Int = 14) async {
        print("[WorkoutListViewModel] refresh() called (JSON)")
        do {
            let parsed = try await service.fetchWorkoutsJSON(daysBack: daysBack)
            print("[WorkoutListViewModel] Parsed \(parsed.count) workouts from JSON.") // DEBUG
            workouts = parsed
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
