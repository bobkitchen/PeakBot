import SwiftUI
import AppKit

struct ContentView: View {
    @Binding var showSettingsSheet: Bool
    @EnvironmentObject var dashboardVM: DashboardViewModel
    @EnvironmentObject var workoutListVM: WorkoutListViewModel
    @EnvironmentObject var trainingPeaksService: TrainingPeaksService
    @State private var showLoginView = false

    var body: some View {
        VStack {
            RootTabView()
                .sheet(isPresented: $showSettingsSheet) {
                    SettingsView()
                }
                .onAppear {
                    workoutListVM.refreshEnabled = true
                    // Call refresh only if it exists and is appropriate
                    Task {
                        await workoutListVM.refresh()
                    }
                }
            Divider()
            // TrainingPeaks Auth & Sync Controls
            if !trainingPeaksService.isAuthenticated {
                Button("Login to TrainingPeaks") {
                    showLoginView = true
                }
            }
            if showLoginView {
                TrainingPeaksWebExporter { zipURL in
                    if let url = zipURL {
                        trainingPeaksService.ingestExportedData(from: url) { success in
                            if success {
                                trainingPeaksService.isAuthenticated = true
                            } else {
                                trainingPeaksService.errorMessage = "Failed to import exported data."
                            }
                        }
                    } else {
                        trainingPeaksService.errorMessage = "Export failed or cancelled."
                    }
                    showLoginView = false
                }
                .frame(width: 640, height: 600)
            }
            if trainingPeaksService.isAuthenticated {
                HStack(spacing: 16) {
                    Button(trainingPeaksService.isSyncing ? "Syncing…" : "Sync last day") {
                        trainingPeaksService.isSyncing = true
                        Task {
                            await TrainingPeaksExportService.shared.sync(range: .days(1), trainingPeaksService: trainingPeaksService)
                            trainingPeaksService.isSyncing = false
                        }
                    }
                    .disabled(trainingPeaksService.isSyncing)
                    if let lastSync = trainingPeaksService.lastSyncDate {
                        Text("Last sync: \(lastSync.formatted(.dateTime.hour().minute()))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if let error = trainingPeaksService.errorMessage {
                        Text("⚠️ \(error)")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }
}

#Preview {
    ContentView(showSettingsSheet: .constant(false))
        .environmentObject(DashboardViewModel())
        .environmentObject(WorkoutListViewModel())
        .environmentObject(TrainingPeaksService())
}
