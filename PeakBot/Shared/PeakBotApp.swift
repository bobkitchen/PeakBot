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
    @StateObject private var chatVM        = ChatViewModel(service: OpenAIService.shared)
    @StateObject private var stravaService = StravaService()
    @StateObject private var dashboardVM = DashboardViewModel()
    @StateObject private var workoutListVM = WorkoutListViewModel()

    // Temporarily disable Settings sheet popup until data flow is confirmed
    // For showing settings from menu
    @State private var showSettingsSheet = false

    // IntervalsAPIService is now fully removed. All metrics should be Strava-based.
    var body: some Scene {
        WindowGroup {
            ContentView(stravaService: stravaService, showSettingsSheet: $showSettingsSheet)
                .environmentObject(dashboardVM)
                .environmentObject(workoutListVM)
        }
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings…", action: { showSettingsSheet = true })
                    .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}
