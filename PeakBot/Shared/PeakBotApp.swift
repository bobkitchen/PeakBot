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
    @State private var intervalSvc: IntervalsAPIService? = IntervalsAPIService.makeShared()
    @StateObject private var openAISvc   = OpenAIService.shared   // ← now ObservableObject

    // MARK: – View‑models
    @State private var dashboardVM: DashboardViewModel? = IntervalsAPIService.makeShared().map { DashboardViewModel(service: $0) }
    @State private var workoutListVM: WorkoutListViewModel? = IntervalsAPIService.makeShared().map { WorkoutListViewModel(service: $0) }
    @StateObject private var chatVM        = ChatViewModel(service: OpenAIService.shared)

    // Temporarily disable Settings sheet popup until data flow is confirmed
    @State private var showSettings = false

    // For showing settings from menu
    @State private var showSettingsSheet = false

    // MARK: – Body
    var body: some Scene {
        WindowGroup {
            if let intervalSvc = intervalSvc,
               let dashboardVM = dashboardVM,
               let workoutListVM = workoutListVM {
                RootTabView()
                    .environmentObject(intervalSvc)
                    .environmentObject(openAISvc)
                    .environmentObject(dashboardVM)
                    .environmentObject(workoutListVM)
                    .environmentObject(chatVM)
                    // Temporarily disable SettingsView sheet
                    //.sheet(isPresented: $showSettingsSheet) {
                    //    SettingsView()
                    //}
            } else {
                // Temporarily do nothing when not initialized
                // This disables SettingsView fallback completely for debugging
            }
        }
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings…", action: { showSettingsSheet = true })
                    .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}
