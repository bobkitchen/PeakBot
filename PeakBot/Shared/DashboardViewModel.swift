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

    // MARK: – Dependency
    private let service: IntervalsAPIService
    init(service: IntervalsAPIService) { self.service = service }

    // MARK: – Public API
    func refresh(days: Int = 90) async {
        do {
            let pts = try await service.fetchWellnessJSON(daysBack: days)
            fitness = pts.reversed()          // oldest‑first for charts
        } catch {
            print("⚠️ Dashboard refresh failed:", error)
        }
    }

    func updateWorkouts(_ newWorkouts: [Workout]) {
        self.workouts = newWorkouts
    }
}