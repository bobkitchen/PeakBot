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

    // MARK: – Public API ------------------------------------------------------

    /// Pull the latest workouts from the specified date.
    func refresh(oldest: String = "2024-01-01") async {
        print("[WorkoutListViewModel] refresh() called (JSON)")
        do {
            let parsed = try await service.fetchWorkoutsJSON(oldest: oldest)
            print("[WorkoutListViewModel] Parsed \(parsed.count) workouts from JSON.") // DEBUG
            workouts = parsed
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: – Private plumbing -----------------------------------------------
    // Legacy CSV workflow removed. No longer needed.

}
