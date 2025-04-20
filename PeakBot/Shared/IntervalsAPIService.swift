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
//  Created on 19 Apr 2025
//

import Foundation
import SwiftUI                       // for @MainActor

/// Main entrance to the Intervals.icu REST API.
@MainActor
final class IntervalsAPIService: ObservableObject {

    // MARK: - Credentials (pulled from Keychain)
    private let apiKey   : String
    private let athleteID: String         // blank ⇒ “self”
    private let baseURL  = "https://intervals.icu/api/v1"

    // MARK: - Shared singleton -----------------------------------------------
    /// Use `IntervalsAPIService.shared` everywhere else in the app.
    static let shared: IntervalsAPIService = {
        guard let key = KeychainHelper.shared.intervalsApiKey,
              !key.isEmpty else {
            fatalError("IntervalsAPI key missing – open Settings first.")
        }
        let id = KeychainHelper.shared.athleteID ?? ""
        return IntervalsAPIService(apiKey: key, athleteID: id)
    }()

    // MARK: - Initialisation ---------------------------------------------------
    private init(apiKey: String, athleteID: String) {
        self.apiKey    = apiKey
        self.athleteID = athleteID
    }

    // MARK: - Public API -------------------------------------------------------

    /// CTL/ATL/TSB trend for the last *daysBack* days.
    func fetchFitnessTrend(daysBack: Int = 90) async throws -> [FitnessPoint] {

        // 1. Get CSV of recent workouts
        let csv      = try await fetchActivitiesCSV(daysBack: daysBack)
        let workouts = try CSVWorkoutParser.parse(csv)

        // 2. Crunch numbers
        return FitnessPointCalculator.trend(from: workouts, days: daysBack)
    }

    /// Raw workouts list as CSV (no parsing here).
    func fetchActivitiesCSV(daysBack: Int = 14) async throws -> String {

        var comps = URLComponents(string: "\(baseURL)/athlete/\(athleteID)/activities.csv")!
        comps.queryItems = [.init(name: "days", value: String(daysBack))]

        let data = try await request(comps)
        guard let csv = String(data: data, encoding: .utf8) else {
            throw ServiceError.csvParsing
        }
        return csv
    }

    // MARK: - Private helpers --------------------------------------------------

    private func request(_ comps: URLComponents) async throws -> Data {

        guard let url = comps.url else { throw ServiceError.invalidURL }

        var req = URLRequest(url: url)
        req.setValue(authHeader, forHTTPHeaderField: "Authorization")

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else {
            throw ServiceError.invalidURL
        }

        switch http.statusCode {
        case 200:   return data
        case 401:   throw ServiceError.unauthorized
        case 404:   throw ServiceError.notFound
        default:    throw ServiceError.serverError(status: http.statusCode)
        }
    }

    /// `Basic <base64(apiKey:athleteID)>`
    private var authHeader: String {
        let cred = "\(apiKey):\(athleteID)"
        let b64  = Data(cred.utf8).base64EncodedString()
        return "Basic \(b64)"
    }
}