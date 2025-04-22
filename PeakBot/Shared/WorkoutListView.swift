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

/// Detail view of a workout
struct WorkoutDetailView: View {
    let workout: Workout
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(workout.name).font(.title2).bold()
            Text("Date: \(workout.startDateLocal, formatter: dateFormatter)")
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// List of recent workouts (placeholder)
struct WorkoutListView: View {
    @EnvironmentObject var workoutListVM: WorkoutListViewModel
    @EnvironmentObject var dashboardVM: DashboardViewModel
    @State private var errorMessage: String? = nil
    @State private var selectedWorkoutDetail: Workout? = nil

    @AppStorage("userFTP") var userFTP: Double = 250
    @AppStorage("tssEdits") var tssEditsData: Data = Data()
    @State private var tssEdits: [Int: Double] = [:]

    func saveTSSEdits() {
        if let data = try? JSONEncoder().encode(tssEdits) {
            tssEditsData = data
        }
    }
    func loadTSSEdits() {
        if let dict = try? JSONDecoder().decode([Int: Double].self, from: tssEditsData) {
            tssEdits = dict
        }
    }

    func autoTSS(for workout: StravaService.StravaActivityDetail) -> Double {
        guard let avgPower = workout.weightedAverageWatts ?? workout.averageWatts,
              let movingTime = workout.movingTime else { return 0 }
        let ftp = userFTP
        let hours = Double(movingTime) / 3600.0
        let intensity = avgPower / ftp
        return hours * intensity * intensity * 100
    }

    func tssValue(for workout: StravaService.StravaActivityDetail) -> Double {
        if let manual = tssEdits[workout.id] {
            return manual
        } else if let existing = workout.tss {
            return existing
        } else {
            return autoTSS(for: workout)
        }
    }

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

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 64))
            Text("Workouts")
                .font(.title)
            if let error = errorMessage {
                Text("⚠️ Workouts error: \(error)")
                    .foregroundColor(.red)
            }
            if workoutListVM.stravaRateLimitHit {
                Text("⚠️ Strava API rate limit reached. Please try again in 15 minutes.")
                    .foregroundColor(.orange)
            }
            if workoutListVM.workouts.isEmpty {
                Text("No workouts found.")
            } else {
                HStack {
                    List(workoutListVM.workouts, id: \.id, selection: $selectedWorkoutDetail) { workout in
                        VStack(alignment: .leading) {
                            Text(workout.name).bold()
                            Text("Date: \(workout.startDateLocal, formatter: dateFormatter)")
                            if let distance = workout.distance {
                                Text("Distance: \(distance/1000, specifier: "%.2f") km")
                            }
                            if let movingTime = workout.movingTime {
                                Text("Moving Time: \(formatSeconds(movingTime))")
                            }
                            if let watts = workout.averageWatts {
                                Text("Avg Power: \(watts, specifier: "%.0f") W")
                            }
                            if let hr = workout.averageHeartrate {
                                Text("Avg HR: \(hr, specifier: "%.0f") bpm")
                            }
                            if let maxHr = workout.maxHeartrate {
                                Text("Max HR: \(maxHr, specifier: "%.0f") bpm")
                            }
                            if let tss = workout.tss {
                                Text("TSS: \(Int(tss))")
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedWorkoutDetail = workout
                        }
                    }
                    .frame(maxHeight: 300)
                    .frame(width: 250)
                    if let selected = selectedWorkoutDetail {
                        VStack(alignment: .leading, spacing: 16) {
                            Text(selected.name).font(.title2).bold()
                            Text("Date: \(selected.startDateLocal, formatter: dateFormatter)")
                            if let distance = selected.distance {
                                Text("Distance: \(distance/1000, specifier: "%.2f") km")
                            }
                            if let movingTime = selected.movingTime {
                                Text("Moving Time: \(formatSeconds(movingTime))")
                            }
                            if let watts = selected.averageWatts {
                                Text("Avg Power: \(watts, specifier: "%.0f") W")
                            }
                            if let hr = selected.averageHeartrate {
                                Text("Avg HR: \(hr, specifier: "%.0f") bpm")
                            }
                            if let maxHr = selected.maxHeartrate {
                                Text("Max HR: \(maxHr, specifier: "%.0f") bpm")
                            }
                            if let tss = selected.tss {
                                Text("TSS: \(Int(tss))")
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.windowBackground)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    Task {
                        await workoutListVM.refreshDetailed()
                    }
                }) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
        }
        .onAppear {
            print("[WorkoutListView] onAppear. Calling refreshDetailed()...")
            loadTSSEdits()
            Task {
                await workoutListVM.refreshDetailed()
            }
        }
    }
}
