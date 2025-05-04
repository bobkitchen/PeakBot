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

    // Published state
    @Published var fitness:  [FitnessPoint] = []
    @Published var workouts: [Workout]      = [] {
        didSet { /* recalc here if you want */ }
    }
    @Published var errorMessage: String?

    // MARK: Public API
    func refresh(days: Int = 90) async {
        // Strava fetch will go here once StravaService is wired in
    }

    func updateWorkouts(_ w: [Workout]) { workouts = w }
}