//
//  ChatViewModel.swift
//  PeakBot
//
//  Created by Bob Kitchen on 4/20/25.
//

import SwiftUI

// Removed duplicate ChatMessage struct. Use the one in ChatMessage.swift.

@MainActor
final class ChatViewModel: ObservableObject {

    // MARK: – State
    @Published var messages: [ChatMessage] = []
    @Published var input = ""

    // MARK: – Public API
    func send() async {
        // 1. append the user’s message
        let userMsg = ChatMessage(id: UUID(), role: .user, content: input)
        messages.append(userMsg)
        input = ""

        // 2. ask OpenAI for a reply
        do {
            let reply = try await "assistant reply" // placeholder for OpenAI reply
            let assistantMsg = ChatMessage(id: UUID(), role: .assistant, content: reply)
            messages.append(assistantMsg)
        } catch {
            messages.append(ChatMessage(id: UUID(), role: .assistant,
                                         content: "⚠️ Error: \(error.localizedDescription)"))
        }
    }
}