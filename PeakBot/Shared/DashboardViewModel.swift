//
//  DashboardViewModel.swift
//  PeakBot
//
//  Created by Bob Kitchen on 4/19/25.
//


//
//  DashboardViewModel.swift
//  PeakBot
//

import Foundation
import SwiftUI

@MainActor
final class DashboardViewModel: ObservableObject {

    // MARK: – Published state
    @Published var fitness: [FitnessPoint] = []
    @Published var workouts: [Workout] = [] {
        didSet {
            // Optionally update fitness if you want to recalc from workouts, but we now fetch from API
        }
    }
    @Published var errorMessage: String? = nil

    // MARK: – Dependencies
    // IntervalsAPIService is now fully disabled and removed

    // MARK: – Initializer
    init() {}

    // MARK: – Public API
    // Intervals API refresh is now disabled. Implement Strava-based fitness refresh here if needed.
    func refresh(days: Int = 90) async {
        // No-op: Intervals API integration removed
        fitness = []
    }

    func updateWorkouts(_ newWorkouts: [Workout]) {
        self.workouts = newWorkouts
    }
}