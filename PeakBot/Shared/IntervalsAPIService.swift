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
    private let athleteID: String = "0"
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
        let csv   = try await fetchActivitiesCSV(daysBack: daysBack)
        let wouts = try CSVWorkoutParser.parse(csv)
        return FitnessPointCalculator.trend(from: wouts, days: daysBack)
    }

    // MARK: – Download workouts CSV
    func fetchActivitiesCSV(daysBack: Int = 14) async throws -> String {
        let url = "\(baseURL)/athlete/\(athleteID)/activities.csv"
        guard var comps = URLComponents(string: url) else { throw ServiceError.invalidURL }
        comps.queryItems = [ .init(name: "days", value: String(daysBack)) ]

        let data = try await request(comps)
        guard let csv = String(data: data, encoding: .utf8) else { throw ServiceError.csvParsing }
        return csv
    }

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
