// TPBackgroundSync.swift
// macOS: No BGTaskScheduler; use direct call or Timer
import Foundation

/// Call this at app launch or on a schedule to sync TrainingPeaks workouts.
func syncTrainingPeaksNow() {
    Task {
        do {
            try await TPConnector.shared.syncLatest()
        } catch {
            print("TP sync error:", error)
        }
    }
}
