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

    // MARK: – Credentials (pulled from Keychain)
    private let apiKey:    String
    private let athleteID: String
    private let baseURL    = "https://intervals.icu/api/v1"

    // MARK: – Shared factory method
    @MainActor static func makeShared() -> IntervalsAPIService? {
        guard
            let key = KeychainHelper.intervalsApiKey,
            let id  = KeychainHelper.athleteID
        else {
            return nil
        }
        return IntervalsAPIService(apiKey: key, athleteID: id)
    }

    // MARK: – Initialisation
    private init(apiKey: String, athleteID: String) {
        self.apiKey    = apiKey
        self.athleteID = athleteID
    }

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
        guard let url = comps.url else { throw ServiceError.invalidURL }

        var req = URLRequest(url: url)
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw ServiceError.invalidURL }

        switch http.statusCode {
        case 200:  return data
        case 401:  throw ServiceError.unauthorized
        case 404:  throw ServiceError.notFound
        default:   throw ServiceError.serverError(status: http.statusCode)
        }
    }
}
