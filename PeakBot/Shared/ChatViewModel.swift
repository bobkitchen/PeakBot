
import SwiftUI

@MainActor
final class ChatViewModel: ObservableObject {

    // MARK: – State
    @Published var messages: [ChatMessage] = []
    @Published var input: String = ""

    // MARK: – Dependency
    private let service: OpenAIService
    init(service: OpenAIService = .init()) { self.service = service }

    // MARK: – Public API
    func send() async {
        // 1. append the user’s message
        let userMsg = ChatMessage(role: .user, content: input)
        messages.append(userMsg)
        input = ""

        // 2. Ask OpenAI for a reply
        do {
            let assistantText = try await service.send(prompt: userMsg.content)
            let assistantMsg  = ChatMessage(role: .assistant, content: assistantText)
            messages.append(assistantMsg)
        } catch {
            let errMsg = ChatMessage(role: .assistant,
                                     content: "⚠️ Error: \(error.localizedDescription)")
            messages.append(errMsg)
        }
    }
}
