import SwiftUI
import Charts

struct WorkoutDetailChart: View {
    let hrStream: [Double]?
    let powerStream: [Double]?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Heart Rate & Power Over Time")
                .font(.headline)
            if let hr = hrStream, !hr.isEmpty {
                Chart {
                    ForEach(Array(hr.enumerated()), id: \ .offset) { idx, value in
                        LineMark(
                            x: .value("Time", idx),
                            y: .value("HR", value)
                        )
                        .foregroundStyle(.red)
                    }
                }
                .frame(height: 120)
                .padding(.bottom, 8)
            }
            if let power = powerStream, !power.isEmpty {
                Chart {
                    ForEach(Array(power.enumerated()), id: \ .offset) { idx, value in
                        LineMark(
                            x: .value("Time", idx),
                            y: .value("Power", value)
                        )
                        .foregroundStyle(.blue)
                    }
                }
                .frame(height: 120)
            }
            if (hrStream?.isEmpty ?? true) && (powerStream?.isEmpty ?? true) {
                Text("No HR or Power data available.")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}

private extension Array where Element == Double {
    var indexed: [(index: Int, value: Double)] {
        enumerated().map { (i, v) in (index: i, value: v) }
    }
}
