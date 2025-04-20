//
//  IntervalsAPIService.swift
//  PeakBot
//
//  Revised 20 Apr 2025 – compiles on Swift 6.
//

import Foundation
import SwiftUI

// MARK: - Errors --------------------------------------------------------------

enum ServiceError: Error, LocalizedError {
    case invalidURL, unauthorized, notFound
    case serverError(status: Int)
    case csvParsing
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:             return "Bad API URL."
        case .unauthorized:           return "401 – check your API key."
        case .notFound:               return "404 – resource not found."
        case .serverError(let s):     return "Server replied (\(s))."
        case .csvParsing:             return "CSV couldn’t be parsed."
        case .decodingError(let err): return err.localizedDescription
        }
    }
}

// MARK: - Service -------------------------------------------------------------

@MainActor
final class IntervalsAPIService: ObservableObject {

    // 1. Credentials (pulled from Keychain)
    private let apiKey:    String
    private let athleteID: String
    private let baseURL = "https://intervals.icu/api/v1"

    // 2. Shared singleton
    static let shared: IntervalsAPIService = {
        guard let key = KeychainHelper.shared.intervalsApiKey,
              let id  = KeychainHelper.shared.athleteID else {
            fatalError("Intervals API keys missing – open Settings first.")
        }
        return IntervalsAPIService(apiKey: key, athleteID: id)
    }()

    // 3. Designated init
    private init(apiKey: String, athleteID: String) {
        self.apiKey    = apiKey
        self.athleteID = athleteID
    }

    // MARK: - PUBLIC API ------------------------------------------------------

    /// CTL/ATL/TSB points for *daysBack* days.
    func fetchFitnessTrend(daysBack: Int = 90) async throws -> [FitnessPoint] {
        let csv      = try await fetchActivitiesCSV(daysBack: daysBack)
        let workouts = try CSVWorkoutParser.parse(csv)
        return FitnessCalculator.trend(from: workouts, days: daysBack)
    }

    // MARK: - PRIVATE helpers -------------------------------------------------

    private func fetchActivitiesCSV(daysBack: Int = 14) async throws -> String {
        var comps = URLComponents(string:
            "\(baseURL)/athlete/\(athleteID)/activities.csv")!
        comps.queryItems = [.init(name: "days", value: String(daysBack))]

        let data = try await request(comps)
        guard let str = String(data: data, encoding: .utf8) else {
            throw ServiceError.csvParsing
        }
        return str
    }

    private func request(_ comps: URLComponents) async throws -> Data {
        guard let url = comps.url else { throw ServiceError.invalidURL }

        var req = URLRequest(url: url)
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else {
            throw ServiceError.invalidURL
        }

        switch http.statusCode {
        case 200: return data
        case 401: throw ServiceError.unauthorized
        case 404: throw ServiceError.notFound
        default:  throw ServiceError.serverError(status: http.statusCode)
        }
    }
}
