
import Foundation

/// Very small PO‑model for one activity.
struct Workout: Identifiable, Hashable, Codable {
    let id:      String
    let date:    Date
    let sport:   String
    let tss:     Double
    let ctl:     Double
    let atl:     Double
}
