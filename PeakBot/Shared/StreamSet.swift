import Foundation

/// Parsed activity streams returned by (time, HR, power)
// Removed IntervalsICU reference for TrainingPeaks transition
struct StreamSet {
    var time:   [TimeInterval]
    var hr:     [Int]?
    var power:  [Int]?
}
