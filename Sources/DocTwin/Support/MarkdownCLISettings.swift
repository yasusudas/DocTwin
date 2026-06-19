import Foundation

enum MarkdownCLIProvider: String, CaseIterable, Identifiable {
    case codex
    case claude
    case gemini
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .codex:
            return "Codex CLI"
        case .claude:
            return "Claude Code CLI"
        case .gemini:
            return "Gemini CLI"
        case .custom:
            return "カスタムCLI"
        }
    }

    var defaultCommandTemplate: String {
        switch self {
        case .codex:
            return #"codex exec --skip-git-repo-check "$(cat "$DOCTWIN_PROMPT_FILE")""#
        case .claude:
            return #"claude -p "$(cat "$DOCTWIN_PROMPT_FILE")""#
        case .gemini:
            return #"gemini --skip-trust --approval-mode auto_edit --output-format text -p "$(cat "$DOCTWIN_PROMPT_FILE")""#
        case .custom:
            return ""
        }
    }
}

struct MarkdownCLISettings {
    enum Keys {
        static let provider = "MarkdownCLIProvider"
        static let commandTemplate = "MarkdownCLICommandTemplate"
        static let timeoutSeconds = "MarkdownCLITimeoutSeconds"
    }

    static let defaultProvider: MarkdownCLIProvider = .codex
    static let defaultTimeoutSeconds: TimeInterval = 3600

    let provider: MarkdownCLIProvider
    let commandTemplate: String
    let timeoutSeconds: TimeInterval

    static func current(defaults: UserDefaults = .standard) -> MarkdownCLISettings {
        let provider = defaults.string(forKey: Keys.provider)
            .flatMap(MarkdownCLIProvider.init(rawValue:)) ?? defaultProvider
        let storedCommand = defaults.string(forKey: Keys.commandTemplate) ?? ""
        let commandTemplate = storedCommand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? provider.defaultCommandTemplate
            : storedCommand
        let storedTimeout = defaults.double(forKey: Keys.timeoutSeconds)
        let timeoutSeconds = storedTimeout > 0 ? storedTimeout : defaultTimeoutSeconds

        return MarkdownCLISettings(
            provider: provider,
            commandTemplate: commandTemplate,
            timeoutSeconds: timeoutSeconds
        )
    }
}
