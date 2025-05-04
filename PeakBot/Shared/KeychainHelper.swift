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
        static let stravaAccessToken = "strava_access_token"
        static let stravaRefreshToken = "strava_refresh_token"
        static let stravaExpiresAt = "strava_expires_at"
    }

    // MARK: – Strava accessors
    static var stravaAccessToken: String? {
        get { read(K.stravaAccessToken) }
        set { write(K.stravaAccessToken, newValue) }
    }
    static var stravaRefreshToken: String? {
        get { read(K.stravaRefreshToken) }
        set { write(K.stravaRefreshToken, newValue) }
    }
    static var stravaExpiresAt: TimeInterval? {
        get { TimeInterval(read(K.stravaExpiresAt) ?? "") }
        set { write(K.stravaExpiresAt, String(newValue ?? 0)) }
    }
    static func clearStravaTokens() {
        try? kc.remove(K.stravaAccessToken)
        try? kc.remove(K.stravaRefreshToken)
        try? kc.remove(K.stravaExpiresAt)
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
