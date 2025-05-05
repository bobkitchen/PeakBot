import SwiftUI
import AppKit

struct ContentView: View {
    @Binding var showSettingsSheet: Bool
    @EnvironmentObject var dashboardVM: DashboardViewModel
    @EnvironmentObject var workoutListVM: WorkoutListViewModel
    @EnvironmentObject var stravaService: StravaService
    @State private var showLoginView = false
    @State private var showTPLoginSheet = false
    @State private var didAutoSync = false

    var body: some View {
        VStack {
            RootTabView()
                .sheet(isPresented: $showSettingsSheet) {
                    SettingsView()
                }
                .onAppear {
                    Task {
                        await dashboardVM.refresh()
                        if !didAutoSync {
                            didAutoSync = true
                            do {
                                try await stravaService.syncRecentActivities()
                                workoutListVM.refresh()
                            } catch {
                                print("[PeakBot] Auto-sync failed: \(error.localizedDescription)")
                            }
                        }
                    }
                    print("[PeakBot DEBUG] ContentView appeared. showLoginView = \(showLoginView)")
                }
            Divider()
            // TrainingPeaks Auth & Sync Controls
            // [LOGIN MOVED TO SETTINGS VIEW]
        }
    }
}

#Preview {
    ContentView(showSettingsSheet: .constant(false))
        .environmentObject(DashboardViewModel())
        .environmentObject(WorkoutListViewModel())
        .environmentObject(StravaService())
}
