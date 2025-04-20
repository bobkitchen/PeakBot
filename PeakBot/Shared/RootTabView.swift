//
//  RootTabView.swift
//  PeakBot
//
//  Created by Bob Kitchen on 4/19/25.
//


import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Dashboard", systemImage: "chart.line.uptrend.xyaxis") }

            WorkoutListView()
                .tabItem { Label("Workouts", systemImage: "list.bullet.rectangle") }

            ChatView()
                .tabItem { Label("Chat", systemImage: "message") }
        }
    }
}