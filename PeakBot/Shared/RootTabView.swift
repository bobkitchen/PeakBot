//
//  RootTabView.swift
//  PeakBot
//
//  Created by Bob Kitchen on 4/19/25.
//


import SwiftUI

struct RootTabView: View {
    @StateObject var workoutListVM = WorkoutListViewModel()

    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Dashboard", systemImage: "chart.line.uptrend.xyaxis") }

            NavigationStack {
                WorkoutListView(viewModel: workoutListVM)
            }
            .tabItem { Label("Workouts", systemImage: "list.bullet.rectangle") }
        }
    }
}