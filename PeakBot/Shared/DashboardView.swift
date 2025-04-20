//
//  DashboardView.swift
//  PeakBot
//
//  Created by Bob Kitchen on 4/19/25.
//

import SwiftUI
import Charts
import AppKit // for NSColor on macOS

struct DashboardView: View {
    @EnvironmentObject var dashboardVM: DashboardViewModel
    @EnvironmentObject var workoutListVM: WorkoutListViewModel
    @State private var dashboardError: String? = nil
    @State private var workoutsError: String? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Summary cards
                HStack(spacing: 16) {
                    SummaryCard(title: "Fitness (CTL)", value: dashboardVM.fitness.last?.ctl)
                    SummaryCard(title: "Fatigue (ATL)", value: dashboardVM.fitness.last?.atl)
                    SummaryCard(title: "Form (TSB)", value: dashboardVM.fitness.last?.tsb)
                }
                .frame(maxWidth: .infinity)

                // Trend chart
                if #available(macOS 13.0, *) {
                    FitnessTrendChart(points: dashboardVM.fitness)
                        .frame(height: 200)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color(NSColor.windowBackgroundColor)))
                        .padding(.vertical)
                } else {
                    Text("Chart requires macOS 13+")
                }

                // Workouts list
                Text("Recent Workouts")
                    .font(.headline)
                if let dashboardError = dashboardError {
                    Text("⚠️ Dashboard error: \(dashboardError)")
                        .foregroundColor(.red)
                }
                if let workoutsError = workoutsError {
                    Text("⚠️ Workouts error: \(workoutsError)")
                        .foregroundColor(.red)
                }
                if workoutListVM.workouts.isEmpty {
                    Text("No workouts found.")
                } else {
                    ForEach(workoutListVM.workouts.prefix(5)) { workout in
                        WorkoutRow(workout: workout)
                    }
                }
            }
            .padding()
        }
        .onAppear {
            Task {
                await dashboardVM.refresh()
                if dashboardVM.fitness.isEmpty {
                    dashboardError = "No fitness data loaded. Check credentials or network."
                } else {
                    dashboardError = nil
                }
            }
            Task {
                await workoutListVM.refresh()
                if workoutListVM.workouts.isEmpty {
                    workoutsError = workoutListVM.errorMessage ?? "No workouts loaded."
                } else {
                    workoutsError = nil
                }
            }
        }
    }
}

struct SummaryCard: View {
    let title: String
    let value: Double?
    var body: some View {
        VStack {
            Text(title).font(.caption)
            Text(value.map { String(format: "%.1f", $0) } ?? "–")
                .font(.title2).bold()
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(NSColor.windowBackgroundColor)))
    }
}

@available(macOS 13.0, *)
struct FitnessTrendChart: View {
    let points: [FitnessPoint]
    var body: some View {
        Chart(points) {
            LineMark(
                x: .value("Date", $0.date),
                y: .value("CTL", $0.ctl)
            ).foregroundStyle(.blue)
            LineMark(
                x: .value("Date", $0.date),
                y: .value("ATL", $0.atl)
            ).foregroundStyle(.red)
            LineMark(
                x: .value("Date", $0.date),
                y: .value("TSB", $0.tsb)
            ).foregroundStyle(.orange)
        }
    }
}

struct WorkoutRow: View {
    let workout: Workout
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(workout.sport).font(.subheadline).bold()
                Text(workout.date, formatter: dateFormatter).font(.caption)
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text("TSS: \(workout.tss, specifier: "%.0f")")
                if workout.ctl != 0 { Text("CTL: \(workout.ctl, specifier: "%.1f")") }
                if workout.atl != 0 { Text("ATL: \(workout.atl, specifier: "%.1f")") }
            }
        }
        .padding(.vertical, 4)
    }
}

private let dateFormatter: DateFormatter = {
    let df = DateFormatter()
    df.dateStyle = .medium
    return df
}()