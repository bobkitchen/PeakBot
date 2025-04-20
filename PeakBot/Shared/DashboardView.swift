//
//  DashboardView.swift
//  PeakBot
//
//  Created by Bob Kitchen on 4/19/25.
//


import SwiftUI

/// The training‑status dashboard (placeholder for now)
struct DashboardView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 64))
            Text("Dashboard")
                .font(.title)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.windowBackground)
    }
}