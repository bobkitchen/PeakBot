
import Foundation

/// Parsed activity streams returned by IntervalsICU (time, HR, power)
struct StreamSet {
    var time:   [TimeInterval]
    var hr:     [Int]?
    var power:  [Int]?
}
