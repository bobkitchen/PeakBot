//
//  OpenAIService.swift
//  PeakBot
//

import Foundation
import SwiftUI

@MainActor
final class OpenAIService: ObservableObject {

    static let shared = OpenAIService()
    private init() { }

    // stub – implement when you add Chat tab back
    func send(prompt: String) async throws -> String {
        return "🤖  Not wired yet."
    }
}
