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
//  Created on 20 Apr 2025
//

import Foundation
import KeychainAccess               // ⇦ make sure Swift Package is added
import SwiftUI                      // for @MainActor

/// Thin wrapper around the KeychainAccess package.
@MainActor
final class KeychainHelper {

    // MARK: - Singleton
    static let shared = KeychainHelper()
    private init() {}

    private let kc = Keychain(service: "PeakBot.Keys")

    // MARK: - Stored keys ------------------------------------------------------

    /// Intervals.icu API key (optional)
    var intervalsApiKey: String? {
        get { try? kc.get("ic_api_key") }
        set { kc["ic_api_key"] = newValue }
    }

    /// Athlete ID (blank ⇒ “self”)
    var athleteID: String? {
        get { try? kc.get("ic_athlete_id") }
        set { kc["ic_athlete_id"] = newValue }
    }

    /// Convenience flag for onboarding screen
    var hasAllKeys: Bool {
        intervalsApiKey != nil && athleteID != nil
    }
}