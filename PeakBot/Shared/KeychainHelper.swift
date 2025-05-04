//
//  KeychainHelper.swift
//  PeakBot
//
//  Created by Bob Kitchen on 4/20/25.
//


//
//  KeychainHelper.swift
//  PeakBot
//
//  Provides a tiny wrapper around Kishikawa Katsumi’s KeychainAccess
//

import Foundation
import KeychainAccess                    // ← SPM package

/// All app‑wide secrets live under this service name.
private let kc = Keychain(service: "PeakBot.Keys")

enum KeychainHelper {
    // MARK: – Stored keys
    private enum K {
        // Removed Strava and Intervals keys for TrainingPeaks transition
        // static let apiKey   = "tp_api"
        // static let athlete  = "tp_id"
        // static let stravaAccessToken = "strava_access_token"
        // static let stravaRefreshToken = "strava_refresh_token"
        // static let stravaExpiresAt = "strava_expires_at"
    }

    // MARK: – Typed accessors
    // Removed Intervals and Strava accessors for TrainingPeaks transition
    // static var intervalsApiKey: String? { ... }
    // static var athleteID: String? { ... }
    // static var stravaAccessToken: String? { ... }
    // static var stravaRefreshToken: String? { ... }
    // static var stravaExpiresAt: TimeInterval? { ... }

    // Removed clearStravaTokens for TrainingPeaks transition
    // static func clearStravaTokens() { ... }

    // Removed hasAllKeys for TrainingPeaks transition
    // static var hasAllKeys: Bool { intervalsApiKey != nil && athleteID != nil }

    // MARK: – TrainingPeaks Session Cookies
    static var tpSessionCookies: [HTTPCookie]? {
        get {
            guard let data = try? kc.getData("tp_cookies") else { return nil }
            do {
                let cookies = try NSKeyedUnarchiver.unarchivedObject(ofClasses: [NSArray.self, HTTPCookie.self], from: data) as? [HTTPCookie]
                return cookies
            } catch {
                return nil
            }
        }
        set {
            guard let cookies = newValue else {
                try? kc.remove("tp_cookies")
                return
            }
            do {
                let data = try NSKeyedArchiver.archivedData(withRootObject: cookies, requiringSecureCoding: false)
                try kc.set(data, key: "tp_cookies")
            } catch {
                // Ignore error
            }
        }
    }

    static var athleteId: String? {
        get  { read("athleteId") }
        set  { write("athleteId", newValue) }
    }

    static func persistTPCookies(cookies: [HTTPCookie]) {
        tpSessionCookies = cookies
        // Persist athleteId directly if present in cookies
        if let id = cookies.first(where: { $0.name == "ajs_user_id" })?.value {
            athleteId = id
        }
    }

    @MainActor static func restoreTPCookies() {
        // …existing cookie injection …
        _ = KeychainHelper.tpSessionCookies // ensure cookies restored

        // Hydrate athleteId directly from Keychain
        if let id = athleteId {
            print("[KeychainHelper] 🔑 restored athleteId = \(id)")
            // Persist athleteId for TPConnector so it can be used immediately without additional network calls.
            if let intId = Int(id) {
                // Store in UserDefaults so TPConnector.athleteId computed property can read it
                UserDefaults.standard.set(intId, forKey: "tpAthleteID")
                TPConnector.shared.athleteId = intId  // cache in runtime instance as well
            }
        } else {
            print("[KeychainHelper] 🔑 athleteId not found in Keychain")
        }
    }

    // MARK: - Private helpers
    private static func read(_ key: String) -> String? {
        return try? kc.getString(key)
    }

    private static func write(_ key: String, _ value: String?) {
        if let value = value {
            try? kc.set(value, key: key)
        } else {
            try? kc.remove(key)
        }
    }
}
