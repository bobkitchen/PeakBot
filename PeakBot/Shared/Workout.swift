import Foundation

/// Activity model matching Intervals.icu /activities JSON response.
struct Workout: Identifiable, Hashable, Codable {
    let id:              Int
    let start_date_local: String
    let type:            String
    let tss:             Double?
    let ctl:             Double?
    let atl:             Double?
    let avg_hr:          Double?
    let max_hr:          Double?
    let avg_power:       Double?
    // Add more fields as needed from the JSON response

    var date: Date? {
        ISO8601DateFormatter().date(from: start_date_local)
    }
}
