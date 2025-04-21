import SwiftUI

struct ContentView: View {
    @ObservedObject var stravaService: StravaService
    @Binding var showSettingsSheet: Bool
    @EnvironmentObject var dashboardVM: DashboardViewModel
    @EnvironmentObject var workoutListVM: WorkoutListViewModel

    var body: some View {
        RootTabView()
            .sheet(isPresented: $showSettingsSheet) {
                SettingsView(stravaService: stravaService)
            }
            .onAppear {
                // Wire up StravaService to WorkoutListViewModel
                workoutListVM.stravaService = stravaService
                // Trigger batch download on startup
                Task {
                    await workoutListVM.refreshDetailed()
                }
            }
    }
}

#Preview {
    ContentView(stravaService: StravaService(), showSettingsSheet: .constant(false))
        .environmentObject(DashboardViewModel())
        .environmentObject(WorkoutListViewModel())
}
