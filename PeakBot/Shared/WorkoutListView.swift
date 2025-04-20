//
//  WorkoutListView.swift
//  PeakBot
//
//  Created by Bob Kitchen on 4/19/25.
//

import SwiftUI

/// List of recent workouts (placeholder)
struct WorkoutListView: View {
    @EnvironmentObject var workoutListVM: WorkoutListViewModel
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
                List(workoutListVM.workouts) { workout in
                    VStack(alignment: .leading) {
                        Text(workout.sport).bold()
                        Text("TSS: \(workout.tss, specifier: "%.0f")  Date: \(workout.date)")
                    }
                }
                .frame(maxHeight: 300)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.windowBackground)
        .onAppear {
            print("[WorkoutListView] onAppear. Calling refresh()...")
            Task {
                await workoutListVM.refresh()
                if workoutListVM.workouts.isEmpty {
                    errorMessage = workoutListVM.errorMessage ?? "No workouts loaded."
                } else {
                    errorMessage = nil
                }
            }
        }
    }
}