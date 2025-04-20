import Foundation

/// One daily CTL/ATL/TSB sample for the trend chart.
struct FitnessPoint: Identifiable, Codable, Hashable {
    let id: UUID
    let date: Date
    let ctl:  Double
    let atl:  Double
    let tsb:  Double
}
