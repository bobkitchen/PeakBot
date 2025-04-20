//
//  OpenAIService.swift
//  PeakBot
//
//  Created by Bob Kitchen on 4/20/25.
//


//
//  OpenAIService.swift
//  PeakBot
//

import Foundation
import Observation                         // Swift 6

@MainActor
final class OpenAIService: ObservableObject {

    // MARK: – Singleton
    @MainActor static let shared = OpenAIService()    // public & actor‑isolated

    private init() { }

    // MARK: – Simple echo mock (replace with real networking later)
    func send(_ prompt: String) async throws -> String {
        try await Task.sleep(for: .seconds(0.4))
        return "Echo: \(prompt)"
    }
}