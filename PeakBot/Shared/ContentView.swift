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
                    if let url = URL(string: "https://home.trainingpeaks.com/login") {
                        NSWorkspace.shared.open(url)
                    }
                }
            } else {
                HStack(spacing: 16) {
                    Button(trainingPeaksService.isSyncing ? "Syncing..." : "Sync Now") {
                        trainingPeaksService.syncAll { _ in }
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
