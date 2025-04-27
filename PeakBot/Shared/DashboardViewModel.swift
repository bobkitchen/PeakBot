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
    @Published var refreshEnabled: Bool = false

    // MARK: – Dependencies

    // MARK: – Initializer
    init() {}

    // MARK: – Public API
    func updateWorkouts(_ newWorkouts: [Workout]) {
        self.workouts = newWorkouts
    }
}