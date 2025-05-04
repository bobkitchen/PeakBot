// StreamSet.swift
// PeakBot
//
// Created by Bob Kitchen on 4/20/25.
//
// All IntervalsICU and TrainingPeaks references removed for Strava-only version.

import Foundation

/// Parsed activity streams returned by (time, HR, power)
struct StreamSet {
    var time:   [TimeInterval]
    var hr:     [Int]?
    var power:  [Int]?
}
