//
//  DashboardViewModel.swift
//  PeakBot
//
//  Created by Bob Kitchen on 4/19/25.
//

import Foundation
import SwiftUI
import CoreData

@MainActor
final class DashboardViewModel: ObservableObject {

    // Published state
    @AppStorage("athleteTimeZone") private var athleteTZString = TimeZone.current.identifier

    @Published var fitness:  [FitnessPoint] = []
    @Published var workouts: [Workout]      = [] {
        didSet { /* recalc here if you want */ }
    }
    @Published var errorMessage: String?

    // MARK: Public API
    func refresh(days: Int = 180) async {
        let context = CoreDataModel.shared.container.viewContext
        let end = Date()
        let start = Calendar.current.date(byAdding: .day, value: -days, to: end) ?? end
        let dlRequest = NSFetchRequest<DailyLoad>(entityName: "DailyLoad")
        dlRequest.predicate = NSPredicate(format: "date >= %@", start as NSDate)
        dlRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
        do {
            let dailyLoads = try context.fetch(dlRequest)
            print("[DEBUG] Fetched DailyLoad count: \(dailyLoads.count)")
            if dailyLoads.count < days || dailyLoads.isEmpty {
                // Always recalculate if missing any days
                let wRequest = NSFetchRequest<Workout>(entityName: "Workout")
                wRequest.predicate = NSPredicate(format: "startDate >= %@ AND tss != nil", start as NSDate)
                wRequest.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: true)]
                let workouts = try context.fetch(wRequest)
                print("[DEBUG] Fetched workouts count: \(workouts.count)")
                self.workouts = workouts
                let tz = TimeZone(identifier: athleteTZString) ?? .current
                let points = FitnessPointCalculator.trend(from: workouts, athleteTZ: tz, range: days)
                self.fitness = points
                // Remove old DailyLoad entries in range
                let oldLoads = try context.fetch(dlRequest)
                for o in oldLoads { context.delete(o) }
                // Save new DailyLoad entries, sum TSS for each day
                let calendar = Calendar.current
                for p in points {
                    let d = DailyLoad(context: context)
                    d.date = p.date
                    d.ctl = p.ctl
                    d.atl = p.atl
                    d.tsb = p.tsb
                    // Sum TSS for the day
                    let tssSum = workouts.filter {
                        $0.startDate != nil && calendar.isDate($0.startDate!, inSameDayAs: p.date) && $0.tss != nil
                    }.reduce(0.0) { $0 + ($1.tss?.doubleValue ?? 0.0) }
                    d.tss = tssSum
                }
                try context.save()
                print("[DEBUG] Saved new DailyLoad entries: \(points.count)")
            }
            // Always reload fitness from DailyLoad after possible update
            let reloaded = try context.fetch(dlRequest)
            print("[DEBUG] Reloaded DailyLoad count: \(reloaded.count)")
            self.fitness = reloaded.map { FitnessPoint(id: UUID(), date: $0.date, ctl: $0.ctl, atl: $0.atl, tsb: $0.tsb) }
        } catch {
            self.errorMessage = "Failed to fetch fitness data: \(error.localizedDescription)"
            print("[ERROR] \(self.errorMessage ?? "Unknown error")")
        }
    }

    /// Reload fitness points from existing DailyLoad entities without recalculation.
    func reloadDailyLoad(days: Int = 180) async {
        let context = CoreDataModel.shared.container.viewContext
        let calendar = Calendar(identifier: .gregorian)
        do {
            let wRequest = NSFetchRequest<Workout>(entityName: "Workout")
            wRequest.predicate = NSPredicate(format: "startDate != nil AND tss != nil")
            wRequest.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: true)]
            let workouts = try context.fetch(wRequest)
            self.workouts = workouts

            let tz = TimeZone(identifier: athleteTZString) ?? .current
            let points = FitnessPointCalculator.trend(from: workouts, athleteTZ: tz, range: days)
            self.fitness = points

            // Save new DailyLoad entries, sum TSS for each day
            let dlRequest = NSFetchRequest<DailyLoad>(entityName: "DailyLoad")
            let oldLoads = try context.fetch(dlRequest)
            for o in oldLoads { context.delete(o) }
            for p in points {
                let d = DailyLoad(context: context)
                d.date = p.date
                d.ctl = p.ctl
                d.atl = p.atl
                d.tsb = p.tsb
                // Sum TSS for the day
                let tssSum = workouts.filter {
                    $0.startDate != nil && calendar.isDate($0.startDate!, inSameDayAs: p.date) && $0.tss != nil
                }.reduce(0.0) { $0 + ($1.tss?.doubleValue ?? 0.0) }
                d.tss = tssSum
            }
            try context.save()
        } catch {
            self.errorMessage = "Failed to fetch fitness data: \(error.localizedDescription)"
            print("[ERROR] \(self.errorMessage ?? "Unknown error")")
        }
    }

    func updateWorkouts(_ w: [Workout]) { workouts = w }
}