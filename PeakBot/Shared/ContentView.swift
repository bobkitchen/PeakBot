import SwiftUI
import AppKit

struct ContentView: View {
    @Binding var showSettingsSheet: Bool
    @EnvironmentObject var dashboardVM: DashboardViewModel
    @EnvironmentObject var workoutListVM: WorkoutListViewModel
    @EnvironmentObject var trainingPeaksService: TrainingPeaksService
    @State private var showLoginView = false
    @State private var showTPLoginSheet = false

    var body: some View {
        VStack {
            RootTabView()
                .sheet(isPresented: $showSettingsSheet) {
                    SettingsView(trainingPeaksService: trainingPeaksService)
                }
                .onAppear {
                    workoutListVM.refreshEnabled = true
                    // Call refresh only if it exists and is appropriate
                    Task {
                        await workoutListVM.refresh()
                    }
                    print("[PeakBot DEBUG] ContentView appeared. showLoginView = \(showLoginView)")
                }
            Divider()
            // TrainingPeaks Auth & Sync Controls
            // [LOGIN MOVED TO SETTINGS VIEW]
            if trainingPeaksService.isAuthenticated {
                HStack(spacing: 16) {
                    Button(trainingPeaksService.isSyncing ? "Syncing…" : "Sync last day") {
                        trainingPeaksService.isSyncing = true
                        trainingPeaksService.errorMessage = nil
                        Task {
                            await TrainingPeaksExportService.shared.sync(range: .days(1), trainingPeaksService: trainingPeaksService)
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
