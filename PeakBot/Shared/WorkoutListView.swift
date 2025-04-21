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
            Text(workout.type).font(.title2).bold()
            if let date = workout.date {
                Text("Date: \(date, formatter: dateFormatter)")
            } else {
                Text("Date: Invalid").foregroundColor(.red)
            }
            Group {
                if let ctl = workout.ctl { Text("CTL: \(ctl, specifier: "%.1f")") }
                if let atl = workout.atl { Text("ATL: \(atl, specifier: "%.1f")") }
                if let tss = workout.tss { Text("TSS: \(tss, specifier: "%.1f")") }
                if let maxHR = workout.maxHR { Text("Max HR: \(maxHR, specifier: "%.0f")") }
                if let avgHR = workout.averageHR { Text("Avg HR: \(avgHR, specifier: "%.0f")") }
                if let avgPower = workout.averagePower { Text("Avg Power: \(avgPower, specifier: "%.0f")") }
            }
            Divider()
            // Dynamically show all other available fields
            ForEach(workout.allFields, id: \.0) { field, value in
                if value != nil && !(field == "ctl" || field == "atl" || field == "tss" || field == "maxHR" || field == "averageHR" || field == "averagePower" || field == "type" || field == "date" || field == "id") {
                    Text("\(field.capitalized): \(value!)")
                }
            }
            Spacer()
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
    @State private var selectedWorkoutDetail: StravaService.StravaActivityDetail?

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
            if workoutListVM.detailedWorkouts.isEmpty {
                Text("No detailed workouts found.")
            } else {
                HStack {
                    List(selection: $selectedWorkoutDetail) {
                        ForEach(workoutListVM.detailedWorkouts) { workout in
                            VStack(alignment: .leading) {
                                Text(workout.name).bold()
                                Text("Date: \(workout.startDateLocal, formatter: dateFormatter)")
                                if let maxHR = workout.maxHeartrate {
                                    Text("Max HR: \(maxHR, specifier: "%.0f")")
                                }
                                if let avgHR = workout.averageHeartrate {
                                    Text("Avg HR: \(avgHR, specifier: "%.1f")")
                                }
                                if let avgPower = workout.averageWatts {
                                    Text("Avg Power: \(avgPower, specifier: "%.1f")")
                                }
                                // TSS display and edit
                                HStack {
                                    Text("TSS: ")
                                    TextField("TSS", value: Binding(
                                        get: {
                                            // Defensive: always return Double?
                                            if let manual = tssEdits[workout.id] {
                                                return manual as Double?
                                            } else if let existing = workout.tss {
                                                return existing as Double?
                                            } else {
                                                return nil
                                            }
                                        },
                                        set: { newValue in
                                            if let val = newValue {
                                                tssEdits[workout.id] = val
                                            } else {
                                                tssEdits.removeValue(forKey: workout.id)
                                            }
                                            saveTSSEdits()
                                        }
                                    ), formatter: NumberFormatter())
                                    .frame(width: 60)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    // Show auto value as hint if both manual and existing are nil
                                    if tssEdits[workout.id] == nil && workout.tss == nil {
                                        Text("(auto: \(autoTSS(for: workout), specifier: "%.0f"))")
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 300)
                    .frame(width: 250)
                    if let selected = selectedWorkoutDetail {
                        VStack(alignment: .leading, spacing: 16) {
                            Text(selected.name).font(.title2).bold()
                            Text("Date: \(selected.startDateLocal, formatter: dateFormatter)")
                            if let movingTime = selected.movingTime {
                                Text("Duration: \(movingTime/60, specifier: "%.0f") min")
                            }
                            if let distance = selected.distance {
                                Text("Distance: \(distance/1000, specifier: "%.2f") km")
                            }
                            if let effort = selected.sufferScore {
                                Text("Relative Effort: \(effort, specifier: "%.0f")")
                            }
                            if let intensity = selected.intensityScore {
                                Text("Intensity: \(intensity, specifier: "%.0f")")
                            }
                            if let avgHR = selected.averageHeartrate {
                                Text("Avg HR: \(avgHR, specifier: "%.0f")")
                            }
                            if let avgPower = selected.averageWatts {
                                Text("Avg Power: \(avgPower, specifier: "%.0f")")
                            }
                            WorkoutDetailChart(hrStream: selected.hrStream, powerStream: selected.powerStream)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Text("Select a workout to see details.")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
