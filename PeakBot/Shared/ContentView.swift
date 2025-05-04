import SwiftUI
import AppKit

struct ContentView: View {
    @Binding var showSettingsSheet: Bool
    @EnvironmentObject var dashboardVM: DashboardViewModel
    @EnvironmentObject var workoutListVM: WorkoutListViewModel
    @State private var showLoginView = false
    @State private var showTPLoginSheet = false

    var body: some View {
        VStack {
            RootTabView()
                .sheet(isPresented: $showSettingsSheet) {
                    SettingsView()
                }
                .onAppear {
                    Task {
                        await dashboardVM.refresh()
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
}
