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
        let sorted = workouts.sorted { $0.date < $1.date }
        // Build daily buckets for the last `days`
        let endDate = sorted.last!.date
        let startDate = Calendar.current.date(byAdding: .day, value: -days+1, to: endDate) ?? endDate
        var dailyTSS: [Date: Double] = [:]
        for w in sorted {
            let day = Calendar.current.startOfDay(for: w.date)
            dailyTSS[day, default: 0] += w.tss ?? 0
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
}