import Foundation

struct NPIFCalculator {
    /// Calculate Normalized Power (NP) from a power stream (in watts)
    /// - Parameter power: Array of power values (watts)
    /// - Returns: Normalized Power (Double) or nil if stream is insufficient
    static func normalizedPower(from power: [Double]?) -> Double? {
        guard let power = power, power.count >= 30 else { return nil }
        // 30-second rolling average
        let window = 30
        var rollingAverages: [Double] = []
        for i in 0...(power.count - window) {
            let avg = power[i..<(i+window)].reduce(0, +) / Double(window)
            rollingAverages.append(avg)
        }
        // 4th power mean
        let fourthPowerMean = rollingAverages.map { pow($0, 4) }.reduce(0, +) / Double(rollingAverages.count)
        return pow(fourthPowerMean, 0.25)
    }

    /// Calculate Intensity Factor (IF)
    /// - Parameters:
    ///   - np: Normalized Power
    ///   - ftp: Functional Threshold Power
    /// - Returns: Intensity Factor (Double) or nil if ftp is invalid
    static func intensityFactor(np: Double?, ftp: Double?) -> Double? {
        guard let np = np, let ftp = ftp, ftp > 0 else { return nil }
        return np / ftp
    }
}
