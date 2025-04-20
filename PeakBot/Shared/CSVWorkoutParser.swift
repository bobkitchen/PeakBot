import Foundation

enum CSVWorkoutParser {

    /// VERY naive CSV parser good enough for the demo – returns 0 workouts if the CSV header isn’t what we expect.
    static func parse(_ csv: String) throws -> [Workout] {
        let rows = csv.split(separator: "\n")
        guard rows.count > 1 else { return [] }
        let header = rows.first!.split(separator: ",").map(String.init)
        guard let idIdx = header.firstIndex(of: "id"),
              let dateIdx = header.firstIndex(of: "start_time_local"),
              let sportIdx = header.firstIndex(of: "sport"),
              let tssIdx = header.firstIndex(of: "tss")
        else {
            print("[CSVWorkoutParser] Could not find required columns in header: \(header)")
            return []
        }

        var workouts: [Workout] = []
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds, .withColonSeparatorInTime]
        for line in rows.dropFirst() {
            let cols = line.split(separator: ",").map(String.init)
            guard cols.count >= header.count else { continue }
            guard let date = fmt.date(from: cols[dateIdx]) else {
                print("[CSVWorkoutParser] Could not parse date: \(cols[dateIdx])")
                continue
            }
            let w = Workout(id: cols[idIdx],
                            date: date,
                            sport: cols[sportIdx],
                            tss: Double(cols[tssIdx]) ?? 0,
                            ctl: 0, atl: 0)
            workouts.append(w)
        }
        return workouts
    }
}
