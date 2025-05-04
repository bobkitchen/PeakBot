// MetricsEngine.swift
// PeakBot
//
// Implements NP, IF, TSS calculations for Strava integration.

import Foundation

struct MetricsEngine {
    /// Calculate Normalized Power (NP) from power stream (watts)
    static func normalizedPower(from power: [Double]?) -> Double? {
        guard let power = power, power.count > 0 else { return nil }
        let window = 30
        let rolling = movingAverage(power, window: window)
        let fourth = rolling.map { pow($0, 4) }
        let mean = fourth.reduce(0, +) / Double(fourth.count)
        return pow(mean, 0.25)
    }
    /// Calculate Intensity Factor (IF)
    static func intensityFactor(np: Double?, ftp: Double) -> Double? {
        guard let np = np, ftp > 0 else { return nil }
        return np / ftp
    }
    /// Calculate Training Stress Score (TSS)
    static func tss(np: Double?, ifv: Double?, seconds: Double, ftp: Double) -> Double? {
        guard let np = np, let ifv = ifv, ftp > 0, seconds > 0 else { return nil }
        return (seconds * np * ifv) / (ftp * 3600) * 100
    }
    /// Simple moving average
    static func movingAverage(_ arr: [Double], window: Int) -> [Double] {
        guard arr.count >= window else { return [] }
        var result: [Double] = []
        var sum = arr.prefix(window).reduce(0, +)
        result.append(sum / Double(window))
        for i in window..<arr.count {
            sum += arr[i] - arr[i - window]
            result.append(sum / Double(window))
        }
        return result
    }
}
