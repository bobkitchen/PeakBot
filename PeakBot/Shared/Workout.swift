import Foundation

/// Activity model matching Intervals.icu /activities JSON response.
struct Workout: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let startDateLocal: Date
    let distance: Double?
    let movingTime: Int?
    let averageWatts: Double?
    let averageHeartrate: Double?
    let maxHeartrate: Double?
    let tss: Double?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case startDateLocal    = "start_date_local"
        case distance
        case movingTime
        case averageWatts
        case averageHeartrate
        case maxHeartrate
        case tss
    }
}
