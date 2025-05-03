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
    @Published var stravaRateLimitHit: Bool = false
    @Published var refreshEnabled: Bool = false

    // MARK: – Dependency
    var dashboardVM: DashboardViewModel?
    private var trainingPeaksService: TrainingPeaksService?
    private var workoutsCancellable: AnyCancellable?

    // Designated initialiser (used by preview / tests too)
    init(dashboardVM: DashboardViewModel? = nil, trainingPeaksService: TrainingPeaksService? = nil) {
        self.dashboardVM = dashboardVM
        self.trainingPeaksService = trainingPeaksService
        if let service = trainingPeaksService {
            workoutsCancellable = service.$workouts.sink { [weak self] newWorkouts in
                self?.workouts = newWorkouts
            }
        }
    }

    // MARK: – Public API ------------------------------------------------------

    /// Pull the latest workouts from the specified date.
    func refresh(daysBack: Int = 30) async {
        print("[WorkoutListViewModel] refresh() called (TrainingPeaks)")
        Task {
            do { try await TPConnector.shared.syncLatest(limit: 20) }
            catch { print("TP sync failed →", error) }
        }
    }
}

extension Workout {
    var allFields: [(String, Any?)] {
        return [
            ("id", id),
            ("name", name),
            ("startDateLocal", startDateLocal),
            ("distance", distance),
            ("movingTime", movingTime)
        ]
    }
}
