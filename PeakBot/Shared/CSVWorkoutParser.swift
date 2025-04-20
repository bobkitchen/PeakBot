 import Foundation
import SwiftCSV

enum CSVWorkoutParser {
    /// Parse the Intervals.icu CSV into our `[Workout]`
    static func parse(_ csvText: String) throws -> [Workout] {
        let csvFile = try CSV<Named>(string: csvText)
        let header = csvFile.header
        print("[CSVWorkoutParser] columns →", header)
        var workouts: [Workout] = []
        let isoFormatter = ISO8601DateFormatter()
        let tFormatter: DateFormatter = {
            let df = DateFormatter()
            df.locale = Locale(identifier: "en_US_POSIX")
            df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            return df
        }()
        let fallbackFormatter: DateFormatter = {
            let df = DateFormatter()
            df.locale = Locale(identifier: "en_US_POSIX")
            df.dateFormat = "yyyy-MM-dd HH:mm:ss"
            return df
        }()
        for (i, row) in csvFile.rows.enumerated() {
            guard
                let idStr = row["id"], !idStr.isEmpty,
                let sport = row["type"], !sport.isEmpty,
                let dateStr = row["start_date_local"], !dateStr.isEmpty
            else {
                print("[CSVWorkoutParser] skipping row: missing id/type/date")
                continue
            }
            // Print the raw date string for debugging
            print("[CSVWorkoutParser] Raw date string: \(dateStr)")
            var date: Date? = isoFormatter.date(from: dateStr)
            if date == nil {
                date = tFormatter.date(from: dateStr)
            }
            if date == nil {
                date = fallbackFormatter.date(from: dateStr)
            }
            if date == nil {
                print("[CSVWorkoutParser] invalid date:", dateStr)
                continue
            }
            // Optionally parse TSS, CTL, ATL if present
            let tss = Double(row["tss"] ?? "")
            let ctl = Double(row["ctl"] ?? "")
            let atl = Double(row["atl"] ?? "")
            let workout = Workout(
                id: idStr,
                date: date!,
                sport: sport,
                tss: tss,
                ctl: ctl,
                atl: atl
            )
            workouts.append(workout)
        }
        print("[CSVWorkoutParser] Parsed \(workouts.count) workouts.")
        return workouts
    }
}
