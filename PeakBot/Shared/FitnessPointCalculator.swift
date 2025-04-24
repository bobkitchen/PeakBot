//
//  FitnessPointCalculator.swift
//  PeakBot
//
//  Created by Bob Kitchen on 4/19/25.
//

import Foundation

/// Produces CTL / ATL / TSB trend points from parsed workouts.
/// Implements a simple impulse-response model for training load.
enum FitnessPointCalculator {
    static func trend(from workouts: [Workout], days: Int) -> [FitnessPoint] {
        guard !workouts.isEmpty else { return [] }
        // Sort workouts by date ascending
        let sorted = workouts.sorted { $0.startDateLocal < $1.startDateLocal }
        // Calculate the earliest date to include
        let endDate = sorted.last?.startDateLocal ?? .distantPast
        let startDate = Calendar.current.date(byAdding: .day, value: -days+1, to: endDate) ?? endDate
        let recent = sorted.filter { $0.startDateLocal >= startDate }
        // Build daily buckets for the last `days`
        var dailyTSS: [Date: Double] = [:]
        for w in recent {
            let date = w.startDateLocal
            let day = Calendar.current.startOfDay(for: date)
            // Use only movingTime for now, as tss and sufferScore are not present
            let tss = 0.0
            dailyTSS[day, default: 0] += tss
        }
        // CTL/ATL impulse-response params
        let ctlTimeConstant = 42.0
        let atlTimeConstant = 7.0
        var ctl = 0.0, atl = 0.0
        var points: [FitnessPoint] = []
        var date = startDate
        while date <= endDate {
            let tss = dailyTSS[date] ?? 0
            ctl += (tss - ctl) / ctlTimeConstant
            atl += (tss - atl) / atlTimeConstant
            let tsb = ctl - atl
            points.append(FitnessPoint(id: UUID(), date: date, ctl: ctl, atl: atl, tsb: tsb))
            date = Calendar.current.date(byAdding: .day, value: 1, to: date) ?? date
        }
        return points
    }
    
    /// Estimate TSS from power/duration/HR if both tss and sufferScore are missing
    static func estimateTSS(for workout: Workout) -> Double {
        // No power-based estimate possible, return 0
        return 0
    }
}