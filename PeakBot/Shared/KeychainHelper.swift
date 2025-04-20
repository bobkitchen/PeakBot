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

    /// `true` only when both credentials are present.
    static var hasAllKeys: Bool { intervalsApiKey != nil && athleteID != nil }
}