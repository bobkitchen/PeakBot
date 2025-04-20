//
//  KeychainHelper.swift
//  PeakBot
//
//  Created by Bob Kitchen on 20 Apr 2025.
//

import Foundation
import KeychainAccess          // ← Swift‑PM package we added

/// All key‑value secrets live here.
/// Because Swift 6 enforces actor isolation for `@MainActor` singletons
/// we expose a *value* (`shared`) rather than static vars.
@MainActor
final class KeychainHelper: ObservableObject {

    // MARK: – Singleton
    static let shared = KeychainHelper()      // <— use this everywhere
    private init() { }

    // MARK: – Keys
    private let kc = Keychain(service: "PeakBot.Keys")

    @Published var intervalsApiKey: String? {
        get { try? kc["api_key"]               }
        set {     kc["api_key"] = newValue     }
    }

    @Published var athleteID:        String? {
        get { try? kc["athlete_id"]           }
        set {     kc["athlete_id"] = newValue }
    }

    /// Helper for onboarding
    var hasAllKeys: Bool { intervalsApiKey != nil && athleteID != nil }
}
