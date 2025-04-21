import Foundation

// Deprecated: Use Workout.swift for activity details.
// This file is retained for reference only.
@available(*, deprecated, message: "Use Workout struct instead.")
struct ActivityDetail: Decodable {
    let id: Int
    let avg_hr, max_hr, avg_power: Double?
}
