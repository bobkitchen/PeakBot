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
                if let tss = workout.tss { Text("TSS: \(tss, specifier: "%.1f")") }
                if let ctl = workout.ctl { Text("CTL: \(ctl, specifier: "%.1f")") }
                if let atl = workout.atl { Text("ATL: \(atl, specifier: "%.1f")") }
            }
            Divider()
            // Dynamically show all other available fields
            ForEach(workout.allFields, id: \.0) { field, value in
                if value != nil && !(field == "tss" || field == "ctl" || field == "atl" || field == "type" || field == "date" || field == "id") {
                    Text("\(field.capitalized): \(value!)")
                }
            }
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension Workout {
    // Returns all fields as [name: value] for dynamic detail rendering
    var allFields: [(String, Any?)] {
        return [
            ("id", id),
            ("date", date != nil ? dateFormatter.string(from: date!) : nil),
            ("type", type),
            ("tss", tss),
            ("ctl", ctl),
            ("atl", atl)
        ]
    }
}

/// List of recent workouts (placeholder)
struct WorkoutListView: View {
    @EnvironmentObject var workoutListVM: WorkoutListViewModel
    @EnvironmentObject var dashboardVM: DashboardViewModel
    @State private var errorMessage: String? = nil

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
            if workoutListVM.workouts.isEmpty {
                Text("No workouts found.")
            } else {
                NavigationView {
                    List(workoutListVM.workouts) { workout in
                        NavigationLink(destination: WorkoutDetailView(workout: workout)) {
                            VStack(alignment: .leading) {
                                Text(workout.type).bold()
                                if let date = workout.date {
                                    Text("Date: \(date, formatter: dateFormatter)")
                                } else {
                                    Text("Date: Invalid").foregroundColor(.red)
                                }
                                if let tss = workout.tss {
                                    Text("TSS: \(tss, specifier: "%.0f")")
                                }
                                if let ctl = workout.ctl {
                                    Text("CTL: \(ctl, specifier: "%.0f")")
                                }
                                if let atl = workout.atl {
                                    Text("ATL: \(atl, specifier: "%.0f")")
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 300)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.windowBackground)
        .onAppear {
            print("[WorkoutListView] onAppear. Calling refresh()...")
            Task {
                await workoutListVM.refresh(oldest: "2024-01-01")
                dashboardVM.updateWorkouts(workoutListVM.workouts)
                if workoutListVM.workouts.isEmpty {
                    errorMessage = workoutListVM.errorMessage ?? "No workouts loaded."
                } else {
                    errorMessage = nil
                }
            }
        }
    }
}