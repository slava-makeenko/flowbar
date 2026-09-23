import FlowbarDomain

extension Agent {

  /// Название агента для интерфейса.
  public var title: String {
    switch self {
    case .claudeCode: "Claude Code"
    case .codex: "Codex"
    }
  }

  /// Папка агента, как её называет пользователь.
  public var folderTitle: String {
    switch self {
    case .claudeCode: "~/.claude"
    case .codex: "~/.codex"
    }
  }
}
