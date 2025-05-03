//
//  SettingsView.swift
//  PeakBot
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var trainingPeaksService: TrainingPeaksService

    @State private var openAIApiKey: String = ""
    @State private var showOAuthSheet = false
    @State private var isConnecting = false
    @State private var connectionError: String?
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("TrainingPeaks Integration")) {
                    if trainingPeaksService.isAuthenticated {
                        Text("Status: ✅ Authenticated")
                        Button("Disconnect TrainingPeaks") {
                            KeychainHelper.tpSessionCookies = nil
                            trainingPeaksService.isAuthenticated = false
                        }.foregroundColor(.red)
                    } else {
                        Text("Status: ❌ Not Authenticated")
                        Button("Login to TrainingPeaks") {
                            showOAuthSheet = true
                        }
                        .sheet(isPresented: $showOAuthSheet) {
                            TrainingPeaksLoginController { success in
                                trainingPeaksService.authenticate { _ in }
                                showOAuthSheet = false
                            }
                            .frame(width: 700, height: 600)
                        }
                    }
                }
                Section(header: Text("Strava Integration")) {
                    // Removed stravaService parameter for TrainingPeaks transition
                    // if stravaService.tokens == nil {
                    //     Button(isConnecting ? "Connecting..." : "Connect with Strava") {
                    //         isConnecting = true
                    //         connectionError = nil
                    //         stravaService.startOAuth { success in
                    //             isConnecting = false
                    //             if !success {
                    //                 connectionError = "OAuth failed. Please try again."
                    //             }
                    //         }
                    //     }
                    //     .disabled(isConnecting)
                    //     if let error = connectionError {
                    //         Text(error).foregroundColor(.red)
                    //     }
                    // } else {
                    //     Text("Strava Connected ")
                    //     Button("Disconnect") {
                    //         stravaService.tokens = nil
                    //         stravaService.stopOAuthServer()
                    //     }.foregroundColor(.red)
                    // }
                }
                Section(header: Text("OpenAI API Key (coming soon)")) {
                    SecureField("OpenAI API Key", text: $openAIApiKey)
                    Button("Save OpenAI Key") {
                        // TODO: Save to Keychain
                    }.disabled(openAIApiKey.isEmpty)
                }
            }
            .navigationTitle("Settings")
            .toolbar { ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }}
        }
        .frame(minWidth: 320, minHeight: 240)
    }
}
