
import Foundation

/// A single message in the chat.
struct ChatMessage: Identifiable, Hashable, Codable {
    enum Role: String, Codable { case user, assistant }

    let id = UUID()
    let role: Role
    let content: String
}
