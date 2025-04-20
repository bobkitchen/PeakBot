 import Foundation
import SwiftCSV

enum CSVWorkoutParser {
    /// Parse the Intervals.icu CSV into our `[Workout]`
    static func parse(_ csvText: String) throws -> [Workout] {
        // 1) explicitly pick the “Named” row view
        let csvFile = try CSV<Named>(string: csvText)

        // 2) dump the header once so you can see what really came back
        if let header = csvFile.header as? [String] {
            print("[CSVWorkoutParser] header columns →", header)
        }

        var workouts: [Workout] = []

        // 3) try your known‑good date formats
        let dateFormats = [
            "yyyy-MM-dd'T'HH:mm:ssXXXXX",
            "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd HH:mm",
            "yyyy-MM-dd"
        ]

        for (i, row) in csvFile.rows.enumerated() {
            // Debug: Print the first 5 rows to verify field content
            if i < 5 { print("[CSVWorkoutParser] Row \(i):", row) }
            let idRaw = row["id"] ?? ""
            let typeRaw = row["type"] ?? ""
            let tssRaw = row["tss"] ?? ""
            let id = idRaw.trimmingCharacters(in: .whitespacesAndNewlines)
            let sport = typeRaw.trimmingCharacters(in: .whitespacesAndNewlines)
            let tssStr = tssRaw.trimmingCharacters(in: .whitespacesAndNewlines)
            if i < 5 {
                print("[CSVWorkoutParser] Row \(i) fields: id=\(id), type=\(sport), tss=\(tssStr)")
            }
            guard !id.isEmpty, !sport.isEmpty, let tss = Double(tssStr) else {
                print("[CSVWorkoutParser] Skipping row \(i): missing or invalid required fields")
                continue
            }

            // pick “start_date_local” if present
            let dateString = (row["start_date_local"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            // try to parse into Date
            let date = dateFormats.compactMap { fmt -> Date? in
                let df = DateFormatter()
                df.locale = Locale(identifier: "en_US_POSIX")
                df.dateFormat = fmt
                return df.date(from: dateString)
            }.first

            if date == nil {
                print("[CSVWorkoutParser] ⚠️ could not parse date for row \(i): \(dateString)")
            }
            guard let workoutDate = date else { continue }

            // build and collect
            let w = Workout(
                id:   id,
                date: workoutDate,
                sport: sport,
                tss:   tss,
                ctl:   0,
                atl:   0
            )
            workouts.append(w)
        }

        print("[CSVWorkoutParser] Parsed \(workouts.count) workouts.")
        return workouts
    }
}
