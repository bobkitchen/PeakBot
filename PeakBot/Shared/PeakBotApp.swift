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
    @StateObject private var stravaService = StravaService.shared // Inject StravaService globally

    // MARK: – View‑models
    @StateObject private var chatVM        = ChatViewModel()
    @StateObject private var dashboardVM = DashboardViewModel()
    @StateObject private var workoutListVM: WorkoutListViewModel = WorkoutListViewModel()

    // Temporarily disable Settings sheet popup until data flow is confirmed
    // For showing settings from menu
    @State private var showSettingsSheet = false

    var body: some Scene {
        WindowGroup {
            ContentView(showSettingsSheet: $showSettingsSheet)
                .environmentObject(dashboardVM)
                .environmentObject(workoutListVM)
                .environmentObject(stravaService) // Inject StravaService
        }
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings…", action: { showSettingsSheet = true })
                    .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}
