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
    @StateObject private var intervalSvc = IntervalsAPIService.shared
    @StateObject private var openAISvc   = OpenAIService.shared   // ← now ObservableObject

    // MARK: – View‑models
    @StateObject private var dashboardVM   = DashboardViewModel(service: .shared)
    @StateObject private var workoutListVM = WorkoutListViewModel()
    @StateObject private var chatVM        = ChatViewModel(service: OpenAIService.shared)

    // Show Settings sheet immediately when API credentials are missing
    @State private var showSettings = !KeychainHelper.hasAllKeys

    // MARK: – Body
    var body: some Scene {
        WindowGroup {
            RootTabView()                      // Dashboard | Workouts | Chat
                // Inject services & VMs into the environment so sub‑views can access them
                .environmentObject(intervalSvc)
                .environmentObject(openAISvc)
                .environmentObject(dashboardVM)
                .environmentObject(workoutListVM)
                .environmentObject(chatVM)
                // On‑boarding sheet
                .sheet(isPresented: $showSettings) { SettingsView() }
        }
    }
}
