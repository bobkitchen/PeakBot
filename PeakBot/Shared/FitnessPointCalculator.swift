import Foundation

struct FitnessPointCalculator {
    enum Weekdays: Int { case sun = 1 }

    static func trend(from workouts: [Workout], days: Int) -> [FitnessPoint] {
        guard !workouts.isEmpty else { print("[DEBUG] No workouts"); return [] }
        let sorted = workouts.filter { $0.startDate != nil && $0.tss != nil }
            .sorted { $0.startDate! < $1.startDate! }
        guard let first = sorted.first?.startDate, let end = sorted.last?.startDate else {
            print("[DEBUG] No valid workout dates"); return []
        }
        // Use the smaller of (days, range of workouts)
        let start = Calendar.current.date(byAdding: .day, value: -days + 1, to: end)! > first ? Calendar.current.date(byAdding: .day, value: -days + 1, to: end)! : first
        print("[DEBUG] FitnessPointCalculator range: \(start) to \(end)")
        let recent = sorted.filter { $0.startDate! >= start }

        var dailyTSS: [Date: Double] = [:]
        for w in recent {
            guard let startDate = w.startDate else { continue }
            let d = Calendar.current.startOfDay(for: startDate)
            let tssValue = w.tss?.doubleValue ?? 0.0
            dailyTSS[d, default: 0.0] += tssValue
        }

        // Calculation
        var ctl = 0.0, atl = 0.0
        var pts: [FitnessPoint] = []
        var day = Calendar.current.startOfDay(for: start)
        let endDay = Calendar.current.startOfDay(for: end)
        while day <= endDay {
            let tss = dailyTSS[day] ?? 0
            ctl += (tss - ctl) / 42.0
            atl += (tss - atl) / 7.0
            pts.append(.init(id: UUID(), date: day, ctl: ctl, atl: atl, tsb: ctl - atl))
            day = Calendar.current.date(byAdding: .day, value: 1, to: day)!
        }
        print("[DEBUG] FitnessPointCalculator produced \(pts.count) points")
        return pts
    }
}