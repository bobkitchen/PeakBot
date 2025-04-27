// TrainingPeaksService.swift
// PeakBot
//
// Service for authenticating, exporting, downloading, and parsing TrainingPeaks data.
//

import Foundation
import Compression
import WebKit
import ZIPFoundation

@MainActor
final class TrainingPeaksService: ObservableObject {
    // MARK: - Published State
    @Published var isAuthenticated: Bool = false
    @Published var isSyncing: Bool = false
    @Published var lastSyncDate: Date?
    @Published var errorMessage: String?
    @Published var workouts: [Workout] = []
    
    // MARK: - Private State
    private var cookies: [HTTPCookie] = []
    
    // MARK: - Authentication
    func authenticate(completion: @escaping (Bool) -> Void) {
        // Check for valid cookies in Keychain
        if let cookies = KeychainHelper.tpSessionCookies,
           cookies.contains(where: { $0.name == "ASP.NET_SessionId" }) {
            isAuthenticated = true
            completion(true)
            return
        }
        isAuthenticated = false
        completion(false)
    }
    
    // MARK: - Export & Download
    func requestExport(completion: @escaping (Result<URL, Error>) -> Void) {
        // Load cookies from Keychain
        guard let cookies = KeychainHelper.tpSessionCookies else {
            completion(.failure(NSError(domain: "TrainingPeaksService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])));
            return
        }
        // Prepare request
        var request = URLRequest(url: URL(string: "https://app.trainingpeaks.com/ExportData/ExportUserData")!)
        request.httpMethod = "POST"
        let cookieHeader = HTTPCookie.requestHeaderFields(with: cookies)
        request.allHTTPHeaderFields = cookieHeader
        
        // Perform request
        let session = URLSession(configuration: .default)
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(NSError(domain: "TrainingPeaksService", code: 500, userInfo: [NSLocalizedDescriptionKey: "No HTTP response"])))
                return
            }
            // Expecting 302 redirect to CloudFront ZIP URL
            if httpResponse.statusCode == 302,
               let location = httpResponse.allHeaderFields["Location"] as? String,
               let zipURL = URL(string: location) {
                // Download ZIP
                let downloadTask = session.downloadTask(with: zipURL) { tempURL, _, downloadError in
                    if let downloadError = downloadError {
                        completion(.failure(downloadError))
                        return
                    }
                    guard let tempURL = tempURL else {
                        completion(.failure(NSError(domain: "TrainingPeaksService", code: 500, userInfo: [NSLocalizedDescriptionKey: "No ZIP file"])))
                        return
                    }
                    // Move file to app cache
                    let fileManager = FileManager.default
                    let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
                    let destURL = caches.appendingPathComponent("tp_export.zip")
                    try? fileManager.removeItem(at: destURL)
                    do {
                        try fileManager.moveItem(at: tempURL, to: destURL)
                        completion(.success(destURL))
                    } catch {
                        completion(.failure(error))
                    }
                }
                downloadTask.resume()
            } else {
                completion(.failure(NSError(domain: "TrainingPeaksService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Unexpected response: \(httpResponse.statusCode)"])));
            }
        }
        task.resume()
    }
    
    // MARK: - Unzip & Parse
    func ingestExportedData(from zipURL: URL, completion: @escaping (Bool) -> Void) {
        // Unzip the file
        let fileManager = FileManager.default
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let unzipDir = caches.appendingPathComponent("tp_unzipped")
        try? fileManager.removeItem(at: unzipDir)
        do {
            try fileManager.createDirectory(at: unzipDir, withIntermediateDirectories: true, attributes: nil)
            guard let archive = Archive(url: zipURL, accessMode: .read) else {
                errorMessage = "Failed to open ZIP archive."
                completion(false)
                return
            }
            for entry in archive {
                let destURL = unzipDir.appendingPathComponent(entry.path)
                _ = try archive.extract(entry, to: destURL)
            }
        } catch {
            errorMessage = "Failed to unzip: \(error.localizedDescription)"
            completion(false)
            return
        }
        // Parse CSVs
        let summaryCSV = unzipDir.appendingPathComponent("WorkoutSummaryExport.csv")
        if fileManager.fileExists(atPath: summaryCSV.path) {
            do {
                let csvString = try String(contentsOf: summaryCSV)
                let workouts = parseWorkoutSummaryCSV(csvString)
                self.workouts = workouts
                // TODO: Update Core Data/entities with workouts
                print("Parsed \(workouts.count) workouts from TrainingPeaks CSV.")
                completion(true)
            } catch {
                errorMessage = "Failed to read or parse CSV: \(error.localizedDescription)"
                completion(false)
            }
        } else {
            errorMessage = "WorkoutSummaryExport.csv not found in export."
            completion(false)
        }
    }
    
    // MARK: - CSV Parsing (simple)
    private func parseWorkoutSummaryCSV(_ csv: String) -> [Workout] {
        var workouts: [Workout] = []
        let lines = csv.components(separatedBy: "\n").filter { !$0.isEmpty }
        guard lines.count > 1 else { return workouts }
        let headers = lines[0].components(separatedBy: ",")
        for line in lines.dropFirst() {
            let fields = line.components(separatedBy: ",")
            if fields.count != headers.count { continue }
            // Map fields to Workout (adjust indices as needed)
            let workout = Workout(
                id: fields[0],
                name: fields[1],
                startDateLocal: ISO8601DateFormatter().date(from: fields[2]) ?? Date(),
                distance: Double(fields[3]) ?? 0.0,
                movingTime: Int(fields[4]) ?? 0
            )
            workouts.append(workout)
        }
        return workouts
    }
    
    // MARK: - Full Sync Flow
    func syncAll(completion: @escaping (Bool) -> Void) {
        isSyncing = true
        errorMessage = nil
        authenticate { [weak self] success in
            guard let self = self, success else {
                self?.isSyncing = false
                self?.errorMessage = "Authentication failed."
                completion(false)
                return
            }
            self.requestExport { result in
                switch result {
                case .success(let zipURL):
                    self.ingestExportedData(from: zipURL) { ingestSuccess in
                        self.isSyncing = false
                        self.lastSyncDate = Date()
                        completion(ingestSuccess)
                    }
                case .failure(let error):
                    self.isSyncing = false
                    self.errorMessage = error.localizedDescription
                    completion(false)
                }
            }
        }
    }
}
