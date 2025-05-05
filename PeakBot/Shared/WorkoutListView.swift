//
//  WorkoutListView.swift
//  PeakBot
//
//  Created by Bob Kitchen on 4/19/25.
//

import SwiftUI

private let dateFormatter: DateFormatter = {
    let df = DateFormatter()
    df.dateStyle = .medium
    df.timeStyle = .short
    return df
}()

func formatSeconds(_ seconds: Int) -> String {
    let hours = seconds / 3600
    let minutes = (seconds % 3600) / 60
    let secs = seconds % 60
    if hours > 0 {
        return String(format: "%d:%02d:%02d", hours, minutes, secs)
    } else {
        return String(format: "%d:%02d", minutes, secs)
    }
}

struct WorkoutRowView: View {
    let workout: Workout
    var body: some View {
        VStack(alignment: .leading) {
            Text(workout.name ?? "Unnamed Workout")
                .font(.headline)
            Text(workout.startDate != nil ? "\(workout.startDate!, formatter: dateFormatter)" : "N/A")
                .font(.subheadline)
            Text("Distance: \(workout.distance?.doubleValue ?? 0, specifier: "%.2f") km")
                .font(.caption)
            Text("Moving Time: \(formatSeconds(Int(workout.movingTime ?? 0)))")
                .font(.caption2)
        }
    }
}

struct WorkoutListView: View {
    @ObservedObject var viewModel: WorkoutListViewModel
    @EnvironmentObject var stravaService: StravaService
    @State private var showSyncing = false
    @State private var syncError: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Workouts")
                    .font(.largeTitle)
                    .bold()
                Spacer()
                Button(action: {
                    showSyncing = true
                    syncError = nil
                    Task {
                        do {
                            try await stravaService.syncRecentActivities()
                            viewModel.refresh()
                        } catch {
                            syncError = error.localizedDescription
                        }
                        showSyncing = false
                    }
                }) {
                    Label("Sync", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderedProminent)
                .tint(.accentColor)
                .disabled(showSyncing)
            }
            .padding([.top, .horizontal])
            if showSyncing {
                ProgressView("Syncing...")
                    .padding(.horizontal)
            }
            if let syncError = syncError {
                Text(syncError)
                    .foregroundColor(.red)
                    .font(.callout)
                    .padding(.horizontal)
            }
            if viewModel.workouts.isEmpty {
                Text("No workouts available.")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                List(viewModel.workouts, id: \.workoutId) { workout in
                    VStack(alignment: .leading) {
                        Text(workout.name ?? "Unnamed Workout")
                            .font(.headline)
                        Text(workout.startDate != nil ? "\(workout.startDate!, formatter: dateFormatter)" : "N/A")
                            .font(.subheadline)
                        Text("Distance: \((workout.distance?.doubleValue ?? 0) / 1000, specifier: "%.2f") km")
                            .font(.caption)
                        Text("Moving Time: \(formatSeconds(Int(workout.movingTime ?? 0)))")
                            .font(.caption2)
                        Text("Avg Power: \(workout.avgPower?.doubleValue ?? 0, specifier: "%.0f")")
                            .font(.caption)
                        Text("TSS: \(workout.tss?.doubleValue ?? 0, specifier: "%.1f")")
                            .font(.caption)
                    }
                }
            }
        }
    }
}
