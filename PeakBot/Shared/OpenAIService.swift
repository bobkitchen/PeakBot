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
//  Created on 20 Apr 2025
//

import Foundation
import SwiftUI                      // for @MainActor + ObservableObject

/// Extremely thin stub; replace `send` with real networking later.
@MainActor
final class OpenAIService: ObservableObject {

    /// Sends the user’s prompt to OpenAI and returns the assistant’s reply.
    func send(prompt: String) async throws -> String {
        // TODO: implement your OpenAI network call here.
        // For now, return a placeholder so the app runs.
        return "🧠 OpenAI stub — echo: \(prompt)"
    }
}