import Foundation

/// One daily CTL/ATL/TSB sample for the trend chart.
struct FitnessPoint: Identifiable, Codable, Hashable {
    let id: UUID
    let date: Date
    let ctl:  Double
    let atl:  Double
    let tsb:  Double
    
    init(id: UUID = UUID(), date: Date, ctl: Double, atl: Double, tsb: Double) {
        self.id = id
        self.date = date
        self.ctl = ctl
        self.atl = atl
        self.tsb = tsb
    }
}
