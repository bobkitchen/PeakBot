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
                dashboardError = dashboardVM.errorMessage
                await dashboardVM.refresh()
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    Task {
                        await dashboardVM.refresh()
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
    
    // Helper for charting
    private struct FitnessPlotPoint: Identifiable {
        let id = UUID()
        let date: Date
        let value: Double
        let metric: String // "CTL", "ATL", "TSB"
    }
    
    // Compute 7-day moving averages for each metric
    private func movingAverage(_ values: [Double], window: Int) -> [Double] {
        guard window > 1, values.count >= window else { return values }
        var result = [Double]()
        for i in 0..<values.count {
            let start = max(0, i - window + 1)
            let windowVals = values[start...i]
            result.append(windowVals.reduce(0, +) / Double(windowVals.count))
        }
        return result
    }

    private var plotPoints: [FitnessPlotPoint] {
        let now = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -90, to: now) ?? now
        let filteredPoints = points.filter { $0.date >= startDate }
        let dates = filteredPoints.map { $0.date }
        let ctlAvg = movingAverage(filteredPoints.map { $0.ctl }, window: 7)
        let atlAvg = movingAverage(filteredPoints.map { $0.atl }, window: 7)
        let tsbAvg = movingAverage(filteredPoints.map { $0.tsb }, window: 7)
        var arr: [FitnessPlotPoint] = []
        for (i, date) in dates.enumerated() {
            arr.append(FitnessPlotPoint(date: date, value: ctlAvg[i], metric: "CTL"))
            arr.append(FitnessPlotPoint(date: date, value: atlAvg[i], metric: "ATL"))
            arr.append(FitnessPlotPoint(date: date, value: tsbAvg[i], metric: "TSB"))
        }
        return arr
    }

    var body: some View {
        Chart(plotPoints) {
            LineMark(
                x: .value("Date", $0.date),
                y: .value("Value", $0.value),
                series: .value("Metric", $0.metric)
            )
            .interpolationMethod(.monotone)
            .foregroundStyle(by: .value("Metric", $0.metric))
        }
        .chartLegend(position: .top, alignment: .center)
    }
}

private let dateFormatter: DateFormatter = {
    let df = DateFormatter()
    df.dateStyle = .medium
    return df
}()