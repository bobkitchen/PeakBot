//
//  WorkoutListViewModel.swift
//  PeakBot
//
//  Re‑written 20 Apr 2025 – fixes access level & actor isolation
//

import Foundation
import SwiftUI
import Combine
import CoreData
import os

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
    // Removed refreshEnabled; not needed for this VM

    // MARK: – Dependency
    var dashboardVM: DashboardViewModel?
    private var workoutsCancellable: AnyCancellable?
    private let coreData = CoreDataModel.shared

    // Designated initialiser (used by preview / tests too)
    init(dashboardVM: DashboardViewModel? = nil) {
        self.dashboardVM = dashboardVM
        fetchWorkoutsFromCoreData()
    }

    // MARK: – Public API ------------------------------------------------------

    /// Pull the latest workouts from Core Data
    func fetchWorkoutsFromCoreData() {
        let context = coreData.container.viewContext
        let request = NSFetchRequest<Workout>(entityName: "Workout")
        request.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: false)]
        request.predicate = NSPredicate(format: "workoutId != nil")
        do {
            workouts = try context.fetch(request)
            print("[DEBUG] Core Data fetch returned \(workouts.count) workouts")
            for w in workouts {
                print("[DEBUG] Workout: id=\(String(describing: w.workoutId)), name=\(w.name ?? "nil")")
            }
        } catch {
            errorMessage = "Failed to fetch workouts: \(error.localizedDescription)"
        }
    }

    /// Call this after sync or Core Data update
    func refresh() {
        fetchWorkoutsFromCoreData()
    }
}
