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
    @State private var dashboardVM: DashboardViewModel? = nil
    @State private var workoutListVM: WorkoutListViewModel? = nil
    @StateObject private var chatVM        = ChatViewModel(service: OpenAIService.shared)

    // Show Settings sheet immediately when API credentials are missing
    @State private var showSettings = !KeychainHelper.hasAllKeys

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
                    .sheet(isPresented: $showSettingsSheet) {
                        SettingsView()
                    }
            } else {
                SettingsView()
                    .onDisappear {
                        if let svc = IntervalsAPIService.makeShared() {
                            intervalSvc = svc
                            dashboardVM = DashboardViewModel(service: svc)
                            workoutListVM = WorkoutListViewModel(service: svc)
                        }
                    }
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
