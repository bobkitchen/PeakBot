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
    @Published var detailedWorkouts: [StravaService.StravaActivityDetail] = []
    @Published var errorMessage: String?
    @Published var stravaRateLimitHit: Bool = false

    // MARK: – Dependency
    var dashboardVM: DashboardViewModel?
    var stravaService: StravaService?

    // TODO: Replace with StravaService once implemented
    // private let service: IntervalsAPIService
    // init(service: IntervalsAPIService, dashboardVM: DashboardViewModel? = nil) { ... }

    // Placeholder for Strava integration
    // Add StravaService reference in next phase

    // Designated initialiser (used by preview / tests too)
    init(dashboardVM: DashboardViewModel? = nil) {
        self.dashboardVM = dashboardVM
    }

    // MARK: – Public API ------------------------------------------------------

    /// Pull the latest workouts from the specified date.
    func refresh(daysBack: Int = 30) async {
        print("[WorkoutListViewModel] refresh() called (Strava)")
        guard let stravaService = stravaService else {
            errorMessage = "Strava service unavailable"
            return
        }
        do {
            let activities = try await stravaService.fetchActivities(perPage: 50)
            // Convert StravaActivitySummary to Workout
            let workouts = activities.map { activity in
                Workout(
                    id: String(activity.id),
                    name: activity.name ?? "Unknown",
                    startDateLocal: activity.startDateLocal ?? Date(),
                    distance: activity.distance,
                    movingTime: activity.movingTime,
                    averageWatts: activity.averageWatts,
                    averageHeartrate: activity.averageHeartrate,
                    maxHeartrate: activity.maxHeartrate,
                    tss: activity.tss,
                    sufferScore: nil // Not available in StravaActivitySummary
                )
            }
            self.workouts = workouts
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Pull the latest detailed workouts from Strava for the last 90 days.
    func refreshDetailed() async {
        stravaRateLimitHit = false
        print("[WorkoutListViewModel] refreshDetailed() called (Strava)")
        guard let stravaService = stravaService else {
            errorMessage = "Strava service unavailable"
            return
        }
        do {
            let details = try await stravaService.fetchDetailedActivities(lastNDays: 90)
            self.detailedWorkouts = details
            errorMessage = nil
        } catch {
            if let nsError = error as NSError?,
               nsError.localizedDescription.contains("Rate Limit Exceeded") {
                self.stravaRateLimitHit = true
            } else {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: – Private plumbing -----------------------------------------------
    // Legacy CSV workflow removed. No longer needed.

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
