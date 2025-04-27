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
    @State private var dashboardError: String? = nil

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

                // Chatbot section
                Divider()
                Text("Chatbot")
                    .font(.headline)
                if let dashboardError = dashboardError {
                    Text("⚠️ Dashboard error: \(dashboardError)")
                        .foregroundColor(.red)
                }
            }
            .padding()
        }
        .onAppear {
            print("[DashboardView] onAppear. dashboardVM: \(dashboardVM)")
            Task {
                dashboardVM.refreshEnabled = true
                dashboardError = dashboardVM.errorMessage
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    Task {
                        dashboardVM.refreshEnabled = true
                    }
                }) {
                    Label("Refresh Fitness", systemImage: "arrow.clockwise")
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

private let dateFormatter: DateFormatter = {
    let df = DateFormatter()
    df.dateStyle = .medium
    return df
}()