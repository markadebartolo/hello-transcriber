import Foundation

/// Explicit destinations only: a key is never tried against another service.
enum HelloAIProvider: String, CaseIterable, Identifiable, Sendable {
    case openAI = "openai"
    case anthropic
    case openRouter = "openrouter"

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .openAI: return "OpenAI"
        case .anthropic: return "Anthropic"
        case .openRouter: return "OpenRouter"
        }
    }
    var endpoint: URL {
        let value: String
        switch self {
        case .openAI: value = "https://api.openai.com/v1/responses"
        case .anthropic: value = "https://api.anthropic.com/v1/messages"
        case .openRouter: value = "https://openrouter.ai/api/v1/responses"
        }
        return URL(string: value)!
    }
    var model: String {
        switch self {
        case .openAI: return "gpt-4.1-mini"
        case .anthropic: return "claude-sonnet-4-5"
        case .openRouter: return "openai/gpt-4.1-mini"
        }
    }
    // Preserve the existing OpenAI service name so installed keys need no migration.
    var keychainService: String { "com.markdebartolo.hello.\(rawValue)" }
    var recipientDescription: String {
        self == .openRouter ? "OpenRouter and its routed model provider" : displayName
    }
}
