import Foundation

/// Simple impulse–response model (ATL 7 d, CTL 42 d)
enum FitnessPointCalculator {
    static func trend(from workouts: [Workout], days: Int) -> [FitnessPoint] {
        guard !workouts.isEmpty else { return [] }

        let sorted = workouts.sorted { $0.startDate < $1.startDate }
        let end    = sorted.last?.startDate ?? .distantPast
        let start  = Calendar.current.date(byAdding: .day, value: -days + 1, to: end) ?? end
        let recent = sorted.filter { $0.startDate >= start }

        var dailyTSS: [Date: Double] = [:]
        for w in recent {
            let d = Calendar.current.startOfDay(for: w.startDate)
            let tssValue = (w.tss as? Double) ?? w.tss?.doubleValue ?? 0.0
            dailyTSS[d, default: 0.0] += tssValue
        }

        let τc = 42.0, τa = 7.0
        var ctl = 0.0, atl = 0.0
        var pts: [FitnessPoint] = []

        var day = start
        while day <= end {
            let tss = dailyTSS[day] ?? 0
            ctl += (tss - ctl) / τc
            atl += (tss - atl) / τa
            pts.append(.init(id: UUID(), date: day, ctl: ctl, atl: atl, tsb: ctl - atl))
            day = Calendar.current.date(byAdding: .day, value: 1, to: day)!
        }
        return pts
    }
}