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
                HStack(spacing: 20) {
                    SummaryCard(title: "Fitness (CTL)", value: dashboardVM.fitness.last?.ctl, icon: "dumbbell")
                    SummaryCard(title: "Fatigue (ATL)", value: dashboardVM.fitness.last?.atl, icon: "bolt.fill")
                    SummaryCard(title: "Form (TSB)", value: dashboardVM.fitness.last?.tsb, icon: "heart.fill")
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
                .padding(.horizontal, 4)

                Divider()
                    .padding(.vertical, 6)

                // Trend chart
                if #available(macOS 13.0, *) {
                    FitnessTrendChart(points: dashboardVM.fitness)
                        .frame(height: 220)
                        .background(.ultraThinMaterial)
                        .cornerRadius(14)
                        .shadow(color: .black.opacity(0.10), radius: 8, x: 0, y: 2)
                        .padding(.bottom, 8)
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
    let icon: String
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.accentColor)
                .shadow(radius: 1)
            Text(value.map { String(format: "%.1f", $0) } ?? "–")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 2)
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

    @State private var showCTL = true
    @State private var showATL = true
    @State private var showTSB = true

    private var filtered: [FitnessPlotPoint] {
        plotPoints.filter { (pt) in
            (pt.metric == "CTL" && showCTL) || (pt.metric == "ATL" && showATL) || (pt.metric == "TSB" && showTSB)
        }
    }

    var body: some View {
        Chart(filtered) {
            LineMark(
                x: .value("Date", $0.date),
                y: .value("Value", $0.value),
                series: .value("Metric", $0.metric)
            )
            .interpolationMethod(.monotone)
            .foregroundStyle(by: .value("Metric", $0.metric))
            .symbol(by: .value("Metric", $0.metric))
            .accessibilityLabel($0.metric)
            .accessibilityValue(Text("\($0.value, specifier: "%.1f") on \(dateFormatter.string(from: $0.date))"))
            .annotation(position: .overlay) { pt in
                if let hovered = pt as? FitnessPlotPoint {
                    Text("\(hovered.metric): \(hovered.value, specifier: "%.1f")")
                        .font(.caption2)
                        .padding(4)
                        .background(.ultraThinMaterial)
                        .cornerRadius(6)
                        .shadow(radius: 2)
                }
            }
        }
        .chartLegend(position: .topTrailing, alignment: .top) {
            HStack(spacing: 12) {
                Toggle(isOn: $showCTL) {
                    Text("CTL")
                }.toggleStyle(LegendToggleStyle(color: .blue))
                Toggle(isOn: $showATL) {
                    Text("ATL")
                }.toggleStyle(LegendToggleStyle(color: .red))
                Toggle(isOn: $showTSB) {
                    Text("TSB")
                }.toggleStyle(LegendToggleStyle(color: .orange))
            }
            .padding(8)
            .background(.ultraThinMaterial)
            .cornerRadius(12)
        }
    }
}

// Custom toggle style for legend buttons
struct LegendToggleStyle: ToggleStyle {
    let color: Color
    func makeBody(configuration: Configuration) -> some View {
        Button(action: { configuration.isOn.toggle() }) {
            HStack(spacing: 4) {
                Circle()
                    .fill(color)
                    .frame(width: 10, height: 10)
                configuration.label
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(configuration.isOn ? .white : color)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(configuration.isOn ? color : Color.gray.opacity(0.15))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(color, lineWidth: configuration.isOn ? 0 : 2)
            )
            .cornerRadius(8)
            .shadow(color: configuration.isOn ? color.opacity(0.25) : .clear, radius: 2, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }
}

private let dateFormatter: DateFormatter = {
    let df = DateFormatter()
    df.dateStyle = .medium
    return df
}()