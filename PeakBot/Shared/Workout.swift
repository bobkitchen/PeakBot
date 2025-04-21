import Foundation

/// Activity model matching Intervals.icu /activities JSON response.
struct Workout: Identifiable, Hashable, Codable {
    let id: String
    let startDateLocal: Date
    let type: String
    let tss: Double?        // aka "training load"
    let ctl: Double?
    let atl: Double?
    let averageHR: Double?
    let maxHR: Double?
    let averagePower: Double?

    var date: Date? {
        startDateLocal
    }

    enum CodingKeys: String, CodingKey {
        case id
        case startDateLocal    = "start_date_local"
        case type
        case tss                = "icu_training_load"
        case ctl                = "icu_ctl"
        case atl                = "icu_atl"
        case averageHR          = "average_heartrate"
        case maxHR              = "max_heartrate"
        case averagePower       = "average_watts"
    }
}
