//
//  FitnessPointCalculator.swift
//  PeakBot
//
//  Re-written to mirror TrainingPeaks PMC math exactly.
//

import Foundation

enum FitnessPointCalculator {

    static func trend(from workouts: [Workout],
                      athleteTZ: TimeZone,
                      range days: Int? = nil) -> [FitnessPoint] {

        guard !workouts.isEmpty else { return [] }

        // ---- 1 Daily TSS buckets in athlete TZ ----------------------------
        let cal = Calendar(identifier: .gregorian)
        var daily: [Date: Double] = [:]

        for w in workouts where w.startDate != nil && w.tss != nil {
            let key = cal.startOfDay(for: w.startDate!, in: athleteTZ)
            daily[key, default: 0] += w.tss!.doubleValue
        }

        let sortedDays = daily.keys.sorted()
        guard let first = sortedDays.first, let last = sortedDays.last else { return [] }

        let start: Date = {
            guard let d = days else { return first }
            return cal.date(byAdding: .day, value: -d + 1, to: last, in: athleteTZ)!
        }()

        // ---- 2 Exponential impulse–response (TP) --------------------------
        let kATL = 1.0 - exp(-1.0 / 7.0)
        let kCTL = 1.0 - exp(-1.0 / 42.0)

        var atlPrev = 0.0, ctlPrev = 0.0
        var pts: [FitnessPoint] = []

        var cursor = start
        while cursor <= last {
            let tss = daily[cursor] ?? 0.0
            let atl = atlPrev + kATL * (tss - atlPrev)
            let ctl = ctlPrev + kCTL * (tss - ctlPrev)
            let tsb = ctlPrev - atlPrev        // yesterday’s balance

            pts.append(.init(date: cursor, ctl: ctl, atl: atl, tsb: tsb))

            atlPrev = atl
            ctlPrev = ctl
            cursor  = cal.date(byAdding: .day, value: 1, to: cursor, in: athleteTZ)!
        }
        return pts
    }
}

// MARK: - Calendar helpers
private extension Calendar {
    func startOfDay(for d: Date, in tz: TimeZone) -> Date {
        var c = dateComponents(in: tz, from: d)
        c.hour = 0; c.minute = 0; c.second = 0; c.nanosecond = 0
        return date(from: c)!
    }
    func date(byAdding comp: Component, value: Int, to d: Date, in tz: TimeZone) -> Date? {
        var c = dateComponents(in: tz, from: d)
        if comp == .day { c.day! += value }
        return date(from: c)
    }
}