//
//  PeakBotApp.swift
//  PeakBot
//
//  Created 20 Apr 2025 – unified iOS & macOS entry‑point
//

import SwiftUI

@main
struct PeakBotApp: App {
    // MARK: – Singleton services  (one instance for the whole app)
    @StateObject private var openAISvc   = OpenAIService.shared   // ← now ObservableObject

    // MARK: – View‑models
    @StateObject private var chatVM        = ChatViewModel()
    @StateObject private var dashboardVM = DashboardViewModel()
    @StateObject private var workoutListVM: WorkoutListViewModel
    @StateObject private var trainingPeaksService = TrainingPeaksService()

    // Temporarily disable Settings sheet popup until data flow is confirmed
    // For showing settings from menu
    @State private var showSettingsSheet = false

    // Removed Strava and IntervalsAPIService for TrainingPeaks transition
    // @StateObject private var stravaService = StravaService()
    // IntervalsAPIService is now fully removed. All metrics should be Strava-based.
    init() {
        let tps = TrainingPeaksService()
        _trainingPeaksService = StateObject(wrappedValue: tps)
        _workoutListVM = StateObject(wrappedValue: WorkoutListViewModel(trainingPeaksService: tps))
    }

    var body: some Scene {
        WindowGroup {
            ContentView(showSettingsSheet: $showSettingsSheet)
                .environmentObject(dashboardVM)
                .environmentObject(workoutListVM)
                .environmentObject(trainingPeaksService)
        }
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings…", action: { showSettingsSheet = true })
                    .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}
