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
    @State private var ftpEffectiveDate: Date = Date()
    @State private var tokenExpiry: Date? = nil
    @State private var showSyncing = false
    @State private var syncError: String? = nil
    // CTL/ATL override states
    @State private var overrideDate: Date = Date()
    @State private var overrideCTL: String = ""
    @State private var overrideATL: String = ""
    @State private var overrideTSB: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Button("TEST BUTTON - Should Print") {
                    print("[DEBUG] TEST BUTTON PRESSED")
                }
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
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            TextField("New FTP", text: $ftp)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(minWidth: 80, maxWidth: 100)
                            DatePicker("Effective", selection: $ftpEffectiveDate, displayedComponents: .date)
                                .labelsHidden()
                        }
                        Button("Add") {
                            if let ftpValue = Double(ftp) {
                                FTPHistoryManager.shared.addFTP(ftpValue, effective: ftpEffectiveDate, context: context)
                                stravaService.ftp = ftpValue // update default
                                ftp = ""
                                ftpEffectiveDate = Date()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    Button(role: .destructive) {
                        let context = CoreDataModel.shared.container.viewContext
                        FTPHistoryManager.shared.clearAll(context: context)
                        // Reset StravaService default FTP to 250
                        stravaService.ftp = 250
                        // Refresh local UI
                        workoutListVM.refresh()
                        Task { await dashboardVM.refresh(days: 180) }
                    } label: {
                        Label("Clear FTP History", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    Button("Apply Global FTP Update") {
                        print("[DEBUG] Apply Global FTP Update button tapped")
                        Task {
                            print("[DEBUG] Entered global FTP update handler")
                            let request = NSFetchRequest<Workout>(entityName: "Workout")
                            let context = CoreDataModel.shared.container.viewContext
                            let history = FTPHistoryManager.shared.allHistory(context: context)
                            print("[DEBUG] FTP history entries: \(history.map{"\($0.ftp)@\($0.date)"})")
                            do {
                                let workouts = try context.fetch(request)
                                print("[DEBUG] Fetched \(workouts.count) workouts for global FTP update.")
                                if workouts.isEmpty {
                                    print("[DEBUG] No workouts found for update.")
                                }
                                for w in workouts {
                                    let power: [Double]? = {
                                        if w.entity.attributesByName.keys.contains("watts"),
                                           let arr = w.value(forKey: "watts") as? [Double] {
                                            return arr
                                        }
                                        if let avg = w.avgPower?.doubleValue {
                                            let secs = Int(w.movingTime?.intValue ?? 0)
                                            return secs > 0 ? Array(repeating: avg, count: secs) : nil
                                        }
                                        return nil
                                    }()
                                    if power == nil || power?.isEmpty == true {
                                        print("[WARNING] No power data for workout id=\(String(describing: w.workoutId)), name=\(w.name ?? "nil")")
                                        continue
                                    }
                                    // Determine ftp to use for this workout's date
                                    let ftpForDate = FTPHistoryManager.shared.ftp(for: w.startDate ?? Date(), context: context) ?? stravaService.ftp
                                    let np = MetricsEngine.normalizedPower(from: power) ?? 0.0
                                    let ifv = MetricsEngine.intensityFactor(np: np, ftp: ftpForDate) ?? 0.0
                                    let tss = MetricsEngine.tss(np: np, ifv: ifv, seconds: Double(w.movingTime ?? 0), ftp: ftpForDate) ?? 0.0
                                    w.np = NSNumber(value: np)
                                    w.intensityFactor = NSNumber(value: ifv)
                                    w.tss = NSNumber(value: tss)
                                    w.ftpUsed = ftpForDate
                                    if let date = w.startDate {
                                        let formatter = DateFormatter()
                                        formatter.dateFormat = "yyyy-MM-dd"
                                        let dateString = formatter.string(from: date)
                                        if dateString == "2025-05-03" || dateString == "2025-05-02" {
                                            print("[VERIFY] Workout on \(dateString): tss=\(tss), np=\(np), if=\(ifv)")
                                        }
                                    }
                                }
                                try context.save()
                                print("[FTPHistoryManager] Updated \(workouts.count) workouts with per-date FTP")
                            } catch {
                                print("[FTPHistoryManager] Error updating workouts: \(error)")
                            }
                            // Refresh UI after applying FTP
                            await workoutListVM.refresh()
                            await dashboardVM.refresh(days: 90)
                        }
                    }
                    .buttonStyle(.bordered)
                    .padding(.top, 8)
                }
                // MARK: CTL/ATL Override
                Section(header: Text("Override CTL / ATL / TSB")) {
                    DatePicker("Date", selection: $overrideDate, displayedComponents: .date)
                    HStack {
                        TextField("CTL", text: $overrideCTL)
                            .frame(width: 60)
                        TextField("ATL", text: $overrideATL)
                            .frame(width: 60)
                        TextField("TSB", text: $overrideTSB)
                            .frame(width: 60)
                        Button("Apply") {
                            let context = CoreDataModel.shared.container.viewContext
                            guard let ctlVal = Double(overrideCTL),
                                  let atlVal = Double(overrideATL),
                                  let tsbVal = Double(overrideTSB) else { return }
                            let day = Calendar.current.startOfDay(for: overrideDate)
                            let req = NSFetchRequest<DailyLoad>(entityName: "DailyLoad")
                            req.predicate = NSPredicate(format: "date == %@", day as NSDate)
                            if let existing = try? context.fetch(req).first {
                                existing.ctl = ctlVal
                                existing.atl = atlVal
                                existing.tsb = tsbVal
                            } else {
                                let d = DailyLoad(context: context)
                                d.date = day
                                d.ctl = ctlVal
                                d.atl = atlVal
                                d.tsb = tsbVal
                                d.tss = 0
                            }
                            try? context.save()
                            Task { await dashboardVM.reloadDailyLoad(days: 180) }
                            overrideCTL = ""; overrideATL = ""; overrideTSB = ""
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    Text("You can seed today's values to match TrainingPeaks; subsequent days will update from workouts.")
                        .font(.footnote)
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
            VStack {
                Spacer()
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
}
