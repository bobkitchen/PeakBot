//
//  PeakBotApp.swift
//  PeakBot
//
//  Created by Bob Kitchen on 4/19/25.
//


import SwiftUI

@main
struct PeakBotApp: App {
    // Shared singletons
    @StateObject private var intervalSvc = IntervalsAPIService.shared
    @StateObject private var openAISvc   = OpenAIService()

    // View‑models
    @StateObject private var dashVM  = DashboardViewModel(service: IntervalsAPIService.shared)
    @StateObject private var wkVM    = WorkoutListViewModel(service: IntervalsAPIService.shared)
    @StateObject private var chatVM  = ChatViewModel(service: OpenAIService())

    @State private var showSettings = !KeychainHelper.hasAllKeys

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(intervalSvc)
                .environmentObject(openAISvc)
                .sheet(isPresented: $showSettings) { SettingsView() }
        }
    }
}