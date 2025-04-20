//
//  WorkoutListView.swift
//  PeakBot
//
//  Created by Bob Kitchen on 4/19/25.
//


import SwiftUI

/// List of recent workouts (placeholder)
struct WorkoutListView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 64))
            Text("Workouts")
                .font(.title)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.windowBackground)
    }
}