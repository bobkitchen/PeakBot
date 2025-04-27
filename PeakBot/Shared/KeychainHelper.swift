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
}