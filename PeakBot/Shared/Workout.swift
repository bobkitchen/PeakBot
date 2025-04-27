import Foundation

/// Activity model matching /activities JSON response.
// Removed Intervals.icu reference for TrainingPeaks transition
struct Workout: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let startDateLocal: Date
    let distance: Double?
    let movingTime: Int?
    // Comment out fields not currently supported by StravaActivityDetail
    // let averageWatts: Double?
    // let averageHeartrate: Double?
    // let maxHeartrate: Double?
    // let tss: Double?
    // let sufferScore: Double?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case startDateLocal    = "start_date_local"
        case distance
        case movingTime
        // Remove/comment out keys for fields not present
        // case averageWatts
        // case averageHeartrate
        // case maxHeartrate
        // case tss
        // case sufferScore = "suffer_score"
    }
}
