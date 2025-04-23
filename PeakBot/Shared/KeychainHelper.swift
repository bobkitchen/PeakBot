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
        static let apiKey   = "tp_api"
        static let athlete  = "tp_id"
        static let stravaAccessToken = "strava_access_token"
        static let stravaRefreshToken = "strava_refresh_token"
        static let stravaExpiresAt = "strava_expires_at"
    }

    // MARK: – Typed accessors
    static var intervalsApiKey: String? {
        get { try? kc.get(K.apiKey) }
        set { kc[K.apiKey] = newValue }
    }

    static var athleteID: String? {
        get { try? kc.get(K.athlete) }
        set { kc[K.athlete] = newValue }
    }

    static var stravaAccessToken: String? {
        get { try? kc.get(K.stravaAccessToken) }
        set { kc[K.stravaAccessToken] = newValue }
    }

    static var stravaRefreshToken: String? {
        get { try? kc.get(K.stravaRefreshToken) }
        set { kc[K.stravaRefreshToken] = newValue }
    }

    static var stravaExpiresAt: TimeInterval? {
        get {
            guard let value = try? kc.get(K.stravaExpiresAt), let doubleVal = Double(value) else { return nil }
            return doubleVal
        }
        set {
            if let val = newValue {
                kc[K.stravaExpiresAt] = String(val)
            } else {
                kc[K.stravaExpiresAt] = nil
            }
        }
    }

    static func clearStravaTokens() {
        kc[K.stravaAccessToken] = nil
        kc[K.stravaRefreshToken] = nil
        kc[K.stravaExpiresAt] = nil
    }

    /// `true` only when both credentials are present.
    static var hasAllKeys: Bool { intervalsApiKey != nil && athleteID != nil }
}