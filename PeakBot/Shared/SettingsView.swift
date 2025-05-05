import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var stravaService: StravaService
    @EnvironmentObject var workoutListVM: WorkoutListViewModel
    @EnvironmentObject var dashboardVM: DashboardViewModel // Added this line
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
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.green)
                                .font(.title2)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Connected to Strava").font(.headline)
                                if let expiry = stravaService.tokens?.expiresAt {
                                    let expiryDate = Date(timeIntervalSince1970: expiry)
                                    Text("Token expires: \(expiryDate, style: .relative)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        if let syncError = syncError {
                            Text(syncError)
                                .foregroundColor(.red)
                                .font(.callout)
                                .padding(.vertical, 4)
                                .transition(.opacity)
                        }
                        HStack(spacing: 16) {
                            Button(action: {
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
                            }) {
                                Label("Sync Now", systemImage: "arrow.clockwise")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.accentColor)
                            .disabled(showSyncing)
                            Button(action: {
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
                            }) {
                                Label("Sync History", systemImage: "clock.arrow.circlepath")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .disabled(showSyncing)
                            Button(action: {
                                showSyncing = true
                                syncError = nil
                                Task {
                                    do {
                                        try await stravaService.syncSixMonthsHistory()
                                        workoutListVM.refresh()
                                        await dashboardVM.refresh(days: 180)
                                    } catch {
                                        syncError = error.localizedDescription
                                    }
                                    showSyncing = false
                                }
                            }) {
                                Label("Sync Last 6 Months", systemImage: "calendar")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .tint(.orange)
                            .disabled(showSyncing)
                        }
                        if showSyncing {
                            ProgressView("Syncing...")
                        }
                    } else {
                        VStack(spacing: 12) {
                            Button(action: {
                                isConnecting = true
                                connectionError = nil
                                stravaService.startOAuth { success in
                                    isConnecting = false
                                    if !success {
                                        connectionError = "OAuth failed. Please try again."
                                    }
                                }
                            }) {
                                Label("Connect to Strava", systemImage: "bolt.horizontal.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.red)
                            .disabled(isConnecting)
                            if isConnecting {
                                ProgressView("Connecting...")
                            }
                            if let connectionError = connectionError {
                                Text(connectionError)
                                    .foregroundColor(.red)
                                    .font(.callout)
                                    .padding(.vertical, 4)
                                    .transition(.opacity)
                            }
                        }
                    }
                }
                Section(header: Text("FTP Settings")) {
                    HStack {
                        TextField("Functional Threshold Power (FTP)", text: $ftp)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(minWidth: 360, maxWidth: 400)
                            .onSubmit {
                                if let ftpValue = Double(ftp) {
                                    stravaService.ftp = ftpValue
                                }
                            }
                        Button("Save") {
                            if let ftpValue = Double(ftp) {
                                stravaService.ftp = ftpValue
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                Section(header: Text("OpenAI API Key (coming soon)")) {
                    SecureField("OpenAI API Key", text: $openAIApiKey)
                    Button("Save OpenAI Key") {
                        // TODO: Save to Keychain
                    }.disabled(openAIApiKey.isEmpty)
                }
            }
            .padding(.vertical, 10)
            .navigationTitle("Settings")
            .frame(minWidth: 350, maxWidth: 450)
            HStack {
                Spacer()
                Button("Close") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
        }
    }
}
