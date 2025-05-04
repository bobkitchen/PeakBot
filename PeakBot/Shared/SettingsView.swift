//
//  SettingsView.swift
//  PeakBot
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var stravaService: StravaService
    @EnvironmentObject var workoutListVM: WorkoutListViewModel
    @State private var openAIApiKey: String = ""
    @State private var showOAuthSheet = false
    @State private var isConnecting = false
    @State private var connectionError: String?
    @State private var ftp: String = ""
    @State private var tokenExpiry: Date? = nil
    @State private var showSyncing = false
    @State private var syncError: String? = nil

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Strava Integration")) {
                    if stravaService.tokens != nil {
                        HStack {
                            Image(systemName: "checkmark.seal.fill").foregroundColor(.green)
                            Text("Connected to Strava")
                        }
                        if let expiry = stravaService.tokens?.expiresAt {
                            let expiryDate = Date(timeIntervalSince1970: expiry)
                            Text("Token expires: \(expiryDate, style: .relative)")
                        }
                        Button("Sync Now") {
                            showSyncing = true
                            syncError = nil
                            Task {
                                do {
                                    try await stravaService.syncRecentActivities()
                                    workoutListVM.refresh()
                                } catch {
                                    syncError = error.localizedDescription
                                }
                                showSyncing = false
                            }
                        }
                        .disabled(showSyncing)
                        Button("Sync History") {
                            showSyncing = true
                            syncError = nil
                            Task {
                                do {
                                    try await stravaService.syncHistory()
                                } catch {
                                    syncError = error.localizedDescription
                                }
                                showSyncing = false
                            }
                        }
                        .disabled(showSyncing)
                        if showSyncing {
                            ProgressView("Syncing...")
                        }
                        if let syncError = syncError {
                            Text("⚠️ \(syncError)").foregroundColor(.red)
                        }
                    } else {
                        Button("Connect to Strava") {
                            isConnecting = true
                            connectionError = nil
                            stravaService.startOAuth { success in
                                isConnecting = false
                                if !success {
                                    connectionError = "OAuth failed. Please try again."
                                }
                            }
                        }
                        .disabled(isConnecting)
                        if isConnecting {
                            ProgressView("Connecting...")
                        }
                        if let connectionError = connectionError {
                            Text("⚠️ \(connectionError)").foregroundColor(.red)
                        }
                    }
                }
                Section(header: Text("FTP Settings")) {
                    TextField("Functional Threshold Power (FTP)", text: $ftp)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 80)
                        .onSubmit {
                            if let ftpValue = Int(ftp) {
                                UserDefaults.standard.set(ftpValue, forKey: "ftp")
                            }
                        }
                    Button("Save FTP") {
                        if let ftpValue = Double(ftp) {
                            stravaService.saveFTP(ftpValue)
                        }
                    }.disabled(ftp.isEmpty)
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
    }
}
