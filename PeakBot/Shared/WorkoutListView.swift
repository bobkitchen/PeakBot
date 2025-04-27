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
            Text(workout.name)
                .font(.headline)
            Text("\(workout.startDateLocal, formatter: dateFormatter)")
                .font(.subheadline)
            Text("Distance: \(workout.distance ?? 0.0, specifier: "%.2f") km")
                .font(.caption)
            Text("Moving Time: \(formatSeconds(workout.movingTime ?? 0))")
                .font(.caption2)
        }
    }
}

struct WorkoutListView: View {
    @ObservedObject var viewModel: WorkoutListViewModel
    
    var body: some View {
        List(viewModel.workouts) { workout in
            WorkoutRowView(workout: workout)
        }
    }
}
