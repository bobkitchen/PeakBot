//
//  IntervalsAPIService.swift
//  PeakBot
//
//  Created by Bob Kitchen on 4/20/25.
//

//
//  IntervalsAPIService.swift
//  PeakBot
//

import Foundation
import SwiftUI                               // for @MainActor
import Combine                               // for ObservableObject

// MARK: – Errors ----------------------------------------------------------------

enum ServiceError: Error, LocalizedError {
    case invalidURL, unauthorized, notFound
    case serverError(status: Int)
    case csvParsing, decodingError(Error)

    var errorDescription: String {
        switch self {
        case .invalidURL:            return "Bad API URL."
        case .unauthorized:          return "401 – check your API key."
        case .notFound:              return "404 – resource not found."
        case .serverError(let s):    return "Server replied (\(s))."
        case .csvParsing:            return "CSV couldn’t be parsed."
        case .decodingError(let e):  return e.localizedDescription
        }
    }
}

// MARK: – Service ----------------------------------------------------------------

@MainActor
final class IntervalsAPIService: ObservableObject {

    // MARK: – Credentials (hardcoded for testing)
    private let apiKey:    String = "3ntigdu81v3u5chn07ivi7z74"
    private let athleteID: String = "327607" // <-- Set to your actual athlete ID
    private let baseURL    = "https://intervals.icu/api/v1"

    // MARK: – Shared factory method
    @MainActor static func makeShared() -> IntervalsAPIService? {
        // Ignore any Keychain or Settings values for now
        return IntervalsAPIService()
    }

    // MARK: – Initialisation
    private init() {}

    // MARK: – Public API (called by view‑models)
    func fetchFitnessTrend(daysBack: Int = 90) async throws -> [FitnessPoint] {
        // JSON is now the only supported workflow
        let fitnessPoints = try await fetchWellnessJSON(daysBack: daysBack)
        return fitnessPoints
    }

    // MARK: – Fetch fitness trend as JSON (direct from Intervals.icu)
    // DISABLED: This endpoint does not exist or is not available for API users.
    func fetchFitnessTrendJSON(daysBack: Int = 90) async throws -> [FitnessPoint] {
        fatalError("The /fitness endpoint is not available via the Intervals.icu public API. Use fetchWellnessJSON instead.")
    }

    // MARK: – Fetch wellness (CTL/ATL/TSB) as JSON from Intervals.icu
    func fetchWellnessJSON(daysBack: Int = 90) async throws -> [FitnessPoint] {
        let url = "\(baseURL)/athlete/\(athleteID)/wellness"
        guard var comps = URLComponents(string: url) else { throw ServiceError.invalidURL }
        let calendar = Calendar.current
        let today = Date()
        let oldestDate = calendar.date(byAdding: .day, value: -daysBack+1, to: today) ?? today
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let oldestString = formatter.string(from: oldestDate)
        comps.queryItems = [
            .init(name: "oldest", value: oldestString)
        ]
        print("[DEBUG] Will request WELLNESS endpoint:")
        print("[DEBUG] URL: \(comps.url?.absoluteString ?? "nil")")
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        // Decode as array of wellness points, then map to FitnessPoint
        struct WellnessPoint: Decodable {
            let date: Date
            let icu_ctl: Double?
            let icu_atl: Double?
        }
        let data = try await request(comps)
        print("[DEBUG] Raw data: \(String(data: data, encoding: .utf8)?.prefix(500) ?? "nil")")
        let rawPoints = try decoder.decode([WellnessPoint].self, from: data)
        var lastCtl = 0.0, lastAtl = 0.0
        let fitnessPoints = rawPoints.compactMap { w -> FitnessPoint? in
            let ctl = w.icu_ctl ?? lastCtl
            let atl = w.icu_atl ?? lastAtl
            lastCtl = ctl
            lastAtl = atl
            return FitnessPoint(id: UUID(), date: w.date, ctl: ctl, atl: atl, tsb: ctl - atl)
        }
        return fitnessPoints
    }

    // MARK: – Fetch workouts as JSON (with TSS, etc.)
    func fetchWorkoutsJSON(oldest: String = "2024-01-01") async throws -> [Workout] {
        let url = "https://intervals.icu/api/v1/athlete/0/activities"
        guard var comps = URLComponents(string: url) else { throw ServiceError.invalidURL }
        comps.queryItems = [ .init(name: "oldest", value: oldest) ]
        let data = try await request(comps)
        if let raw = String(data: data, encoding: .utf8) {
            print("[IntervalsAPIService] Raw JSON response: \(raw)")
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([Workout].self, from: data)
    }

    // MARK: – Legacy CSV API (removed)
    // func fetchWorkoutsCSV(daysBack: Int = 14) async throws -> [Workout] {
    //     fatalError("CSV API is deprecated. Use fetchWorkoutsJSON instead.")
    // }

    // MARK: – HTTP plumbing
    private func request(_ comps: URLComponents) async throws -> Data {
        // Patch athlete ID logic: use "me" if empty or "me", else use numeric
        var comps = comps
        if let idx = comps.path.range(of: "/athlete/") {
            let rest = comps.path[idx.upperBound...]
            let idEnd = rest.prefix { $0.isNumber }
            let athleteId = String(idEnd)
            if athleteId.isEmpty || athleteId.lowercased() == "me" {
                comps.path = comps.path.replacingOccurrences(of: "/athlete/" + athleteId, with: "/athlete/me")
            }
        }

        print("[IntervalsAPIService] Requesting: \(comps.url?.absoluteString ?? "nil")")
        print("[IntervalsAPIService] Using API Key: \(apiKey)")
        print("[IntervalsAPIService] Using Athlete ID: \(athleteID)")

        guard let url = comps.url else { throw ServiceError.invalidURL }
        var req = URLRequest(url: url)
        let credentials = "API_KEY:\(apiKey)"
        let authHeader = "Basic " + Data(credentials.utf8).base64EncodedString()
        req.setValue(authHeader, forHTTPHeaderField: "Authorization")

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw ServiceError.invalidURL }

        print("[IntervalsAPIService] HTTP Status: \(http.statusCode)")
        if let responseString = String(data: data, encoding: .utf8) {
            print("[IntervalsAPIService] Response: \(responseString.prefix(500))")
        }

        switch http.statusCode {
        case 200:  return data
        case 401:  throw ServiceError.unauthorized
        case 404:  throw ServiceError.notFound
        default:   throw ServiceError.serverError(status: http.statusCode)
        }
    }
}
