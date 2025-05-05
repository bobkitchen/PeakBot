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
                Section(header: Text("FTP History")) {
                    let context = CoreDataModel.shared.container.viewContext
                    let history = FTPHistoryManager.shared.allHistory(context: context)
                    if let current = history.first {
                        Text("Current FTP: \(current.ftp, specifier: "%.0f") W (since \(current.date, style: .date))")
                            .font(.headline)
                            .padding(.bottom, 2)
                    } else {
                        Text("No FTP history yet.").italic()
                    }
                    ForEach(history, id: \.id) { entry in
                        HStack {
                            Text("\(entry.ftp, specifier: "%.0f") W")
                            Spacer()
                            Text(entry.date, style: .date)
                        }
                    }
                    HStack {
                        TextField("New FTP", text: $ftp)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(minWidth: 100, maxWidth: 120)
                        Button("Add") {
                            if let ftpValue = Double(ftp) {
                                FTPHistoryManager.shared.addFTP(ftpValue, effective: Date(), context: context)
                                stravaService.ftp = ftpValue
                                ftp = ""
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    Button("Apply Current FTP to Last 3 Months") {
                        let threeMonthsAgo = Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date()
                        let request = NSFetchRequest<Workout>(entityName: "Workout")
                        request.predicate = NSPredicate(format: "startDate >= %@", threeMonthsAgo as NSDate)
                        let context = CoreDataModel.shared.container.viewContext
                        let history = FTPHistoryManager.shared.allHistory(context: context)
                        let currentFTP = history.first?.ftp ?? stravaService.ftp
                        do {
                            let workouts = try context.fetch(request)
                            for w in workouts {
                                // Recalculate metrics
                                let power = (try? (w.value(forKey: "watts") as? [Double])) ?? nil
                                let np = MetricsEngine.normalizedPower(from: power) ?? 0.0
                                let ifv = MetricsEngine.intensityFactor(np: np, ftp: currentFTP) ?? 0.0
                                let tss = MetricsEngine.tss(np: np, ifv: ifv, seconds: Double(w.movingTime ?? 0), ftp: currentFTP) ?? 0.0
                                w.np = NSNumber(value: np)
                                w.intensityFactor = NSNumber(value: ifv)
                                w.tss = NSNumber(value: tss)
                                w.ftpUsed = currentFTP
                            }
                            try context.save()
                            print("[FTPHistoryManager] Updated \(workouts.count) workouts with FTP=\(currentFTP)")
                        } catch {
                            print("[FTPHistoryManager] Error updating workouts: \(error)")
                        }
                        // Refresh UI after applying FTP
                        workoutListVM.refresh()
                        Task { await dashboardVM.refresh(days: 90) }
                    }
                    .buttonStyle(.bordered)
                    .padding(.top, 8)
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
