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

// Move formatSeconds to the top so it is in scope for all views
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

/// Detail view of a workout
struct WorkoutDetailView: View {
    let workout: StravaService.StravaActivityDetail
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(workout.name).font(.title2).bold()
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
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// List of recent workouts (placeholder)
struct WorkoutListView: View {
    @EnvironmentObject var workoutListVM: WorkoutListViewModel
    @State private var selectedWorkoutID: String? = nil
    @State private var selectedDetail: StravaService.StravaActivityDetail?
    @State private var isLoadingDetail = false
    @State private var errorMessage: String? = nil
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

    func npValue(for workout: StravaService.StravaActivityDetail) -> Double? {
        return workout.normalizedPower
    }

    func ifValue(for workout: StravaService.StravaActivityDetail) -> Double? {
        return workout.intensityFactor
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedWorkoutID) {
                ForEach(workoutListVM.workouts, id: \.id) { workout in
                    Text(workout.name)
                        .tag(workout.id as String?)
                }
            }
            .navigationTitle("")
        } detail: {
            Group {
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                } else if isLoadingDetail {
                    ProgressView("Loading workout details…")
                } else if let detail = selectedDetail {
                    WorkoutDetailView(workout: detail)
                } else if let selectedID = selectedWorkoutID,
                          let workout = workoutListVM.workouts.first(where: { $0.id == selectedID }) {
                    Text("Select a workout to see details")
                        .foregroundColor(.secondary)
                } else {
                    Text("No workout selected")
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onChange(of: selectedWorkoutID) { newID in
            guard let id = newID,
                  let workout = workoutListVM.workouts.first(where: { $0.id == id }) else { selectedDetail = nil; errorMessage = nil; return }
            Task {
                isLoadingDetail = true
                errorMessage = nil
                let detail = await workoutListVM.fetchDetail(for: workout)
                if let detail = detail {
                    selectedDetail = detail
                } else {
                    errorMessage = "Failed to load workout details."
                    selectedDetail = nil
                }
                isLoadingDetail = false
            }
        }
        .onAppear {
            Task { await workoutListVM.refresh() }
            loadTSSEdits()
        }
    }
}
